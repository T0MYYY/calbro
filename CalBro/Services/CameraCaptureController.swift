import Foundation
@preconcurrency import AVFoundation
import CoreMotion
import os

private let camLog = Logger(subsystem: "com.wydfcc.calbro", category: "Camera")

enum CameraCaptureStatus: Equatable {
    case idle
    case requestingPermission
    case starting
    case running
    case denied
    case unavailable

    /// Shown in the camera HUD when capture isn't possible.
    var message: String? {
        switch self {
        case .idle, .running:       nil
        case .requestingPermission: String(localized: "Waiting for camera access…")
        case .starting:             String(localized: "Starting camera…")
        case .denied:               String(localized: "Camera access is off. Turn it on in Settings › CalBro.")
        case .unavailable:          String(localized: "The camera isn't available on this device.")
        }
    }

    var canCapture: Bool { self == .running }
}

enum CameraCaptureError: Error {
    case unavailable
    case captureInProgress
    case noPhotoData
}

@MainActor
@Observable
final class CameraCaptureController {
    private(set) var status: CameraCaptureStatus = .idle
    /// Distance to the surface in cm from LiDAR / dual-camera depth; nil when unavailable.
    private(set) var currentHeightCm: Double?

    private let box = CameraSessionBox()

    var session: AVCaptureSession { box.session }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            status = .requestingPermission
            Task {
                if await AVCaptureDevice.requestAccess(for: .video) { configureAndStart() }
                else { status = .denied }
            }
        case .denied, .restricted:
            status = .denied
        @unknown default:
            status = .unavailable
        }
    }

    func stop() {
        box.stop()
        currentHeightCm = nil
    }

    func capturePhotoData() async throws -> Data {
        guard status.canCapture else { throw CameraCaptureError.unavailable }
        return try await box.capturePhotoData()
    }

    private func configureAndStart() {
        status = .starting
        box.onDepthSample = { [weak self] cm in
            Task { @MainActor [weak self] in self?.currentHeightCm = cm }
        }
        box.configureAndStart { [weak self] succeeded in
            Task { @MainActor [weak self] in
                self?.status = succeeded ? .running : .unavailable
            }
        }
    }
}

// MARK: - Device tilt

/// Reads how far the phone is from pointing straight down.
@MainActor
final class TiltSensor {
    private let manager = CMMotionManager()

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 0.1
        manager.startDeviceMotionUpdates()
    }

    func stop() { manager.stopDeviceMotionUpdates() }

    /// 0° when the back camera points straight down, 90° when the phone is upright; nil without motion data.
    var tiltDegrees: Double? {
        guard let g = manager.deviceMotion?.gravity else { return nil }
        return acos(max(-1, min(1, -g.z))) * 180 / .pi
    }
}

// MARK: - CameraSessionBox

