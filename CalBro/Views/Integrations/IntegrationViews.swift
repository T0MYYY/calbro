import SwiftUI
import WidgetKit

struct HealthKitSyncView: View {
    let viewModel: IntegrationViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            NavHeader("Health & reminders", showsBack: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CBCard(background: CBColors.bgSoft) {
                        HStack(spacing: 14) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(Color.pink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Apple Health").font(CBTypography.body(17, weight: .bold))
                                Text(healthStatus)
                                    .font(CBTypography.body(13, weight: .semibold))
                                    .foregroundStyle(viewModel.healthError == nil ? CBColors.inkMid : CBColors.terra)
                            }
                            Spacer()
                            if viewModel.isWorking { ProgressView() }
                        }
                    }

                    SectionLabel("Apple Health")
                    VStack(spacing: 0) {
                        ToggleRow(title: "Body measurements",
                                  subtitle: "Imports weight, height, age and sex, plus weight history",
                                  isOn: viewModel.health.readBody) { on in
                            Task { await viewModel.setReadBody(on) }
                        }
                        ToggleRow(title: "Active energy",
                                  subtitle: "Replaces the activity estimate in today's budget with calories burned",
                                  isOn: viewModel.health.useActiveEnergy) { on in
                            Task { await viewModel.setUseActiveEnergy(on) }
                        }
                        ToggleRow(title: "Save meals to Health",
                                  subtitle: "Writes the energy, protein, carbs and fat of each meal you log",
                                  isOn: viewModel.health.writeMeals) { on in
                            Task { await viewModel.setWriteMeals(on) }
                        }
                    }
                    .disabled(viewModel.isWorking || !viewModel.isHealthAvailable)

                    if viewModel.health.readBody {
                        Button("Import now") { Task { await viewModel.importBodyData() } }
                            .font(CBTypography.body(14, weight: .semibold))
                            .foregroundStyle(CBColors.terra)
                    }

                    SectionLabel("Reminders")
                    VStack(spacing: 0) {
                        ToggleRow(title: "Meal reminder",
                                  subtitle: "Only if nothing is logged by then",
                                  isOn: viewModel.reminders.mealReminderEnabled) { on in
                            Task { await viewModel.setMealReminder(on) }
                        }
                        if viewModel.reminders.mealReminderEnabled {
                            DatePicker("Time",
                                       selection: Binding(get: { viewModel.mealReminderTime },
                                                          set: { date in Task { await viewModel.setMealReminderTime(date) } }),
                                       displayedComponents: .hourAndMinute)
                                .font(CBTypography.body(15))
                                .padding(.vertical, 8)
                        }
                        ToggleRow(title: "Calorie warning",
                                  subtitle: "Alerts once a day at 90% of your target",
                                  isOn: viewModel.reminders.calorieWarningEnabled) { on in
                            Task { await viewModel.setCalorieWarning(on) }
                        }
                    }

                    if viewModel.notificationPermission == .denied {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notifications are turned off for CalBro.")
                                .font(CBTypography.body(13)).foregroundStyle(CBColors.terra)
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                            .font(CBTypography.body(14, weight: .semibold))
                            .foregroundStyle(CBColors.terra)
                        }
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

    private var healthStatus: String {
        if let error = viewModel.healthError { return error }
        if !viewModel.isHealthAvailable { return String(localized: "Not available on this device") }
        guard viewModel.health.anyEnabled else { return String(localized: "Off") }
        if viewModel.health.useActiveEnergy, let kcal = viewModel.todayActiveEnergy {
            return String(localized: "On · \(NutritionFormat.kcal(kcal)) burned today")
        }
        if let date = viewModel.lastHealthImport {
            return String(localized: "On · imported \(date.formatted(.relative(presentation: .named)))")
        }
        return String(localized: "On")
    }
}

private struct ToggleRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: { onChange($0) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CBTypography.body(16, weight: .medium))
                    .foregroundStyle(CBColors.ink)
                Text(subtitle)
                    .font(CBTypography.body(13))
                    .foregroundStyle(CBColors.inkMid)
            }
        }
        .toggleStyle(.switch)
        .tint(CBColors.terra)
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Rectangle().fill(CBColors.inkLine).frame(height: 1)
        }
    }
}

// MARK: - Widgets

/// Renders the real widget views with today's data.
struct WidgetPreviewView: View {
    @State private var snapshot: WidgetNutritionSnapshot = .empty()
    private let mealStore = MealLogStore.shared

    var body: some View {
        VStack(spacing: 0) {
            NavHeader("Widgets", showsBack: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Touch and hold the Home Screen, tap Edit › Add Widget, then search for CalBro.")
                        .font(CBTypography.body(13))
                        .foregroundStyle(CBColors.inkMid)

                    SectionLabel("Lock Screen")
                    HStack(spacing: 18) {
                        NutritionWidgetFace(family: .accessoryCircular, snapshot: snapshot)
                            .frame(width: 72, height: 72)
                        NutritionWidgetFace(family: .accessoryRectangular, snapshot: snapshot)
                            .frame(width: 170, height: 72, alignment: .leading)
                    }
                    .foregroundStyle(.white)
                    .environment(\.colorScheme, .dark)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: 0x1b2438))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    SectionLabel("Home Screen")
                    HStack(alignment: .top, spacing: 14) {
                        widgetTile(.systemSmall, width: 158)
                        Spacer(minLength: 0)
                    }
                    widgetTile(.systemMedium, width: nil)
                }
                .padding(.horizontal, CBSpacing.page)
                .padding(.bottom, 96)
            }
        }
        .background(CBColors.bg)
        .navigationBarBackButtonHidden()
        .edgeSwipeBackEnabled()
        .task(id: mealStore.totalsForToday()) {
            mealStore.syncWidget()
            snapshot = SharedNutritionStore.load()
        }
    }

    private func widgetTile(_ family: WidgetFamily, width: CGFloat?) -> some View {
        NutritionWidgetFace(family: family, snapshot: snapshot)
            .padding(16)
            .frame(width: width, height: 158)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .background(WidgetPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}
