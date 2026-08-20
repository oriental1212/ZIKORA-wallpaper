import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class PersistenceStartupController {
    enum Phase {
        case ready
        case recoveryRequired(UserMessage)
    }

    private(set) var phase: Phase
    private(set) var modelContainer: ModelContainer?
    private let storeURL: URL?
    private let logger: any AppLogging
    @ObservationIgnored private var maintenanceTask: Task<Void, Never>?

    init(storeURL: URL?, logger: any AppLogging) {
        self.storeURL = storeURL
        self.logger = logger
        self.phase = .recoveryRequired(UserMessageCatalog.message(
            for: AppFailure(code: .persistenceFailed)
        ))
        retry()
    }

    private init(inMemoryContainer: ModelContainer, logger: any AppLogging) {
        self.storeURL = nil
        self.logger = logger
        self.phase = .ready
        self.modelContainer = inMemoryContainer
    }

    var managedRootURL: URL? {
        storeURL?.deletingLastPathComponent()
            .appendingPathComponent("Wallpapers", isDirectory: true)
    }

    static func live(logger: any AppLogging) -> PersistenceStartupController {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            if let container = try? PersistenceContainerFactory.makeInMemoryStore() {
                return PersistenceStartupController(
                    inMemoryContainer: container,
                    logger: logger
                )
            }
            return PersistenceStartupController(storeURL: nil, logger: logger)
        }
        let storeURL = try? PersistenceContainerFactory.defaultStoreURL()
        return PersistenceStartupController(storeURL: storeURL, logger: logger)
    }

    func retry() {
        maintenanceTask?.cancel()
        guard let storeURL else {
            modelContainer = nil
            phase = .recoveryRequired(UserMessageCatalog.message(
                for: AppFailure(code: .persistenceFailed)
            ))
            logger.log(AppLogRecord(
                category: .persistence,
                level: .error,
                event: .operationFailed,
                errorCode: .persistenceFailed
            ))
            return
        }

        switch PersistenceStoreRecovery.openStore(at: storeURL, logger: logger) {
        case .ready(let container):
            modelContainer = container
            phase = .ready
            startMaintenance(container: container, storeURL: storeURL)
        case .recoveryRequired(let message):
            modelContainer = nil
            phase = .recoveryRequired(message)
        }
    }

    func archiveAndStartFresh() {
        guard let storeURL else {
            retry()
            return
        }
        do {
            modelContainer = try PersistenceStoreRecovery.archiveAndCreateFreshStore(
                at: storeURL
            ).container
            phase = .ready
            if let modelContainer {
                startMaintenance(container: modelContainer, storeURL: storeURL)
            }
            logger.log(AppLogRecord(
                category: .persistence,
                level: .information,
                event: .stateRestored
            ))
        } catch {
            modelContainer = nil
            phase = .recoveryRequired(UserMessageCatalog.message(
                for: AppFailure(code: .persistenceFailed)
            ))
            logger.log(AppLogRecord(
                category: .persistence,
                level: .error,
                event: .operationFailed,
                errorCode: .persistenceFailed
            ))
        }
    }

    private func startMaintenance(container: ModelContainer, storeURL: URL) {
        let logger = logger
        let managedRootURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent("Wallpapers", isDirectory: true)
        let repository = SwiftDataRepositoryStore(modelContainer: container)
        let inventory = LocalManagedFileInventory(rootURL: managedRootURL)
        maintenanceTask = Task {
            do {
                _ = try await MaintainWallpaperFilesUseCase(
                    wallpapers: repository,
                    fileInventory: inventory,
                    logger: logger
                ).execute()
            } catch is CancellationError {
                return
            } catch {
                logger.log(AppLogRecord(
                    category: .fileStore,
                    level: .error,
                    event: .operationFailed,
                    errorCode: .fileOperationFailed
                ))
            }
        }
    }
}
