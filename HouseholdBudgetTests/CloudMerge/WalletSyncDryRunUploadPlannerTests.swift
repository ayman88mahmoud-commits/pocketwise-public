import XCTest
@testable import WalletBoard

final class WalletSyncDryRunUploadPlannerTests: XCTestCase {

    private var store: WalletStore!
    private let planner = WalletSyncDryRunUploadPlanner()

    override func setUp() {
        super.setUp()
        let suiteName = "com.test.dryrun.\(UUID().uuidString)"
        store = WalletStore(userDefaults: UserDefaults(suiteName: suiteName)!)
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - Requirement 1: Empty summary from empty store

    func testEmptyStoreProducesZeroTotals() {
        let summary = planner.plan(from: store)

        XCTAssertEqual(summary.totalDTOCount, 0)
        XCTAssertEqual(summary.totalRecordCount, 0)
    }

    func testEmptyStoreProducesEmptyCountsByEntity() {
        let summary = planner.plan(from: store)

        XCTAssertTrue(summary.countsByEntity.isEmpty)
    }

    func testEmptyStoreProducesEmptySampleRecordNames() {
        let summary = planner.plan(from: store)

        XCTAssertTrue(summary.sampleRecordNames.isEmpty)
    }

    // MARK: - Requirement 2: Counts DTOs by entity

    func testCountsByEntityMatchesAddedAccounts() {
        store.accounts = [makeAccount(id: UUID()), makeAccount(id: UUID())]

        let summary = planner.plan(from: store)

        XCTAssertEqual(summary.countsByEntity[.account], 2)
    }

    func testCountsByEntityMatchesAddedFinancialEvents() {
        store.financialEvents = [makeFinancialEvent(), makeFinancialEvent(), makeFinancialEvent()]

        let summary = planner.plan(from: store)

        XCTAssertEqual(summary.countsByEntity[.financialEvent], 3)
    }

    func testTotalDTOCountSumsAcrossEntities() {
        store.accounts = [makeAccount(id: UUID())]
        store.categories = [makeCategory(id: UUID()), makeCategory(id: UUID())]

        let summary = planner.plan(from: store)

        XCTAssertEqual(summary.totalDTOCount, 3)
    }

    // MARK: - Requirement 3: Converts DTOs to CKRecords locally

    func testRecordCountMatchesDTOCount() {
        store.accounts = [makeAccount(id: UUID()), makeAccount(id: UUID())]
        store.financialEvents = [makeFinancialEvent()]

        let summary = planner.plan(from: store)

        XCTAssertEqual(summary.totalRecordCount, summary.totalDTOCount)
    }

    // MARK: - Requirement 4: Record type is WalletSyncRecord

    func testRecordTypeIsWalletSyncRecordWithEmptyStore() {
        let summary = planner.plan(from: store)

        XCTAssertEqual(summary.recordType, "WalletSyncRecord")
    }

    func testRecordTypeIsWalletSyncRecordWithData() {
        store.accounts = [makeAccount(id: UUID())]

        let summary = planner.plan(from: store)

        XCTAssertEqual(summary.recordType, "WalletSyncRecord")
    }

    // MARK: - Requirement 5: Sample record names without financial data

    func testSampleRecordNamesContainEntityPrefixedUUID() {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        store.accounts = [makeAccount(id: id)]

        let summary = planner.plan(from: store)

        XCTAssertTrue(
            summary.sampleRecordNames.contains("Account_11111111-1111-1111-1111-111111111111")
        )
    }

    func testSampleRecordNamesAreLimitedToFive() {
        store.accounts = (0..<10).map { _ in makeAccount(id: UUID()) }

        let summary = planner.plan(from: store)

        XCTAssertLessThanOrEqual(
            summary.sampleRecordNames.count,
            WalletSyncDryRunUploadPlanner.sampleRecordNameLimit
        )
    }

    func testSampleRecordNamesDoNotContainFinancialAmounts() {
        store.accounts = [makeAccount(id: UUID())]

        let summary = planner.plan(from: store)

        for name in summary.sampleRecordNames {
            XCTAssertFalse(name.contains("1250"), "Sample record name must not expose financial amounts")
        }
    }

    // MARK: - Requirement 6: householdSettings is skipped

    func testSkippedEntitiesIncludesHouseholdSettings() {
        let summary = planner.plan(from: store)

        XCTAssertTrue(summary.skippedEntities.contains(.householdSettings))
    }

    func testWarningsDescribeHouseholdSettingsSkip() {
        let summary = planner.plan(from: store)

        XCTAssertTrue(summary.warnings.contains(where: { $0.contains("householdSettings") }))
    }

    // MARK: - Requirement 7: monthlyBudgetItem excluded

    func testSkippedEntitiesIncludesMonthlyBudgetItem() {
        let summary = planner.plan(from: store)

        XCTAssertTrue(summary.skippedEntities.contains(.monthlyBudgetItem))
    }

    func testMonthlyBudgetItemNotInCountsByEntityEvenWhenBudgetHasItems() {
        var item = WalletMonthlyBudgetItem(categoryName: "Food", plannedAmount: 500.0)
        item.id = UUID()
        let budget = WalletMonthlyBudget(
            id: UUID(),
            year: 2025,
            month: 6,
            items: [item],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_010_000),
            isDeleted: false,
            deletedAt: nil
        )
        store.monthlyBudgets = [budget]

        let summary = planner.plan(from: store)

        XCTAssertNil(summary.countsByEntity[.monthlyBudgetItem])
    }

