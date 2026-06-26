import XCTest
@testable import PocketWise

final class WalletSyncRecordIdentityTests: XCTestCase {

    func testAccountRecordNameIsStable() {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

        XCTAssertEqual(
            WalletSyncRecordEntity.account.recordName(for: id),
            "Account_11111111-1111-1111-1111-111111111111"
        )
    }

    func testFinancialEventRecordNameIsStable() {
        let id = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

        XCTAssertEqual(
            WalletSyncRecordIdentity(entity: .financialEvent, id: id).recordName,
            "FinancialEvent_22222222-2222-2222-2222-222222222222"
        )
    }

    func testDifferentEntityTypesWithSameUUIDProduceDifferentRecordNames() {
        let id = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

        let accountName = WalletSyncRecordEntity.account.recordName(for: id)
        let categoryName = WalletSyncRecordEntity.category.recordName(for: id)

        XCTAssertNotEqual(accountName, categoryName)
        XCTAssertEqual(accountName, "Account_33333333-3333-3333-3333-333333333333")
        XCTAssertEqual(categoryName, "Category_33333333-3333-3333-3333-333333333333")
    }

    func testRecordNamesDoNotContainSpaces() {
        let id = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!

        for entity in WalletSyncRecordEntity.allCases {
            XCTAssertFalse(entity.recordName(for: id).contains(" "))
        }
    }

    func testHelperIsDeterministic() {
        let id = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let first = WalletSyncRecordIdentity(entity: .creditCardPayment, id: id)
        let second = WalletSyncRecordIdentity(entity: .creditCardPayment, id: id)

        XCTAssertEqual(first.recordName, second.recordName)
        XCTAssertEqual(first, second)
    }
}
