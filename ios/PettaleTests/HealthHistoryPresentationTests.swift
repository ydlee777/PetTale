import Foundation
import XCTest
@testable import Pettale

@MainActor
final class HealthHistoryPresentationTests: XCTestCase {
    private let en = Locale(identifier: "en_US")
    private let ko = Locale(identifier: "ko_KR")

    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return value
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func pet(_ name: String = "Oreo") throws -> Pet {
        try Pet(name: name, species: .cat)
    }

    @discardableResult
    private func event(
        pet: Pet,
        category: EventCategory,
        type: String? = nil,
        occurredAt: String = "2026-08-16T00:00:00Z",
        count: Int? = nil,
        description: String? = nil,
        diaryText: String? = nil,
        transcript: String = "Spoken context",
        createdAt: String = "2026-08-16T00:00:01Z"
    ) throws -> PetEvent {
        let record = try PetRecord(
            pet: pet,
            originalTranscript: transcript,
            diaryText: diaryText,
            recordedAt: date(occurredAt),
            now: date(createdAt)
        )
        return try PetEvent(
            record: record,
            category: category,
            eventType: type,
            occurredAt: date(occurredAt),
            count: count,
            description: description,
            now: date(createdAt)
        )
    }

    func testOnlyHealthMedicationAndVetAreIncluded() throws {
        let oreo = try pet()
        for category in EventCategory.allCases {
            try event(pet: oreo, category: category)
        }
        XCTAssertEqual(
            Set(HealthHistoryPresentation.entries(for: oreo, locale: en).map(\.category)),
            Set([.health, .medication, .vet])
        )
        XCTAssertEqual(HealthHistoryPresentation.entries(for: oreo, locale: en).count, 3)
    }

    func testNewestFirstOrderingUsesOccurredAt() throws {
        let oreo = try pet()
        try event(pet: oreo, category: .health, type: "OLDER", occurredAt: "2026-08-01T00:00:00Z")
        try event(pet: oreo, category: .health, type: "NEWER", occurredAt: "2026-08-16T00:00:00Z")
        XCTAssertEqual(HealthHistoryPresentation.entries(for: oreo, locale: en).map(\.title), ["Newer", "Older"])
    }

    func testIdenticalTimeUsesUpdatedThenCreatedThenIDTieBreak() throws {
        let oreo = try pet()
        let older = try event(pet: oreo, category: .health, type: "OLDER_UPDATE", createdAt: "2026-08-16T00:00:01Z")
        let newer = try event(pet: oreo, category: .health, type: "NEWER_UPDATE", createdAt: "2026-08-16T00:00:02Z")
        try older.update(category: .health, eventType: "MOST_RECENT", occurredAt: older.occurredAt, numericValue: nil, unit: nil, count: nil, durationMinutes: nil, description: nil, at: date("2026-08-16T00:00:03Z"))
        let entries = HealthHistoryPresentation.entries(for: oreo, locale: en)
        XCTAssertEqual(entries.map(\.id), [older.id, newer.id])
    }

    func testGroupsByLocalCalendarDay() throws {
        let oreo = try pet()
        try event(pet: oreo, category: .health, occurredAt: "2026-08-15T15:30:00Z")
        try event(pet: oreo, category: .vet, occurredAt: "2026-08-16T02:00:00Z")
        try event(pet: oreo, category: .medication, occurredAt: "2026-08-14T10:00:00Z")
        let timeline = HealthHistoryPresentation.timeline(
            for: oreo,
            calendar: calendar,
            locale: en,
            now: date("2026-08-16T12:00:00Z")
        )
        XCTAssertEqual(timeline.sections.count, 2)
        XCTAssertEqual(timeline.sections.first?.entries.count, 2)
        XCTAssertEqual(timeline.sections.first?.title, "Today")
    }

