import Foundation

struct GoogleLoginRequest: Codable {
    let idToken: String
    let invitationToken: String?

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case invitationToken = "invitation_token"
    }
}

struct LoginResponse: Codable {
    let accessToken: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresAt = "expires_at"
    }
}

struct VerifyInviteRequest: Codable {
    let email: String
    let code: String
}

struct VerifyInviteResponse: Codable {
    let invitationToken: String

    enum CodingKeys: String, CodingKey {
        case invitationToken = "invitation_token"
    }
}
