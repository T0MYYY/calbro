import Foundation

struct NutritionPrediction: Equatable, Sendable {
    var calories: Int
    var massGrams: Int
    var protein: Int
    var carbs: Int
    var fat: Int
}

enum NutritionPredictionError: LocalizedError, Equatable {
    case noPhoto
    case modelUnavailable
    case inferenceFailed
    case nothingDetected

    var errorDescription: String? {
        switch self {
        case .noPhoto:          String(localized: "The photo couldn't be captured. Try again.")
        case .modelUnavailable: String(localized: "The nutrition model isn't installed in this build.")
        case .inferenceFailed:  String(localized: "The estimate failed on this photo. Try again from straight above.")
        case .nothingDetected:  String(localized: "No food was recognized. Center the plate and try again.")
        }
    }
}
