import Foundation

struct ExtractedEventDraft: Codable, Equatable, Sendable {
    var category: EventCategory
    var eventType: String?
    var occurredAt: Date
    var numericValue: Double?
    var unit: String?
    var count: Int?
    var durationMinutes: Int?
    var description: String?
}

struct EventExtractionResult: Decodable, Equatable, Sendable {
    let schemaVersion: String
    let clientPetId: UUID
    var events: [ExtractedEventDraft]
}

enum EventExtractionError: Error, Equatable {
    case quotaExceeded
    case temporarilyUnavailable
    case invalidResponse

    static func mapped(statusCode: Int, data: Data) -> EventExtractionError {
        if statusCode == 429,
           let response = try? JSONDecoder().decode(ExtractionErrorResponse.self, from: data),
           response.code == "QUOTA_EXCEEDED" {
            return .quotaExceeded
        }
        return .temporarilyUnavailable
    }
}

private struct ExtractionErrorResponse: Decodable { let code: String }

@MainActor
protocol EventExtractionService {
    func extract(
        transcript: String,
        recordedAt: Date,
        petID: UUID,
        petName: String,
        knownPetNames: [String],
        spokenLanguage: String,
        timeZone: String,
        session: PettaleSession
    ) async throws -> EventExtractionResult
}

struct BackendEventExtractionService: EventExtractionService {
    let baseURL: URL
    var urlSession: URLSession = .shared

    init(baseURL: URL = BackendAuthenticationService.configuredBaseURL, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    func extract(
        transcript: String,
        recordedAt: Date,
        petID: UUID,
        petName: String,
        knownPetNames: [String],
        spokenLanguage: String,
        timeZone: String,
        session: PettaleSession
    ) async throws -> EventExtractionResult {
        var request = URLRequest(url: baseURL.appending(path: "api/v1/ai/extractions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder.pettaleExtraction.encode(RequestBody(
            transcript: transcript,
            recordedAt: recordedAt,
            selectedPet: .init(clientPetId: petID, name: petName),
            knownPetNames: knownPetNames,
            spokenLanguage: spokenLanguage,
            timeZone: timeZone
        ))
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw EventExtractionError.invalidResponse }
        if http.statusCode == 429 {
            throw EventExtractionError.mapped(statusCode: http.statusCode, data: data)
        }
        guard http.statusCode == 200 else { throw EventExtractionError.temporarilyUnavailable }
        do {
            let result = try JSONDecoder.pettaleExtraction.decode(EventExtractionResult.self, from: data)
            guard result.schemaVersion == "1", result.clientPetId == petID, !result.events.isEmpty else {
                throw EventExtractionError.invalidResponse
            }
            return result
        } catch let error as EventExtractionError {
            throw error
        } catch {
            throw EventExtractionError.invalidResponse
        }
    }

    private struct RequestBody: Encodable {
        let transcript: String
        let recordedAt: Date
        let selectedPet: SelectedPet
        let knownPetNames: [String]
        let spokenLanguage: String
        let timeZone: String
    }
    private struct SelectedPet: Encodable { let clientPetId: UUID; let name: String }
}

private extension JSONEncoder {
    static var pettaleExtraction: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var pettaleExtraction: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: value) { return date }
            let standard = ISO8601DateFormatter()
            guard let date = standard.date(from: value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
            }
            return date
        }
        return decoder
    }
}
