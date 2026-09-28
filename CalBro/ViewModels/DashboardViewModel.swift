import Foundation

struct WeekDay: Identifiable, Equatable {
    let date: Date
    let symbol: String
    let dayNumber: Int
    let status: DayStatus
    let isFuture: Bool
    let isToday: Bool

    var id: Date { date }
}

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var selectedDate: Date

    private let mealStore: MealLogStore
    private let profileStore: ProfileStore
    private let integrations: IntegrationViewModel
    private let calendar = Calendar.current

    init(mealStore: MealLogStore = .shared, profileStore: ProfileStore = .shared,
         integrations: IntegrationViewModel = .shared) {
        self.mealStore = mealStore
        self.profileStore = profileStore
        self.integrations = integrations
        self.selectedDate = Calendar.current.startOfDay(for: Date())
    }

    var isShowingToday: Bool { calendar.isDateInToday(selectedDate) }

    // MARK: - Selected day

    var calorieTarget: Int { integrations.calorieTarget(on: selectedDate) }

    var nutrition: DailyNutrition {
        let p = profileStore.profile
        return DailyNutrition(
            totals: mealStore.totals(on: selectedDate),
            calorieTarget: calorieTarget,
            proteinTarget: p.proteinTargetG, carbTarget: p.carbTargetG, fatTarget: p.fatTargetG
        )
    }

    var meals: [LoggedMeal] { mealStore.meals(on: selectedDate) }

    /// Extra budget from Apple Health active energy, when that's in use today.
    var activeEnergyBonus: Int? {
        guard isShowingToday else { return nil }
        let delta = calorieTarget - profileStore.profile.calorieTarget
        return delta != 0 ? integrations.todayActiveEnergy : nil
    }

    var selectedDayTitle: String {
        if isShowingToday { return String(localized: "Today") }
        if calendar.isDateInYesterday(selectedDate) { return String(localized: "Yesterday") }
        return selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    // MARK: - Week strip

    var monthLabel: String {
        selectedDate.formatted(.dateTime.month(.wide).year())
    }

    var streakLabel: String {
        let s = mealStore.streak()
        if s == 0 { return String(localized: "Log a meal to start a streak") }
        return String(localized: "\(s)-day streak")
    }

    /// The calendar week containing the selected day, starting on the locale's first weekday.
    var week: [WeekDay] {
        let today = calendar.startOfDay(for: Date())
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let target = profileStore.profile.calorieTarget
        return (0..<7).map { i in
            let d = start.adding(days: i, calendar: calendar)
            return WeekDay(
                date: d,
                symbol: symbols[(calendar.component(.weekday, from: d) - 1) % symbols.count],
                dayNumber: calendar.component(.day, from: d),
                status: mealStore.status(on: d, target: calendar.isDateInToday(d) ? calorieTarget : target),
                isFuture: d > today,
                isToday: calendar.isDate(d, inSameDayAs: today)
            )
        }
    }

    func select(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        guard day <= calendar.startOfDay(for: Date()) else { return }
        selectedDate = day
    }

    func selectToday() { selectedDate = calendar.startOfDay(for: Date()) }
}
