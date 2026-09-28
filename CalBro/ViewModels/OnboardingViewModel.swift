import Foundation

enum OnboardingStep: Int, CaseIterable {
    case goal, body, activity, diet, result
}

@MainActor
@Observable
final class OnboardingViewModel {
    var step: OnboardingStep = .goal
    private(set) var profile: UserProfile

    private let profileStore: ProfileStore

    init(profileStore: ProfileStore = .shared) {
        self.profileStore = profileStore
        self.profile = profileStore.profile
    }

    var isComplete: Bool { profileStore.onboardingComplete }

    var progressText: String {
        let current = min(step.rawValue + 1, 4)
        return String(localized: "\(current) of 4", comment: "Onboarding progress, e.g. “2 of 4”")
    }

    var progress: Double { Double(min(step.rawValue + 1, 4)) / 4 }

    // MARK: - Input handlers

    func selectGoal(_ goal: FitnessGoal)       { profile.goal = goal }
    func selectSex(_ sex: BiologicalSex)        { profile.sex = sex }
    func selectUnits(_ units: UnitSystem)       { profile.units = units }
    func adjustAge(by delta: Int)               { updateAge(profile.age + delta) }
    func updateAge(_ age: Int)                  { profile.age = min(max(age, 13), 99) }
    func updateHeight(_ cm: Int)                { profile.heightCentimeters = min(max(cm, 90), 240) }
    func updateWeight(_ kg: Double)             { profile.weightKilograms = min(max(kg, 30), 250) }
    func selectActivity(_ level: ActivityLevel) { profile.activityLevel = level }

    /// Height in the display unit: cm, or total inches for imperial.
    var heightDisplayValue: Int {
        profile.units == .metric
            ? profile.heightCentimeters
            : Int((Double(profile.heightCentimeters) / WeightMath.cmPerInch).rounded())
    }

    func updateHeight(displayValue: Int) {
        updateHeight(profile.units == .metric ? displayValue : Int((Double(displayValue) * WeightMath.cmPerInch).rounded()))
    }

    var weightDisplayValue: Int { profile.weightInDisplayUnit(profile.weightKilograms) }

    func updateWeight(displayValue: Int) {
        updateWeight(profile.kilograms(fromDisplayUnit: Double(displayValue)))
    }

    func toggleDietPreference(_ preference: DietPreference) {
        if preference == .noRestriction {
            profile.dietPreferences = [.noRestriction]
            return
        }
        profile.dietPreferences.remove(.noRestriction)
        if profile.dietPreferences.contains(preference) {
            profile.dietPreferences.remove(preference)
        } else {
            profile.dietPreferences.insert(preference)
        }
        if profile.dietPreferences.isEmpty { profile.dietPreferences.insert(.noRestriction) }
    }

    // MARK: - Navigation

    func next() {
        switch step {
        case .goal:     step = .body
        case .body:     step = .activity
        case .activity: step = .diet
        case .diet:
            profile.recalculateTargets()
            step = .result
        case .result:
            profileStore.completeOnboarding(with: profile)
        }
    }

    func back() {
        switch step {
        case .goal:     break
        case .body:     step = .goal
        case .activity: step = .body
        case .diet:     step = .activity
        case .result:   step = .diet
        }
    }

    func skipDiet() {
        profile.dietPreferences = [.noRestriction]
        profile.recalculateTargets()
        step = .result
    }

    // MARK: - Result step

    var weeklyDeltaLabel: String {
        let weekly = profile.weeklyWeightChangeKg
        guard abs(weekly) > 0.01 else { return String(localized: "Maintenance") }
        let rate = profile.weightRateDisplay(kgPerWeek: abs(weekly))
        return weekly < 0 ? String(localized: "Lose ~\(rate)") : String(localized: "Gain ~\(rate)")
    }

    var goalTimelineLabel: String {
        abs(profile.weeklyWeightChangeKg) > 0.01
            ? String(localized: "Consistent logging is what makes this work.")
            : String(localized: "Focus on food quality and consistency.")
    }
}
