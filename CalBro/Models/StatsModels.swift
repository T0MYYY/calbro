import Foundation

struct TrendBar: Identifiable, Equatable {
    let id: Date
    let day: String
    let accessibilityDay: String
    let consumed: Int
    let progress: Double
    let isToday: Bool

    var valueLabel: String { consumed > 0 ? consumed.formatted() : "—" }
}
