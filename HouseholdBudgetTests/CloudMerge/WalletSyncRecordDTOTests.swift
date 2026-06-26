import XCTest
@testable import PocketWise

final class WalletSyncRecordDTOTests: XCTestCase {

    func testDTOEncodesAndDecodes() throws {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let dto = WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .account, id: id),
            updatedAt: updatedAt,
            fields: [
                "name": .string("Test Cash"),
                "balance": .double(1250.75),
                "isActive": .bool(true)
            ]
        )

        let decoded = try roundTrip(dto)

        XCTAssertEqual(decoded, dto)
        XCTAssertEqual(decoded.recordName, "Account_11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(decoded.updatedAt, updatedAt)
    }

    func testFieldValuesEncodeAndDecode() throws {
        let id = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let date = Date(timeIntervalSince1970: 1_800_010_000)
        let fieldValues: [String: WalletSyncFieldValue] = [
            "string": .string("Groceries"),
            "double": .double(99.5),
            "int": .int(7),
            "bool": .bool(false),
            "date": .date(date),
            "uuid": .uuid(id),
            "stringArray": .stringArray(["Food", "Delivery"]),
            "null": .null
        ]

        let dto = WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .category, id: id),
            fields: fieldValues
        )

        let decoded = try roundTrip(dto)

        XCTAssertEqual(decoded.fields, fieldValues)
    }

    func testDeletedDTOKeepsDeletionMetadata() throws {
        let id = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let updatedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let deletedAt = Date(timeIntervalSince1970: 1_800_030_000)
        let dto = WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .financialEvent, id: id),
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            isDeleted: true,
            fields: [:]
        )

        let decoded = try roundTrip(dto)

        XCTAssertTrue(decoded.isDeleted)
        XCTAssertEqual(decoded.updatedAt, updatedAt)
        XCTAssertEqual(decoded.deletedAt, deletedAt)
    }

    func testDTORecordNameCanUseWalletSyncRecordIdentity() {
        let id = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let identity = WalletSyncRecordIdentity(entity: .creditCardPayment, id: id)

        let dto = WalletSyncRecordDTO(identity: identity)

        XCTAssertEqual(dto.recordName, identity.recordName)
        XCTAssertEqual(dto.recordName, "CreditCardPayment_44444444-4444-4444-4444-444444444444")
    }

    func testDTORecordNameContainsNoSpaces() {
        let id = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let dto = WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .householdSettings, id: id)
        )

        XCTAssertFalse(dto.recordName.contains(" "))
    }

    private func roundTrip(_ dto: WalletSyncRecordDTO) throws -> WalletSyncRecordDTO {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(dto)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WalletSyncRecordDTO.self, from: data)
    }
}
