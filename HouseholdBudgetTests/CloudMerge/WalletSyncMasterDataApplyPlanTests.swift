import XCTest
import CloudKit
@testable import WalletBoard

final class WalletSyncMasterDataApplyPlanTests: XCTestCase {

    func testMasterDataApplyPlanIncludesAccountCategoryAndWalletEventOnly() {
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())
        let records = [
            record(for: accountDTO(id: UUID())),
            record(for: categoryDTO(id: UUID())),
            record(for: walletEventDTO(id: UUID()))
        ]

        let plan = planner.makePlan(changedRecords: records, deletedRecordNames: [])

        XCTAssertEqual(plan.plannedCreateCount, 3)
        XCTAssertEqual(plan.blockedCount, 0)
    }

    func testNonMasterEntityIsBlocked() {
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())
        let dto = WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.financialEvent.recordName(for: UUID()),
            entity: .financialEvent,
            id: UUID()
        )

        let plan = planner.makePlan(changedRecords: [record(for: dto)], deletedRecordNames: [])

        XCTAssertEqual(plan.blockedCount, 1)
    }

    func testMonthlyBudgetItemAndHouseholdSettingsAreBlocked() {
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())
        let records = [
            record(for: WalletSyncRecordDTO(recordName: WalletSyncRecordEntity.monthlyBudgetItem.recordName(for: UUID()), entity: .monthlyBudgetItem, id: UUID())),
            record(for: WalletSyncRecordDTO(recordName: WalletSyncRecordEntity.householdSettings.recordName(for: UUID()), entity: .householdSettings, id: UUID()))
        ]

        let plan = planner.makePlan(changedRecords: records, deletedRecordNames: [])

        XCTAssertEqual(plan.blockedCount, 2)
    }

    func testDecodeFailuresBecomeFailedPlanItems() {
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())
        let badRecord = CKRecord(recordType: WalletSyncCKRecordAdapter.recordType)

        let plan = planner.makePlan(changedRecords: [badRecord], deletedRecordNames: [])

        XCTAssertEqual(plan.failedCount, 1)
    }

    func testAccountCreateAndUpdatePlansAreProducedByIDExistence() {
        let existingID = UUID()
        let newID = UUID()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState(accountIDs: [existingID]))

        let plan = planner.makePlan(
            changedRecords: [record(for: accountDTO(id: newID)), record(for: accountDTO(id: existingID))],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.plannedCreateCount, 1)
        XCTAssertEqual(plan.plannedUpdateCount, 1)
    }

    func testAccountDeleteIsPlannedAsSoftDisableOnly() {
        let id = UUID()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState(accountIDs: [id]))

        let plan = planner.makePlan(changedRecords: [], deletedRecordNames: [WalletSyncRecordEntity.account.recordName(for: id)])

        XCTAssertEqual(plan.plannedDisableCount, 1)
    }

    func testCategoryCreateUpdateDeleteBehaviorIsPlannedSafely() {
        let existingID = UUID()
        let newID = UUID()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState(categoryIDs: [existingID]))

        let plan = planner.makePlan(
            changedRecords: [record(for: categoryDTO(id: newID)), record(for: categoryDTO(id: existingID))],
            deletedRecordNames: [WalletSyncRecordEntity.category.recordName(for: existingID)]
        )

        XCTAssertEqual(plan.plannedCreateCount, 1)
        XCTAssertEqual(plan.plannedUpdateCount, 1)
        XCTAssertEqual(plan.plannedDisableCount, 1)
    }

    func testWalletEventCreateUpdateDeleteBehaviorIsPlannedSafely() {
        let existingID = UUID()
        let newID = UUID()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState(walletEventIDs: [existingID]))

        let plan = planner.makePlan(
            changedRecords: [record(for: walletEventDTO(id: newID)), record(for: walletEventDTO(id: existingID))],
            deletedRecordNames: [WalletSyncRecordEntity.walletEvent.recordName(for: existingID)]
        )

        XCTAssertEqual(plan.plannedCreateCount, 1)
        XCTAssertEqual(plan.plannedUpdateCount, 1)
        XCTAssertEqual(plan.plannedDisableCount, 1)
    }

    func testAccountBalanceFieldIsNotCopiedIntoApplyPlan() {
        let id = UUID()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())
        var dto = accountDTO(id: id)
        dto.fields["balance"] = .double(99_999)

        let plan = planner.makePlan(changedRecords: [record(for: dto)], deletedRecordNames: [])

        guard case .createAccount(let account) = plan.items.first?.action else {
            XCTFail("Expected create account action")
            return
        }
        XCTAssertEqual(account.balance, 0)
    }

    func testSummaryCountsAreCorrect() {
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())
        let badRecord = CKRecord(recordType: WalletSyncCKRecordAdapter.recordType)

        let plan = planner.makePlan(
            changedRecords: [
                record(for: accountDTO(id: UUID())),
                record(for: WalletSyncRecordDTO(recordName: WalletSyncRecordEntity.financialEvent.recordName(for: UUID()), entity: .financialEvent, id: UUID())),
                badRecord
            ],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.plannedCreateCount, 1)
        XCTAssertEqual(plan.blockedCount, 1)
        XCTAssertEqual(plan.failedCount, 1)
    }

    private func record(for dto: WalletSyncRecordDTO) -> CKRecord {
        WalletSyncCKRecordAdapter.ckRecord(from: dto)
    }

    private func accountDTO(id: UUID) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.account.recordName(for: id),
            entity: .account,
            id: id,
            updatedAt: Date(),
            fields: [
                "name": .string("Remote Account"),
                "balance": .double(123),
                "type": .string(AccountType.cash.rawValue),
                "isActive": .bool(true),
                "recognitionAliases": .stringArray(["Alias"]),
                "recognitionCardEndings": .stringArray(["1234"]),
                "appearanceColor": .string(ProviderAppearanceColor.green.rawValue),
                "createdAt": .date(Date())
            ]
        )
    }

    private func categoryDTO(id: UUID) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.category.recordName(for: id),
            entity: .category,
            id: id,
            updatedAt: Date(),
            fields: [
                "name": .string("Remote Category"),
                "subcategories": .stringArray(["One"]),
                "isActive": .bool(true),
                "inactiveSubcategoryNames": .stringArray([]),
                "createdAt": .date(Date())
            ]
        )
    }

    private func walletEventDTO(id: UUID) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.walletEvent.recordName(for: id),
            entity: .walletEvent,
            id: id,
            updatedAt: Date(),
            fields: [
                "name": .string("Remote Event"),
                "categoryName": .string("Food"),
                "subCategoryName": .string("Supermarket"),
                "defaultAccountName": .null,
                "isFavorite": .bool(true),
                "isActive": .bool(true),
                "createdAt": .date(Date())
            ]
        )
    }

    private final class FakeLocalState: WalletSyncMergePlanLocalStateReading {
        var accountIDs: Set<UUID>
        var categoryIDs: Set<UUID>
        var walletEventIDs: Set<UUID>

        init(accountIDs: Set<UUID> = [], categoryIDs: Set<UUID> = [], walletEventIDs: Set<UUID> = []) {
            self.accountIDs = accountIDs
            self.categoryIDs = categoryIDs
            self.walletEventIDs = walletEventIDs
        }

        func containsAccount(id: UUID) -> Bool { accountIDs.contains(id) }
        func containsCategory(id: UUID) -> Bool { categoryIDs.contains(id) }
        func containsWalletEvent(id: UUID) -> Bool { walletEventIDs.contains(id) }
    }
}
