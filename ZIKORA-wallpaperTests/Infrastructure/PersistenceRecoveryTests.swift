import Foundation
import os
import SwiftData
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct PersistenceRecoveryTests {
    @Test("An unreadable store returns a safe recovery state without exposing the database error")
    func unreadableStoreRequiresRecovery() throws {
        let rootURL = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let invalidStoreURL = rootURL.appendingPathComponent("directory.store", isDirectory: true)
        try FileManager.default.createDirectory(at: invalidStoreURL, withIntermediateDirectories: true)
        let logger = RecoveryRecordingLogger()

        switch PersistenceStoreRecovery.openStore(at: invalidStoreURL, logger: logger) {
        case .ready:
            Issue.record("A directory must not be accepted as a SQLite store")
        case .recoveryRequired(let message):
            #expect(message == UserMessageCatalog.message(for: AppFailure(code: .persistenceFailed)))
        }
        #expect(logger.records == [AppLogRecord(
            category: .persistence,
            level: .error,
            event: .operationFailed,
            errorCode: .persistenceFailed
        )])
    }

    @Test("Explicit recovery archives the unreadable store before creating a fresh database")
    func archiveAndCreateFreshStore() throws {
        let rootURL = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let storeURL = rootURL.appendingPathComponent("ZIKORA.store")
        let originalData = Data("not-a-database".utf8)
        try originalData.write(to: storeURL)
        let archiveID = fixedUUID(9)

        let recovery = try PersistenceStoreRecovery.archiveAndCreateFreshStore(
            at: storeURL,
            archiveID: archiveID
        )
        let archiveURL = try #require(recovery.archiveURL)
        let archivedStoreURL = archiveURL.appendingPathComponent("ZIKORA.store")
        #expect(try Data(contentsOf: archivedStoreURL) == originalData)
        #expect(FileManager.default.fileExists(atPath: storeURL.path))

        let context = ModelContext(recovery.container)
        #expect(try context.fetchCount(FetchDescriptor<PersistedWallpaper>()) == 0)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "zikora-p02-recovery-\(UUID().uuidString)",
            isDirectory: true
        )
    }

    private func fixedUUID(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}

private final class RecoveryRecordingLogger: AppLogging, Sendable {
    private let storage = OSAllocatedUnfairLock(initialState: [AppLogRecord]())

    var records: [AppLogRecord] {
        storage.withLock { $0 }
    }

    func log(_ record: AppLogRecord) {
        storage.withLock { $0.append(record) }
    }
}
