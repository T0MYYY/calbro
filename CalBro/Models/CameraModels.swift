import Foundation

/// Live framing state used to gate auto-capture and passed along with each photo.
struct CaptureGuidance: Equatable, Sendable {
    /// Degrees away from pointing straight down (0 = overhead).
    var tiltDegrees: Double
    /// Distance to the food in cm from LiDAR / depth; nil on devices without depth.
    var heightCm: Double?

    static let overheadThreshold: Double = 28
    /// Matches the camera-to-plate distance of the DPF training data.
    static let heightRange: ClosedRange<Double> = 27...34

    var isOverhead: Bool { tiltDegrees < Self.overheadThreshold }

    var isHeightInRange: Bool {
        guard let heightCm else { return true }
        return Self.heightRange.contains(heightCm)
    }

    var isReady: Bool { isOverhead && isHeightInRange }
}

enum RecognitionSource: Equatable {
    case onDevice
    case simulatorSample

    var title: String {
        switch self {
        case .onDevice:        String(localized: "On-device estimate")
        case .simulatorSample: String(localized: "Simulator sample")
        }
    }
}

struct FoodRecognitionResult: Identifiable, Equatable {
    let id = UUID()
    let foodName: String
    let massGrams: Int?
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    var source: RecognitionSource = .onDevice

    var servingDescription: String {
        if let massGrams {
            String(localized: "About \(NutritionFormat.grams(massGrams))", comment: "Estimated portion mass")
        } else {
            String(localized: "Estimated portion")
        }
    }
}
