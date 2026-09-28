import XCTest
@testable import CalBro

@MainActor
final class CalBroStateTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() {
        for name in suiteNames { UserDefaults.standard.removePersistentDomain(forName: name) }
        suiteNames = []
        super.tearDown()
    }

    private func makeDefaults() -> UserDefaults {
        let name = "CalBroTests.\(UUID().uuidString)"
        suiteNames.append(name)
        return UserDefaults(suiteName: name) ?? .standard
    }

    private func makeStores() -> (ProfileStore, MealLogStore, UserDefaults) {
        let defaults = makeDefaults()
        let profiles = ProfileStore(stateStore: UserDefaultsAppStateStore(defaults: defaults), defaults: defaults)
        let meals = MealLogStore(profileStore: profiles, defaults: defaults, syncsWidget: false)
        return (profiles, meals, defaults)
    }

    private func meal(daysAgo: Int, calories: Int, name: String = "Test", now: Date = Date()) -> LoggedMeal {
        let day = Calendar.current.startOfDay(for: now).adding(days: -daysAgo).addingTimeInterval(12 * 3600)
        return LoggedMeal(id: UUID(), name: name, timestamp: day, calories: calories,
                          proteinG: 30, carbsG: 50, fatG: 10, servingMultiplier: 1)
    }

    // MARK: - Onboarding & profile

    func testOnboardingCompletesAndPersists() {
        let defaults = makeDefaults()
        let store = ProfileStore(stateStore: UserDefaultsAppStateStore(defaults: defaults), defaults: defaults)
        let model = OnboardingViewModel(profileStore: store)

        model.selectGoal(.buildMuscle)
        model.updateAge(41)
        model.updateHeight(181)
        model.updateWeight(82)
        for _ in 0..<4 { model.next() }
        XCTAssertEqual(model.step, .result)
        XCTAssertFalse(model.isComplete)
        model.next()
        XCTAssertTrue(model.isComplete)

        let restored = ProfileStore(stateStore: UserDefaultsAppStateStore(defaults: defaults), defaults: defaults)
        XCTAssertTrue(restored.onboardingComplete)
        XCTAssertEqual(restored.profile.goal, .buildMuscle)
        XCTAssertEqual(restored.profile.age, 41)
        XCTAssertEqual(restored.profile.heightCentimeters, 181)
        XCTAssertEqual(restored.profile.weightKilograms, 82, accuracy: 0.01)
        XCTAssertEqual(restored.weights.count, 1, "Onboarding weight seeds the weight log")
    }

    func testImperialOnboardingInputRoundTrips() {
        let (store, _, _) = makeStores()
        let model = OnboardingViewModel(profileStore: store)
        model.selectUnits(.imperial)
        model.updateHeight(displayValue: 69)        // 5 ft 9 in
        model.updateWeight(displayValue: 180)       // lb
        XCTAssertEqual(model.heightDisplayValue, 69)
        XCTAssertEqual(model.weightDisplayValue, 180)
        XCTAssertEqual(model.profile.weightKilograms, 81.6, accuracy: 0.1)
    }

    func testProfileEditRecordsWeighInAndNotifies() {
        let (store, _, _) = makeStores()
        store.completeOnboarding(with: UserProfile())
        var changes = 0
        store.onProfileChange = { _ in changes += 1 }
        var p = store.profile
        p.weightKilograms = 70
        store.update(p)
        XCTAssertEqual(changes, 1)
        XCTAssertEqual(store.weights.last?.kilograms ?? 0, 70, accuracy: 0.01)
    }

    func testDisplayNamesAreDecoupledFromPersistedRawValues() {
        XCTAssertEqual(FitnessGoal.loseFat.rawValue, "Lose fat\n& tone")
        XCTAssertFalse(FitnessGoal.loseFat.title.contains("\n"))
        for goal in FitnessGoal.allCases { XCTAssertFalse(goal.title.isEmpty) }
    }

    func testKetoCapsCarbs() {
        var p = UserProfile()
        p.dietPreferences = [.keto]
        p.recalculateTargets()
        XCTAssertLessThanOrEqual(p.carbTargetG, 30)
    }

    // MARK: - Meals & stats

    func testDayStatusThresholds() {
        XCTAssertEqual(DayStatus(consumed: 0, target: 2000, logged: false), .noLog)
        XCTAssertEqual(DayStatus(consumed: 1500, target: 2000, logged: true), .under)
        XCTAssertEqual(DayStatus(consumed: 2000, target: 2000, logged: true), .onTarget)
        XCTAssertEqual(DayStatus(consumed: 2300, target: 2000, logged: true), .over)
    }

    func testStreakSurvivesUntilTodayIsLogged() {
        let (_, meals, _) = makeStores()
        meals.log(meal(daysAgo: 1, calories: 500))
        meals.log(meal(daysAgo: 2, calories: 500))
        XCTAssertEqual(meals.streak(), 2, "An unlogged today doesn't break the streak yet")
        meals.log(meal(daysAgo: 0, calories: 500))
        XCTAssertEqual(meals.streak(), 3)
    }

    func testMealsPersistAndTotalsUpdate() {
        let (profiles, meals, defaults) = makeStores()
        let m = meal(daysAgo: 0, calories: 400)
        meals.log(m)
        var edited = m
        edited.servingMultiplier = 1.5
        meals.update(edited)
        XCTAssertEqual(meals.totalsForToday().calories, 600)

        let reloaded = MealLogStore(profileStore: profiles, defaults: defaults, syncsWidget: false)
        XCTAssertEqual(reloaded.totalsForToday().calories, 600)
        reloaded.remove(id: m.id)
        XCTAssertEqual(reloaded.totalsForToday().mealCount, 0)
    }

    func testStatsAverageOnlyCountsLoggedDaysAndBestDayIsNamed() {
        let (profiles, meals, _) = makeStores()
        var p = UserProfile()
        p.calorieTarget = 2000
        profiles.completeOnboarding(with: p)
        let target = profiles.profile.calorieTarget
        meals.log(meal(daysAgo: 0, calories: target))
        meals.log(meal(daysAgo: 3, calories: target / 2))
        let stats = StatsViewModel(mealStore: meals, profileStore: profiles)
        XCTAssertEqual(stats.loggedDays, 2)
        XCTAssertEqual(stats.onTargetDays, 1)
        XCTAssertEqual(stats.averageCalories, (target + target / 2) / 2)
        XCTAssertEqual(stats.bestDayLabel, Date().formatted(.dateTime.weekday(.wide)))
    }

    func testCalendarMissedDaysStartAtFirstLog() {
        let (profiles, meals, _) = makeStores()
        profiles.completeOnboarding(with: UserProfile())
        let calendar = CalendarViewModel(mealStore: meals, profileStore: profiles)
        XCTAssertEqual(calendar.summary.missed, 0, "Nothing is missed before tracking starts")

        let day = Calendar.current.component(.day, from: Date())
        guard day >= 3 else { return }  // needs two earlier days in this month
        meals.log(meal(daysAgo: 2, calories: 1800))
        XCTAssertEqual(calendar.summary.missed, 1, "Yesterday is missed; today is still open")
    }

    func testCalendarMonthNavigationAndSwipe() {
        let (profiles, meals, _) = makeStores()
        let model = CalendarViewModel(mealStore: meals, profileStore: profiles)
        let start = model.displayedMonth
        model.select(Date())
        model.nextMonth()
        XCTAssertEqual(model.displayedMonth, start % 12 + 1)
        XCTAssertNil(model.selectedDate)
        model.previousMonth()
        XCTAssertEqual(model.displayedMonth, start)

        model.handleMonthSwipe(width: -120, height: 8, startX: 140)
        XCTAssertEqual(model.displayedMonth, start % 12 + 1)
        model.handleMonthSwipe(width: 130, height: 0, startX: 16)  // edge swipe is left for back navigation
        XCTAssertEqual(model.displayedMonth, start % 12 + 1)
    }

    // MARK: - Weight analysis

    func testPlateauDetection() {
        let flat = (0...5).map { WeightEntry(date: Date().adding(days: -$0 * 3), kilograms: 80 + ($0 % 2 == 0 ? 0.05 : -0.05)) }
        XCTAssertEqual(WeightAnalysis.plateauState(entries: flat, goal: .loseFat).isPlateau, true)

        let losing = (0...5).map { WeightEntry(date: Date().adding(days: -$0 * 3), kilograms: 80 + Double($0) * 0.25) }
        guard case .progressing(let trend) = WeightAnalysis.plateauState(entries: losing, goal: .loseFat) else {
            return XCTFail("Expected progress")
        }
        XCTAssertEqual(trend.kgPerWeek, -0.583, accuracy: 0.01)
        XCTAssertEqual(WeightAnalysis.plateauState(entries: Array(losing.prefix(2)), goal: .loseFat), .notEnoughData)
    }

    func testCalibrationFromIntakeAndWeightChange() {
        let now = Date()
        // Losing 0.5 kg/week while eating 2000 kcal ⇒ maintenance ≈ 2000 + 550.
        let entries = (0...7).map { WeightEntry(date: now.adding(days: -$0 * 3), kilograms: 80 + Double($0) * 3 * 0.5 / 7) }
        var intake: [Date: Int] = [:]
        for d in 0..<20 { intake[Calendar.current.startOfDay(for: now.adding(days: -d))] = 2000 }
        let estimate = WeightAnalysis.calibration(entries: entries, intakeByDay: intake, now: now)
        XCTAssertEqual(Double(estimate?.tdee ?? 0), 2550, accuracy: 15)

        XCTAssertNil(WeightAnalysis.calibration(entries: entries, intakeByDay: [:], now: now),
                     "No estimate without logged intake")
    }

    func testProjection() {
        let p = WeightProjector.project(fromKg: 80, toKg: 75, dailyBalance: 500)
        guard case .eta(_, let weeks) = p.outcome else { return XCTFail("Expected an ETA") }
        XCTAssertEqual(weeks, 5 / (500 * 7 / 7700 * 0.92), accuracy: 0.01)
        XCTAssertEqual(WeightProjector.project(fromKg: 80, toKg: 80.1, dailyBalance: 500).outcome, .reached)
        XCTAssertEqual(WeightProjector.project(fromKg: 80, toKg: 40, dailyBalance: 100).outcome, .tooSlow)
        XCTAssertTrue(WeightProjector.project(fromKg: 60, toKg: 65, dailyBalance: 300).isGain)
    }

    // MARK: - Capture

    private struct FailingRecognition: FoodRecognitionService {
        func warmUp() {}
        func recognizeFood(from imageData: Data?, guidance: CaptureGuidance) async throws -> FoodRecognitionResult {
            throw NutritionPredictionError.nothingDetected
        }
    }

    func testFailedRecognitionBlocksLogging() async throws {
        let (_, meals, _) = makeStores()
        let model = CameraFlowViewModel(recognitionService: FailingRecognition(), mealStore: meals)
        model.manualCapture(camera: CameraCaptureController())
        for _ in 0..<50 where model.errorMessage == nil { try await Task.sleep(for: .milliseconds(20)) }

        XCTAssertEqual(model.phase, .scanning)
        XCTAssertNil(model.result)
        XCTAssertEqual(model.errorMessage, NutritionPredictionError.nothingDetected.errorDescription)
        model.addToLog(multiplier: 1)
        XCTAssertTrue(meals.meals.isEmpty)
    }

    func testRealRecognitionRequiresAPhoto() async {
        do {
            _ = try await DPFFoodRecognitionService().recognizeFood(from: nil, guidance: CaptureGuidance(tiltDegrees: 0))
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? NutritionPredictionError, .noPhoto)
        }
    }

    func testCaptureGuidanceGate() {
        XCTAssertTrue(CaptureGuidance(tiltDegrees: 10, heightCm: 30).isReady)
        XCTAssertTrue(CaptureGuidance(tiltDegrees: 10, heightCm: nil).isReady, "No depth sensor: tilt only")
        XCTAssertFalse(CaptureGuidance(tiltDegrees: 40, heightCm: 30).isReady)
        XCTAssertFalse(CaptureGuidance(tiltDegrees: 10, heightCm: 45).isReady)
    }

    // MARK: - Integrations

    private final class MockHealth: HealthDataProviding, @unchecked Sendable {
        var isAvailable = true
        var active: Int? = 400
        var saved: [UUID] = []
        var deleted: [UUID] = []
        func requestAuthorization(for settings: HealthSettings) async throws {}
        func bodyMetrics() async -> HealthBodyMetrics { HealthBodyMetrics(heightCentimeters: 180, age: 30) }
        func weightHistory(days: Int) async -> [WeightEntry] {
            [WeightEntry(date: Date().adding(days: -1), kilograms: 77, source: .health)]
        }
        func activeEnergyToday() async -> Int? { active }
        func saveMeal(_ meal: LoggedMeal) async throws { saved.append(meal.id) }
        func deleteMeal(id: UUID) async throws { deleted.append(id) }
    }

    private final class MockNotifications: NotificationScheduling, @unchecked Sendable {
        var scheduled: [(hour: Int, skipToday: Bool)] = []
        var cancelled = 0
        var warnings = 0
        func permission() async -> NotificationPermission { .allowed }
        func requestPermission() async -> Bool { true }
        func scheduleMealReminders(hour: Int, minute: Int, skipToday: Bool) async { scheduled.append((hour, skipToday)) }
        func cancelMealReminders() async { cancelled += 1 }
        func postCalorieWarning(consumed: Int, target: Int) async { warnings += 1 }
    }

    func testActiveEnergyReplacesActivityAllowance() async {
        let (profiles, meals, defaults) = makeStores()
        profiles.completeOnboarding(with: UserProfile())
        let model = IntegrationViewModel(healthProvider: MockHealth(), notifications: MockNotifications(),
                                         profileStore: profiles, mealStore: meals, defaults: defaults)
        let base = profiles.profile.calorieTarget
        XCTAssertEqual(model.calorieTarget(on: Date()), base)
        await model.setUseActiveEnergy(true)
        XCTAssertEqual(model.calorieTarget(on: Date()), base - profiles.profile.activityAllowance + 400)
    }

    func testBodyImportUpdatesProfileAndWeights() async {
        let (profiles, meals, defaults) = makeStores()
        profiles.completeOnboarding(with: UserProfile())
        let model = IntegrationViewModel(healthProvider: MockHealth(), notifications: MockNotifications(),
                                         profileStore: profiles, mealStore: meals, defaults: defaults)
        await model.setReadBody(true)
        XCTAssertEqual(profiles.profile.heightCentimeters, 180)
        XCTAssertEqual(profiles.profile.age, 30)
        XCTAssertTrue(profiles.weights.contains { $0.source == .health })
    }

    func testMealChangesDriveHealthWritesAndReminders() async throws {
        let (profiles, meals, defaults) = makeStores()
        profiles.completeOnboarding(with: UserProfile())
        let health = MockHealth()
        let notes = MockNotifications()
        let model = IntegrationViewModel(healthProvider: health, notifications: notes,
                                         profileStore: profiles, mealStore: meals, defaults: defaults)
        model.connect()
        await model.setWriteMeals(true)
        await model.setMealReminder(true)
        XCTAssertEqual(notes.scheduled.last?.skipToday, false)

        let m = meal(daysAgo: 0, calories: 3000)
        meals.log(m)
        for _ in 0..<50 where health.saved.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(health.saved, [m.id])
        XCTAssertEqual(notes.scheduled.last?.skipToday, true, "Today's reminder is skipped once a meal is logged")

        meals.remove(id: m.id)
        for _ in 0..<50 where health.deleted.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(health.deleted, [m.id])
    }

    func testIntegrationSettingsPersist() async {
        let (profiles, meals, defaults) = makeStores()
        let first = IntegrationViewModel(healthProvider: MockHealth(), notifications: MockNotifications(),
                                         profileStore: profiles, mealStore: meals, defaults: defaults)
        await first.setCalorieWarning(true)
        await first.setReadBody(true)
        let restored = IntegrationViewModel(healthProvider: MockHealth(), notifications: MockNotifications(),
                                            profileStore: profiles, mealStore: meals, defaults: defaults)
        XCTAssertTrue(restored.reminders.calorieWarningEnabled)
        XCTAssertTrue(restored.health.readBody)
        XCTAssertFalse(restored.reminders.mealReminderEnabled, "Meal reminder is off until the user turns it on")
    }

    func testGoalsScenarioAndCustomBalancePersist() {
        let (profiles, meals, defaults) = makeStores()
        profiles.completeOnboarding(with: UserProfile())
        let first = GoalsViewModel(profileStore: profiles, mealStore: meals, defaults: defaults)
        first.selectScenario(.aggressive)
        XCTAssertEqual(first.dailyBalance, 750)
        first.updateBalance(525)
        XCTAssertNil(first.selectedScenario)

        let restored = GoalsViewModel(profileStore: profiles, mealStore: meals, defaults: defaults)
        XCTAssertEqual(restored.dailyBalance, 525)
        XCTAssertLessThan(restored.targetWeightKilograms, profiles.profile.weightKilograms, "Default target follows a fat-loss goal")
    }
}

private extension PlateauState {
    var isPlateau: Bool {
        if case .plateau = self { return true }
        return false
    }
}
