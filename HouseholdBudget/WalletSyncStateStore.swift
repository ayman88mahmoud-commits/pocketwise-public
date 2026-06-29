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
    func locallyDeletedFinancialEventDeletedAt(id: UUID) -> Date?
}

protocol WalletSyncLocalFinancialEventDeletionStoring: WalletSyncLocalFinancialEventDeletionReading {
    func markFinancialEventDeletedLocally(id: UUID, deletedAt: Date)
    func syncableFinancialEventDeletionDTOs() -> [WalletSyncRecordDTO]
}

protocol WalletSyncLocalInstallmentPlanDeletionReading {
    func isInstallmentPlanDeletedLocally(id: UUID) -> Bool
    func locallyDeletedInstallmentPlanDeletedAt(id: UUID) -> Date?
}

protocol WalletSyncLocalInstallmentPlanDeletionStoring: WalletSyncLocalInstallmentPlanDeletionReading {
    func markInstallmentPlanDeletedLocally(id: UUID, deletedAt: Date)
    func syncableInstallmentPlanDeletionDTOs() -> [WalletSyncRecordDTO]
}

protocol WalletSyncLocalRecordTombstoneReading {
    func isRecordDeletedLocally(entity: WalletSyncRecordEntity, id: UUID) -> Bool
}

protocol WalletSyncLocalRecordTombstoneStoring: WalletSyncLocalRecordTombstoneReading {
    func markRecordDeletedLocally(entity: WalletSyncRecordEntity, id: UUID)
}

struct WalletSyncStateStore {
    static let walletSyncZoneChangeTokenKey = "WalletSyncState.\(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName).changeTokenData"
    static let locallyDeletedFinancialEventIDsKey = "WalletSyncState.\(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName).locallyDeletedFinancialEventIDs"
    static let locallyDeletedInstallmentPlanIDsKey = "WalletSyncState.\(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName).locallyDeletedInstallmentPlanIDs"
    static let locallyDeletedRecordIDsKey = "WalletSyncState.\(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName).locallyDeletedRecordIDs"

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

    func markFinancialEventDeletedLocally(id: UUID, deletedAt: Date = Date()) {
        var deletions = locallyDeletedFinancialEventDeletions()
        let existingDeletedAt = deletions[id] ?? .distantPast
        deletions[id] = max(existingDeletedAt, deletedAt)
        saveLocallyDeletedFinancialEventDeletions(deletions)
        markRecordDeletedLocally(entity: .financialEvent, id: id)
    }

    func isFinancialEventDeletedLocally(id: UUID) -> Bool {
        locallyDeletedFinancialEventDeletions()[id] != nil
    }

    func locallyDeletedFinancialEventDeletedAt(id: UUID) -> Date? {
        locallyDeletedFinancialEventDeletions()[id]
    }

    func syncableFinancialEventDeletionDTOs() -> [WalletSyncRecordDTO] {
        locallyDeletedFinancialEventDeletions()
            .map { id, deletedAt in
                WalletSyncRecordMappers.dtoForFinancialEventDeletion(id: id, deletedAt: deletedAt)
            }
            .sorted { $0.recordName < $1.recordName }
    }

    func clearLocallyDeletedFinancialEventIDs() {
        keyValueStore.removeObject(forKey: Self.locallyDeletedFinancialEventIDsKey)
    }

    func markInstallmentPlanDeletedLocally(id: UUID, deletedAt: Date = Date()) {
        var deletions = locallyDeletedInstallmentPlanDeletions()
        let existingDeletedAt = deletions[id] ?? .distantPast
        deletions[id] = max(existingDeletedAt, deletedAt)
        saveLocallyDeletedInstallmentPlanDeletions(deletions)
        markRecordDeletedLocally(entity: .installmentPlan, id: id)
    }

    func isInstallmentPlanDeletedLocally(id: UUID) -> Bool {
        locallyDeletedInstallmentPlanDeletions()[id] != nil
    }

    func locallyDeletedInstallmentPlanDeletedAt(id: UUID) -> Date? {
        locallyDeletedInstallmentPlanDeletions()[id]
    }

