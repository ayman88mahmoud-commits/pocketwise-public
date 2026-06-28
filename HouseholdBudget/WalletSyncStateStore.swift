import Foundation

protocol WalletSyncStateKeyValueStoring {
    func data(forKey defaultName: String) -> Data?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

extension UserDefaults: WalletSyncStateKeyValueStoring {}

protocol WalletSyncChangeTokenStoring {
    func loadWalletSyncZoneChangeTokenData() -> Data?
    func saveWalletSyncZoneChangeTokenData(_ tokenData: Data)
    func clearWalletSyncZoneChangeTokenData()
    func hasWalletSyncZoneChangeToken() -> Bool
}

struct WalletSyncStateStore {
    static let walletSyncZoneChangeTokenKey = "WalletSyncState.\(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName).changeTokenData"

    private let keyValueStore: WalletSyncStateKeyValueStoring

    init(keyValueStore: WalletSyncStateKeyValueStoring = UserDefaults.standard) {
        self.keyValueStore = keyValueStore
    }

    func loadWalletSyncZoneChangeTokenData() -> Data? {
        keyValueStore.data(forKey: Self.walletSyncZoneChangeTokenKey)
    }

    func saveWalletSyncZoneChangeTokenData(_ tokenData: Data) {
        keyValueStore.set(tokenData, forKey: Self.walletSyncZoneChangeTokenKey)
    }

    func clearWalletSyncZoneChangeTokenData() {
        keyValueStore.removeObject(forKey: Self.walletSyncZoneChangeTokenKey)
    }

    func hasWalletSyncZoneChangeToken() -> Bool {
        loadWalletSyncZoneChangeTokenData() != nil
    }
}

extension WalletSyncStateStore: WalletSyncChangeTokenStoring {}
