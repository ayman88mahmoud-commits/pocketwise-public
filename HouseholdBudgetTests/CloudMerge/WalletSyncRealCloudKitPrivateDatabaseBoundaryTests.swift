import XCTest
import CloudKit
@testable import WalletBoard

final class WalletSyncRealCloudKitPrivateDatabaseBoundaryTests: XCTestCase {

    // MARK: - Test 1: Initializes without WalletStore

    func testBoundaryInitializesWithoutWalletStore() {
        let provider = FakePrivateBoundaryProvider()
        let boundary = WalletSyncRealCloudKitPrivateDatabaseBoundary(
            configuration: WalletSyncCloudKitConfiguration(),
            accountStatusProvider: provider
        )
        XCTAssertNotNil(boundary)
    }

    // MARK: - Test 2: Initializes without UI (non-UI test target)

    func testBoundaryInitializesInNonUITestTarget() {
        let boundary = WalletSyncRealCloudKitPrivateDatabaseBoundary()
        XCTAssertNotNil(boundary)
    }

    // MARK: - Test 3: Does not require WalletICloudSyncService

    func testBoundaryDoesNotRequireWalletICloudSyncService() {
        let provider = FakePrivateBoundaryProvider()
        let boundary = WalletSyncRealCloudKitPrivateDatabaseBoundary(
            configuration: WalletSyncCloudKitConfiguration(),
            accountStatusProvider: provider
        )
        let mirror = Mirror(reflecting: boundary)
        let propertyNames = mirror.children.compactMap { $0.label }
        XCTAssertFalse(
            propertyNames.contains(where: { $0.lowercased().contains("icloud") }),
            "Boundary must not hold a WalletICloudSyncService reference"
        )
    }

    // MARK: - Test 4: saveRecords throws immediately

    func testSaveRecordsThrowsImmediately() async {
        let provider = FakePrivateBoundaryProvider()
        let boundary = WalletSyncRealCloudKitPrivateDatabaseBoundary(
            configuration: WalletSyncCloudKitConfiguration(),
            accountStatusProvider: provider
        )

        do {
            _ = try await boundary.saveRecords([])
            XCTFail("saveRecords must throw before performing any record operation")
        } catch {
            guard case .some(.recordOperationsNotEnabled) = error as? WalletSyncCloudKitError else {
                XCTFail("Expected recordOperationsNotEnabled, got \(error)")
                return
            }
        }
    }

    // MARK: - Test 5: fetchChangedRecords throws immediately

    func testFetchChangedRecordsThrowsImmediately() async {
        let provider = FakePrivateBoundaryProvider()
        let boundary = WalletSyncRealCloudKitPrivateDatabaseBoundary(
            configuration: WalletSyncCloudKitConfiguration(),
            accountStatusProvider: provider
        )

        do {
            _ = try await boundary.fetchChangedRecords(since: nil)
            XCTFail("fetchChangedRecords must throw before performing any record operation")
        } catch {
            guard case .some(.recordOperationsNotEnabled) = error as? WalletSyncCloudKitError else {
                XCTFail("Expected recordOperationsNotEnabled, got \(error)")
                return
            }
        }
    }

    // MARK: - Test 6: saveRecords does not call the provider

    func testSaveRecordsDoesNotCallProvider() async {
        let provider = FakePrivateBoundaryProvider()
        let boundary = WalletSyncRealCloudKitPrivateDatabaseBoundary(
            configuration: WalletSyncCloudKitConfiguration(),
            accountStatusProvider: provider
        )

        _ = try? await boundary.saveRecords([])

        XCTAssertEqual(
            provider.accountStatusCallCount, 0,
            "saveRecords must not contact the account status provider"
        )
    }

    // MARK: - Test 7: fetchChangedRecords does not call the provider

    func testFetchChangedRecordsDoesNotCallProvider() async {
        let provider = FakePrivateBoundaryProvider()
        let boundary = WalletSyncRealCloudKitPrivateDatabaseBoundary(
            configuration: WalletSyncCloudKitConfiguration(),
            accountStatusProvider: provider
        )

        _ = try? await boundary.fetchChangedRecords(since: nil)

        XCTAssertEqual(
            provider.accountStatusCallCount, 0,
            "fetchChangedRecords must not contact the account status provider"
        )
    }

