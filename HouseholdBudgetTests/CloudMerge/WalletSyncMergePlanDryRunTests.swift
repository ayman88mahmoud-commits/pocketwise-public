import XCTest
@testable import WalletBoard

final class WalletSyncMergePlanDryRunTests: XCTestCase {

    func testPlannerIdentifiesAccountCreateUpdateAndDeleteByIDExistence() {
        let existingID = UUID()
        let newID = UUID()
        let localState = FakeLocalState(accountIDs: [existingID])
        let planner = WalletSyncMergePlanDryRun(localState: localState)

        let summary = planner.makePlan(for: [
            makeItem(entity: .account, id: newID),
            makeItem(entity: .account, id: existingID),
            makeItem(entity: .account, id: existingID, isDeleted: true, status: .validDeletedTombstone)
        ])

        XCTAssertEqual(summary.wouldCreateCount, 1)
        XCTAssertEqual(summary.wouldUpdateCount, 1)
        XCTAssertEqual(summary.wouldDeleteCount, 1)
    }

    func testPlannerIdentifiesCategoryCreateUpdateAndDeleteByIDExistence() {
        let existingID = UUID()
        let newID = UUID()
        let localState = FakeLocalState(categoryIDs: [existingID])
        let planner = WalletSyncMergePlanDryRun(localState: localState)

        let summary = planner.makePlan(for: [
            makeItem(entity: .category, id: newID),
            makeItem(entity: .category, id: existingID),
            makeItem(entity: .category, id: existingID, isDeleted: true, status: .deletedRecordNameOnly)
        ])

        XCTAssertEqual(summary.wouldCreateCount, 1)
        XCTAssertEqual(summary.wouldUpdateCount, 1)
        XCTAssertEqual(summary.wouldDeleteCount, 1)
    }

    func testPlannerIdentifiesWalletEventCreateUpdateAndDeleteByIDExistence() {
        let existingID = UUID()
        let newID = UUID()
        let localState = FakeLocalState(walletEventIDs: [existingID])
        let planner = WalletSyncMergePlanDryRun(localState: localState)

        let summary = planner.makePlan(for: [
            makeItem(entity: .walletEvent, id: newID),
            makeItem(entity: .walletEvent, id: existingID),
            makeItem(entity: .walletEvent, id: existingID, isDeleted: true, status: .validDeletedTombstone)
        ])

        XCTAssertEqual(summary.wouldCreateCount, 1)
        XCTAssertEqual(summary.wouldUpdateCount, 1)
        XCTAssertEqual(summary.wouldDeleteCount, 1)
    }

    func testPlannerIgnoresDeleteWhenLocalIDDoesNotExist() {
        let planner = WalletSyncMergePlanDryRun(localState: FakeLocalState())

        let summary = planner.makePlan(for: [
            makeItem(entity: .account, id: UUID(), isDeleted: true, status: .deletedRecordNameOnly)
        ])

        XCTAssertEqual(summary.wouldIgnoreCount, 1)
    }

    func testPlannerBlocksOtherEntitiesAsPendingApplyImplementation() {
        let planner = WalletSyncMergePlanDryRun(localState: FakeLocalState())

        let summary = planner.makePlan(for: [
            makeItem(entity: .financialEvent, id: UUID())
        ])

        XCTAssertEqual(summary.blockedCount, 1)
        XCTAssertEqual(summary.items.first?.blockReason, .pendingApplyImplementation)
    }

    func testPlannerBlocksMonthlyBudgetItemAndHouseholdSettings() {
        let planner = WalletSyncMergePlanDryRun(localState: FakeLocalState())

        let summary = planner.makePlan(for: [
            makeItem(entity: .monthlyBudgetItem, id: UUID(), status: .blockedMonthlyBudgetItemNoParent),
            makeItem(entity: .householdSettings, id: UUID(), status: .blockedHouseholdSettingsNoModel)
        ])

        XCTAssertEqual(summary.blockedCount, 2)
        XCTAssertEqual(summary.items.map(\.blockReason), [
            .monthlyBudgetItemNoParent,
            .householdSettingsNoModel
        ])
    }

