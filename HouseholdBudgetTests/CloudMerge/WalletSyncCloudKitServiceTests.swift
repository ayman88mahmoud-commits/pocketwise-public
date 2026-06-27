import XCTest
import CloudKit
@testable import WalletBoard

@MainActor
final class WalletSyncCloudKitServiceTests: XCTestCase {

    func testServiceInitializesWithoutTouchingNetworkBoundary() {
        let boundary = FakeDatabaseBoundary()

        _ = WalletSyncCloudKitService(databaseBoundary: boundary)

        XCTAssertFalse(boundary.wasTouched)
    }

    func testServiceStoresInertConfiguration() {
        let configuration = WalletSyncCloudKitConfiguration(
            containerIdentifier: "iCloud.com.example.wallet.tests",
            databaseScope: .private
        )

        let service = WalletSyncCloudKitService(configuration: configuration)

        XCTAssertEqual(service.configuration.containerIdentifier, "iCloud.com.example.wallet.tests")
        XCTAssertEqual(service.configuration.databaseScope, .private)
    }

    func testCheckAccountAvailabilityCallsFakeBoundaryOnce() async throws {
        let boundary = FakeDatabaseBoundary(accountAvailability: .available)
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        _ = try await service.checkAccountAvailability()

        XCTAssertEqual(boundary.accountAvailabilityCallCount, 1)
    }

    func testCheckAccountAvailabilityReturnsAvailableFromFakeBoundary() async throws {
        let boundary = FakeDatabaseBoundary(accountAvailability: .available)
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        let availability = try await service.checkAccountAvailability()

        XCTAssertEqual(availability, .available)
    }

    func testCheckAccountAvailabilityReturnsNoAccountFromFakeBoundary() async throws {
        let boundary = FakeDatabaseBoundary(accountAvailability: .noAccount)
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        let availability = try await service.checkAccountAvailability()

        XCTAssertEqual(availability, .noAccount)
    }

    func testCheckAccountAvailabilityReturnsRestrictedFromFakeBoundary() async throws {
        let boundary = FakeDatabaseBoundary(accountAvailability: .restricted)
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        let availability = try await service.checkAccountAvailability()

        XCTAssertEqual(availability, .restricted)
    }

    func testCheckAccountAvailabilityReturnsCouldNotDetermineFromFakeBoundary() async throws {
        let boundary = FakeDatabaseBoundary(accountAvailability: .couldNotDetermine)
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        let availability = try await service.checkAccountAvailability()

        XCTAssertEqual(availability, .couldNotDetermine)
    }

    func testCheckAccountAvailabilityPropagatesFakeBoundaryErrors() async {
        let boundary = FakeDatabaseBoundary(accountAvailabilityError: FakeBoundaryError.accountFailed)
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        do {
            _ = try await service.checkAccountAvailability()
            XCTFail("Expected checkAccountAvailability to throw")
        } catch {
            XCTAssertEqual(error as? FakeBoundaryError, .accountFailed)
        }
    }

    func testCheckAccountAvailabilityDoesNotCallSaveOrFetch() async throws {
        let boundary = FakeDatabaseBoundary(accountAvailability: .available)
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        _ = try await service.checkAccountAvailability()

        XCTAssertEqual(boundary.saveCallCount, 0)
        XCTAssertEqual(boundary.fetchCallCount, 0)
    }

    func testCheckAccountAvailabilityDoesNotRequireWalletStore() async throws {
        let boundary = FakeDatabaseBoundary(accountAvailability: .available)
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        let availability = try await service.checkAccountAvailability()

        XCTAssertEqual(availability, .available)
    }

    func testCheckAccountAvailabilityDoesNotRequireWalletICloudSyncService() async throws {
        let boundary = FakeDatabaseBoundary(accountAvailability: .available)
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        let availability = try await service.checkAccountAvailability()

        XCTAssertEqual(availability, .available)
    }

    func testCloudKitAccountStatusAvailableMapsToAvailable() {
        let availability = WalletSyncCloudKitAccountAvailability(cloudKitAccountStatus: .available)

        XCTAssertEqual(availability, .available)
    }

    func testCloudKitAccountStatusNoAccountMapsToNoAccount() {
        let availability = WalletSyncCloudKitAccountAvailability(cloudKitAccountStatus: .noAccount)

        XCTAssertEqual(availability, .noAccount)
    }

