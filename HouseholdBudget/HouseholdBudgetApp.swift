import Foundation
import Security
import SwiftUI

@main
struct HouseholdBudgetApp: App {

    @State private var store: WalletStore?
    @State private var startupState: StartupState = .loading
    @State private var hasStartedStartup = false
    @State private var pendingBankSMSImportDrafts = PendingBankSMSImportStore.load()
    @State private var lastBankSMSImportIdentity: String?
    @State private var lastBankSMSImportReceivedAt: Date?

    init() {
        LegacyCredentialCleanup.runIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if let store, startupState == .ready {
                    WalletRootView(pendingBankSMSImportDrafts: $pendingBankSMSImportDrafts)
                        .environmentObject(store)
                        .transition(.opacity)
                } else {
                    Color.clear
                }

                if startupState != .ready {
                    PocketWiseLoadingView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.45), value: startupState)
            .task {
                await startAppIfNeeded()
            }
            .onOpenURL { url in
                handleOpenURL(url)
            }
        }
    }

    @MainActor
    private func handleOpenURL(_ url: URL) {
        guard let draft = BankSMSImportParser.draft(from: url) else {
            return
        }

        let now = Date()
        if draft.importIdentity == lastBankSMSImportIdentity,
           let lastBankSMSImportReceivedAt,
           now.timeIntervalSince(lastBankSMSImportReceivedAt) < 2 {
            return
        }

        lastBankSMSImportIdentity = draft.importIdentity
        lastBankSMSImportReceivedAt = now
        pendingBankSMSImportDrafts = PendingBankSMSImportStore.append(draft)
    }

    @MainActor
    private func startAppIfNeeded() async {
        guard !hasStartedStartup else {
            return
        }

        hasStartedStartup = true

        let shouldSkipLoadingDelay = shouldSkipLoadingDelayForCurrentLaunch()
        let minimumLoadingScreen = Task {
            if !shouldSkipLoadingDelay {
                await sleepIgnoringCancellation(nanoseconds: 3_000_000_000)
            }
        }
        let loadedStore = await loadStoreForCurrentLaunch()

        store = loadedStore
        startupState = .warmingUp
        warmUpCriticalDisplayData(using: loadedStore)

        await minimumLoadingScreen.value
        startupState = .ready
    }

    @MainActor
    private func loadStoreForCurrentLaunch() async -> WalletStore {
        #if DEBUG
        if let store = UITestDemoLaunch.loadStoreIfRequested() {
            return store
        }
        #endif

        return await WalletStore.loadForStartup()
    }

    private func shouldSkipLoadingDelayForCurrentLaunch() -> Bool {
        #if DEBUG
        UITestDemoLaunch.shouldSkipLoadingDelay
        #else
        false
        #endif
    }

    private func warmUpCriticalDisplayData(using store: WalletStore) {
        AccountVisualIdentity.warmUp(accounts: store.accounts)
        _ = store.availableCash
        _ = store.favoriteEvents.prefix(4)
        _ = store.recentPaidEvents.prefix(4)
        _ = store.upcomingEvents.prefix(4)
    }

    private func sleepIgnoringCancellation(nanoseconds: UInt64) async {
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}


private enum StartupState {
    case loading
    case warmingUp
    case ready
}

#if DEBUG
private enum UITestDemoLaunch {
    private static let demoDataArgument = "--uitest-demo-data"
    private static let skipLoadingDelayArgument = "--uitest-skip-loading-delay"
    private static let suiteEnvironmentKey = "POCKETWISE_UITEST_SUITE"
    private static let demoJSONEnvironmentKey = "POCKETWISE_UITEST_DEMO_JSON"

    static var shouldSkipLoadingDelay: Bool {
        ProcessInfo.processInfo.arguments.contains(skipLoadingDelayArgument)
    }

    @MainActor
    static func loadStoreIfRequested() -> WalletStore? {
        let processInfo = ProcessInfo.processInfo
        guard processInfo.arguments.contains(demoDataArgument) else {
            return nil
        }

        let suiteName = processInfo.environment[suiteEnvironmentKey] ?? "PocketWiseUITest-\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            assertionFailure("Could not create UI test UserDefaults suite.")
            return WalletStore()
        }

        userDefaults.removePersistentDomain(forName: suiteName)

        let store = WalletStore(userDefaults: userDefaults)
        guard let json = processInfo.environment[demoJSONEnvironmentKey],
              let data = json.data(using: .utf8) else {
            assertionFailure("UI test demo data launch requested without fixture JSON.")
            return store
        }

        do {
            try store.importBackupSnapshotFromJSON(data)
        } catch {
            assertionFailure("Failed to import UI test demo data: \(error.localizedDescription)")
        }

        return store
    }
}
#endif

private enum LegacyCredentialCleanup {

    private static let cleanupFlag = "legacyCredentialCleanupComplete"

    static func runIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: cleanupFlag) else {
            return
        }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: ["HouseholdBudget", "Open", "AI"].joined(separator: "."),
            kSecAttrAccount as String: ["OPEN", "AI"].joined() + "_" + ["API", "KEY"].joined(separator: "_")
        ]

        SecItemDelete(query as CFDictionary)
        query.removeAll()
        UserDefaults.standard.set(true, forKey: cleanupFlag)
    }
}
