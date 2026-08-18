import XCTest
@testable import Oreamy

final class TodayPresentationTests: XCTestCase {
    func testLatestRecordBecomesRecentStory() throws {
        let pet = try makePet("Oreo")
        _ = try PetRecord(pet: pet, originalTranscript: "Older", recordedAt: date(100))
        let latest = try PetRecord(pet: pet, originalTranscript: "Latest", recordedAt: date(200))
        XCTAssertEqual(TodayPresentation.snapshot(for: pet).recentStory?.id, latest.id)
    }

    func testDiaryTextIsPreferred() throws {
        let pet = try makePet("Oreo")
        _ = try PetRecord(pet: pet, originalTranscript: "Transcript", diaryText: "Diary", recordedAt: date(100))
        XCTAssertEqual(TodayPresentation.snapshot(for: pet).recentStory?.displayText, "Diary")
    }

    func testTranscriptIsFallback() throws {
        let pet = try makePet("Oreo")
        _ = try PetRecord(pet: pet, originalTranscript: "Transcript", diaryText: "  ", recordedAt: date(100))
        XCTAssertEqual(TodayPresentation.snapshot(for: pet).recentStory?.displayText, "Transcript")
    }

    func testNoRecordStateHasNoRecentStory() throws {
        XCTAssertNil(TodayPresentation.snapshot(for: try makePet("Oreo")).recentStory)
    }

    func testLongStoryRemainsUnmodifiedForUILineLimiting() throws {
        let pet = try makePet("Oreo")
        let longText = String(repeating: "A long story. ", count: 100)
        _ = try PetRecord(pet: pet, originalTranscript: longText, recordedAt: date(100))
        XCTAssertEqual(
            TodayPresentation.snapshot(for: pet).recentStory?.displayText,
            longText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func testPetIsolationAndSwitching() throws {
        let oreo = try makePet("Oreo")
        let creamy = try makePet("Creamy")
        _ = try PetRecord(pet: oreo, originalTranscript: "Oreo story", recordedAt: date(100))
        _ = try PetRecord(pet: creamy, originalTranscript: "Creamy story", recordedAt: date(200))
        XCTAssertEqual(TodayPresentation.snapshot(for: oreo).recentStory?.displayText, "Oreo story")
        XCTAssertEqual(TodayPresentation.snapshot(for: creamy).recentStory?.displayText, "Creamy story")
    }

    func testLatestValidWeightReusesWeightPresentation() throws {
        let pet = try makePet("Oreo")
        let older = try PetRecord(pet: pet, originalTranscript: "Weight", recordedAt: date(100))
        _ = try PetEvent(record: older, category: .weight, eventType: "BODY_WEIGHT", occurredAt: date(100), numericValue: 6.1, unit: "KG")
        let newer = try PetRecord(pet: pet, originalTranscript: "Weight", recordedAt: date(200))
        let latest = try PetEvent(record: newer, category: .weight, eventType: "BODY_WEIGHT", occurredAt: date(200), numericValue: 6.2, unit: "KG")
        _ = try PetEvent(record: newer, category: .weight, eventType: "OTHER", occurredAt: date(300), numericValue: 99, unit: "KG")
        XCTAssertEqual(TodayPresentation.snapshot(for: pet).latestWeight?.eventID, latest.id)
        XCTAssertEqual(TodayPresentation.snapshot(for: pet).latestWeight?.kilograms, 6.2)
    }

    func testNoWeightState() throws {
        XCTAssertNil(TodayPresentation.snapshot(for: try makePet("Oreo")).latestWeight)
    }

    func testFeatureDestinationsRemainCanonicalAndRecordIsIndependent() throws {
        let snapshot = TodayPresentation.snapshot(for: try makePet("Oreo"))
        XCTAssertEqual(snapshot.destinations, [.weight, .healthHistory, .recordSummary])
    }

    func testPresentationDoesNotMutatePersistence() throws {
        let pet = try makePet("Oreo")
        let record = try PetRecord(pet: pet, originalTranscript: "Story", recordedAt: date(100))
        let beforeRecordIDs = (pet.records ?? []).map(\.id)
        let beforeUpdatedAt = pet.updatedAt
        _ = TodayPresentation.snapshot(for: pet)
        XCTAssertEqual((pet.records ?? []).map(\.id), beforeRecordIDs)
        XCTAssertEqual(record.originalTranscript, "Story")
        XCTAssertEqual(pet.updatedAt, beforeUpdatedAt)
    }

    private func makePet(_ name: String) throws -> Pet {
        try Pet(name: name, species: .cat)
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: seconds)
    }
}
