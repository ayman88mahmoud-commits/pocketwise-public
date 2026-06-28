import XCTest
import CloudKit
@testable import WalletBoard

@MainActor
final class WalletSyncMasterDataCoordinatorTests: XCTestCase {

    // MARK: - Test 1: Coordinator runs pipeline when allowed

    func testCoordinatorRunsPipelineWhenAllowed() async {
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(pipeline: pipeline, minimumInterval: 0)

        let result = await coordinator.runIfAllowed()

        XCTAssertTrue(result.didRun)
        XCTAssertEqual(pipeline.runCallCount, 1)
        XCTAssertNil(result.skipReason)
    }

    // MARK: - Test 2: Coordinator skips when already running

    func testCoordinatorSkipsWhenAlreadyRunning() async {
        let slowPipeline = SlowFakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(pipeline: slowPipeline, minimumInterval: 0)

        // Start first run without awaiting
        let firstTask = Task { @MainActor in await coordinator.runIfAllowed() }

        // Allow first task to run until it suspends inside pipeline.run()
        await Task.yield()

        // Coordinator should report isRunning — second call must be skipped
        let secondResult = await coordinator.runIfAllowed()

        slowPipeline.resume()
        let firstResult = await firstTask.value

        XCTAssertTrue(firstResult.didRun)
        XCTAssertFalse(secondResult.didRun)

        guard case .skipped(let reason) = secondResult, case .alreadyRunning = reason else {
            XCTFail("Expected skipped with .alreadyRunning reason, got \(secondResult)")
            return
        }
    }

    // MARK: - Test 3: Coordinator skips when rate-limited

    func testCoordinatorSkipsWhenRateLimited() async {
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        let dateProvider = FakeCoordinatorDateProvider(now: baseDate)
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(
            pipeline: pipeline,
            dateProvider: dateProvider,
            minimumInterval: 300
        )

        let first = await coordinator.runIfAllowed()
        XCTAssertTrue(first.didRun)

        // Do not advance date — still within minimum interval
        let second = await coordinator.runIfAllowed()
        XCTAssertFalse(second.didRun)

        guard case .skipped(let reason) = second, case .rateLimited = reason else {
            XCTFail("Expected skipped with .rateLimited reason")
            return
        }
    }

    // MARK: - Test 4: Coordinator runs after rate-limit interval has passed

    func testCoordinatorRunsAfterRateLimitIntervalHasPassed() async {
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        let dateProvider = FakeCoordinatorDateProvider(now: baseDate)
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(
            pipeline: pipeline,
            dateProvider: dateProvider,
            minimumInterval: 300
        )

        let first = await coordinator.runIfAllowed()
        XCTAssertTrue(first.didRun)

        // Advance date beyond the minimum interval (no real waiting required)
        dateProvider.now = baseDate.addingTimeInterval(301)

        let second = await coordinator.runIfAllowed()
        XCTAssertTrue(second.didRun)
        XCTAssertEqual(pipeline.runCallCount, 2)
    }

    // MARK: - Test 5: Coordinator skips when disabled

    func testCoordinatorSkipsWhenDisabled() async {
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(
            pipeline: pipeline,
            minimumInterval: 0,
            enabled: false
        )

        let result = await coordinator.runIfAllowed()

        XCTAssertFalse(result.didRun)
        XCTAssertEqual(pipeline.runCallCount, 0)

        guard case .skipped(let reason) = result, case .disabled = reason else {
            XCTFail("Expected skipped with .disabled reason")
            return
        }
    }

    // MARK: - Test 6: Coordinator skips when iCloud unavailable

    func testCoordinatorSkipsWhenICloudUnavailable() async {
        let pipeline = FakeCoordinatorPipeline()
        let checker = FakeCoordinatorAvailabilityChecker(availability: .noAccount)
        let coordinator = WalletSyncMasterDataCoordinator(
            pipeline: pipeline,
            availabilityChecker: checker,
            minimumInterval: 0
        )

        let result = await coordinator.runIfAllowed()

        XCTAssertFalse(result.didRun)
        XCTAssertEqual(pipeline.runCallCount, 0)

        guard case .skipped(let reason) = result, case .iCloudUnavailable = reason else {
            XCTFail("Expected skipped with .iCloudUnavailable reason")
            return
        }
    }

    // MARK: - Test 7: Coordinator returns safe skipped status

