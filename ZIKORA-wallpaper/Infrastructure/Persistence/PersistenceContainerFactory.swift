import Foundation
import SwiftData

enum PersistenceContainerFactory {
    static var currentSchema: Schema {
        Schema(versionedSchema: ZIKORASchemaV1.self)
    }

    static func makeStore(at storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "ZIKORA",
            schema: currentSchema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: currentSchema,
            migrationPlan: ZIKORAMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func makeInMemoryStore() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "ZIKORA-InMemory",
            schema: currentSchema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: currentSchema,
            migrationPlan: ZIKORAMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func defaultStoreURL(fileManager: FileManager = .default) throws -> URL {
        guard let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw AppFailure(code: .storageUnavailable)
        }
        let bundleComponent = Bundle.main.bundleIdentifier ?? "cn.zhikezhui.ZIKORA-wallpaper"
        let directoryURL = applicationSupportURL
            .appendingPathComponent(bundleComponent, isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL.appendingPathComponent("ZIKORA.store")
    }
}
