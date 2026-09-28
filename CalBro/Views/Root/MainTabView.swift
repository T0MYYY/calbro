import SwiftUI

struct MainTabView: View {
    @State private var nav       = AppNavigationViewModel()
    @State private var dashboard = DashboardViewModel()
    @State private var calendar  = CalendarViewModel()
    @State private var stats     = StatsViewModel()
    @State private var goals     = GoalsViewModel()
    private let integrations = IntegrationViewModel.shared

    var body: some View {
        @Bindable var nav = nav

        TabView(selection: $nav.selectedTab) {
            Tab("Today", systemImage: AppTab.today.symbol, value: AppTab.today) {
                NavigationStack(path: $nav.todayPath) {
                    DashboardView(viewModel: dashboard, navigation: nav)
                        .navigationDestination(for: AppRoute.self) { destination(for: $0) }
                }
            }
            Tab("Stats", systemImage: AppTab.stats.symbol, value: AppTab.stats) {
                NavigationStack(path: $nav.statsPath) {
                    StatsCaloriesView(viewModel: stats, navigation: nav)
                        .navigationDestination(for: AppRoute.self) { destination(for: $0) }
                }
            }
            Tab("Profile", systemImage: AppTab.profile.symbol, value: AppTab.profile) {
                NavigationStack(path: $nav.profilePath) {
                    ProfileHubView(navigation: nav, goals: goals, stats: stats)
                        .navigationDestination(for: AppRoute.self) { destination(for: $0) }
                }
            }
        }
        .fullScreenCover(item: $nav.presentedSheet) { _ in
            CameraFlowView(onClose: { nav.dismissSheet() })
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .nutrition:    NutritionDetailView(viewModel: dashboard)
        case .calendar:     CalendarMonthView(viewModel: calendar, onOpenDay: openDay)
        case .weeklyReport: StatsReportView(stats: stats)
        case .prediction:   WeightPredictionView(viewModel: goals)
        case .weightTrend:  WeightTrendView(viewModel: goals)
        case .integrations: HealthKitSyncView(viewModel: integrations)
        case .widgets:      WidgetPreviewView()
        }
    }

    /// From the calendar: show that day on the Today tab.
    private func openDay(_ date: Date) {
        dashboard.select(date)
        nav.todayPath = [.nutrition]
        nav.selectedTab = .today
    }
}
