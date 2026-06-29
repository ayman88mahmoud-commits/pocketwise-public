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

    func testApplierCreatesAccountWithRemoteStoredBalance() {
        let store = FakeApplyingStore()
        let account = makeAccount(name: "Remote Cash", balance: 900)
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .createAccount(account), entity: .account, id: account.id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.createdCount, 1)
        XCTAssertEqual(store.accounts.first?.name, "Remote Cash")
        XCTAssertEqual(store.accounts.first?.type, .cash)
        XCTAssertEqual(store.accounts.first?.balance, 900)
    }

    func testApplierUpdatesAccountByDirectlyCopyingRemoteStoredBalance() {
        let id = UUID()
        let store = FakeApplyingStore(accounts: [makeAccount(id: id, name: "Local", balance: 500)])
        let remote = makeAccount(id: id, name: "Remote", balance: 900)
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .updateAccount(remote), entity: .account, id: id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.updatedCount, 1)
        XCTAssertEqual(store.accounts.first?.name, "Remote")
        XCTAssertEqual(store.accounts.first?.balance, 900)
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

    private func makeCategory(id: UUID = UUID(), name: String = "Food") -> WalletBoard.Category {
        WalletBoard.Category(id: id, name: name, subcategories: ["Supermarket"])
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

    func testApplyCreateMonthlyBudgetAddsToStore() {
        let store = FakeApplyingStore()
        var budget = WalletMonthlyBudget(year: 2026, month: 6, items: [])
        budget.id = UUID()
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .createWalletMonthlyBudget(budget), entity: .monthlyBudget, id: budget.id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.createdCount, 1)
        XCTAssertEqual(store.monthlyBudgets.count, 1)
        XCTAssertEqual(store.monthlyBudgets.first?.id, budget.id)
        XCTAssertEqual(store.monthlyBudgets.first?.year, 2026)
        XCTAssertEqual(store.monthlyBudgets.first?.month, 6)
    }

    func testApplyCreateMonthlyBudgetDoesNotTouchItems() {
        let store = FakeApplyingStore()
        var budget = WalletMonthlyBudget(year: 2026, month: 6, items: [])
        budget.id = UUID()
        let itemCarriedInRemote = WalletMonthlyBudgetItem(categoryName: "Food", plannedAmount: 500)
        budget.items = [itemCarriedInRemote]
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .createWalletMonthlyBudget(budget), entity: .monthlyBudget, id: budget.id)
        ])

        _ = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(store.monthlyBudgets.first?.items.count, 0)
    }

    func testApplyCreateMonthlyBudgetIgnoresDuplicate() {
        let budgetID = UUID()
        var existing = WalletMonthlyBudget(year: 2026, month: 6, items: [])
        existing.id = budgetID
        let store = FakeApplyingStore(monthlyBudgets: [existing])
        var remote = WalletMonthlyBudget(year: 2026, month: 6, items: [])
        remote.id = budgetID
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .createWalletMonthlyBudget(remote), entity: .monthlyBudget, id: budgetID)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.createdCount, 0)
        XCTAssertEqual(store.monthlyBudgets.count, 1)
    }

    func testApplyUpdateMonthlyBudgetUpdatesMetadataFields() {
        let budgetID = UUID()
        var existing = WalletMonthlyBudget(year: 2025, month: 1, items: [])
        existing.id = budgetID
        let store = FakeApplyingStore(monthlyBudgets: [existing])
        var remote = WalletMonthlyBudget(year: 2026, month: 6, items: [])
        remote.id = budgetID
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .updateWalletMonthlyBudget(remote), entity: .monthlyBudget, id: budgetID)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.updatedCount, 1)
        XCTAssertEqual(store.monthlyBudgets.first?.year, 2026)
        XCTAssertEqual(store.monthlyBudgets.first?.month, 6)
    }

    func testApplyUpdateMonthlyBudgetPreservesExistingItems() {
        let budgetID = UUID()
        let localItem = WalletMonthlyBudgetItem(categoryName: "Food", plannedAmount: 500)
        var existing = WalletMonthlyBudget(year: 2025, month: 1, items: [localItem])
        existing.id = budgetID
        let store = FakeApplyingStore(monthlyBudgets: [existing])
        var remote = WalletMonthlyBudget(year: 2026, month: 6, items: [])
        remote.id = budgetID
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .updateWalletMonthlyBudget(remote), entity: .monthlyBudget, id: budgetID)
        ])

        _ = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(store.monthlyBudgets.first?.items.count, 1)
        XCTAssertEqual(store.monthlyBudgets.first?.items.first?.categoryName, "Food")
    }

    func testApplyCreateMonthlyBudgetItemAddsToParent() {
        let budgetID = UUID()
        var budget = WalletMonthlyBudget(year: 2026, month: 6, items: [])
        budget.id = budgetID
        let store = FakeApplyingStore(monthlyBudgets: [budget])
        var item = WalletMonthlyBudgetItem(categoryName: "Food", plannedAmount: 500)
        item.id = UUID()
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .createWalletMonthlyBudgetItem(item, parentBudgetID: budgetID), entity: .monthlyBudgetItem, id: item.id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.createdCount, 1)
        XCTAssertEqual(store.monthlyBudgets.first?.items.count, 1)
        XCTAssertEqual(store.monthlyBudgets.first?.items.first?.categoryName, "Food")
        XCTAssertEqual(store.monthlyBudgets.first?.items.first?.plannedAmount, 500)
    }

    func testApplyCreateMonthlyBudgetItemSkipsIfParentNotFound() {
        let store = FakeApplyingStore()
        var item = WalletMonthlyBudgetItem(categoryName: "Food", plannedAmount: 500)
        item.id = UUID()
        let orphanParentID = UUID()
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .createWalletMonthlyBudgetItem(item, parentBudgetID: orphanParentID), entity: .monthlyBudgetItem, id: item.id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.createdCount, 0)
        XCTAssertEqual(result.skippedCount, 1)
    }

    func testApplyCreateMonthlyBudgetItemIgnoresDuplicateItem() {
        let budgetID = UUID()
        let itemID = UUID()
        var existingItem = WalletMonthlyBudgetItem(categoryName: "Food", plannedAmount: 500)
        existingItem.id = itemID
        var budget = WalletMonthlyBudget(year: 2026, month: 6, items: [existingItem])
        budget.id = budgetID
        let store = FakeApplyingStore(monthlyBudgets: [budget])
        var remoteItem = WalletMonthlyBudgetItem(categoryName: "Food", plannedAmount: 600)
        remoteItem.id = itemID
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .createWalletMonthlyBudgetItem(remoteItem, parentBudgetID: budgetID), entity: .monthlyBudgetItem, id: itemID)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.createdCount, 0)
        XCTAssertEqual(store.monthlyBudgets.first?.items.first?.plannedAmount, 500)
    }

    func testApplyUpdateMonthlyBudgetItemUpdatesFields() {
        let budgetID = UUID()
        let itemID = UUID()
        var existingItem = WalletMonthlyBudgetItem(categoryName: "Food", plannedAmount: 500)
        existingItem.id = itemID
        var budget = WalletMonthlyBudget(year: 2026, month: 6, items: [existingItem])
        budget.id = budgetID
        let store = FakeApplyingStore(monthlyBudgets: [budget])
        var remoteItem = WalletMonthlyBudgetItem(categoryName: "Transport", plannedAmount: 750)
        remoteItem.id = itemID
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .updateWalletMonthlyBudgetItem(remoteItem, parentBudgetID: budgetID), entity: .monthlyBudgetItem, id: itemID)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.updatedCount, 1)
        XCTAssertEqual(store.monthlyBudgets.first?.items.first?.categoryName, "Transport")
        XCTAssertEqual(store.monthlyBudgets.first?.items.first?.plannedAmount, 750)
    }

    func testApplyUpdateMonthlyBudgetItemSkipsIfParentNotFound() {
        let store = FakeApplyingStore()
        var item = WalletMonthlyBudgetItem(categoryName: "Food", plannedAmount: 500)
        item.id = UUID()
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .updateWalletMonthlyBudgetItem(item, parentBudgetID: UUID()), entity: .monthlyBudgetItem, id: item.id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.updatedCount, 0)
        XCTAssertEqual(result.skippedCount, 1)
    }

    func testApplyUpdateMonthlyBudgetItemSkipsIfItemNotFoundInParent() {
        let budgetID = UUID()
        var budget = WalletMonthlyBudget(year: 2026, month: 6, items: [])
        budget.id = budgetID
        let store = FakeApplyingStore(monthlyBudgets: [budget])
        var item = WalletMonthlyBudgetItem(categoryName: "Food", plannedAmount: 500)
        item.id = UUID()
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .updateWalletMonthlyBudgetItem(item, parentBudgetID: budgetID), entity: .monthlyBudgetItem, id: item.id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.updatedCount, 0)
        XCTAssertEqual(result.skippedCount, 1)
    }

    func testApplyOrdersParentBeforeChildWhenChildAppearsFirst() {
        let cardID = UUID()
        let purchaseID = UUID()
        let card = CreditCard(
            id: cardID,
            name: "Remote Card",
            bankName: "Bank",
            cardNetwork: .visa,
            creditLimit: 5000,
            statementClosingDay: 25,
            paymentDueDay: 15
        )
        let purchase = CreditCardPurchase(
            id: purchaseID,
            cardID: cardID,
            title: "Purchase",
            amount: 100,
            purchaseDate: Date(),
            categoryName: "Food",
            subCategoryName: "Supermarket",
            note: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let store = FakeApplyingStore()
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .createCreditCardPurchase(purchase), entity: .creditCardPurchase, id: purchaseID),
            makeItem(action: .createCreditCard(card), entity: .creditCard, id: cardID)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.createdCount, 2)
        XCTAssertEqual(store.creditCards.map(\.id), [cardID])
        XCTAssertEqual(store.creditCardPurchases.map(\.id), [purchaseID])
    }

    func testChildDoesNotCreateOrphanWhenParentApplyFailedOrMissing() {
        let cardID = UUID()
        let purchaseID = UUID()
        let purchase = CreditCardPurchase(
            id: purchaseID,
            cardID: cardID,
            title: "Purchase",
            amount: 100,
            purchaseDate: Date(),
            categoryName: "Food",
            subCategoryName: "Supermarket",
            note: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let store = FakeApplyingStore()
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .failed, entity: .creditCard, id: cardID),
            makeItem(action: .createCreditCardPurchase(purchase), entity: .creditCardPurchase, id: purchaseID)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.failedCount, 1)
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertTrue(store.creditCardPurchases.isEmpty)
    }

    func testRemoteFinancialEventDeletionRemovesEventAndRecordsLocalTombstone() {
        let eventID = UUID()
        let deletedAt = Date(timeIntervalSince1970: 1_800_001_000)
        let store = FakeApplyingStore()
        store.financialEvents = [makeFinancialEvent(id: eventID)]
        let deletionStore = FakeFinancialEventDeletionStore()
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .deleteFinancialEvent(id: eventID, deletedAt: deletedAt), entity: .financialEventDeletion, id: eventID)
        ])

        let result = WalletSyncMasterDataApplier(
            store: store,
            localFinancialEventDeletionStore: deletionStore
        ).apply(plan)

        XCTAssertEqual(result.disabledCount, 1)
        XCTAssertTrue(store.financialEvents.isEmpty)
        XCTAssertEqual(deletionStore.deletedAtByID[eventID], deletedAt)
    }

    func testRemoteInstallmentPlanDeletionRemovesPlanAndRecordsLocalTombstone() {
        let planID = UUID()
        let deletedAt = Date(timeIntervalSince1970: 1_800_001_500)
        let store = FakeApplyingStore()
        store.installmentPlans = [makeInstallmentPlan(id: planID)]
        let deletionStore = FakeInstallmentPlanDeletionStore()
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(action: .deleteInstallmentPlan(id: planID, deletedAt: deletedAt), entity: .installmentPlanDeletion, id: planID)
        ])

        let result = WalletSyncMasterDataApplier(
            store: store,
            localInstallmentPlanDeletionStore: deletionStore
        ).apply(plan)

        XCTAssertEqual(result.disabledCount, 1)
        XCTAssertTrue(store.installmentPlans.isEmpty)
        XCTAssertEqual(deletionStore.deletedAtByID[planID], deletedAt)
    }

    func testRemoteHighRiskDeletionRemovesCreditCardPurchaseAndRecordsLocalTombstone() {
        let purchaseID = UUID()
        let cardID = UUID()
        let deletedAt = Date(timeIntervalSince1970: 1_800_002_000)
        let store = FakeApplyingStore()
        store.creditCards = [makeCreditCard(id: cardID)]
        store.creditCardPurchases = [makeCreditCardPurchase(id: purchaseID, cardID: cardID)]
        let deletionStore = FakeHighRiskRecordDeletionStore()
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(
                action: .deleteHighRiskRecord(entity: .creditCardPurchase, id: purchaseID, deletedAt: deletedAt),
                entity: .creditCardPurchaseDeletion,
                id: purchaseID
            )
        ])

        let result = WalletSyncMasterDataApplier(
            store: store,
            localHighRiskRecordDeletionStore: deletionStore
        ).apply(plan)

        XCTAssertEqual(result.disabledCount, 1)
        XCTAssertTrue(store.creditCardPurchases.isEmpty)
        XCTAssertEqual(deletionStore.deletedAtByRecord[WalletSyncRecordEntity.creditCardPurchase.recordName(for: purchaseID)], deletedAt)
    }

    func testRemoteHighRiskDeletionRemovesCreditCardPaymentWithoutMutatingAccounts() {
        let paymentID = UUID()
        let cardID = UUID()
        let deletedAt = Date(timeIntervalSince1970: 1_800_003_000)
        let account = makeAccount(name: "Cash", balance: 5_000)
        let store = FakeApplyingStore(accounts: [account])
        store.creditCards = [makeCreditCard(id: cardID)]
        store.creditCardPayments = [makeCreditCardPayment(id: paymentID, cardID: cardID)]
        let deletionStore = FakeHighRiskRecordDeletionStore()
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(
                action: .deleteHighRiskRecord(entity: .creditCardPayment, id: paymentID, deletedAt: deletedAt),
                entity: .creditCardPaymentDeletion,
                id: paymentID
            )
        ])

        let result = WalletSyncMasterDataApplier(
            store: store,
            localHighRiskRecordDeletionStore: deletionStore
        ).apply(plan)

        XCTAssertEqual(result.disabledCount, 1)
        XCTAssertTrue(store.creditCardPayments.isEmpty)
        XCTAssertEqual(store.accounts.first?.balance, 5_000)
        XCTAssertEqual(deletionStore.deletedAtByRecord[WalletSyncRecordEntity.creditCardPayment.recordName(for: paymentID)], deletedAt)
    }

    func testRemoteHighRiskDeletionRemovesPersonDebtAndLinkedEntries() {
        let debtID = UUID()
        let entryID = UUID()
        let deletedAt = Date(timeIntervalSince1970: 1_800_004_000)
        let store = FakeApplyingStore()
        store.personDebts = [makePersonDebt(id: debtID)]
        store.personDebtEntries = [makePersonDebtEntry(id: entryID, debtID: debtID)]
        let deletionStore = FakeHighRiskRecordDeletionStore()
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(
                action: .deleteHighRiskRecord(entity: .personDebt, id: debtID, deletedAt: deletedAt),
                entity: .personDebtDeletion,
                id: debtID
            )
        ])

        let result = WalletSyncMasterDataApplier(
            store: store,
            localHighRiskRecordDeletionStore: deletionStore
        ).apply(plan)

        XCTAssertEqual(result.disabledCount, 1)
        XCTAssertTrue(store.personDebts.isEmpty)
        XCTAssertTrue(store.personDebtEntries.isEmpty)
        XCTAssertEqual(deletionStore.deletedAtByRecord[WalletSyncRecordEntity.personDebt.recordName(for: debtID)], deletedAt)
        XCTAssertNotNil(deletionStore.deletedAtByRecord[WalletSyncRecordEntity.personDebtEntry.recordName(for: entryID)])
    }

    func testRemoteHighRiskDeletionRemovesPersonDebtEntryAndRecordsLocalTombstone() {
        let debtID = UUID()
        let entryID = UUID()
        let deletedAt = Date(timeIntervalSince1970: 1_800_005_000)
        let store = FakeApplyingStore(personDebts: [makePersonDebt(id: debtID)])
        store.personDebtEntries = [makePersonDebtEntry(id: entryID, debtID: debtID)]
        let deletionStore = FakeHighRiskRecordDeletionStore()
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(
                action: .deleteHighRiskRecord(entity: .personDebtEntry, id: entryID, deletedAt: deletedAt),
                entity: .personDebtEntryDeletion,
                id: entryID
            )
        ])

        let result = WalletSyncMasterDataApplier(
            store: store,
            localHighRiskRecordDeletionStore: deletionStore
        ).apply(plan)

        XCTAssertEqual(result.disabledCount, 1)
        XCTAssertTrue(store.personDebtEntries.isEmpty)
        XCTAssertEqual(deletionStore.deletedAtByRecord[WalletSyncRecordEntity.personDebtEntry.recordName(for: entryID)], deletedAt)
    }

    func testRemoteHighRiskDeletionRemovesMonthlyBudgetItemOnly() {
        let budgetID = UUID()
        let deletedItemID = UUID()
        let survivingItemID = UUID()
        let deletedAt = Date(timeIntervalSince1970: 1_800_006_000)
        var deletedItem = WalletMonthlyBudgetItem(categoryName: "Food", plannedAmount: 500)
        deletedItem.id = deletedItemID
        var survivingItem = WalletMonthlyBudgetItem(categoryName: "Transport", plannedAmount: 300)
        survivingItem.id = survivingItemID
        var budget = WalletMonthlyBudget(year: 2026, month: 6, items: [deletedItem, survivingItem])
        budget.id = budgetID
        let store = FakeApplyingStore(monthlyBudgets: [budget])
        let deletionStore = FakeHighRiskRecordDeletionStore()
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makeItem(
                action: .deleteHighRiskRecord(entity: .monthlyBudgetItem, id: deletedItemID, deletedAt: deletedAt),
                entity: .monthlyBudgetItemDeletion,
                id: deletedItemID
            )
        ])

        let result = WalletSyncMasterDataApplier(
            store: store,
            localHighRiskRecordDeletionStore: deletionStore
        ).apply(plan)

        XCTAssertEqual(result.disabledCount, 1)
        XCTAssertEqual(store.monthlyBudgets.first?.items.count, 1)
        XCTAssertEqual(store.monthlyBudgets.first?.items.first?.id, survivingItemID)
        XCTAssertEqual(deletionStore.deletedAtByRecord[WalletSyncRecordEntity.monthlyBudgetItem.recordName(for: deletedItemID)], deletedAt)
    }

    private final class FakeApplyingStore: WalletSyncMasterDataApplyingStore {
        var accounts: [Account]
        var categories: [WalletBoard.Category]
        var walletEvents: [WalletEvent]
        var merchantMemories: [MerchantMemory] = []
        var historicalMonthlySummaries: [HistoricalMonthlySummaryEntry] = []
        var personDebts: [PersonDebt] = []
        var creditCards: [CreditCard] = []
        var installmentPlans: [InstallmentPlan] = []
        var financialEvents: [FinancialEvent] = [] {
            didSet { financialEventMutationCount += 1 }
        }
        var creditCardPurchases: [CreditCardPurchase] = []
        var creditCardPayments: [CreditCardPayment] = []
        var personDebtEntries: [PersonDebtEntry] = []
        var monthlyBudgets: [WalletMonthlyBudget] = []

        var financialEventMutationCount = 0
        var creditCardMutationCount = 0
        var personDebtMutationCount = 0
        var monthlyBudgetMutationCount = 0
        var recurringMutationCount = 0

        init(
            accounts: [Account] = [],
            categories: [WalletBoard.Category] = [],
            walletEvents: [WalletEvent] = [],
            creditCards: [CreditCard] = [],
            personDebts: [PersonDebt] = [],
            monthlyBudgets: [WalletMonthlyBudget] = []
        ) {
            self.accounts = accounts
            self.categories = categories
            self.walletEvents = walletEvents
            self.creditCards = creditCards
            self.personDebts = personDebts
            self.monthlyBudgets = monthlyBudgets
        }
    }

    private func makeFinancialEvent(id: UUID = UUID()) -> FinancialEvent {
        var event = FinancialEvent(
            type: .expense,
            status: .paid,
            title: "Groceries",
            amount: 100,
            date: Date(),
            accountName: "Cash",
            destinationAccountName: nil,
            paymentMethodName: nil,
            walletEventName: nil,
            categoryName: "Food",
            subCategoryName: "Supermarket"
        )
        event.id = id
        return event
    }

    private func makeInstallmentPlan(id: UUID = UUID()) -> InstallmentPlan {
        InstallmentPlan(
            id: id,
            purchaseName: "Valu test",
            totalAmount: 1000,
            installmentCount: 4,
            firstDueDate: Date(timeIntervalSince1970: 1_800_000_000),
            categoryName: "Debt",
            subCategoryName: "Installment"
        )
    }

    private func makeCreditCard(id: UUID = UUID()) -> CreditCard {
        CreditCard(
            id: id,
            name: "Visa",
            bankName: "Bank",
            cardNetwork: .visa,
            creditLimit: 1000,
            openingOutstandingBalance: 0,
            statementClosingDay: 25,
            paymentDueDay: 15
        )
    }

    private func makeCreditCardPurchase(id: UUID = UUID(), cardID: UUID) -> CreditCardPurchase {
        CreditCardPurchase(
            id: id,
            cardID: cardID,
            title: "Purchase",
            amount: 100,
            purchaseDate: Date(),
            categoryName: "Food",
            subCategoryName: "Groceries",
            note: nil,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private func makeCreditCardPayment(id: UUID = UUID(), cardID: UUID) -> CreditCardPayment {
        CreditCardPayment(
            id: id,
            cardID: cardID,
            fromAccountName: "Cash",
            amount: 200,
            paymentDate: Date(timeIntervalSince1970: 1_800_000_000),
            note: nil,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private func makePersonDebt(id: UUID = UUID()) -> PersonDebt {
        PersonDebt(id: id, personName: "Test Person", kind: .iOwe, originalAmount: 500)
    }

    private func makePersonDebtEntry(id: UUID = UUID(), debtID: UUID) -> PersonDebtEntry {
        PersonDebtEntry(
            id: id,
            debtID: debtID,
            entryType: .repaymentPaid,
            amount: 100,
            accountName: "Cash",
            date: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}

private final class FakeFinancialEventDeletionStore: WalletSyncLocalFinancialEventDeletionStoring {
    var deletedAtByID: [UUID: Date] = [:]

    func markFinancialEventDeletedLocally(id: UUID, deletedAt: Date) {
        deletedAtByID[id] = max(deletedAtByID[id] ?? .distantPast, deletedAt)
    }

    func isFinancialEventDeletedLocally(id: UUID) -> Bool {
        deletedAtByID[id] != nil
    }

    func locallyDeletedFinancialEventDeletedAt(id: UUID) -> Date? {
        deletedAtByID[id]
    }

    func syncableFinancialEventDeletionDTOs() -> [WalletSyncRecordDTO] {
        deletedAtByID.map { id, deletedAt in
            WalletSyncRecordMappers.dtoForFinancialEventDeletion(id: id, deletedAt: deletedAt)
        }
    }
}

private final class FakeInstallmentPlanDeletionStore: WalletSyncLocalInstallmentPlanDeletionStoring {
    var deletedAtByID: [UUID: Date] = [:]

    func markInstallmentPlanDeletedLocally(id: UUID, deletedAt: Date) {
        deletedAtByID[id] = max(deletedAtByID[id] ?? .distantPast, deletedAt)
    }

    func isInstallmentPlanDeletedLocally(id: UUID) -> Bool {
        deletedAtByID[id] != nil
    }

    func locallyDeletedInstallmentPlanDeletedAt(id: UUID) -> Date? {
        deletedAtByID[id]
    }

    func syncableInstallmentPlanDeletionDTOs() -> [WalletSyncRecordDTO] {
        deletedAtByID.map { id, deletedAt in
            WalletSyncRecordMappers.dtoForInstallmentPlanDeletion(id: id, deletedAt: deletedAt)
        }
    }
}

private final class FakeHighRiskRecordDeletionStore: WalletSyncLocalHighRiskRecordDeletionStoring {
    var deletedAtByRecord: [String: Date] = [:]

    func markHighRiskRecordDeletedLocally(entity: WalletSyncRecordEntity, id: UUID, deletedAt: Date) {
        let recordName = entity.recordName(for: id)
        deletedAtByRecord[recordName] = max(deletedAtByRecord[recordName] ?? .distantPast, deletedAt)
    }

    func isHighRiskRecordDeletedLocally(entity: WalletSyncRecordEntity, id: UUID) -> Bool {
        deletedAtByRecord[entity.recordName(for: id)] != nil
    }

    func locallyDeletedHighRiskRecordDeletedAt(entity: WalletSyncRecordEntity, id: UUID) -> Date? {
        deletedAtByRecord[entity.recordName(for: id)]
    }

    func syncableHighRiskRecordDeletionDTOs() -> [WalletSyncRecordDTO] {
        []
    }
}
