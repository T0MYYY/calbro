import SwiftUI
import UIKit

/// Fixed design sizes, scaled with the user's Dynamic Type setting (capped so layouts hold).
enum CBTypography {
    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: scaled(size, cap: 1.3), weight: .bold, design: .rounded)
    }

    static func body(_ size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size, cap: 1.45), weight: weight, design: .rounded)
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: scaled(size, cap: 1.15), weight: weight, design: .serif).italic()
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size, cap: 1.3), weight: weight, design: .monospaced)
    }

    private static func scaled(_ size: CGFloat, cap: CGFloat) -> CGFloat {
        min(UIFontMetrics.default.scaledValue(for: size), size * cap)
    }
}
