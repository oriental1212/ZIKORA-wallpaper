import Foundation
import SwiftData

@MainActor
enum PersistenceOpenResult {
    case ready(ModelContainer)
    case recoveryRequired(UserMessage)
}

@MainActor
enum PersistenceStoreRecovery {
    static func openStore(
        at storeURL: URL,
        logger: any AppLogging
    ) -> PersistenceOpenResult {
        do {
            return .ready(try PersistenceContainerFactory.makeStore(at: storeURL))
        } catch {
            logger.log(AppLogRecord(
                category: .persistence,
                level: .error,
                event: .operationFailed,
                errorCode: .persistenceFailed
            ))
            return .recoveryRequired(UserMessageCatalog.message(
                for: AppFailure(code: .persistenceFailed)
            ))
        }
    }

    static func archiveAndCreateFreshStore(
        at storeURL: URL,
        fileManager: FileManager = .default,
        archiveID: UUID = UUID()
    ) throws -> (container: ModelContainer, archiveURL: URL?) {
        let existingURLs = relatedStoreURLs(for: storeURL).filter {
            fileManager.fileExists(atPath: $0.path)
        }
        guard !existingURLs.isEmpty else {
            return (try PersistenceContainerFactory.makeStore(at: storeURL), nil)
        }

        let recoveryRoot = storeURL.deletingLastPathComponent()
            .appendingPathComponent("Persistence Recovery", isDirectory: true)
        let archiveURL = recoveryRoot
            .appendingPathComponent(archiveID.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: archiveURL, withIntermediateDirectories: true)

        var movedItems: [(original: URL, archived: URL)] = []
        do {
            for originalURL in existingURLs {
                let archivedURL = archiveURL.appendingPathComponent(originalURL.lastPathComponent)
                try fileManager.moveItem(at: originalURL, to: archivedURL)
                movedItems.append((originalURL, archivedURL))
            }
            return (try PersistenceContainerFactory.makeStore(at: storeURL), archiveURL)
        } catch {
            for freshURL in relatedStoreURLs(for: storeURL) where fileManager.fileExists(atPath: freshURL.path) {
                try? fileManager.removeItem(at: freshURL)
            }
            for item in movedItems.reversed() where fileManager.fileExists(atPath: item.archived.path) {
                try? fileManager.moveItem(at: item.archived, to: item.original)
            }
            throw AppFailure(code: .persistenceFailed)
        }
    }

    private static func relatedStoreURLs(for storeURL: URL) -> [URL] {
        [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal"),
        ]
    }
}
