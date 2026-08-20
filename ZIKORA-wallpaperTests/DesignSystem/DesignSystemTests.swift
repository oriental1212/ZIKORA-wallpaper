import SwiftUI
import Testing
@testable import ZIKORA_wallpaper

struct DesignSystemTests {
    @Test("Spacing and radius tokens use the locked scale")
    func tokenScale() {
        #expect(DesignSpacing.compact == 4)
        #expect(DesignSpacing.small == 8)
        #expect(DesignSpacing.standard == 16)
        #expect(DesignSpacing.large == 24)
        #expect(DesignSpacing.section == 32)
        #expect(DesignRadius.control < DesignRadius.card)
    }

    @Test("Status semantics always include an SF Symbol, not color alone")
    func statusSymbols() {
        let statuses: [StatusBadgeKind] = [.information, .success, .warning, .failure, .disabled]
        #expect(statuses.allSatisfy { !$0.systemImage.isEmpty })
    }

    @Test("Button operation phases expose text or icon feedback")
    func buttonPhases() {
        #expect(ZIKORAButtonPhase.loading.statusKey != nil)
        #expect(ZIKORAButtonPhase.success.systemImage == "checkmark")
        #expect(ZIKORAButtonPhase.failure.systemImage == "exclamationmark.triangle")
    }

    @Test("Reduce Motion removes nonessential state animation")
    func reducedMotion() {
        #expect(DesignMotion.stateChange(reduceMotion: true) == nil)
        #expect(DesignMotion.stateChange(reduceMotion: false) != nil)
    }
}
