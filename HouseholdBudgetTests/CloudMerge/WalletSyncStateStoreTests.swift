import XCTest
@testable import WalletBoard

final class WalletSyncStateStoreTests: XCTestCase {

    func testRecordLevelSyncZoneNameUsesCleanV2Zone() {
        XCTAssertEqual(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName, "WalletSyncZoneV2")
    }

    func testInitialStateHasNoToken() {
        let keyValueStore = FakeKeyValueStore()
        let store = WalletSyncStateStore(keyValueStore: keyValueStore)

        XCTAssertNil(store.loadWalletSyncZoneChangeTokenData())
        XCTAssertFalse(store.hasWalletSyncZoneChangeToken())
    }

    func testSaveTokenPersistsDataThroughStore() {
        let keyValueStore = FakeKeyValueStore()
        let store = WalletSyncStateStore(keyValueStore: keyValueStore)
        let tokenData = Data([1, 2, 3])

        store.saveWalletSyncZoneChangeTokenData(tokenData)

        XCTAssertEqual(
            keyValueStore.storage[WalletSyncStateStore.walletSyncZoneChangeTokenKey] as? Data,
            tokenData
        )
    }

    func testLoadTokenReturnsSavedData() {
        let keyValueStore = FakeKeyValueStore()
        let store = WalletSyncStateStore(keyValueStore: keyValueStore)
        let tokenData = Data([4, 5, 6])

        store.saveWalletSyncZoneChangeTokenData(tokenData)

        XCTAssertEqual(store.loadWalletSyncZoneChangeTokenData(), tokenData)
    }

    func testClearTokenRemovesData() {
        let keyValueStore = FakeKeyValueStore()
        let store = WalletSyncStateStore(keyValueStore: keyValueStore)

        store.saveWalletSyncZoneChangeTokenData(Data([7, 8, 9]))
        store.clearWalletSyncZoneChangeTokenData()

        XCTAssertNil(store.loadWalletSyncZoneChangeTokenData())
    }

    func testHasTokenReflectsState() {
        let keyValueStore = FakeKeyValueStore()
        let store = WalletSyncStateStore(keyValueStore: keyValueStore)

        XCTAssertFalse(store.hasWalletSyncZoneChangeToken())

        store.saveWalletSyncZoneChangeTokenData(Data([1]))

        XCTAssertTrue(store.hasWalletSyncZoneChangeToken())

        store.clearWalletSyncZoneChangeTokenData()

        XCTAssertFalse(store.hasWalletSyncZoneChangeToken())
    }

    func testStoreUsesOnlyExpectedNamespacedKey() {
        let keyValueStore = FakeKeyValueStore()
        let store = WalletSyncStateStore(keyValueStore: keyValueStore)

        store.saveWalletSyncZoneChangeTokenData(Data([1]))
        _ = store.loadWalletSyncZoneChangeTokenData()
        store.clearWalletSyncZoneChangeTokenData()

        XCTAssertEqual(
            Set(keyValueStore.touchedKeys),
            [WalletSyncStateStore.walletSyncZoneChangeTokenKey]
        )
    }

    func testTokenKeyUsesCurrentZoneNameAndDoesNotReuseLegacyZoneKey() {
        XCTAssertTrue(WalletSyncStateStore.walletSyncZoneChangeTokenKey.contains(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName))
        XCTAssertNotEqual(WalletSyncStateStore.walletSyncZoneChangeTokenKey, "WalletSyncState.WalletSyncZone.changeTokenData")
    }

    func testLocallyDeletedFinancialEventIDsPersistThroughStore() {
        let keyValueStore = FakeKeyValueStore()
        let store = WalletSyncStateStore(keyValueStore: keyValueStore)
        let deletedID = UUID()
        let deletedAt = Date(timeIntervalSince1970: 1_800_001_000)

        XCTAssertFalse(store.isFinancialEventDeletedLocally(id: deletedID))

        store.markFinancialEventDeletedLocally(id: deletedID, deletedAt: deletedAt)

        XCTAssertTrue(store.isFinancialEventDeletedLocally(id: deletedID))
        XCTAssertEqual(store.locallyDeletedFinancialEventDeletedAt(id: deletedID), deletedAt)
    }

