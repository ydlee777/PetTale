import XCTest
@testable import Oreamy

@MainActor
final class FilteredEventPresentationTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return value
    }
    private var now: Date { date("2026-08-17T03:00:00Z") }

    func testSupportedCountsExactlyMatchDrillDowns() throws {
        let pet = try makePet()
        let record = try makeRecord(pet, at: now)
        for category in [EventCategory.food, .food, .activity, .health, .health, .health, .vet] {
            _ = try PetEvent(record: record, category: category, occurredAt: now)
        }
        let summary = statistics(pet, .thirtyDays)
        XCTAssertEqual(timeline(pet, .food, .thirtyDays).eventCount, summary.foodCount)
        XCTAssertEqual(timeline(pet, .activity, .thirtyDays).eventCount, summary.activityCount)
        XCTAssertEqual(timeline(pet, .health, .thirtyDays).eventCount, summary.healthCount)
        XCTAssertEqual(timeline(pet, .vet, .thirtyDays).eventCount, summary.vetCount)
    }

    func testSevenDayPeriodIsPreserved() throws {
        try assertPeriod(.sevenDays, inside: "2026-08-11T03:00:00Z", outside: "2026-08-10T02:59:59Z")
    }

    func testThirtyDayPeriodIsPreserved() throws {
        try assertPeriod(.thirtyDays, inside: "2026-07-19T03:00:00Z", outside: "2026-07-18T02:59:59Z")
    }

    func testThreeMonthPeriodIsPreserved() throws {
        try assertPeriod(.threeMonths, inside: "2026-05-18T03:00:00Z", outside: "2026-05-17T02:59:59Z")
    }

    func testFutureEventsAreExcluded() throws {
        let pet = try makePet()
        let record = try makeRecord(pet, at: now)
        _ = try PetEvent(record: record, category: .food, occurredAt: now.addingTimeInterval(1))
        XCTAssertTrue(timeline(pet, .food, .thirtyDays).isEmpty)
    }

    func testOccurredAtBoundariesAreInclusive() throws {
        let pet = try makePet()
        let start = PeriodStatisticsPresentation.periodStart(for: .sevenDays, now: now, calendar: calendar)
        let record = try makeRecord(pet, at: now)
        _ = try PetEvent(record: record, category: .food, occurredAt: start)
        _ = try PetEvent(record: record, category: .food, occurredAt: now)
        XCTAssertEqual(timeline(pet, .food, .sevenDays).eventCount, 2)
    }

    func testPetIsolation() throws {
        let oreo = try makePet("Oreo")
        let creamy = try makePet("Creamy")
        _ = try PetEvent(record: makeRecord(oreo, at: now), category: .activity, occurredAt: now)
        XCTAssertEqual(timeline(oreo, .activity, .thirtyDays).eventCount, 1)
        XCTAssertEqual(timeline(creamy, .activity, .thirtyDays).eventCount, 0)
    }

    func testEntriesAreNewestFirst() throws {
        let pet = try makePet()
        let record = try makeRecord(pet, at: now)
        let old = try PetEvent(record: record, category: .activity, occurredAt: now.addingTimeInterval(-3600))
        let recent = try PetEvent(record: record, category: .activity, occurredAt: now)
        XCTAssertEqual(timeline(pet, .activity, .thirtyDays).sections.flatMap(\.entries).map(\.id), [recent.id, old.id])
    }

    func testStoredDetailsArePreserved() throws {
        let pet = try makePet()
        let event = try PetEvent(
            record: makeRecord(pet, at: now), category: .activity, eventType: "PLAY",
            occurredAt: now, numericValue: 2.5, unit: "KM", count: 2,
            durationMinutes: 20, description: "Played in the garden"
        )
        let entry = try XCTUnwrap(timeline(pet, .activity, .thirtyDays).sections.first?.entries.first)
        XCTAssertEqual(entry.id, event.id)
        XCTAssertEqual(entry.description, "Played in the garden")
        XCTAssertEqual(entry.count, 2)
        XCTAssertEqual(entry.durationMinutes, 20)
        XCTAssertEqual(entry.numericValue, 2.5)
        XCTAssertEqual(entry.unit, "KM")
    }

    func testUnknownEventTypeHasSafeHumanReadableFallback() throws {
        let pet = try makePet()
        _ = try PetEvent(record: makeRecord(pet, at: now), category: .food, eventType: "SPECIAL_SNACK", occurredAt: now)
        XCTAssertEqual(timeline(pet, .food, .thirtyDays).sections.first?.entries.first?.title, "Special Snack")
    }

    func testPresentationDoesNotMutatePersistenceModels() throws {
        let pet = try makePet()
        let record = try makeRecord(pet, at: now)
        let event = try PetEvent(record: record, category: .health, eventType: "VOMITING", occurredAt: now, count: 1)
        _ = timeline(pet, .health, .thirtyDays)
        XCTAssertEqual(record.originalTranscript, "Stored transcript")
        XCTAssertEqual(event.eventType, "VOMITING")
        XCTAssertEqual(event.count, 1)
    }

    private func assertPeriod(_ period: StatisticsPeriod, inside: String, outside: String) throws {
        let pet = try makePet()
        let record = try makeRecord(pet, at: now)
        _ = try PetEvent(record: record, category: .food, occurredAt: date(inside))
        _ = try PetEvent(record: record, category: .food, occurredAt: date(outside))
        let result = timeline(pet, .food, period)
        XCTAssertEqual(result.period, period)
        XCTAssertEqual(result.eventCount, 1)
    }

    private func statistics(_ pet: Pet, _ period: StatisticsPeriod) -> PeriodStatistics {
        PeriodStatisticsPresentation.statistics(for: pet, period: period, now: now, calendar: calendar)
    }

    private func timeline(_ pet: Pet, _ category: EventCategory, _ period: StatisticsPeriod) -> FilteredEventTimeline {
        let start = PeriodStatisticsPresentation.periodStart(for: period, now: now, calendar: calendar)
        return FilteredEventPresentation.timeline(
            for: pet, category: category, period: period, periodStart: start, now: now,
            calendar: calendar, locale: Locale(identifier: "en_US"), bundle: .main
        )
    }

    private func makePet(_ name: String = "Oreo") throws -> Pet { try Pet(name: name, species: .cat) }

    private func makeRecord(_ pet: Pet, at date: Date) throws -> PetRecord {
        try PetRecord(pet: pet, originalTranscript: "Stored transcript", recordedAt: date)
    }

    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
}
