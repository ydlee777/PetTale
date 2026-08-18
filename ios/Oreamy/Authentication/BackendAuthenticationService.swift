import Foundation

@MainActor
protocol AuthenticationService {
    func authenticate(identityToken: String, nonce: String) async throws -> OreamySession
}

struct BackendAuthenticationService: AuthenticationService {
    let baseURL: URL
    var urlSession: URLSession = .shared

    init(
        baseURL: URL = BackendAuthenticationService.configuredBaseURL,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    func authenticate(identityToken: String, nonce: String) async throws -> OreamySession {
        var request = URLRequest(url: baseURL.appending(path: "api/v1/auth/apple"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(identityToken: identityToken, nonce: nonce))
        let (data, response) = try await urlSession.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw AuthenticationError.invalidBackendResponse
        }
        let decoded = try JSONDecoder.oreamyAuth.decode(ResponseBody.self, from: data)
        return OreamySession(userID: decoded.userId, accessToken: decoded.accessToken, expiresAt: decoded.expiresAt)
    }

    private struct RequestBody: Encodable { let identityToken: String; let nonce: String }
    private struct ResponseBody: Decodable { let userId: UUID; let accessToken: String; let expiresAt: Date }

    static var configuredBaseURL: URL {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "OREAMYAPIBaseURL") as? String,
            let url = URL(string: value)
        else {
            preconditionFailure("OREAMYAPIBaseURL must contain a valid backend URL")
        }
        return url
    }
}

private extension JSONDecoder {
    static var oreamyAuth: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { container in
            let value = try container.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let standard = ISO8601DateFormatter()
            guard let date = standard.date(from: value) else {
                throw DecodingError.dataCorruptedError(in: try container.singleValueContainer(), debugDescription: "Invalid ISO-8601 date")
            }
            return date
        }
        return decoder
    }
}
