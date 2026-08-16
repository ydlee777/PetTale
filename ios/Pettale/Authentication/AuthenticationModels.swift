import Foundation

struct PettaleSession: Codable, Equatable {
    let userID: UUID
    let accessToken: String
    let expiresAt: Date

    var isExpired: Bool { expiresAt <= Date() }
}

enum AuthenticationState: Equatable {
    case signedOut
    case signingIn
    case signedIn(PettaleSession)
    case failed(String)
}

enum AuthenticationError: Error {
    case invalidAppleCredential
    case invalidBackendResponse
}
