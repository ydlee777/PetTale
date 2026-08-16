import SwiftData
import SwiftUI

enum LaunchRoute: Equatable {
    case firstPetSetup
    case home

    static func resolve(petCount: Int) -> Self {
        petCount == 0 ? .firstPetSetup : .home
    }
}

struct RootView: View {
    @Query(sort: \Pet.createdAt) private var pets: [Pet]

    var body: some View {
        switch LaunchRoute.resolve(petCount: pets.count) {
        case .firstPetSetup:
            FirstPetSetupView()
        case .home:
            HomeView(pets: pets)
        }
    }
}

private struct FirstPetSetupView: View {
    var body: some View {
        NavigationStack {
            PetFormView(mode: .create, isFirstPet: true)
        }
    }
}
