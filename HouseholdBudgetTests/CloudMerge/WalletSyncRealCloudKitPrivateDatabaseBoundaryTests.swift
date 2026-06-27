import XCTest
import CloudKit
@testable import WalletBoard

final class WalletSyncRealCloudKitPrivateDatabaseBoundaryTests: XCTestCase {

    func testBoundaryInitializesWithoutWalletStoreOrUI() {
        let boundary = makeBoundary()

        XCTAssertNotNil(boundary)
    }

    func testBoundaryDoesNotRequireWalletICloudSyncService() {
        let boundary = makeBoundary()
        let propertyNames = Mirror(reflecting: boundary).children.compactMap { $0.label }

        XCTAssertFalse(propertyNames.contains { $0.lowercased().contains("icloudsyncservice") })
    }

    func testBoundaryHasNoWalletStoreReference() {
        let boundary = makeBoundary()
        let propertyNames = Mirror(reflecting: boundary).children.compactMap { $0.label }

        XCTAssertFalse(propertyNames.contains { $0.lowercased().contains("walletstore") })
    }

    func testBoundaryHasNoBackupReference() {
        let boundary = makeBoundary()
        let propertyNames = Mirror(reflecting: boundary).children.compactMap { $0.label }

        XCTAssertFalse(propertyNames.contains { $0.lowercased().contains("backup") })
    }

    func testSaveRecordsDelegatesToInjectedSaverOnce() async throws {
        let saver = FakeRecordSaver()
        let boundary = makeBoundary(recordSaver: saver)
        let records = [
            makeRecord(named: "Account_11111111-1111-1111-1111-111111111111")
        ]

        _ = try await boundary.saveRecords(records)

        XCTAssertEqual(saver.saveCallCount, 1)
    }

    func testSaveRecordsPassesExactRecordsToInjectedSaver() async throws {
        let saver = FakeRecordSaver()
        let boundary = makeBoundary(recordSaver: saver)
        let records = [
            makeRecord(named: "Account_11111111-1111-1111-1111-111111111111"),
            makeRecord(named: "FinancialEvent_22222222-2222-2222-2222-222222222222")
        ]

        _ = try await boundary.saveRecords(records)

        XCTAssertEqual(
            saver.receivedRecordNames,
            [
                "Account_11111111-1111-1111-1111-111111111111",
                "FinancialEvent_22222222-2222-2222-2222-222222222222"
            ]
        )
    }

    func testSaveRecordsUsesSyncZoneRecordsForInjectedSaver() async throws {
        let saver = FakeRecordSaver()
        let boundary = makeBoundary(recordSaver: saver)

        _ = try await boundary.saveRecords([
            makeRecord(named: "Account_11111111-1111-1111-1111-111111111111")
        ])

        XCTAssertEqual(saver.receivedZoneNames, [
            WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName
        ])
    }

    func testSaveRecordsPreservesRecordFieldsWhenMovingToSyncZone() async throws {
        let saver = FakeRecordSaver()
        let boundary = makeBoundary(recordSaver: saver)
        let record = makeRecord(named: "Account_11111111-1111-1111-1111-111111111111")
        record["entity"] = "Account" as NSString
        record["field_label"] = "safe-label" as NSString
        record["fieldType_label"] = "string" as NSString

        _ = try await boundary.saveRecords([record])

        XCTAssertEqual(saver.receivedRecords.first?["entity"] as? String, "Account")
        XCTAssertEqual(saver.receivedRecords.first?["field_label"] as? String, "safe-label")
        XCTAssertEqual(saver.receivedRecords.first?["fieldType_label"] as? String, "string")
    }

    func testSaveRecordsReturnsRecordsFromInjectedSaver() async throws {
        let savedRecord = makeRecord(named: "Saved_33333333-3333-3333-3333-333333333333")
        let saver = FakeRecordSaver(recordsToReturn: [savedRecord])
        let boundary = makeBoundary(recordSaver: saver)

        let savedRecords = try await boundary.saveRecords([
            makeRecord(named: "Input_11111111-1111-1111-1111-111111111111")
        ])

        XCTAssertEqual(savedRecords.map(\.recordID.recordName), [
            "Saved_33333333-3333-3333-3333-333333333333"
        ])
    }

