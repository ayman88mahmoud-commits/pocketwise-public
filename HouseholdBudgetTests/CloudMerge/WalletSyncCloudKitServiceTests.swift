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

    private final class FakeDatabaseBoundary: WalletSyncCloudKitDatabaseBoundary {
        var wasTouched = false
    }
}