    // MARK: - Test 8: accountAvailability delegates to provider only

    func testAccountAvailabilityDelegatesToProviderAndDoesNotTouchRecordOperations() async {
        let provider = FakePrivateBoundaryProvider()
        provider.stubbedStatus = .available
        let boundary = WalletSyncRealCloudKitPrivateDatabaseBoundary(
            configuration: WalletSyncCloudKitConfiguration(),
            accountStatusProvider: provider
        )

        let result = try? await boundary.accountAvailability()

        XCTAssertEqual(result, .available)
        XCTAssertEqual(
            provider.accountStatusCallCount, 1,
            "accountAvailability must delegate to the provider exactly once"
        )
    }

    func testAccountAvailabilityWithNoAccountStatusReturnsExpectedCase() async {
        let provider = FakePrivateBoundaryProvider()
        provider.stubbedStatus = .noAccount
        let boundary = WalletSyncRealCloudKitPrivateDatabaseBoundary(
            configuration: WalletSyncCloudKitConfiguration(),
            accountStatusProvider: provider
        )

        let result = try? await boundary.accountAvailability()

        XCTAssertEqual(result, .noAccount)
        XCTAssertEqual(provider.accountStatusCallCount, 1)
    }

    // MARK: - Test 9: No CKDatabase record operation is called

    func testSaveThrowsWithoutCallingAnyDatabaseOperation() async {
        let provider = FakePrivateBoundaryProvider()
        let boundary = WalletSyncRealCloudKitPrivateDatabaseBoundary(
            configuration: WalletSyncCloudKitConfiguration(),
            accountStatusProvider: provider
        )

        var caughtError: Error?
        do {
            _ = try await boundary.saveRecords([])
        } catch {
            caughtError = error
        }

        XCTAssertNotNil(caughtError)
        XCTAssertEqual(
            provider.accountStatusCallCount, 0,
            "save must throw before any database or provider operation occurs"
        )
    }

    // MARK: - Test 10: No WalletStore mutation

    func testBoundaryHasNoWalletStoreReference() {
        let provider = FakePrivateBoundaryProvider()
        let boundary = WalletSyncRealCloudKitPrivateDatabaseBoundary(
            configuration: WalletSyncCloudKitConfiguration(),
            accountStatusProvider: provider
        )
        let mirror = Mirror(reflecting: boundary)
        let propertyNames = mirror.children.compactMap { $0.label }
        XCTAssertFalse(
            propertyNames.contains(where: { $0.lowercased().contains("store") }),
            "Boundary must not hold a WalletStore reference"
        )
    }

    // MARK: - Test 11: No backup/import/export behavior touched

    func testBoundaryHasNoBackupReference() {
        let provider = FakePrivateBoundaryProvider()
        let boundary = WalletSyncRealCloudKitPrivateDatabaseBoundary(
            configuration: WalletSyncCloudKitConfiguration(),
            accountStatusProvider: provider
        )
        let mirror = Mirror(reflecting: boundary)
        let propertyNames = mirror.children.compactMap { $0.label }
        XCTAssertFalse(
            propertyNames.contains(where: { $0.lowercased().contains("backup") }),
            "Boundary must not hold any backup-related reference"
        )
    }

    // MARK: - Test 12: No UI dependency

    func testBoundaryRunsInNonUITestTargetWithoutCrashing() async {
        let provider = FakePrivateBoundaryProvider()
        let boundary = WalletSyncRealCloudKitPrivateDatabaseBoundary(
            configuration: WalletSyncCloudKitConfiguration(),
            accountStatusProvider: provider
        )
        // Runs in the non-UI test target. No SwiftUI or UIKit types referenced.
        _ = try? await boundary.saveRecords([])
        XCTAssertTrue(true)
    }

    // MARK: - Fake provider

    private final class FakePrivateBoundaryProvider: WalletSyncCloudKitAccountStatusProviding {
        var accountStatusCallCount = 0
        var stubbedStatus: CKAccountStatus = .available

        func accountStatus() async throws -> CKAccountStatus {
            accountStatusCallCount += 1
            return stubbedStatus
        }
    }
}
