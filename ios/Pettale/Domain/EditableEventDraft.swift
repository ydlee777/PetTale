import Foundation

struct EditableEventDraft: Identifiable, Equatable, Sendable {
    let id: UUID
    var category: EventCategory
    var eventType: String
    var occurredAt: Date
    var numericValue: Double?
    var unit: String
    var count: Int?
    var durationMinutes: Int?
    var description: String

    init(
        id: UUID = UUID(),
        category: EventCategory = .other,
        eventType: String = "",
        occurredAt: Date,
        numericValue: Double? = nil,
        unit: String = "",
        count: Int? = nil,
        durationMinutes: Int? = nil,
        description: String = ""
    ) {
        self.id = id
        self.category = category
        self.eventType = eventType
        self.occurredAt = occurredAt
        self.numericValue = numericValue
        self.unit = unit
        self.count = count
        self.durationMinutes = durationMinutes
        self.description = description
    }

    init(extracted: ExtractedEventDraft) {
        self.init(
            category: extracted.category,
            eventType: extracted.eventType ?? "",
            occurredAt: extracted.occurredAt,
            numericValue: extracted.numericValue,
            unit: extracted.unit ?? "",
            count: extracted.count,
            durationMinutes: extracted.durationMinutes,
            description: extracted.description ?? ""
        )
        normalize()
    }

    mutating func normalize() {
        eventType = Self.canonicalCode(eventType)
        unit = Self.canonicalCode(unit)
        description = description.trimmingCharacters(in: .whitespacesAndNewlines)

        switch category {
        case .weight:
            eventType = "BODY_WEIGHT"
            count = nil
            durationMinutes = nil
        case .activity:
            numericValue = nil
            unit = ""
            count = nil
        case .health where eventType == "VOMITING":
            numericValue = nil
            unit = ""
            durationMinutes = nil
        default:
            break
        }
    }

    static func canonicalCode(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .uppercased(with: Locale(identifier: "en_US_POSIX"))
    }

    var localizedEventType: String {
        WorkflowPresentation.eventType(eventType)
    }
}

enum EventDraftValidationError: LocalizedError, Equatable {
    case invalidEventType
    case bodyWeightTypeRequired
    case negativeCount
    case negativeDuration
    case invalidNumericValue
    case invalidUnit
    case descriptionTooLong

    var errorDescription: String? {
        switch self {
        case .invalidEventType: String(localized: "Enter a valid canonical event type.")
        case .bodyWeightTypeRequired: String(localized: "Weight events must use Body Weight.")
        case .negativeCount: String(localized: "Count cannot be negative.")
        case .negativeDuration: String(localized: "Duration cannot be negative.")
        case .invalidNumericValue: String(localized: "Enter a valid numeric value.")
        case .invalidUnit: String(localized: "Enter a valid canonical unit.")
        case .descriptionTooLong: String(localized: "Description must be 1,000 characters or fewer.")
        }
    }
}

enum EventDraftValidator {
    static func normalized(_ draft: EditableEventDraft) throws -> EditableEventDraft {
        var value = draft
        value.normalize()
        if !value.eventType.isEmpty, !isCanonicalCode(value.eventType) {
            throw EventDraftValidationError.invalidEventType
        }
        if value.category == .weight, value.eventType != "BODY_WEIGHT" {
            throw EventDraftValidationError.bodyWeightTypeRequired
        }
        if let count = value.count, count < 0 { throw EventDraftValidationError.negativeCount }
        if let duration = value.durationMinutes, duration < 0 { throw EventDraftValidationError.negativeDuration }
        if let numeric = value.numericValue, !numeric.isFinite { throw EventDraftValidationError.invalidNumericValue }
        if !value.unit.isEmpty, !isCanonicalCode(value.unit) {
            throw EventDraftValidationError.invalidUnit
        }
        if value.description.count > 1_000 { throw EventDraftValidationError.descriptionTooLong }
        return value
    }

    private static func isCanonicalCode(_ value: String) -> Bool {
        guard (1...64).contains(value.count), let first = value.unicodeScalars.first,
              (65...90).contains(first.value) else { return false }
        return value.unicodeScalars.allSatisfy {
            (65...90).contains($0.value) || (48...57).contains($0.value) || $0.value == 95
        }
    }
}
