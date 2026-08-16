import Foundation
import SwiftData

enum PettaleSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static let models: [any PersistentModel.Type] = [Pet.self, PetRecord.self, PetEvent.self]

    @Model
    final class Pet {
        private(set) var id: UUID = UUID()
        private(set) var name: String = ""
        private var speciesRawValue: String = PetSpecies.other.rawValue
        private var sexRawValue: String = PetSex.unknown.rawValue
        var birthDate: Date?
        var adoptionDate: Date?
        var breed: String?
        @Attribute(.externalStorage) private(set) var profilePhotoData: Data?
        private(set) var createdAt: Date = Date()
        private(set) var updatedAt: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \PetRecord.pet)
        private(set) var records: [PetRecord] = []

        var species: PetSpecies {
            get { PetSpecies(rawValue: speciesRawValue) ?? .other }
            set { speciesRawValue = newValue.rawValue }
        }

        var sex: PetSex {
            get { PetSex(rawValue: sexRawValue) ?? .unknown }
            set { sexRawValue = newValue.rawValue }
        }

        init(
            id: UUID = UUID(),
            name: String,
            species: PetSpecies,
            sex: PetSex = .unknown,
            birthDate: Date? = nil,
            adoptionDate: Date? = nil,
            breed: String? = nil,
            profilePhotoData: Data? = nil,
            now: Date = Date()
        ) throws {
            let validatedName = try Self.validatedName(name)

            self.id = id
            self.name = validatedName
            self.speciesRawValue = species.rawValue
            self.sexRawValue = sex.rawValue
            self.birthDate = birthDate
            self.adoptionDate = adoptionDate
            self.breed = Self.normalizedOptionalText(breed)
            self.profilePhotoData = profilePhotoData
            self.createdAt = now
            self.updatedAt = now
        }

        func update(
            name: String,
            species: PetSpecies,
            sex: PetSex,
            birthDate: Date?,
            adoptionDate: Date?,
            breed: String?,
            at updatedAt: Date = Date()
        ) throws {
            self.name = try Self.validatedName(name)
            self.speciesRawValue = species.rawValue
            self.sexRawValue = sex.rawValue
            self.birthDate = birthDate
            self.adoptionDate = adoptionDate
            self.breed = Self.normalizedOptionalText(breed)
            self.updatedAt = updatedAt
        }

        func setProfilePhotoData(_ data: Data?, at updatedAt: Date = Date()) {
            profilePhotoData = data
            self.updatedAt = updatedAt
        }

        private static func validatedName(_ value: String) throws -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw PetValidationError.emptyName }
            return trimmed
        }

        private static func normalizedOptionalText(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    @Model
    final class PetRecord {
        private(set) var id: UUID = UUID()
        var pet: Pet?
        private(set) var originalTranscript: String = ""
        private(set) var recordedAt: Date = Date()
        private(set) var createdAt: Date = Date()
        private(set) var updatedAt: Date = Date()
        @Relationship(deleteRule: .cascade, inverse: \PetEvent.record)
        private(set) var events: [PetEvent] = []

        init(
            id: UUID = UUID(),
            pet: Pet,
            originalTranscript: String,
            recordedAt: Date = Date(),
            now: Date = Date()
        ) throws {
            self.id = id
            self.pet = pet
            self.originalTranscript = try Self.validatedTranscript(originalTranscript)
            self.recordedAt = recordedAt
            self.createdAt = now
            self.updatedAt = now
        }

        func update(
            originalTranscript: String,
            recordedAt: Date,
            at updatedAt: Date = Date()
        ) throws {
            self.originalTranscript = try Self.validatedTranscript(originalTranscript)
            self.recordedAt = recordedAt
            self.updatedAt = updatedAt
        }

        private static func validatedTranscript(_ value: String) throws -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw PetRecordValidationError.emptyTranscript }
            return trimmed
        }
    }

    @Model
    final class PetEvent {
        private(set) var id: UUID = UUID()
        var record: PetRecord?
        private(set) var categoryRawValue: String = EventCategory.other.rawValue
        private(set) var eventType: String?
        private(set) var occurredAt: Date = Date()
        private(set) var numericValue: Double?
        private(set) var unit: String?
        private(set) var count: Int?
        private(set) var durationMinutes: Int?
        private(set) var eventDescription: String?
        private(set) var createdAt: Date = Date()
        private(set) var updatedAt: Date = Date()

        var category: EventCategory {
            get { EventCategory(rawValue: categoryRawValue) ?? .other }
            set { categoryRawValue = newValue.rawValue }
        }

        init(
            id: UUID = UUID(),
            record: PetRecord,
            category: EventCategory,
            eventType: String? = nil,
            occurredAt: Date? = nil,
            numericValue: Double? = nil,
            unit: String? = nil,
            count: Int? = nil,
            durationMinutes: Int? = nil,
            description: String? = nil,
            now: Date = Date()
        ) throws {
            try Self.validate(count: count, durationMinutes: durationMinutes)
            self.id = id
            self.record = record
            self.categoryRawValue = category.rawValue
            self.eventType = Self.normalizedCode(eventType)
            self.occurredAt = occurredAt ?? record.recordedAt
            self.numericValue = numericValue
            self.unit = Self.normalizedCode(unit)
            self.count = count
            self.durationMinutes = durationMinutes
            self.eventDescription = Self.normalizedText(description)
            self.createdAt = now
            self.updatedAt = now
        }

        func update(
            category: EventCategory,
            eventType: String?,
            occurredAt: Date,
            numericValue: Double?,
            unit: String?,
            count: Int?,
            durationMinutes: Int?,
            description: String?,
            at updatedAt: Date = Date()
        ) throws {
            try Self.validate(count: count, durationMinutes: durationMinutes)
            self.categoryRawValue = category.rawValue
            self.eventType = Self.normalizedCode(eventType)
            self.occurredAt = occurredAt
            self.numericValue = numericValue
            self.unit = Self.normalizedCode(unit)
            self.count = count
            self.durationMinutes = durationMinutes
            self.eventDescription = Self.normalizedText(description)
            self.updatedAt = updatedAt
        }

        private static func validate(count: Int?, durationMinutes: Int?) throws {
            if let count, count < 0 { throw PetRecordValidationError.negativeCount }
            if let durationMinutes, durationMinutes < 0 { throw PetRecordValidationError.negativeDuration }
        }

        private static func normalizedCode(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed.uppercased()
        }

        private static func normalizedText(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
}

typealias Pet = PettaleSchemaV2.Pet
typealias PetRecord = PettaleSchemaV2.PetRecord
typealias PetEvent = PettaleSchemaV2.PetEvent
