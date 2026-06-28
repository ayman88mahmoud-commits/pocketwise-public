import XCTest
import CloudKit
@testable import WalletBoard

final class WalletSyncDryRunLoopControllerTests: XCTestCase {

    func testNoSavedTokenFetchesWithNilToken() async throws {
        let fetcher = FakeChangedRecordFetcher()
        let store = FakeChangeTokenStore()
        let controller = WalletSyncDryRunLoopController(changedRecordFetcher: fetcher, tokenStore: store)

        _ = try await controller.runDryRunLoop()

        XCTAssertEqual(fetcher.receivedTokens, [nil])
    }

    func testSavedTokenFetchesWithSavedToken() async throws {
        let tokenData = Data([1, 2, 3])
        let fetcher = FakeChangedRecordFetcher()
        let store = FakeChangeTokenStore(tokenData: tokenData)
        let controller = WalletSyncDryRunLoopController(changedRecordFetcher: fetcher, tokenStore: store)

        _ = try await controller.runDryRunLoop()

        XCTAssertEqual(fetcher.receivedTokens, [tokenData])
    }

    func testReturnedTokenIsSavedWhenPresent() async throws {
        let returnedToken = Data([4, 5, 6])
        let fetcher = FakeChangedRecordFetcher(
            result: WalletSyncCloudKitFetchResult(records: [], changeTokenData: returnedToken)
        )
        let store = FakeChangeTokenStore()
        let controller = WalletSyncDryRunLoopController(changedRecordFetcher: fetcher, tokenStore: store)

        _ = try await controller.runDryRunLoop()

        XCTAssertEqual(store.tokenData, returnedToken)
        XCTAssertEqual(store.saveCallCount, 1)
    }

    func testExistingTokenIsNotOverwrittenWhenReturnedTokenIsNil() async throws {
        let existingToken = Data([7, 8, 9])
        let fetcher = FakeChangedRecordFetcher(
            result: WalletSyncCloudKitFetchResult(records: [], changeTokenData: nil)
        )
        let store = FakeChangeTokenStore(tokenData: existingToken)
        let controller = WalletSyncDryRunLoopController(changedRecordFetcher: fetcher, tokenStore: store)

        _ = try await controller.runDryRunLoop()

        XCTAssertEqual(store.tokenData, existingToken)
        XCTAssertEqual(store.saveCallCount, 0)
    }

    func testSummaryReportsUsedSavedToken() async throws {
        let fetcher = FakeChangedRecordFetcher()
        let store = FakeChangeTokenStore(tokenData: Data([1]))
        let controller = WalletSyncDryRunLoopController(changedRecordFetcher: fetcher, tokenStore: store)

        let summary = try await controller.runDryRunLoop()

        XCTAssertTrue(summary.usedSavedToken)
    }

    func testSummaryReportsChangedAndDeletedCounts() async throws {
        let fetcher = FakeChangedRecordFetcher(
            result: WalletSyncCloudKitFetchResult(
                records: [
                    makeRecord(named: "Account_11111111-1111-1111-1111-111111111111"),
                    makeRecord(named: "Category_22222222-2222-2222-2222-222222222222")
                ],
                deletedRecordNames: ["WalletEvent_33333333-3333-3333-3333-333333333333"]
            )
        )
        let store = FakeChangeTokenStore()
        let controller = WalletSyncDryRunLoopController(changedRecordFetcher: fetcher, tokenStore: store)

        let summary = try await controller.runDryRunLoop()

        XCTAssertEqual(summary.changedRecordCount, 2)
        XCTAssertEqual(summary.deletedRecordCount, 1)
    }

    func testSummaryReportsTokenReturnedAndTokenSaved() async throws {
        let fetcher = FakeChangedRecordFetcher(
            result: WalletSyncCloudKitFetchResult(records: [], changeTokenData: Data([1]))
        )
        let store = FakeChangeTokenStore()
        let controller = WalletSyncDryRunLoopController(changedRecordFetcher: fetcher, tokenStore: store)

        let summary = try await controller.runDryRunLoop()

        XCTAssertTrue(summary.tokenReturned)
        XCTAssertTrue(summary.tokenSaved)
    }

