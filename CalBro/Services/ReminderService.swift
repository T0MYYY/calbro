import Foundation
import UserNotifications

protocol NotificationScheduling: Sendable {
    func permission() async -> NotificationPermission
    func requestPermission() async -> Bool
    /// Replaces all pending meal reminders with one per day for the next week.
    func scheduleMealReminders(hour: Int, minute: Int, skipToday: Bool) async
    func cancelMealReminders() async
    func postCalorieWarning(consumed: Int, target: Int) async
}

final class UserNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private let center = UNUserNotificationCenter.current()
    private static let mealPrefix = "calbro.reminder.meal."
    /// Identifier used by the old repeating reminder; removed on reschedule.
    private static let legacyMealID = "calbro.reminder.mealLogging"
    private static let warningID = "calbro.reminder.calorieWarning"

    func permission() async -> NotificationPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .allowed
        case .denied: .denied
        default: .unknown
        }
    }

    func requestPermission() async -> Bool {
        switch await permission() {
        case .allowed: return true
        case .denied:  return false
        case .unknown: return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    func scheduleMealReminders(hour: Int, minute: Int, skipToday: Bool) async {
        await cancelMealReminders()
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        for offset in 0..<7 {
            if offset == 0 && skipToday { continue }
            let day = today.adding(days: offset, calendar: calendar)
            guard let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fire > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "Log your meals")
            content.body = String(localized: "You haven't logged anything today. Snap your next meal to keep your streak.")
            content.sound = .default
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let request = UNNotificationRequest(
                identifier: Self.mealPrefix + String(offset),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            try? await center.add(request)
        }
    }

    func cancelMealReminders() async {
        let ids = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix(Self.mealPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids + [Self.legacyMealID])
    }

    func postCalorieWarning(consumed: Int, target: Int) async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Calorie budget almost reached")
        let share = NutritionFormat.percent(Double(consumed) / Double(max(target, 1)))
        content.body = String(localized: "You've had \(NutritionFormat.kcal(consumed)) of \(NutritionFormat.kcal(target)) today (\(share)).")
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: Self.warningID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await center.add(request)
    }
}
