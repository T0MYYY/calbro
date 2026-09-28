import Foundation
import WidgetKit

/// App Group shared between the main app and the widget extension.
enum AppGroup {
    static let id = "group.com.wydfcc.calbro"
    static var defaults: UserDefaults { UserDefaults(suiteName: id) ?? .standard }
}

/// Today's nutrition snapshot written by the app, read by the widget.
struct WidgetNutritionSnapshot: Codable, Equatable {
    var date: Date
    var caloriesConsumed: Int
    var calorieTarget: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var proteinTarget: Int
    var carbTarget: Int
    var fatTarget: Int

    var remaining: Int { max(0, calorieTarget - caloriesConsumed) }
    var over: Int { max(0, caloriesConsumed - calorieTarget) }
    var progress: Double {
        calorieTarget > 0 ? min(1, Double(caloriesConsumed) / Double(calorieTarget)) : 0
    }

    static let placeholder = WidgetNutritionSnapshot(
        date: Date(), caloriesConsumed: 1240, calorieTarget: 1820,
        protein: 82, carbs: 148, fat: 38,
        proteinTarget: 150, carbTarget: 180, fatTarget: 60
    )

    static func empty(date: Date = Date()) -> WidgetNutritionSnapshot {
        WidgetNutritionSnapshot(
            date: date, caloriesConsumed: 0, calorieTarget: 1820,
            protein: 0, carbs: 0, fat: 0,
            proteinTarget: 150, carbTarget: 180, fatTarget: 60
        )
    }

    /// Same targets with nothing eaten yet — what the widget shows after midnight.
    func startingDay(_ date: Date) -> WidgetNutritionSnapshot {
        var copy = self
        copy.date = date
        copy.caloriesConsumed = 0
        copy.protein = 0
        copy.carbs = 0
        copy.fat = 0
        return copy
    }
}

/// Bridges nutrition data into the App Group container and refreshes widget timelines.
enum SharedNutritionStore {
    private static let key = "widget.today.v1"

    static func save(_ snapshot: WidgetNutritionSnapshot) {
        guard stored() != snapshot,
              let data = try? JSONEncoder().encode(snapshot) else { return }
        AppGroup.defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Snapshot for `date`. A snapshot from an earlier day keeps its targets but zero intake.
    static func load(for date: Date = Date()) -> WidgetNutritionSnapshot {
        guard let snapshot = stored() else { return .empty(date: date) }
        if Calendar.current.isDate(snapshot.date, inSameDayAs: date) { return snapshot }
        return snapshot.startingDay(date)
    }

    private static func stored() -> WidgetNutritionSnapshot? {
        guard let data = AppGroup.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetNutritionSnapshot.self, from: data)
    }
}
