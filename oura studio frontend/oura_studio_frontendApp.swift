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
                        .environmentObject(appState.tsplPrinterService)
                } else {
                    LoginView()
                        .environmentObject(appState)
                        .environmentObject(api)
                        .environmentObject(appState.tsplPrinterService)
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
    let state = AppState()
    return LoginView()
        .environmentObject(state)
        .environmentObject(APIService.shared)
        .environmentObject(state.tsplPrinterService)
}

#Preview("Main App") {
    let state = AppState()
    return MainTabView()
        .environmentObject(state)
        .environmentObject(APIService.shared)
        .environmentObject(state.tsplPrinterService)
}
