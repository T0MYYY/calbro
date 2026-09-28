import Foundation

@MainActor
@Observable
final class StatsViewModel {
    private let mealStore: MealLogStore
    private let profileStore: ProfileStore
    private let calendar = Calendar.current

    init(mealStore: MealLogStore = .shared, profileStore: ProfileStore = .shared) {
        self.mealStore = mealStore
        self.profileStore = profileStore
    }

    /// Rolling window: the last seven days including today.
    var days: [Date] { mealStore.recentDays(7) }

    var rangeLabel: String {
        guard let first = days.first, let last = days.last else { return "" }
        return (first..<last)
            .formatted(.interval.month(.abbreviated).day())
    }

    private var target: Int { profileStore.profile.calorieTarget }

    private var loggedTotals: [DayTotals] {
        days.map { mealStore.totals(on: $0) }.filter { $0.mealCount > 0 }
    }

    // MARK: - Bars

    var calorieBars: [TrendBar] {
        days.map { d in
            let consumed = mealStore.totals(on: d).calories
            let symbols = calendar.veryShortStandaloneWeekdaySymbols
            return TrendBar(
                id: d,
                day: symbols[(calendar.component(.weekday, from: d) - 1) % symbols.count],
                accessibilityDay: d.formatted(.dateTime.weekday(.wide)),
                consumed: consumed,
                progress: Double(consumed) / Double(max(target, 1)),
                isToday: calendar.isDateInToday(d)
            )
        }
    }

    // MARK: - Summary metrics

    var loggedDays: Int { loggedTotals.count }

    var onTargetDays: Int {
        days.filter { mealStore.status(on: $0, target: target) == .onTarget }.count
    }

    /// Average over logged days only, so unlogged days don't drag it toward zero.
    var averageCalories: Int {
        let logged = loggedTotals
        guard !logged.isEmpty else { return 0 }
        return logged.map(\.calories).reduce(0, +) / logged.count
    }

    var weeklyMacros: [Macro] {
        let logged = loggedTotals
        let n = max(logged.count, 1)
        let p = profileStore.profile
        let avg = { (kp: KeyPath<DayTotals, Int>) in logged.map { $0[keyPath: kp] }.reduce(0, +) / n }
        let row = { (id: String, label: String, value: Int, target: Int, color: NutritionColorKey) in
            Macro(id: id, label: label,
                  value: String(localized: "\(NutritionFormat.grams(value)) of \(NutritionFormat.grams(target))",
                                comment: "Average grams per logged day compared with the daily target"),
                  progress: Double(value) / Double(max(1, target)), colorKey: color)
        }
        return [
            row("protein", String(localized: "Protein"), avg(\.protein), p.proteinTargetG, .plum),
            row("carbs", String(localized: "Carbs"), avg(\.carbs), p.carbTargetG, .ocean),
            row("fat", String(localized: "Fat"), avg(\.fat), p.fatTargetG, .gold)
        ]
    }

    var streak: Int { mealStore.streak() }

    var calorieTargetLabel: String { NutritionFormat.kcal(target) }

    /// Logged day with intake closest to the target.
    var bestDayLabel: String? {
        let best = days
            .map { ($0, mealStore.totals(on: $0)) }
            .filter { $0.1.mealCount > 0 }
            .min { abs($0.1.calories - target) < abs($1.1.calories - target) }
        return best?.0.formatted(.dateTime.weekday(.wide))
    }

    /// Most frequently logged meal name in the window.
    var mostLoggedFood: String? {
        guard let start = days.first else { return nil }
        let recent = mealStore.meals.filter { $0.timestamp >= start }
        let counts = Dictionary(grouping: recent, by: \.name).mapValues(\.count)
        return counts.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key
    }
}
