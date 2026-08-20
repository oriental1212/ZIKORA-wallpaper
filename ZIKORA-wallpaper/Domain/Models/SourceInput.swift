import Foundation

nonisolated struct SourceFormInput: Equatable, Sendable {
    var name: String
    var urlText: String
    var isEnabled: Bool
}

nonisolated struct ValidatedSourceInput: Equatable, Sendable {
    static let maximumNameLength = 50

    let name: String
    let url: URL
    let isEnabled: Bool

    var fingerprint: SourceInputFingerprint {
        SourceInputFingerprint(name: name, url: url)
    }
}

nonisolated struct SourceInputFingerprint: Equatable, Hashable, Sendable {
    let name: String
    let url: URL
}

nonisolated struct SourceConnectionTestProof: Equatable, Sendable {
    let inputFingerprint: SourceInputFingerprint
    let testedAt: Date

    func matches(_ input: ValidatedSourceInput) -> Bool {
        inputFingerprint == input.fingerprint
    }
}

nonisolated struct SourceDuplicateURLConfirmation: Equatable, Sendable {
    let inputFingerprint: SourceInputFingerprint

    func matches(_ input: ValidatedSourceInput) -> Bool {
        inputFingerprint == input.fingerprint
    }
}

nonisolated enum SourceInputContext: Equatable, Sendable {
    case create
    case edit(sourceID: SourceID, originalURL: URL)
}

nonisolated enum SourceInputIssue: Equatable, Hashable, Sendable {
    case nameRequired
    case nameTooLong(maximum: Int)
    case invalidURL
    case connectionTestRequired
    case duplicateURLConfirmationRequired
}

nonisolated struct SourceInputDecision: Equatable, Sendable {
    let context: SourceInputContext
    let validatedInput: ValidatedSourceInput?
    let issues: Set<SourceInputIssue>
    let duplicateNameSourceIDs: [SourceID]
    let duplicateURLSourceIDs: [SourceID]
    let connectionProofIsCurrent: Bool

    var canSave: Bool {
        issues.isEmpty && validatedInput != nil
    }
}
