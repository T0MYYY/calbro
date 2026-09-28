import Foundation

/// Locale-aware strings for nutrition quantities, shared by the app and the widget.
enum NutritionFormat {
    static func kcal(_ value: Int) -> String {
        kcal(formatted: value.formatted())
    }

    private static func kcal(formatted number: String) -> String {
        String(localized: "\(number) kcal", comment: "An amount of food energy, e.g. “1,820 kcal” or “−500 kcal”")
    }

    static func grams(_ value: Int) -> String {
        String(localized: "\(value.formatted()) g", comment: "A mass in grams, e.g. “82 g”")
    }

    static func kcalLeft(_ value: Int) -> String {
        String(localized: "\(value.formatted()) kcal left", comment: "Calories still available today")
    }

    static func kcalOver(_ value: Int) -> String {
        String(localized: "\(value.formatted()) kcal over", comment: "Calories eaten beyond today's target")
    }

    static func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    /// Signed calorie delta, e.g. “−500 kcal” / “+300 kcal”.
    static func signedKcal(_ value: Int) -> String {
        kcal(formatted: value.formatted(.number.sign(strategy: .always(includingZero: false))))
    }
}
