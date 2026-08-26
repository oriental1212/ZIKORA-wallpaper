import Foundation

/// Serializes every fetch entry point and shares the in-flight result with concurrent callers.
actor FetchOrchestrator: FetchOrchestrating {
    private let workflow: any WallpaperFetchWorkflow
    private var activeTask: Task<FetchExecutionResult, Error>?
    private var activeToken: UUID?

    init(workflow: any WallpaperFetchWorkflow) {
        self.workflow = workflow
    }

    func run(
        taskKind: FetchTaskKind,
        reason: FetchTriggerReason
    ) async throws -> FetchExecutionResult {
        if let activeTask {
            return try await activeTask.value
        }

        let token = UUID()
        let workflow = self.workflow
        let task = Task {
            try await workflow.execute(
                taskKind: taskKind,
                reason: reason,
                progress: { _ in }
            )
        }
        activeTask = task
        activeToken = token

        do {
            let result = try await task.value
            clearActiveTask(if: token)
            return result
        } catch {
            clearActiveTask(if: token)
            throw error
        }
    }

    func isRunning() -> Bool {
        activeTask != nil
    }

    private func clearActiveTask(if token: UUID) {
        guard activeToken == token else { return }
        activeTask = nil
        activeToken = nil
    }
}

extension FetchOrchestrator: WallpaperFetchWorkflow {
    func execute(
        taskKind: FetchTaskKind,
        reason: FetchTriggerReason,
        progress: @escaping @Sendable (FetchProgress) -> Void
    ) async throws -> FetchExecutionResult {
        try await run(taskKind: taskKind, reason: reason)
    }
}

extension FetchOrchestrator: SourceFetchOrchestrating {
    func run(sourceID: SourceID) async throws -> FetchExecutionResult {
        if let activeTask {
            return try await activeTask.value
        }
        guard let workflow = workflow as? any TargetedWallpaperFetchWorkflow else {
            throw AppFailure(code: .unknown)
        }

        let token = UUID()
        let task = Task {
            try await workflow.execute(
                sourceID: sourceID,
                reason: .manual,
                progress: { _ in }
            )
        }
        activeTask = task
        activeToken = token
        do {
            let result = try await task.value
            clearActiveTask(if: token)
            return result
        } catch {
            clearActiveTask(if: token)
            throw error
        }
    }
}
