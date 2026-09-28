import SwiftUI

/// Breakdown of one day (the day selected on the Today tab): targets, energy split and meals.
struct NutritionDetailView: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        let n = viewModel.nutrition
        VStack(spacing: 0) {
            NavHeader("Nutrition",
                      subtitle: viewModel.selectedDate.formatted(date: .complete, time: .omitted),
                      showsBack: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(spacing: 3) {
                            CalorieRing(progress: n.calorieProgress, label: n.caloriesConsumed.formatted(),
                                        size: 68, stroke: 7, display: false)
                            Text("Calories").font(CBTypography.body(11)).foregroundStyle(CBColors.inkMid)
                        }
                        .frame(maxWidth: .infinity)
                        ForEach(n.macros) { macro in
                            VStack(spacing: 3) {
                                MacroRing(macro: macro, size: 52, stroke: 5)
                                Text(macro.label).font(CBTypography.body(11)).foregroundStyle(CBColors.inkMid)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Rectangle().fill(CBColors.inkFaint).frame(height: 1)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Against your targets").font(CBTypography.body(15, weight: .semibold))
                        TargetRow(label: "Calories", value: n.caloriesConsumed, target: n.calorieTarget,
                                  format: NutritionFormat.kcal, color: CBColors.terra)
                        TargetRow(label: "Protein", value: n.totals.protein, target: n.proteinTarget,
                                  format: NutritionFormat.grams, color: CBColors.plum)
                        TargetRow(label: "Carbs", value: n.totals.carbs, target: n.carbTarget,
                                  format: NutritionFormat.grams, color: CBColors.ocean)
                        TargetRow(label: "Fat", value: n.totals.fat, target: n.fatTarget,
                                  format: NutritionFormat.grams, color: CBColors.gold)
                    }

                    if n.caloriesConsumed > 0 {
                        EnergySplitCard(totals: n.totals)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meals").font(CBTypography.body(15, weight: .semibold))
                        if viewModel.meals.isEmpty {
                            Text("Nothing logged on this day")
                                .font(CBTypography.body(14)).foregroundStyle(CBColors.inkMid)
                        }
                        ForEach(viewModel.meals) { meal in
                            MealBreakdownRow(meal: meal)
                        }
                    }

                    Text("Estimates come from a single photo and can be far off. Adjust servings when you know better.")
                        .font(CBTypography.body(12))
                        .foregroundStyle(CBColors.inkMid)
                }
                .padding(.horizontal, CBSpacing.page)
                .padding(.bottom, 96)
            }
        }
        .background(CBColors.bg)
        .navigationBarBackButtonHidden()
        .edgeSwipeBackEnabled()
    }
}

private struct TargetRow: View {
    let label: LocalizedStringKey
    let value: Int
    let target: Int
    let format: (Int) -> String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text(label).font(CBTypography.body(14)).foregroundStyle(CBColors.inkMid)
                Spacer()
                Text("\(format(value)) / \(format(target))", comment: "Amount eaten out of the target, e.g. “82 g / 150 g” or “1,240 / 1,820 kcal”")
                    .font(CBTypography.body(13, weight: .medium))
                    .foregroundStyle(CBColors.ink)
            }
            ProgressBar(progress: Double(value) / Double(max(target, 1)), color: color, height: 5)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Share of calories coming from protein, carbs and fat.
private struct EnergySplitCard: View {
    let totals: DayTotals

    private var parts: [(LocalizedStringKey, Double, Color)] {
        let p = Double(totals.protein * 4), c = Double(totals.carbs * 4), f = Double(totals.fat * 9)
        let sum = max(p + c + f, 1)
        return [("Protein", p / sum, CBColors.plum), ("Carbs", c / sum, CBColors.ocean), ("Fat", f / sum, CBColors.gold)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Where the calories come from").font(CBTypography.body(15, weight: .semibold))
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(parts.indices, id: \.self) { i in
                        Rectangle().fill(parts[i].2).frame(width: max(0, geo.size.width * parts[i].1 - 2))
                    }
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
            .accessibilityHidden(true)
            HStack(spacing: 14) {
                ForEach(parts.indices, id: \.self) { i in
                    HStack(spacing: 5) {
                        Circle().fill(parts[i].2).frame(width: 8, height: 8)
                        Text(parts[i].0)
                        Text(NutritionFormat.percent(parts[i].1)).fontWeight(.semibold)
                    }
                    .font(CBTypography.body(12))
                    .foregroundStyle(CBColors.inkMid)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct MealBreakdownRow: View {
    let meal: LoggedMeal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(meal.name).font(CBTypography.body(14, weight: .semibold)).foregroundStyle(CBColors.ink)
                Spacer()
                Text(NutritionFormat.kcal(meal.adjustedCalories)).font(CBTypography.body(14, weight: .semibold))
            }
            HStack(spacing: 10) {
                Text(meal.timeLabel)
                Text("Protein \(NutritionFormat.grams(meal.adjustedProtein))")
                Text("Carbs \(NutritionFormat.grams(meal.adjustedCarbs))")
                Text("Fat \(NutritionFormat.grams(meal.adjustedFat))")
            }
            .font(CBTypography.body(12))
            .foregroundStyle(CBColors.inkMid)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(CBColors.inkLine).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}
