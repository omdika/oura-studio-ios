import SwiftUI
import GoogleSignIn

@main
struct OuraStudioApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var api = APIService.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isCheckingAuth {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if appState.isAuthenticated {
                    MainTabView()
                        .environmentObject(appState)
                        .environmentObject(api)
                } else {
                    LoginView()
                        .environmentObject(appState)
                        .environmentObject(api)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: appState.isAuthenticated)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}

#Preview("Login Screen") {
    LoginView()
        .environmentObject(AppState())
        .environmentObject(APIService.shared)
}

#Preview("Main App") {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(APIService.shared)
}
