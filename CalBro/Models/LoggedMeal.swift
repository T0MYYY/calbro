import Foundation

struct LoggedMeal: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let timestamp: Date
    let calories: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
    var servingMultiplier: Double

    var adjustedCalories: Int { scaled(calories) }
    var adjustedProtein: Int  { scaled(proteinG) }
    var adjustedCarbs: Int    { scaled(carbsG) }
    var adjustedFat: Int      { scaled(fatG) }

    var timeLabel: String { timestamp.formatted(date: .omitted, time: .shortened) }

    private func scaled(_ value: Int) -> Int { Int((Double(value) * servingMultiplier).rounded()) }
}

struct DayTotals: Equatable {
    var calories = 0
    var protein = 0
    var carbs = 0
    var fat = 0
    var mealCount = 0

    mutating func add(_ meal: LoggedMeal) {
        calories += meal.adjustedCalories
        protein += meal.adjustedProtein
        carbs += meal.adjustedCarbs
        fat += meal.adjustedFat
        mealCount += 1
    }
}

/// How a logged day compares with the calorie target.
enum DayStatus: Equatable {
    case noLog, under, onTarget, over

    /// Within 80–110 % of target counts as on target.
    init(consumed: Int, target: Int, logged: Bool) {
        guard logged else { self = .noLog; return }
        let t = Double(max(target, 1))
        if Double(consumed) > t * 1.10 { self = .over }
        else if Double(consumed) >= t * 0.80 { self = .onTarget }
        else { self = .under }
    }

    var colorKey: NutritionColorKey? {
        switch self {
        case .noLog:    nil
        case .under:    .gold
        case .onTarget: .sage
        case .over:     .terra
        }
    }

    var title: String {
        switch self {
        case .noLog:    String(localized: "No log")
        case .under:    String(localized: "Under")
        case .onTarget: String(localized: "On target")
        case .over:     String(localized: "Over")
        }
    }
}
