import SwiftData
import SwiftUI

struct RootView: View {
    @Query(sort: \Pet.createdAt) private var pets: [Pet]
    @State private var launchFlow: OreamyLaunchFlow
    let authentication: AuthenticationController
    let subscription: SubscriptionController
    private let holdsIntroForDevelopment: Bool
    private let forcesWelcomeForDevelopment: Bool

    init(authentication: AuthenticationController, subscription: SubscriptionController) {
        self.authentication = authentication
        self.subscription = subscription
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        holdsIntroForDevelopment = arguments.contains("-oreamyHoldIntro")
        forcesWelcomeForDevelopment = arguments.contains("-oreamyWelcome")
        _launchFlow = State(initialValue: OreamyLaunchFlow(
            destination: forcesWelcomeForDevelopment ? .welcome : .intro
        ))
#else
        holdsIntroForDevelopment = false
        forcesWelcomeForDevelopment = false
        _launchFlow = State(initialValue: OreamyLaunchFlow())
#endif
    }

    var body: some View {
        Group {
            switch launchFlow.destination {
            case .intro:
                OreamyIntroView(holdsForDevelopment: holdsIntroForDevelopment) {
                    launchFlow.completeIntro(petCount: pets.count)
                }
            case .welcome:
                OreamyWelcomeView { launchFlow.getStarted() }
            case .firstPetCreation:
                FirstPetSetupView { launchFlow.cancelFirstPetCreation() }
            case .home:
                HomeView(pets: pets, authentication: authentication, subscription: subscription)
            }
        }
        .onChange(of: pets.count, initial: true) { _, count in
            guard !forcesWelcomeForDevelopment else { return }
            launchFlow.petsDidChange(count: count)
        }
        .task(id: session?.accessToken) {
            await subscription.refreshServiceAccess(session: session)
        }
    }

    private var session: OreamySession? {
        if case .signedIn(let session) = authentication.state { return session }
        return nil
    }
}

private struct FirstPetSetupView: View {
    let cancelAction: () -> Void

    var body: some View {
        NavigationStack {
            PetFormView(mode: .create, isFirstPet: true, cancelAction: cancelAction)
        }
    }
}