    func testSaveRecordsWrapsSaverErrorsSafely() async {
        let saver = FakeRecordSaver(error: TestUnderlyingError.sample)
        let boundary = makeBoundary(recordSaver: saver)

        do {
            _ = try await boundary.saveRecords([
                makeRecord(named: "Account_11111111-1111-1111-1111-111111111111")
            ])
            XCTFail("Expected saveRecords to throw")
        } catch {
            guard case .some(.unknown(let underlying)) = error as? WalletSyncCloudKitError else {
                XCTFail("Expected unknown sync error")
                return
            }
            XCTAssertEqual(underlying as? TestUnderlyingError, .sample)
        }
    }

    func testSaveRecordsWithEmptyArrayReturnsEmptyWithoutTouchingSaver() async throws {
        let saver = FakeRecordSaver()
        let boundary = makeBoundary(recordSaver: saver)

        let savedRecords = try await boundary.saveRecords([])

        XCTAssertTrue(savedRecords.isEmpty)
        XCTAssertEqual(saver.saveCallCount, 0)
    }

    func testFetchChangedRecordsDelegatesToInjectedFetcherOnce() async throws {
        let changedFetcher = FakeChangedRecordFetcher()
        let boundary = makeBoundary(changedRecordFetcher: changedFetcher)

        _ = try await boundary.fetchChangedRecords(since: nil)

        XCTAssertEqual(changedFetcher.fetchCallCount, 1)
    }

    func testFetchChangedRecordsPassesOptionalTokenToInjectedFetcher() async throws {
        let tokenData = Data([1, 2, 3])
        let changedFetcher = FakeChangedRecordFetcher()
        let boundary = makeBoundary(changedRecordFetcher: changedFetcher)

        _ = try await boundary.fetchChangedRecords(since: tokenData)

        XCTAssertEqual(changedFetcher.receivedChangeTokenData, tokenData)
    }

    func testFetchChangedRecordsUsesSyncZone() async throws {
        let changedFetcher = FakeChangedRecordFetcher()
        let boundary = makeBoundary(changedRecordFetcher: changedFetcher)

        _ = try await boundary.fetchChangedRecords(since: nil)

        XCTAssertEqual(
            changedFetcher.receivedZoneIDs.map(\.zoneName),
            [WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName]
        )
    }

    func testFetchChangedRecordsReturnsChangedRecordsFromInjectedFetcher() async throws {
        let expectedRecord = makeRecord(named: "Account_11111111-1111-1111-1111-111111111111")
        let changedFetcher = FakeChangedRecordFetcher(
            result: WalletSyncCloudKitFetchResult(records: [expectedRecord])
        )
        let boundary = makeBoundary(changedRecordFetcher: changedFetcher)

        let result = try await boundary.fetchChangedRecords(since: nil)

        XCTAssertEqual(result.records.map(\.recordID.recordName), [
            "Account_11111111-1111-1111-1111-111111111111"
        ])
    }

    func testFetchChangedRecordsReturnsDeletedRecordNamesFromInjectedFetcher() async throws {
        let changedFetcher = FakeChangedRecordFetcher(
            result: WalletSyncCloudKitFetchResult(
                records: [],
                deletedRecordNames: ["Category_22222222-2222-2222-2222-222222222222"]
            )
        )
        let boundary = makeBoundary(changedRecordFetcher: changedFetcher)

        let result = try await boundary.fetchChangedRecords(since: nil)

        XCTAssertEqual(result.deletedRecordNames, [
            "Category_22222222-2222-2222-2222-222222222222"
        ])
    }

    func testFetchChangedRecordsReturnsTokenDataFromInjectedFetcher() async throws {
        let tokenData = Data([9, 8, 7])
        let changedFetcher = FakeChangedRecordFetcher(
            result: WalletSyncCloudKitFetchResult(records: [], changeTokenData: tokenData)
        )
        let boundary = makeBoundary(changedRecordFetcher: changedFetcher)

        let result = try await boundary.fetchChangedRecords(since: nil)

        XCTAssertEqual(result.changeTokenData, tokenData)
    }

