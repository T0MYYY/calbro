import SwiftUI

struct StatsCaloriesView: View {
    @Bindable var viewModel: StatsViewModel
    @Bindable var navigation: AppNavigationViewModel

    var body: some View {
        VStack(spacing: 0) {
            NavHeader("Stats", subtitle: String(localized: "Last 7 days · \(viewModel.rangeLabel)")) {
                Button {
                    navigation.navigate(.weeklyReport, in: .stats)
                } label: {
                    PillTag("Report", color: CBColors.inkMid)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.cbPressable)
                .accessibilityIdentifier("openReport")
            }
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        MetricCard(
                            value: viewModel.averageCalories > 0 ? NutritionFormat.kcal(viewModel.averageCalories) : "—",
                            label: "Daily average"
                        )
                        MetricCard(value: viewModel.calorieTargetLabel, label: "Target")
                        MetricCard(
                            value: String(localized: "\(viewModel.loggedDays) of 7"),
                            label: "Days logged",
                            color: viewModel.loggedDays >= 5 ? CBColors.sage : CBColors.gold
                        )
                    }
                    Rectangle().fill(CBColors.inkFaint).frame(height: 1)
                    TrendBarChart(bars: viewModel.calorieBars)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Macros, average per logged day")
                            .font(CBTypography.body(13)).foregroundStyle(CBColors.inkMid)
                        ForEach(viewModel.weeklyMacros) { macro in
                            MacroBar(macro: macro)
                        }
                    }
                }
                .padding(.horizontal, CBSpacing.page)
                .padding(.bottom, 96)
            }
        }
        .background(CBColors.bg)
    }
}

struct StatsReportView: View {
    let stats: StatsViewModel

    var body: some View {
        VStack(spacing: 0) {
            NavHeader("Weekly report", subtitle: stats.rangeLabel, showsBack: true)
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 20) {
                        CalorieRing(
                            progress: adherence,
                            label: NutritionFormat.percent(adherence),
                            size: 92, stroke: 9,
                            color: adherence >= 0.7 ? CBColors.sage : CBColors.gold,
                            display: false
                        )
                        .accessibilityLabel(Text("Days on target"))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summaryTitle).font(CBTypography.title(22)).foregroundStyle(CBColors.ink)
                            Text("\(stats.onTargetDays) of 7 days on target")
                            Text(stats.streak > 0 ? String(localized: "\(stats.streak)-day streak") : String(localized: "No streak yet"))
                        }
                        .font(CBTypography.body(14))
                        .foregroundStyle(CBColors.inkMid)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Rectangle().fill(CBColors.inkFaint).frame(height: 1)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calorie trend").font(CBTypography.body(15, weight: .semibold))
                        TrendBarChart(bars: stats.calorieBars)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Macro averages").font(CBTypography.body(15, weight: .semibold))
                        ForEach(stats.weeklyMacros) { macro in MacroBar(macro: macro) }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Insights").font(CBTypography.body(15, weight: .semibold))
                        InsightRow(label: "Days logged", value: String(localized: "\(stats.loggedDays) of 7"))
                        InsightRow(label: "Average intake",
                                   value: stats.averageCalories > 0 ? NutritionFormat.kcal(stats.averageCalories)
                                                                    : String(localized: "No data"))
                        if let bestDay = stats.bestDayLabel {
                            InsightRow(label: "Closest to target", value: bestDay)
                        }
                        if let mostLogged = stats.mostLoggedFood {
                            InsightRow(label: "Most logged", value: mostLogged)
                        }
                        InsightRow(label: "Streak",
                                   value: stats.streak > 0 ? String(localized: "\(stats.streak) days")
                                                           : String(localized: "Start today"))
                    }
                }
                .padding(.horizontal, CBSpacing.page)
                .padding(.top, 16)
                .padding(.bottom, 96)
            }
        }
        .background(CBColors.bg)
        .navigationBarBackButtonHidden()
        .edgeSwipeBackEnabled()
    }

    private var adherence: Double { Double(stats.onTargetDays) / 7 }

    private var summaryTitle: String {
        switch stats.onTargetDays {
        case 6...: String(localized: "Great week!")
        case 4...: String(localized: "Good week")
        case 2...: String(localized: "Getting there")
        default:   stats.loggedDays == 0 ? String(localized: "No data yet") : String(localized: "Keep going")
        }
    }
}

private struct InsightRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(CBColors.inkMid)
            Spacer()
            Text(value).fontWeight(.medium).foregroundStyle(CBColors.ink)
                .multilineTextAlignment(.trailing)
        }
        .font(CBTypography.body(14))
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(CBColors.inkLine).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}
