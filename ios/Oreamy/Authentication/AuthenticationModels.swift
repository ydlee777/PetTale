import Foundation

struct OreamySession: Codable, Equatable {
    let userID: UUID
    let accessToken: String
    let expiresAt: Date

    var isExpired: Bool { expiresAt <= Date() }
}

enum AuthenticationState: Equatable {
    case signedOut
    case signingIn
    case signedIn(OreamySession)
    case failed(String)
}

enum AuthenticationError: Error {
    case invalidAppleCredential
    case invalidBackendResponse
}
