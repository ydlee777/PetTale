import Foundation
import SwiftData
import XCTest
@testable import Pettale

@MainActor
final class AuthenticationControllerTests: XCTestCase {
    func testInitialStateLoadsValidStoredSession() {
        let session = makeSession()
        let controller = AuthenticationController(service: FakeAuthenticationService(), store: MemorySessionStore(session: session))
        XCTAssertEqual(controller.state, .signedIn(session))
    }

    func testNonceGenerationIsRandomAndHashIsDeterministic() throws {
        let first = try AuthenticationNonce.generate()
        let second = try AuthenticationNonce.generate()
        XCTAssertNotEqual(first, second)
        XCTAssertGreaterThanOrEqual(Data(base64Encoded: first)?.count ?? 0, 32)
        XCTAssertEqual(AuthenticationNonce.sha256("nonce").count, 64)
        XCTAssertEqual(AuthenticationNonce.sha256("nonce"), AuthenticationNonce.sha256("nonce"))
    }

    func testSuccessfulBackendSessionIsStoredAndStateBecomesSignedIn() async throws {
        let session = makeSession()
        let service = FakeAuthenticationService(result: .success(session))
        let store = MemorySessionStore()
        let controller = AuthenticationController(service: service, store: store)
        _ = try controller.prepareNonce()
        await controller.completeAppleAuthorization(identityTokenData: Data("apple.jwt".utf8))
        XCTAssertEqual(controller.state, .signedIn(session))
        XCTAssertEqual(store.session, session)
        XCTAssertEqual(service.receivedToken, "apple.jwt")
        XCTAssertNotNil(service.receivedNonce)
    }

    func testFailureReturnsSignedOutDataBoundaryWithoutDeletingPet() async throws {
        let container = try PettalePersistence.makeModelContainer(inMemory: true, cloudKitEnabled: false)
        let pet = try Pet(name: "Oreo", species: .cat)
        container.mainContext.insert(pet)
        try container.mainContext.save()
        let controller = AuthenticationController(
            service: FakeAuthenticationService(result: .failure(AuthenticationError.invalidBackendResponse)),
            store: MemorySessionStore()
        )
        _ = try controller.prepareNonce()
        await controller.completeAppleAuthorization(identityTokenData: Data("bad".utf8))
        guard case .failed = controller.state else { return XCTFail("Expected failed state") }
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Pet>()).count, 1)
    }

    func testLogoutClearsStoredSession() {
        let store = MemorySessionStore(session: makeSession())
        let controller = AuthenticationController(service: FakeAuthenticationService(), store: store)
        controller.logout()
        XCTAssertEqual(controller.state, .signedOut)
        XCTAssertNil(store.session)
        XCTAssertTrue(store.didClear)
    }

    func testKeychainStoreRoundTripAndClear() throws {
        let store = KeychainSessionStore(service: "com.pettale.tests.\(UUID().uuidString)")
        defer { try? store.clear() }
        let session = makeSession()
        try store.save(session)
        let restored = try XCTUnwrap(store.load())
        XCTAssertEqual(restored.userID, session.userID)
        XCTAssertEqual(restored.accessToken, session.accessToken)
        XCTAssertEqual(restored.expiresAt.timeIntervalSince1970, session.expiresAt.timeIntervalSince1970, accuracy: 1)
        try store.clear()
        XCTAssertNil(try store.load())
    }

    private func makeSession() -> PettaleSession {
        PettaleSession(userID: UUID(), accessToken: "pettale.jwt", expiresAt: Date().addingTimeInterval(900))
    }
}

private final class MemorySessionStore: SessionStore {
    var session: PettaleSession?
    var didClear = false
    init(session: PettaleSession? = nil) { self.session = session }
    func load() throws -> PettaleSession? { session }
    func save(_ session: PettaleSession) throws { self.session = session }
    func clear() throws { session = nil; didClear = true }
}

private final class FakeAuthenticationService: AuthenticationService {
    var result: Result<PettaleSession, Error>
    var receivedToken: String?
    var receivedNonce: String?
    init(result: Result<PettaleSession, Error> = .failure(AuthenticationError.invalidBackendResponse)) { self.result = result }
    func authenticate(identityToken: String, nonce: String) async throws -> PettaleSession {
        receivedToken = identityToken
        receivedNonce = nonce
        return try result.get()
    }
}
