import Foundation

// Raw values are persisted — never change them. User-facing text comes from `title`.

enum FitnessGoal: String, CaseIterable, Identifiable, Codable {
    case loseFat         = "Lose fat\n& tone"
    case buildMuscle     = "Build\nmuscle"
    case gainWeight      = "Gain\nweight"
    case maintain        = "Maintain\nweight"
    case betterNutrition = "Better\nnutrition"
    case healthCondition = "Health\ncondition"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loseFat:         String(localized: "Lose fat & tone")
        case .buildMuscle:     String(localized: "Build muscle")
        case .gainWeight:      String(localized: "Gain weight")
        case .maintain:        String(localized: "Maintain weight")
        case .betterNutrition: String(localized: "Better nutrition")
        case .healthCondition: String(localized: "Health condition")
        }
    }

    /// kcal delta applied to TDEE
    var dailyAdjustment: Int {
        switch self {
        case .loseFat:         -500
        case .buildMuscle:      300
        case .gainWeight:       500
        case .maintain:           0
        case .betterNutrition:    0
        case .healthCondition: -200
        }
    }
}

enum BiologicalSex: String, CaseIterable, Identifiable, Codable {
    case male   = "Male"
    case female = "Female"
    case other  = "Other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male:   String(localized: "Male")
        case .female: String(localized: "Female")
        case .other:  String(localized: "Other", comment: "Biological sex option")
        }
    }
}

enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    case sedentary        = "Sedentary"
    case lightlyActive    = "Lightly active"
    case moderatelyActive = "Moderately active"
    case veryActive       = "Very active"
    case athlete          = "Athlete"

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .sedentary:        1.200
        case .lightlyActive:    1.375
        case .moderatelyActive: 1.550
        case .veryActive:       1.725
        case .athlete:          1.900
        }
    }

    var multiplierLabel: String {
        "×" + multiplier.formatted(.number.precision(.fractionLength(1...3)))
    }

    var title: String {
        switch self {
        case .sedentary:        String(localized: "Sedentary")
        case .lightlyActive:    String(localized: "Lightly active")
        case .moderatelyActive: String(localized: "Moderately active")
        case .veryActive:       String(localized: "Very active")
        case .athlete:          String(localized: "Athlete")
        }
    }

    var subtitle: String {
        switch self {
        case .sedentary:        String(localized: "Desk job, little exercise")
        case .lightlyActive:    String(localized: "1–3 workouts a week")
        case .moderatelyActive: String(localized: "3–5 workouts a week")
        case .veryActive:       String(localized: "6–7 hard workouts a week")
        case .athlete:          String(localized: "Training twice a day or a physical job")
        }
    }
}

enum DietPreference: String, CaseIterable, Identifiable, Codable {
    case noRestriction = "No restriction"
    case vegetarian    = "Vegetarian"
    case vegan         = "Vegan"
    case lowCarb       = "Low-carb"
    case keto          = "Keto"
    case highProtein   = "High-protein"
    case glutenFree    = "Gluten-free"
    case dairyFree     = "Dairy-free"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noRestriction: String(localized: "No restriction")
        case .vegetarian:    String(localized: "Vegetarian")
        case .vegan:         String(localized: "Vegan")
        case .lowCarb:       String(localized: "Low-carb")
        case .keto:          String(localized: "Keto")
        case .highProtein:   String(localized: "High-protein")
        case .glutenFree:    String(localized: "Gluten-free")
        case .dairyFree:     String(localized: "Dairy-free")
        }
    }
}

enum UnitSystem: String, CaseIterable, Identifiable, Codable {
    case metric   = "Metric"
    case imperial = "Imperial"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .metric:   String(localized: "Metric")
        case .imperial: String(localized: "Imperial")
        }
    }
}

/// A maintenance estimate derived from logged intake and weight change.
struct TDEECalibration: Equatable, Codable {
    var tdee: Int
    var date: Date
}

struct UserProfile: Equatable, Codable {
    var goal: FitnessGoal      = .loseFat
    var sex: BiologicalSex     = .male
    var age: Int               = 28
    var heightCentimeters: Int = 172
    var weightKilograms: Double = 74
    var activityLevel: ActivityLevel = .lightlyActive
    var dietPreferences: Set<DietPreference> = [.noRestriction]
    /// Display preference for height & weight. Calories are always shown in kcal.
    var units: UnitSystem = .metric
    var targetWeightKilograms: Double?
    var calibration: TDEECalibration?

    // Stored after target computation
    var calorieTarget:  Int = 1820
    var proteinTargetG: Int = 150
    var carbTargetG:    Int = 180
    var fatTargetG:     Int = 60

