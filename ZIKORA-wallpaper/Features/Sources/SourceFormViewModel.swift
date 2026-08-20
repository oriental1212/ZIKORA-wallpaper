import Combine
import Foundation
import SwiftUI

enum SourceFormMode: Equatable {
    case create
    case edit(source: WallpaperSource)
}

enum SourceFormConnectionState: Equatable {
    case idle
    case loading
    case success(SourceConnectionPreview)
    case failure(UserMessage)
}

@MainActor
final class SourceFormViewModel: ObservableObject {
    @Published private(set) var name: String
    @Published private(set) var urlText: String
    @Published private(set) var isEnabled: Bool
    @Published private(set) var validationIssues: Set<SourceInputIssue> = []
    @Published private(set) var connectionState: SourceFormConnectionState = .idle
    @Published private(set) var duplicateNameWarning = false
    @Published private(set) var duplicateURLNeedsConfirmation = false
    @Published private(set) var canSave = false
    @Published private(set) var isSaving = false
    @Published private(set) var savedSourceID: SourceID?
    @Published var saveError: UserMessage?

    let mode: SourceFormMode

    private let repository: any SourceRepository
    private let clock: any Clock
    private let uuidGenerator: any UUIDGenerating
    private let coordinator: SourceConnectionTestCoordinator
    private var connectionProof: SourceConnectionTestProof?
    private var duplicateURLConfirmation: SourceDuplicateURLConfirmation?
    private var testGeneration = 0
    private var evaluationGeneration = 0
    private var evaluationTask: Task<Void, Never>?
    var onSaved: ((SourceID) -> Void)?

    init(
        repository: any SourceRepository,
        clock: any Clock,
        uuidGenerator: any UUIDGenerating,
        logger: any AppLogging,
        mode: SourceFormMode,
        coordinator: SourceConnectionTestCoordinator? = nil,
        onSaved: @escaping (SourceID) -> Void
    ) {
        self.repository = repository
        self.clock = clock
        self.uuidGenerator = uuidGenerator
        self.mode = mode
        self.coordinator = coordinator ?? SourceConnectionTestCoordinator(
            useCase: TestSourceConnectionUseCase(
                downloader: URLSessionImageDownloader(logger: logger),
                validator: ImageIOImageValidator(),
                clock: clock
            )
        )
        self.onSaved = onSaved

        switch mode {
        case .create:
            self.name = ""
            self.urlText = ""
            self.isEnabled = true
        case .edit(let source):
            self.name = source.name
            self.urlText = source.url.absoluteString
            self.isEnabled = source.isEnabled
        }

        evaluateValidation()
        Task { await evaluateAvailability(generation: 0) }
    }

    var currentInput: SourceFormInput {
        SourceFormInput(name: name, urlText: urlText, isEnabled: isEnabled)
    }

    var validatedURL: URL? {
        EvaluateSourceInputUseCase.validate(currentInput).input?.url
    }

    var canTest: Bool {
        EvaluateSourceInputUseCase.validate(currentInput).input != nil
            && !validationIssues.contains(.invalidURL)
    }

    var canSubmit: Bool {
        !isSaving && (canSave || duplicateURLNeedsConfirmation)
    }

    var testDisabledReason: LocalizedStringKey {
        if validationIssues.contains(.nameRequired) {
            return "source.form.name.required"
        }
        if validationIssues.contains(where: { issue in
            if case .nameTooLong = issue { return true }
            return false
        }) {
            return "source.form.name.too-long"
        }
        if validationIssues.contains(.invalidURL) {
            return "source.form.url.invalid"
        }
        if connectionState == .loading {
            return "status.loading"
        }
        return "source.form.test.required"
    }

    var saveDisabledReason: LocalizedStringKey {
        if validationIssues.contains(.nameRequired) {
            return "source.form.name.required"
        }
        if validationIssues.contains(where: { issue in
            if case .nameTooLong = issue { return true }
            return false
        }) {
            return "source.form.name.too-long"
        }
        if validationIssues.contains(.invalidURL) {
            return "source.form.url.invalid"
        }
        if validationIssues.contains(.connectionTestRequired) {
            return "source.form.test.required"
        }
        return "source.form.save.disabled"
    }

    func setName(_ value: String) {
        guard name != value else {
            return
        }
        name = value
        inputChanged()
    }

    func setURLText(_ value: String) {
        guard urlText != value else {
            return
        }
        urlText = value
        inputChanged()
    }

    func setIsEnabled(_ value: Bool) {
        guard isEnabled != value else {
            return
        }
        isEnabled = value
        inputChanged()
    }