    func syncableInstallmentPlanDeletionDTOs() -> [WalletSyncRecordDTO] {
        locallyDeletedInstallmentPlanDeletions()
            .map { id, deletedAt in
                WalletSyncRecordMappers.dtoForInstallmentPlanDeletion(id: id, deletedAt: deletedAt)
            }
            .sorted { $0.recordName < $1.recordName }
    }

    func clearLocallyDeletedInstallmentPlanIDs() {
        keyValueStore.removeObject(forKey: Self.locallyDeletedInstallmentPlanIDsKey)
    }

    func markRecordDeletedLocally(entity: WalletSyncRecordEntity, id: UUID) {
        var recordNames = locallyDeletedRecordNames()
        recordNames.insert(entity.recordName(for: id))
        saveLocallyDeletedRecordNames(recordNames)
    }

    func isRecordDeletedLocally(entity: WalletSyncRecordEntity, id: UUID) -> Bool {
        locallyDeletedRecordNames().contains(entity.recordName(for: id))
    }

    func clearLocallyDeletedRecordIDs() {
        keyValueStore.removeObject(forKey: Self.locallyDeletedRecordIDsKey)
    }

    private func locallyDeletedFinancialEventDeletions() -> [UUID: Date] {
        guard let data = keyValueStore.data(forKey: Self.locallyDeletedFinancialEventIDsKey) else {
            return [:]
        }

        if let encodedDeletions = try? JSONDecoder().decode([String: Date].self, from: data) {
            return Dictionary(uniqueKeysWithValues: encodedDeletions.compactMap { rawID, deletedAt in
                guard let id = UUID(uuidString: rawID) else { return nil }
                return (id, deletedAt)
            })
        }

        if let legacyIDs = try? JSONDecoder().decode([String].self, from: data) {
            return Dictionary(uniqueKeysWithValues: legacyIDs.compactMap { rawID in
                guard let id = UUID(uuidString: rawID) else { return nil }
                return (id, Date.distantFuture)
            })
        }

        return [:]
    }

    private func saveLocallyDeletedFinancialEventDeletions(_ deletions: [UUID: Date]) {
        let encodedDeletions = Dictionary(uniqueKeysWithValues: deletions.map { id, deletedAt in
            (id.uuidString, deletedAt)
        })
        guard let data = try? JSONEncoder().encode(encodedDeletions) else { return }
        keyValueStore.set(data, forKey: Self.locallyDeletedFinancialEventIDsKey)
    }

    private func locallyDeletedInstallmentPlanDeletions() -> [UUID: Date] {
        guard let data = keyValueStore.data(forKey: Self.locallyDeletedInstallmentPlanIDsKey),
              let encodedDeletions = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: encodedDeletions.compactMap { rawID, deletedAt in
            guard let id = UUID(uuidString: rawID) else { return nil }
            return (id, deletedAt)
        })
    }

    private func saveLocallyDeletedInstallmentPlanDeletions(_ deletions: [UUID: Date]) {
        let encodedDeletions = Dictionary(uniqueKeysWithValues: deletions.map { id, deletedAt in
            (id.uuidString, deletedAt)
        })
        guard let data = try? JSONEncoder().encode(encodedDeletions) else { return }
        keyValueStore.set(data, forKey: Self.locallyDeletedInstallmentPlanIDsKey)
    }

    private func locallyDeletedRecordNames() -> Set<String> {
        guard let data = keyValueStore.data(forKey: Self.locallyDeletedRecordIDsKey),
              let recordNames = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }

        return Set(recordNames)
    }

    private func saveLocallyDeletedRecordNames(_ recordNames: Set<String>) {
        guard let data = try? JSONEncoder().encode(recordNames.sorted()) else { return }
        keyValueStore.set(data, forKey: Self.locallyDeletedRecordIDsKey)
    }
}

extension WalletSyncStateStore: WalletSyncChangeTokenStoring {}
extension WalletSyncStateStore: WalletSyncLocalFinancialEventDeletionStoring {}
extension WalletSyncStateStore: WalletSyncLocalInstallmentPlanDeletionStoring {}
extension WalletSyncStateStore: WalletSyncLocalRecordTombstoneStoring {}
