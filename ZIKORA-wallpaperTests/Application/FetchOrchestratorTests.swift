import Foundation
import Testing
@testable import ZIKORA_wallpaper

struct FetchOrchestratorTests {
    @Test("Concurrent fetch triggers share one workflow execution")
    func concurrentTriggersShareOneExecution() async throws {
        let workflow = CountingFetchWorkflow()
        let orchestrator = FetchOrchestrator(workflow: workflow)

        async let first = orchestrator.run(
            taskKind: .automaticDaily,
            reason: .applicationStarted
        )
        async let second = orchestrator.run(
            taskKind: .manualUpdate,
            reason: .manual
        )

        let results = try await [first, second]
        #expect(results[0] == results[1])
        #expect(await workflow.executionCount() == 1)
        #expect(await workflow.maximumConcurrentExecutions() == 1)
        #expect(await orchestrator.isRunning() == false)
    }

    @Test("A failed workflow is cleared so a later trigger can retry")
    func failureDoesNotPoisonOrchestrator() async {
        let workflow = CountingFetchWorkflow(failFirst: true)
        let orchestrator = FetchOrchestrator(workflow: workflow)

        await #expect(throws: TestWorkflowError.failed) {
            try await orchestrator.run(taskKind: .automaticDaily, reason: .retryDue)
        }
        let result = try? await orchestrator.run(
            taskKind: .automaticDaily,
            reason: .retryDue
        )

        #expect(result?.taskKind == .automaticDaily)
        #expect(await workflow.executionCount() == 2)
    }
}

private enum TestWorkflowError: Error, Equatable {
    case failed
}

private actor CountingFetchWorkflow: WallpaperFetchWorkflow {
    private var executions = 0
    private var active = 0
    private var maximumActive = 0
    private let failFirst: Bool

    init(failFirst: Bool = false) {
        self.failFirst = failFirst
    }

    func execute(
        taskKind: FetchTaskKind,
        reason: FetchTriggerReason,
        progress: @escaping @Sendable (FetchProgress) -> Void
    ) async throws -> FetchExecutionResult {
        executions += 1
        active += 1
        maximumActive = max(maximumActive, active)
        defer { active -= 1 }

        await Task.yield()
        await Task.yield()
        if failFirst && executions == 1 {
            throw TestWorkflowError.failed
        }
        return FetchExecutionResult(
            taskKind: taskKind,
            wallpaperID: nil,
            usedDefaultSource: false
        )
    }

    func executionCount() -> Int { executions }
    func maximumConcurrentExecutions() -> Int { maximumActive }
}
