import Foundation

/// One grid cell. `id` is the cell's position in the month grid so padding cells
/// stay stable across recomputations.
struct CalendarDayModel: Identifiable, Equatable {
    let id: Int
    let date: Date?
    let day: Int?
    let status: NutritionColorKey?
    let isToday: Bool
    let accessibilityLabel: String
}

struct MonthSummary: Equatable {
    var onTarget = 0
    var under = 0
    var over = 0
    var missed = 0
}

@MainActor
@Observable
final class CalendarViewModel {
    /// First moment of the displayed month.
    private(set) var monthAnchor: Date
    var selectedDate: Date?

    private let mealStore: MealLogStore
    private let profileStore: ProfileStore
    private let calendar = Calendar.current

    init(mealStore: MealLogStore = .shared, profileStore: ProfileStore = .shared, now: Date = Date()) {
        self.mealStore = mealStore
        self.profileStore = profileStore
        let comps = Calendar.current.dateComponents([.year, .month], from: now)
        self.monthAnchor = Calendar.current.date(from: comps) ?? now
    }

    var monthTitle: String { monthAnchor.formatted(.dateTime.month(.wide).year()) }

    var displayedMonth: Int { calendar.component(.month, from: monthAnchor) }

    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var target: Int { profileStore.profile.calorieTarget }

    /// Grid of weeks (each 7 cells) from logged meals.
    var weeks: [[CalendarDayModel]] {
        guard let range = calendar.range(of: .day, in: .month, for: monthAnchor) else { return [] }
        let leading = (calendar.component(.weekday, from: monthAnchor) - calendar.firstWeekday + 7) % 7
        var cells: [CalendarDayModel] = []
        for _ in 0..<leading { cells.append(blankCell(id: cells.count)) }
        for day in range {
            let date = monthAnchor.adding(days: day - 1, calendar: calendar)
            let status = status(on: date)
            let label = "\(date.formatted(date: .complete, time: .omitted)), \(status.title)"
            cells.append(CalendarDayModel(id: cells.count, date: date, day: day, status: status.colorKey,
                                          isToday: calendar.isDateInToday(date), accessibilityLabel: label))
        }
        while cells.count % 7 != 0 { cells.append(blankCell(id: cells.count)) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    /// Past days only; days before the first logged meal aren't counted as missed.
    var summary: MonthSummary {
        guard let range = calendar.range(of: .day, in: .month, for: monthAnchor) else { return MonthSummary() }
        let today = calendar.startOfDay(for: Date())
        let trackingStart = mealStore.firstLoggedDay ?? today
        var s = MonthSummary()
        for day in range {
            let date = monthAnchor.adding(days: day - 1, calendar: calendar)
            guard date <= today else { break }
            switch status(on: date) {
            case .onTarget: s.onTarget += 1
            case .under:    s.under += 1
            case .over:     s.over += 1
            case .noLog:    if date >= trackingStart && date < today { s.missed += 1 }
            }
        }
        return s
    }

    var selectedDayDetail: (title: String, totals: DayTotals, status: DayStatus)? {
        guard let selectedDate else { return nil }
        return (selectedDate.formatted(date: .complete, time: .omitted),
                mealStore.totals(on: selectedDate), status(on: selectedDate))
    }

    // MARK: - Actions

    func select(_ date: Date) { selectedDate = date }
    func nextMonth() { shiftMonth(by: 1) }
    func previousMonth() { shiftMonth(by: -1) }

    func handleMonthSwipe(width: Double, height: Double, startX: Double) {
        guard startX > 36 else { return }  // leave the left edge for back-swipe
        guard abs(width) > 72, abs(width) > abs(height) * 1.6 else { return }
        if width < 0 { nextMonth() } else { previousMonth() }
    }

    // MARK: - Helpers

    private func status(on date: Date) -> DayStatus {
        date > Date() ? .noLog : mealStore.status(on: date, target: target)
    }

    private func blankCell(id: Int) -> CalendarDayModel {
        CalendarDayModel(id: id, date: nil, day: nil, status: nil, isToday: false, accessibilityLabel: "")
    }

    private func shiftMonth(by amount: Int) {
        guard let next = calendar.date(byAdding: .month, value: amount, to: monthAnchor) else { return }
        monthAnchor = next
        selectedDate = nil
    }
}
