import Foundation

/// Single source of truth for the profile and weight history. Views read it directly,
/// so an edit anywhere shows up everywhere without reloading from UserDefaults.
@MainActor
@Observable
final class ProfileStore {
    static let shared = ProfileStore()

    private(set) var profile: UserProfile
    private(set) var onboardingComplete: Bool
    /// Sorted oldest → newest.
    private(set) var weights: [WeightEntry]

    /// Called after every profile change (widget + notification refresh).
    @ObservationIgnored var onProfileChange: ((UserProfile) -> Void)?

    private let stateStore: AppStateStore
    private let defaults: UserDefaults
    private static let weightsKey = "calbro.weights.v1"
    static let recalibrationInterval: TimeInterval = 14 * 86_400

    init(stateStore: AppStateStore = UserDefaultsAppStateStore(), defaults: UserDefaults = .standard) {
        self.stateStore = stateStore
        self.defaults = defaults
        let snapshot = stateStore.load()
        profile = snapshot?.profile ?? UserProfile()
        onboardingComplete = snapshot?.onboardingComplete ?? false
        if let data = defaults.data(forKey: Self.weightsKey),
           let saved = try? JSONDecoder().decode([WeightEntry].self, from: data) {
            weights = saved.sorted { $0.date < $1.date }
        } else {
            weights = []
        }
    }

    // MARK: - Profile

    func completeOnboarding(with profile: UserProfile, now: Date = Date()) {
        onboardingComplete = true
        if weights.isEmpty {
            weights = [WeightEntry(date: now, kilograms: profile.weightKilograms)]
            saveWeights()
        }
        apply(profile)
    }

    /// Saves an edited profile. A changed body weight is also recorded as today's weigh-in.
    func update(_ newProfile: UserProfile, now: Date = Date()) {
        if abs(newProfile.weightKilograms - profile.weightKilograms) >= 0.05 {
            upsertWeight(WeightEntry(date: now, kilograms: newProfile.weightKilograms))
        }
        apply(newProfile)
    }

    func setTargetWeight(_ kilograms: Double?) {
        var p = profile
        p.targetWeightKilograms = kilograms
        apply(p)
    }

    func applyCalibration(_ estimate: CalibrationEstimate, now: Date = Date()) {
        var p = profile
        p.calibration = TDEECalibration(tdee: estimate.tdee, date: now)
        apply(p)
    }

    func clearCalibration() {
        var p = profile
        p.calibration = nil
        apply(p)
    }

    /// Once calibrated, refresh the estimate every two weeks while data keeps coming in.
    func recalibrateIfDue(intakeByDay: [Date: Int], now: Date = Date()) {
        guard let current = profile.calibration,
              now.timeIntervalSince(current.date) >= Self.recalibrationInterval,
              let estimate = WeightAnalysis.calibration(entries: weights, intakeByDay: intakeByDay, now: now)
        else { return }
        applyCalibration(estimate, now: now)
    }

    // MARK: - Weight log

    func logWeight(kilograms: Double, on date: Date = Date()) {
        upsertWeight(WeightEntry(date: date, kilograms: kilograms))
        syncProfileWeightToLatest()
    }

    func deleteWeight(id: UUID) {
        weights.removeAll { $0.id == id }
        saveWeights()
        syncProfileWeightToLatest()
    }

    /// Replaces previously imported Health samples with a fresh import.
    func replaceHealthWeights(_ entries: [WeightEntry]) {
        weights.removeAll { $0.source == .health }
        weights.append(contentsOf: entries)
        weights.sort { $0.date < $1.date }
        saveWeights()
        syncProfileWeightToLatest()
    }

    // MARK: - Private

    private func apply(_ newProfile: UserProfile) {
        var p = newProfile
        p.recalculateTargets()
        profile = p
        stateStore.save(AppStateSnapshot(onboardingComplete: onboardingComplete, profile: p))
        onProfileChange?(p)
    }

    /// One manual weigh-in per day; a second entry the same day replaces the first.
    private func upsertWeight(_ entry: WeightEntry) {
        weights.removeAll {
            $0.source == entry.source && Calendar.current.isDate($0.date, inSameDayAs: entry.date)
        }
        weights.append(entry)
        weights.sort { $0.date < $1.date }
        saveWeights()
    }

    private func syncProfileWeightToLatest() {
        guard let latest = weights.last, abs(latest.kilograms - profile.weightKilograms) >= 0.05 else { return }
        var p = profile
        p.weightKilograms = latest.kilograms
        apply(p)
    }

    private func saveWeights() {
        guard let data = try? JSONEncoder().encode(weights) else { return }
        defaults.set(data, forKey: Self.weightsKey)
    }
}
