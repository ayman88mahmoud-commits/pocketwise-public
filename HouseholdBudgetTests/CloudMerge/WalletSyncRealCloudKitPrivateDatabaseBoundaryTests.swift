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

    func testFetchChangedRecordsRemainsDisabled() async {
        let boundary = makeBoundary()

        do {
            _ = try await boundary.fetchChangedRecords(since: nil)
            XCTFail("Expected fetchChangedRecords to throw")
        } catch {
            guard case .some(.recordOperationsNotEnabled) = error as? WalletSyncCloudKitError else {
                XCTFail("Expected recordOperationsNotEnabled")
                return
            }
        }
    }

    func testAccountAvailabilityDelegatesOnlyToAccountProvider() async throws {
        let accountProvider = FakePrivateBoundaryProvider()
        accountProvider.stubbedStatus = .available
        let saver = FakeRecordSaver()
        let boundary = makeBoundary(accountStatusProvider: accountProvider, recordSaver: saver)

        let result = try await boundary.accountAvailability()

        XCTAssertEqual(result, .available)
        XCTAssertEqual(accountProvider.accountStatusCallCount, 1)
        XCTAssertEqual(saver.saveCallCount, 0)
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

    func testFetchChangedRecordsDoesNotCallAccountStatusProviderOrSaver() async {
        let accountProvider = FakePrivateBoundaryProvider()
        let saver = FakeRecordSaver()
        let boundary = makeBoundary(accountStatusProvider: accountProvider, recordSaver: saver)

        _ = try? await boundary.fetchChangedRecords(since: nil)

        XCTAssertEqual(accountProvider.accountStatusCallCount, 0)
        XCTAssertEqual(saver.saveCallCount, 0)
    }

    private func makeBoundary(
        accountStatusProvider: FakePrivateBoundaryProvider = FakePrivateBoundaryProvider(),
        recordSaver: FakeRecordSaver = FakeRecordSaver()
    ) -> WalletSyncRealCloudKitPrivateDatabaseBoundary {
        WalletSyncRealCloudKitPrivateDatabaseBoundary(
            configuration: WalletSyncCloudKitConfiguration(),
            accountStatusProvider: accountStatusProvider,
            recordSaver: recordSaver
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
        var recordsToReturn: [CKRecord]?
        var error: Error?

        init(recordsToReturn: [CKRecord]? = nil, error: Error? = nil) {
            self.recordsToReturn = recordsToReturn
            self.error = error
        }

        func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord] {
            saveCallCount += 1
            receivedRecordNames = records.map(\.recordID.recordName)

            if let error {
                throw error
            }

            return recordsToReturn ?? records
        }
    }

    private enum TestUnderlyingError: Error, Equatable {
        case sample
    }
}
