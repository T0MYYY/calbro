import Foundation

struct WeightEntry: Identifiable, Codable, Equatable {
    enum Source: String, Codable { case manual, health }

    var id = UUID()
    var date: Date
    var kilograms: Double
    var source: Source = .manual
}

struct WeightTrend: Equatable {
    /// Least-squares slope, negative when losing.
    let kgPerWeek: Double
    let spanDays: Int
    let entryCount: Int
}

enum PlateauState: Equatable {
    case notEnoughData
    case maintaining(WeightTrend)
    case progressing(WeightTrend)
    case wrongDirection(WeightTrend)
    case plateau(WeightTrend)
}

struct CalibrationEstimate: Equatable {
    let tdee: Int
    let loggedDays: Int
    let spanDays: Int
}

enum WeightAnalysis {
    /// Slower than this counts as flat: about 0.2 kg over two weeks.
    static let plateauThresholdKgPerWeek = 0.1

    static func trend(_ entries: [WeightEntry], windowDays: Int, minimumSpanDays: Int,
                      now: Date = Date()) -> WeightTrend? {
        let cutoff = now.addingTimeInterval(-Double(windowDays) * 86_400)
        let recent = entries.filter { $0.date >= cutoff && $0.date <= now }.sorted { $0.date < $1.date }
        guard recent.count >= 3, let first = recent.first, let last = recent.last else { return nil }
        let spanDays = Int((last.date.timeIntervalSince(first.date) / 86_400).rounded())
        guard spanDays >= minimumSpanDays else { return nil }

        let xs = recent.map { $0.date.timeIntervalSince(first.date) / 86_400 }
        let ys = recent.map(\.kilograms)
        let meanX = xs.reduce(0, +) / Double(xs.count)
        let meanY = ys.reduce(0, +) / Double(ys.count)
        var num = 0.0, den = 0.0
        for (x, y) in zip(xs, ys) {
            num += (x - meanX) * (y - meanY)
            den += (x - meanX) * (x - meanX)
        }
        guard den > 0 else { return nil }
        return WeightTrend(kgPerWeek: num / den * 7, spanDays: spanDays, entryCount: recent.count)
    }

    static func plateauState(entries: [WeightEntry], goal: FitnessGoal, now: Date = Date()) -> PlateauState {
        guard let trend = trend(entries, windowDays: 21, minimumSpanDays: 12, now: now) else { return .notEnoughData }
        let direction = goal.dailyAdjustment.signum()
        if direction == 0 { return .maintaining(trend) }
        if abs(trend.kgPerWeek) < plateauThresholdKgPerWeek { return .plateau(trend) }
        return (trend.kgPerWeek < 0) == (direction < 0) ? .progressing(trend) : .wrongDirection(trend)
    }

    /// Maintenance calories implied by the last four weeks: average logged intake
    /// minus the energy equivalent of the measured weight change.
    static func calibration(entries: [WeightEntry], intakeByDay: [Date: Int],
                            now: Date = Date()) -> CalibrationEstimate? {
        guard let trend = trend(entries, windowDays: 28, minimumSpanDays: 14, now: now) else { return nil }
        let cutoff = now.addingTimeInterval(-28 * 86_400)
        let intakes = intakeByDay.filter { $0.key >= cutoff && $0.key <= now && $0.value > 0 }.map(\.value)
        guard intakes.count >= 10 else { return nil }
        let averageIntake = Double(intakes.reduce(0, +)) / Double(intakes.count)
        let tdee = averageIntake - trend.kgPerWeek / 7 * WeightMath.kcalPerKg
        guard (1000...6000).contains(tdee) else { return nil }
        return CalibrationEstimate(tdee: Int(tdee.rounded()), loggedDays: intakes.count, spanDays: trend.spanDays)
    }
}
