import SwiftUI
import SwiftData

@main
struct PettaleApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try PettalePersistence.makeApplicationModelContainer()
        } catch {
            fatalError("Unable to initialize Pettale private storage: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(modelContainer)
    }
}
