import Foundation

enum AppConfig {
    /// Backend base URL injected via XCConfig -> Info.plist.
    /// Falls back to production URL if not found (e.g. unit tests without host app bundle).
    static var apiBaseURL: String {
        if let url = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !url.isEmpty,
           !url.contains("$(") { // unresolved variable -> fallback
            return url
        }
        // Fallback for tests / misconfiguration - never hardcode in APIService directly
        return "https://ourastudiobackendseoul-763614853578.asia-northeast3.run.app/api/v1"
    }
}
