import Foundation
import SwiftData
import XCTest
@testable import Oreamy

@MainActor
final class DiaryPresentationTests: XCTestCase {
    private let en = Locale(identifier: "en_US")
    private let ko = Locale(identifier: "ko_KR")

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func makePet(name: String = "Oreo") throws -> Pet {
        try Pet(name: name, species: .cat)
    }

    func testRecordsSortNewestFirstAndGroupMultipleRecordsByLocalDay() throws {
        let pet = try makePet()
        let older = try PetRecord(pet: pet, originalTranscript: "Morning", recordedAt: date("2026-08-16T00:00:00Z"))
        let newer = try PetRecord(pet: pet, originalTranscript: "Evening", recordedAt: date("2026-08-16T10:00:00Z"))
        let yesterday = try PetRecord(pet: pet, originalTranscript: "Yesterday", recordedAt: date("2026-08-15T10:00:00Z"))
        _ = [older, yesterday, newer]

        let timeline = DiaryPresentation.timeline(
            for: pet,
            calendar: makeCalendar(),
            locale: en,
            now: date("2026-08-16T12:00:00Z")
        )

        XCTAssertEqual(timeline.sections.count, 2)
        XCTAssertEqual(timeline.sections[0].entries.map(\.displayText), ["Evening", "Morning"])
        XCTAssertEqual(timeline.sections[1].entries.map(\.displayText), ["Yesterday"])
    }

    func testSelectedPetHistoryIsIsolated() throws {
        let oreo = try makePet()
        let creamy = try makePet(name: "Creamy")
        _ = try PetRecord(pet: oreo, originalTranscript: "Oreo story")
        _ = try PetRecord(pet: creamy, originalTranscript: "Creamy story")

        let timeline = DiaryPresentation.timeline(for: creamy, locale: en)
        XCTAssertEqual(timeline.sections.flatMap(\.entries).map(\.displayText), ["Creamy story"])
    }

    func testDiaryTextWinsAndTranscriptIsFallbackWithoutMutation() throws {
        let pet = try makePet()
        let generated = try PetRecord(pet: pet, originalTranscript: "Spoken", diaryText: "Story")
        let historical = try PetRecord(pet: pet, originalTranscript: "Historical", diaryText: nil)

        XCTAssertEqual(DiaryPresentation.displayText(for: generated), "Story")
        XCTAssertEqual(DiaryPresentation.displayText(for: historical), "Historical")
        XCTAssertNil(historical.diaryText)
        XCTAssertEqual(historical.originalTranscript, "Historical")
    }

    func testEmptyDiary() throws {
        XCTAssertTrue(DiaryPresentation.timeline(for: try makePet(), locale: en).isEmpty)
    }

    func testWeightSummaryUsesValueWithoutRawCanonicalCode() throws {
        let pet = try makePet()
        let record = try PetRecord(pet: pet, originalTranscript: "Weight")
        _ = try PetEvent(record: record, category: .weight, eventType: "BODY_WEIGHT", numericValue: 6.2, unit: "KG")

        let entry = DiaryPresentation.entry(for: record, locale: en)
        XCTAssertEqual(entry.summaries.first?.text, "6.2 kg")
        XCTAssertFalse(entry.summaries.contains { $0.text.contains("BODY_WEIGHT") })
    }

    func testFoodEventsAggregateDeterministically() throws {
        let pet = try makePet()
        let record = try PetRecord(pet: pet, originalTranscript: "Meals")
        _ = try (0..<3).map { _ in try PetEvent(record: record, category: .food) }

        let summary = try XCTUnwrap(DiaryPresentation.entry(for: record, locale: en).summaries.first)
        XCTAssertEqual(summary.text, "Meals · 3 times")
    }

    func testActivityDurationAndVomitingCountSummaries() throws {
        let pet = try makePet()
        let record = try PetRecord(pet: pet, originalTranscript: "Played and vomited")
        _ = [
            try PetEvent(record: record, category: .activity, eventType: "PLAY", durationMinutes: 20),
            try PetEvent(record: record, category: .health, eventType: "VOMITING", count: 1)
        ]

        let summaries = DiaryPresentation.entry(for: record, locale: en).summaries.map(\.text)
        XCTAssertTrue(summaries.contains("Play · 20 minutes"))
        XCTAssertTrue(summaries.contains("Vomiting · 1 time"))
    }

    func testUnknownEventRemainsDisplayable() throws {
        let pet = try makePet()
        let record = try PetRecord(pet: pet, originalTranscript: "A small moment")
        _ = try PetEvent(record: record, category: .other, eventType: "TAIL_WAG", description: "Wagged their tail")

        let summary = try XCTUnwrap(DiaryPresentation.entry(for: record, locale: en).summaries.first)
        XCTAssertEqual(summary.text, "Wagged their tail")
    }

    func testDetailPreservesFoodTimesAndEventValues() throws {
        let pet = try makePet()
        let record = try PetRecord(pet: pet, originalTranscript: "Ate twice", diaryText: "Two good meals")
        let first = try PetEvent(record: record, category: .food, occurredAt: date("2026-08-16T21:00:00Z"))
        let second = try PetEvent(record: record, category: .food, occurredAt: date("2026-08-17T03:00:00Z"))
        _ = [second, first]

        let entry = DiaryPresentation.entry(for: record, locale: en)
        XCTAssertEqual(entry.displayText, "Two good meals")
        XCTAssertEqual(entry.originalTranscript, "Ate twice")
        XCTAssertEqual(entry.eventDetails.count, 2)
        XCTAssertNotEqual(entry.eventDetails[0].occurredAtText, entry.eventDetails[1].occurredAtText)
    }

    func testHealthDescriptionStaysObservational() throws {
        let pet = try makePet(name: "Creamy")
        let record = try PetRecord(pet: pet, originalTranscript: "Left eye looked red and watery")
        _ = try PetEvent(record: record, category: .health, eventType: "EYE_REDNESS", description: "Left eye looked a little red and watery")

        let entry = DiaryPresentation.entry(for: record, locale: en)
        XCTAssertEqual(entry.eventDetails.first?.value, "Left eye looked a little red and watery")
        XCTAssertFalse(entry.eventDetails.first?.value.lowercased().contains("infection") == true)
    }

    func testEnglishAndKoreanDayLabelsAreLocalized() {
        let calendar = makeCalendar()
        let now = date("2026-08-16T12:00:00Z")
        let today = calendar.startOfDay(for: now)
        XCTAssertEqual(DiaryPresentation.dayTitle(today, calendar: calendar, locale: en, now: now), "Today")
        XCTAssertEqual(DiaryPresentation.dayTitle(today, calendar: calendar, locale: ko, now: now), "오늘")
    }
}