    func testSummaryReportsMoreComing() async throws {
        let fetcher = FakeChangedRecordFetcher(
            result: WalletSyncCloudKitFetchResult(records: [], moreComing: true)
        )
        let store = FakeChangeTokenStore()
        let controller = WalletSyncDryRunLoopController(changedRecordFetcher: fetcher, tokenStore: store)

        let summary = try await controller.runDryRunLoop()

        XCTAssertTrue(summary.moreComing)
    }

    func testSampleRecordNamesAreLimited() async throws {
        let records = (0..<5).map { makeRecord(named: "Account_\($0)") }
        let deletedRecordNames = (0..<5).map { "Category_\($0)" }
        let fetcher = FakeChangedRecordFetcher(
            result: WalletSyncCloudKitFetchResult(
                records: records,
                deletedRecordNames: deletedRecordNames
            )
        )
        let store = FakeChangeTokenStore()
        let controller = WalletSyncDryRunLoopController(
            changedRecordFetcher: fetcher,
            tokenStore: store,
            sampleLimit: 2
        )

        let summary = try await controller.runDryRunLoop()

        XCTAssertEqual(summary.sampleChangedRecordNames, ["Account_0", "Account_1"])
        XCTAssertEqual(summary.sampleDeletedRecordNames, ["Category_0", "Category_1"])
    }

    func testControllerDoesNotRequireWalletStoreOrICloudSyncService() {
        let controller = WalletSyncDryRunLoopController(
            changedRecordFetcher: FakeChangedRecordFetcher(),
            tokenStore: FakeChangeTokenStore()
        )
        let propertyNames = Mirror(reflecting: controller).children.compactMap { $0.label?.lowercased() }

        XCTAssertFalse(propertyNames.contains { $0.contains("walletstore") })
        XCTAssertFalse(propertyNames.contains { $0.contains("icloudsyncservice") })
    }

    func testControllerDoesNotExposeApplyOrDecodeDependencies() {
        let controller = WalletSyncDryRunLoopController(
            changedRecordFetcher: FakeChangedRecordFetcher(),
            tokenStore: FakeChangeTokenStore()
        )
        let propertyNames = Mirror(reflecting: controller).children.compactMap { $0.label?.lowercased() }

        XCTAssertFalse(propertyNames.contains { $0.contains("apply") })
        XCTAssertFalse(propertyNames.contains { $0.contains("decode") })
        XCTAssertFalse(propertyNames.contains { $0.contains("mapper") })
    }

    func testUserDefaultsAccessRemainsIsolatedToStateStore() {
        let controller = WalletSyncDryRunLoopController(
            changedRecordFetcher: FakeChangedRecordFetcher(),
            tokenStore: FakeChangeTokenStore()
        )
        let propertyNames = Mirror(reflecting: controller).children.compactMap { $0.label?.lowercased() }

        XCTAssertFalse(propertyNames.contains { $0.contains("userdefaults") })
    }

    private func makeRecord(named recordName: String) -> CKRecord {
        CKRecord(recordType: WalletSyncCKRecordAdapter.recordType, recordID: CKRecord.ID(recordName: recordName))
    }

    private final class FakeChangedRecordFetcher: WalletSyncDryRunChangedRecordFetching {
        var result: WalletSyncCloudKitFetchResult
        var receivedTokens: [Data?] = []

        init(result: WalletSyncCloudKitFetchResult = WalletSyncCloudKitFetchResult(records: [])) {
            self.result = result
        }

        func fetchChangedRecords(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult {
            receivedTokens.append(changeToken)
            return result
        }
    }

    private final class FakeChangeTokenStore: WalletSyncChangeTokenStoring {
        var tokenData: Data?
        var saveCallCount = 0

        init(tokenData: Data? = nil) {
            self.tokenData = tokenData
        }

        func loadWalletSyncZoneChangeTokenData() -> Data? {
            tokenData
        }

        func saveWalletSyncZoneChangeTokenData(_ tokenData: Data) {
            saveCallCount += 1
            self.tokenData = tokenData
        }

        func clearWalletSyncZoneChangeTokenData() {
            tokenData = nil
        }

        func hasWalletSyncZoneChangeToken() -> Bool {
            tokenData != nil
        }
    }
}
