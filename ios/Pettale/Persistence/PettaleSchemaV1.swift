import Foundation
import SwiftData

enum PettaleSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static let models: [any PersistentModel.Type] = [Pet.self]

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
            guard !trimmed.isEmpty else {
                throw PetValidationError.emptyName
            }
            return trimmed
        }

        private static func normalizedOptionalText(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
}

typealias PetV1 = PettaleSchemaV1.Pet