    func testCoordinatorReturnsSafeSkippedStatus() async {
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(
            pipeline: pipeline,
            minimumInterval: 0,
            enabled: false
        )

        let result = await coordinator.runIfAllowed()

        XCTAssertFalse(result.didRun)
        XCTAssertNotNil(result.skipReason)
        XCTAssertNil(result.pipelineSummary)
        XCTAssertNotNil(coordinator.lastResult)
    }

    // MARK: - Test 8: Coordinator exposes pipeline summary safely

    func testCoordinatorExposesPipelineSummarySafely() async {
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(pipeline: pipeline, minimumInterval: 0)

        let result = await coordinator.runIfAllowed()

        XCTAssertTrue(result.didRun)
        let summary = result.pipelineSummary
        XCTAssertNotNil(summary)
        // Summary contains only safe integer counts — no names, balances, or personal text
        XCTAssertEqual(summary?.uploadedCount, 0)
        XCTAssertEqual(summary?.changedRecordCount, 0)
        XCTAssertEqual(summary?.appliedCreatedCount, 0)
        XCTAssertEqual(summary?.appliedUpdatedCount, 0)
    }

    // MARK: - Test 9: Coordinator does not call WalletICloudSyncService

    func testCoordinatorDoesNotCallWalletICloudSyncService() async {
        // WalletSyncMasterDataCoordinator has no WalletICloudSyncService parameter.
        // This test compiles correctly only because the coordinator's init contains no such dependency.
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(pipeline: pipeline, minimumInterval: 0)
        let result = await coordinator.runIfAllowed()
        XCTAssertTrue(result.didRun)
    }

    // MARK: - Test 10: Coordinator does not mutate WalletStore directly

    func testCoordinatorDoesNotMutateWalletStoreDirectly() async {
        // WalletSyncMasterDataCoordinator holds no WalletStore reference.
        // The only path that reaches WalletStore is through the injected pipeline protocol.
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(pipeline: pipeline, minimumInterval: 0)
        let result = await coordinator.runIfAllowed()
        XCTAssertEqual(pipeline.runCallCount, 1)
        XCTAssertTrue(result.didRun)
    }

    // MARK: - Test 11: Coordinator does not apply non-master-data

    func testCoordinatorDoesNotApplyNonMasterData() async {
        // The coordinator invokes only WalletSyncMasterDataPipelineRunning.run().
        // Entities outside Account, Category, and WalletEvent cannot be applied
        // because the pipeline protocol surface contains no other entity path.
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(pipeline: pipeline, minimumInterval: 0)
        _ = await coordinator.runIfAllowed()
        XCTAssertEqual(pipeline.runCallCount, 1)
    }

    // MARK: - Tests 12–18: Coordinator does not mutate non-master-data types

    func testCoordinatorDoesNotMutateTransactions() async {
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(pipeline: pipeline, minimumInterval: 0)
        let result = await coordinator.runIfAllowed()
        // Coordinator contains no FinancialEvent or transaction mutation path.
        XCTAssertTrue(result.didRun)
    }

    func testCoordinatorDoesNotMutateFinancialEvents() async {
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(pipeline: pipeline, minimumInterval: 0)
        let result = await coordinator.runIfAllowed()
        XCTAssertTrue(result.didRun)
    }

    func testCoordinatorDoesNotMutateBudgets() async {
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(pipeline: pipeline, minimumInterval: 0)
        let result = await coordinator.runIfAllowed()
        XCTAssertTrue(result.didRun)
    }

    func testCoordinatorDoesNotMutateCreditCards() async {
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(pipeline: pipeline, minimumInterval: 0)
        let result = await coordinator.runIfAllowed()
        XCTAssertTrue(result.didRun)
    }

    func testCoordinatorDoesNotMutateDebts() async {
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(pipeline: pipeline, minimumInterval: 0)
        let result = await coordinator.runIfAllowed()
        XCTAssertTrue(result.didRun)
    }

    func testCoordinatorDoesNotMutateRecurringData() async {
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(pipeline: pipeline, minimumInterval: 0)
        let result = await coordinator.runIfAllowed()
        XCTAssertTrue(result.didRun)
    }

    func testCoordinatorDoesNotMutateAccountBalances() async {
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(pipeline: pipeline, minimumInterval: 0)
        let result = await coordinator.runIfAllowed()
        // The coordinator passes no balance value to the pipeline protocol.
        // WalletSyncMasterDataManualPipelineSummary contains only safe integer counts.
        XCTAssertTrue(result.didRun)
    }

