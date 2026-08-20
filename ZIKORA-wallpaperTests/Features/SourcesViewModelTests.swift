import Foundation
import Testing
@testable import ZIKORA_wallpaper

@MainActor
struct SourcesViewModelTests {
    @Test("Loading shows all sources, including disabled, and a complete seven-day plan")
    func loadShowsDisabledAndCompletePlan() async throws {
        let store = try InMemoryRepositoryStore()
        let enabled = try makeSource(id: 1, name: "Enabled", isEnabled: true)
        let disabled = try makeSource(id: 2, name: "Disabled", isEnabled: false)
        try await store.save(enabled)
        try await store.save(disabled)

        let model = SourcesViewModel(
            repository: store,
            clock: FixedClock(date: date(100)),
            calendar: FixedCalendarProvider(value: utcCalendar),
            uuidGenerator: FixedUUIDGenerator(value: fixedUUID(30))
        )
        await model.load()

        #expect(model.sources.map(\.name) == ["Enabled", "Disabled"])
        #expect(model.plan?.rows.map(\.weekday) == Weekday.allCases)
        #expect(model.plan?.rows.allSatisfy {
            $0.referenceState == .available(sourceID: enabled.id, name: enabled.name)
        } == true)
    }

    @Test("Disabling a source keeps it visible and removes it from selectable plan options")
    func disablingSourceUpdatesPlan() async throws {
        let store = try InMemoryRepositoryStore()
        let source = try makeSource(id: 1, name: "Only", isEnabled: true)
        try await store.save(source)
        let model = makeModel(store: store)
        await model.load()

        await model.setEnabled(sourceID: source.id, isEnabled: false)

        #expect(model.sources.first?.isEnabled == false)
        #expect(model.sources.count == 1)
        #expect(model.plan?.selectableSources.isEmpty == true)
    }

    @Test("Deleting a source clears plan and default references")
    func deleteClearsPlanAndDefault() async throws {
        let store = try InMemoryRepositoryStore()
        let source = try makeSource(id: 1, name: "Delete Me", isEnabled: true)
        let schedule = WeeklySchedule(
            id: fixedUUID(40),
            mondaySourceID: source.id,
            tuesdaySourceID: nil,
            wednesdaySourceID: source.id,
            thursdaySourceID: nil,
            fridaySourceID: nil,
            saturdaySourceID: nil,
            sundaySourceID: nil,
            defaultSourceID: source.id,
            updatedAt: date(10)
        )
        try await store.save(source)
        try await store.save(schedule)
        let model = makeModel(store: store)
        await model.load()

        await model.requestDelete(source)
        #expect(model.pendingDeletion?.affectedWeekdays == [.monday, .wednesday])
        #expect(model.pendingDeletion?.wasDefaultSource == true)

        await model.confirmDelete()
        #expect(try await store.source(id: source.id) == nil)
        #expect(model.plan?.schedule.mondaySourceID == nil)
        #expect(model.plan?.schedule.wednesdaySourceID == nil)
        #expect(model.plan?.schedule.defaultSourceID == nil)
    }

    @Test("Weekly plan day updates save immediately and refresh the snapshot")
    func updateDaySavesImmediately() async throws {
        let store = try InMemoryRepositoryStore()
        let source = try makeSource(id: 1, name: "Planned", isEnabled: true)
        try await store.save(source)
        let model = makeModel(store: store)
        await model.load()

        await model.updateDay(.friday, sourceID: source.id)

        #expect(model.plan?.schedule.fridaySourceID == source.id)
        #expect(model.plan?.rows.first { $0.weekday == .friday }?.referenceState
            == .available(sourceID: source.id, name: source.name))
        #expect(try await store.loadSchedule()?.fridaySourceID == source.id)
    }

    @Test("Default source updates only enabled sources and updates the displayed state")
    func updateDefaultSource() async throws {
        let store = try InMemoryRepositoryStore()
        let source = try makeSource(id: 1, name: "Default", isEnabled: true)
        try await store.save(source)
        let model = makeModel(store: store)
        await model.load()

        await model.updateDefault(sourceID: source.id)

        #expect(model.defaultReferenceState == .available(sourceID: source.id, name: source.name))
        #expect(try await store.loadSchedule()?.defaultSourceID == source.id)
    }

    private func makeModel(store: any RepositoryStore) -> SourcesViewModel {
        SourcesViewModel(
            repository: store,
            clock: FixedClock(date: date(100)),
            calendar: FixedCalendarProvider(value: utcCalendar),
            uuidGenerator: FixedUUIDGenerator(value: fixedUUID(30))
        )
    }

    private func makeSource(
        id: UInt8,
        name: String,
        isEnabled: Bool
    ) throws -> WallpaperSource {
        WallpaperSource(
            id: SourceID(rawValue: fixedUUID(id)),
            name: name,
            url: try #require(URL(string: "https://example.test/\(id).png")),
            isEnabled: isEnabled,
            createdAt: Date(timeIntervalSince1970: TimeInterval(id)),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(id)),
            lastFetchAt: nil,
            lastFetchStatus: .never,
            lastErrorCode: nil,
            lastErrorMessage: nil,
            consecutiveFailureDays: 0
        )
    }
}

