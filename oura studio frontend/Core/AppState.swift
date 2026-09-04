import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isCheckingAuth: Bool = true
    @Published var selectedTab: Int = 0
    @Published var produksiSubTabIndex: Int = 0
    @Published var dashboardNeedsRefresh: Bool = false
    @Published var currentUserEmail: String? = nil
    @Published var currentUserRole: String? = nil

    private let api: APIService

    init(api: APIService = .shared) {
        self.api = api
        checkStoredToken()
        api.onUnauthorized = { [weak self] in self?.handleUnauthorized() }
    }

    private func checkStoredToken() {
        if ProcessInfo.processInfo.arguments.contains("--uitest-bypass-auth") {
            api.useMock = true
            currentUserEmail = "admin@ourastudio.com"
            currentUserRole = "admin"
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
            updateCurrentUser(from: token)
            isAuthenticated = true
        }
        isCheckingAuth = false
    }

    func loginWithGoogle(idToken: String?, invitationToken: String? = nil) async throws {
        let response = try await api.loginWithGoogle(idToken: idToken, invitationToken: invitationToken)
        KeychainManager.saveToken(response.accessToken)
        api.authToken = response.accessToken
        updateCurrentUser(from: response.accessToken)
        isAuthenticated = true
    }

    // TODO: Remove when Google Sign-In production OAuth is configured.
    // Temporary dev login: called from the DEBUG token-paste field on LoginView.
    #if DEBUG
    func loginWithDevToken(_ token: String) {
        KeychainManager.saveToken(token)
        api.authToken = token
        updateCurrentUser(from: token)
        isAuthenticated = true
    }
    #endif

    func handleUnauthorized() {
        KeychainManager.deleteToken()
        api.authToken = nil
        updateCurrentUser(from: nil)
        isAuthenticated = false
    }

    func logout() {
        KeychainManager.deleteToken()
        api.authToken = nil
        updateCurrentUser(from: nil)
        isAuthenticated = false
    }

    private func updateCurrentUser(from token: String?) {
        guard let token = token, let claims = token.decodeJWTClaims() else {
            currentUserEmail = nil
            currentUserRole = nil
            return
        }
        currentUserEmail = claims["email"] as? String
        currentUserRole = claims["role"] as? String
    }
}

// MARK: - JWT Decoder Extension

extension String {
    func decodeJWTClaims() -> [String: Any]? {
        let parts = self.components(separatedBy: ".")
        guard parts.count > 1 else { return nil }
        
        let payloadPart = parts[1]
        var base64 = payloadPart
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Pad base64 string
        let padding = base64.count % 4
        if padding > 0 {
            base64 += String(repeating: "=", count: 4 - padding)
        }
        
        guard let data = Data(base64Encoded: base64) else { return nil }
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            return json
        } catch {
            return nil
        }
    }
}
