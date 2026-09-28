import SwiftUI
import UIKit

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
        .buttonStyle(.cbPressable)
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

/// Plain-looking button whose whole frame is tappable (including clear backgrounds)
/// and that dims while pressed, so taps register and feel immediate.
struct CBPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.55 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CBPressableButtonStyle {
    static var cbPressable: CBPressableButtonStyle { CBPressableButtonStyle() }
}

/// Screens hide the system back button to draw their own header, which also disables
/// the interactive swipe-back. This re-enables the native gesture on the hosting stack.
private struct InteractivePopEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enable()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enable()
        }

        private func enable() {
            guard let nav = navigationController, let pop = nav.interactivePopGestureRecognizer else { return }
            pop.isEnabled = true
            PopGestureDelegate.shared.attach(to: nav)
        }
    }
}

/// Allows the swipe only when there is a screen to go back to; swiping on a
/// stack's root would otherwise leave the navigation controller stuck.
@MainActor
private final class PopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = PopGestureDelegate()
    private let controllers = NSHashTable<UINavigationController>.weakObjects()

    func attach(to nav: UINavigationController) {
        controllers.add(nav)
        nav.interactivePopGestureRecognizer?.delegate = self
    }

    nonisolated func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        MainActor.assumeIsolated {
            controllers.allObjects.first { $0.interactivePopGestureRecognizer === gestureRecognizer }
                .map { $0.viewControllers.count > 1 } ?? false
        }
    }
}

extension View {
    func edgeSwipeBackEnabled() -> some View {
        background(InteractivePopEnabler().frame(width: 0, height: 0))
    }
}

extension View {
    /// Number pads have no return key; adds a Done button above the keyboard.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
    }
}
