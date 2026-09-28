import Foundation

enum PredictionScenario: String, CaseIterable, Identifiable, Codable {
    case gentle
    case current
    case aggressive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gentle:     String(localized: "Gentle")
        case .current:    String(localized: "Your plan")
        case .aggressive: String(localized: "Faster")
        }
    }

    /// Daily energy gap in kcal; `.current` uses the profile's own goal.
    func dailyBalance(for profile: UserProfile) -> Int {
        switch self {
        case .gentle:     250
        case .current:    max(abs(profile.goal.dailyAdjustment), 100)
        case .aggressive: 750
        }
    }
}

struct WeightProjection: Equatable {
    enum Outcome: Equatable {
        case reached
        case eta(Date, weeks: Double)
        /// More than two years away at this pace.
        case tooSlow
    }

    let targetKilograms: Double
    let isGain: Bool
    let dailyBalance: Int
    let outcome: Outcome
}

enum WeightProjector {
    /// Linear 7,700 kcal/kg projection, slowed 8 % for metabolic adaptation.
    static func project(fromKg current: Double, toKg target: Double, dailyBalance: Int,
                        now: Date = Date(), calendar: Calendar = .current) -> WeightProjection {
        let isGain = target > current
        let delta = abs(target - current)
        guard delta >= 0.25 else {
            return WeightProjection(targetKilograms: target, isGain: isGain, dailyBalance: dailyBalance, outcome: .reached)
        }
        let weeklyKg = Double(max(dailyBalance, 1)) * 7 / WeightMath.kcalPerKg * 0.92
        let weeks = delta / weeklyKg
        guard weeks <= 104,
              let date = calendar.date(byAdding: .day, value: Int((weeks * 7).rounded()), to: now)
        else {
            return WeightProjection(targetKilograms: target, isGain: isGain, dailyBalance: dailyBalance, outcome: .tooSlow)
        }
        return WeightProjection(targetKilograms: target, isGain: isGain, dailyBalance: dailyBalance,
                                outcome: .eta(date, weeks: weeks))
    }
}

struct TDEEItem: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let progress: Double
    let colorKey: NutritionColorKey
}
