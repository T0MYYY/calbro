import SwiftUI

struct CalendarMonthView: View {
    @Bindable var viewModel: CalendarViewModel
    var onOpenDay: (Date) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(verbatim: viewModel.monthTitle, showsBack: true) { monthControls }

            HStack {
                ForEach(Array(viewModel.weekdaySymbols.enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(CBTypography.body(12))
                        .foregroundStyle(CBColors.inkMid)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .accessibilityHidden(true)

            VStack(spacing: 4) {
                ForEach(Array(viewModel.weeks.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 4) {
                        ForEach(row) { cell in
                            CalendarDayCell(
                                day: cell.day,
                                status: cell.status,
                                isToday: cell.isToday,
                                isSelected: cell.date != nil && cell.date == viewModel.selectedDate,
                                accessibilityLabel: cell.accessibilityLabel,
                                action: { if let date = cell.date { viewModel.select(date) } }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        viewModel.handleMonthSwipe(
                            width: value.translation.width,
                            height: value.translation.height,
                            startX: value.startLocation.x
                        )
                    }
            )

            HStack(spacing: 12) {
                LegendItem(label: "On target", color: CBColors.sage)
                LegendItem(label: "Under", color: CBColors.gold)
                LegendItem(label: "Over", color: CBColors.terra)
                LegendItem(label: "No log", color: CBColors.inkFaint)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, CBSpacing.page)
            .padding(.vertical, 10)

            ScrollView {
                VStack(spacing: 12) {
                    let summary = viewModel.summary
                    CBCard {
                        HStack {
                            MetricCard(value: summary.onTarget.formatted(), label: "On target")
                            MetricCard(value: summary.under.formatted(), label: "Under")
                            MetricCard(value: summary.over.formatted(), label: "Over")
                            MetricCard(value: summary.missed.formatted(), label: "Missed")
                        }
                    }

                    if let detail = viewModel.selectedDayDetail, let date = viewModel.selectedDate {
                        Button { onOpenDay(date) } label: {
                            CBCard(background: CBColors.bgSoft) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(detail.title).font(CBTypography.body(14, weight: .semibold))
                                            .foregroundStyle(CBColors.ink)
                                        Text(verbatim: detail.totals.mealCount > 0
                                             ? "\(NutritionFormat.kcal(detail.totals.calories)) · \(detail.status.title)"
                                             : detail.status.title)
                                            .font(CBTypography.body(13)).foregroundStyle(CBColors.inkMid)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(CBColors.inkMid)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("Shows that day's meals"))
                    }
                }
                .padding(.horizontal, CBSpacing.page)
                .padding(.bottom, 96)
            }
        }
        .background(CBColors.bg)
        .navigationBarBackButtonHidden()
        .edgeSwipeBackEnabled()
    }

    private var monthControls: some View {
        HStack(spacing: 18) {
            Button(action: viewModel.previousMonth) {
                Image(systemName: "chevron.left").frame(width: 32, height: 44)
            }
            .accessibilityLabel(Text("Previous month"))
            Button(action: viewModel.nextMonth) {
                Image(systemName: "chevron.right").frame(width: 32, height: 44)
            }
            .accessibilityLabel(Text("Next month"))
        }
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(CBColors.inkMid)
        .buttonStyle(.plain)
    }
}

private struct LegendItem: View {
    let label: LocalizedStringKey
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.35))
                .overlay(RoundedRectangle(cornerRadius: 2).stroke(color, lineWidth: 1))
                .frame(width: 8, height: 8)
            Text(label)
                .font(CBTypography.body(12))
                .foregroundStyle(CBColors.inkMid)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
