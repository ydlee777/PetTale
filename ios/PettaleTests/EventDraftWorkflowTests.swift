import Foundation
import SwiftData
import XCTest
@testable import Pettale

@MainActor
final class EventDraftWorkflowTests: XCTestCase {
    func testSemanticPlayLocalizationsAreDistinct() {
        let korean = Locale(identifier: "ko")
        let english = Locale(identifier: "en")
        let bundle = Bundle.main
        XCTAssertEqual(WorkflowPresentation.audioPlay(locale: korean, bundle: bundle), "재생")
        XCTAssertEqual(WorkflowPresentation.eventType("PLAY", locale: korean, bundle: bundle), "놀이")
        XCTAssertNotEqual(WorkflowPresentation.audioPlay(locale: korean, bundle: bundle), WorkflowPresentation.eventType("PLAY", locale: korean, bundle: bundle))
        XCTAssertEqual(WorkflowPresentation.audioPlay(locale: english, bundle: bundle), "Play")
        XCTAssertEqual(WorkflowPresentation.eventType("PLAY", locale: english, bundle: bundle), "Play")
    }

    func testQuotaCodeMapsToLocalizedClientMessageWithoutUsingBackendMessage() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "code": "QUOTA_EXCEEDED",
            "message": "RAW BACKEND ENGLISH MUST NOT BE SHOWN"
        ])
        XCTAssertEqual(EventExtractionError.mapped(statusCode: 429, data: data), .quotaExceeded)
        XCTAssertEqual(WorkflowPresentation.quotaMessage(locale: Locale(identifier: "ko"), bundle: .main), "이번 달 AI 사용 한도에 도달했어요.")
        XCTAssertFalse(WorkflowPresentation.quotaMessage(locale: Locale(identifier: "ko"), bundle: .main).contains("RAW"))
        XCTAssertEqual(EventExtractionError.mapped(statusCode: 429, data: Data("{}".utf8)), .temporarilyUnavailable)
    }

    func testLanguagePreferenceDefaultsAndPersistsWithoutSwiftData() throws {
        let suite = "TranscriptionLanguagePreferenceTests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(TranscriptionLanguagePreference.load(defaults: defaults, preferredLanguages: ["ko-KR"]), .korean)
        XCTAssertEqual(TranscriptionLanguagePreference.load(defaults: defaults, preferredLanguages: ["en-US"]), .english)
        TranscriptionLanguagePreference.save(.korean, defaults: defaults)
        XCTAssertEqual(TranscriptionLanguagePreference.load(defaults: defaults, preferredLanguages: ["en-US"]), .korean)

        let container = try makeContainer()
        XCTAssertEqual(PettaleSchemaV3.versionIdentifier, Schema.Version(3, 0, 0))
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<PetRecord>()).isEmpty)
    }

    func testExtractionMapsToIndependentEditableDraft() {
        let extracted = ExtractedEventDraft(
            category: .weight,
            eventType: "body_weight",
            occurredAt: Date(timeIntervalSince1970: 100),
            numericValue: 6.2,
            unit: "kg",
            count: nil,
            durationMinutes: nil,
            description: " Morning weight "
        )
        var editable = EditableEventDraft(extracted: extracted)
        editable.numericValue = 6.4
        editable.description = "Corrected"

        XCTAssertEqual(extracted.numericValue, 6.2)
        XCTAssertEqual(extracted.description, " Morning weight ")
        XCTAssertEqual(editable.eventType, "BODY_WEIGHT")
        XCTAssertEqual(editable.unit, "KG")
    }

    func testDraftEditingAndCategoryNormalizationAreTransient() throws {
        let container = try makeContainer()
        var draft = EditableEventDraft(category: .health, eventType: "VOMITING", occurredAt: .now, count: 1)
        draft.category = .activity
        draft.eventType = " play "
        draft.durationMinutes = 20
        draft.description = " Played with Creamy "
        let normalized = try EventDraftValidator.normalized(draft)

        XCTAssertEqual(normalized.eventType, "PLAY")
        XCTAssertEqual(normalized.durationMinutes, 20)
        XCTAssertEqual(normalized.description, "Played with Creamy")
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<PetRecord>()).isEmpty)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<PetEvent>()).isEmpty)
    }

    func testWeightAndStructuredValueSemanticsAreDeterministic() throws {
        var weight = EditableEventDraft(
            category: .weight,
            eventType: "WEIGHT",
            occurredAt: .now,
            numericValue: 6.2,
            unit: "kg",
            count: 4,
            durationMinutes: 10
        )
        weight.normalize()
        XCTAssertEqual(weight.eventType, "BODY_WEIGHT")
        XCTAssertEqual(weight.unit, "KG")
        XCTAssertNil(weight.count)
        XCTAssertNil(weight.durationMinutes)

        let activity = try EventDraftValidator.normalized(.init(
            category: .activity,
            eventType: "PLAY",
            occurredAt: .now,
            numericValue: 20,
            unit: "MINUTES",
            durationMinutes: 20
        ))
        XCTAssertNil(activity.numericValue)
        XCTAssertTrue(activity.unit.isEmpty)
        XCTAssertEqual(activity.durationMinutes, 20)
    }

    func testOneTranscriptAndMultipleEventsSaveAtomicallyForRecordingPet() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let oreo = try Pet(name: "Oreo", species: .cat)
        let creamy = try Pet(name: "Creamy", species: .cat)
        context.insert(oreo)
        context.insert(creamy)
        try context.save()
        let recordedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let vomitingAt = recordedAt.addingTimeInterval(-3_600)
        let drafts = [
            EditableEventDraft(category: .weight, eventType: "BODY_WEIGHT", occurredAt: recordedAt, numericValue: 6.2, unit: "KG"),
            EditableEventDraft(category: .health, eventType: "VOMITING", occurredAt: vomitingAt, count: 1),
            EditableEventDraft(category: .activity, eventType: "PLAY", occurredAt: recordedAt, durationMinutes: 20, description: "Played with Creamy")
        ]

        let graph = try EventDraftSaveService.save(
            petID: oreo.id,
            approvedTranscript: "  Approved transcript  ",
            recordedAt: recordedAt,
            drafts: drafts,
            in: context,
            now: recordedAt
        )

        let record = try XCTUnwrap(context.fetch(FetchDescriptor<PetRecord>()).first)
        let events = try context.fetch(FetchDescriptor<PetEvent>())
        XCTAssertEqual(record.id, graph.recordID)
        XCTAssertEqual(Set(events.map(\.id)), Set(graph.eventIDs))
        XCTAssertEqual(record.originalTranscript, "Approved transcript")
        XCTAssertEqual(record.recordedAt, recordedAt)
        XCTAssertEqual(record.pet?.id, oreo.id)
        XCTAssertEqual(oreo.records?.count, 1)
        XCTAssertEqual(creamy.records?.count, 0)
        XCTAssertEqual(events.first(where: { $0.category == .weight })?.numericValue, 6.2)
        XCTAssertEqual(events.first(where: { $0.category == .weight })?.unit, "KG")
        XCTAssertEqual(events.first(where: { $0.eventType == "VOMITING" })?.count, 1)
        XCTAssertEqual(events.first(where: { $0.eventType == "VOMITING" })?.occurredAt, vomitingAt)
        XCTAssertEqual(events.first(where: { $0.eventType == "PLAY" })?.durationMinutes, 20)
        XCTAssertEqual(events.first(where: { $0.eventType == "PLAY" })?.eventDescription, "Played with Creamy")
    }

    func testIntentionallyConfirmedTranscriptOnlyRecordIsSupported() throws {
        let container = try makeContainer()
        let pet = try Pet(name: "Oreo", species: .cat)
        container.mainContext.insert(pet)
        try container.mainContext.save()

        _ = try EventDraftSaveService.save(
            petID: pet.id,
            approvedTranscript: "A diary note with no structured events.",
            recordedAt: .now,
            drafts: [],
            in: container.mainContext
        )

        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<PetRecord>()).count, 1)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<PetEvent>()).isEmpty)
    }

    func testValidationFailureLeavesNoPartialHistoryAndCanRetry() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let pet = try Pet(name: "Oreo", species: .cat)
        context.insert(pet)
        try context.save()
        let invalid = EditableEventDraft(category: .health, eventType: "BAD-TYPE", occurredAt: .now)

        XCTAssertThrowsError(try EventDraftSaveService.save(
            petID: pet.id,
            approvedTranscript: "Oreo had an observation.",
            recordedAt: .now,
            drafts: [invalid],
            in: context
        ))
        XCTAssertTrue(try context.fetch(FetchDescriptor<PetRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PetEvent>()).isEmpty)

        let corrected = EditableEventDraft(category: .health, eventType: "OBSERVATION", occurredAt: .now)
        XCTAssertNoThrow(try EventDraftSaveService.save(
            petID: pet.id,
            approvedTranscript: "Oreo had an observation.",
            recordedAt: .now,
            drafts: [corrected],
            in: context
        ))
    }

    func testMissingPetAndEmptyTranscriptPersistNothing() throws {
        let container = try makeContainer()
        XCTAssertThrowsError(try EventDraftSaveService.save(
            petID: UUID(), approvedTranscript: "Note", recordedAt: .now, drafts: [], in: container.mainContext
        ))
        XCTAssertThrowsError(try EventDraftSaveService.save(
            petID: UUID(), approvedTranscript: "  ", recordedAt: .now, drafts: [], in: container.mainContext
        ))
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<PetRecord>()).isEmpty)
    }

    func testSavedGraphSurvivesContainerRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "Step3E.store")
        let petID: UUID

        do {
            let container = try PettalePersistence.makeModelContainer(cloudKitEnabled: false, storeURL: storeURL)
            let pet = try Pet(name: "Oreo", species: .cat)
            petID = pet.id
            container.mainContext.insert(pet)
            try container.mainContext.save()
            _ = try EventDraftSaveService.save(
                petID: pet.id,
                approvedTranscript: "Oreo played.",
                recordedAt: .now,
                drafts: [.init(category: .activity, eventType: "PLAY", occurredAt: .now, durationMinutes: 20)],
                in: container.mainContext
            )
        }

        let reopened = try PettalePersistence.makeModelContainer(cloudKitEnabled: false, storeURL: storeURL)
        let record = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<PetRecord>()).first)
        XCTAssertEqual(record.pet?.id, petID)
        XCTAssertEqual(record.events?.first?.eventType, "PLAY")
        XCTAssertEqual(record.events?.first?.durationMinutes, 20)
    }

    private func makeContainer() throws -> ModelContainer {
        try PettalePersistence.makeModelContainer(inMemory: true, cloudKitEnabled: false)
    }
}
