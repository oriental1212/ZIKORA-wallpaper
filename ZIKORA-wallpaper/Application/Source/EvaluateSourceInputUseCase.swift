import Foundation

nonisolated struct EvaluateSourceInputUseCase: Sendable {
    private let sources: any SourceRepository

    init(sources: any SourceRepository) {
        self.sources = sources
    }

    func execute(
        input: SourceFormInput,
        context: SourceInputContext,
        connectionProof: SourceConnectionTestProof?,
        duplicateURLConfirmation: SourceDuplicateURLConfirmation? = nil
    ) async throws -> SourceInputDecision {
        let validation = Self.validate(input)
        guard let validatedInput = validation.input else {
            return SourceInputDecision(
                context: context,
                validatedInput: nil,
                issues: validation.issues,
                duplicateNameSourceIDs: [],
                duplicateURLSourceIDs: [],
                connectionProofIsCurrent: false
            )
        }

        let excludedSourceID = context.editingSourceID
        let existingSources = try await sources.allSources().filter {
            $0.id != excludedSourceID
        }
        let duplicateNameSourceIDs = existingSources
            .filter { $0.name == validatedInput.name }
            .map(\.id)
            .sorted(by: Self.sortIDs)
        let duplicateURLSourceIDs = existingSources
            .filter { Self.normalizedURL($0.url) == validatedInput.url }
            .map(\.id)
            .sorted(by: Self.sortIDs)
        let proofIsCurrent = connectionProof?.matches(validatedInput) == true
        var issues = validation.issues

        if context.requiresConnectionProof(for: validatedInput.url), !proofIsCurrent {
            issues.insert(.connectionTestRequired)
        }
        if !duplicateURLSourceIDs.isEmpty,
           duplicateURLConfirmation?.matches(validatedInput) != true {
            issues.insert(.duplicateURLConfirmationRequired)
        }

        return SourceInputDecision(
            context: context,
            validatedInput: validatedInput,
            issues: issues,
            duplicateNameSourceIDs: duplicateNameSourceIDs,
            duplicateURLSourceIDs: duplicateURLSourceIDs,
            connectionProofIsCurrent: proofIsCurrent
        )
    }

    static func validate(
        _ input: SourceFormInput
    ) -> (input: ValidatedSourceInput?, issues: Set<SourceInputIssue>) {
        let normalizedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedURLText = input.urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        var issues: Set<SourceInputIssue> = []

        if normalizedName.isEmpty {
            issues.insert(.nameRequired)
        } else if normalizedName.count > ValidatedSourceInput.maximumNameLength {
            issues.insert(.nameTooLong(maximum: ValidatedSourceInput.maximumNameLength))
        }

        let url = validatedURL(from: normalizedURLText)
        if url == nil {
            issues.insert(.invalidURL)
        }

        guard issues.isEmpty, let url else {
            return (nil, issues)
        }
        return (
            ValidatedSourceInput(name: normalizedName, url: url, isEnabled: input.isEnabled),
            issues
        )
    }

    private static func validatedURL(from value: String) -> URL? {
        guard !value.isEmpty,
              !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty else {
            return nil
        }

        components.scheme = scheme
        components.host = host.lowercased()
        return components.url
    }

    private static func normalizedURL(_ url: URL) -> URL? {
        validatedURL(from: url.absoluteString)
    }

    private static func sortIDs(_ lhs: SourceID, _ rhs: SourceID) -> Bool {
        lhs.rawValue.uuidString < rhs.rawValue.uuidString
    }
}

private extension SourceInputContext {
    nonisolated var editingSourceID: SourceID? {
        switch self {
        case .create:
            nil
        case .edit(let sourceID, _):
            sourceID
        }
    }

    nonisolated func requiresConnectionProof(for currentURL: URL) -> Bool {
        switch self {
        case .create:
            true
        case .edit(_, let originalURL):
            EvaluateSourceInputUseCase.validate(SourceFormInput(
                name: "original",
                urlText: originalURL.absoluteString,
                isEnabled: true
            )).input?.url != currentURL
        }
    }
}