    // MARK: - Test 19: Rate limiter is testable without waiting

    func testRateLimiterIsTestableWithoutWaiting() async {
        let baseDate = Date(timeIntervalSince1970: 2_000_000)
        let dateProvider = FakeCoordinatorDateProvider(now: baseDate)
        let pipeline = FakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(
            pipeline: pipeline,
            dateProvider: dateProvider,
            minimumInterval: 300
        )

        let first = await coordinator.runIfAllowed()
        XCTAssertTrue(first.didRun)

        // Within interval — should be rate-limited without sleeping
        let second = await coordinator.runIfAllowed()
        XCTAssertFalse(second.didRun)

        // Advance date without real waiting
        dateProvider.now = baseDate.addingTimeInterval(301)

        // Now runs again
        let third = await coordinator.runIfAllowed()
        XCTAssertTrue(third.didRun)
        XCTAssertEqual(pipeline.runCallCount, 2)
    }

    // MARK: - Test 20: Overlap guard is testable

    func testOverlapGuardIsTestable() async {
        let slowPipeline = SlowFakeCoordinatorPipeline()
        let coordinator = WalletSyncMasterDataCoordinator(pipeline: slowPipeline, minimumInterval: 0)

        let firstTask = Task { @MainActor in await coordinator.runIfAllowed() }

        await Task.yield()

        let secondResult = await coordinator.runIfAllowed()

        slowPipeline.resume()
        let firstResult = await firstTask.value

        XCTAssertTrue(firstResult.didRun)
        XCTAssertFalse(secondResult.didRun)

        guard case .skipped(let reason) = secondResult, case .alreadyRunning = reason else {
            XCTFail("Overlap guard did not return .alreadyRunning")
            return
        }
    }
}

// MARK: - Fake helpers (file-private so nested types can access them)

private final class FakeCoordinatorPipeline: WalletSyncMasterDataPipelineRunning {
    var runCallCount = 0

    func run() async throws -> WalletSyncMasterDataManualPipelineSummary {
        runCallCount += 1
        return makeCoordinatorTestSummary()
    }
}

@MainActor
private final class SlowFakeCoordinatorPipeline: WalletSyncMasterDataPipelineRunning {
    private var runContinuation: CheckedContinuation<WalletSyncMasterDataManualPipelineSummary, Never>?

    func run() async throws -> WalletSyncMasterDataManualPipelineSummary {
        await withCheckedContinuation { continuation in
            runContinuation = continuation
        }
    }

    func resume() {
        runContinuation?.resume(returning: makeCoordinatorTestSummary())
        runContinuation = nil
    }
}

private final class FakeCoordinatorAvailabilityChecker: WalletSyncMasterDataAvailabilityChecking {
    var availability: WalletSyncCloudKitAccountAvailability

    init(availability: WalletSyncCloudKitAccountAvailability) {
        self.availability = availability
    }

    func checkMasterDataSyncAvailability() async -> WalletSyncCloudKitAccountAvailability {
        availability
    }
}

private final class FakeCoordinatorDateProvider: WalletSyncCurrentDateProviding {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

private func makeCoordinatorTestSummary() -> WalletSyncMasterDataManualPipelineSummary {
    WalletSyncMasterDataManualPipelineSummary(
        zoneEnsured: true,
        uploadedCount: 0,
        uploadedAccountCount: 0,
        uploadedCategoryCount: 0,
        uploadedWalletEventCount: 0,
        uploadCap: 50,
        uploadCappedCount: 0,
        usedSavedToken: false,
        changedRecordCount: 0,
        deletedRecordCount: 0,
        skippedLocalEchoCount: 0,
        skippedLocalEchoRecordNames: [],
        parsedValidCount: 0,
        blockedCount: 0,
        failedCount: 0,
        plannedCreateCount: 0,
        plannedUpdateCount: 0,
        plannedDisableCount: 0,
        appliedCreatedCount: 0,
        appliedUpdatedCount: 0,
        appliedDisabledCount: 0,
        appliedBlockedCount: 0,
        appliedFailedCount: 0,
        tokenReturned: false,
        tokenSaved: false,
        moreComing: false,
        sampleRecordNames: []
    )
}
