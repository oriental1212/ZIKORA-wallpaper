import Foundation
import Testing
@testable import ZIKORA_wallpaper

struct RepositoryTestDoubleTests {
    @Test("Production in-memory repository conforms to the concrete domain boundary")
    func sourceCRUD() async throws {
        let repository = try InMemoryRepositoryStore()
        let now = Date(timeIntervalSince1970: 1_787_097_600)
        let sourceID = SourceID(rawValue: UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
        ))
        let url = try #require(URL(string: "https://example.invalid/wallpaper.png"))
        let source = WallpaperSource(
            id: sourceID,
            name: "First",
            url: url,
            isEnabled: true,
            createdAt: now,
            updatedAt: now,
            lastFetchAt: nil,
            lastFetchStatus: .never,
            lastErrorCode: nil,
            lastErrorMessage: nil,
            consecutiveFailureDays: 0
        )

        try await repository.save(source)
        #expect(try await repository.source(id: sourceID) == source)
        try await repository.delete(id: sourceID, scheduleUpdatedAt: now)
        #expect(try await repository.source(id: sourceID) == nil)
    }

    @Test("Sequence fakes return scripted values without sleeping or randomness")
    func scriptedRuntimeDependencies() async {
        let first = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let fallback = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9))
        let uuids = SequenceUUIDGenerator(values: [first], fallback: fallback)
        let random = SequenceRandomSelector(values: [-1, 8], fallback: 0)

        #expect(await uuids.makeUUID() == first)
        #expect(await uuids.makeUUID() == fallback)
        #expect(await random.index(upperBound: 5) == 4)
        #expect(await random.index(upperBound: 5) == 3)
        #expect(await random.index(upperBound: 0) == nil)
    }
}
