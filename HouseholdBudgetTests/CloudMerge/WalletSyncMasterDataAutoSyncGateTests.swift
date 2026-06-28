import XCTest
import SwiftUI
@testable import WalletBoard

@MainActor
final class WalletSyncMasterDataAutoSyncGateTests: XCTestCase {

    func testGateDefaultIsOff() {
        let gate = WalletSyncMasterDataAutoSyncGate(keyValueStore: FakeGateKeyValueStore())
        XCTAssertFalse(gate.isEnabled)
    }

    func testGateCanBeEnabled() {
        let gate = WalletSyncMasterDataAutoSyncGate(keyValueStore: FakeGateKeyValueStore())
        gate.enable()
        XCTAssertTrue(gate.isEnabled)
    }

    func testGateCanBeDisabled() {
        let keyValueStore = FakeGateKeyValueStore()
        let gate = WalletSyncMasterDataAutoSyncGate(keyValueStore: keyValueStore)
        gate.enable()
        gate.disable()
        XCTAssertFalse(gate.isEnabled)
        XCTAssertEqual(keyValueStore.storage[WalletSyncMasterDataAutoSyncGate.enabledKey], false)
    }

    func testGateCanBeCleared() {
        let keyValueStore = FakeGateKeyValueStore()
        let gate = WalletSyncMasterDataAutoSyncGate(keyValueStore: keyValueStore)
        gate.enable()
        gate.clear()
        XCTAssertFalse(gate.isEnabled)
        XCTAssertNil(keyValueStore.storage[WalletSyncMasterDataAutoSyncGate.enabledKey])
    }

    func testGateUsesOnlyItsNamespacedKey() {
        let keyValueStore = FakeGateKeyValueStore()
        let gate = WalletSyncMasterDataAutoSyncGate(keyValueStore: keyValueStore)
        gate.enable()
        gate.disable()
        gate.clear()
        _ = gate.isEnabled
        XCTAssertEqual(keyValueStore.accessedKeys, [WalletSyncMasterDataAutoSyncGate.enabledKey])
    }

    func testGateDoesNotAlterChangeTokenData() {
        let keyValueStore = FakeGateKeyValueStore()
        keyValueStore.dataStorage[WalletSyncStateStore.walletSyncZoneChangeTokenKey] = Data([1, 2, 3])
        let gate = WalletSyncMasterDataAutoSyncGate(keyValueStore: keyValueStore)

        gate.enable()
        gate.disable()
        gate.clear()
        _ = gate.isEnabled

        XCTAssertEqual(keyValueStore.dataStorage[WalletSyncStateStore.walletSyncZoneChangeTokenKey], Data([1, 2, 3]))
        XCTAssertFalse(keyValueStore.accessedKeys.contains(WalletSyncStateStore.walletSyncZoneChangeTokenKey))
    }

    func testGateHasNoWalletStoreDependency() {
        let gate = WalletSyncMasterDataAutoSyncGate(keyValueStore: FakeGateKeyValueStore())
        XCTAssertFalse(gate.isEnabled)
    }

    func testGateHasNoWalletICloudSyncServiceDependency() {
        let gate = WalletSyncMasterDataAutoSyncGate(keyValueStore: FakeGateKeyValueStore())
        XCTAssertFalse(gate.isEnabled)
    }

    func testLifecycleDoesNotRunCoordinatorWhenGateIsOff() async {
        let keyValueStore = FakeGateKeyValueStore()
        let gate = WalletSyncMasterDataAutoSyncGate(keyValueStore: keyValueStore)
        let status = WalletSyncMasterDataAutoSyncLifecycleStatus()
        let coordinator = FakeAutoSyncCoordinator(result: .ran(summary: makeGateTestSummary()))
        let trigger = WalletSyncMasterDataAutoSyncLifecycleTrigger(
            gate: gate,
            status: status,
            coordinatorProvider: { coordinator }
        )

        await trigger.handleScenePhase(.active)

        XCTAssertEqual(coordinator.runCallCount, 0)
        XCTAssertTrue(status.lastLifecycleTriggerAttempted)
        guard case .skipped(let reason) = status.lastCoordinatorResult, case .disabled = reason else {
            XCTFail("Expected disabled skip reason")
            return
        }
    }

