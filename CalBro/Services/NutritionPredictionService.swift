import Foundation
import CoreML
import UIKit
import os

private let mlLog = Logger(subsystem: "com.wydfcc.calbro", category: "CoreML")

protocol NutritionPredictionService: Sendable {
    /// Starts loading models in the background so the first capture isn't slow.
    func warmUp()
    func predictNutrition(from imageData: Data, guidance: CaptureGuidance) async throws -> NutritionPrediction
}

// MARK: - Core ML (Depth Anything V2 → DPF-Nutrition)

/// Shared so the models are loaded once per launch rather than every time the camera opens.
final class CoreMLNutritionPredictionService: NutritionPredictionService, @unchecked Sendable {
    static let shared = CoreMLNutritionPredictionService()

    private struct LoadedModels: @unchecked Sendable {
        let depth: MLModel      // DA2: image → depth (GRAYSCALE_FLOAT16)
        let nutrition: MLModel  // DPF: rgb + depth → nutrition [1, 5]
    }

    private let lock = NSLock()
    private var loadingTask: Task<LoadedModels?, Never>?

    /// The DA2 package declares a fixed 518×392 input (both multiples of 14).
    private static let da2InputSize = CGSize(width: 518, height: 392)
    private static let dpfHeight = 336
    private static let dpfWidth = 448

    func warmUp() { _ = modelTask() }

    func predictNutrition(from imageData: Data, guidance: CaptureGuidance) async throws -> NutritionPrediction {
        guard let image = UIImage(data: imageData) else { throw NutritionPredictionError.noPhoto }
        guard let models = await modelTask().value else {
            resetFailedLoad()
            throw NutritionPredictionError.modelUnavailable
        }
        let prediction: NutritionPrediction
        do {
            prediction = try await runPipeline(image: image, models: models)
        } catch {
            mlLog.error("Pipeline failed: \(String(describing: error), privacy: .public)")
            throw NutritionPredictionError.inferenceFailed
        }
        guard prediction.calories > 0, prediction.massGrams > 0 else {
            throw NutritionPredictionError.nothingDetected
        }
        return prediction
    }

    // MARK: - Pipeline

    private func runPipeline(image: UIImage, models: LoadedModels) async throws -> NutritionPrediction {
        guard let da2Image = image.resized(to: Self.da2InputSize),
              let pixelBuf = da2Image.toCVPixelBuffer() else {
            throw InferenceError.preprocessingFailed
        }
        let da2Out = try await models.depth.prediction(from: MLDictionaryFeatureProvider(dictionary: [
            "image": MLFeatureValue(pixelBuffer: pixelBuf)
        ]))
        guard let depthBuf = da2Out.featureValue(for: "depth")?.imageBufferValue else {
            throw InferenceError.outputMissing("depth")
        }

        let rgbArray   = try image.toMLMultiArray(height: Self.dpfHeight, width: Self.dpfWidth)
        let depthArray = try depthBufferToMLArray(depthBuf, height: Self.dpfHeight, width: Self.dpfWidth)
        let dpfOut = try await models.nutrition.prediction(from: MLDictionaryFeatureProvider(dictionary: [
            "rgb":   MLFeatureValue(multiArray: rgbArray),
            "depth": MLFeatureValue(multiArray: depthArray)
        ]))
        guard let nutrition = dpfOut.featureValue(for: "nutrition")?.multiArrayValue, nutrition.count >= 5 else {
            throw InferenceError.outputMissing("nutrition")
        }

        // [calories, mass, fat, carb, protein]
        let value = { (i: Int) in max(0, Int(nutrition[i].doubleValue.rounded())) }
        let result = NutritionPrediction(calories: value(0), massGrams: value(1), protein: value(4), carbs: value(3), fat: value(2))
        mlLog.debug("DPF output: \(result.calories) kcal, \(result.massGrams) g")
        return result
    }

    // MARK: - Model loading

    private func modelTask() -> Task<LoadedModels?, Never> {
        lock.withLock {
            if let loadingTask { return loadingTask }
            let task = Task.detached(priority: .userInitiated) { await Self.loadModels() }
            loadingTask = task
            return task
        }
    }

    /// Lets a later capture retry, e.g. after a failed first-launch compile.
    private func resetFailedLoad() {
        lock.withLock { loadingTask = nil }
    }

    private static func loadModels() async -> LoadedModels? {
        guard let modelsDir = Bundle.main.resourceURL?.appendingPathComponent("Models"),
              let cachesRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        else { return nil }
        let cacheDir = cachesRoot.appendingPathComponent("CB_Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        async let da2 = compileOrLoad(
            name: "DA2",
            source: modelsDir.appendingPathComponent("depth-anything-v2-small/DepthAnythingV2SmallF16P6.mlpackage"),
            cache: cacheDir.appendingPathComponent("DA2.mlmodelc")
        )
        async let dpf = compileOrLoad(
            name: "DPF",
            source: modelsDir.appendingPathComponent("DPFNutritionRGBDepth.mlpackage"),
            cache: cacheDir.appendingPathComponent("DPF.mlmodelc")
        )
        guard let d = await da2, let n = await dpf else {
            mlLog.error("Models unavailable")
            return nil
        }
        return LoadedModels(depth: d, nutrition: n)
    }

    private static func compileOrLoad(name: String, source: URL, cache: URL) async -> MLModel? {
        let fm = FileManager.default
        if fm.fileExists(atPath: cache.path) {
            if let model = try? MLModel(contentsOf: cache) { return model }
            try? fm.removeItem(at: cache)
        }
        guard fm.fileExists(atPath: source.path) else {
            mlLog.error("\(name, privacy: .public) not bundled at \(source.path, privacy: .public)")
            return nil
        }
        do {
            let compiled = try await MLModel.compileModel(at: source)
            if (try? fm.copyItem(at: compiled, to: cache)) != nil, let model = try? MLModel(contentsOf: cache) {
                return model
            }
            return try MLModel(contentsOf: compiled)
        } catch {
            mlLog.error("\(name, privacy: .public) failed to load: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}

enum InferenceError: Error {
    case preprocessingFailed
    case outputMissing(String)
}
