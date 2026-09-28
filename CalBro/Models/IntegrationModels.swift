import Foundation

/// What CalBro exchanges with Apple Health. Each is off until the user turns it on.
struct HealthSettings: Equatable, Codable {
    /// Import weight, height, age and sex into the profile, plus weight history.
    var readBody = false
    /// Replace the activity-multiplier allowance with today's measured active energy.
    var useActiveEnergy = false
    /// Save each logged meal's energy and macros to Health.
    var writeMeals = false

    var anyEnabled: Bool { readBody || useActiveEnergy || writeMeals }
}

struct ReminderSettings: Equatable, Codable {
    var mealReminderEnabled = false
    var mealReminderHour = 12
    var mealReminderMinute = 0
    var calorieWarningEnabled = false
}

enum NotificationPermission: Equatable {
    case unknown, allowed, denied
}
