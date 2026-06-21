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

        async let minimumLoadingScreen: Void = sleepIgnoringCancellation(nanoseconds: 3_000_000_000)
        let loadedStore = await WalletStore.loadForStartup()

        store = loadedStore
        startupState = .warmingUp
        warmUpCriticalDisplayData(using: loadedStore)

        await minimumLoadingScreen
        startupState = .ready
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
