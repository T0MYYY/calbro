import Foundation

@Observable
@MainActor
final class MealLogStore {
    static let shared = MealLogStore()

    enum Change {
        case added(LoggedMeal)
        case updated(LoggedMeal)
        case removed(LoggedMeal)
    }

    /// About 13 months, so the calendar and calibration never lose recent history.
    static let retentionDays = 400

    private(set) var meals: [LoggedMeal] = []
    /// Totals per start-of-day, rebuilt whenever `meals` changes.
    private(set) var totalsByDay: [Date: DayTotals] = [:]

    /// Health write-back, reminders and alerts hook in here.
    @ObservationIgnored var onChange: ((Change) -> Void)?
    /// Today's budget; replaced by the integration layer when active energy is synced.
    @ObservationIgnored var todayCalorieTarget: () -> Int

    private let profileStore: ProfileStore
    private let defaults: UserDefaults
    private let syncsWidget: Bool
    private let calendar = Calendar.current
    private static let key = "calbro.meals.v1"

    init(profileStore: ProfileStore = .shared, defaults: UserDefaults = .standard, syncsWidget: Bool = true) {
        self.profileStore = profileStore
        self.defaults = defaults
        self.syncsWidget = syncsWidget
        self.todayCalorieTarget = { profileStore.profile.calorieTarget }
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([LoggedMeal].self, from: data) {
            meals = saved.sorted { $0.timestamp < $1.timestamp }
        }
        rebuildIndex()
    }

    // MARK: - Mutations

    func log(_ meal: LoggedMeal) {
        meals.append(meal)
        meals.sort { $0.timestamp < $1.timestamp }
        didMutate(.added(meal))
    }

    func update(_ meal: LoggedMeal) {
        guard let i = meals.firstIndex(where: { $0.id == meal.id }) else { return }
        meals[i] = meal
        didMutate(.updated(meal))
    }

    func remove(id: UUID) {
        guard let i = meals.firstIndex(where: { $0.id == id }) else { return }
        let removed = meals.remove(at: i)
        didMutate(.removed(removed))
    }

    // MARK: - Queries

    func meals(on date: Date) -> [LoggedMeal] {
        meals.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }

    func mealsForToday() -> [LoggedMeal] { meals(on: Date()) }

    func totals(on date: Date) -> DayTotals {
        totalsByDay[calendar.startOfDay(for: date)] ?? DayTotals()
    }

    func totalsForToday() -> DayTotals { totals(on: Date()) }

    func isLogged(_ date: Date) -> Bool { totals(on: date).mealCount > 0 }

    func status(on date: Date, target: Int) -> DayStatus {
        let t = totals(on: date)
        return DayStatus(consumed: t.calories, target: target, logged: t.mealCount > 0)
    }

    var intakeByDay: [Date: Int] { totalsByDay.mapValues(\.calories) }

    var firstLoggedDay: Date? { meals.first.map { calendar.startOfDay(for: $0.timestamp) } }

    /// Consecutive logged days ending today — or yesterday, since today may not be logged yet.
    func streak(asOf now: Date = Date()) -> Int {
        var day = calendar.startOfDay(for: now)
        if !isLogged(day) { day = day.adding(days: -1, calendar: calendar) }
        var count = 0
        while isLogged(day) {
            count += 1
            day = day.adding(days: -1, calendar: calendar)
        }
        return count
    }

    /// The last `count` days ending today, oldest first.
    func recentDays(_ count: Int, endingAt now: Date = Date()) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0..<count).map { today.adding(days: $0 - (count - 1), calendar: calendar) }
    }

    // MARK: - Widget bridge

    func syncWidget() {
        guard syncsWidget else { return }
        let totals = totalsForToday()
        let profile = profileStore.profile
        SharedNutritionStore.save(WidgetNutritionSnapshot(
            date: Date(),
            caloriesConsumed: totals.calories,
            calorieTarget: todayCalorieTarget(),
            protein: totals.protein, carbs: totals.carbs, fat: totals.fat,
            proteinTarget: profile.proteinTargetG,
            carbTarget: profile.carbTargetG,
            fatTarget: profile.fatTargetG
        ))
    }

    // MARK: - Private

    private func didMutate(_ change: Change) {
        let cutoff = Date().adding(days: -Self.retentionDays, calendar: calendar)
        meals.removeAll { $0.timestamp < cutoff }
        rebuildIndex()
        if let data = try? JSONEncoder().encode(meals) {
            defaults.set(data, forKey: Self.key)
        }
        syncWidget()
        onChange?(change)
    }

    private func rebuildIndex() {
        var index: [Date: DayTotals] = [:]
        for meal in meals {
            index[calendar.startOfDay(for: meal.timestamp), default: DayTotals()].add(meal)
        }
        totalsByDay = index
    }
}

extension Date {
    /// Day arithmetic that can't fail in practice; falls back to 24 h steps.
    func adding(days: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: self) ?? addingTimeInterval(Double(days) * 86_400)
    }
}
