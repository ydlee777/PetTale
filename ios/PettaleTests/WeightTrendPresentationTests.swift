import Foundation
import XCTest
@testable import Pettale

@MainActor
final class WeightTrendPresentationTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
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
        value: Double? = 6.2,
        at occurredAt: String = "2026-08-01T00:00:00Z",
        category: EventCategory = .weight,
        type: String? = "BODY_WEIGHT",
        unit: String? = "KG",
        now: String = "2026-08-01T00:00:01Z"
    ) throws -> PetEvent {
        let record = try PetRecord(pet: pet, originalTranscript: "Record", recordedAt: date(occurredAt), now: date(now))
        return try PetEvent(
            record: record,
            category: category,
            eventType: type,
            occurredAt: date(occurredAt),
            numericValue: value,
            unit: unit,
            now: date(now)
        )
    }

    func testNoWeightEventsProducesEmptyTrend() throws {
        let trend = WeightTrendPresentation.trend(for: try pet(), period: .all, now: date("2026-08-17T00:00:00Z"), calendar: calendar)
        XCTAssertTrue(trend.visibleObservations.isEmpty)
        XCTAssertNil(trend.current)
        XCTAssertNil(trend.changeKilograms)
    }

    func testOneValidWeightHasCurrentButNoChange() throws {
        let oreo = try pet()
        try event(pet: oreo)
        let trend = WeightTrendPresentation.trend(for: oreo, period: .all, now: date("2026-08-17T00:00:00Z"), calendar: calendar)
        XCTAssertEqual(trend.current?.kilograms, 6.2)
        XCTAssertNil(trend.changeKilograms)
    }

    func testMultipleWeightsSortChronologicallyAndLatestOccurredAtIsCurrent() throws {
        let oreo = try pet()
        try event(pet: oreo, value: 6.2, at: "2026-08-17T00:00:00Z")
        try event(pet: oreo, value: 6.4, at: "2026-05-15T00:00:00Z")
        try event(pet: oreo, value: 6.3, at: "2026-06-15T00:00:00Z")
        let trend = WeightTrendPresentation.trend(for: oreo, period: .all, now: date("2026-08-17T12:00:00Z"), calendar: calendar)
        XCTAssertEqual(trend.visibleObservations.map(\.kilograms), [6.4, 6.3, 6.2])
        XCTAssertEqual(trend.current?.kilograms, 6.2)
    }

    func testPositiveNegativeAndZeroChanges() {
        let start = date("2026-08-01T00:00:00Z")
        let end = date("2026-08-17T00:00:00Z")
        func change(_ first: Double, _ last: Double) -> Double {
            WeightTrendPresentation.trend(
                observations: [
                    WeightObservation(eventID: UUID(), occurredAt: start, kilograms: first),
                    WeightObservation(eventID: UUID(), occurredAt: end, kilograms: last)
                ],
                period: .all,
                now: end,
                calendar: calendar
            ).changeKilograms!
        }
        XCTAssertEqual(change(6.1, 6.2), 0.1, accuracy: 0.0001)
        XCTAssertEqual(change(6.2, 6.1), -0.1, accuracy: 0.0001)
        XCTAssertEqual(change(6.2, 6.2), 0, accuracy: 0.0001)
    }

    func testPeriodFilteringUsesCalendarBoundary() throws {
        let oreo = try pet()
        try event(pet: oreo, value: 6.4, at: "2026-04-01T00:00:00Z")
        try event(pet: oreo, value: 6.3, at: "2026-06-01T00:00:00Z")
        try event(pet: oreo, value: 6.2, at: "2026-08-17T00:00:00Z")
        let now = date("2026-08-17T12:00:00Z")
        XCTAssertEqual(WeightTrendPresentation.trend(for: oreo, period: .threeMonths, now: now, calendar: calendar).visibleObservations.count, 2)
        XCTAssertEqual(WeightTrendPresentation.trend(for: oreo, period: .all, now: now, calendar: calendar).visibleObservations.count, 3)
    }

    func testPetIsolation() throws {
        let oreo = try pet()
        let creamy = try pet("Creamy")
        try event(pet: oreo, value: 6.2)
        try event(pet: creamy, value: 5.1)
        XCTAssertEqual(WeightTrendPresentation.observations(for: oreo).map(\.kilograms), [6.2])
        XCTAssertEqual(WeightTrendPresentation.observations(for: creamy).map(\.kilograms), [5.1])
    }

    func testInvalidWeightRepresentationsAreExcluded() throws {
        let oreo = try pet()
        try event(pet: oreo, value: 6.2)
        try event(pet: oreo, value: 7, category: .health)
        try event(pet: oreo, value: 7, type: "WEIGHT")
        try event(pet: oreo, value: nil)
        try event(pet: oreo, value: 14, unit: "LB")
        try event(pet: oreo, value: -1)
        XCTAssertEqual(WeightTrendPresentation.observations(for: oreo).map(\.kilograms), [6.2])
    }

    func testDuplicateTimestampKeepsMostRecentlyUpdatedEvent() throws {
        let oreo = try pet()
        let older = try event(pet: oreo, value: 6.4, now: "2026-08-01T00:00:01Z")
        let newer = try event(pet: oreo, value: 6.2, now: "2026-08-01T00:00:02Z")
        try older.update(category: .weight, eventType: "BODY_WEIGHT", occurredAt: older.occurredAt, numericValue: 6.3, unit: "KG", count: nil, durationMinutes: nil, description: nil, at: date("2026-08-01T00:00:03Z"))
        XCTAssertEqual(WeightTrendPresentation.observations(for: oreo).map(\.kilograms), [6.3])
        XCTAssertNotEqual(older.id, newer.id)
    }

    func testNumberFormattingAvoidsUnnecessaryPrecision() {
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(WeightTrendPresentation.formattedKilograms(6, locale: locale), "6 kg")
        XCTAssertEqual(WeightTrendPresentation.formattedKilograms(6.2, locale: locale), "6.2 kg")
        XCTAssertEqual(WeightTrendPresentation.formattedKilograms(6.25, locale: locale), "6.25 kg")
        XCTAssertEqual(WeightTrendPresentation.formattedChange(0.1, locale: locale), "+0.1 kg")
    }

    func testChartRangeAddsPaddingAndPreventsAggressiveZoom() throws {
        let equal = try XCTUnwrap(WeightTrendPresentation.chartDomain(for: [6.2, 6.2]))
        XCTAssertEqual(equal.lowerBound, 5.95, accuracy: 0.0001)
        XCTAssertEqual(equal.upperBound, 6.45, accuracy: 0.0001)
        let varied = try XCTUnwrap(WeightTrendPresentation.chartDomain(for: [5, 10]))
        XCTAssertEqual(varied.lowerBound, 4, accuracy: 0.0001)
        XCTAssertEqual(varied.upperBound, 11, accuracy: 0.0001)
    }

    func testPresentationDoesNotMutatePersistedEvent() throws {
        let oreo = try pet()
        let stored = try event(pet: oreo, value: 6.2)
        let originalID = stored.id
        let originalDate = stored.occurredAt
        _ = WeightTrendPresentation.trend(for: oreo, period: .all, now: date("2026-08-17T00:00:00Z"), calendar: calendar)
        XCTAssertEqual(stored.id, originalID)
        XCTAssertEqual(stored.numericValue, 6.2)
        XCTAssertEqual(stored.unit, "KG")
        XCTAssertEqual(stored.occurredAt, originalDate)
    }
}