    func testPetIsolationAndEmptyState() throws {
        let oreo = try pet()
        let creamy = try pet("Creamy")
        try event(pet: oreo, category: .health, type: "VOMITING")
        XCTAssertEqual(HealthHistoryPresentation.entries(for: oreo, locale: en).count, 1)
        XCTAssertTrue(HealthHistoryPresentation.timeline(for: creamy, locale: en).isEmpty)
    }

    func testVomitingCountAndMissingCount() throws {
        let oreo = try pet()
        try event(pet: oreo, category: .health, type: "VOMITING", count: 1)
        try event(pet: oreo, category: .health, type: "VOMITING", occurredAt: "2026-08-15T00:00:00Z")
        let entries = HealthHistoryPresentation.entries(for: oreo, locale: en)
        XCTAssertEqual(entries[0].title, "Vomiting")
        XCTAssertEqual(entries[0].countText, "1 time")
        XCTAssertNil(entries[1].countText)
        XCTAssertEqual(HealthHistoryPresentation.formattedCount(1, locale: ko), "1회")
    }

    func testKnownEyeTypesUseFriendlyPresentation() {
        for type in ["EYE_REDNESS", "EYE_OBSERVATION", "RED_WATERY_EYE"] {
            XCTAssertEqual(
                HealthHistoryPresentation.friendlyTitle(category: .health, eventType: type, locale: en),
                "Eye Condition"
            )
        }
    }

    func testUnknownTypeAndDescriptionDisplaySafely() throws {
        let creamy = try pet("Creamy")
        try event(
            pet: creamy,
            category: .health,
            type: "SKIN_OBSERVATION",
            description: "A small dry patch was visible"
        )
        let entry = try XCTUnwrap(HealthHistoryPresentation.entries(for: creamy, locale: en).first)
        XCTAssertEqual(entry.title, "Skin Observation")
        XCTAssertEqual(entry.description, "A small dry patch was visible")
    }

    func testMissingTypeFallsBackToLocalizedCategory() throws {
        let oreo = try pet()
        try event(pet: oreo, category: .health, description: "Looked tired")
        XCTAssertEqual(HealthHistoryPresentation.entries(for: oreo, locale: en).first?.title, "Health")
    }

    func testMedicationAndVetUseOnlyStoredDetails() throws {
        let oreo = try pet()
        try event(pet: oreo, category: .medication, description: "Eye drops")
        try event(pet: oreo, category: .vet, description: "Annual checkup")
        let entries = HealthHistoryPresentation.entries(for: oreo, locale: en)
        XCTAssertEqual(Set(entries.map(\.title)), Set(["Medication", "Vet Visit"]))
        XCTAssertEqual(Set(entries.compactMap(\.description)), Set(["Eye drops", "Annual checkup"]))
    }

    func testDiaryContextUsesDiaryTextThenTranscriptFallback() throws {
        let oreo = try pet()
        try event(pet: oreo, category: .health, diaryText: "That day's story", transcript: "Spoken one")
        try event(pet: oreo, category: .vet, occurredAt: "2026-08-15T00:00:00Z", transcript: "Spoken two")
        let entries = HealthHistoryPresentation.entries(for: oreo, locale: en)
        XCTAssertEqual(entries[0].diaryContext, "That day's story")
        XCTAssertEqual(entries[0].originalTranscript, "Spoken one")
        XCTAssertEqual(entries[1].diaryContext, "Spoken two")
    }

    func testPresentationDoesNotMutateSwiftData() throws {
        let oreo = try pet()
        let stored = try event(pet: oreo, category: .health, type: "VOMITING", count: 1, description: "Vomited once")
        let originalUpdatedAt = stored.updatedAt
        _ = HealthHistoryPresentation.timeline(for: oreo, locale: en)
        XCTAssertEqual(stored.category, .health)
        XCTAssertEqual(stored.eventType, "VOMITING")
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.eventDescription, "Vomited once")
        XCTAssertEqual(stored.updatedAt, originalUpdatedAt)
    }
}
