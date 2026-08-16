import Foundation
import Observation

@MainActor
@Observable
final class AuthenticationController {
    private(set) var state: AuthenticationState
    private(set) var currentNonce: String?
    private let service: AuthenticationService
    private let store: SessionStore

    init(service: AuthenticationService = BackendAuthenticationService(), store: SessionStore = KeychainSessionStore()) {
        self.service = service
        self.store = store
        if let session = try? store.load(), !session.isExpired {
            state = .signedIn(session)
        } else {
            state = .signedOut
        }
    }

    func prepareNonce() throws -> String {
        let nonce = try AuthenticationNonce.generate()
        currentNonce = nonce
        return AuthenticationNonce.sha256(nonce)
    }

    func completeAppleAuthorization(identityTokenData: Data) async {
        guard let nonce = currentNonce,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            state = .failed(String(localized: "Sign in failed. Please try again."))
            return
        }
        currentNonce = nil
        state = .signingIn
        do {
            let session = try await service.authenticate(identityToken: identityToken, nonce: nonce)
            try store.save(session)
            state = .signedIn(session)
        } catch {
            state = .failed(String(localized: "Sign in failed. Please try again."))
        }
    }

    func cancelAppleAuthorization() {
        currentNonce = nil
        if case .signedIn = state { return }
        state = .signedOut
    }

    func logout() {
        try? store.clear()
        currentNonce = nil
        state = .signedOut
    }
}
