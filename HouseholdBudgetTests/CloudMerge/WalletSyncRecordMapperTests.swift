import XCTest
@testable import WalletBoard

final class WalletSyncRecordMapperTests: XCTestCase {

    func testAccountMapsToAccountEntity() {
        let account = makeAccount()

        let dto = WalletSyncRecordMappers.dto(for: account)

        XCTAssertEqual(dto.entity, .account)
    }

    func testAccountRecordNameIsStable() {
        let account = makeAccount()

        let dto = WalletSyncRecordMappers.dto(for: account)

        XCTAssertEqual(dto.recordName, "Account_11111111-1111-1111-1111-111111111111")
        XCTAssertEqual(dto.recordName, WalletSyncRecordIdentity(entity: .account, id: account.id).recordName)
    }

    func testAccountIDIsPreserved() {
        let account = makeAccount()

        let dto = WalletSyncRecordMappers.dto(for: account)

        XCTAssertEqual(dto.id, account.id)
    }

    func testAccountNormalFieldsArePresent() {
        let account = makeAccount()

        let dto = WalletSyncRecordMappers.dto(for: account)

        XCTAssertEqual(dto.fields["name"], .string("Test Cash"))
        XCTAssertEqual(dto.fields["balance"], .double(1250.75))
        XCTAssertEqual(dto.fields["type"], .string("Cash"))
        XCTAssertEqual(dto.fields["isActive"], .bool(true))
        XCTAssertEqual(dto.fields["recognitionAliases"], .stringArray(["Main cash", "Cash wallet"]))
        XCTAssertEqual(dto.fields["recognitionCardEndings"], .stringArray(["1234", "9876"]))
        XCTAssertEqual(dto.fields["appearanceColor"], .string("Green"))
        XCTAssertEqual(dto.fields["createdAt"], .date(account.createdAt))
    }

    func testAccountNilAppearanceColorMapsToNullField() {
        let account = makeAccount(appearanceColor: nil)

        let dto = WalletSyncRecordMappers.dto(for: account)

        XCTAssertEqual(dto.fields["appearanceColor"], .null)
    }

    func testAccountTombstoneMetadataIsPreserved() {
        let deletedAt = Date(timeIntervalSince1970: 1_800_020_000)
        let account = makeAccount(isDeleted: true, deletedAt: deletedAt)

        let dto = WalletSyncRecordMappers.dto(for: account)

        XCTAssertTrue(dto.isDeleted)
        XCTAssertEqual(dto.deletedAt, deletedAt)
        XCTAssertEqual(dto.updatedAt, account.updatedAt)
    }

    func testAccountMapperIsDeterministic() {
        let account = makeAccount()

        let first = WalletSyncRecordMappers.dto(for: account)
        let second = WalletSyncRecordMappers.dto(for: account)

        XCTAssertEqual(first.recordName, second.recordName)
        XCTAssertEqual(first.entity, second.entity)
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.updatedAt, second.updatedAt)
        XCTAssertEqual(first.deletedAt, second.deletedAt)
        XCTAssertEqual(first.isDeleted, second.isDeleted)
        XCTAssertEqual(first.fields, second.fields)
    }

    private func makeAccount(
        appearanceColor: ProviderAppearanceColor? = .green,
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) -> Account {
        Account(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Test Cash",
            balance: 1250.75,
            type: .cash,
            isActive: true,
            recognitionAliases: ["Main cash", "Cash wallet"],
            recognitionCardEndings: ["1234", "9876"],
            appearanceColor: appearanceColor,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_010_000),
            isDeleted: isDeleted,
            deletedAt: deletedAt
        )
    }
}
