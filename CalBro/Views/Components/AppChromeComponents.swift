import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(CBColors.terra)
                .frame(width: 58, height: 58)
                .contentShape(Circle())
        }
        .buttonStyle(.cbPressable)
        .cbGlass(.regular, cornerRadius: 29, tint: CBColors.terra.opacity(0.22), interactive: true)
        .shadow(color: CBColors.ink.opacity(0.14), radius: 16, x: 0, y: 8)
        .accessibilityLabel(Text("Scan a meal"))
        .accessibilityIdentifier("scanMeal")
    }
}

struct NavHeader<Trailing: View>: View {
    let title: Text
    var subtitle: String?
    var showsBack = false
    @ViewBuilder var trailing: Trailing
    @Environment(\.dismiss) private var dismiss

    init(_ title: LocalizedStringKey, subtitle: String? = nil, showsBack: Bool = false,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = Text(title)
        self.subtitle = subtitle
        self.showsBack = showsBack
        self.trailing = trailing()
    }

    init(verbatim title: String, subtitle: String? = nil, showsBack: Bool = false,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = Text(title)
        self.subtitle = subtitle
        self.showsBack = showsBack
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 8) {
            if showsBack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CBColors.inkMid)
                        .frame(width: 32, height: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.cbPressable)
                .accessibilityLabel(Text("Back"))
                .accessibilityIdentifier("back")
            }
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(CBTypography.title(22))
                    .foregroundStyle(CBColors.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(CBTypography.body(13))
                        .foregroundStyle(CBColors.inkMid)
                }
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, CBSpacing.page)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}

struct WeekStrip: View {
    let monthLabel: String
    let streakLabel: String
    let days: [WeekDay]
    let selectedDate: Date
    let onSelect: (Date) -> Void
    var onOpenCalendar: () -> Void = {}

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onOpenCalendar) {
                    HStack(spacing: 4) {
                        Text(monthLabel)
                        Image(systemName: "calendar").imageScale(.small)
                    }
                    .frame(minHeight: 44)
                    .font(CBTypography.body(13, weight: .medium))
                    .foregroundStyle(CBColors.inkMid)
                }
                .buttonStyle(.cbPressable)
                .accessibilityHint(Text("Opens the monthly calendar"))
                .accessibilityIdentifier("openCalendar")
                Spacer()
                Text(streakLabel)
                    .font(CBTypography.body(13, weight: .semibold))
                    .foregroundStyle(CBColors.terra)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            HStack {
                ForEach(days) { day in
                    dayButton(day)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CBColors.inkFaint).frame(height: 1)
        }
    }

    private func dayButton(_ day: WeekDay) -> some View {
        let isSelected = Calendar.current.isDate(day.date, inSameDayAs: selectedDate)
        return Button {
            onSelect(day.date)
        } label: {
            VStack(spacing: 4) {
                Text(day.symbol)
                    .font(CBTypography.body(11, weight: .medium))
                    .foregroundStyle(isSelected ? CBColors.terra : CBColors.inkMid)
                Text(day.dayNumber.formatted())
                    .font(CBTypography.body(15, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.white : (day.isFuture ? CBColors.inkMid : CBColors.ink))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(isSelected ? CBColors.terra : CBColors.inkFaint.opacity(0.45)))
                    .clipShape(Circle())
                Circle()
                    .fill(day.status.colorKey.map(CBColors.nutrition) ?? .clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.cbPressable)
        .disabled(day.isFuture)
        .accessibilityLabel(Text(day.date.formatted(date: .complete, time: .omitted)))
        .accessibilityValue(Text(day.isFuture ? "" : day.status.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct CalendarDayCell: View {
    let day: Int?
    let status: NutritionColorKey?
    let isToday: Bool
    let isSelected: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(background)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: border == .clear ? 0 : 1))
                VStack(spacing: 2) {
                    if let day {
                        Text(day.formatted())
                            .font(CBTypography.body(14, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? CBColors.controlOnFill : CBColors.ink)
                        if let status, !isToday {
                            Circle()
                                .fill(CBColors.nutrition(status))
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.cbPressable)
        .disabled(day == nil)
        .accessibilityHidden(day == nil)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var background: Color {
        if isToday { return CBColors.controlFill }
        if isSelected { return CBColors.terra.opacity(0.14) }
        if let status { return CBColors.nutrition(status).opacity(0.13) }
        return .clear
    }

    private var border: Color {
        if isSelected { return CBColors.terra.opacity(0.55) }
        if let status { return CBColors.nutrition(status).opacity(0.28) }
        return .clear
    }
}

struct TrendBarChart: View {
    let bars: [TrendBar]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily calories vs. target")
                .font(CBTypography.body(13))
                .foregroundStyle(CBColors.inkMid)
            ZStack(alignment: .top) {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(CBColors.terra.opacity(0.35))
                    .frame(height: 1)
                    .offset(y: 4)
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(bars) { bar in
                        VStack(spacing: 4) {
                            Text(bar.valueLabel)
                                .font(CBTypography.mono(9))
                                .foregroundStyle(bar.progress > 1.1 ? CBColors.terra : CBColors.inkMid)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(bar.isToday ? CBColors.terra : (bar.progress > 1.1 ? CBColors.terra.opacity(0.55) : CBColors.sage.opacity(0.55)))
                                .frame(height: max(CGFloat(min(bar.progress, 1.15)) * 90, bar.consumed > 0 ? 3 : 0))
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(bar.isToday ? CBColors.terra : .clear, lineWidth: 1.5))
                            Text(bar.day)
                                .font(CBTypography.body(11, weight: bar.isToday ? .bold : .regular))
                                .foregroundStyle(bar.isToday ? CBColors.ink : CBColors.inkMid)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(bar.accessibilityDay))
                        .accessibilityValue(Text(bar.consumed > 0 ? NutritionFormat.kcal(bar.consumed) : String(localized: "No log")))
                    }
                }
                .frame(height: 122, alignment: .bottom)
            }
        }
    }
}

struct TDEEBreakdownCard: View {
    let items: [TDEEItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calorie budget")
                .font(CBTypography.body(15, weight: .semibold))
                .foregroundStyle(CBColors.ink)
            ForEach(items) { item in
                VStack(spacing: 3) {
                    HStack {
                        Text(item.label)
                            .font(CBTypography.body(13, weight: item.colorKey == .terra ? .bold : .regular))
                            .foregroundStyle(item.colorKey == .terra ? CBColors.ink : CBColors.inkMid)
                        Spacer()
                        Text(item.value)
                            .font(CBTypography.body(13, weight: .semibold))
                            .foregroundStyle(item.colorKey == .terra ? CBColors.terra : CBColors.ink)
                    }
                    ProgressBar(progress: item.progress, color: CBColors.nutrition(item.colorKey), height: 5)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Section caption used above grouped rows.
struct SectionLabel: View {
    let text: Text

    init(_ key: LocalizedStringKey) { text = Text(key) }

    var body: some View {
        text
            .textCase(.uppercase)
            .font(CBTypography.body(12, weight: .medium))
            .foregroundStyle(CBColors.inkMid)
            .accessibilityAddTraits(.isHeader)
    }
}
