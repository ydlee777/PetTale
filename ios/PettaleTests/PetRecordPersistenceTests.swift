import Foundation
import SwiftData
import XCTest
@testable import Pettale

@MainActor
final class PetRecordPersistenceTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try PettalePersistence.makeModelContainer(inMemory: true, cloudKitEnabled: false)
    }

    func testV2SchemaAndContainerInitialize() throws {
        let container = try makeContainer()
        XCTAssertEqual(PettaleSchemaV2.versionIdentifier, Schema.Version(2, 0, 0))
        XCTAssertEqual(PettaleSchemaV2.models.count, 3)
        XCTAssertEqual(PettaleMigrationPlan.schemas.count, 2)
        XCTAssertEqual(PettaleMigrationPlan.stages.count, 1)
        XCTAssertNotNil(container.schema.entity(for: Pet.self))
        XCTAssertNotNil(container.schema.entity(for: PetRecord.self))
        XCTAssertNotNil(container.schema.entity(for: PetEvent.self))
    }

    func testPetRecordCreationAndTranscriptPersistence() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = try Pet(name: "Oreo", species: .cat)
        let recordedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let record = try PetRecord(
            pet: pet,
            originalTranscript: "  오늘 오레오가 잘 먹었어.  ",
            recordedAt: recordedAt
        )
        context.insert(pet)
        context.insert(record)
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<PetRecord>()).first)
        XCTAssertEqual(fetched.originalTranscript, "오늘 오레오가 잘 먹었어.")
        XCTAssertEqual(fetched.recordedAt, recordedAt)
        XCTAssertEqual(fetched.pet?.id, pet.id)
    }

    func testEmptyTranscriptIsRejected() throws {
        let pet = try Pet(name: "Oreo", species: .cat)
        XCTAssertThrowsError(try PetRecord(pet: pet, originalTranscript: " \n ")) { error in
            XCTAssertEqual(error as? PetRecordValidationError, .emptyTranscript)
        }
    }

    func testPetRecordUpdatePreservesIdentityAndCreatedAt() throws {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = createdAt.addingTimeInterval(60)
        let pet = try Pet(name: "Oreo", species: .cat)
        let record = try PetRecord(
            id: id,
            pet: pet,
            originalTranscript: "Original",
            now: createdAt
        )
        try record.update(
            originalTranscript: "Corrected",
            recordedAt: updatedAt,
            at: updatedAt
        )
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.createdAt, createdAt)
        XCTAssertEqual(record.updatedAt, updatedAt)
        XCTAssertEqual(record.originalTranscript, "Corrected")
    }

    func testPetEventPersistsAllStructuredValues() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = try Pet(name: "Oreo", species: .cat)
        let record = try PetRecord(pet: pet, originalTranscript: "Oreo weighed 6.2 kg.")
        let occurredAt = Date(timeIntervalSince1970: 1_700_000_200)
        let event = try PetEvent(
            record: record,
            category: .weight,
            eventType: " body_weight ",
            occurredAt: occurredAt,
            numericValue: 6.2,
            unit: " kg ",
            count: 1,
            durationMinutes: 20,
            description: "  Morning measurement.  "
        )
        context.insert(pet)
        context.insert(record)
        context.insert(event)
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<PetEvent>()).first)
        XCTAssertEqual(fetched.record?.id, record.id)
        XCTAssertEqual(fetched.category, .weight)
        XCTAssertEqual(fetched.eventType, "BODY_WEIGHT")
        XCTAssertEqual(fetched.occurredAt, occurredAt)
        XCTAssertEqual(fetched.numericValue, 6.2)
        XCTAssertEqual(fetched.unit, "KG")
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.durationMinutes, 20)
        XCTAssertEqual(fetched.eventDescription, "Morning measurement.")
    }

    func testEventDefaultsOccurredAtToRecordTimeAndAllowsOptionalEventType() throws {
        let recordedAt = Date(timeIntervalSince1970: 1_700_000_300)
        let pet = try Pet(name: "Oreo", species: .cat)
        let record = try PetRecord(
            pet: pet,
            originalTranscript: "Oreo was happy.",
            recordedAt: recordedAt
        )
        let event = try PetEvent(record: record, category: .behavior, eventType: "  ")
        XCTAssertNil(event.eventType)
        XCTAssertEqual(event.occurredAt, recordedAt)
    }

    func testAllEventCategoriesRoundTripCanonicalValues() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = try Pet(name: "Oreo", species: .cat)
        let record = try PetRecord(pet: pet, originalTranscript: "Daily note")
        context.insert(pet)
        context.insert(record)
        for category in EventCategory.allCases {
            context.insert(try PetEvent(record: record, category: category))
        }
        try context.save()

        let values = Set(try context.fetch(FetchDescriptor<PetEvent>()).map(\.category))
        XCTAssertEqual(values, Set(EventCategory.allCases))
        XCTAssertEqual(Set(EventCategory.allCases.map(\.rawValue)), [
            "FOOD", "WEIGHT", "HEALTH", "MEDICATION", "ACTIVITY", "BEHAVIOR",
            "SLEEP", "GROOMING", "VET", "EVENT", "OTHER"
        ])
    }

    func testCountAndDurationRejectNegativeValues() throws {
        let pet = try Pet(name: "Oreo", species: .cat)
        let record = try PetRecord(pet: pet, originalTranscript: "Daily note")
        XCTAssertThrowsError(try PetEvent(record: record, category: .health, count: -1)) { error in
            XCTAssertEqual(error as? PetRecordValidationError, .negativeCount)
        }
        XCTAssertThrowsError(try PetEvent(record: record, category: .activity, durationMinutes: -1)) { error in
            XCTAssertEqual(error as? PetRecordValidationError, .negativeDuration)
        }
        XCTAssertNoThrow(try PetEvent(record: record, category: .health, count: 0, durationMinutes: 0))
    }

    func testPetEventUpdatePreservesIdentityAndCreatedAt() throws {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let updatedAt = createdAt.addingTimeInterval(120)
        let pet = try Pet(name: "Oreo", species: .cat)
        let record = try PetRecord(pet: pet, originalTranscript: "Daily note")
        let event = try PetEvent(id: id, record: record, category: .other, now: createdAt)
        try event.update(
            category: .activity,
            eventType: "play",
            occurredAt: updatedAt,
            numericValue: nil,
            unit: nil,
            count: nil,
            durationMinutes: 20,
            description: "Played with Creamy",
            at: updatedAt
        )
        XCTAssertEqual(event.id, id)
        XCTAssertEqual(event.createdAt, createdAt)
        XCTAssertEqual(event.updatedAt, updatedAt)
        XCTAssertEqual(event.category, .activity)
    }

    func testOneRecordOwnsMultipleEvents() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = try Pet(name: "Oreo", species: .cat)
        let record = try PetRecord(pet: pet, originalTranscript: "Oreo ate and played.")
        context.insert(pet)
        context.insert(record)
        context.insert(try PetEvent(record: record, category: .food, eventType: "ATE_WELL"))
        context.insert(try PetEvent(record: record, category: .activity, eventType: "PLAY"))
        try context.save()
        XCTAssertEqual(record.events.count, 2)
    }

    func testDeletingRecordCascadesEventsWithoutOrphans() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = try Pet(name: "Oreo", species: .cat)
        let record = try PetRecord(pet: pet, originalTranscript: "Oreo played.")
        let event = try PetEvent(record: record, category: .activity)
        context.insert(pet)
        context.insert(record)
        context.insert(event)
        try context.save()
        context.delete(record)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<PetRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PetEvent>()).isEmpty)
        XCTAssertEqual(pet.records.count, 0)
    }

    func testDeletingPetCascadesOwnedHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = try Pet(name: "Oreo", species: .cat)
        let record = try PetRecord(pet: pet, originalTranscript: "Oreo played.")
        context.insert(pet)
        context.insert(record)
        context.insert(try PetEvent(record: record, category: .activity))
        try context.save()
        context.delete(pet)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<Pet>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PetRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PetEvent>()).isEmpty)
    }

    func testMultiplePetsRemainIsolatedAndWeightQueryIsCorrect() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let oreo = try Pet(name: "Oreo", species: .cat)
        let creamy = try Pet(name: "Creamy", species: .cat)
        let oreoRecord = try PetRecord(pet: oreo, originalTranscript: "Oreo weighed 6.2 kg.")
        let creamyRecord = try PetRecord(pet: creamy, originalTranscript: "Creamy weighed 4.1 kg.")
        context.insert(oreo)
        context.insert(creamy)
        context.insert(oreoRecord)
        context.insert(creamyRecord)
        context.insert(try PetEvent(record: oreoRecord, category: .weight, numericValue: 6.2, unit: "KG"))
        context.insert(try PetEvent(record: oreoRecord, category: .food))
        context.insert(try PetEvent(record: creamyRecord, category: .weight, numericValue: 4.1, unit: "KG"))
        try context.save()

        let weights = oreo.records
            .flatMap(\.events)
            .filter { $0.category == .weight }
            .sorted { $0.occurredAt < $1.occurredAt }
        XCTAssertEqual(weights.count, 1)
        XCTAssertEqual(weights.first?.numericValue, 6.2)
        XCTAssertEqual(oreo.records.count, 1)
        XCTAssertEqual(creamy.records.count, 1)
    }

    func testRealV1StoreMigratesToV2AndAcceptsNewModels() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "Pettale.store")
        let id = UUID()
        let birthDate = Date(timeIntervalSince1970: 1_000_000)
        let adoptionDate = Date(timeIntervalSince1970: 2_000_000)
        let photo = Data([0x01, 0x02, 0x03, 0x04])

        do {
            let schema = Schema(versionedSchema: PettaleSchemaV1.self)
            let configuration = ModelConfiguration(
                "PettalePrivateData",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            let v1Container = try ModelContainer(for: schema, configurations: [configuration])
            let v1Pet = try PetV1(
                id: id,
                name: "Oreo",
                species: .cat,
                sex: .male,
                birthDate: birthDate,
                adoptionDate: adoptionDate,
                breed: "Korean Shorthair",
                profilePhotoData: photo
            )
            v1Container.mainContext.insert(v1Pet)
            try v1Container.mainContext.save()
        }

        let v2Container = try PettalePersistence.makeModelContainer(
            cloudKitEnabled: false,
            storeURL: storeURL
        )
        let context = v2Container.mainContext
        let migratedPet = try XCTUnwrap(context.fetch(FetchDescriptor<Pet>()).first)
        XCTAssertEqual(migratedPet.id, id)
        XCTAssertEqual(migratedPet.name, "Oreo")
        XCTAssertEqual(migratedPet.species, .cat)
        XCTAssertEqual(migratedPet.sex, .male)
        XCTAssertEqual(migratedPet.birthDate, birthDate)
        XCTAssertEqual(migratedPet.adoptionDate, adoptionDate)
        XCTAssertEqual(migratedPet.breed, "Korean Shorthair")
        XCTAssertEqual(migratedPet.profilePhotoData, photo)

        let record = try PetRecord(pet: migratedPet, originalTranscript: "Oreo played for twenty minutes.")
        let event = try PetEvent(record: record, category: .activity, eventType: "PLAY", durationMinutes: 20)
        context.insert(record)
        context.insert(event)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<PetRecord>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PetEvent>()).count, 1)
    }
}
