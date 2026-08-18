import Foundation
import SwiftData
import XCTest
@testable import Oreamy

@MainActor
final class PetRecordPersistenceTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try PettalePersistence.makeModelContainer(inMemory: true, cloudKitEnabled: false)
    }

    func testV4SchemaAndContainerInitialize() throws {
        let container = try makeContainer()
        XCTAssertEqual(PettaleSchemaV3.versionIdentifier, Schema.Version(3, 0, 0))
        XCTAssertEqual(PettaleSchemaV4.versionIdentifier, Schema.Version(4, 0, 0))
        XCTAssertEqual(PettaleSchemaV4.models.count, 3)
        XCTAssertEqual(PettaleMigrationPlan.schemas.count, 4)
        XCTAssertEqual(PettaleMigrationPlan.stages.count, 3)
        XCTAssertNotNil(container.schema.entity(for: Pet.self))
        XCTAssertNotNil(container.schema.entity(for: PetRecord.self))
        XCTAssertNotNil(container.schema.entity(for: PetEvent.self))
    }

    func testCloudKitCompatibleContainerInitializes() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertNoThrow(try PettalePersistence.makeModelContainer(
            cloudKitEnabled: true,
            storeURL: directory.appending(path: "CloudKitCompatible.store")
        ))
    }

    func testPetRecordCreationAndTranscriptPersistence() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = try Pet(name: "Oreo", species: .cat)
        let recordedAt = Date(timeIntervalSince1970: 1_700_000_100)
        let record = try PetRecord(
            pet: pet,
            originalTranscript: "  오늘 오레오가 잘 먹었어.  ",
            diaryText: "  오늘 오레오는 잘 먹었어요.  ",
            recordedAt: recordedAt
        )
        context.insert(pet)
        context.insert(record)
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<PetRecord>()).first)
        XCTAssertEqual(fetched.originalTranscript, "오늘 오레오가 잘 먹었어.")
        XCTAssertEqual(fetched.diaryText, "오늘 오레오는 잘 먹었어요.")
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
        XCTAssertEqual(record.events?.count, 2)
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
        XCTAssertEqual(pet.records?.count, 0)
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

        let oreoRecords: [PetRecord] = oreo.records ?? []
        let oreoEvents: [PetEvent] = oreoRecords.flatMap { $0.events ?? [] }
        let weights = oreoEvents
            .filter { $0.category == .weight }
            .sorted { $0.occurredAt < $1.occurredAt }
        XCTAssertEqual(weights.count, 1)
        XCTAssertEqual(weights.first?.numericValue, 6.2)
        XCTAssertEqual(oreo.records?.count, 1)
        XCTAssertEqual(creamy.records?.count, 1)
    }

    func testRealV1StoreMigratesToV2AndAcceptsNewModels() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "Oreamy.store")
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

    func testExistingV2StoreMigratesToCloudKitCompatibleV3() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "OreamyV2.store")
        let petID = UUID()

        do {
            let schema = Schema(versionedSchema: PettaleSchemaV2.self)
            let configuration = ModelConfiguration("PettalePrivateData", schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let pet = try PettaleSchemaV2.Pet(id: petID, name: "Oreo", species: .cat)
            let record = try PettaleSchemaV2.PetRecord(pet: pet, originalTranscript: "Existing V2 record")
            container.mainContext.insert(pet)
            container.mainContext.insert(record)
            try container.mainContext.save()
        }

        let migrated = try PettalePersistence.makeModelContainer(cloudKitEnabled: false, storeURL: storeURL)
        let pets = try migrated.mainContext.fetch(FetchDescriptor<Pet>())
        let records = try migrated.mainContext.fetch(FetchDescriptor<PetRecord>())
        XCTAssertEqual(pets.first?.id, petID)
        XCTAssertEqual(records.first?.originalTranscript, "Existing V2 record")
    }

    func testRealV3StoreMigratesToV4AndPreservesGraphThenPersistsDiary() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "OreamyV3.store")
        let petID = UUID()
        let recordID = UUID()
        let eventID = UUID()
        let photo = Data([0x01, 0x02, 0x03])

        do {
            let schema = Schema(versionedSchema: PettaleSchemaV3.self)
            let configuration = ModelConfiguration("PettalePrivateData", schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let pet = try PettaleSchemaV3.Pet(id: petID, name: "Oreo", species: .cat, profilePhotoData: photo)
            let record = try PettaleSchemaV3.PetRecord(id: recordID, pet: pet, originalTranscript: "Oreo played.")
            let event = try PettaleSchemaV3.PetEvent(id: eventID, record: record, category: .activity, eventType: "PLAY", durationMinutes: 20)
            container.mainContext.insert(pet)
            container.mainContext.insert(record)
            container.mainContext.insert(event)
            try container.mainContext.save()
        }

        do {
            let migrated = try PettalePersistence.makeModelContainer(cloudKitEnabled: false, storeURL: storeURL)
            let pet = try XCTUnwrap(migrated.mainContext.fetch(FetchDescriptor<Pet>()).first)
            let oldRecord = try XCTUnwrap(migrated.mainContext.fetch(FetchDescriptor<PetRecord>()).first)
            let oldEvent = try XCTUnwrap(migrated.mainContext.fetch(FetchDescriptor<PetEvent>()).first)
            XCTAssertEqual(pet.id, petID)
            XCTAssertEqual(pet.profilePhotoData, photo)
            XCTAssertEqual(oldRecord.id, recordID)
            XCTAssertEqual(oldRecord.originalTranscript, "Oreo played.")
            XCTAssertNil(oldRecord.diaryText)
            XCTAssertEqual(oldRecord.pet?.id, petID)
            XCTAssertEqual(oldEvent.id, eventID)
            XCTAssertEqual(oldEvent.record?.id, recordID)
            XCTAssertEqual(oldEvent.eventType, "PLAY")
            migrated.mainContext.insert(try PetRecord(pet: pet, originalTranscript: "Oreo ate.", diaryText: "Oreo ate well today."))
            try migrated.mainContext.save()
        }

        let reopened = try PettalePersistence.makeModelContainer(cloudKitEnabled: false, storeURL: storeURL)
        let diaries = try reopened.mainContext.fetch(FetchDescriptor<PetRecord>()).compactMap(\.diaryText)
        XCTAssertEqual(diaries, ["Oreo ate well today."])
    }
}