    func testCloudKitAccountStatusRestrictedMapsToRestricted() {
        let availability = WalletSyncCloudKitAccountAvailability(cloudKitAccountStatus: .restricted)

        XCTAssertEqual(availability, .restricted)
    }

    func testCloudKitAccountStatusCouldNotDetermineMapsToCouldNotDetermine() {
        let availability = WalletSyncCloudKitAccountAvailability(cloudKitAccountStatus: .couldNotDetermine)

        XCTAssertEqual(availability, .couldNotDetermine)
    }

    func testCloudKitAccountStatusTemporarilyUnavailableMapsToTemporarilyUnavailable() {
        let availability = WalletSyncCloudKitAccountAvailability(cloudKitAccountStatus: .temporarilyUnavailable)

        XCTAssertEqual(availability, .temporarilyUnavailable)
    }

    func testCloudKitAccountStatusMapperDoesNotRequireWalletStore() {
        let availability = WalletSyncCloudKitAccountAvailability(cloudKitAccountStatus: .available)

        XCTAssertEqual(availability, .available)
    }

    func testCloudKitAccountStatusMapperDoesNotRequireWalletICloudSyncService() {
        let availability = WalletSyncCloudKitAccountAvailability(cloudKitAccountStatus: .noAccount)

        XCTAssertEqual(availability, .noAccount)
    }

    func testCloudKitAccountStatusMapperDoesNotTouchFakeBoundary() {
        let boundary = FakeDatabaseBoundary(accountAvailability: .available)

        _ = WalletSyncCloudKitAccountAvailability(cloudKitAccountStatus: .available)

        XCTAssertFalse(boundary.wasTouched)
        XCTAssertEqual(boundary.accountAvailabilityCallCount, 0)
        XCTAssertEqual(boundary.saveCallCount, 0)
        XCTAssertEqual(boundary.fetchCallCount, 0)
    }

    func testRealAccountBoundaryInitializesWithoutWalletStoreOrUI() {
        let provider = FakeAccountStatusProvider(status: .available)

        _ = WalletSyncRealCloudKitAccountBoundary(accountStatusProvider: provider)

        XCTAssertEqual(provider.callCount, 0)
    }

    func testRealAccountBoundaryMapsAvailableFromFakeProvider() async throws {
        let provider = FakeAccountStatusProvider(status: .available)
        let boundary = WalletSyncRealCloudKitAccountBoundary(accountStatusProvider: provider)

        let availability = try await boundary.accountAvailability()

        XCTAssertEqual(availability, .available)
        XCTAssertEqual(provider.callCount, 1)
    }

    func testRealAccountBoundaryMapsNoAccountFromFakeProvider() async throws {
        let provider = FakeAccountStatusProvider(status: .noAccount)
        let boundary = WalletSyncRealCloudKitAccountBoundary(accountStatusProvider: provider)

        let availability = try await boundary.accountAvailability()

        XCTAssertEqual(availability, .noAccount)
    }

    func testRealAccountBoundaryMapsRestrictedFromFakeProvider() async throws {
        let provider = FakeAccountStatusProvider(status: .restricted)
        let boundary = WalletSyncRealCloudKitAccountBoundary(accountStatusProvider: provider)

        let availability = try await boundary.accountAvailability()

        XCTAssertEqual(availability, .restricted)
    }

    func testRealAccountBoundaryMapsCouldNotDetermineFromFakeProvider() async throws {
        let provider = FakeAccountStatusProvider(status: .couldNotDetermine)
        let boundary = WalletSyncRealCloudKitAccountBoundary(accountStatusProvider: provider)

        let availability = try await boundary.accountAvailability()

        XCTAssertEqual(availability, .couldNotDetermine)
    }

    func testRealAccountBoundaryMapsTemporarilyUnavailableFromFakeProvider() async throws {
        let provider = FakeAccountStatusProvider(status: .temporarilyUnavailable)
        let boundary = WalletSyncRealCloudKitAccountBoundary(accountStatusProvider: provider)

        let availability = try await boundary.accountAvailability()

        XCTAssertEqual(availability, .temporarilyUnavailable)
    }

