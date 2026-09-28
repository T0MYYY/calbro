import SwiftUI
import WidgetKit

/// Self-contained palette (the widget target doesn't compile the app's design system).
enum WidgetPalette {
    static let terra = Color(red: 0.51, green: 0.55, blue: 0.97)
    static let plum  = Color(red: 0.70, green: 0.61, blue: 1.00)
    static let ocean = Color(red: 0.44, green: 0.68, blue: 0.96)
    static let gold  = Color(red: 0.83, green: 0.63, blue: 0.19)
    static let card  = Color(red: 0.067, green: 0.094, blue: 0.157)
}

/// Widget content for each family. The widget wraps it in `containerBackground`;
/// the in-app preview screen draws its own background around the same view.
struct NutritionWidgetFace: View {
    let family: WidgetFamily
    let snapshot: WidgetNutritionSnapshot

    var body: some View {
        switch family {
        case .accessoryCircular:    circular
        case .accessoryRectangular: rectangular
        case .systemSmall:          small
        default:                    medium
        }
    }

    private var snap: WidgetNutritionSnapshot { snapshot }

    private var statusLine: String {
        snap.over > 0 ? NutritionFormat.kcalOver(snap.over) : NutritionFormat.kcalLeft(snap.remaining)
    }

    private var circular: some View {
        Gauge(value: snap.progress) {
            Text("kcal")
        } currentValueLabel: {
            Text(snap.caloriesConsumed.formatted())
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(NutritionFormat.kcal(snap.caloriesConsumed)) of \(NutritionFormat.kcal(snap.calorieTarget))"))
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(snap.caloriesConsumed.formatted()) / \(NutritionFormat.kcal(snap.calorieTarget))",
                 comment: "Amount eaten out of the target, e.g. “82 g / 150 g” or “1,240 / 1,820 kcal”")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.7)
            ProgressView(value: snap.progress)
                .tint(.primary)
            Text(statusLine)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: snap.progress)
                    .stroke(WidgetPalette.terra, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(snap.caloriesConsumed.formatted())
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                    Text("kcal").font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
                }
                .padding(8)
            }
            Text(statusLine)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Today").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                Text(snap.caloriesConsumed.formatted())
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(statusLine)
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    macroPill(Text("Protein"), snap.protein, WidgetPalette.plum)
                    macroPill(Text("Carbs"), snap.carbs, WidgetPalette.ocean)
                    macroPill(Text("Fat"), snap.fat, WidgetPalette.gold)
                }
            }
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: snap.progress)
                    .stroke(WidgetPalette.terra, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(NutritionFormat.percent(snap.progress))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 84, height: 84)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func macroPill(_ label: Text, _ grams: Int, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(NutritionFormat.grams(grams))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            label
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(color.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