/// Owns the capture session. Everything except `onDepthSample` assignment runs on `sessionQueue`.
private final class CameraSessionBox: NSObject,
    AVCapturePhotoCaptureDelegate,
    AVCaptureDepthDataOutputDelegate,
    @unchecked Sendable
{
    let session = AVCaptureSession()
    /// Receives a smoothed height in cm (or nil) for each depth frame, on the session queue.
    var onDepthSample: (@Sendable (Double?) -> Void)?

    private let sessionQueue = DispatchQueue(label: "calbro.camera.session", qos: .userInitiated)
    private let photoOutput  = AVCapturePhotoOutput()
    private let depthOutput  = AVCaptureDepthDataOutput()
    private var photoContinuation: CheckedContinuation<Data, Error>?
    private var configured = false

    // Rolling average of the last 8 frames for a stable height reading
    private var depthSamples: [Double] = []
    private let depthSampleCapacity = 8

    func configureAndStart(completion: @escaping @Sendable (Bool) -> Void) {
        sessionQueue.async { [self] in
            do {
                if !configured {
                    try configureSession()
                    configured = true
                }
                if !session.isRunning { session.startRunning() }
                completion(true)
            } catch {
                camLog.error("Session configuration failed: \(String(describing: error), privacy: .public)")
                completion(false)
            }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
            depthSamples.removeAll()
        }
    }

    func capturePhotoData() async throws -> Data {
        try await withCheckedThrowingContinuation { cont in
            sessionQueue.async { [self] in
                guard photoContinuation == nil else {
                    cont.resume(throwing: CameraCaptureError.captureInProgress)
                    return
                }
                photoContinuation = cont
                let settings = AVCapturePhotoSettings()
                settings.flashMode = .off
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }

        // The plain wide-angle camera has no depth; LiDAR / dual-camera virtual devices do.
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInLiDARDepthCamera, .builtInDualCamera, .builtInDualWideCamera,
                          .builtInTripleCamera, .builtInWideAngleCamera],
            mediaType: .video, position: .back
        )
        let device = discovery.devices.first(where: { !$0.activeFormat.supportedDepthDataFormats.isEmpty })
            ?? discovery.devices.first
        guard let device,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            throw CameraCaptureError.unavailable
        }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else { throw CameraCaptureError.unavailable }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality

        guard session.canAddOutput(depthOutput) else { return }
        session.addOutput(depthOutput)
        depthOutput.isFilteringEnabled = true
        depthOutput.alwaysDiscardsLateDepthData = true
        depthOutput.setDelegate(self, callbackQueue: sessionQueue)
        depthOutput.connection(with: .depthData)?.isEnabled = true

        // activeDepthDataFormat must be set after the outputs are added or no depth frames arrive.
        let formats = device.activeFormat.supportedDepthDataFormats
        let preferred = formats.first {
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat32
        } ?? formats.first
        if let preferred {
            do {
                try device.lockForConfiguration()
                device.activeDepthDataFormat = preferred
                device.unlockForConfiguration()
            } catch {
                camLog.error("Depth format not set: \(String(describing: error), privacy: .public)")
            }
        }
    }

    // MARK: - AVCapturePhotoCaptureDelegate

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let data = photo.fileDataRepresentation()
        sessionQueue.async { [self] in
            let cont = photoContinuation
            photoContinuation = nil
            if let error { cont?.resume(throwing: error) }
            else if let data { cont?.resume(returning: data) }
            else { cont?.resume(throwing: CameraCaptureError.noPhotoData) }
        }
    }

    // MARK: - AVCaptureDepthDataOutputDelegate

    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData,
                         timestamp: CMTime, connection: AVCaptureConnection) {
        let converted = depthData.depthDataType == kCVPixelFormatType_DepthFloat32
            ? depthData
            : depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)

        let buf = converted.depthDataMap
        CVPixelBufferLockBaseAddress(buf, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buf, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buf) else { return }
        let w = CVPixelBufferGetWidth(buf), h = CVPixelBufferGetHeight(buf)
        let bpr = CVPixelBufferGetBytesPerRow(buf)

        // Average the central 20 % of the frame, ignoring invalid readings.
        let cx = w / 2, cy = h / 2, rx = max(1, w / 10), ry = max(1, h / 10)
        var sum = 0.0, count = 0.0
        for py in max(0, cy - ry)...min(h - 1, cy + ry) {
            let row = base.advanced(by: py * bpr).assumingMemoryBound(to: Float32.self)
            for px in max(0, cx - rx)...min(w - 1, cx + rx) {
                let v = Double(row[px])
                if v > 0.05 && v < 3.0 { sum += v; count += 1 }
            }
        }

        var cm: Double?
        if count > 0 {
            depthSamples.append(sum / count)
            if depthSamples.count > depthSampleCapacity { depthSamples.removeFirst() }
            cm = depthSamples.reduce(0, +) / Double(depthSamples.count) * 100
        }
        onDepthSample?(cm)
    }
}
