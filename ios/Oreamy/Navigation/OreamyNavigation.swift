import SwiftUI

enum OreamyRootTab: String, CaseIterable, Identifiable {
    case today
    case diary

    var id: Self { self }
    var localizationKey: String { rawValue == "today" ? "Today" : "Diary" }
    var title: LocalizedStringKey {
        LocalizedStringKey(localizationKey)
    }
}

enum OreamyMenuDestination: String, CaseIterable {
    case managePets
    case diary
    case weight
    case healthHistory
    case recordSummary
    case premium
    case account
}

enum OreamyNavigationPresentation {
    static let menuDestinations = OreamyMenuDestination.allCases
    static let todayShortcuts: [OreamyMenuDestination] = [.weight, .healthHistory, .recordSummary]
    static let premiumUsesPushNavigation = true
    static let petSelectorActions: [OreamyPetSelectorAction] = [.addPet, .managePets]
}

enum OreamyPetSelectorAction: Equatable {
    case addPet
    case managePets
}

enum PetSelection {
    static func selectedID(afterCreating createdID: UUID) -> UUID { createdID }

    static func resolvedID(selectedID: UUID?, availableIDs: [UUID]) -> UUID? {
        guard !availableIDs.isEmpty else { return nil }
        return selectedID.flatMap { availableIDs.contains($0) ? $0 : nil } ?? availableIDs.first
    }

    static func selectedID(
        afterDeleting deletedID: UUID,
        currentID: UUID?,
        remainingIDs: [UUID]
    ) -> UUID? {
        guard currentID == deletedID else { return resolvedID(selectedID: currentID, availableIDs: remainingIDs) }
        return remainingIDs.first
    }

    static func menuIDs(availableIDs: [UUID]) -> [UUID] { availableIDs }
}
