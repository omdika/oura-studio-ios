import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isCheckingAuth: Bool = true
    @Published var selectedTab: Int = 0
    @Published var produksiSubTabIndex: Int = 0
    @Published var dashboardNeedsRefresh: Bool = false

    private let api: APIService

    init(api: APIService = .shared) {
        self.api = api
        checkStoredToken()
        api.onUnauthorized = { [weak self] in self?.handleUnauthorized() }
    }

    private func checkStoredToken() {
        if ProcessInfo.processInfo.arguments.contains("--uitest-bypass-auth") {
            api.useMock = true
            isAuthenticated = true
            isCheckingAuth = false
            return
        }

        // TODO: Remove this block once Google Sign-In production OAuth is fully configured.
        // Temporary dev auth: seeds a manual bearer token from the Xcode Run scheme's
        // environment variables into Keychain on every DEBUG launch — no hardcoded strings in source.
        // Setup: Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables
        //   Key: DEV_BEARER_TOKEN  Value: <paste token here>
        // Overrides any previously stored token so rotating the token in the scheme takes effect
        // immediately without needing to manually clear Keychain.
        // This is a replacement for Google Sign-In while GCP OAuth client ID is not yet set up.
        #if DEBUG
        if let devToken = ProcessInfo.processInfo.environment["DEV_BEARER_TOKEN"],
           !devToken.isEmpty {
            KeychainManager.saveToken(devToken)
        }
        #endif

        if let token = KeychainManager.loadToken() {
            api.authToken = token
            isAuthenticated = true
        }
        isCheckingAuth = false
    }

    func loginWithGoogle(idToken: String?, invitationToken: String? = nil) async throws {
        let response = try await api.loginWithGoogle(idToken: idToken, invitationToken: invitationToken)
        KeychainManager.saveToken(response.accessToken)
        api.authToken = response.accessToken
        isAuthenticated = true
    }

    // TODO: Remove when Google Sign-In production OAuth is configured.
    // Temporary dev login: called from the DEBUG token-paste field on LoginView.
    #if DEBUG
    func loginWithDevToken(_ token: String) {
        KeychainManager.saveToken(token)
        api.authToken = token
        isAuthenticated = true
    }
    #endif

    func handleUnauthorized() {
        KeychainManager.deleteToken()
        api.authToken = nil
        isAuthenticated = false
    }

    func logout() {
        KeychainManager.deleteToken()
        api.authToken = nil
        isAuthenticated = false
    }
}