@MainActor
struct SourceFormViewModelTests {
    @Test("Form validates inline, tests connection, and saves a created source")
    func createSourceHappyPath() async throws {
        let store = try InMemoryRepositoryStore()
        let downloader = StubImageDownloader(
            result: DownloadedImage(
                temporaryFileURL: try makeTemporaryFile(),
                responseMIMEType: "image/png",
                byteCount: 1234
            )
        )
        let coordinator = SourceConnectionTestCoordinator(
            useCase: TestSourceConnectionUseCase(
                downloader: downloader,
                validator: StubImageValidator(
                    result: ValidatedImage(
                        pixelWidth: 1920,
                        pixelHeight: 1080,
                        formatIdentifier: "public.png"
                    )
                ),
                clock: FixedClock(date: Date(timeIntervalSince1970: 42))
            )
        )
        var savedSourceID: SourceID?
        let model = SourceFormViewModel(
            repository: store,
            clock: FixedClock(date: Date(timeIntervalSince1970: 42)),
            uuidGenerator: FixedUUIDGenerator(value: fixedUUID(50)),
            logger: NoOpAppLogger(),
            mode: .create,
            coordinator: coordinator,
            onSaved: { savedSourceID = $0 }
        )

        #expect(model.validationIssues.contains(.nameRequired))
        #expect(model.validationIssues.contains(.invalidURL))

        model.setName("Daily")
        model.setURLText("HTTPS://EXAMPLE.TEST/image.png")
        await waitUntil { model.canTest }

        model.testConnection()
        await waitUntil {
            if case .success = model.connectionState { true } else { false }
        }
        guard case .success(let preview) = model.connectionState else {
            Issue.record("Expected a successful connection preview")
            return
        }
        #expect(preview.pixelWidth == 1920)
        #expect(preview.formatIdentifier == "public.png")
        await waitUntil { model.canSave }

        model.save()
        await waitUntil { savedSourceID != nil }

        #expect(savedSourceID != nil)
        #expect(try await store.allSources().count == 1)
    }

    @Test("Duplicate URL requires confirmation and duplicate names warn without blocking save")
    func duplicateURLConfirmation() async throws {
        let store = try InMemoryRepositoryStore()
        let existing = try makeSource(id: 1, name: "Existing", url: "https://example.test/same.png")
        try await store.save(existing)
        let coordinator = SourceConnectionTestCoordinator(
            useCase: TestSourceConnectionUseCase(
                downloader: StubImageDownloader(
                    result: DownloadedImage(
                        temporaryFileURL: try makeTemporaryFile(),
                        responseMIMEType: "image/png",
                        byteCount: 100
                    )
                ),
                validator: StubImageValidator(
                    result: ValidatedImage(pixelWidth: 1, pixelHeight: 1, formatIdentifier: "public.png")
                ),
                clock: FixedClock(date: Date(timeIntervalSince1970: 1))
            )
        )
        var savedSourceID: SourceID?
        let model = SourceFormViewModel(
            repository: store,
            clock: FixedClock(date: Date(timeIntervalSince1970: 1)),
            uuidGenerator: FixedUUIDGenerator(value: fixedUUID(51)),
            logger: NoOpAppLogger(),
            mode: .create,
            coordinator: coordinator,
            onSaved: { savedSourceID = $0 }
        )

        model.setName("Existing")
        model.setURLText("https://example.test/same.png")
        await waitUntil { model.canTest }
        model.testConnection()
        await waitUntil { model.duplicateURLNeedsConfirmation }

        model.save()
        await waitUntil { model.duplicateURLNeedsConfirmation }
        model.confirmDuplicateURLAndSave()
        await waitUntil { savedSourceID != nil }

        #expect(savedSourceID != nil)
        #expect(try await store.allSources().count == 2)
    }

