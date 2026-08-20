import Foundation
import Testing
@testable import ZIKORA_wallpaper

struct WallpaperSelectionPolicyTests {
    @Test("Selection excludes invalid files and protects current in random mode")
    func filtersCandidates() async {
        let current = makeWallpaper(id: 1, createdAt: 1, current: true)
        let invalid = makeWallpaper(id: 2, createdAt: 2, state: .missing)
        let candidate = makeWallpaper(id: 3, createdAt: 3)

        #expect(WallpaperSelectionPolicy.randomPool([current, invalid, candidate]).map(\.id) == [candidate.id])
        #expect(await WallpaperSelectionPolicy.selectRandom(
            [current, invalid, candidate], selector: FixedRandomSelector(value: 0)
        )?.id == candidate.id)
    }

    @Test("Chronological ordering is stable and manual daily ordering is newest first")
    func stableOrdering() {
        let first = makeWallpaper(id: 1, createdAt: 10)
        let second = makeWallpaper(id: 2, createdAt: 10)
        let third = makeWallpaper(id: 3, createdAt: 20)
        let chronological = WallpaperSelectionPolicy.chronological([third, second, first])
        #expect(chronological.map(\.id) == [first.id, second.id, third.id])
        #expect(WallpaperSelectionPolicy.manualDaily([first, second, third]).map(\.id) == [third.id, second.id, first.id])
    }

    @Test("Random selection avoids the previous item when alternatives exist")
    func randomAvoidsRepeat() async {
        let first = makeWallpaper(id: 1, createdAt: 1)
        let second = makeWallpaper(id: 2, createdAt: 2)
        #expect(await WallpaperSelectionPolicy.selectRandom(
            [first, second], previousID: first.id, selector: FixedRandomSelector(value: 0)
        )?.id == second.id)
        #expect(WallpaperSelectionPolicy.randomPool([first], previousID: first.id).count == 1)
    }

    private func makeWallpaper(
        id: UInt8,
        createdAt: TimeInterval,
        state: WallpaperFileState = .available,
        current: Bool = false
    ) -> Wallpaper {
        Wallpaper(
            id: WallpaperID(rawValue: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, id))),
            contentHash: "hash-\(id)", sourceID: nil, sourceNameSnapshot: "source",
            relativePath: ManagedRelativePath(rawValue: "2026-08-19/\(id).jpg")!,
            downloadDay: LocalDay(rawValue: "2026-08-19")!, createdAt: Date(timeIntervalSince1970: createdAt),
            pixelWidth: 1, pixelHeight: 1, fileSize: 1, format: .jpeg, fileState: state, isCurrent: current
        )
    }
}
