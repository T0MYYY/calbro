import SwiftUI
import Charts

// MARK: - Profile Hub

struct ProfileHubView: View {
    @Bindable var navigation: AppNavigationViewModel
    let goals: GoalsViewModel
    let stats: StatsViewModel
    @State private var showEditProfile = false
    private let profileStore = ProfileStore.shared

    var body: some View {
        let profile = profileStore.profile
        ScrollView {
            VStack(spacing: 14) {
                profileHeaderCard(profile)

                CBCard {
                    TDEEBreakdownCard(items: goals.tdeeItems)
                }

                CBCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Daily macro targets")
                            .font(CBTypography.body(15, weight: .semibold))
                            .foregroundStyle(CBColors.ink)
                        HStack(spacing: 8) {
                            MacroTarget(label: "Protein", grams: profile.proteinTargetG, color: CBColors.plum)
                            MacroTarget(label: "Carbs",   grams: profile.carbTargetG,    color: CBColors.ocean)
                            MacroTarget(label: "Fat",     grams: profile.fatTargetG,     color: CBColors.gold)
                        }
                    }
                }

                CBCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Last 7 days")
                            .font(CBTypography.body(15, weight: .semibold))
                            .foregroundStyle(CBColors.ink)
                        HStack(spacing: 12) {
                            weekStat(value: stats.loggedDays.formatted(), label: "days logged", color: CBColors.sage)
                            weekStat(value: stats.averageCalories > 0 ? NutritionFormat.kcal(stats.averageCalories) : "—",
                                     label: "daily average", color: CBColors.terra)
                            weekStat(value: stats.streak.formatted(), label: "day streak", color: CBColors.plum)
                        }
                    }
                }

                Rectangle().fill(CBColors.inkFaint).frame(height: 1).padding(.horizontal)

                navRows
            }
            .padding(.horizontal, CBSpacing.page)
            .padding(.bottom, 96)
        }
        .background(CBColors.bg)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditProfile) {
            ProfileEditView(profile: profile) { profileStore.update($0) }
        }
    }

    private func profileHeaderCard(_ profile: UserProfile) -> some View {
        CBCard(background: CBColors.terra.opacity(0.04), border: CBColors.terra.opacity(0.25)) {
            HStack(spacing: 16) {
                Image(systemName: "person.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(CBColors.terra, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    PillTag(profile.goal.title, color: CBColors.terra, filled: true)
                    Text("\(profile.weightDisplay) · \(profile.heightDisplay) · \(profile.age) yrs",
                         comment: "Weight · height · age in years")
                        .font(CBTypography.body(14))
                        .foregroundStyle(CBColors.inkMid)
                    if profile.weeklyWeightChangeKg != 0 {
                        let rate = profile.weightRateDisplay(kgPerWeek: abs(profile.weeklyWeightChangeKg))
                        Text(profile.weeklyWeightChangeKg < 0 ? String(localized: "Lose ~\(rate)") : String(localized: "Gain ~\(rate)"))
                            .font(CBTypography.body(13, weight: .medium))
                            .foregroundStyle(CBColors.sage)
                    }
                }

                Spacer()

                Button("Edit") { showEditProfile = true }
                    .font(CBTypography.body(15, weight: .semibold))
                    .foregroundStyle(CBColors.terra)
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Edit profile"))
                    .accessibilityIdentifier("editProfile")
            }
        }
    }

    private var navRows: some View {
        VStack(spacing: 0) {
            navRow(title: "Weight prediction", subtitle: "When you'll reach your target weight",
                   icon: "chart.line.uptrend.xyaxis", color: CBColors.sage) {
                navigation.navigate(.prediction, in: .profile)
            }
            .accessibilityIdentifier("row.prediction")
            navRow(title: "Weight trend", subtitle: "Weigh-ins, plateau check and calibration",
                   icon: "scalemass", color: CBColors.gold) {
                navigation.navigate(.weightTrend, in: .profile)
            }
            .accessibilityIdentifier("row.weightTrend")
            navRow(title: "Apple Health & reminders", subtitle: "Body data, activity and meal alerts",
                   icon: "heart.fill", color: CBColors.ocean) {
                navigation.navigate(.integrations, in: .profile)
            }
            .accessibilityIdentifier("row.integrations")
            navRow(title: "Widgets", subtitle: "Home Screen and Lock Screen",
                   icon: "squares.below.rectangle", color: CBColors.plum) {
                navigation.navigate(.widgets, in: .profile)
            }
            .accessibilityIdentifier("row.widgets")
        }
    }

    private func navRow(title: LocalizedStringKey, subtitle: LocalizedStringKey, icon: String, color: Color,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(CBTypography.body(15, weight: .medium)).foregroundStyle(CBColors.ink)
                    Text(subtitle).font(CBTypography.body(13)).foregroundStyle(CBColors.inkMid)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(CBColors.inkMid).font(.system(size: 13))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(CBColors.inkLine).frame(height: 1) }
        }
        .buttonStyle(.plain)
    }

    private func weekStat(value: String, label: LocalizedStringKey, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(CBTypography.body(16, weight: .bold)).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(CBTypography.body(11)).foregroundStyle(CBColors.inkMid)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct MacroTarget: View {
    let label: LocalizedStringKey
    let grams: Int
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(NutritionFormat.grams(grams)).font(CBTypography.body(17, weight: .bold)).foregroundStyle(color)
            Text(label).font(CBTypography.body(11)).foregroundStyle(CBColors.inkMid)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Profile Edit Sheet

struct ProfileEditView: View {
    let onSave: (UserProfile) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var profile: UserProfile

    init(profile: UserProfile, onSave: @escaping (UserProfile) -> Void) {
        _profile = State(initialValue: profile)
        self.onSave = onSave
    }

    private var imperial: Bool { profile.units == .imperial }

    /// Height stepper in cm, or whole inches for imperial.
    private var heightBinding: Binding<Int> {
        Binding(
            get: { imperial ? Int((Double(profile.heightCentimeters) / WeightMath.cmPerInch).rounded()) : profile.heightCentimeters },
            set: { profile.heightCentimeters = imperial ? Int((Double($0) * WeightMath.cmPerInch).rounded()) : $0 }
        )
    }

    /// Weight stepper in whole kg or lb.
    private var weightBinding: Binding<Int> {
        Binding(
            get: { profile.weightInDisplayUnit(profile.weightKilograms) },
            set: { profile.weightKilograms = profile.kilograms(fromDisplayUnit: Double($0)) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Units", selection: $profile.units) {
                        ForEach(UnitSystem.allCases) { u in Text(u.title).tag(u) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Units")
                } footer: {
                    Text("Calories are always shown in kcal.")
                }

                Section("Body") {
                    Picker("Sex", selection: $profile.sex) {
                        ForEach(BiologicalSex.allCases) { s in Text(s.title).tag(s) }
                    }
                    Stepper(value: $profile.age, in: 13...99) {
                        LabeledContent("Age", value: profile.age.formatted())
                    }
                    Stepper(value: heightBinding, in: imperial ? 40...94 : 100...240) {
                        LabeledContent("Height", value: profile.heightDisplay)
                    }
                    Stepper(value: weightBinding, in: imperial ? 66...660 : 30...300) {
                        LabeledContent("Weight", value: profile.weightDisplay)
                    }
                }

                Section {
                    Picker("Goal", selection: $profile.goal) {
                        ForEach(FitnessGoal.allCases) { g in Text(g.title).tag(g) }
                    }
                    .pickerStyle(.menu)
                    Picker("Activity", selection: $profile.activityLevel) {
                        ForEach(ActivityLevel.allCases) { a in Text(a.title).tag(a) }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Goal")
                } footer: {
                    if profile.calibration != nil {
                        Text("Your maintenance calories come from your own logs, so the activity level no longer changes your target.")
                    }
                }

                Section("Diet") {
                    ForEach(DietPreference.allCases) { pref in
                        Toggle(pref.title, isOn: Binding(
                            get: { profile.dietPreferences.contains(pref) },
                            set: { on in
                                if pref == .noRestriction {
                                    if on { profile.dietPreferences = [.noRestriction] }
                                } else if on {
                                    profile.dietPreferences.insert(pref)
                                    profile.dietPreferences.remove(.noRestriction)
                                } else {
                                    profile.dietPreferences.remove(pref)
                                    if profile.dietPreferences.isEmpty { profile.dietPreferences.insert(.noRestriction) }
                                }
                            }
                        ))
                        .tint(CBColors.terra)
                    }
                }

                Section("Preview") {
                    let p = computedProfile
                    LabeledContent("BMR", value: NutritionFormat.kcal(p.bmr))
                    LabeledContent("TDEE", value: NutritionFormat.kcal(p.tdee))
                    LabeledContent("Daily target", value: NutritionFormat.kcal(p.calorieTarget))
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(CBColors.terra)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(profile)
                        dismiss()
                    }
                    .font(.body.bold())
                    .foregroundStyle(CBColors.terra)
                }
            }
        }
    }

    private var computedProfile: UserProfile {
        var p = profile
        p.recalculateTargets()
        return p
    }
}

// MARK: - Weight Prediction

struct WeightPredictionView: View {
    @Bindable var viewModel: GoalsViewModel

    private var profile: UserProfile { viewModel.profile }

    private var targetBinding: Binding<Int> {
        Binding(
            get: { profile.weightInDisplayUnit(viewModel.targetWeightKilograms) },
            set: { viewModel.setTargetWeight(displayValue: $0) }
        )
    }

    var body: some View {
        let projection = viewModel.projection
        VStack(spacing: 0) {
            NavHeader("Weight prediction", subtitle: String(localized: "From your profile and plan"), showsBack: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    CBCard(background: CBColors.sage.opacity(0.04), border: CBColors.sage.opacity(0.35)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("At this pace").font(CBTypography.body(14)).foregroundStyle(CBColors.inkMid)
                            Text(headline(projection))
                                .font(CBTypography.body(20, weight: .bold)).foregroundStyle(CBColors.ink)
                            if case .eta(_, let weeks) = projection.outcome {
                                Text("About \(Int(weeks.rounded())) weeks")
                                    .font(CBTypography.body(14)).foregroundStyle(CBColors.inkMid)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    CBCard {
                        Stepper(value: targetBinding, in: targetRange) {
                            LabeledContent("Target weight",
                                           value: UserProfile.weightString(kilograms: viewModel.targetWeightKilograms,
                                                                           units: profile.units))
                        }
                        .font(CBTypography.body(15))
                    }

                    if projection.outcome != .reached {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Scenario").font(CBTypography.body(14, weight: .semibold))
                            HStack(spacing: 8) {
                                ForEach(PredictionScenario.allCases) { scenario in
                                    ScenarioButton(title: scenario.title,
                                                   detail: NutritionFormat.kcal(scenario.dailyBalance(for: profile)),
                                                   selected: viewModel.selectedScenario == scenario) {
                                        viewModel.selectScenario(scenario)
                                    }
                                }
                            }
                            CBCard {
                                VStack(spacing: 8) {
                                    HStack {
                                        (viewModel.isGain ? Text("Daily surplus") : Text("Daily deficit"))
                                            .font(CBTypography.body(14)).foregroundStyle(CBColors.inkMid)
                                        Spacer()
                                        Text(NutritionFormat.kcal(viewModel.dailyBalance)).font(CBTypography.body(15, weight: .bold))
                                    }
                                    Slider(value: Binding(get: { Double(viewModel.dailyBalance) },
                                                          set: { viewModel.updateBalance($0) }),
                                           in: 100...1000, step: 50) {
                                        (viewModel.isGain ? Text("Daily surplus") : Text("Daily deficit"))
                                    }
                                    .tint(CBColors.terra)
                                    .accessibilityValue(Text(NutritionFormat.kcal(viewModel.dailyBalance)))
                                    HStack {
                                        Text(NutritionFormat.kcal(100))
                                        Spacer()
                                        Text(NutritionFormat.kcal(1000))
                                    }
                                    .font(CBTypography.mono(10))
                                    .foregroundStyle(CBColors.inkMid)
                                    .accessibilityHidden(true)
                                }
                            }
                        }
                    }

                    Text(calibrationNote)
                        .font(CBTypography.body(13)).foregroundStyle(CBColors.inkMid)
                    Text("Projections assume 7,700 kcal per kg, slowed slightly for metabolic adaptation. Real progress is rarely linear.")
                        .font(CBTypography.body(12)).foregroundStyle(CBColors.inkMid)
                }
                .padding(.horizontal, CBSpacing.page).padding(.bottom, 96)
            }
        }
        .background(CBColors.bg).navigationBarBackButtonHidden().edgeSwipeBackEnabled()
    }

    private var targetRange: ClosedRange<Int> {
        profile.units == .metric ? 30...250 : 66...550
    }

    private func headline(_ p: WeightProjection) -> String {
        let target = UserProfile.weightString(kilograms: p.targetKilograms, units: profile.units)
        switch p.outcome {
        case .reached:
            return String(localized: "You're at your target weight")
        case .eta(let date, _):
            let when = date.formatted(.dateTime.month(.wide).year())
            return String(localized: "Reach \(target) around \(when)")
        case .tooSlow:
            return String(localized: "More than two years to \(target) at this pace")
        }
    }

    private var calibrationNote: String {
        if let c = profile.calibration {
            return String(localized: "Maintenance calories calibrated from your logs on \(c.date.formatted(date: .abbreviated, time: .omitted)). They refresh every two weeks while you keep logging.")
        }
        return String(localized: "Maintenance calories are a formula estimate. Log meals and weigh in for two weeks to calibrate them on the Weight trend screen.")
    }
}

// MARK: - Weight Trend

struct WeightTrendView: View {
    @Bindable var viewModel: GoalsViewModel
    @State private var entryValue: Double?
    @FocusState private var entryFocused: Bool

    private var profile: UserProfile { viewModel.profile }

    private func display(_ kg: Double) -> Double {
        profile.units == .metric ? kg : kg * WeightMath.poundsPerKg
    }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader("Weight trend", showsBack: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    statusCard
                    chart
                    logCard
                    calibrationCard
                    if case .plateau = viewModel.plateau { strategies }
                    history
                }
                .padding(.horizontal, CBSpacing.page).padding(.bottom, 96)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(CBColors.bg).navigationBarBackButtonHidden().edgeSwipeBackEnabled()
    }

    // MARK: Status

    private var statusCard: some View {
        let (tag, color, title, detail) = statusText
        return CBCard(background: color.opacity(0.05), border: color.opacity(0.4)) {
            VStack(alignment: .leading, spacing: 8) {
                PillTag(tag, color: color, filled: true)
                Text(title).font(CBTypography.body(18, weight: .bold)).foregroundStyle(CBColors.ink)
                Text(detail).font(CBTypography.body(14)).foregroundStyle(CBColors.inkMid)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusText: (String, Color, String, String) {
        switch viewModel.plateau {
        case .notEnoughData:
            return (String(localized: "Not enough data"), CBColors.inkMid,
                    String(localized: "Weigh in a few times"),
                    String(localized: "Log your weight at least three times over two weeks to see your trend."))
        case .maintaining(let t):
            return (String(localized: "Maintaining"), CBColors.sage, rate(t),
                    String(localized: "Your goal is to hold steady; small swings are normal."))
        case .progressing(let t):
            return (String(localized: "On track"), CBColors.sage, rate(t),
                    String(localized: "Your weight is moving in the direction of your goal."))
        case .wrongDirection(let t):
            return (String(localized: "Off track"), CBColors.terra, rate(t),
                    String(localized: "Your weight is moving away from your goal. Check that every meal is logged."))
        case .plateau(let t):
            return (String(localized: "Plateau"), CBColors.gold, rate(t),
                    String(localized: "Almost no change over the last \(t.spanDays) days."))
        }
    }

    private func rate(_ t: WeightTrend) -> String {
        let r = profile.weightRateDisplay(kgPerWeek: abs(t.kgPerWeek))
        if abs(t.kgPerWeek) < 0.05 { return String(localized: "Stable") }
        return t.kgPerWeek < 0 ? String(localized: "Losing \(r)") : String(localized: "Gaining \(r)")
    }

    // MARK: Chart

    @ViewBuilder
    private var chart: some View {
        let cutoff = Date().adding(days: -90)
        let points = viewModel.weights.filter { $0.date >= cutoff }
        if points.count >= 2 {
            Chart(points) { entry in
                LineMark(x: .value("Date", entry.date), y: .value("Weight", display(entry.kilograms)))
                    .foregroundStyle(CBColors.terra)
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", entry.date), y: .value("Weight", display(entry.kilograms)))
                    .foregroundStyle(CBColors.terra)
                    .symbolSize(24)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 180)
            .accessibilityLabel(Text("Weight over the last 90 days"))
        }
    }

    // MARK: Log

    private var logCard: some View {
        CBCard {
            HStack(spacing: 10) {
                Text("Today's weight").font(CBTypography.body(15, weight: .medium))
                Spacer()
                TextField(profile.weightInDisplayUnit(profile.weightKilograms).formatted(),
                          value: $entryValue,
                          format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .focused($entryFocused)
                    .accessibilityLabel(Text("Today's weight"))
                    .accessibilityIdentifier("weightField")
                Text(profile.weightUnitSymbol).foregroundStyle(CBColors.inkMid).accessibilityHidden(true)
                Button("Log") {
                    guard let v = entryValue, v > 0 else { return }
                    viewModel.logWeight(displayValue: v)
                    entryValue = nil
                    entryFocused = false
                }
                .font(CBTypography.body(15, weight: .semibold))
                .foregroundStyle(CBColors.terra)
                .disabled((entryValue ?? 0) <= 0)
                .accessibilityIdentifier("logWeight")
            }
        }
    }

    // MARK: Calibration

    @ViewBuilder
    private var calibrationCard: some View {
        CBCard(background: CBColors.bgSoft) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Maintenance calories").font(CBTypography.body(15, weight: .semibold))
                if let c = profile.calibration {
                    Text("Using \(NutritionFormat.kcal(c.tdee)) from your logs (formula: \(NutritionFormat.kcal(profile.formulaTDEE))).")
                        .font(CBTypography.body(13)).foregroundStyle(CBColors.inkMid)
                    Button("Go back to the formula", action: viewModel.clearCalibration)
                        .font(CBTypography.body(14, weight: .semibold)).foregroundStyle(CBColors.terra)
                } else if let estimate = viewModel.calibrationEstimate {
                    Text("Your last \(estimate.spanDays) days suggest \(NutritionFormat.kcal(estimate.tdee)) a day (formula: \(NutritionFormat.kcal(profile.formulaTDEE))). This is only accurate if you logged everything you ate.")
                        .font(CBTypography.body(13)).foregroundStyle(CBColors.inkMid)
                    Button("Use this estimate", action: viewModel.applyCalibration)
                        .font(CBTypography.body(14, weight: .semibold)).foregroundStyle(CBColors.terra)
                } else {
                    Text("Needs two weeks of weigh-ins and at least 10 logged days in the last four weeks.")
                        .font(CBTypography.body(13)).foregroundStyle(CBColors.inkMid)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Strategies

    private var strategies: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What to try").font(CBTypography.body(15, weight: .semibold))
            StrategyRow(title: "Check your logging", subtitle: "Snacks, drinks and cooking oil are easy to miss")
            StrategyRow(title: "Take a maintenance break", subtitle: "A week at maintenance can ease diet fatigue")
            StrategyRow(title: "Move a little more", subtitle: "A daily 20-minute walk adds up")
            StrategyRow(title: "Sleep", subtitle: "Short sleep tends to increase appetite")
        }
    }

    // MARK: History

    @ViewBuilder
    private var history: some View {
        if !viewModel.weights.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Weigh-ins").font(CBTypography.body(15, weight: .semibold)).padding(.bottom, 6)
                ForEach(viewModel.weights.suffix(10).reversed()) { entry in
                    HStack {
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(CBColors.inkMid)
                        if entry.source == .health {
                            Image(systemName: "heart.fill").foregroundStyle(CBColors.terra).imageScale(.small)
                                .accessibilityLabel(Text("From Apple Health"))
                        }
                        Spacer()
                        Text(UserProfile.weightString(kilograms: entry.kilograms, units: profile.units, fractionDigits: 1))
                            .fontWeight(.medium)
                        if entry.source == .manual {
                            Menu {
                                Button(role: .destructive) { viewModel.deleteWeight(id: entry.id) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis").frame(width: 32, height: 36).contentShape(Rectangle())
                            }
                            .foregroundStyle(CBColors.inkMid)
                            .accessibilityLabel(Text("Weigh-in actions"))
                        }
                    }
                    .font(CBTypography.body(14))
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) { Rectangle().fill(CBColors.inkLine).frame(height: 1) }
                }
            }
        }
    }
}

// MARK: - Shared subviews

private struct ScenarioButton: View {
    let title: String
    let detail: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(CBTypography.body(13, weight: .semibold))
                Text(detail).font(CBTypography.body(11)).opacity(0.75)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(selected ? CBColors.controlOnFill : CBColors.ink)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(selected ? CBColors.controlFill : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? CBColors.controlFill : CBColors.inkFaint, lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct StrategyRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        CBCard {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(CBTypography.body(15, weight: .medium)).foregroundStyle(CBColors.ink)
                Text(subtitle).font(CBTypography.body(13)).foregroundStyle(CBColors.inkMid)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
