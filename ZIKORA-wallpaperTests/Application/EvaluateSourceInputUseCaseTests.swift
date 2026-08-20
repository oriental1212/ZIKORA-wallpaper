import Foundation
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct EvaluateSourceInputUseCaseTests {
    @Test("Name and URL validation normalize supported input and reject invalid fields")
    func validationBoundaries() throws {
        let international = EvaluateSourceInputUseCase.validate(SourceFormInput(
            name: "  每日风景  ",
            urlText: "  HTTPS://例子.测试/壁纸.png?token=私密  ",
            isEnabled: true
        ))
        let validated = try #require(international.input)
        #expect(international.issues.isEmpty)
        #expect(validated.name == "每日风景")
        #expect(validated.url.scheme == "https")
        #expect(validated.url.host == "xn--fsqu00a.xn--0zwm56d")
        #expect(validated.url.query?.contains("token=") == true)

        let blankAndInvalid = EvaluateSourceInputUseCase.validate(SourceFormInput(
            name: " \n ",
            urlText: "file:///tmp/private.png",
            isEnabled: true
        ))
        #expect(blankAndInvalid.input == nil)
        #expect(blankAndInvalid.issues == [.nameRequired, .invalidURL])
        #expect(EvaluateSourceInputUseCase.validate(SourceFormInput(
            name: "FTP",
            urlText: "ftp://example.test/image.png",
            isEnabled: true
        )).issues == [.invalidURL])
        #expect(EvaluateSourceInputUseCase.validate(SourceFormInput(
            name: "Missing Host",
            urlText: "https:///image.png",
            isEnabled: true
        )).issues == [.invalidURL])

        let tooLong = EvaluateSourceInputUseCase.validate(SourceFormInput(
            name: String(repeating: "图", count: 51),
            urlText: "https://example.test/image.png",
            isEnabled: true
        ))
        #expect(tooLong.issues == [.nameTooLong(maximum: 50)])
        #expect(EvaluateSourceInputUseCase.validate(SourceFormInput(
            name: String(repeating: "图", count: 50),
            urlText: "http://example.test/image.png",
            isEnabled: false
        )).input != nil)
    }

    @Test("New sources require a successful proof matching the current name and URL")
    func createProofFingerprint() async throws {
        let store = try InMemoryRepositoryStore()
        let useCase = EvaluateSourceInputUseCase(sources: store)
        let originalInput = SourceFormInput(
            name: "Mountains",
            urlText: "https://example.test/mountains.jpg?token=secret",
            isEnabled: true
        )
        let validated = try #require(EvaluateSourceInputUseCase.validate(originalInput).input)
        let proof = SourceConnectionTestProof(
            inputFingerprint: validated.fingerprint,
            testedAt: Date(timeIntervalSince1970: 1_787_097_600)
        )

        let ready = try await useCase.execute(
            input: originalInput,
            context: .create,
            connectionProof: proof
        )
        #expect(ready.canSave)
        #expect(ready.connectionProofIsCurrent)

        var renamed = originalInput
        renamed.name = "New Mountains"
        let renamedDecision = try await useCase.execute(
            input: renamed,
            context: .create,
            connectionProof: proof
        )
        #expect(!renamedDecision.canSave)
        #expect(renamedDecision.issues == [.connectionTestRequired])

        var changedURL = originalInput
        changedURL.urlText = "https://example.test/other.jpg?token=secret"
        let changedURLDecision = try await useCase.execute(
            input: changedURL,
            context: .create,
            connectionProof: proof
        )
        #expect(!changedURLDecision.connectionProofIsCurrent)
        #expect(changedURLDecision.issues == [.connectionTestRequired])
    }

    @Test("Duplicate names warn while duplicate URLs require explicit confirmation")
    func duplicateSignals() async throws {
        let first = try source(id: 1, name: "Daily", url: "https://example.test/daily.png")
        let second = try source(id: 2, name: "Other", url: "https://example.test/other.png")
        let store = try InMemoryRepositoryStore(sources: [first, second])
        let useCase = EvaluateSourceInputUseCase(sources: store)
        let input = SourceFormInput(
            name: " Daily ",
            urlText: "HTTPS://EXAMPLE.TEST/daily.png",
            isEnabled: true
        )
        let validated = try #require(EvaluateSourceInputUseCase.validate(input).input)
        let proof = SourceConnectionTestProof(
            inputFingerprint: validated.fingerprint,
            testedAt: .distantPast
        )

        let unconfirmed = try await useCase.execute(
            input: input,
            context: .create,
            connectionProof: proof
        )
        #expect(unconfirmed.duplicateNameSourceIDs == [first.id])
        #expect(unconfirmed.duplicateURLSourceIDs == [first.id])
        #expect(unconfirmed.issues == [.duplicateURLConfirmationRequired])
        #expect(!unconfirmed.canSave)

        let confirmed = try await useCase.execute(
            input: input,
            context: .create,
            connectionProof: proof,
            duplicateURLConfirmation: SourceDuplicateURLConfirmation(
                inputFingerprint: validated.fingerprint
            )
        )
        #expect(confirmed.canSave)
        #expect(confirmed.duplicateNameSourceIDs == [first.id])
    }

    @Test("Editing name or enabled state keeps validity, but changing URL requires a new proof")
    func editRulesAndSelfExclusion() async throws {
        let original = try source(id: 3, name: "Original", url: "https://example.test/original.png")
        let store = try InMemoryRepositoryStore(sources: [original])
        let useCase = EvaluateSourceInputUseCase(sources: store)
        let renamed = SourceFormInput(
            name: "Renamed",
            urlText: original.url.absoluteString,
            isEnabled: false
        )

        let renamedDecision = try await useCase.execute(
            input: renamed,
            context: .edit(sourceID: original.id, originalURL: original.url),
            connectionProof: nil
        )
        #expect(renamedDecision.canSave)
        #expect(renamedDecision.duplicateNameSourceIDs.isEmpty)
        #expect(renamedDecision.duplicateURLSourceIDs.isEmpty)

        let changed = SourceFormInput(
            name: "Renamed",
            urlText: "https://example.test/changed.png",
            isEnabled: false
        )
        let changedDecision = try await useCase.execute(
            input: changed,
            context: .edit(sourceID: original.id, originalURL: original.url),
            connectionProof: nil
        )
        #expect(changedDecision.issues == [.connectionTestRequired])
        #expect(!changedDecision.canSave)
    }

    @Test("Evaluation and cancellation do not mutate persisted sources")
    func evaluationHasNoPersistenceSideEffects() async throws {
        let original = try source(id: 4, name: "Keep", url: "https://example.test/keep.png")
        let store = try InMemoryRepositoryStore(sources: [original])
        let useCase = EvaluateSourceInputUseCase(sources: store)

        _ = try await useCase.execute(
            input: SourceFormInput(
                name: "Cancelled Edit",
                urlText: "https://example.test/cancelled.png",
                isEnabled: false
            ),
            context: .edit(sourceID: original.id, originalURL: original.url),
            connectionProof: nil
        )

        #expect(try await store.allSources() == [original])
    }

    private func source(id: UInt8, name: String, url: String) throws -> WallpaperSource {
        WallpaperSource(
            id: SourceID(rawValue: fixedUUID(id)),
            name: name,
            url: try #require(URL(string: url)),
            isEnabled: true,
            createdAt: Date(timeIntervalSince1970: TimeInterval(id)),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(id)),
            lastFetchAt: nil,
            lastFetchStatus: .never,
            lastErrorCode: nil,
            lastErrorMessage: nil,
            consecutiveFailureDays: 0
        )
    }

    private func fixedUUID(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