    func testFetchChangedRecordsReturnsMoreComingFromInjectedFetcher() async throws {
        let changedFetcher = FakeChangedRecordFetcher(
            result: WalletSyncCloudKitFetchResult(records: [], moreComing: true)
        )
        let boundary = makeBoundary(changedRecordFetcher: changedFetcher)

        let result = try await boundary.fetchChangedRecords(since: nil)

        XCTAssertTrue(result.moreComing)
    }

    func testFetchChangedRecordsWrapsFetcherErrorsSafely() async {
        let changedFetcher = FakeChangedRecordFetcher(error: TestUnderlyingError.sample)
        let boundary = makeBoundary(changedRecordFetcher: changedFetcher)

        do {
            _ = try await boundary.fetchChangedRecords(since: nil)
            XCTFail("Expected fetchChangedRecords to throw")
        } catch {
            guard case .some(.unknown(let underlying)) = error as? WalletSyncCloudKitError else {
                XCTFail("Expected unknown sync error")
                return
            }
            XCTAssertEqual(underlying as? TestUnderlyingError, .sample)
        }
    }

    func testAccountAvailabilityDelegatesOnlyToAccountProvider() async throws {
        let accountProvider = FakePrivateBoundaryProvider()
        accountProvider.stubbedStatus = .available
        let saver = FakeRecordSaver()
        let fetcher = FakeRecordFetcher()
        let changedFetcher = FakeChangedRecordFetcher()
        let boundary = makeBoundary(
            accountStatusProvider: accountProvider,
            recordSaver: saver,
            recordFetcher: fetcher,
            changedRecordFetcher: changedFetcher
        )

        let result = try await boundary.accountAvailability()

        XCTAssertEqual(result, .available)
        XCTAssertEqual(accountProvider.accountStatusCallCount, 1)
        XCTAssertEqual(saver.saveCallCount, 0)
        XCTAssertEqual(fetcher.fetchCallCount, 0)
        XCTAssertEqual(changedFetcher.fetchCallCount, 0)
    }

    func testSaveRecordsDoesNotCallAccountStatusProvider() async throws {
        let accountProvider = FakePrivateBoundaryProvider()
        let saver = FakeRecordSaver()
        let boundary = makeBoundary(accountStatusProvider: accountProvider, recordSaver: saver)

        _ = try await boundary.saveRecords([
            makeRecord(named: "Account_11111111-1111-1111-1111-111111111111")
        ])

        XCTAssertEqual(accountProvider.accountStatusCallCount, 0)
        XCTAssertEqual(saver.saveCallCount, 1)
    }

    func testFetchChangedRecordsDoesNotCallAccountStatusProviderSaverOrSingleRecordFetcher() async throws {
        let accountProvider = FakePrivateBoundaryProvider()
        let saver = FakeRecordSaver()
        let fetcher = FakeRecordFetcher()
        let changedFetcher = FakeChangedRecordFetcher()
        let boundary = makeBoundary(
            accountStatusProvider: accountProvider,
            recordSaver: saver,
            recordFetcher: fetcher,
            changedRecordFetcher: changedFetcher
        )

        _ = try await boundary.fetchChangedRecords(since: nil)

        XCTAssertEqual(accountProvider.accountStatusCallCount, 0)
        XCTAssertEqual(saver.saveCallCount, 0)
        XCTAssertEqual(fetcher.fetchCallCount, 0)
        XCTAssertEqual(changedFetcher.fetchCallCount, 1)
    }

    func testFetchRecordDelegatesToInjectedFetcherOnce() async throws {
        let fetcher = FakeRecordFetcher()
        let boundary = makeBoundary(recordFetcher: fetcher)

        _ = try await boundary.fetchRecord(named: "Account_11111111-1111-1111-1111-111111111111")

        XCTAssertEqual(fetcher.fetchCallCount, 1)
    }

    func testFetchRecordPassesExactRecordNameToInjectedFetcher() async throws {
        let fetcher = FakeRecordFetcher()
        let boundary = makeBoundary(recordFetcher: fetcher)

        _ = try await boundary.fetchRecord(named: "Account_11111111-1111-1111-1111-111111111111")

        XCTAssertEqual(fetcher.receivedRecordNames, [
            "Account_11111111-1111-1111-1111-111111111111"
        ])
    }

