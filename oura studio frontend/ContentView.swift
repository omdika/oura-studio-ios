import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isCheckingAuth {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(OuraTheme.Colors.background)
            } else if appState.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: appState.isAuthenticated)
    }
}
