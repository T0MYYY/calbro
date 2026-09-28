import Foundation

struct Macro: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let progress: Double
    let colorKey: NutritionColorKey
}

enum NutritionColorKey: String, Equatable {
    case terra
    case sage
    case ocean
    case gold
    case plum
    case ink
}

struct DailyNutrition: Equatable {
    var totals: DayTotals
    var calorieTarget: Int
    var proteinTarget: Int
    var carbTarget: Int
    var fatTarget: Int

    var caloriesConsumed: Int { totals.calories }
    var remainingCalories: Int { max(calorieTarget - caloriesConsumed, 0) }
    var overCalories: Int { max(caloriesConsumed - calorieTarget, 0) }

    var calorieProgress: Double {
        min(Double(caloriesConsumed) / Double(max(calorieTarget, 1)), 1.2)
    }

    var macros: [Macro] {
        [
            Macro(id: "protein", label: String(localized: "Protein"),
                  value: NutritionFormat.grams(totals.protein),
                  progress: Double(totals.protein) / Double(max(1, proteinTarget)), colorKey: .plum),
            Macro(id: "carbs", label: String(localized: "Carbs"),
                  value: NutritionFormat.grams(totals.carbs),
                  progress: Double(totals.carbs) / Double(max(1, carbTarget)), colorKey: .ocean),
            Macro(id: "fat", label: String(localized: "Fat"),
                  value: NutritionFormat.grams(totals.fat),
                  progress: Double(totals.fat) / Double(max(1, fatTarget)), colorKey: .gold)
        ]
    }
}