    func testLocallyDeletedFinancialEventsProduceSyncableDeletionDTOs() {
        let keyValueStore = FakeKeyValueStore()
        let store = WalletSyncStateStore(keyValueStore: keyValueStore)
        let deletedID = UUID()
        let deletedAt = Date(timeIntervalSince1970: 1_800_001_000)

        store.markFinancialEventDeletedLocally(id: deletedID, deletedAt: deletedAt)

        let dto = store.syncableFinancialEventDeletionDTOs().first
        XCTAssertEqual(dto?.entity, .financialEventDeletion)
        XCTAssertEqual(dto?.id, deletedID)
        XCTAssertEqual(dto?.updatedAt, deletedAt)
        XCTAssertEqual(dto?.deletedAt, deletedAt)
        XCTAssertEqual(dto?.isDeleted, true)
    }

    func testLocallyDeletedFinancialEventIDsAreZoneNamespaced() {
        XCTAssertTrue(WalletSyncStateStore.locallyDeletedFinancialEventIDsKey.contains(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName))
        XCTAssertNotEqual(
            WalletSyncStateStore.locallyDeletedFinancialEventIDsKey,
            "WalletSyncState.WalletSyncZone.locallyDeletedFinancialEventIDs"
        )
    }

    func testLocallyDeletedInstallmentPlansProduceSyncableDeletionDTOs() {
        let keyValueStore = FakeKeyValueStore()
        let store = WalletSyncStateStore(keyValueStore: keyValueStore)
        let deletedID = UUID()
        let deletedAt = Date(timeIntervalSince1970: 1_800_001_500)

        store.markInstallmentPlanDeletedLocally(id: deletedID, deletedAt: deletedAt)

        let dto = store.syncableInstallmentPlanDeletionDTOs().first
        XCTAssertTrue(store.isInstallmentPlanDeletedLocally(id: deletedID))
        XCTAssertEqual(store.locallyDeletedInstallmentPlanDeletedAt(id: deletedID), deletedAt)
        XCTAssertEqual(dto?.entity, .installmentPlanDeletion)
        XCTAssertEqual(dto?.id, deletedID)
        XCTAssertEqual(dto?.updatedAt, deletedAt)
        XCTAssertEqual(dto?.deletedAt, deletedAt)
        XCTAssertEqual(dto?.isDeleted, true)
    }

    func testLocallyDeletedInstallmentPlanIDsAreZoneNamespaced() {
        XCTAssertTrue(WalletSyncStateStore.locallyDeletedInstallmentPlanIDsKey.contains(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName))
        XCTAssertNotEqual(
            WalletSyncStateStore.locallyDeletedInstallmentPlanIDsKey,
            "WalletSyncState.WalletSyncZone.locallyDeletedInstallmentPlanIDs"
        )
    }

