import SwiftUI

struct RootView: View {
    @State private var onboarding = OnboardingViewModel()
    private let profileStore = ProfileStore.shared

    var body: some View {
        Group {
            if profileStore.onboardingComplete {
                MainTabView()
            } else {
                OnboardingFlowView(viewModel: onboarding)
            }
        }
        .background(CBColors.bg)
        .font(CBTypography.body())
    }
}

#Preview {
    RootView()
}