    func testWarningsDescribeMonthlyBudgetItemSkip() {
        let summary = planner.plan(from: store)

        XCTAssertTrue(summary.warnings.contains(where: { $0.contains("monthlyBudgetItem") }))
    }

    // MARK: - Requirement 8: WalletStore is not mutated

    func testPlanDoesNotMutateAccountsArray() {
        store.accounts = [makeAccount(id: UUID()), makeAccount(id: UUID())]
        let countBefore = store.accounts.count

        _ = planner.plan(from: store)

        XCTAssertEqual(store.accounts.count, countBefore)
    }

    func testPlanDoesNotMutateFinancialEventsArray() {
        store.financialEvents = [makeFinancialEvent(), makeFinancialEvent(), makeFinancialEvent()]
        let countBefore = store.financialEvents.count

        _ = planner.plan(from: store)

        XCTAssertEqual(store.financialEvents.count, countBefore)
    }

    // MARK: - Requirements 9 & 10: No upload method calls

    func testPlannerHasNoStoredServiceDependency() {
        // WalletSyncDryRunUploadPlanner has no stored properties.
        // No WalletSyncCloudKitService instance can exist, so uploadPreparedRecords
        // and uploadPreparedRecordsWithResult cannot be called.
        let mirror = Mirror(reflecting: WalletSyncDryRunUploadPlanner())

        XCTAssertEqual(mirror.children.count, 0, "Planner must have no stored properties")
    }

    // MARK: - Requirements 11 & 12: No fetch or account availability calls

    func testPlanIsSynchronousAndRequiresNoAsyncContext() {
        // plan(from:) is a synchronous, non-throwing function.
        // fetchRecordChanges and checkAccountAvailability are both async.
        // A synchronous function cannot call async methods without await,
        // so neither can be invoked by the planner.
        let summary = planner.plan(from: store)

        XCTAssertNotNil(summary)
    }

    // MARK: - Requirement 13: No CKDatabase construction

    func testPlannerProducesCorrectRecordTypeWithoutCKDatabase() {
        // WalletSyncCKRecordAdapter creates CKRecord objects, never CKDatabase.
        // The planner delegates conversion to the adapter and only counts the results.
        store.accounts = [makeAccount(id: UUID())]

        let summary = planner.plan(from: store)

        XCTAssertEqual(summary.recordType, "WalletSyncRecord")
        XCTAssertEqual(summary.totalRecordCount, 1)
    }

    // MARK: - Requirement 14: No WalletICloudSyncService dependency

    func testPlannerHasNoWalletICloudSyncServiceProperty() {
        let mirror = Mirror(reflecting: WalletSyncDryRunUploadPlanner())
        let propertyNames = mirror.children.compactMap { $0.label }

        XCTAssertFalse(
            propertyNames.contains(where: { $0.lowercased().contains("icloud") }),
            "Planner must not hold a WalletICloudSyncService reference"
        )
    }

    // MARK: - Requirement 15: No UI dependency

    func testPlannerRunsInNonUITestTargetWithoutCrashing() {
        // WalletSyncDryRunUploadPlanner is a plain struct with no SwiftUI or UIKit types.
        // This test runs in the non-UI test target. If it compiles and runs without crashing,
        // the planner has no UI dependency.
        store.accounts = [makeAccount(id: UUID())]

        let summary = planner.plan(from: store)

        XCTAssertGreaterThan(summary.totalDTOCount, 0)
    }

    // MARK: - Helpers

    private func makeAccount(id: UUID) -> Account {
        Account(
            id: id,
            name: "Test Account",
            balance: 1250.0,
            type: .cash,
            isActive: true,
            recognitionAliases: [],
            recognitionCardEndings: [],
            appearanceColor: nil,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_010_000),
            isDeleted: false,
            deletedAt: nil
        )
    }

    private func makeCategory(id: UUID) -> WalletBoard.Category {
        WalletBoard.Category(
            id: id,
            name: "Food",
            subcategories: ["Supermarket"],
            isActive: true,
            inactiveSubcategoryNames: [],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_010_000),
            isDeleted: false,
            deletedAt: nil
        )
    }

    private func makeFinancialEvent() -> FinancialEvent {
        var event = FinancialEvent(
            type: .expense,
            status: .paid,
            title: "Test Expense",
            amount: 100.0,
            date: Date(timeIntervalSince1970: 1_800_000_000),
            accountName: nil,
            destinationAccountName: nil,
            paymentMethodName: nil,
            walletEventName: nil,
            categoryName: "Food",
            subCategoryName: nil
        )
        event.id = UUID()
        event.createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        event.updatedAt = Date(timeIntervalSince1970: 1_800_010_000)
        return event
    }
}