    func testFetchRecordUsesSyncZone() async throws {
        let fetcher = FakeRecordFetcher()
        let boundary = makeBoundary(recordFetcher: fetcher)

        _ = try await boundary.fetchRecord(named: "Account_11111111-1111-1111-1111-111111111111")

        XCTAssertEqual(
            fetcher.receivedZoneIDs.map(\.zoneName),
            [WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName]
        )
    }

    func testFetchRecordReturnsRecordFromInjectedFetcher() async throws {
        let expectedRecord = makeRecord(named: "Account_22222222-2222-2222-2222-222222222222")
        let fetcher = FakeRecordFetcher(recordToReturn: expectedRecord)
        let boundary = makeBoundary(recordFetcher: fetcher)

        let record = try await boundary.fetchRecord(named: "Account_11111111-1111-1111-1111-111111111111")

        XCTAssertEqual(record.recordID.recordName, "Account_22222222-2222-2222-2222-222222222222")
    }

    func testFetchRecordWrapsFetcherErrorsSafely() async {
        let fetcher = FakeRecordFetcher(error: TestUnderlyingError.sample)
        let boundary = makeBoundary(recordFetcher: fetcher)

        do {
            _ = try await boundary.fetchRecord(named: "Account_11111111-1111-1111-1111-111111111111")
            XCTFail("Expected fetchRecord to throw")
        } catch {
            guard case .some(.unknown(let underlying)) = error as? WalletSyncCloudKitError else {
                XCTFail("Expected unknown sync error")
                return
            }
            XCTAssertEqual(underlying as? TestUnderlyingError, .sample)
        }
    }

    func testSaveRecordsDoesNotCallRecordFetcher() async throws {
        let saver = FakeRecordSaver()
        let fetcher = FakeRecordFetcher()
        let boundary = makeBoundary(recordSaver: saver, recordFetcher: fetcher)

        _ = try await boundary.saveRecords([
            makeRecord(named: "Account_11111111-1111-1111-1111-111111111111")
        ])

        XCTAssertEqual(saver.saveCallCount, 1)
        XCTAssertEqual(fetcher.fetchCallCount, 0)
    }

    func testEnsureSyncZoneDelegatesToInjectedZoneEnsurer() async throws {
        let zoneEnsurer = FakeZoneEnsurer()
        let boundary = makeBoundary(zoneEnsurer: zoneEnsurer)

        try await boundary.ensureSyncZone()

        XCTAssertEqual(zoneEnsurer.ensureCallCount, 1)
        XCTAssertEqual(zoneEnsurer.receivedZoneIDs.map(\.zoneName), [
            WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName
        ])
    }

    func testEnsureSyncZoneCanBeCalledRepeatedly() async throws {
        let zoneEnsurer = FakeZoneEnsurer()
        let boundary = makeBoundary(zoneEnsurer: zoneEnsurer)

        try await boundary.ensureSyncZone()
        try await boundary.ensureSyncZone()

        XCTAssertEqual(zoneEnsurer.ensureCallCount, 2)
    }

    func testEnsureSyncZoneTreatsExistingZoneSuccessAsSuccess() async throws {
        let zoneEnsurer = FakeZoneEnsurer()
        zoneEnsurer.zoneAlreadyExists = true
        let boundary = makeBoundary(zoneEnsurer: zoneEnsurer)

        try await boundary.ensureSyncZone()

        XCTAssertEqual(zoneEnsurer.ensureCallCount, 1)
    }

    func testEnsureSyncZoneWrapsZoneEnsurerErrorsSafely() async {
        let zoneEnsurer = FakeZoneEnsurer(error: TestUnderlyingError.sample)
        let boundary = makeBoundary(zoneEnsurer: zoneEnsurer)

        do {
            try await boundary.ensureSyncZone()
            XCTFail("Expected ensureSyncZone to throw")
        } catch {
            guard case .some(.unknown(let underlying)) = error as? WalletSyncCloudKitError else {
                XCTFail("Expected unknown sync error")
                return
            }
            XCTAssertEqual(underlying as? TestUnderlyingError, .sample)
        }
    }

