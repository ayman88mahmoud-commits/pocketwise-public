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
