import SwiftUI
import Combine

protocol WalletSyncMasterDataAutoSyncGateKeyValueStoring {
    func bool(forKey defaultName: String) -> Bool
    func set(_ value: Bool, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

extension UserDefaults: WalletSyncMasterDataAutoSyncGateKeyValueStoring {}

protocol WalletSyncMasterDataAutoSyncGateReading {
    var isEnabled: Bool { get }
}

// Persisted flag that controls whether the production-safe master-data foreground
// auto sync may run. Defaults to off. Holds no WalletStore, CloudKit boundary,
// or sync logic of any kind.
struct WalletSyncMasterDataAutoSyncGate: WalletSyncMasterDataAutoSyncGateReading {
    static let enabledKey = "WalletSyncState.MasterDataAutoSync.enabled"

    private let keyValueStore: WalletSyncMasterDataAutoSyncGateKeyValueStoring

    init(keyValueStore: WalletSyncMasterDataAutoSyncGateKeyValueStoring = UserDefaults.standard) {
        self.keyValueStore = keyValueStore
    }

    var isEnabled: Bool {
        keyValueStore.bool(forKey: Self.enabledKey)
    }

    func enable() {
        keyValueStore.set(true, forKey: Self.enabledKey)
    }

    // Sets to false explicitly (key remains in store).
    func disable() {
        keyValueStore.set(false, forKey: Self.enabledKey)
    }

    // Removes the key entirely, returning to the default-off state.
    func clear() {
        keyValueStore.removeObject(forKey: Self.enabledKey)
    }
}

protocol WalletSyncMasterDataAutoSyncCoordinatorRunning: AnyObject {
    var lastResult: WalletSyncMasterDataCoordinatorResult? { get }
    func runIfAllowed() async -> WalletSyncMasterDataCoordinatorResult
}

extension WalletSyncMasterDataCoordinator: WalletSyncMasterDataAutoSyncCoordinatorRunning {}

@MainActor
final class WalletSyncMasterDataAutoSyncLifecycleStatus: ObservableObject {
    static let shared = WalletSyncMasterDataAutoSyncLifecycleStatus()

    @Published private(set) var lastLifecycleTriggerAttempted = false
    @Published private(set) var lastCoordinatorResult: WalletSyncMasterDataCoordinatorResult?

    func recordAttempt(result: WalletSyncMasterDataCoordinatorResult?) {
        lastLifecycleTriggerAttempted = true
        lastCoordinatorResult = result
    }

    func reset() {
        lastLifecycleTriggerAttempted = false
        lastCoordinatorResult = nil
    }
}

@MainActor
final class WalletSyncMasterDataAutoSyncLifecycleTrigger {
    private let gate: WalletSyncMasterDataAutoSyncGateReading
    private let status: WalletSyncMasterDataAutoSyncLifecycleStatus
    private let coordinatorProvider: () -> WalletSyncMasterDataAutoSyncCoordinatorRunning
    private var coordinator: WalletSyncMasterDataAutoSyncCoordinatorRunning?

    init(
        gate: WalletSyncMasterDataAutoSyncGateReading,
        status: WalletSyncMasterDataAutoSyncLifecycleStatus,
        coordinatorProvider: @escaping () -> WalletSyncMasterDataAutoSyncCoordinatorRunning
    ) {
        self.gate = gate
        self.status = status
        self.coordinatorProvider = coordinatorProvider
    }

    func handleScenePhase(_ phase: ScenePhase) async {
        guard phase == .active else { return }

        guard gate.isEnabled else {
            status.recordAttempt(result: .skipped(reason: .disabled))
            return
        }

        let activeCoordinator: WalletSyncMasterDataAutoSyncCoordinatorRunning
        if let coordinator {
            activeCoordinator = coordinator
        } else {
            let newCoordinator = coordinatorProvider()
            coordinator = newCoordinator
            activeCoordinator = newCoordinator
        }

        let result = await activeCoordinator.runIfAllowed()
        status.recordAttempt(result: result)
    }
}