    func testRealZoneEnsurerFetchExistingZoneReturnsSuccessWithoutCreate() async throws {
        let zoneOperator = FakeZoneOperator()
        let ensurer = WalletSyncCKPrivateDatabaseZoneEnsurer(zoneOperator: zoneOperator)

        try await ensurer.ensureZone(WalletSyncRealCloudKitPrivateDatabaseBoundary.defaultSyncZoneID())

        XCTAssertEqual(zoneOperator.fetchCallCount, 1)
        XCTAssertEqual(zoneOperator.saveCallCount, 0)
    }

    func testRealZoneEnsurerMissingZoneThenCreateReturnsSuccess() async throws {
        let zoneOperator = FakeZoneOperator(fetchError: CKError(.zoneNotFound))
        let ensurer = WalletSyncCKPrivateDatabaseZoneEnsurer(zoneOperator: zoneOperator)

        try await ensurer.ensureZone(WalletSyncRealCloudKitPrivateDatabaseBoundary.defaultSyncZoneID())

        XCTAssertEqual(zoneOperator.fetchCallCount, 1)
        XCTAssertEqual(zoneOperator.saveCallCount, 1)
    }

    func testRealZoneEnsurerCreateAlreadyExistsReturnsSuccess() async throws {
        let zoneOperator = FakeZoneOperator(
            fetchError: CKError(.zoneNotFound),
            saveError: CKError(.serverRecordChanged)
        )
        let ensurer = WalletSyncCKPrivateDatabaseZoneEnsurer(zoneOperator: zoneOperator)

        try await ensurer.ensureZone(WalletSyncRealCloudKitPrivateDatabaseBoundary.defaultSyncZoneID())

        XCTAssertEqual(zoneOperator.fetchCallCount, 1)
        XCTAssertEqual(zoneOperator.saveCallCount, 1)
    }

    func testRealZoneEnsurerNonMissingFetchErrorRemainsFailure() async {
        let zoneOperator = FakeZoneOperator(fetchError: TestUnderlyingError.sample)
        let ensurer = WalletSyncCKPrivateDatabaseZoneEnsurer(zoneOperator: zoneOperator)

        do {
            try await ensurer.ensureZone(WalletSyncRealCloudKitPrivateDatabaseBoundary.defaultSyncZoneID())
            XCTFail("Expected ensureZone to throw")
        } catch {
            XCTAssertEqual(error as? TestUnderlyingError, .sample)
            XCTAssertEqual(zoneOperator.saveCallCount, 0)
        }
    }

    func testRealZoneEnsurerNonAlreadyExistsCreateErrorRemainsFailure() async {
        let zoneOperator = FakeZoneOperator(
            fetchError: CKError(.zoneNotFound),
            saveError: TestUnderlyingError.sample
        )
        let ensurer = WalletSyncCKPrivateDatabaseZoneEnsurer(zoneOperator: zoneOperator)

        do {
            try await ensurer.ensureZone(WalletSyncRealCloudKitPrivateDatabaseBoundary.defaultSyncZoneID())
            XCTFail("Expected ensureZone to throw")
        } catch {
            XCTAssertEqual(error as? TestUnderlyingError, .sample)
            XCTAssertEqual(zoneOperator.saveCallCount, 1)
        }
    }

    private func makeBoundary(
        accountStatusProvider: FakePrivateBoundaryProvider = FakePrivateBoundaryProvider(),
        recordSaver: FakeRecordSaver = FakeRecordSaver(),
        recordFetcher: FakeRecordFetcher = FakeRecordFetcher(),
        changedRecordFetcher: FakeChangedRecordFetcher = FakeChangedRecordFetcher(),
        zoneEnsurer: FakeZoneEnsurer = FakeZoneEnsurer()
    ) -> WalletSyncRealCloudKitPrivateDatabaseBoundary {
        WalletSyncRealCloudKitPrivateDatabaseBoundary(
            configuration: WalletSyncCloudKitConfiguration(),
            accountStatusProvider: accountStatusProvider,
            recordSaver: recordSaver,
            recordFetcher: recordFetcher,
            changedRecordFetcher: changedRecordFetcher,
            zoneEnsurer: zoneEnsurer
        )
    }

    private func makeRecord(named recordName: String) -> CKRecord {
        CKRecord(
            recordType: WalletSyncCKRecordAdapter.recordType,
            recordID: CKRecord.ID(recordName: recordName)
        )
    }

