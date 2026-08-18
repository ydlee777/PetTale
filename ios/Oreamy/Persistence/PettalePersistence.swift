import Foundation
import SwiftData

enum PettalePersistence {
    static let cloudKitContainerIdentifier = "iCloud.com.oreamy.app"

    static func makeModelContainer(
        inMemory: Bool = false,
        cloudKitEnabled: Bool = true,
        storeURL: URL? = nil
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: PettaleSchemaV4.self)
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = cloudKitEnabled
            ? .private(cloudKitContainerIdentifier)
            : .none

        let configuration: ModelConfiguration
        if let storeURL {
            configuration = ModelConfiguration(
                "PettalePrivateData",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: cloudKitDatabase
            )
        } else {
            configuration = ModelConfiguration(
                "PettalePrivateData",
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                cloudKitDatabase: cloudKitDatabase
            )
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: PettaleMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func makeApplicationModelContainer() throws -> ModelContainer {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return try makeModelContainer(
                inMemory: true,
                cloudKitEnabled: false
            )
        }

        do {
            return try makeModelContainer(cloudKitEnabled: true)
        } catch {
            // Local persistence remains available before the app's CloudKit
            // container and provisioning profile are configured by a team.
            return try makeModelContainer(cloudKitEnabled: false)
        }
    }
}
