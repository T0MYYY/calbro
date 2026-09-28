import Foundation

protocol FoodRecognitionService: Sendable {
    func warmUp()
    func recognizeFood(from imageData: Data?, guidance: CaptureGuidance) async throws -> FoodRecognitionResult
}

/// The simulator has no camera or Neural Engine; this returns a fixed, clearly labeled sample
/// so the result flow can be exercised during development.
final class SimulatorSampleRecognitionService: FoodRecognitionService {
    func warmUp() {}

    func recognizeFood(from imageData: Data?, guidance: CaptureGuidance) async throws -> FoodRecognitionResult {
        try await Task.sleep(for: .milliseconds(400))
        return FoodRecognitionResult(
            foodName: String(localized: "Sample meal"),
            massGrams: 320, calories: 520, protein: 32, carbs: 68, fat: 14,
            source: .simulatorSample
        )
    }
}

final class DPFFoodRecognitionService: FoodRecognitionService {
    private let prediction: NutritionPredictionService

    init(prediction: NutritionPredictionService = CoreMLNutritionPredictionService.shared) {
        self.prediction = prediction
    }

    func warmUp() { prediction.warmUp() }

    func recognizeFood(from imageData: Data?, guidance: CaptureGuidance) async throws -> FoodRecognitionResult {
        guard let imageData else { throw NutritionPredictionError.noPhoto }
        let p = try await prediction.predictNutrition(from: imageData, guidance: guidance)
        return FoodRecognitionResult(
            foodName: String(localized: "Scanned meal"),
            massGrams: p.massGrams,
            calories: p.calories, protein: p.protein, carbs: p.carbs, fat: p.fat,
            source: .onDevice
        )
    }
}
