import Foundation
import SwiftData
import XCTest
@testable import Oreamy

@MainActor
final class PetPersistenceTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try PettalePersistence.makeModelContainer(
            inMemory: true,
            cloudKitEnabled: false
        )
    }

    func testPetCreationUsesStableIdentityAndTimestamps() throws {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let pet = try Pet(id: id, name: "  Momo  ", species: .cat, now: createdAt)

        XCTAssertEqual(pet.id, id)
        XCTAssertEqual(pet.name, "Momo")
        XCTAssertEqual(pet.species, .cat)
        XCTAssertEqual(pet.sex, .unknown)
        XCTAssertEqual(pet.createdAt, createdAt)
        XCTAssertEqual(pet.updatedAt, createdAt)
    }

    func testEmptyNameIsRejected() {
        XCTAssertThrowsError(try Pet(name: " \n ", species: .dog)) { error in
            XCTAssertEqual(error as? PetValidationError, .emptyName)
        }
    }

    func testPetPersistsAndFetchesCanonicalValues() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = try Pet(name: "Bori", species: .dog, sex: .female)

        context.insert(pet)
        try context.save()
        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<Pet>()).first)

        XCTAssertEqual(fetched.id, pet.id)
        XCTAssertEqual(fetched.species.rawValue, "DOG")
        XCTAssertEqual(fetched.sex.rawValue, "FEMALE")
    }

    func testAllSpeciesCanonicalValuesRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        for species in PetSpecies.allCases {
            context.insert(try Pet(name: species.rawValue, species: species))
        }
        try context.save()

        let values = Set(try context.fetch(FetchDescriptor<Pet>()).map(\.species))
        XCTAssertEqual(values, Set(PetSpecies.allCases))
        XCTAssertEqual(Set(PetSpecies.allCases.map(\.rawValue)), ["CAT", "DOG", "OTHER"])
    }

    func testAllSexCanonicalValuesRoundTrip() throws {
        let container = try makeContainer()
        let context = container.mainContext

        for sex in PetSex.allCases {
            context.insert(try Pet(name: sex.rawValue, species: .other, sex: sex))
        }
        try context.save()

        let values = Set(try context.fetch(FetchDescriptor<Pet>()).map(\.sex))
        XCTAssertEqual(values, Set(PetSex.allCases))
        XCTAssertEqual(Set(PetSex.allCases.map(\.rawValue)), ["MALE", "FEMALE", "UNKNOWN"])
    }

    func testUpdatePreservesIdentityAndCreationDate() throws {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = createdAt.addingTimeInterval(60)
        let pet = try Pet(id: id, name: "Momo", species: .cat, now: createdAt)

        try pet.update(
            name: "Momo II",
            species: .other,
            sex: .male,
            birthDate: nil,
            adoptionDate: nil,
            breed: " Mixed ",
            at: updatedAt
        )

        XCTAssertEqual(pet.id, id)
        XCTAssertEqual(pet.createdAt, createdAt)
        XCTAssertEqual(pet.updatedAt, updatedAt)
        XCTAssertEqual(pet.name, "Momo II")
        XCTAssertEqual(pet.species, .other)
        XCTAssertEqual(pet.sex, .male)
        XCTAssertEqual(pet.breed, "Mixed")
    }

    func testOptionalFieldsAndExternalPhotoDataPersist() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let birthDate = Date(timeIntervalSince1970: 1_000_000)
        let adoptionDate = Date(timeIntervalSince1970: 2_000_000)
        let photoData = Data([0x01, 0x02, 0x03])
        let pet = try Pet(
            name: "Nabi",
            species: .cat,
            birthDate: birthDate,
            adoptionDate: adoptionDate,
            breed: "Korean Shorthair",
            profilePhotoData: photoData
        )

        context.insert(pet)
        try context.save()
        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<Pet>()).first)

        XCTAssertEqual(fetched.birthDate, birthDate)
        XCTAssertEqual(fetched.adoptionDate, adoptionDate)
        XCTAssertEqual(fetched.breed, "Korean Shorthair")
        XCTAssertEqual(fetched.profilePhotoData, photoData)
    }

    func testDeleteRemovesPet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = try Pet(name: "Bori", species: .dog)
        context.insert(pet)
        try context.save()

        context.delete(pet)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<Pet>()).isEmpty)
    }

    func testDiskStoreRetainsPetAcrossContainerRecreation() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "Oreamy.store")
        let id = UUID()

        do {
            let container = try PettalePersistence.makeModelContainer(
                cloudKitEnabled: false,
                storeURL: storeURL
            )
            container.mainContext.insert(try Pet(id: id, name: "Duri", species: .dog))
            try container.mainContext.save()
        }

        let reopenedContainer = try PettalePersistence.makeModelContainer(
            cloudKitEnabled: false,
            storeURL: storeURL
        )
        let fetched = try XCTUnwrap(reopenedContainer.mainContext.fetch(FetchDescriptor<Pet>()).first)
        XCTAssertEqual(fetched.id, id)
    }

    func testSchemaAndContainerInitialization() throws {
        let container = try makeContainer()

        XCTAssertEqual(PettaleSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(PettaleSchemaV1.models.count, 1)
        XCTAssertNotNil(container.schema.entity(for: Pet.self))
        XCTAssertTrue(container.configurations.allSatisfy(\.isStoredInMemoryOnly))
    }
}

