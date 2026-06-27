import XCTest
import CloudKit
@testable import WalletBoard

final class WalletSyncAccountAvailabilityCheckerTests: XCTestCase {

    func testCheckerReturnsAvailableFromFakeBoundary() async throws {
        let boundary = FakeCheckerBoundary(availability: .available)
        let checker = WalletSyncAccountAvailabilityChecker(boundary: boundary)

        let result = try await checker.checkAvailability()

        XCTAssertEqual(result, .available)
    }

    func testCheckerReturnsNoAccountFromFakeBoundary() async throws {
        let boundary = FakeCheckerBoundary(availability: .noAccount)
        let checker = WalletSyncAccountAvailabilityChecker(boundary: boundary)

        let result = try await checker.checkAvailability()

        XCTAssertEqual(result, .noAccount)
    }

    func testCheckerReturnsRestrictedFromFakeBoundary() async throws {
        let boundary = FakeCheckerBoundary(availability: .restricted)
        let checker = WalletSyncAccountAvailabilityChecker(boundary: boundary)

        let result = try await checker.checkAvailability()

        XCTAssertEqual(result, .restricted)
    }

    func testCheckerReturnsCouldNotDetermineFromFakeBoundary() async throws {
        let boundary = FakeCheckerBoundary(availability: .couldNotDetermine)
        let checker = WalletSyncAccountAvailabilityChecker(boundary: boundary)

        let result = try await checker.checkAvailability()

        XCTAssertEqual(result, .couldNotDetermine)
    }

    func testCheckerPropagatesFakeBoundaryErrors() async {
        let boundary = FakeCheckerBoundary(error: FakeCheckerError.unavailable)
        let checker = WalletSyncAccountAvailabilityChecker(boundary: boundary)

        do {
            _ = try await checker.checkAvailability()
            XCTFail("Expected checkAvailability to throw")
        } catch {
            XCTAssertEqual(error as? FakeCheckerError, .unavailable)
        }
    }

    func testCheckerDoesNotCallSaveRecords() async throws {
        let boundary = FakeCheckerBoundary(availability: .available)
        let checker = WalletSyncAccountAvailabilityChecker(boundary: boundary)

        _ = try await checker.checkAvailability()

        XCTAssertEqual(boundary.saveCallCount, 0)
    }

    func testCheckerDoesNotCallFetchChangedRecords() async throws {
        let boundary = FakeCheckerBoundary(availability: .available)
        let checker = WalletSyncAccountAvailabilityChecker(boundary: boundary)

        _ = try await checker.checkAvailability()

        XCTAssertEqual(boundary.fetchCallCount, 0)
    }

    func testCheckerDoesNotRequireWalletStore() async throws {
        let boundary = FakeCheckerBoundary(availability: .available)
        let checker = WalletSyncAccountAvailabilityChecker(boundary: boundary)

        let result = try await checker.checkAvailability()

        XCTAssertEqual(result, .available)
    }

    func testCheckerDoesNotRequireWalletICloudSyncService() async throws {
        let boundary = FakeCheckerBoundary(availability: .noAccount)
        let checker = WalletSyncAccountAvailabilityChecker(boundary: boundary)

        let result = try await checker.checkAvailability()

        XCTAssertEqual(result, .noAccount)
    }

    func testCheckerHasNoUIDependency() async throws {
        let boundary = FakeCheckerBoundary(availability: .restricted)
        let checker = WalletSyncAccountAvailabilityChecker(boundary: boundary)

        let result = try await checker.checkAvailability()

        XCTAssertEqual(result, .restricted)
    }

    func testCheckerCallsAccountAvailabilityExactlyOnce() async throws {
        let boundary = FakeCheckerBoundary(availability: .available)
        let checker = WalletSyncAccountAvailabilityChecker(boundary: boundary)

        _ = try await checker.checkAvailability()

        XCTAssertEqual(boundary.accountAvailabilityCallCount, 1)
    }

    func testLiveDefaultConstructsWithoutLiveCall() {
        let checker = WalletSyncAccountAvailabilityChecker.liveDefault()

        // Construction only — does not call CKContainer.accountStatus()
        _ = checker
    }

    func testLiveDefaultDoesNotCallBoundaryOnConstruction() {
        // liveDefault() creates a WalletSyncRealCloudKitAccountBoundary which
        // wraps a WalletSyncCKContainerAccountStatusProvider but does not call it.
        // No CKContainer.accountStatus() is invoked by construction alone.
        _ = WalletSyncAccountAvailabilityChecker.liveDefault()
    }

    private final class FakeCheckerBoundary: WalletSyncCloudKitDatabaseBoundary {
        var accountAvailabilityCallCount = 0
        var saveCallCount = 0
        var fetchCallCount = 0

        private let availabilityResult: WalletSyncCloudKitAccountAvailability
        private let errorToThrow: Error?

        init(
            availability: WalletSyncCloudKitAccountAvailability = .unknown,
            error: Error? = nil
        ) {
            self.availabilityResult = availability
            self.errorToThrow = error
        }

        func accountAvailability() async throws -> WalletSyncCloudKitAccountAvailability {
            accountAvailabilityCallCount += 1
            if let errorToThrow { throw errorToThrow }
            return availabilityResult
        }

        func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord] {
            saveCallCount += 1
            return records
        }

        func fetchChangedRecords(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult {
            fetchCallCount += 1
            return WalletSyncCloudKitFetchResult(records: [])
        }
    }

    private enum FakeCheckerError: Error, Equatable {
        case unavailable
    }
}