    func testPlannerMarksDecodeFailuresAsFailed() {
        let planner = WalletSyncMergePlanDryRun(localState: FakeLocalState())

        let summary = planner.makePlan(for: [
            WalletSyncInboxItem(
                recordName: "bad-record",
                entity: nil,
                id: nil,
                isDeleted: false,
                updatedAt: nil,
                deletedAt: nil,
                fieldCount: 0,
                status: .decodeFailed
            )
        ])

        XCTAssertEqual(summary.failedCount, 1)
    }

    func testSummaryCountsMatchPlanActions() {
        let existingID = UUID()
        let localState = FakeLocalState(accountIDs: [existingID])
        let planner = WalletSyncMergePlanDryRun(localState: localState)

        let summary = planner.makePlan(for: [
            makeItem(entity: .account, id: UUID()),
            makeItem(entity: .account, id: existingID),
            makeItem(entity: .account, id: existingID, isDeleted: true, status: .validDeletedTombstone),
            makeItem(entity: .account, id: UUID(), isDeleted: true, status: .deletedRecordNameOnly),
            makeItem(entity: .financialEvent, id: UUID()),
            WalletSyncInboxItem(
                recordName: "bad-record",
                entity: nil,
                id: nil,
                isDeleted: false,
                updatedAt: nil,
                deletedAt: nil,
                fieldCount: 0,
                status: .decodeFailed
            )
        ])

        XCTAssertEqual(summary.wouldCreateCount, 1)
        XCTAssertEqual(summary.wouldUpdateCount, 1)
        XCTAssertEqual(summary.wouldDeleteCount, 1)
        XCTAssertEqual(summary.wouldIgnoreCount, 1)
        XCTAssertEqual(summary.blockedCount, 1)
        XCTAssertEqual(summary.failedCount, 1)
    }

    func testSampleNamesAreLimited() {
        let planner = WalletSyncMergePlanDryRun(localState: FakeLocalState())
        let items = (0..<5).map { index in
            makeItem(entity: .account, id: UUID(), recordName: "Account_\(index)")
        }

        let summary = planner.makePlan(for: items)

        XCTAssertEqual(summary.sampleRecordNames(limit: 2), ["Account_0", "Account_1"])
    }

    func testPlannerNeverMutatesLocalState() {
        let localState = FakeLocalState(accountIDs: [UUID()])
        let planner = WalletSyncMergePlanDryRun(localState: localState)

        _ = planner.makePlan(for: [
            makeItem(entity: .account, id: UUID())
        ])

        XCTAssertEqual(localState.mutationCount, 0)
    }

    func testPlannerDoesNotExposeApplyDecodeOrServiceDependencies() {
        let planner = WalletSyncMergePlanDryRun(localState: FakeLocalState())
        let propertyNames = Mirror(reflecting: planner).children.compactMap { $0.label?.lowercased() }

        XCTAssertFalse(propertyNames.contains { $0.contains("apply") })
        XCTAssertFalse(propertyNames.contains { $0.contains("decode") })
        XCTAssertFalse(propertyNames.contains { $0.contains("walleticloudsyncservice") })
        XCTAssertFalse(propertyNames.contains { $0.contains("userdefaults") })
    }

    private func makeItem(
        entity: WalletSyncRecordEntity,
        id: UUID,
        recordName: String? = nil,
        isDeleted: Bool = false,
        status: WalletSyncInboxItemStatus = .validChangedRecord
    ) -> WalletSyncInboxItem {
        WalletSyncInboxItem(
            recordName: recordName ?? entity.recordName(for: id),
            entity: entity,
            id: id,
            isDeleted: isDeleted,
            updatedAt: Date(),
            deletedAt: isDeleted ? Date() : nil,
            fieldCount: 1,
            status: status
        )
    }

    private final class FakeLocalState: WalletSyncMergePlanLocalStateReading {
        var accountIDs: Set<UUID>
        var categoryIDs: Set<UUID>
        var walletEventIDs: Set<UUID>
        var mutationCount = 0

        init(
            accountIDs: Set<UUID> = [],
            categoryIDs: Set<UUID> = [],
            walletEventIDs: Set<UUID> = []
        ) {
            self.accountIDs = accountIDs
            self.categoryIDs = categoryIDs
            self.walletEventIDs = walletEventIDs
        }

        func containsAccount(id: UUID) -> Bool {
            accountIDs.contains(id)
        }

        func containsCategory(id: UUID) -> Bool {
            categoryIDs.contains(id)
        }

        func containsWalletEvent(id: UUID) -> Bool {
            walletEventIDs.contains(id)
        }
    }
}
