import Foundation

@MainActor
@Observable
final class GoalsViewModel {
    private(set) var selectedScenario: PredictionScenario? = .current
    /// Daily deficit or surplus chosen on the slider, in kcal.
    var customBalance: Double = 500

    private let profileStore: ProfileStore
    private let mealStore: MealLogStore
    private let defaults: UserDefaults
    private let persistenceKey: String

    private struct PersistedState: Codable {
        var selectedScenario: PredictionScenario?
        var customBalance: Double
    }

    init(profileStore: ProfileStore = .shared, mealStore: MealLogStore = .shared,
         defaults: UserDefaults = .standard, persistenceKey: String = "calbro.goals.v2") {
        self.profileStore = profileStore
        self.mealStore = mealStore
        self.defaults = defaults
        self.persistenceKey = persistenceKey
        if let data = defaults.data(forKey: persistenceKey),
           let state = try? JSONDecoder().decode(PersistedState.self, from: data) {
            selectedScenario = state.selectedScenario
            customBalance = state.customBalance
        }
    }

    var profile: UserProfile { profileStore.profile }

    // MARK: - Projection

    /// Explicit target if set; otherwise a modest default in the goal's direction.
    var targetWeightKilograms: Double {
        if let t = profile.targetWeightKilograms { return t }
        let w = profile.weightKilograms
        switch profile.goal.dailyAdjustment.signum() {
        case -1: return (w * 0.93 * 2).rounded() / 2
        case 1:  return (w * 1.05 * 2).rounded() / 2
        default: return w
        }
    }

    var isGain: Bool { targetWeightKilograms > profile.weightKilograms }

    var dailyBalance: Int {
        selectedScenario?.dailyBalance(for: profile) ?? Int(customBalance.rounded())
    }

    var projection: WeightProjection {
        WeightProjector.project(fromKg: profile.weightKilograms, toKg: targetWeightKilograms, dailyBalance: dailyBalance)
    }

    func selectScenario(_ scenario: PredictionScenario) {
        selectedScenario = scenario
        customBalance = Double(scenario.dailyBalance(for: profile))
        persist()
    }

    func updateBalance(_ value: Double) {
        customBalance = value
        selectedScenario = nil
        persist()
    }

    /// `value` is in the user's display unit.
    func setTargetWeight(displayValue value: Int) {
        profileStore.setTargetWeight(profile.kilograms(fromDisplayUnit: Double(value)))
    }

    // MARK: - Weight trend & calibration

    var weights: [WeightEntry] { profileStore.weights }

    var plateau: PlateauState { WeightAnalysis.plateauState(entries: weights, goal: profile.goal) }

    var calibrationEstimate: CalibrationEstimate? {
        WeightAnalysis.calibration(entries: weights, intakeByDay: mealStore.intakeByDay)
    }

    func logWeight(displayValue: Double, on date: Date = Date()) {
        profileStore.logWeight(kilograms: profile.kilograms(fromDisplayUnit: displayValue), on: date)
    }

    func deleteWeight(id: UUID) { profileStore.deleteWeight(id: id) }

    func applyCalibration() {
        guard let estimate = calibrationEstimate else { return }
        profileStore.applyCalibration(estimate)
    }

    func clearCalibration() { profileStore.clearCalibration() }

    // MARK: - TDEE breakdown

    var tdeeItems: [TDEEItem] {
        let p = profile
        let tdee = max(p.tdee, 1)
        let adjustment = p.calorieTarget - p.tdee
        var items: [TDEEItem] = []
        if let calibration = p.calibration {
            items.append(TDEEItem(id: "calibrated", label: String(localized: "Maintenance (from your logs)"),
                                  value: NutritionFormat.kcal(calibration.tdee), progress: 1, colorKey: .sage))
        } else {
            items.append(TDEEItem(id: "bmr", label: String(localized: "BMR (base metabolism)"),
                                  value: NutritionFormat.kcal(p.bmr),
                                  progress: Double(p.bmr) / Double(tdee), colorKey: .ink))
            items.append(TDEEItem(id: "activity",
                                  label: String(localized: "Activity \(p.activityLevel.multiplierLabel)"),
                                  value: NutritionFormat.signedKcal(p.activityAllowance),
                                  progress: Double(p.activityAllowance) / Double(tdee), colorKey: .ink))
            items.append(TDEEItem(id: "tdee", label: String(localized: "TDEE total"),
                                  value: NutritionFormat.kcal(p.tdee), progress: 1, colorKey: .sage))
        }
        if adjustment != 0 {
            items.append(TDEEItem(id: "adjustment",
                                  label: adjustment < 0 ? String(localized: "Daily deficit") : String(localized: "Daily surplus"),
                                  value: NutritionFormat.signedKcal(adjustment),
                                  progress: Double(abs(adjustment)) / Double(tdee), colorKey: .ink))
        }
        items.append(TDEEItem(id: "goal", label: String(localized: "Your calorie goal"),
                              value: NutritionFormat.kcal(p.calorieTarget),
                              progress: Double(p.calorieTarget) / Double(tdee), colorKey: .terra))
        return items
    }

    private func persist() {
        let state = PersistedState(selectedScenario: selectedScenario, customBalance: customBalance)
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: persistenceKey)
    }
}
