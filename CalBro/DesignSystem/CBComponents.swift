import SwiftUI

struct CBCard<Content: View>: View {
    var background = CBColors.bg
    var border = CBColors.inkFaint
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .background(background)
            .overlay(RoundedRectangle(cornerRadius: CBSpacing.cardRadius).stroke(border, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: CBSpacing.cardRadius, style: .continuous))
    }
}

struct PrimaryButton: View {
    let title: Text
    let action: () -> Void

    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = Text(title)
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            title
                .font(CBTypography.body(18, weight: .semibold))
                .foregroundStyle(CBColors.controlOnFill)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(CBColors.controlFill)
                .clipShape(RoundedRectangle(cornerRadius: CBSpacing.buttonRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("primaryButton")
    }
}

struct ProgressBar: View {
    let progress: Double
    var color = CBColors.terra
    var height: CGFloat = 7

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.12))
                Capsule()
                    .fill(color)
                    .frame(width: max(0, min(progress, 1.15)) * proxy.size.width)
            }
        }
        .frame(height: height)
    }
}

struct MacroBar: View {
    let macro: Macro

    var body: some View {
        let color = CBColors.nutrition(macro.colorKey)
        VStack(spacing: 4) {
            HStack {
                Text(macro.label)
                    .foregroundStyle(CBColors.inkMid)
                Spacer()
                Text(macro.value)
                    .fontWeight(.medium)
                    .foregroundStyle(CBColors.ink)
            }
            .font(CBTypography.body(14))
            ProgressBar(progress: macro.progress, color: color, height: 6)
        }
    }
}

struct RingShape: Shape {
    let progress: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * min(progress, 1)),
            clockwise: false
        )
        return path
    }
}

struct CalorieRing: View {
    let progress: Double
    let label: String
    var subtitle: String = ""
    var size: CGFloat = 148
    var stroke: CGFloat = 12
    var color = CBColors.terra
    var display = true

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.12), lineWidth: stroke)
            RingShape(progress: progress)
                .stroke(color, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
            VStack(spacing: 2) {
                Text(label)
                    .font(display ? CBTypography.display(size * 0.19) : CBTypography.body(size * 0.17, weight: .bold))
                    .foregroundStyle(CBColors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(CBTypography.body(size * 0.13))
                        .foregroundStyle(CBColors.inkMid)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            .padding(stroke + 2)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
    }
}

struct MacroRing: View {
    let macro: Macro
    var size: CGFloat = 54
    var stroke: CGFloat = 5

    var body: some View {
        CalorieRing(
            progress: macro.progress,
            label: macro.value,
            size: size,
            stroke: stroke,
            color: CBColors.nutrition(macro.colorKey),
            display: false
        )
        .accessibilityLabel(Text(macro.label))
        .accessibilityValue(Text(macro.value))
    }
}

struct PillTag: View {
    let text: Text
    var color = CBColors.terra
    var filled = false

    init(_ key: LocalizedStringKey, color: Color = CBColors.terra, filled: Bool = false) {
        self.text = Text(key)
        self.color = color
        self.filled = filled
    }

    @_disfavoredOverload
    init<S: StringProtocol>(_ string: S, color: Color = CBColors.terra, filled: Bool = false) {
        self.text = Text(string)
        self.color = color
        self.filled = filled
    }

    var body: some View {
        text
            .font(CBTypography.body(13, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(filled ? .white : color)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(filled ? color : color.opacity(0.09))
            .overlay(Capsule().stroke(filled ? Color.clear : color.opacity(0.25), lineWidth: 1))
            .clipShape(Capsule())
    }
}

struct MetricCard: View {
    let value: String
    let label: Text
    var color = CBColors.ink

    init(value: String, label: LocalizedStringKey, color: Color = CBColors.ink) {
        self.value = value
        self.label = Text(label)
        self.color = color
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(CBTypography.body(18, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            label
                .font(CBTypography.body(12))
                .foregroundStyle(CBColors.inkMid)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct EdgeSwipeBackModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .global)
                    .onEnded { value in
                        let startsAtEdge = value.startLocation.x < 28
                        let movesRight = value.translation.width > 72
                        let mostlyHorizontal = abs(value.translation.height) < 48
                        if startsAtEdge && movesRight && mostlyHorizontal {
                            dismiss()
                        }
                    }
            )
    }
}

extension View {
    func edgeSwipeBackEnabled() -> some View {
        modifier(EdgeSwipeBackModifier())
    }
}