    func testLocallyDeletedHighRiskRecordsProduceSyncableDeletionDTOs() {
        let keyValueStore = FakeKeyValueStore()
        let store = WalletSyncStateStore(keyValueStore: keyValueStore)
        let purchaseID = UUID()
        let paymentID = UUID()
        let debtID = UUID()
        let entryID = UUID()
        let budgetItemID = UUID()
        let deletedAt = Date(timeIntervalSince1970: 1_800_002_000)

        store.markHighRiskRecordDeletedLocally(entity: .creditCardPurchase, id: purchaseID, deletedAt: deletedAt)
        store.markHighRiskRecordDeletedLocally(entity: .creditCardPayment, id: paymentID, deletedAt: deletedAt)
        store.markHighRiskRecordDeletedLocally(entity: .personDebt, id: debtID, deletedAt: deletedAt)
        store.markHighRiskRecordDeletedLocally(entity: .personDebtEntry, id: entryID, deletedAt: deletedAt)
        store.markHighRiskRecordDeletedLocally(entity: .monthlyBudgetItem, id: budgetItemID, deletedAt: deletedAt)

        let dtos = store.syncableHighRiskRecordDeletionDTOs()
        XCTAssertTrue(store.isHighRiskRecordDeletedLocally(entity: .creditCardPayment, id: paymentID))
        XCTAssertEqual(store.locallyDeletedHighRiskRecordDeletedAt(entity: .creditCardPayment, id: paymentID), deletedAt)
        XCTAssertEqual(Set(dtos.map(\.entity)), [
            .creditCardPurchaseDeletion,
            .creditCardPaymentDeletion,
            .personDebtDeletion,
            .personDebtEntryDeletion,
            .monthlyBudgetItemDeletion
        ])
        XCTAssertTrue(dtos.allSatisfy { $0.updatedAt == deletedAt && $0.deletedAt == deletedAt && $0.isDeleted })
        XCTAssertTrue(dtos.contains { $0.entity == .creditCardPurchaseDeletion && $0.id == purchaseID })
        XCTAssertTrue(dtos.contains { $0.entity == .creditCardPaymentDeletion && $0.id == paymentID })
        XCTAssertTrue(dtos.contains { $0.entity == .personDebtDeletion && $0.id == debtID })
        XCTAssertTrue(dtos.contains { $0.entity == .personDebtEntryDeletion && $0.id == entryID })
        XCTAssertTrue(dtos.contains { $0.entity == .monthlyBudgetItemDeletion && $0.id == budgetItemID })
    }

    func testLocallyDeletedHighRiskRecordIDsAreZoneNamespaced() {
        XCTAssertTrue(WalletSyncStateStore.locallyDeletedHighRiskRecordIDsKey.contains(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName))
        XCTAssertNotEqual(
            WalletSyncStateStore.locallyDeletedHighRiskRecordIDsKey,
            "WalletSyncState.WalletSyncZone.locallyDeletedHighRiskRecordIDs"
        )
    }

    func testLocallyDeletedRecordIDsPersistThroughStore() {
        let keyValueStore = FakeKeyValueStore()
        let store = WalletSyncStateStore(keyValueStore: keyValueStore)
        let deletedID = UUID()

        XCTAssertFalse(store.isRecordDeletedLocally(entity: .installmentPlan, id: deletedID))

        store.markRecordDeletedLocally(entity: .installmentPlan, id: deletedID)

        XCTAssertTrue(store.isRecordDeletedLocally(entity: .installmentPlan, id: deletedID))
        XCTAssertFalse(store.isRecordDeletedLocally(entity: .creditCardPurchase, id: deletedID))
    }

    func testLocallyDeletedRecordIDsAreZoneNamespaced() {
        XCTAssertTrue(WalletSyncStateStore.locallyDeletedRecordIDsKey.contains(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName))
        XCTAssertNotEqual(
            WalletSyncStateStore.locallyDeletedRecordIDsKey,
            "WalletSyncState.WalletSyncZone.locallyDeletedRecordIDs"
        )
    }

    func testStoreDoesNotReferenceWalletStoreOrICloudSyncService() {
        let store = WalletSyncStateStore(keyValueStore: FakeKeyValueStore())
        let propertyNames = Mirror(reflecting: store).children.compactMap { $0.label?.lowercased() }

        XCTAssertFalse(propertyNames.contains { $0.contains("walletstore") })
        XCTAssertFalse(propertyNames.contains { $0.contains("icloudsyncservice") })
    }

    private final class FakeKeyValueStore: WalletSyncStateKeyValueStoring {
        var storage: [String: Any] = [:]
        var touchedKeys: [String] = []

        func data(forKey defaultName: String) -> Data? {
            touchedKeys.append(defaultName)
            return storage[defaultName] as? Data
        }

        func set(_ value: Any?, forKey defaultName: String) {
            touchedKeys.append(defaultName)
            storage[defaultName] = value
        }

        func removeObject(forKey defaultName: String) {
            touchedKeys.append(defaultName)
            storage.removeValue(forKey: defaultName)
        }
    }
}
