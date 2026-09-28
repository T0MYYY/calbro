import SwiftUI

@main
struct CalBroApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        IntegrationViewModel.shared.connect()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                    Task { await IntegrationViewModel.shared.refresh() }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await IntegrationViewModel.shared.refresh() }
            }
        }
    }
}
