import XCTest
import CloudKit
@testable import WalletBoard

final class WalletSyncCKRecordAdapterTests: XCTestCase {

    // MARK: - Record identity

    func testCKRecordNameMatchesDTORecordName() {
        let dto = makeDTO()

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record.recordID.recordName, dto.recordName)
    }

    func testCKRecordTypeIsStable() {
        let dto = makeDTO()

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record.recordType, WalletSyncCKRecordAdapter.recordType)
        XCTAssertEqual(record.recordType, "WalletSyncRecord")
    }

    // MARK: - Metadata fields

    func testEntityMetadataIsStored() {
        let dto = makeDTO()

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record["entity"] as? String, "Account")
    }

    func testIDMetadataIsStoredAsLowercasedString() {
        let dto = makeDTO()

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record["id"] as? String, "11111111-1111-1111-1111-111111111111")
    }

    func testUpdatedAtMetadataIsStored() {
        let updatedAt = Date(timeIntervalSince1970: 1_800_010_000)
        let dto = makeDTO(updatedAt: updatedAt)

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record["updatedAt"] as? Date, updatedAt)
    }

    func testNilUpdatedAtMetadataIsAbsent() {
        let dto = makeDTO(updatedAt: nil)

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertNil(record["updatedAt"])
    }

    func testDeletedAtMetadataIsStored() {
        let deletedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let dto = makeDTO(deletedAt: deletedAt, isDeleted: true)

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record["deletedAt"] as? Date, deletedAt)
    }

    func testNilDeletedAtMetadataIsAbsent() {
        let dto = makeDTO()

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertNil(record["deletedAt"])
    }

    func testIsDeletedFalseMetadataIsStored() {
        let dto = makeDTO(isDeleted: false)

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record["isDeleted"] as? Bool, false)
    }

    func testIsDeletedTrueMetadataIsStored() {
        let dto = makeDTO(isDeleted: true)

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record["isDeleted"] as? Bool, true)
    }

    // MARK: - DTO field type mapping

    func testStringFieldMapsCorrectly() {
        let dto = makeDTO(fields: ["name": .string("Groceries")])

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record["field_name"] as? String, "Groceries")
        XCTAssertEqual(record["fieldType_name"] as? String, "string")
    }

    func testDoubleFieldMapsCorrectly() {
        let dto = makeDTO(fields: ["amount": .double(99.50)])

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record["field_amount"] as? Double, 99.50)
    }

    func testIntFieldMapsCorrectly() {
        let dto = makeDTO(fields: ["year": .int(2025)])

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record["field_year"] as? Int, 2025)
    }

    func testBoolFieldMapsCorrectly() {
        let dto = makeDTO(fields: ["isActive": .bool(true)])

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record["field_isActive"] as? Bool, true)
    }

    func testDateFieldMapsCorrectly() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let dto = makeDTO(fields: ["createdAt": .date(date)])

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record["field_createdAt"] as? Date, date)
    }

    func testUUIDFieldMapsAsLowercasedString() {
        let uuid = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let dto = makeDTO(fields: ["debtID": .uuid(uuid)])

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record["field_debtID"] as? String, "22222222-2222-2222-2222-222222222222")
        XCTAssertEqual(record["fieldType_debtID"] as? String, "uuid")
    }

    func testStringArrayFieldMapsCorrectly() {
        let arr = ["Food", "Transport"]
        let dto = makeDTO(fields: ["aliases": .stringArray(arr)])

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record["field_aliases"] as? [String], arr)
    }

    func testEmptyStringArrayFieldIsAbsentFromRecord() {
        let dto = makeDTO(fields: ["aliases": .stringArray([])])

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertNil(record["field_aliases"])
    }

    func testEmptyStringArrayFieldTypeMarkerIsAbsentFromRecord() {
        let dto = makeDTO(fields: ["aliases": .stringArray([])])

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertNil(record["fieldType_aliases"])
    }

    func testEmptyStringArrayDoesNotAffectOtherFieldTypes() {
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let dto = makeDTO(fields: [
            "aliases": .stringArray([]),
            "name": .string("Cash"),
            "balance": .double(10),
            "year": .int(2026),
            "isActive": .bool(true),
            "createdAt": .date(createdAt)
        ])

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertNil(record["field_aliases"])
        XCTAssertEqual(record["field_name"] as? String, "Cash")
        XCTAssertEqual(record["field_balance"] as? Double, 10)
        XCTAssertEqual(record["field_year"] as? Int, 2026)
        XCTAssertEqual(record["field_isActive"] as? Bool, true)
        XCTAssertEqual(record["field_createdAt"] as? Date, createdAt)
    }

    func testNullFieldIsAbsentFromRecord() {
        let dto = makeDTO(fields: ["note": .null])

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertNil(record["field_note"])
        XCTAssertNil(record["fieldType_note"])
    }

    // MARK: - Field key collision prevention

    func testCustomFieldsDoNotCollideWithMetadataKeys() {
        // A DTO field named "entity" is stored as "field_entity", not "entity",
        // preserving the metadata key for the sync entity identifier.
        let dto = makeDTO(fields: ["entity": .string("should-not-collide")])

        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(record["entity"] as? String, "Account")
        XCTAssertEqual(record["field_entity"] as? String, "should-not-collide")
    }

    // MARK: - Reverse conversion

    func testWrongRecordTypeThrows() {
        let record = CKRecord(recordType: "WrongRecordType", recordID: CKRecord.ID(recordName: "bad"))

        XCTAssertThrowsError(try WalletSyncCKRecordAdapter.dto(from: record)) { error in
            XCTAssertEqual(error as? WalletSyncCKRecordAdapter.AdapterError, .invalidRecordType("WrongRecordType"))
        }
    }

    func testRoundTripPreservesRecordName() throws {
        let dto = makeDTO()

        let decoded = try roundTrip(dto)

        XCTAssertEqual(decoded.recordName, dto.recordName)
    }

    func testRoundTripPreservesEntity() throws {
        let dto = makeDTO()

        let decoded = try roundTrip(dto)

        XCTAssertEqual(decoded.entity, dto.entity)
    }

    func testRoundTripPreservesID() throws {
        let dto = makeDTO()

        let decoded = try roundTrip(dto)

        XCTAssertEqual(decoded.id, dto.id)
    }

    func testRoundTripPreservesMetadata() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_800_010_000)
        let deletedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let dto = makeDTO(updatedAt: updatedAt, deletedAt: deletedAt, isDeleted: true)

        let decoded = try roundTrip(dto)

        XCTAssertEqual(decoded.updatedAt, updatedAt)
        XCTAssertEqual(decoded.deletedAt, deletedAt)
        XCTAssertTrue(decoded.isDeleted)
    }

    func testRoundTripPreservesStringField() throws {
        let dto = makeDTO(fields: ["name": .string("Groceries")])

        let decoded = try roundTrip(dto)

        XCTAssertEqual(decoded.fields["name"], .string("Groceries"))
    }

    func testRoundTripPreservesDoubleField() throws {
        let dto = makeDTO(fields: ["amount": .double(99.50)])

        let decoded = try roundTrip(dto)

        XCTAssertEqual(decoded.fields["amount"], .double(99.50))
    }

    func testRoundTripPreservesIntField() throws {
        let dto = makeDTO(fields: ["year": .int(2025)])

        let decoded = try roundTrip(dto)

        XCTAssertEqual(decoded.fields["year"], .int(2025))
    }

    func testRoundTripPreservesBoolField() throws {
        let dto = makeDTO(fields: ["isActive": .bool(true)])

        let decoded = try roundTrip(dto)

        XCTAssertEqual(decoded.fields["isActive"], .bool(true))
    }

    func testRoundTripPreservesDateField() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let dto = makeDTO(fields: ["createdAt": .date(date)])

        let decoded = try roundTrip(dto)

        XCTAssertEqual(decoded.fields["createdAt"], .date(date))
    }

    func testRoundTripPreservesUUIDFieldAsUUIDNotString() throws {
        let uuid = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let dto = makeDTO(fields: ["debtID": .uuid(uuid)])

        let decoded = try roundTrip(dto)

        XCTAssertEqual(decoded.fields["debtID"], .uuid(uuid))
        XCTAssertNotEqual(decoded.fields["debtID"], .string(uuid.uuidString.lowercased()))
    }

    func testRoundTripPreservesUUIDLookingStringAsString() throws {
        let uuidLookingString = "33333333-3333-3333-3333-333333333333"
        let dto = makeDTO(fields: ["externalReference": .string(uuidLookingString)])

        let decoded = try roundTrip(dto)

        XCTAssertEqual(decoded.fields["externalReference"], .string(uuidLookingString))
        XCTAssertNotEqual(
            decoded.fields["externalReference"],
            .uuid(UUID(uuidString: uuidLookingString)!)
        )
    }

    func testRoundTripPreservesStringArrayField() throws {
        let aliases = ["Food", "Transport"]
        let dto = makeDTO(fields: ["aliases": .stringArray(aliases)])

        let decoded = try roundTrip(dto)

        XCTAssertEqual(decoded.fields["aliases"], .stringArray(aliases))
    }

    func testRoundTripOmitsEmptyStringArrayField() throws {
        let dto = makeDTO(fields: ["aliases": .stringArray([])])

        let decoded = try roundTrip(dto)

        XCTAssertNil(decoded.fields["aliases"])
    }

    func testNullFieldsRemainAbsentAfterRoundTrip() throws {
        let dto = makeDTO(fields: ["note": .null])

        let decoded = try roundTrip(dto)

        XCTAssertNil(decoded.fields["note"])
    }

    func testRoundTripPreservesCustomFieldWithoutMetadataCollision() throws {
        let dto = makeDTO(fields: ["entity": .string("custom-entity")])

        let decoded = try roundTrip(dto)

        XCTAssertEqual(decoded.entity, .account)
        XCTAssertEqual(decoded.fields["entity"], .string("custom-entity"))
    }

    func testUnknownNonPrefixedKeysAreIgnored() throws {
        let record = WalletSyncCKRecordAdapter.ckRecord(from: makeDTO(fields: ["name": .string("Cash")]))
        record["unknown"] = "ignored"

        let decoded = try WalletSyncCKRecordAdapter.dto(from: record)

        XCTAssertNil(decoded.fields["unknown"])
        XCTAssertEqual(decoded.fields["name"], .string("Cash"))
    }

    func testReverseConversionIsDeterministic() throws {
        let dto = makeDTO(
            updatedAt: Date(timeIntervalSince1970: 1_800_010_000),
            fields: [
                "name": .string("Cash"),
                "balance": .double(500.0),
                "isActive": .bool(true)
            ]
        )
        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        let first = try WalletSyncCKRecordAdapter.dto(from: record)
        let second = try WalletSyncCKRecordAdapter.dto(from: record)

        XCTAssertEqual(first.recordName, second.recordName)
        XCTAssertEqual(first.entity, second.entity)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.updatedAt, second.updatedAt)
        XCTAssertEqual(first.deletedAt, second.deletedAt)
        XCTAssertEqual(first.isDeleted, second.isDeleted)
        XCTAssertEqual(first.fields, second.fields)
    }

    // MARK: - Determinism

    func testConversionIsDeterministic() {
        let dto = makeDTO(
            updatedAt: Date(timeIntervalSince1970: 1_800_010_000),
            fields: [
                "name": .string("Cash"),
                "balance": .double(500.0),
                "isActive": .bool(true)
            ]
        )

        let first  = WalletSyncCKRecordAdapter.ckRecord(from: dto)
        let second = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        XCTAssertEqual(first.recordID.recordName,     second.recordID.recordName)
        XCTAssertEqual(first.recordType,              second.recordType)
        XCTAssertEqual(first["entity"] as? String,    second["entity"] as? String)
        XCTAssertEqual(first["id"] as? String,        second["id"] as? String)
        XCTAssertEqual(first["updatedAt"] as? Date,   second["updatedAt"] as? Date)
        XCTAssertEqual(first["isDeleted"] as? Bool,   second["isDeleted"] as? Bool)
        XCTAssertEqual(first["field_name"] as? String,    second["field_name"] as? String)
        XCTAssertEqual(first["field_balance"] as? Double, second["field_balance"] as? Double)
        XCTAssertEqual(first["field_isActive"] as? Bool,  second["field_isActive"] as? Bool)
    }

    // MARK: - Helpers

    private func makeDTO(
        updatedAt: Date? = Date(timeIntervalSince1970: 1_800_010_000),
        deletedAt: Date? = nil,
        isDeleted: Bool = false,
        fields: [String: WalletSyncFieldValue] = [:]
    ) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(
                entity: .account,
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
            ),
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            isDeleted: isDeleted,
            fields: fields
        )
    }

    private func roundTrip(_ dto: WalletSyncRecordDTO) throws -> WalletSyncRecordDTO {
        try WalletSyncCKRecordAdapter.dto(from: WalletSyncCKRecordAdapter.ckRecord(from: dto))
    }
}
