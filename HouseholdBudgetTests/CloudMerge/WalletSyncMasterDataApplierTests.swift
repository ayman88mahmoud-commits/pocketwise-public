import XCTest
@testable import WalletBoard

@MainActor
final class WalletSyncMasterDataApplierTests: XCTestCase {

    func testApplyButtonCannotApplyWithoutCurrentSessionPlanEquivalent() {
        let store = FakeApplyingStore()
        let result = WalletSyncMasterDataApplier(store: store).apply(WalletSyncMasterDataApplyPlanSummary(items: []))

        XCTAssertEqual(result.createdCount, 0)
        XCTAssertEqual(result.updatedCount, 0)
        XCTAssertEqual(result.disabledCount, 0)
    }

    func testApplierCreatesOnlySafeAccountFields() {
        let store = FakeApplyingStore()
        let account = makeAccount(name: "Remote Cash", balance: 0)
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .createAccount(account), entity: .account, id: account.id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.createdCount, 1)
        XCTAssertEqual(store.accounts.first?.name, "Remote Cash")
        XCTAssertEqual(store.accounts.first?.type, .cash)
        XCTAssertEqual(store.accounts.first?.balance, 0)
    }

    func testApplierUpdatesOnlySafeAccountFieldsAndPreservesBalance() {
        let id = UUID()
        let store = FakeApplyingStore(accounts: [makeAccount(id: id, name: "Local", balance: 500)])
        let remote = makeAccount(id: id, name: "Remote", balance: 0)
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .updateAccount(remote), entity: .account, id: id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.updatedCount, 1)
        XCTAssertEqual(store.accounts.first?.name, "Remote")
        XCTAssertEqual(store.accounts.first?.balance, 500)
    }

    func testApplierSoftDisablesAccount() {
        let id = UUID()
        let store = FakeApplyingStore(accounts: [makeAccount(id: id)])
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .deleteAccountSoftOrDisableOnly(id: id), entity: .account, id: id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.disabledCount, 1)
        XCTAssertEqual(store.accounts.first?.isActive, false)
        XCTAssertEqual(store.accounts.first?.isDeleted, true)
    }

    func testApplierCreatesAndUpdatesCategorySafeFieldsOnly() {
        let id = UUID()
        let store = FakeApplyingStore(categories: [makeCategory(id: id, name: "Local")])
        let create = makeCategory(name: "Created")
        let update = makeCategory(id: id, name: "Updated")
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .createCategory(create), entity: .category, id: create.id),
            makeItem(action: .updateCategory(update), entity: .category, id: id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.createdCount, 1)
        XCTAssertEqual(result.updatedCount, 1)
        XCTAssertTrue(store.categories.contains { $0.name == "Created" })
        XCTAssertTrue(store.categories.contains { $0.name == "Updated" })
    }

    func testApplierAppliesSyntheticCategoryWithoutMutatingAccountsOrWalletEvents() throws {
        let dto = try WalletSyncCKRecordAdapter.dto(
            from: WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryRecord()
        )
        let category = Category(
            id: dto.id,
            name: WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryName,
            subcategories: [WalletSyncDebugSyntheticMasterDataChangeFactory.debugSubcategoryName],
            isActive: false
        )
        let account = makeAccount()
        let walletEvent = makeWalletEvent()
        let store = FakeApplyingStore(accounts: [account], walletEvents: [walletEvent])
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .createCategory(category), entity: .category, id: category.id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.createdCount, 1)
        XCTAssertEqual(store.accounts, [account])
        XCTAssertEqual(store.walletEvents, [walletEvent])
        XCTAssertEqual(store.categories.first?.name, WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryName)
        XCTAssertEqual(store.categories.first?.isActive, false)
    }

    func testApplierSoftDisablesCategory() {
        let id = UUID()
        let store = FakeApplyingStore(categories: [makeCategory(id: id)])
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .deleteCategorySoftOrDisableOnly(id: id), entity: .category, id: id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.disabledCount, 1)
        XCTAssertEqual(store.categories.first?.isActive, false)
        XCTAssertEqual(store.categories.first?.isDeleted, true)
    }

    func testApplierCreatesAndUpdatesWalletEventSafeFieldsOnly() {
        let id = UUID()
        let store = FakeApplyingStore(walletEvents: [makeWalletEvent(id: id, name: "Local")])
        let create = makeWalletEvent(name: "Created")
        let update = makeWalletEvent(id: id, name: "Updated")
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .createWalletEvent(create), entity: .walletEvent, id: create.id),
            makeItem(action: .updateWalletEvent(update), entity: .walletEvent, id: id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.createdCount, 1)
        XCTAssertEqual(result.updatedCount, 1)
        XCTAssertTrue(store.walletEvents.contains { $0.name == "Created" })
        XCTAssertTrue(store.walletEvents.contains { $0.name == "Updated" })
    }

    func testApplierSoftDisablesWalletEvent() {
        let id = UUID()
        let store = FakeApplyingStore(walletEvents: [makeWalletEvent(id: id)])
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .deleteWalletEventSoftOrDisableOnly(id: id), entity: .walletEvent, id: id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.disabledCount, 1)
        XCTAssertEqual(store.walletEvents.first?.isActive, false)
        XCTAssertEqual(store.walletEvents.first?.isDeleted, true)
    }

    func testApplierDoesNotMutateNonMasterDataCollections() {
        let store = FakeApplyingStore()
        store.financialEventMutationCount = 0
        store.creditCardMutationCount = 0
        store.personDebtMutationCount = 0
        store.monthlyBudgetMutationCount = 0
        store.recurringMutationCount = 0

        _ = WalletSyncMasterDataApplier(store: store).apply(WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .createAccount(makeAccount()), entity: .account, id: UUID())
        ]))

        XCTAssertEqual(store.financialEventMutationCount, 0)
        XCTAssertEqual(store.creditCardMutationCount, 0)
        XCTAssertEqual(store.personDebtMutationCount, 0)
        XCTAssertEqual(store.monthlyBudgetMutationCount, 0)
        XCTAssertEqual(store.recurringMutationCount, 0)
    }

    func testApplierDoesNotExposeCloudKitUserDefaultsOrICloudSyncServiceDependencies() {
        let applier = WalletSyncMasterDataApplier(store: FakeApplyingStore())
        let propertyNames = Mirror(reflecting: applier).children.compactMap { $0.label?.lowercased() }

        XCTAssertFalse(propertyNames.contains { $0.contains("cloudkit") })
        XCTAssertFalse(propertyNames.contains { $0.contains("userdefaults") })
        XCTAssertFalse(propertyNames.contains { $0.contains("walleticloudsyncservice") })
    }

    func testSummaryCountsAreCorrect() {
        let store = FakeApplyingStore()
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .createAccount(makeAccount()), entity: .account, id: UUID()),
            makeItem(action: .blocked(reason: .nonMasterDataEntity), entity: .financialEvent, id: UUID()),
            makeItem(action: .failed, entity: nil, id: nil)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.createdCount, 1)
        XCTAssertEqual(result.blockedCount, 1)
        XCTAssertEqual(result.failedCount, 1)
    }

    private func makeItem(
        action: WalletSyncMasterDataApplyAction,
        entity: WalletSyncRecordEntity?,
        id: UUID?
    ) -> WalletSyncMasterDataApplyPlanItem {
        WalletSyncMasterDataApplyPlanItem(
            recordName: entity?.recordName(for: id ?? UUID()) ?? "bad-record",
            entity: entity,
            id: id,
            action: action
        )
    }

    private func makeAccount(id: UUID = UUID(), name: String = "Cash", balance: Double = 0) -> Account {
        Account(id: id, name: name, balance: balance, type: .cash)
    }

    private func makeCategory(id: UUID = UUID(), name: String = "Food") -> Category {
        Category(id: id, name: name, subcategories: ["Supermarket"])
    }

    private func makeWalletEvent(id: UUID = UUID(), name: String = "Groceries") -> WalletEvent {
        var event = WalletEvent(
            name: name,
            categoryName: "Food",
            subCategoryName: "Supermarket",
            defaultAccountName: nil,
            isFavorite: false
        )
        event.id = id
        return event
    }

    private final class FakeApplyingStore: WalletSyncMasterDataApplyingStore {
        var accounts: [Account]
        var categories: [Category]
        var walletEvents: [WalletEvent]
        var merchantMemories: [MerchantMemory] = []
        var historicalMonthlySummaries: [HistoricalMonthlySummaryEntry] = []
        var personDebts: [PersonDebt] = []
        var creditCards: [CreditCard] = []
        var installmentPlans: [InstallmentPlan] = []

        var financialEventMutationCount = 0
        var creditCardMutationCount = 0
        var personDebtMutationCount = 0
        var monthlyBudgetMutationCount = 0
        var recurringMutationCount = 0

        init(
            accounts: [Account] = [],
            categories: [Category] = [],
            walletEvents: [WalletEvent] = []
        ) {
            self.accounts = accounts
            self.categories = categories
            self.walletEvents = walletEvents
        }
    }
}