    func testRealAccountBoundaryWrapsProviderErrors() async {
        let provider = FakeAccountStatusProvider(error: TestUnderlyingError.sample)
        let boundary = WalletSyncRealCloudKitAccountBoundary(accountStatusProvider: provider)

        do {
            _ = try await boundary.accountAvailability()
            XCTFail("Expected accountAvailability to throw")
        } catch {
            guard case .some(.unknown(let underlying)) = error as? WalletSyncCloudKitError else {
                XCTFail("Expected unknown sync error")
                return
            }
            XCTAssertEqual(underlying as? TestUnderlyingError, .sample)
        }
    }

    func testRealAccountBoundarySaveRecordsThrowsWithoutCloudKitRecordOperation() async {
        let provider = FakeAccountStatusProvider(status: .available)
        let boundary = WalletSyncRealCloudKitAccountBoundary(accountStatusProvider: provider)

        do {
            _ = try await boundary.saveRecords([
                makeRecord(named: "Account_11111111-1111-1111-1111-111111111111")
            ])
            XCTFail("Expected saveRecords to throw")
        } catch {
            guard case .some(.recordOperationsNotEnabled) = error as? WalletSyncCloudKitError else {
                XCTFail("Expected recordOperationsNotEnabled, got \(error)")
                return
            }
            XCTAssertEqual(provider.callCount, 0)
        }
    }

    func testRealAccountBoundaryFetchChangesThrowsWithoutCloudKitRecordOperation() async {
        let provider = FakeAccountStatusProvider(status: .available)
        let boundary = WalletSyncRealCloudKitAccountBoundary(accountStatusProvider: provider)

        do {
            _ = try await boundary.fetchChangedRecords(since: nil)
            XCTFail("Expected fetchChangedRecords to throw")
        } catch {
            guard case .some(.recordOperationsNotEnabled) = error as? WalletSyncCloudKitError else {
                XCTFail("Expected recordOperationsNotEnabled, got \(error)")
                return
            }
            XCTAssertEqual(provider.callCount, 0)
        }
    }

    func testRealAccountBoundaryDoesNotRequireWalletStore() async throws {
        let provider = FakeAccountStatusProvider(status: .available)
        let boundary = WalletSyncRealCloudKitAccountBoundary(accountStatusProvider: provider)

        let availability = try await boundary.accountAvailability()

        XCTAssertEqual(availability, .available)
    }

    func testRealAccountBoundaryDoesNotRequireWalletICloudSyncService() async throws {
        let provider = FakeAccountStatusProvider(status: .available)
        let boundary = WalletSyncRealCloudKitAccountBoundary(accountStatusProvider: provider)

        let availability = try await boundary.accountAvailability()

        XCTAssertEqual(availability, .available)
    }

    func testMissingDatabaseBoundaryErrorCanBeDescribedSafely() {
        let error = WalletSyncCloudKitError.missingDatabaseBoundary

        if case .missingDatabaseBoundary = error {
            XCTAssertEqual(error.localizedDescription, "Cloud sync database boundary is not configured.")
        } else {
            XCTFail("Expected missingDatabaseBoundary")
        }
    }

    func testInvalidRecordErrorCarriesMessage() {
        let error = WalletSyncCloudKitError.invalidRecord("Missing required sync metadata.")

        if case .invalidRecord(let message) = error {
            XCTAssertEqual(message, "Missing required sync metadata.")
            XCTAssertEqual(error.localizedDescription, "Missing required sync metadata.")
        } else {
            XCTFail("Expected invalidRecord")
        }
    }

    func testWrongRecordTypeErrorCarriesRecordType() {
        let error = WalletSyncCloudKitError.wrongRecordType("OtherRecord")

        if case .wrongRecordType(let recordType) = error {
            XCTAssertEqual(recordType, "OtherRecord")
            XCTAssertEqual(error.localizedDescription, "Unexpected CloudKit record type: OtherRecord.")
        } else {
            XCTFail("Expected wrongRecordType")
        }
    }

    func testPartialFailurePreservesRecordNamesAndUnderlyingError() {
        let error = WalletSyncCloudKitError.partialFailure(
            recordNames: ["Account_1", "FinancialEvent_2"],
            underlying: TestUnderlyingError.sample
        )

        if case .partialFailure(let recordNames, let underlying) = error {
            XCTAssertEqual(recordNames, ["Account_1", "FinancialEvent_2"])
            XCTAssertEqual(underlying as? TestUnderlyingError, .sample)
            XCTAssertEqual(error.localizedDescription, "Cloud sync failed for 2 record(s).")
        } else {
            XCTFail("Expected partialFailure")
        }
    }

