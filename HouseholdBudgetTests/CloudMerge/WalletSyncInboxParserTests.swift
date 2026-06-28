import XCTest
import CloudKit
@testable import WalletBoard

final class WalletSyncInboxParserTests: XCTestCase {

    func testParserDecodesValidWalletSyncRecordIntoSafeInboxItem() {
        let id = UUID()
        let updatedAt = Date()
        let dto = WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.account.recordName(for: id),
            entity: .account,
            id: id,
            updatedAt: updatedAt,
            fields: [
                "name": .string("Private Account Name"),
                "balance": .double(99)
            ]
        )

        let result = WalletSyncInboxParser().parse(
            changedRecords: [WalletSyncCKRecordAdapter.ckRecord(from: dto)],
            deletedRecordNames: []
        )

        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items.first?.recordName, WalletSyncRecordEntity.account.recordName(for: id))
        XCTAssertEqual(result.items.first?.entity, .account)
        XCTAssertEqual(result.items.first?.id, id)
        XCTAssertEqual(result.items.first?.updatedAt, updatedAt)
        XCTAssertEqual(result.items.first?.fieldCount, 2)
        XCTAssertEqual(result.items.first?.status, .validChangedRecord)
    }

    func testParserHandlesDeletedRecordNames() {
        let id = UUID()
        let recordName = WalletSyncRecordEntity.category.recordName(for: id)

        let result = WalletSyncInboxParser().parse(changedRecords: [], deletedRecordNames: [recordName])

        XCTAssertEqual(result.items.first?.recordName, recordName)
        XCTAssertEqual(result.items.first?.entity, .category)
        XCTAssertEqual(result.items.first?.id, id)
        XCTAssertEqual(result.items.first?.isDeleted, true)
        XCTAssertEqual(result.items.first?.fieldCount, 0)
        XCTAssertEqual(result.items.first?.status, .deletedRecordNameOnly)
    }

    func testParserReportsDecodeFailuresWithoutCrashing() {
        let record = CKRecord(recordType: WalletSyncCKRecordAdapter.recordType)

        let result = WalletSyncInboxParser().parse(changedRecords: [record], deletedRecordNames: [])

        XCTAssertEqual(result.items.first?.status, .decodeFailed)
        XCTAssertEqual(result.failedCount, 1)
    }

    func testParserBlocksMonthlyBudgetItem() {
        let id = UUID()
        let dto = WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.monthlyBudgetItem.recordName(for: id),
            entity: .monthlyBudgetItem,
            id: id,
            fields: ["amount": .double(10)]
        )

        let result = WalletSyncInboxParser().parse(
            changedRecords: [WalletSyncCKRecordAdapter.ckRecord(from: dto)],
            deletedRecordNames: []
        )

        XCTAssertEqual(result.items.first?.status, .blockedMonthlyBudgetItemNoParent)
        XCTAssertEqual(result.blockedCount, 1)
    }

    func testParserBlocksHouseholdSettings() {
        let id = UUID()
        let dto = WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.householdSettings.recordName(for: id),
            entity: .householdSettings,
            id: id
        )

        let result = WalletSyncInboxParser().parse(
            changedRecords: [WalletSyncCKRecordAdapter.ckRecord(from: dto)],
            deletedRecordNames: []
        )

        XCTAssertEqual(result.items.first?.status, .blockedHouseholdSettingsNoModel)
        XCTAssertEqual(result.blockedCount, 1)
    }

    func testParserDoesNotExposePayloadValues() {
        let id = UUID()
        let dto = WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.walletEvent.recordName(for: id),
            entity: .walletEvent,
            id: id,
            fields: [
                "name": .string("Private Event Name"),
                "note": .string("Private Note")
            ]
        )

        let result = WalletSyncInboxParser().parse(
            changedRecords: [WalletSyncCKRecordAdapter.ckRecord(from: dto)],
            deletedRecordNames: []
        )
        let itemDescription = String(describing: result.items)

        XCTAssertFalse(itemDescription.contains("Private Event Name"))
        XCTAssertFalse(itemDescription.contains("Private Note"))
        XCTAssertEqual(result.items.first?.fieldCount, 2)
    }
}
