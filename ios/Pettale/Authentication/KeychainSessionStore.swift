import Foundation
import Security

@MainActor
protocol SessionStore {
    func load() throws -> PettaleSession?
    func save(_ session: PettaleSession) throws
    func clear() throws
}

struct KeychainSessionStore: SessionStore {
    private let service: String
    private let account = "pettale-session"

    init(service: String = Bundle.main.bundleIdentifier ?? "com.pettale.app") {
        self.service = service
    }

    func load() throws -> PettaleSession? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query(returnData: true) as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw AuthenticationError.invalidBackendResponse }
        return try JSONDecoder.pettale.decode(PettaleSession.self, from: data)
    }

    func save(_ session: PettaleSession) throws {
        try clear()
        var attributes = query(returnData: false)
        attributes[kSecValueData as String] = try JSONEncoder.pettale.encode(session)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else {
            throw AuthenticationError.invalidBackendResponse
        }
    }

    func clear() throws {
        let status = SecItemDelete(query(returnData: false) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AuthenticationError.invalidBackendResponse
        }
    }

    private func query(returnData: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if returnData {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }
        return query
    }
}

private extension JSONEncoder {
    static var pettale: JSONEncoder { let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; return encoder }
}

private extension JSONDecoder {
    static var pettale: JSONDecoder { let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder }
}
