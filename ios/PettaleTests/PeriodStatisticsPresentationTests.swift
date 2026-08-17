import XCTest
@testable import Pettale

@MainActor
final class PeriodStatisticsPresentationTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return value
    }

    private var now: Date { date("2026-08-17T03:00:00Z") }

    func testDefaultPeriodIsThirtyDays() {
        XCTAssertEqual(PeriodStatisticsPresentation.defaultPeriod, .thirtyDays)
    }

    func testAllFivePeriodStartsUseInjectedCalendar() {
        let expected = [
            "2026-08-10T03:00:00Z", "2026-07-18T03:00:00Z", "2026-05-17T03:00:00Z",
            "2026-02-17T03:00:00Z", "2025-08-17T03:00:00Z"
        ].map(date)
        XCTAssertEqual(StatisticsPeriod.allCases.map {
            PeriodStatisticsPresentation.periodStart(for: $0, now: now, calendar: calendar)
        }, expected)
    }

    func testStartAndNowBoundariesAreInclusiveAndFutureIsExcluded() throws {
        let pet = try makePet()
        let start = PeriodStatisticsPresentation.periodStart(for: .sevenDays, now: now, calendar: calendar)
        try addRecord(to: pet, recordedAt: start)
        try addRecord(to: pet, recordedAt: now)
        try addRecord(to: pet, recordedAt: now.addingTimeInterval(1))
        let result = summary(pet, .sevenDays)
        XCTAssertEqual(result.storyCount, 2)
        XCTAssertEqual(result.recordedDays, 2)
    }

    func testRecordedDaysUseCalendarDaysAndStoriesUseRecordCount() throws {
        let pet = try makePet()
        try addRecord(to: pet, recordedAt: date("2026-08-16T00:00:00Z"))
        try addRecord(to: pet, recordedAt: date("2026-08-16T10:00:00Z"))
        try addRecord(to: pet, recordedAt: date("2026-08-17T00:00:00Z"))
        let result = summary(pet)
        XCTAssertEqual(result.recordedDays, 2)
        XCTAssertEqual(result.storyCount, 3)
    }

    func testTranscriptOnlyRecordCountsAsStory() throws {
        let pet = try makePet()
        try addRecord(to: pet, recordedAt: now)
        let result = summary(pet)
        XCTAssertEqual(result.storyCount, 1)
        XCTAssertEqual(result.recordedDays, 1)
        XCTAssertEqual(result.foodCount + result.activityCount + result.healthCount + result.vetCount, 0)
    }

    func testSupportedEventCategoriesCountEachEvent() throws {
        let pet = try makePet()
        let record = try addRecord(to: pet, recordedAt: now)
        try addEvents([.food, .food, .activity, .health, .health, .vet], to: record, occurredAt: now)
        let result = summary(pet)
        XCTAssertEqual(result.foodCount, 2)
        XCTAssertEqual(result.activityCount, 1)
        XCTAssertEqual(result.healthCount, 2)
        XCTAssertEqual(result.vetCount, 1)
    }

    func testUnsupportedCategoriesAndMedicationAreNotStatistics() throws {
        let pet = try makePet()
        let outsideRecord = try addRecord(to: pet, recordedAt: date("2026-01-01T00:00:00Z"))
        try addEvents([.behavior, .sleep, .grooming, .event, .other, .medication], to: outsideRecord, occurredAt: now)
        XCTAssertTrue(summary(pet).isEmpty)
    }

    func testEventCountsUseOccurredAtIndependentOfRecordDate() throws {
        let pet = try makePet()
        let oldRecord = try addRecord(to: pet, recordedAt: date("2026-01-01T00:00:00Z"))
        try addEvents([.food], to: oldRecord, occurredAt: now)
        let recentRecord = try addRecord(to: pet, recordedAt: now)
        try addEvents([.health], to: recentRecord, occurredAt: date("2026-01-01T00:00:00Z"))
        let result = summary(pet)
        XCTAssertEqual(result.storyCount, 1)
        XCTAssertEqual(result.foodCount, 1)
        XCTAssertEqual(result.healthCount, 0)
    }

    func testFutureEventsAreExcluded() throws {
        let pet = try makePet()
        let record = try addRecord(to: pet, recordedAt: now)
        try addEvents([.food], to: record, occurredAt: now.addingTimeInterval(1))
        XCTAssertEqual(summary(pet).foodCount, 0)
    }

    func testPetIsolationAndEmptyPet() throws {
        let oreo = try makePet("Oreo")
        let creamy = try makePet("Creamy")
        let record = try addRecord(to: oreo, recordedAt: now)
        try addEvents([.food], to: record, occurredAt: now)
        XCTAssertEqual(summary(oreo).foodCount, 1)
        XCTAssertTrue(summary(creamy).isEmpty)
    }

    func testWeightSummaryUsesEarliestLatestAndChange() throws {
        let pet = try makePet()
        try addWeight(6.4, to: pet, at: date("2026-08-01T03:00:00Z"))
        try addWeight(6.2, to: pet, at: now)
        let weight = try XCTUnwrap(summary(pet).weight)
        XCTAssertEqual(weight.earliest.kilograms, 6.4)
        XCTAssertEqual(weight.latest.kilograms, 6.2)
        XCTAssertEqual(try XCTUnwrap(weight.changeKilograms), -0.2, accuracy: 0.0001)
    }

    func testSingleWeightHasNoChangeAndNoWeightHasNoSummary() throws {
        let weighted = try makePet()
        try addWeight(6.2, to: weighted, at: now)
        XCTAssertNil(try XCTUnwrap(summary(weighted).weight).changeKilograms)
        XCTAssertNil(summary(try makePet("Empty")).weight)
    }

    func testWeightValidityExactlyMatchesWeightTrendContract() throws {
        let pet = try makePet()
        try addWeight(6.2, to: pet, at: now)
        try addWeight(7, to: pet, at: now.addingTimeInterval(-1), eventType: "WEIGHT")
        try addWeight(14, to: pet, at: now.addingTimeInterval(-2), unit: "LB")
        try addWeight(-1, to: pet, at: now.addingTimeInterval(-3))
        XCTAssertEqual(summary(pet).weight?.latest.kilograms, 6.2)
    }

    func testWeightDuplicateResolutionExactlyMatchesWeightTrendContract() throws {
        let pet = try makePet()
        let timestamp = date("2026-08-10T03:00:00Z")
        let older = try addWeight(6.4, to: pet, at: timestamp, updatedAt: date("2026-08-10T03:00:01Z"))
        _ = try addWeight(6.2, to: pet, at: timestamp, updatedAt: date("2026-08-10T03:00:02Z"))
        try older.update(category: .weight, eventType: "BODY_WEIGHT", occurredAt: timestamp, numericValue: 6.3, unit: "KG", count: nil, durationMinutes: nil, description: nil, at: date("2026-08-10T03:00:03Z"))
        XCTAssertEqual(summary(pet).weight?.latest.kilograms, 6.3)
    }

    func testPresentationDoesNotMutateRecordsOrEvents() throws {
        let pet = try makePet()
        let record = try addRecord(to: pet, recordedAt: now)
        let event = try PetEvent(record: record, category: .health, eventType: "VOMITING", count: 1)
        _ = summary(pet)
        XCTAssertEqual(record.recordedAt, now)
        XCTAssertEqual(event.eventType, "VOMITING")
        XCTAssertEqual(event.count, 1)
    }

    private func summary(_ pet: Pet, _ period: StatisticsPeriod = .thirtyDays) -> PeriodStatistics {
        PeriodStatisticsPresentation.statistics(for: pet, period: period, now: now, calendar: calendar)
    }

    private func makePet(_ name: String = "Oreo") throws -> Pet {
        try Pet(name: name, species: .cat)
    }

    @discardableResult
    private func addRecord(to pet: Pet, recordedAt: Date) throws -> PetRecord {
        let record = try PetRecord(pet: pet, originalTranscript: "Test record", recordedAt: recordedAt)
        return record
    }

    private func addEvents(_ categories: [EventCategory], to record: PetRecord, occurredAt: Date) throws {
        for category in categories {
            let event = try PetEvent(record: record, category: category, occurredAt: occurredAt)
            _ = event
        }
    }

    @discardableResult
    private func addWeight(
        _ value: Double,
        to pet: Pet,
        at occurredAt: Date,
        eventType: String = "BODY_WEIGHT",
        unit: String = "KG",
        updatedAt: Date? = nil
    ) throws -> PetEvent {
        let record = try addRecord(to: pet, recordedAt: occurredAt)
        let event = try PetEvent(
            record: record,
            category: .weight,
            eventType: eventType,
            occurredAt: occurredAt,
            numericValue: value,
            unit: unit,
            now: updatedAt ?? occurredAt
        )
        return event
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
