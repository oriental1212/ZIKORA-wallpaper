import Foundation
@testable import ZIKORA_wallpaper

actor SequenceUUIDGenerator: UUIDGenerating {
    private var values: [UUID]
    private let fallback: UUID

    init(values: [UUID], fallback: UUID) {
        self.values = values
        self.fallback = fallback
    }

    func makeUUID() async -> UUID {
        guard !values.isEmpty else {
            return fallback
        }

        return values.removeFirst()
    }
}

actor SequenceRandomSelector: RandomSelecting {
    private var values: [Int]
    private let fallback: Int

    init(values: [Int], fallback: Int = 0) {
        self.values = values
        self.fallback = fallback
    }

    func index(upperBound: Int) async -> Int? {
        guard upperBound > 0 else {
            return nil
        }

        let value = values.isEmpty ? fallback : values.removeFirst()
        let remainder = value % upperBound
        return remainder >= 0 ? remainder : remainder + upperBound
    }
}