    private final class FakePrivateBoundaryProvider: WalletSyncCloudKitAccountStatusProviding {
        var accountStatusCallCount = 0
        var stubbedStatus: CKAccountStatus = .available

        func accountStatus() async throws -> CKAccountStatus {
            accountStatusCallCount += 1
            return stubbedStatus
        }
    }

    private final class FakeRecordSaver: WalletSyncPrivateDatabaseRecordSaving {
        var saveCallCount = 0
        var receivedRecordNames: [String] = []
        var receivedZoneNames: [String] = []
        var receivedRecords: [CKRecord] = []
        var recordsToReturn: [CKRecord]?
        var error: Error?

        init(recordsToReturn: [CKRecord]? = nil, error: Error? = nil) {
            self.recordsToReturn = recordsToReturn
            self.error = error
        }

        func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord] {
            saveCallCount += 1
            receivedRecordNames = records.map(\.recordID.recordName)
            receivedZoneNames = records.map(\.recordID.zoneID.zoneName)
            receivedRecords = records

            if let error {
                throw error
            }

            return recordsToReturn ?? records
        }
    }

    private final class FakeRecordFetcher: WalletSyncPrivateDatabaseRecordFetching {
        var fetchCallCount = 0
        var receivedRecordNames: [String] = []
        var receivedZoneIDs: [CKRecordZone.ID] = []
        var recordToReturn: CKRecord?
        var error: Error?

        init(recordToReturn: CKRecord? = nil, error: Error? = nil) {
            self.recordToReturn = recordToReturn
            self.error = error
        }

        func fetchRecord(named recordName: String, in zoneID: CKRecordZone.ID) async throws -> CKRecord {
            fetchCallCount += 1
            receivedRecordNames.append(recordName)
            receivedZoneIDs.append(zoneID)

            if let error {
                throw error
            }

            return recordToReturn ?? CKRecord(
                recordType: WalletSyncCKRecordAdapter.recordType,
                recordID: CKRecord.ID(recordName: recordName, zoneID: zoneID)
            )
        }
    }

    private final class FakeChangedRecordFetcher: WalletSyncPrivateDatabaseChangedRecordFetching {
        var fetchCallCount = 0
        var receivedZoneIDs: [CKRecordZone.ID] = []
        var receivedChangeTokenData: Data?
        var result: WalletSyncCloudKitFetchResult
        var error: Error?

        init(
            result: WalletSyncCloudKitFetchResult = WalletSyncCloudKitFetchResult(records: []),
            error: Error? = nil
        ) {
            self.result = result
            self.error = error
        }

        func fetchChangedRecords(
            in zoneID: CKRecordZone.ID,
            since changeToken: Data?
        ) async throws -> WalletSyncCloudKitFetchResult {
            fetchCallCount += 1
            receivedZoneIDs.append(zoneID)
            receivedChangeTokenData = changeToken

            if let error {
                throw error
            }

            return result
        }
    }

    private final class FakeZoneEnsurer: WalletSyncPrivateDatabaseZoneEnsuring {
        var ensureCallCount = 0
        var receivedZoneIDs: [CKRecordZone.ID] = []
        var zoneAlreadyExists = false
        var error: Error?

        init(error: Error? = nil) {
            self.error = error
        }

        func ensureZone(_ zoneID: CKRecordZone.ID) async throws {
            ensureCallCount += 1
            receivedZoneIDs.append(zoneID)

            if let error {
                throw error
            }
        }
    }

    private final class FakeZoneOperator: WalletSyncPrivateDatabaseZoneOperating {
        var fetchCallCount = 0
        var saveCallCount = 0
        var fetchError: Error?
        var saveError: Error?

        init(fetchError: Error? = nil, saveError: Error? = nil) {
            self.fetchError = fetchError
            self.saveError = saveError
        }

        func fetchZone(_ zoneID: CKRecordZone.ID) async throws -> CKRecordZone {
            fetchCallCount += 1

            if let fetchError {
                throw fetchError
            }

            return CKRecordZone(zoneID: zoneID)
        }

        func saveZone(_ zoneID: CKRecordZone.ID) async throws {
            saveCallCount += 1

            if let saveError {
                throw saveError
            }
        }
    }

    private enum TestUnderlyingError: Error, Equatable {
        case sample
    }
}