    func testConnection() {
        guard canTest else {
            return
        }

        testGeneration += 1
        let generation = testGeneration
        let input = currentInput
        connectionState = .loading
        connectionProof = nil
        duplicateURLConfirmation = nil
        saveError = nil

        Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let result = try await self.coordinator.test(input: input)
                guard generation == self.testGeneration else {
                    return
                }
                self.connectionProof = result.proof
                self.connectionState = .success(result.preview)
                await self.evaluateAvailability(generation: self.evaluationGeneration)
            } catch is CancellationError {
                // A superseded test is intentionally ignored.
            } catch {
                guard generation == self.testGeneration else {
                    return
                }
                self.connectionProof = nil
                self.connectionState = .failure(Self.userMessage(for: error))
                await self.evaluateAvailability(generation: self.evaluationGeneration)
            }
        }
    }

    func cancelTest() {
        testGeneration += 1
        let coordinator = coordinator
        Task {
            await coordinator.cancel()
        }
    }

    func save() {
        guard canSubmit else {
            return
        }

        Task {
            await performSave()
        }
    }

    func confirmDuplicateURLAndSave() {
        guard let input = EvaluateSourceInputUseCase.validate(currentInput).input else {
            return
        }
        duplicateURLConfirmation = SourceDuplicateURLConfirmation(
            inputFingerprint: input.fingerprint
        )
        duplicateURLNeedsConfirmation = false
        Task {
            await performSave()
        }
    }

    func cancelDuplicateURL() {
        duplicateURLNeedsConfirmation = false
        duplicateURLConfirmation = nil
    }

    private func inputChanged() {
        evaluateValidation()

        if connectionState == .loading {
            testGeneration += 1
            connectionState = .idle
            let coordinator = coordinator
            Task {
                await coordinator.cancel()
            }
        }

        if let validatedURL,
           connectionProof?.inputFingerprint.url != validatedURL {
            connectionProof = nil
            connectionState = .idle
            duplicateURLConfirmation = nil
        }

        evaluationGeneration += 1
        let generation = evaluationGeneration
        evaluationTask?.cancel()
        evaluationTask = Task { [weak self] in
            await self?.evaluateAvailability(generation: generation)
        }
    }

    private func evaluateValidation() {
        validationIssues = EvaluateSourceInputUseCase.validate(currentInput).issues
    }

    private func evaluateAvailability(generation: Int) async {
        guard EvaluateSourceInputUseCase.validate(currentInput).input != nil else {
            duplicateNameWarning = false
            duplicateURLNeedsConfirmation = false
            canSave = false
            return
        }

        do {
            let decision = try await EvaluateSourceInputUseCase(sources: repository).execute(
                input: currentInput,
                context: context,
                connectionProof: connectionProof,
                duplicateURLConfirmation: duplicateURLConfirmation
            )
            guard generation == evaluationGeneration else {
                return
            }
            duplicateNameWarning = !decision.duplicateNameSourceIDs.isEmpty
            duplicateURLNeedsConfirmation = decision.issues.contains(.duplicateURLConfirmationRequired)
            let blockingIssues = decision.issues.subtracting([.duplicateURLConfirmationRequired])
            canSave = decision.validatedInput != nil && blockingIssues.isEmpty
        } catch {
            guard generation == evaluationGeneration else {
                return
            }
            duplicateNameWarning = false
            duplicateURLNeedsConfirmation = false
            canSave = false
        }
    }

    private func performSave() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let decision = try await EvaluateSourceInputUseCase(sources: repository).execute(
                input: currentInput,
                context: context,
                connectionProof: connectionProof,
                duplicateURLConfirmation: duplicateURLConfirmation
            )

            if decision.issues.contains(.duplicateURLConfirmationRequired) {
                duplicateURLNeedsConfirmation = true
                return
            }
            guard decision.canSave, let input = decision.validatedInput else {
                saveError = Self.userMessage(for: SourceManagementError.inputNotReady)
                return
            }

            let source = try await SaveSourceUseCase(
                sources: repository,
                clock: clock,
                uuidGenerator: uuidGenerator
            ).execute(
                input: SourceFormInput(
                    name: input.name,
                    urlText: input.url.absoluteString,
                    isEnabled: input.isEnabled
                ),
                context: context,
                connectionProof: connectionProof,
                duplicateURLConfirmation: duplicateURLConfirmation
            )
            savedSourceID = source.id
            onSaved?(source.id)
        } catch {
            saveError = Self.userMessage(for: error)
        }
    }

    private var context: SourceInputContext {
        switch mode {
        case .create:
            .create
        case .edit(let source):
            .edit(sourceID: source.id, originalURL: source.url)
        }
    }

    private static func userMessage(for error: Error) -> UserMessage {
        if let failure = error as? AppFailure {
            return UserMessageCatalog.message(for: failure)
        }
        if let repositoryError = error as? RepositoryError {
            switch repositoryError {
            case .notFound:
                return UserMessageCatalog.message(for: AppFailure(code: .missingConfiguration))
            case .duplicateContentHash, .duplicateTaskKey, .invalidPersistedValue, .persistenceFailed:
                return UserMessageCatalog.message(for: AppFailure(code: .persistenceFailed))
            }
        }
        return UserMessageCatalog.message(for: AppFailure(code: .unknown))
    }
}
