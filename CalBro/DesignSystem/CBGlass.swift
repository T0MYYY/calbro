import SwiftUI

enum CBGlassVariant {
    case regular
    case clear
}

struct CBGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    let variant: CBGlassVariant
    let cornerRadius: CGFloat
    let tint: Color?
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(variant == .clear ? Color.black.opacity(0.68) : CBColors.bg)
                .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(contrast == .increased ? CBColors.inkMid : CBColors.inkFaint, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            let base = variant == .clear ? Glass.clear : Glass.regular
            content
                .glassEffect((interactive ? base.interactive() : base).tint(tint), in: .rect(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    func cbGlass(
        _ variant: CBGlassVariant = .regular,
        cornerRadius: CGFloat = CBSpacing.glassRadius,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        modifier(CBGlassModifier(variant: variant, cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }
}
