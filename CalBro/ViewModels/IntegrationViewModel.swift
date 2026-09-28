import Foundation

/// App-wide coordinator for Apple Health and notifications. Reacts to meal and profile changes.
@MainActor
@Observable
final class IntegrationViewModel {
    static let shared = IntegrationViewModel()

    private(set) var health: HealthSettings
    private(set) var reminders: ReminderSettings
    private(set) var todayActiveEnergy: Int?
    private(set) var lastHealthImport: Date?
    private(set) var healthError: String?
    private(set) var notificationPermission: NotificationPermission = .unknown
    private(set) var isWorking = false

    var isHealthAvailable: Bool { healthProvider.isAvailable }

    private let healthProvider: HealthDataProviding
    private let notifications: NotificationScheduling
    private let profileStore: ProfileStore
    private let mealStore: MealLogStore
    private let defaults: UserDefaults

    private static let settingsKey = "calbro.integrations.v2"
    private static let warningDayKey = "calbro.reminder.calorieWarning.lastDay"

    private struct PersistedState: Codable {
        var health: HealthSettings
        var reminders: ReminderSettings
    }

    init(
        healthProvider: HealthDataProviding = HealthKitService(),
        notifications: NotificationScheduling = UserNotificationScheduler(),
        profileStore: ProfileStore = .shared,
        mealStore: MealLogStore = .shared,
        defaults: UserDefaults = .standard
    ) {
        self.healthProvider = healthProvider
        self.notifications = notifications
        self.profileStore = profileStore
        self.mealStore = mealStore
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.settingsKey),
           let state = try? JSONDecoder().decode(PersistedState.self, from: data) {
            health = state.health
            reminders = state.reminders
        } else {
            health = HealthSettings()
            reminders = ReminderSettings()
        }
    }

    /// Hooks the stores up to this coordinator. Called once at launch.
    func connect() {
        mealStore.todayCalorieTarget = { [weak self] in
            guard let self else { return 0 }
            return self.calorieTarget(on: Date())
        }
        mealStore.onChange = { [weak self] change in
            Task { await self?.mealsDidChange(change) }
        }
        profileStore.onProfileChange = { [weak self] _ in
            self?.mealStore.syncWidget()
        }
    }

    // MARK: - Calorie budget

    /// Today's target, with the activity-multiplier allowance swapped for measured active energy.
    /// A calibrated TDEE already reflects real activity, so it's left alone.
    func calorieTarget(on date: Date) -> Int {
        let profile = profileStore.profile
        guard health.useActiveEnergy, profile.calibration == nil,
              Calendar.current.isDateInToday(date), let active = todayActiveEnergy
        else { return profile.calorieTarget }
        return max(1000, profile.calorieTarget - profile.activityAllowance + active)
    }

    // MARK: - Lifecycle

    /// Runs when the app becomes active or the day changes.
    func refresh() async {
        notificationPermission = await notifications.permission()
        if health.readBody { await importBodyData() }
        if health.useActiveEnergy { todayActiveEnergy = await healthProvider.activeEnergyToday() }
        profileStore.recalibrateIfDue(intakeByDay: mealStore.intakeByDay)
        mealStore.syncWidget()
        await rescheduleMealReminders()
    }

    // MARK: - Health toggles

    func setReadBody(_ on: Bool) async {
        await changeHealth { $0.readBody = on }
        if on && healthError == nil { await importBodyData() }
    }

    func setUseActiveEnergy(_ on: Bool) async {
        await changeHealth { $0.useActiveEnergy = on }
        todayActiveEnergy = on && healthError == nil ? await healthProvider.activeEnergyToday() : nil
        mealStore.syncWidget()
    }

    func setWriteMeals(_ on: Bool) async {
        await changeHealth { $0.writeMeals = on }
        guard on, healthError == nil else { return }
        // Backfill today so the day is complete in Health.
        for meal in mealStore.mealsForToday() {
            try? await healthProvider.saveMeal(meal)
        }
    }

    func importBodyData() async {
        let metrics = await healthProvider.bodyMetrics()
        let history = await healthProvider.weightHistory(days: 120)
        if !history.isEmpty { profileStore.replaceHealthWeights(history) }
        var p = profileStore.profile
        if let cm = metrics.heightCentimeters { p.heightCentimeters = Int(cm.rounded()) }
        if let age = metrics.age { p.age = age }
        if let sex = metrics.sex { p.sex = sex }
        if history.isEmpty, let kg = metrics.weightKilograms { p.weightKilograms = kg }
        if p != profileStore.profile { profileStore.update(p) }
        lastHealthImport = Date()
    }

    /// Applies the change right away so the switch moves on tap; reverts if authorization fails.
    private func changeHealth(_ edit: (inout HealthSettings) -> Void) async {
        let previous = health
        var next = health
        edit(&next)
        healthError = nil
        let turningOn = next.readBody && !previous.readBody
            || next.useActiveEnergy && !previous.useActiveEnergy
            || next.writeMeals && !previous.writeMeals
        health = next
        if turningOn {
            guard healthProvider.isAvailable else {
                health = previous
                healthError = String(localized: "Apple Health isn't available on this device.")
                return
            }
            isWorking = true
            defer { isWorking = false }
            do {
                try await healthProvider.requestAuthorization(for: next)
            } catch {
                health = previous
                healthError = String(localized: "Apple Health access wasn't granted.")
                return
            }
        }
        persist()
    }

    // MARK: - Reminders

    func setMealReminder(_ on: Bool) async {
        reminders.mealReminderEnabled = on
        if on, !(await notifications.requestPermission()) {
            reminders.mealReminderEnabled = false
            notificationPermission = .denied
            return
        }
        notificationPermission = await notifications.permission()
        persist()
        await rescheduleMealReminders()
    }

    func setMealReminderTime(_ date: Date) async {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        reminders.mealReminderHour = comps.hour ?? 12
        reminders.mealReminderMinute = comps.minute ?? 0
        persist()
        await rescheduleMealReminders()
    }

    var mealReminderTime: Date {
        Calendar.current.date(bySettingHour: reminders.mealReminderHour, minute: reminders.mealReminderMinute,
                              second: 0, of: Date()) ?? Date()
    }

    func setCalorieWarning(_ on: Bool) async {
        reminders.calorieWarningEnabled = on
        if on, !(await notifications.requestPermission()) {
            reminders.calorieWarningEnabled = false
            notificationPermission = .denied
            return
        }
        notificationPermission = await notifications.permission()
        persist()
    }

    private func rescheduleMealReminders() async {
        guard reminders.mealReminderEnabled else {
            await notifications.cancelMealReminders()
            return
        }
        await notifications.scheduleMealReminders(
            hour: reminders.mealReminderHour, minute: reminders.mealReminderMinute,
            skipToday: !mealStore.mealsForToday().isEmpty
        )
    }

    /// Fires once per day when today's intake first reaches 90 % of the target.
    private func evaluateCalorieWarning() async {
        guard reminders.calorieWarningEnabled else { return }
        let consumed = mealStore.totalsForToday().calories
        let target = calorieTarget(on: Date())
        guard target > 0, Double(consumed) >= Double(target) * 0.9 else { return }
        let today = Calendar.current.startOfDay(for: Date())
        if let last = defaults.object(forKey: Self.warningDayKey) as? Date,
           Calendar.current.isDate(last, inSameDayAs: today) { return }
        defaults.set(today, forKey: Self.warningDayKey)
        await notifications.postCalorieWarning(consumed: consumed, target: target)
    }

    // MARK: - Meal changes

    private func mealsDidChange(_ change: MealLogStore.Change) async {
        if health.writeMeals {
            switch change {
            case .added(let meal), .updated(let meal): try? await healthProvider.saveMeal(meal)
            case .removed(let meal):                   try? await healthProvider.deleteMeal(id: meal.id)
            }
        }
        await rescheduleMealReminders()
        await evaluateCalorieWarning()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(PersistedState(health: health, reminders: reminders)) else { return }
        defaults.set(data, forKey: Self.settingsKey)
    }
}
