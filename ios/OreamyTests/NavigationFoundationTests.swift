import XCTest
@testable import Oreamy

final class NavigationFoundationTests: XCTestCase {
    func testDeletingSelectedPetSelectsDeterministicRemainingPet() {
        let first = UUID()
        let deleted = UUID()
        XCTAssertEqual(
            PetSelection.selectedID(afterDeleting: deleted, currentID: deleted, remainingIDs: [first]),
            first
        )
    }

    func testDeletingNonSelectedPetPreservesSelection() {
        let selected = UUID()
        XCTAssertEqual(
            PetSelection.selectedID(afterDeleting: UUID(), currentID: selected, remainingIDs: [selected]),
            selected
        )
    }

    func testDeletingLastPetClearsSelection() {
        let deleted = UUID()
        XCTAssertNil(PetSelection.selectedID(afterDeleting: deleted, currentID: deleted, remainingIDs: []))
    }
    func testRootContainsOnlyTodayAndDiaryWithoutOpenLabel() {
        let labels = OreamyRootTab.allCases.map(\.localizationKey)
        XCTAssertEqual(labels, ["Today", "Diary"])
        XCTAssertFalse(labels.contains("Open"))
        XCTAssertFalse(labels.contains("열기"))
    }

    func testPetSelectorPreservesPetOrderAndSelectedPet() {
        let oreo = UUID()
        let creamy = UUID()
        XCTAssertEqual(PetSelection.menuIDs(availableIDs: [oreo, creamy]), [oreo, creamy])
        XCTAssertEqual(PetSelection.resolvedID(selectedID: creamy, availableIDs: [oreo, creamy]), creamy)
    }

    func testNewlyCreatedPetReplacesThePreviousSelection() {
        let oreo = UUID()
        let creamy = UUID()
        var selectedID: UUID? = oreo
        selectedID = PetSelection.selectedID(afterCreating: creamy)
        XCTAssertEqual(selectedID, creamy)
    }

    func testPetSelectorOffersAddAndManageActions() {
        XCTAssertEqual(OreamyNavigationPresentation.petSelectorActions, [.addPet, .managePets])
    }

    func testMenuMapsToExistingV1Destinations() {
        XCTAssertEqual(OreamyNavigationPresentation.menuDestinations, [
            .managePets, .diary, .weight, .healthHistory, .recordSummary, .premium, .account
        ])
    }

    func testPremiumUsesPushAndTodayShortcutsRemain() {
        XCTAssertTrue(OreamyNavigationPresentation.premiumUsesPushNavigation)
        XCTAssertEqual(OreamyNavigationPresentation.todayShortcuts, [.weight, .healthHistory, .recordSummary])
    }

    func testPetSelectionIsPureAndFallsBackWithoutPersistenceMutation() {
        let oreo = UUID()
        let creamy = UUID()
        let ids = [oreo, creamy]
        XCTAssertEqual(PetSelection.resolvedID(selectedID: UUID(), availableIDs: ids), oreo)
        XCTAssertEqual(ids, [oreo, creamy])
    }
}
