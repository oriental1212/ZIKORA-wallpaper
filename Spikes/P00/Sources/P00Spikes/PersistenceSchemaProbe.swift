import Foundation
import SwiftData

@Model
final class ProbeSource {
    @Attribute(.unique) var id: UUID
    var name: String
    var url: URL
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, url: URL, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
    }
}

@Model
final class ProbeWallpaper {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var contentHash: String
    var sourceID: UUID?
    var sourceNameSnapshot: String
    var relativePath: String
    var isCurrent: Bool

    init(
        id: UUID = UUID(),
        contentHash: String,
        sourceID: UUID?,
        sourceNameSnapshot: String,
        relativePath: String,
        isCurrent: Bool
    ) {
        self.id = id
        self.contentHash = contentHash
        self.sourceID = sourceID
        self.sourceNameSnapshot = sourceNameSnapshot
        self.relativePath = relativePath
        self.isCurrent = isCurrent
    }
}

@Model
final class ProbeDailyFetchRecord {
    @Attribute(.unique) var taskKey: String
    var localDate: String
    var automaticAttemptCount: Int
    var nextRetryAt: Date?
    var wallpaperID: UUID?

    init(
        taskKey: String,
        localDate: String,
        automaticAttemptCount: Int,
        nextRetryAt: Date?,
        wallpaperID: UUID?
    ) {
        self.taskKey = taskKey
        self.localDate = localDate
        self.automaticAttemptCount = automaticAttemptCount
        self.nextRetryAt = nextRetryAt
        self.wallpaperID = wallpaperID
    }
}

enum PersistenceSchemaProbe {
    @MainActor
    static func run() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("zikora-p00-persistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storeURL = rootURL.appendingPathComponent("probe.store")
        let schema = Schema([
            ProbeSource.self,
            ProbeWallpaper.self,
            ProbeDailyFetchRecord.self,
        ])

        let sourceID = UUID()
        let wallpaperID = UUID()

        try writeSeedData(
            schema: schema,
            storeURL: storeURL,
            sourceID: sourceID,
            wallpaperID: wallpaperID
        )
        try verifyReopenAndDeleteSemantics(
            schema: schema,
            storeURL: storeURL,
            sourceID: sourceID,
            wallpaperID: wallpaperID
        )

        reportPass("SwiftData save/reopen and source-history retention")
    }

    @MainActor
    private static func writeSeedData(
        schema: Schema,
        storeURL: URL,
        sourceID: UUID,
        wallpaperID: UUID
    ) throws {
        let container = try makeContainer(schema: schema, storeURL: storeURL)
        let context = ModelContext(container)
        let sourceURL = try requireURL("https://example.invalid/wallpaper.png")
        let source = ProbeSource(id: sourceID, name: "Probe Source", url: sourceURL)
        let wallpaper = ProbeWallpaper(
            id: wallpaperID,
            contentHash: "probe-sha256",
            sourceID: sourceID,
            sourceNameSnapshot: source.name,
            relativePath: "Wallpapers/2026-08-18/probe.png",
            isCurrent: true
        )
        let record = ProbeDailyFetchRecord(
            taskKey: "2026-08-18|daily",
            localDate: "2026-08-18",
            automaticAttemptCount: 2,
            nextRetryAt: Date(timeIntervalSince1970: 1_787_000_000),
            wallpaperID: wallpaperID
        )

        context.insert(source)
        context.insert(wallpaper)
        context.insert(record)
        try context.save()
    }

    @MainActor
    private static func verifyReopenAndDeleteSemantics(
        schema: Schema,
        storeURL: URL,
        sourceID: UUID,
        wallpaperID: UUID
    ) throws {
        let container = try makeContainer(schema: schema, storeURL: storeURL)
        let context = ModelContext(container)

        let sources = try context.fetch(FetchDescriptor<ProbeSource>())
        let wallpapers = try context.fetch(FetchDescriptor<ProbeWallpaper>())
        let records = try context.fetch(FetchDescriptor<ProbeDailyFetchRecord>())

        try require(sources.count == 1, "Expected one source after reopening the store")
        try require(wallpapers.count == 1, "Expected one wallpaper after reopening the store")
        try require(records.first?.automaticAttemptCount == 2, "Retry state did not survive reopening")
        try require(wallpapers.first?.sourceID == sourceID, "Wallpaper source snapshot link changed")
        try require(records.first?.wallpaperID == wallpaperID, "Daily record wallpaper link changed")

        if let source = sources.first {
            context.delete(source)
            try context.save()
        }

        let remainingWallpapers = try context.fetch(FetchDescriptor<ProbeWallpaper>())
        try require(remainingWallpapers.count == 1, "Deleting a source must not delete wallpaper history")
        try require(
            remainingWallpapers.first?.sourceNameSnapshot == "Probe Source",
            "Wallpaper source-name snapshot must survive source deletion"
        )
    }

    private static func makeContainer(schema: Schema, storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "P00Probe",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func requireURL(_ value: String) throws -> URL {
        guard let url = URL(string: value) else {
            throw ProbeFailure("Invalid probe URL")
        }
        return url
    }
}