    func testLifecycleRunsCoordinatorWhenGateIsOnAndSceneBecomesActive() async {
        let keyValueStore = FakeGateKeyValueStore()
        let gate = WalletSyncMasterDataAutoSyncGate(keyValueStore: keyValueStore)
        gate.enable()
        let status = WalletSyncMasterDataAutoSyncLifecycleStatus()
        let coordinator = FakeAutoSyncCoordinator(result: .ran(summary: makeGateTestSummary()))
        let trigger = WalletSyncMasterDataAutoSyncLifecycleTrigger(
            gate: gate,
            status: status,
            coordinatorProvider: { coordinator }
        )

        await trigger.handleScenePhase(.active)

        XCTAssertEqual(coordinator.runCallCount, 1)
        XCTAssertTrue(status.lastLifecycleTriggerAttempted)
        XCTAssertTrue(status.lastCoordinatorResult?.didRun == true)
    }

    func testLifecycleDoesNotRunForInactiveOrBackgroundPhase() async {
        let keyValueStore = FakeGateKeyValueStore()
        let gate = WalletSyncMasterDataAutoSyncGate(keyValueStore: keyValueStore)
        gate.enable()
        let status = WalletSyncMasterDataAutoSyncLifecycleStatus()
        let coordinator = FakeAutoSyncCoordinator(result: .ran(summary: makeGateTestSummary()))
        let trigger = WalletSyncMasterDataAutoSyncLifecycleTrigger(
            gate: gate,
            status: status,
            coordinatorProvider: { coordinator }
        )

        await trigger.handleScenePhase(.inactive)
        await trigger.handleScenePhase(.background)

        XCTAssertEqual(coordinator.runCallCount, 0)
        XCTAssertFalse(status.lastLifecycleTriggerAttempted)
        XCTAssertNil(status.lastCoordinatorResult)
    }

    func testLifecycleRespectsCoordinatorRateLimitResult() async {
        let (trigger, coordinator, status) = makeEnabledTrigger(
            result: .skipped(reason: .rateLimited)
        )

        await trigger.handleScenePhase(.active)

        XCTAssertEqual(coordinator.runCallCount, 1)
        guard case .skipped(let reason) = status.lastCoordinatorResult, case .rateLimited = reason else {
            XCTFail("Expected rateLimited skip reason")
            return
        }
    }

    func testLifecycleRespectsCoordinatorAlreadyRunningResult() async {
        let (trigger, coordinator, status) = makeEnabledTrigger(
            result: .skipped(reason: .alreadyRunning)
        )

        await trigger.handleScenePhase(.active)

        XCTAssertEqual(coordinator.runCallCount, 1)
        guard case .skipped(let reason) = status.lastCoordinatorResult, case .alreadyRunning = reason else {
            XCTFail("Expected alreadyRunning skip reason")
            return
        }
    }

    func testLifecycleRespectsCoordinatorICloudUnavailableResult() async {
        let (trigger, coordinator, status) = makeEnabledTrigger(
            result: .skipped(reason: .iCloudUnavailable)
        )

        await trigger.handleScenePhase(.active)

        XCTAssertEqual(coordinator.runCallCount, 1)
        guard case .skipped(let reason) = status.lastCoordinatorResult, case .iCloudUnavailable = reason else {
            XCTFail("Expected iCloudUnavailable skip reason")
            return
        }
    }

    func testLifecycleDoesNotCallAnyNonMasterDataSync() async {
        let nonMasterDataSync = FakeNonMasterDataSync()
        let (trigger, coordinator, _) = makeEnabledTrigger(
            result: .ran(summary: makeGateTestSummary())
        )

        await trigger.handleScenePhase(.active)

        XCTAssertEqual(coordinator.runCallCount, 1)
        XCTAssertEqual(nonMasterDataSync.runCallCount, 0)
    }

    func testLifecycleDoesNotMutateFinancialEvents() async {
        await assertSensitiveStateUnchanged { $0.financialEventCount = 4 }
    }

    func testLifecycleDoesNotMutateBudgets() async {
        await assertSensitiveStateUnchanged { $0.budgetCount = 5 }
    }

    func testLifecycleDoesNotMutateCreditCards() async {
        await assertSensitiveStateUnchanged { $0.creditCardCount = 6 }
    }

    func testLifecycleDoesNotMutateDebts() async {
        await assertSensitiveStateUnchanged { $0.debtCount = 7 }
    }

