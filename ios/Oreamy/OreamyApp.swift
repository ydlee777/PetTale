import SwiftUI
import SwiftData

@main
struct OreamyApp: App {
    private let modelContainer: ModelContainer
    @State private var authentication: AuthenticationController
    @State private var subscription: SubscriptionController

    init() {
        _authentication = State(initialValue: AuthenticationController())
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let subscription = arguments.contains(where: { $0.hasPrefix("-oreamyPremium") })
            ? SubscriptionController(
                service: SubscriptionDevelopmentService(arguments: arguments),
                preferredProductID: arguments.contains("-oreamyPremiumAnnual")
                    ? OreamySubscriptionProduct.annualID
                    : OreamySubscriptionProduct.monthlyID
            )
            : SubscriptionController()
#else
        let subscription = SubscriptionController()
#endif
        subscription.startTransactionListener()
        _subscription = State(initialValue: subscription)
        do {
            modelContainer = try PettalePersistence.makeApplicationModelContainer()
#if DEBUG
            try DiaryDevelopmentSeed.installIfRequested(in: modelContainer)
#endif
        } catch {
            fatalError("Unable to initialize Oreamy private storage: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(authentication: authentication, subscription: subscription)
        }
        .modelContainer(modelContainer)
    }
}
