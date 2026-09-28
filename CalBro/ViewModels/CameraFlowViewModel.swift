import Foundation
import UIKit

enum CapturePhase: Equatable {
    case scanning          // waiting for overhead + correct height
    case aiming            // locked — filling progress ring
    case countdown(Int)    // 3 → 2 → 1
    case processing
    case result
}

@MainActor
@Observable
final class CameraFlowViewModel {
    private(set) var phase: CapturePhase = .scanning
    private(set) var guidance = CaptureGuidance(tiltDegrees: 90, heightCm: nil)
    private(set) var hasTiltReading = false
    private(set) var aimingProgress: Double = 0.0

    private(set) var result: FoodRecognitionResult?
    private(set) var capturedImageData: Data?
    /// Set when a capture fails; the result sheet is never shown in that case.
    var errorMessage: String?

    private let tilt = TiltSensor()
    private let recognitionService: FoodRecognitionService
    private let mealStore: MealLogStore
    private var countdownTask: Task<Void, Never>?

    init(recognitionService: FoodRecognitionService? = nil, mealStore: MealLogStore = .shared) {
        #if targetEnvironment(simulator)
        self.recognitionService = recognitionService ?? SimulatorSampleRecognitionService()
        #else
        self.recognitionService = recognitionService ?? DPFFoodRecognitionService()
        #endif
        self.mealStore = mealStore
    }

    var tiltDegrees: Double { guidance.tiltDegrees }
    var heightCm: Double? { guidance.heightCm }

    /// Countdown tolerates a little drift before giving up.
    private var countdownShouldCancel: Bool {
        if guidance.tiltDegrees > CaptureGuidance.overheadThreshold + 15 { return true }
        if let h = guidance.heightCm, h < 22 || h > 40 { return true }
        return false
    }

    // MARK: - Guidance loop

    func run(camera: CameraCaptureController) async {
        recognitionService.warmUp()
        tilt.start()
        defer { tilt.stop() }
        while !Task.isCancelled {
            if let degrees = tilt.tiltDegrees {
                hasTiltReading = true
                guidance.tiltDegrees = degrees
            }
            guidance.heightCm = camera.currentHeightCm

            switch phase {
            case .scanning:
                if hasTiltReading, camera.status.canCapture, errorMessage == nil, guidance.isReady {
                    enterAiming(camera: camera)
                }
            case .aiming:
                if !guidance.isReady { backToScanning() }
            case .countdown:
                if countdownShouldCancel { backToScanning() }
            case .processing, .result:
                break
            }

            do { try await Task.sleep(for: .milliseconds(200)) }
            catch { return }
        }
    }

    // MARK: - Actions

    func manualCapture(camera: CameraCaptureController) {
        guard phase == .scanning || phase == .aiming else { return }
        cancelCountdown()
        errorMessage = nil
        Task { await doCapture(camera: camera) }
    }

    func addToLog(multiplier: Double) {
        guard let r = result else { return }
        mealStore.log(LoggedMeal(
            id: UUID(), name: r.foodName, timestamp: Date(),
            calories: r.calories, proteinG: r.protein,
            carbsG: r.carbs, fatG: r.fat,
            servingMultiplier: multiplier
        ))
        reset()
    }

    func dismissResult() { reset() }

    func dismissError() { errorMessage = nil }

    // MARK: - Private

    private func backToScanning() {
        cancelCountdown()
        aimingProgress = 0
        phase = .scanning
    }

    private func enterAiming(camera: CameraCaptureController) {
        guard phase == .scanning else { return }
        phase = .aiming
        aimingProgress = 0
        countdownTask = Task { @MainActor [weak self] in
            let steps = 50
            for i in 0...steps {
                guard !Task.isCancelled, let self else { return }
                self.aimingProgress = Double(i) / Double(steps)
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard !Task.isCancelled, let self, self.phase == .aiming else { return }
            for n in [3, 2, 1] {
                guard !Task.isCancelled else { return }
                self.phase = .countdown(n)
                UIImpactFeedbackGenerator(style: n == 1 ? .heavy : .medium).impactOccurred()
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else { return }
            await self.doCapture(camera: camera)
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func doCapture(camera: CameraCaptureController) async {
        phase = .processing
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        let frameGuidance = guidance
        let imageData = try? await camera.capturePhotoData()
        capturedImageData = imageData
        do {
            result = try await recognitionService.recognizeFood(from: imageData, guidance: frameGuidance)
            phase = .result
        } catch {
            result = nil
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? String(localized: "The estimate failed on this photo. Try again from straight above.")
            aimingProgress = 0
            phase = .scanning
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func reset() {
        cancelCountdown()
        phase = .scanning
        aimingProgress = 0
        result = nil
        capturedImageData = nil
        errorMessage = nil
    }
}