    func testUnknownPreservesUnderlyingError() {
        let error = WalletSyncCloudKitError.unknown(underlying: TestUnderlyingError.sample)

        if case .unknown(let underlying) = error {
            XCTAssertEqual(underlying as? TestUnderlyingError, .sample)
        } else {
            XCTFail("Expected unknown")
        }
    }

    func testAccountNotAvailableExistsAsDistinctCase() {
        if case .accountNotAvailable = WalletSyncCloudKitError.accountNotAvailable {
            XCTAssertEqual(WalletSyncCloudKitError.accountNotAvailable.localizedDescription, "iCloud account is not available.")
        } else {
            XCTFail("Expected accountNotAvailable")
        }
    }

    func testNetworkUnavailableExistsAsDistinctCase() {
        if case .networkUnavailable = WalletSyncCloudKitError.networkUnavailable {
            XCTAssertEqual(WalletSyncCloudKitError.networkUnavailable.localizedDescription, "Network is unavailable.")
        } else {
            XCTFail("Expected networkUnavailable")
        }
    }

    func testPermissionFailureExistsAsDistinctCase() {
        if case .permissionFailure = WalletSyncCloudKitError.permissionFailure {
            XCTAssertEqual(WalletSyncCloudKitError.permissionFailure.localizedDescription, "CloudKit permission was denied.")
        } else {
            XCTFail("Expected permissionFailure")
        }
    }

    func testCloudKitUnavailableExistsAsDistinctCase() {
        if case .cloudKitUnavailable = WalletSyncCloudKitError.cloudKitUnavailable {
            XCTAssertEqual(WalletSyncCloudKitError.cloudKitUnavailable.localizedDescription, "CloudKit is unavailable.")
        } else {
            XCTFail("Expected cloudKitUnavailable")
        }
    }

    func testRecordOperationsNotEnabledExistsAsDistinctCase() {
        if case .recordOperationsNotEnabled = WalletSyncCloudKitError.recordOperationsNotEnabled {
            XCTAssertEqual(
                WalletSyncCloudKitError.recordOperationsNotEnabled.localizedDescription,
                "Record operations are not enabled in this sync phase."
            )
        } else {
            XCTFail("Expected recordOperationsNotEnabled")
        }
    }

    func testRecordOperationsNotEnabledIsDifferentFromCloudKitUnavailable() {
        let disabled = WalletSyncCloudKitError.recordOperationsNotEnabled
        let unavailable = WalletSyncCloudKitError.cloudKitUnavailable

        if case .cloudKitUnavailable = disabled {
            XCTFail("recordOperationsNotEnabled must not match cloudKitUnavailable")
        }
        if case .recordOperationsNotEnabled = unavailable {
            XCTFail("cloudKitUnavailable must not match recordOperationsNotEnabled")
        }
    }