    // MARK: - Energy

    /// Mifflin-St Jeor
    var bmr: Int {
        let base = 10 * weightKilograms + 6.25 * Double(heightCentimeters) - 5 * Double(age)
        switch sex {
        case .male:   return Int((base + 5).rounded())
        case .female: return Int((base - 161).rounded())
        case .other:  return Int((base - 78).rounded())
        }
    }

    /// Formula estimate from BMR × activity multiplier.
    var formulaTDEE: Int { Int((Double(bmr) * activityLevel.multiplier).rounded()) }

    /// Maintenance calories actually used for targets: the calibrated value when available.
    var tdee: Int { calibration?.tdee ?? formulaTDEE }

    /// The part of TDEE that comes from the activity multiplier (formula only).
    var activityAllowance: Int { formulaTDEE - bmr }

    var weeklyWeightChangeKg: Double {
        Double(goal.dailyAdjustment) * 7 / WeightMath.kcalPerKg
    }

    mutating func recalculateTargets() {
        calorieTarget = max(1000, tdee + goal.dailyAdjustment)
        let kcal = Double(calorieTarget)

        var proteinPerKg: Double
        var fatShare: Double
        switch goal {
        case .loseFat:     proteinPerKg = 2.2; fatShare = 0.25
        case .buildMuscle: proteinPerKg = 2.0; fatShare = 0.28
        case .gainWeight:  proteinPerKg = 1.8; fatShare = 0.30
        default:           proteinPerKg = 1.6; fatShare = 0.30
        }
        if dietPreferences.contains(.highProtein) { proteinPerKg += 0.4 }
        if dietPreferences.contains(.lowCarb) { fatShare = max(fatShare, 0.40) }
        if dietPreferences.contains(.keto) { fatShare = max(fatShare, 0.70) }

        proteinTargetG = max(40, Int((weightKilograms * proteinPerKg).rounded()))
        fatTargetG     = max(20, Int((kcal * fatShare / 9).rounded()))
        let remainingKcal = kcal - Double(proteinTargetG) * 4 - Double(fatTargetG) * 9
        carbTargetG = max(20, Int((remainingKcal / 4).rounded()))
        if dietPreferences.contains(.keto) { carbTargetG = min(carbTargetG, 30) }
    }
}

// MARK: - Units

enum WeightMath {
    static let kcalPerKg = 7700.0
    static let poundsPerKg = 2.20462
    static let cmPerInch = 2.54
}

extension UserProfile {
    var heightDisplay: String { Self.heightString(centimeters: heightCentimeters, units: units) }
    var weightDisplay: String { Self.weightString(kilograms: weightKilograms, units: units) }

    static func heightString(centimeters: Int, units: UnitSystem) -> String {
        switch units {
        case .metric:
            return Measurement(value: Double(centimeters), unit: UnitLength.centimeters)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided))
        case .imperial:
            let totalInches = Int((Double(centimeters) / WeightMath.cmPerInch).rounded())
            return String(localized: "\(totalInches / 12) ft \(totalInches % 12) in",
                          comment: "Height in feet and inches, e.g. “5 ft 9 in”")
        }
    }

    static func weightString(kilograms: Double, units: UnitSystem, fractionDigits: Int = 0) -> String {
        let measurement = units == .metric
            ? Measurement(value: kilograms, unit: UnitMass.kilograms)
            : Measurement(value: kilograms * WeightMath.poundsPerKg, unit: UnitMass.pounds)
        return measurement.formatted(.measurement(
            width: .abbreviated, usage: .asProvided,
            numberFormatStyle: .number.precision(.fractionLength(0...fractionDigits))
        ))
    }

    /// Weekly rate in the user's unit, e.g. “0.5 kg/week”.
    func weightRateDisplay(kgPerWeek: Double) -> String {
        let value = units == .metric ? kgPerWeek : kgPerWeek * WeightMath.poundsPerKg
        let number = value.formatted(.number.precision(.fractionLength(1)))
        switch units {
        case .metric:   return String(localized: "\(number) kg/week")
        case .imperial: return String(localized: "\(number) lb/week")
        }
    }

    /// Weight in the display unit, rounded to whole units (for steppers and fields).
    func weightInDisplayUnit(_ kilograms: Double) -> Int {
        Int((units == .metric ? kilograms : kilograms * WeightMath.poundsPerKg).rounded())
    }

    func kilograms(fromDisplayUnit value: Double) -> Double {
        units == .metric ? value : value / WeightMath.poundsPerKg
    }

    var weightUnitSymbol: String {
        units == .metric ? String(localized: "kg") : String(localized: "lb")
    }
}