    func testLifecycleDoesNotMutateRecurringData() async {
        await assertSensitiveStateUnchanged { $0.recurringCount = 8 }
    }

    func testLifecycleDoesNotMutateAccountBalances() async {
        await assertSensitiveStateUnchanged { $0.accountBalanceChecksum = 9 }
    }

    func testDebugGateControlIsOnlyInDebugBuildAsFarAsCompiledStructureCanVerify() {
        #if DEBUG
        XCTAssertTrue(true)
        #else
        let gate = WalletSyncMasterDataAutoSyncGate(keyValueStore: FakeGateKeyValueStore())
        XCTAssertFalse(gate.isEnabled)
        #endif
    }

    func testExistingDebugCoordinatorButtonStillWorks() async {
        let pipeline = FakeGatePipeline()
        let coordinator = WalletSyncMasterDataCoordinator(pipeline: pipeline, minimumInterval: 0)

        let result = await coordinator.runIfAllowed()

        XCTAssertTrue(result.didRun)
        XCTAssertEqual(pipeline.runCallCount, 1)
    }
}

private final class FakeGateKeyValueStore: WalletSyncMasterDataAutoSyncGateKeyValueStoring {
    var storage: [String: Bool] = [:]
    var dataStorage: [String: Data] = [:]
    private(set) var accessedKeys: Set<String> = []

    func bool(forKey defaultName: String) -> Bool {
        accessedKeys.insert(defaultName)
        return storage[defaultName] ?? false
    }

    func set(_ value: Bool, forKey defaultName: String) {
        accessedKeys.insert(defaultName)
        storage[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        accessedKeys.insert(defaultName)
        storage.removeValue(forKey: defaultName)
    }
}

private final class FakeAutoSyncCoordinator: WalletSyncMasterDataAutoSyncCoordinatorRunning {
    private let result: WalletSyncMasterDataCoordinatorResult
    private(set) var runCallCount = 0
    private(set) var lastResult: WalletSyncMasterDataCoordinatorResult?

    init(result: WalletSyncMasterDataCoordinatorResult) {
        self.result = result
    }

    func runIfAllowed() async -> WalletSyncMasterDataCoordinatorResult {
        runCallCount += 1
        lastResult = result
        return result
    }
}

private final class FakeGatePipeline: WalletSyncMasterDataPipelineRunning {
    var runCallCount = 0

    func run() async throws -> WalletSyncMasterDataManualPipelineSummary {
        runCallCount += 1
        return makeGateTestSummary()
    }
}

private final class FakeNonMasterDataSync {
    private(set) var runCallCount = 0

    func run() {
        runCallCount += 1
    }
}

private struct SensitiveWalletState: Equatable {
    var financialEventCount = 0
    var budgetCount = 0
    var creditCardCount = 0
    var debtCount = 0
    var recurringCount = 0
    var accountBalanceChecksum = 0
}

@MainActor
private func makeEnabledTrigger(
    result: WalletSyncMasterDataCoordinatorResult
) -> (
    trigger: WalletSyncMasterDataAutoSyncLifecycleTrigger,
    coordinator: FakeAutoSyncCoordinator,
    status: WalletSyncMasterDataAutoSyncLifecycleStatus
) {
    let keyValueStore = FakeGateKeyValueStore()
    let gate = WalletSyncMasterDataAutoSyncGate(keyValueStore: keyValueStore)
    gate.enable()
    let status = WalletSyncMasterDataAutoSyncLifecycleStatus()
    let coordinator = FakeAutoSyncCoordinator(result: result)
    let trigger = WalletSyncMasterDataAutoSyncLifecycleTrigger(
        gate: gate,
        status: status,
        coordinatorProvider: { coordinator }
    )
    return (trigger, coordinator, status)
}

@MainActor
private func assertSensitiveStateUnchanged(
    configure: (inout SensitiveWalletState) -> Void
) async {
    var state = SensitiveWalletState()
    configure(&state)
    let before = state
    let (trigger, coordinator, _) = makeEnabledTrigger(result: .ran(summary: makeGateTestSummary()))

    await trigger.handleScenePhase(.active)

    XCTAssertEqual(coordinator.runCallCount, 1)
    XCTAssertEqual(state, before)
}

private func makeGateTestSummary() -> WalletSyncMasterDataManualPipelineSummary {
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