    @Test("Changing the URL in edit mode forces a new connection test")
    func editURLRequiresRetest() async throws {
        let store = try InMemoryRepositoryStore()
        let source = try makeSource(id: 1, name: "Original", url: "https://example.test/original.png")
        try await store.save(source)
        let model = SourceFormViewModel(
            repository: store,
            clock: FixedClock(date: Date(timeIntervalSince1970: 1)),
            uuidGenerator: FixedUUIDGenerator(value: fixedUUID(52)),
            logger: NoOpAppLogger(),
            mode: .edit(source: source),
            onSaved: { _ in }
        )

        await waitUntil { model.canSave }
        model.setURLText("https://example.test/changed.png")
        await waitUntil { !model.canSave }

        #expect(!model.canSubmit)
    }

    @Test("A superseded connection test cannot publish a result for the new URL")
    func connectionTestCancellationRace() async throws {
        let firstFile = try makeTemporaryFile()
        let secondFile = try makeTemporaryFile()
        let downloader = BlockingImageDownloader(files: [firstFile, secondFile])
        let coordinator = SourceConnectionTestCoordinator(
            useCase: TestSourceConnectionUseCase(
                downloader: downloader,
                validator: StubImageValidator(
                    result: ValidatedImage(pixelWidth: 1, pixelHeight: 1, formatIdentifier: "public.png")
                ),
                clock: FixedClock(date: Date(timeIntervalSince1970: 1))
            )
        )
        let model = SourceFormViewModel(
            repository: try InMemoryRepositoryStore(),
            clock: FixedClock(date: Date(timeIntervalSince1970: 1)),
            uuidGenerator: FixedUUIDGenerator(value: fixedUUID(53)),
            logger: NoOpAppLogger(),
            mode: .create,
            coordinator: coordinator,
            onSaved: { _ in }
        )

        model.setName("Race")
        model.setURLText("https://example.test/first.png")
        await waitUntil { model.canTest }
        model.testConnection()
        await downloader.waitUntilStarted(count: 1)

        model.setURLText("https://example.test/second.png")
        await waitUntil { model.canTest }
        model.testConnection()
        await downloader.waitUntilStarted(count: 2)
        await downloader.releaseNext()

        await waitUntil {
            if case .success = model.connectionState { true } else { false }
        }
        #expect(model.validatedURL?.absoluteString == "https://example.test/second.png")
    }

    private func makeSource(
        id: UInt8,
        name: String,
        url: String
    ) throws -> WallpaperSource {
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
}

private let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

@MainActor
private func waitUntil(
    timeout: TimeInterval = 2,
    _ condition: @escaping () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        await Task.yield()
    }
}

private func date(_ second: TimeInterval) -> Date {
    Date(timeIntervalSince1970: second)
}

private func fixedUUID(_ value: UInt8) -> UUID {
    UUID(uuid: (
        UInt8(value), 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0
    ))
}

private actor StubImageDownloader: ImageDownloading {
    let result: DownloadedImage

    init(result: DownloadedImage) {
        self.result = result
    }

    func download(from _: URL) async throws -> DownloadedImage {
        result
    }
}

private struct StubImageValidator: ImageValidating {
    let result: ValidatedImage

    func validate(fileAt _: URL, declaredMIMEType _: String?) async throws -> ValidatedImage {
        result
    }
}

private actor BlockingImageDownloader: ImageDownloading {
    private var files: [URL]
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var startedCount = 0

    init(files: [URL]) {
        self.files = files
    }

    func download(from _: URL) async throws -> DownloadedImage {
        startedCount += 1
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                waiters.append(continuation)
            }
        } onCancel: {
            Task { await self.cancelWaiter() }
        }
        try Task.checkCancellation()
        return DownloadedImage(
            temporaryFileURL: files.removeFirst(),
            responseMIMEType: "image/png",
            byteCount: 1
        )
    }

    func waitUntilStarted(count: Int) async {
        while startedCount < count {
            await Task.yield()
        }
    }

    func releaseNext() {
        guard !waiters.isEmpty else {
            return
        }
        waiters.removeFirst().resume()
    }

    private func cancelWaiter() {
        guard !waiters.isEmpty else {
            return
        }
        waiters.removeFirst().resume()
    }
}

private func makeTemporaryFile() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("zikora-sources-ui-\(UUID().uuidString)")
    try Data("fixture".utf8).write(to: url)
    return url
}