    func testPrepareRecordsForUploadConvertsDTOsUsingAdapter() {
        let dto = makeDTO(fields: ["name": .string("Test Cash")])
        let service = WalletSyncCloudKitService()

        let records = service.prepareRecordsForUpload([dto])

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?["field_name"] as? String, "Test Cash")
        XCTAssertEqual(records.first?["fieldType_name"] as? String, "string")
    }

    func testPrepareRecordsForUploadPreservesRecordNames() {
        let dto = makeDTO()
        let service = WalletSyncCloudKitService()

        let record = service.prepareRecordsForUpload([dto]).first

        XCTAssertEqual(record?.recordID.recordName, dto.recordName)
    }

    func testPrepareRecordsForUploadPreservesRecordType() {
        let dto = makeDTO()
        let service = WalletSyncCloudKitService()

        let record = service.prepareRecordsForUpload([dto]).first

        XCTAssertEqual(record?.recordType, WalletSyncCKRecordAdapter.recordType)
        XCTAssertEqual(record?.recordType, "WalletSyncRecord")
    }

    func testDecodeDownloadedRecordsConvertsRecordsUsingAdapter() throws {
        let dto = makeDTO(fields: ["name": .string("Test Cash")])
        let service = WalletSyncCloudKitService()
        let records = service.prepareRecordsForUpload([dto])

        let decoded = try service.decodeDownloadedRecords(records)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.recordName, dto.recordName)
        XCTAssertEqual(decoded.first?.entity, dto.entity)
        XCTAssertEqual(decoded.first?.id, dto.id)
        XCTAssertEqual(decoded.first?.fields["name"], .string("Test Cash"))
    }

    func testDecodeDownloadedRecordsPropagatesAdapterErrorsForInvalidRecords() {
        let service = WalletSyncCloudKitService()
        let invalidRecord = CKRecord(
            recordType: "WrongRecordType",
            recordID: CKRecord.ID(recordName: "bad-record")
        )

        XCTAssertThrowsError(try service.decodeDownloadedRecords([invalidRecord])) { error in
            XCTAssertEqual(
                error as? WalletSyncCKRecordAdapter.AdapterError,
                .invalidRecordType("WrongRecordType")
            )
        }
    }

    func testLocalPrepareAndDecodeDoNotTouchNetworkBoundary() throws {
        let boundary = FakeDatabaseBoundary()
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)
        let dto = makeDTO(fields: ["name": .string("Test Cash")])

        let records = service.prepareRecordsForUpload([dto])
        _ = try service.decodeDownloadedRecords(records)

        XCTAssertFalse(boundary.wasTouched)
    }

    func testServiceDoesNotRequireWalletStore() {
        let service = WalletSyncCloudKitService()

        XCTAssertTrue(service.prepareRecordsForUpload([]).isEmpty)
    }

    func testServiceDoesNotRequireWalletICloudSyncService() {
        let service = WalletSyncCloudKitService()

        XCTAssertNoThrow(try service.decodeDownloadedRecords([]))
    }

    func testAdapterContractRemainsRespected() throws {
        let uuid = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let dto = makeDTO(fields: [
            "entity": .string("custom-entity"),
            "externalReference": .string("33333333-3333-3333-3333-333333333333"),
            "linkedID": .uuid(uuid),
            "note": .null
        ])
        let service = WalletSyncCloudKitService()

        let record = service.prepareRecordsForUpload([dto])[0]
        let decoded = try service.decodeDownloadedRecords([record])[0]

        XCTAssertEqual(record["entity"] as? String, "Account")
        XCTAssertEqual(record["field_entity"] as? String, "custom-entity")
        XCTAssertEqual(record["fieldType_entity"] as? String, "string")
        XCTAssertEqual(decoded.fields["externalReference"], .string("33333333-3333-3333-3333-333333333333"))
        XCTAssertEqual(decoded.fields["linkedID"], .uuid(uuid))
        XCTAssertNil(decoded.fields["note"])
    }

    func testUploadPreparedRecordsCallsFakeBoundaryOnce() async throws {
        let boundary = FakeDatabaseBoundary()
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)
        let records = [makeRecord(named: "Account_11111111-1111-1111-1111-111111111111")]

        _ = try await service.uploadPreparedRecords(records)

        XCTAssertEqual(boundary.saveCallCount, 1)
    }

    func testUploadPreparedRecordsPassesExactRecordNamesToFakeBoundary() async throws {
        let boundary = FakeDatabaseBoundary()
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)
        let records = [
            makeRecord(named: "Account_11111111-1111-1111-1111-111111111111"),
            makeRecord(named: "Category_22222222-2222-2222-2222-222222222222")
        ]

        _ = try await service.uploadPreparedRecords(records)

        XCTAssertEqual(
            boundary.savedRecordNames,
            [
                "Account_11111111-1111-1111-1111-111111111111",
                "Category_22222222-2222-2222-2222-222222222222"
            ]
        )
    }

    func testUploadPreparedRecordsReturnsRecordsFromFakeBoundary() async throws {
        let returnedRecord = makeRecord(named: "Returned_33333333-3333-3333-3333-333333333333")
        let boundary = FakeDatabaseBoundary(recordsToSaveReturn: [returnedRecord])
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        let returnedRecords = try await service.uploadPreparedRecords([
            makeRecord(named: "Input_11111111-1111-1111-1111-111111111111")
        ])

        XCTAssertEqual(returnedRecords.map(\.recordID.recordName), [
            "Returned_33333333-3333-3333-3333-333333333333"
        ])
    }

    func testUploadPreparedRecordsPropagatesFakeBoundaryErrors() async {
        let boundary = FakeDatabaseBoundary(saveError: FakeBoundaryError.saveFailed)
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        do {
            _ = try await service.uploadPreparedRecords([
                makeRecord(named: "Account_11111111-1111-1111-1111-111111111111")
            ])
            XCTFail("Expected uploadPreparedRecords to throw")
        } catch {
            XCTAssertEqual(error as? FakeBoundaryError, .saveFailed)
        }
    }

    func testUploadResultIncludesSavedRecords() async throws {
        let savedRecord = makeRecord(named: "Saved_11111111-1111-1111-1111-111111111111")
        let boundary = FakeDatabaseBoundary(recordsToSaveReturn: [savedRecord])
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        let result = try await service.uploadPreparedRecordsWithResult([
            makeRecord(named: "Input_22222222-2222-2222-2222-222222222222")
        ])

        XCTAssertEqual(result.savedRecords.count, 1)
        XCTAssertEqual(result.savedRecords.first?.recordID.recordName, "Saved_11111111-1111-1111-1111-111111111111")
        XCTAssertTrue(result.failedRecordNames.isEmpty)
        XCTAssertTrue(result.underlyingErrorsByRecordName.isEmpty)
    }

    func testUploadResultPreservesSavedRecordNames() async throws {
        let savedRecords = [
            makeRecord(named: "Account_11111111-1111-1111-1111-111111111111"),
            makeRecord(named: "Category_22222222-2222-2222-2222-222222222222")
        ]
        let boundary = FakeDatabaseBoundary(recordsToSaveReturn: savedRecords)
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        let result = try await service.uploadPreparedRecordsWithResult([
            makeRecord(named: "Input_33333333-3333-3333-3333-333333333333")
        ])

        XCTAssertEqual(
            result.savedRecords.map(\.recordID.recordName),
            [
                "Account_11111111-1111-1111-1111-111111111111",
                "Category_22222222-2222-2222-2222-222222222222"
            ]
        )
    }

    func testUploadResultCanRepresentFailedRecordNames() {
        let result = WalletSyncCloudKitUploadResult(
            savedRecords: [],
            failedRecordNames: ["Account_11111111-1111-1111-1111-111111111111"]
        )

        XCTAssertEqual(result.failedRecordNames, ["Account_11111111-1111-1111-1111-111111111111"])
        XCTAssertTrue(result.savedRecords.isEmpty)
    }

    func testUploadResultCanRepresentPerRecordUnderlyingErrors() {
        let result = WalletSyncCloudKitUploadResult(
            savedRecords: [],
            failedRecordNames: ["Account_11111111-1111-1111-1111-111111111111"],
            underlyingErrorsByRecordName: [
                "Account_11111111-1111-1111-1111-111111111111": TestUnderlyingError.sample
            ]
        )

        XCTAssertEqual(
            result.underlyingErrorsByRecordName["Account_11111111-1111-1111-1111-111111111111"] as? TestUnderlyingError,
            .sample
        )
    }

    func testUploadPreparedRecordsWithResultCallsOnlyFakeBoundary() async throws {
        let boundary = FakeDatabaseBoundary()
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        _ = try await service.uploadPreparedRecordsWithResult([
            makeRecord(named: "Account_11111111-1111-1111-1111-111111111111")
        ])

        XCTAssertTrue(boundary.wasTouched)
        XCTAssertEqual(boundary.saveCallCount, 1)
        XCTAssertEqual(boundary.fetchCallCount, 0)
    }

    func testUploadPreparedRecordsWithResultDoesNotConstructCloudKitContainerOrDatabase() async throws {
        let boundary = FakeDatabaseBoundary()
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        _ = try await service.uploadPreparedRecordsWithResult([])

        XCTAssertEqual(boundary.saveCallCount, 1)
        XCTAssertTrue(boundary.savedRecordNames.isEmpty)
    }

    func testUploadPreparedRecordsWithResultPropagatesFakeBoundaryErrors() async {
        let boundary = FakeDatabaseBoundary(saveError: FakeBoundaryError.saveFailed)
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        do {
            _ = try await service.uploadPreparedRecordsWithResult([
                makeRecord(named: "Account_11111111-1111-1111-1111-111111111111")
            ])
            XCTFail("Expected uploadPreparedRecordsWithResult to throw")
        } catch {
            XCTAssertEqual(error as? FakeBoundaryError, .saveFailed)
        }
    }

    func testUploadPreparedRecordsThrowsSyncErrorWhenBoundaryIsMissing() async {
        let service = WalletSyncCloudKitService()

        do {
            _ = try await service.uploadPreparedRecords([])
            XCTFail("Expected uploadPreparedRecords to throw")
        } catch {
            if case .some(.missingDatabaseBoundary) = error as? WalletSyncCloudKitError {
                XCTAssertEqual(error.localizedDescription, "Cloud sync database boundary is not configured.")
            } else {
                XCTFail("Expected missingDatabaseBoundary")
            }
        }
    }

    func testFetchRecordChangesCallsFakeBoundaryOnce() async throws {
        let boundary = FakeDatabaseBoundary()
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        _ = try await service.fetchRecordChanges(since: nil)

        XCTAssertEqual(boundary.fetchCallCount, 1)
    }

    func testFetchRecordChangesPassesChangeTokenToFakeBoundary() async throws {
        let boundary = FakeDatabaseBoundary()
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)
        let token = Data([1, 2, 3])

        _ = try await service.fetchRecordChanges(since: token)

        XCTAssertEqual(boundary.receivedChangeTokenData, token)
    }

    func testFetchRecordChangesReturnsFakeRecordsAndToken() async throws {
        let record = makeRecord(named: "Account_11111111-1111-1111-1111-111111111111")
        let token = Data([4, 5, 6])
        let boundary = FakeDatabaseBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [record], changeTokenData: token)
        )
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        let result = try await service.fetchRecordChanges(since: nil)

        XCTAssertEqual(result.records.map(\.recordID.recordName), [
            "Account_11111111-1111-1111-1111-111111111111"
        ])
        XCTAssertEqual(result.changeTokenData, token)
    }

    func testFetchRecordChangesPropagatesFakeBoundaryErrors() async {
        let boundary = FakeDatabaseBoundary(fetchError: FakeBoundaryError.fetchFailed)
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        do {
            _ = try await service.fetchRecordChanges(since: nil)
            XCTFail("Expected fetchRecordChanges to throw")
        } catch {
            XCTAssertEqual(error as? FakeBoundaryError, .fetchFailed)
        }
    }

    func testFetchRecordChangesThrowsSyncErrorWhenBoundaryIsMissing() async {
        let service = WalletSyncCloudKitService()

        do {
            _ = try await service.fetchRecordChanges(since: nil)
            XCTFail("Expected fetchRecordChanges to throw")
        } catch {
            if case .some(.missingDatabaseBoundary) = error as? WalletSyncCloudKitError {
                XCTAssertEqual(error.localizedDescription, "Cloud sync database boundary is not configured.")
            } else {
                XCTFail("Expected missingDatabaseBoundary")
            }
        }
    }

    func testPrepareRecordsForUploadStillDoesNotTouchBoundary() {
        let boundary = FakeDatabaseBoundary()
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        _ = service.prepareRecordsForUpload([makeDTO()])

        XCTAssertEqual(boundary.saveCallCount, 0)
        XCTAssertEqual(boundary.fetchCallCount, 0)
        XCTAssertEqual(boundary.accountAvailabilityCallCount, 0)
        XCTAssertFalse(boundary.wasTouched)
    }

    func testDecodeDownloadedRecordsStillDoesNotTouchBoundary() throws {
        let boundary = FakeDatabaseBoundary()
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)
        let records = service.prepareRecordsForUpload([makeDTO()])

        _ = try service.decodeDownloadedRecords(records)

        XCTAssertEqual(boundary.saveCallCount, 0)
        XCTAssertEqual(boundary.fetchCallCount, 0)
        XCTAssertEqual(boundary.accountAvailabilityCallCount, 0)
        XCTAssertFalse(boundary.wasTouched)
    }

    func testBoundaryMethodsDoNotRequireWalletStore() async throws {
        let boundary = FakeDatabaseBoundary()
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        _ = try await service.uploadPreparedRecords([])

        XCTAssertEqual(boundary.saveCallCount, 1)
    }

    func testBoundaryMethodsDoNotRequireWalletICloudSyncService() async throws {
        let boundary = FakeDatabaseBoundary()
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        _ = try await service.fetchRecordChanges(since: nil)

        XCTAssertEqual(boundary.fetchCallCount, 1)
    }

    func testUploadResultMethodDoesNotRequireWalletStore() async throws {
        let boundary = FakeDatabaseBoundary()
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        let result = try await service.uploadPreparedRecordsWithResult([])

        XCTAssertTrue(result.savedRecords.isEmpty)
    }

    func testUploadResultMethodDoesNotRequireWalletICloudSyncService() async throws {
        let boundary = FakeDatabaseBoundary()
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        let result = try await service.uploadPreparedRecordsWithResult([])

        XCTAssertTrue(result.failedRecordNames.isEmpty)
    }

    func testUploadPreparedRecordsDoesNotCallAccountStatus() async throws {
        let boundary = FakeDatabaseBoundary()
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        _ = try await service.uploadPreparedRecords([])

        XCTAssertEqual(boundary.saveCallCount, 1)
        XCTAssertEqual(boundary.accountAvailabilityCallCount, 0)
    }

    func testFetchRecordChangesDoesNotCallAccountStatus() async throws {
        let boundary = FakeDatabaseBoundary()
        let service = WalletSyncCloudKitService(databaseBoundary: boundary)

        _ = try await service.fetchRecordChanges(since: nil)

        XCTAssertEqual(boundary.fetchCallCount, 1)
        XCTAssertEqual(boundary.accountAvailabilityCallCount, 0)
    }

    private func makeDTO(
        fields: [String: WalletSyncFieldValue] = [:]
    ) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(
                entity: .account,
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
            ),
            updatedAt: Date(timeIntervalSince1970: 1_800_010_000),
            fields: fields
        )
    }

    private func makeRecord(named recordName: String) -> CKRecord {
        CKRecord(
            recordType: WalletSyncCKRecordAdapter.recordType,
            recordID: CKRecord.ID(recordName: recordName)
        )
    }

    private final class FakeDatabaseBoundary: WalletSyncCloudKitDatabaseBoundary {
        var accountAvailabilityCallCount = 0
        var saveCallCount = 0
        var fetchCallCount = 0
        var savedRecordNames: [String] = []
        var receivedChangeTokenData: Data?
        var wasTouched = false

        var accountAvailabilityResult: WalletSyncCloudKitAccountAvailability
        var recordsToSaveReturn: [CKRecord]?
        var fetchResult: WalletSyncCloudKitFetchResult
        var accountAvailabilityError: Error?
        var saveError: Error?
        var fetchError: Error?

        init(
            accountAvailability: WalletSyncCloudKitAccountAvailability = .unknown,
            recordsToSaveReturn: [CKRecord]? = nil,
            fetchResult: WalletSyncCloudKitFetchResult? = nil,
            accountAvailabilityError: Error? = nil,
            saveError: Error? = nil,
            fetchError: Error? = nil
        ) {
            self.accountAvailabilityResult = accountAvailability
            self.recordsToSaveReturn = recordsToSaveReturn
            self.fetchResult = fetchResult ?? WalletSyncCloudKitFetchResult(records: [])
            self.accountAvailabilityError = accountAvailabilityError
            self.saveError = saveError
            self.fetchError = fetchError
        }

        func accountAvailability() async throws -> WalletSyncCloudKitAccountAvailability {
            wasTouched = true
            accountAvailabilityCallCount += 1

            if let accountAvailabilityError {
                throw accountAvailabilityError
            }

            return accountAvailabilityResult
        }

        func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord] {
            wasTouched = true
            saveCallCount += 1
            savedRecordNames = records.map(\.recordID.recordName)

            if let saveError {
                throw saveError
            }

            return recordsToSaveReturn ?? records
        }

        func fetchChangedRecords(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult {
            wasTouched = true
            fetchCallCount += 1
            receivedChangeTokenData = changeToken

            if let fetchError {
                throw fetchError
            }

            return fetchResult
        }
    }

    private enum FakeBoundaryError: Error, Equatable {
        case accountFailed
        case saveFailed
        case fetchFailed
    }

    private final class FakeAccountStatusProvider: WalletSyncCloudKitAccountStatusProviding {
        var status: CKAccountStatus
        var error: Error?
        var callCount = 0

        init(status: CKAccountStatus = .available, error: Error? = nil) {
            self.status = status
            self.error = error
        }

        func accountStatus() async throws -> CKAccountStatus {
            callCount += 1

            if let error {
                throw error
            }

            return status
        }
    }

    private enum TestUnderlyingError: Error, Equatable {
        case sample
    }
}
