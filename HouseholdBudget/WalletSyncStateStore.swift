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

protocol WalletSyncLocalFinancialEventDeletionReading {
    func isFinancialEventDeletedLocally(id: UUID) -> Bool
}

protocol WalletSyncLocalFinancialEventDeletionStoring: WalletSyncLocalFinancialEventDeletionReading {
    func markFinancialEventDeletedLocally(id: UUID)
}

struct WalletSyncStateStore {
    static let walletSyncZoneChangeTokenKey = "WalletSyncState.\(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName).changeTokenData"
    static let locallyDeletedFinancialEventIDsKey = "WalletSyncState.\(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName).locallyDeletedFinancialEventIDs"

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

    func markFinancialEventDeletedLocally(id: UUID) {
        var ids = locallyDeletedFinancialEventIDs()
        ids.insert(id)
        saveLocallyDeletedFinancialEventIDs(ids)
    }

    func isFinancialEventDeletedLocally(id: UUID) -> Bool {
        locallyDeletedFinancialEventIDs().contains(id)
    }

    func clearLocallyDeletedFinancialEventIDs() {
        keyValueStore.removeObject(forKey: Self.locallyDeletedFinancialEventIDsKey)
    }

    private func locallyDeletedFinancialEventIDs() -> Set<UUID> {
        guard let data = keyValueStore.data(forKey: Self.locallyDeletedFinancialEventIDsKey),
              let rawIDs = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }

        return Set(rawIDs.compactMap(UUID.init(uuidString:)))
    }

    private func saveLocallyDeletedFinancialEventIDs(_ ids: Set<UUID>) {
        let rawIDs = ids.map(\.uuidString).sorted()
        guard let data = try? JSONEncoder().encode(rawIDs) else { return }
        keyValueStore.set(data, forKey: Self.locallyDeletedFinancialEventIDsKey)
    }
}

extension WalletSyncStateStore: WalletSyncChangeTokenStoring {}
extension WalletSyncStateStore: WalletSyncLocalFinancialEventDeletionStoring {}
