import Combine
import Foundation

@MainActor
final class SourcesViewModel: ObservableObject {
    @Published private(set) var sources: [WallpaperSource] = []
    @Published private(set) var plan: WeeklyPlanSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: UserMessage?
    @Published private(set) var isPreparingDeletion = false
    @Published var pendingDeletion: SourceDeletionImpact?
    @Published var notice: OperationNotice?
    @Published private(set) var focusedSourceID: SourceID?

    private let repository: any RepositoryStore
    private let clock: any Clock
    private let calendar: any CalendarProviding
    private let uuidGenerator: any UUIDGenerating
    private var resetFocusTask: Task<Void, Never>?

    init(
        repository: any RepositoryStore,
        clock: any Clock = SystemClock(),
        calendar: any CalendarProviding = SystemCalendarProvider(),
        uuidGenerator: any UUIDGenerating = SystemUUIDGenerator()
    ) {
        self.repository = repository
        self.clock = clock
        self.calendar = calendar
        self.uuidGenerator = uuidGenerator
    }

    var defaultReferenceState: WeeklyPlanReferenceState {
        guard let schedule = plan?.schedule else {
            return .unset
        }
        guard let sourceID = schedule.defaultSourceID else {
            return .unset
        }
        guard let source = sources.first(where: { $0.id == sourceID }) else {
            return .missing(sourceID: sourceID)
        }
        return source.isEnabled
            ? .available(sourceID: sourceID, name: source.name)
            : .disabled(sourceID: sourceID, name: source.name)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedSources = try await ListSourcesUseCase(sources: repository).execute()
            let fetchedPlan = try await makePreparePlanUseCase().execute()
            sources = fetchedSources
            plan = fetchedPlan
            loadError = nil
        } catch {
            loadError = Self.userMessage(for: error)
        }
    }

    func setEnabled(sourceID: SourceID, isEnabled: Bool) async {
        do {
            let updated = try await SetSourceEnabledUseCase(
                sources: repository,
                clock: clock
            ).execute(sourceID: sourceID, isEnabled: isEnabled)
            replace(updated)
            try await refreshPlan()
        } catch {
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
            await load()
        }
    }

    func updateDay(_ weekday: Weekday, sourceID: SourceID?) async {
        do {
            _ = try await UpdateWeeklyPlanDayUseCase(
                sources: repository,
                schedules: repository,
                clock: clock,
                uuidGenerator: uuidGenerator
            ).execute(weekday: weekday, sourceID: sourceID)
            try await refreshPlan()
        } catch {
            notice = OperationNotice(
                tone: Self.tone(for: error),
                message: Self.userMessage(for: error)
            )
            await load()
        }
    }

    func updateDefault(sourceID: SourceID?) async {
        do {
            _ = try await UpdateDefaultSourceUseCase(
                sources: repository,
                schedules: repository,
                clock: clock,
                uuidGenerator: uuidGenerator
            ).execute(sourceID: sourceID)
            try await refreshPlan()
        } catch {
            notice = OperationNotice(
                tone: Self.tone(for: error),
                message: Self.userMessage(for: error)
            )
            await load()
        }
    }

    func requestDelete(_ source: WallpaperSource) async {
        isPreparingDeletion = true
        defer { isPreparingDeletion = false }

        do {
            pendingDeletion = try await DeleteSourceUseCase(
                repository: repository,
                clock: clock
            ).preview(sourceID: source.id)
        } catch {
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
        }
    }

    func confirmDelete() async {
        guard let sourceID = pendingDeletion?.sourceID else {
            return
        }
        await confirmDelete(sourceID: sourceID)
    }

    func confirmDelete(sourceID: SourceID) async {

        do {
            _ = try await DeleteSourceUseCase(
                repository: repository,
                clock: clock
            ).execute(sourceID: sourceID)
            pendingDeletion = nil
            await load()
        } catch {
            pendingDeletion = nil
            notice = OperationNotice(
                tone: .failure,
                message: Self.userMessage(for: error)
            )
            await load()
        }
    }

    func focusSource(id: SourceID) {
        focusedSourceID = id
        resetFocusTask?.cancel()
        resetFocusTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else {
                return
            }
            self?.focusedSourceID = nil
        }
    }

    private func replace(_ source: WallpaperSource) {
        guard let index = sources.firstIndex(where: { $0.id == source.id }) else {
            return
        }
        sources[index] = source
    }

    private func refreshPlan() async throws {
        plan = try await makePreparePlanUseCase().execute()
    }

    private func makePreparePlanUseCase() -> PrepareWeeklyPlanUseCase {
        PrepareWeeklyPlanUseCase(
            sources: repository,
            schedules: repository,
            clock: clock,
            calendarProvider: calendar,
            uuidGenerator: uuidGenerator
        )
    }

    private static func userMessage(for error: Error) -> UserMessage {
        if let failure = error as? AppFailure {
            return UserMessageCatalog.message(for: failure)
        }
        if case WeeklyPlanError.scheduleSaveFailed = error {
            return UserMessageCatalog.message(for: AppFailure(code: .persistenceFailed))
        }
        if case DefaultSourceError.scheduleSaveFailed = error {
            return UserMessageCatalog.message(for: AppFailure(code: .persistenceFailed))
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

    private static func tone(for error: Error) -> OperationNoticeTone {
        if case WeeklyPlanError.sourceUnavailable = error {
            return .warning
        }
        if case DefaultSourceError.sourceUnavailable = error {
            return .warning
        }
        return .failure
    }
}
