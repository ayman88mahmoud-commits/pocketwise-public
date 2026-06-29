import Foundation

protocol WalletSyncMasterDataApplyingStore: AnyObject {
    var accounts: [Account] { get set }
    var categories: [Category] { get set }
    var walletEvents: [WalletEvent] { get set }
    var merchantMemories: [MerchantMemory] { get set }
    var historicalMonthlySummaries: [HistoricalMonthlySummaryEntry] { get set }
    var personDebts: [PersonDebt] { get set }
    var creditCards: [CreditCard] { get set }
    var installmentPlans: [InstallmentPlan] { get set }
    var financialEvents: [FinancialEvent] { get set }
    var creditCardPurchases: [CreditCardPurchase] { get set }
    var creditCardPayments: [CreditCardPayment] { get set }
    var personDebtEntries: [PersonDebtEntry] { get set }
    var monthlyBudgets: [WalletMonthlyBudget] { get set }
}

extension WalletStore: WalletSyncMasterDataApplyingStore {}

struct WalletSyncMasterDataApplyResult: Equatable {
    var createdCount = 0
    var updatedCount = 0
    var disabledCount = 0
    var blockedCount = 0
    var failedCount = 0
    var skippedCount = 0
}

@MainActor
struct WalletSyncMasterDataApplier {
    private let store: WalletSyncMasterDataApplyingStore
    private let localFinancialEventDeletionStore: WalletSyncLocalFinancialEventDeletionStoring

    init(
        store: WalletSyncMasterDataApplyingStore,
        localFinancialEventDeletionStore: WalletSyncLocalFinancialEventDeletionStoring? = nil
    ) {
        self.store = store
        self.localFinancialEventDeletionStore = localFinancialEventDeletionStore ?? WalletSyncStateStore()
    }

    func apply(_ plan: WalletSyncMasterDataApplyPlanSummary) -> WalletSyncMasterDataApplyResult {
        var result = WalletSyncMasterDataApplyResult()
        let orderedItems = plan.items.sorted { applyPriority(for: $0.action) < applyPriority(for: $1.action) }

        for item in orderedItems {
            switch item.action {
            case .createAccount(let account):
                applyCreateAccount(account, result: &result)
            case .updateAccount(let account):
                applyUpdateAccount(account, result: &result)
            case .deleteAccountSoftOrDisableOnly(let id):
                applyDisableAccount(id: id, result: &result)
            case .createCategory(let category):
                applyCreateCategory(category, result: &result)
            case .updateCategory(let category):
                applyUpdateCategory(category, result: &result)
            case .deleteCategorySoftOrDisableOnly(let id):
                applyDisableCategory(id: id, result: &result)
            case .createWalletEvent(let walletEvent):
                applyCreateWalletEvent(walletEvent, result: &result)
            case .updateWalletEvent(let walletEvent):
                applyUpdateWalletEvent(walletEvent, result: &result)
            case .deleteWalletEventSoftOrDisableOnly(let id):
                applyDisableWalletEvent(id: id, result: &result)
            case .createMerchantMemory(let memory):
                applyCreateMerchantMemory(memory, result: &result)
            case .updateMerchantMemory(let memory):
                applyUpdateMerchantMemory(memory, result: &result)
            case .createHistoricalMonthlySummary(let entry):
                applyCreateHistoricalMonthlySummary(entry, result: &result)
            case .updateHistoricalMonthlySummary(let entry):
                applyUpdateHistoricalMonthlySummary(entry, result: &result)
            case .createPersonDebt(let debt):
                applyCreatePersonDebt(debt, result: &result)
            case .updatePersonDebt(let debt):
                applyUpdatePersonDebt(debt, result: &result)
            case .createCreditCard(let card):
                applyCreateCreditCard(card, result: &result)
            case .updateCreditCard(let card):
                applyUpdateCreditCard(card, result: &result)
            case .createInstallmentPlan(let plan):
                applyCreateInstallmentPlan(plan, result: &result)
            case .updateInstallmentPlan(let plan):
                applyUpdateInstallmentPlan(plan, result: &result)
            case .createFinancialEvent(let event):
                applyCreateFinancialEvent(event, result: &result)
            case .updateFinancialEvent(let event):
                applyUpdateFinancialEvent(event, result: &result)
            case .deleteFinancialEvent(let id, let deletedAt):
                applyDeleteFinancialEvent(id: id, deletedAt: deletedAt, result: &result)
            case .createCreditCardPurchase(let purchase):
                applyCreateCreditCardPurchase(purchase, result: &result)
            case .updateCreditCardPurchase(let purchase):
                applyUpdateCreditCardPurchase(purchase, result: &result)
            case .createCreditCardPayment(let payment):
                applyCreateCreditCardPayment(payment, result: &result)
            case .updateCreditCardPayment(let payment):
                applyUpdateCreditCardPayment(payment, result: &result)
            case .createPersonDebtEntry(let entry):
                applyCreatePersonDebtEntry(entry, result: &result)
            case .updatePersonDebtEntry(let entry):
                applyUpdatePersonDebtEntry(entry, result: &result)
            case .createWalletMonthlyBudget(let budget):
                applyCreateWalletMonthlyBudget(budget, result: &result)
            case .updateWalletMonthlyBudget(let budget):
                applyUpdateWalletMonthlyBudget(budget, result: &result)
            case .createWalletMonthlyBudgetItem(let item, let parentBudgetID):
                applyCreateWalletMonthlyBudgetItem(item, parentBudgetID: parentBudgetID, result: &result)
            case .updateWalletMonthlyBudgetItem(let item, let parentBudgetID):
                applyUpdateWalletMonthlyBudgetItem(item, parentBudgetID: parentBudgetID, result: &result)
            case .blocked:
                result.blockedCount += 1
            case .failed:
                result.failedCount += 1
            }
        }

        return result
    }

    private func applyPriority(for action: WalletSyncMasterDataApplyAction) -> Int {
        switch action {
        case .deleteFinancialEvent:
            return 0
        case .createCreditCard, .updateCreditCard,
             .createPersonDebt, .updatePersonDebt,
             .createWalletMonthlyBudget, .updateWalletMonthlyBudget:
            return 0
        case .createCreditCardPurchase, .updateCreditCardPurchase,
             .createCreditCardPayment, .updateCreditCardPayment,
             .createPersonDebtEntry, .updatePersonDebtEntry,
             .createWalletMonthlyBudgetItem, .updateWalletMonthlyBudgetItem:
            return 2
        default:
            return 1
        }
    }

    private func applyCreateAccount(_ remote: Account, result: inout WalletSyncMasterDataApplyResult) {
        guard !store.accounts.contains(where: { $0.id == remote.id }) else {
            result.skippedCount += 1
            return
        }

        store.accounts.append(remote)
        result.createdCount += 1
    }

    private func applyUpdateAccount(_ remote: Account, result: inout WalletSyncMasterDataApplyResult) {
        guard let index = store.accounts.firstIndex(where: { $0.id == remote.id }) else {
            result.skippedCount += 1
            return
        }

        store.accounts[index].name = remote.name
        store.accounts[index].type = remote.type
        store.accounts[index].balance = remote.balance
        store.accounts[index].isActive = remote.isActive
        store.accounts[index].recognitionAliases = remote.recognitionAliases
        store.accounts[index].recognitionCardEndings = remote.recognitionCardEndings
        store.accounts[index].appearanceColor = remote.appearanceColor
        store.accounts[index].createdAt = remote.createdAt
        store.accounts[index].updatedAt = remote.updatedAt
        store.accounts[index].isDeleted = remote.isDeleted
        store.accounts[index].deletedAt = remote.deletedAt
        result.updatedCount += 1
    }

    private func applyDisableAccount(id: UUID, result: inout WalletSyncMasterDataApplyResult) {
        guard let index = store.accounts.firstIndex(where: { $0.id == id }) else {
            result.skippedCount += 1
            return
        }

        store.accounts[index].isActive = false
        store.accounts[index].isDeleted = true
        store.accounts[index].deletedAt = store.accounts[index].deletedAt ?? Date()
        result.disabledCount += 1
    }

    private func applyCreateCategory(_ category: Category, result: inout WalletSyncMasterDataApplyResult) {
        guard !store.categories.contains(where: { $0.id == category.id }) else {
            result.skippedCount += 1
            return
        }

        store.categories.append(category)
        result.createdCount += 1
    }

    private func applyUpdateCategory(_ remote: Category, result: inout WalletSyncMasterDataApplyResult) {
        guard let index = store.categories.firstIndex(where: { $0.id == remote.id }) else {
            result.skippedCount += 1
            return
        }

        store.categories[index].name = remote.name
        store.categories[index].subcategories = remote.subcategories
        store.categories[index].isActive = remote.isActive
        store.categories[index].inactiveSubcategoryNames = remote.inactiveSubcategoryNames
        store.categories[index].createdAt = remote.createdAt
        store.categories[index].updatedAt = remote.updatedAt
        store.categories[index].isDeleted = remote.isDeleted
        store.categories[index].deletedAt = remote.deletedAt
        result.updatedCount += 1
    }

    private func applyDisableCategory(id: UUID, result: inout WalletSyncMasterDataApplyResult) {
        guard let index = store.categories.firstIndex(where: { $0.id == id }) else {
            result.skippedCount += 1
            return
        }

        store.categories[index].isActive = false
        store.categories[index].isDeleted = true
        store.categories[index].deletedAt = store.categories[index].deletedAt ?? Date()
        result.disabledCount += 1
    }

    private func applyCreateWalletEvent(_ walletEvent: WalletEvent, result: inout WalletSyncMasterDataApplyResult) {
        guard !store.walletEvents.contains(where: { $0.id == walletEvent.id }) else {
            result.skippedCount += 1
            return
        }

        store.walletEvents.append(walletEvent)
        result.createdCount += 1
    }

    private func applyUpdateWalletEvent(_ remote: WalletEvent, result: inout WalletSyncMasterDataApplyResult) {
        guard let index = store.walletEvents.firstIndex(where: { $0.id == remote.id }) else {
            result.skippedCount += 1
            return
        }

        store.walletEvents[index].name = remote.name
        store.walletEvents[index].categoryName = remote.categoryName
        store.walletEvents[index].subCategoryName = remote.subCategoryName
        store.walletEvents[index].defaultAccountName = remote.defaultAccountName
        store.walletEvents[index].isFavorite = remote.isFavorite
        store.walletEvents[index].isActive = remote.isActive
        store.walletEvents[index].createdAt = remote.createdAt
        store.walletEvents[index].updatedAt = remote.updatedAt
        store.walletEvents[index].isDeleted = remote.isDeleted
        store.walletEvents[index].deletedAt = remote.deletedAt
        result.updatedCount += 1
    }

    private func applyDisableWalletEvent(id: UUID, result: inout WalletSyncMasterDataApplyResult) {
        guard let index = store.walletEvents.firstIndex(where: { $0.id == id }) else {
            result.skippedCount += 1
            return
        }

        store.walletEvents[index].isActive = false
        store.walletEvents[index].isDeleted = true
        store.walletEvents[index].deletedAt = store.walletEvents[index].deletedAt ?? Date()
        result.disabledCount += 1
    }

    private func applyCreateMerchantMemory(_ memory: MerchantMemory, result: inout WalletSyncMasterDataApplyResult) {
        guard !store.merchantMemories.contains(where: { $0.id == memory.id }) else {
            result.skippedCount += 1
            return
        }

        store.merchantMemories.append(memory)
        result.createdCount += 1
    }

    private func applyUpdateMerchantMemory(_ remote: MerchantMemory, result: inout WalletSyncMasterDataApplyResult) {
        guard let index = store.merchantMemories.firstIndex(where: { $0.id == remote.id }) else {
            result.skippedCount += 1
            return
        }

        store.merchantMemories[index] = remote
        result.updatedCount += 1
    }

    private func applyCreateHistoricalMonthlySummary(_ entry: HistoricalMonthlySummaryEntry, result: inout WalletSyncMasterDataApplyResult) {
        guard !store.historicalMonthlySummaries.contains(where: { $0.id == entry.id }) else {
            result.skippedCount += 1
            return
        }

        store.historicalMonthlySummaries.append(entry)
        result.createdCount += 1
    }

    private func applyUpdateHistoricalMonthlySummary(_ remote: HistoricalMonthlySummaryEntry, result: inout WalletSyncMasterDataApplyResult) {
        guard let index = store.historicalMonthlySummaries.firstIndex(where: { $0.id == remote.id }) else {
            result.skippedCount += 1
            return
        }

        store.historicalMonthlySummaries[index] = remote
        result.updatedCount += 1
    }

    private func applyCreatePersonDebt(_ debt: PersonDebt, result: inout WalletSyncMasterDataApplyResult) {
        guard !store.personDebts.contains(where: { $0.id == debt.id }) else {
            result.skippedCount += 1
            return
        }

        store.personDebts.append(debt)
        result.createdCount += 1
    }

    private func applyUpdatePersonDebt(_ remote: PersonDebt, result: inout WalletSyncMasterDataApplyResult) {
        guard let index = store.personDebts.firstIndex(where: { $0.id == remote.id }) else {
            result.skippedCount += 1
            return
        }

        store.personDebts[index] = remote
        result.updatedCount += 1
    }

    private func applyCreateCreditCard(_ card: CreditCard, result: inout WalletSyncMasterDataApplyResult) {
        guard !store.creditCards.contains(where: { $0.id == card.id }) else {
            result.skippedCount += 1
            return
        }

        store.creditCards.append(card)
        result.createdCount += 1
    }

    private func applyUpdateCreditCard(_ remote: CreditCard, result: inout WalletSyncMasterDataApplyResult) {
        guard let index = store.creditCards.firstIndex(where: { $0.id == remote.id }) else {
            result.skippedCount += 1
            return
        }

        store.creditCards[index] = remote
        result.updatedCount += 1
    }

    private func applyCreateInstallmentPlan(_ plan: InstallmentPlan, result: inout WalletSyncMasterDataApplyResult) {
        guard !store.installmentPlans.contains(where: { $0.id == plan.id }) else {
            result.skippedCount += 1
            return
        }

        store.installmentPlans.append(plan)
        result.createdCount += 1
    }

    private func applyUpdateInstallmentPlan(_ remote: InstallmentPlan, result: inout WalletSyncMasterDataApplyResult) {
        guard let index = store.installmentPlans.firstIndex(where: { $0.id == remote.id }) else {
            result.skippedCount += 1
            return
        }

        store.installmentPlans[index] = remote
        result.updatedCount += 1
    }

    private func applyCreateFinancialEvent(_ event: FinancialEvent, result: inout WalletSyncMasterDataApplyResult) {
        guard !store.financialEvents.contains(where: { $0.id == event.id }) else {
            result.skippedCount += 1
            return
        }

        store.financialEvents.append(event)
        result.createdCount += 1
    }

    private func applyUpdateFinancialEvent(_ remote: FinancialEvent, result: inout WalletSyncMasterDataApplyResult) {
        guard let index = store.financialEvents.firstIndex(where: { $0.id == remote.id }) else {
            result.skippedCount += 1
            return
        }

        store.financialEvents[index] = remote
        result.updatedCount += 1
    }

    private func applyDeleteFinancialEvent(id: UUID, deletedAt: Date, result: inout WalletSyncMasterDataApplyResult) {
        localFinancialEventDeletionStore.markFinancialEventDeletedLocally(id: id, deletedAt: deletedAt)

        guard let index = store.financialEvents.firstIndex(where: { $0.id == id }) else {
            result.skippedCount += 1
            return
        }

        store.financialEvents.remove(at: index)
        result.disabledCount += 1
    }

    private func applyCreateCreditCardPurchase(_ purchase: CreditCardPurchase, result: inout WalletSyncMasterDataApplyResult) {
        guard store.creditCards.contains(where: { $0.id == purchase.cardID }) else {
            result.skippedCount += 1
            return
        }
        guard !store.creditCardPurchases.contains(where: { $0.id == purchase.id }) else {
            result.skippedCount += 1
            return
        }

        store.creditCardPurchases.append(purchase)
        result.createdCount += 1
    }

    private func applyUpdateCreditCardPurchase(_ remote: CreditCardPurchase, result: inout WalletSyncMasterDataApplyResult) {
        guard store.creditCards.contains(where: { $0.id == remote.cardID }) else {
            result.skippedCount += 1
            return
        }
        guard let index = store.creditCardPurchases.firstIndex(where: { $0.id == remote.id }) else {
            result.skippedCount += 1
            return
        }

        store.creditCardPurchases[index] = remote
        result.updatedCount += 1
    }

    private func applyCreateCreditCardPayment(_ payment: CreditCardPayment, result: inout WalletSyncMasterDataApplyResult) {
        guard store.creditCards.contains(where: { $0.id == payment.cardID }) else {
            result.skippedCount += 1
            return
        }
        guard !store.creditCardPayments.contains(where: { $0.id == payment.id }) else {
            result.skippedCount += 1
            return
        }

        store.creditCardPayments.append(payment)
        result.createdCount += 1
    }

    private func applyUpdateCreditCardPayment(_ remote: CreditCardPayment, result: inout WalletSyncMasterDataApplyResult) {
        guard store.creditCards.contains(where: { $0.id == remote.cardID }) else {
            result.skippedCount += 1
            return
        }
        guard let index = store.creditCardPayments.firstIndex(where: { $0.id == remote.id }) else {
            result.skippedCount += 1
            return
        }

        store.creditCardPayments[index] = remote
        result.updatedCount += 1
    }

    private func applyCreatePersonDebtEntry(_ entry: PersonDebtEntry, result: inout WalletSyncMasterDataApplyResult) {
        guard store.personDebts.contains(where: { $0.id == entry.debtID }) else {
            result.skippedCount += 1
            return
        }
        guard !store.personDebtEntries.contains(where: { $0.id == entry.id }) else {
            result.skippedCount += 1
            return
        }

        store.personDebtEntries.append(entry)
        result.createdCount += 1
    }

    private func applyUpdatePersonDebtEntry(_ remote: PersonDebtEntry, result: inout WalletSyncMasterDataApplyResult) {
        guard store.personDebts.contains(where: { $0.id == remote.debtID }) else {
            result.skippedCount += 1
            return
        }
        guard let index = store.personDebtEntries.firstIndex(where: { $0.id == remote.id }) else {
            result.skippedCount += 1
            return
        }

        store.personDebtEntries[index] = remote
        result.updatedCount += 1
    }

    private func applyCreateWalletMonthlyBudget(_ budget: WalletMonthlyBudget, result: inout WalletSyncMasterDataApplyResult) {
        guard !store.monthlyBudgets.contains(where: { $0.id == budget.id }) else {
            result.skippedCount += 1
            return
        }

        var newBudget = budget
        newBudget.items = []
        store.monthlyBudgets.append(newBudget)
        result.createdCount += 1
    }

    private func applyUpdateWalletMonthlyBudget(_ remote: WalletMonthlyBudget, result: inout WalletSyncMasterDataApplyResult) {
        guard let index = store.monthlyBudgets.firstIndex(where: { $0.id == remote.id }) else {
            result.skippedCount += 1
            return
        }

        let existingItems = store.monthlyBudgets[index].items
        store.monthlyBudgets[index].year = remote.year
        store.monthlyBudgets[index].month = remote.month
        store.monthlyBudgets[index].createdAt = remote.createdAt
        store.monthlyBudgets[index].updatedAt = remote.updatedAt
        store.monthlyBudgets[index].isDeleted = remote.isDeleted
        store.monthlyBudgets[index].deletedAt = remote.deletedAt
        store.monthlyBudgets[index].items = existingItems
        result.updatedCount += 1
    }

    private func applyCreateWalletMonthlyBudgetItem(_ item: WalletMonthlyBudgetItem, parentBudgetID: UUID, result: inout WalletSyncMasterDataApplyResult) {
        guard let budgetIndex = store.monthlyBudgets.firstIndex(where: { $0.id == parentBudgetID }) else {
            result.skippedCount += 1
            return
        }

        guard !store.monthlyBudgets[budgetIndex].items.contains(where: { $0.id == item.id }) else {
            result.skippedCount += 1
            return
        }

        store.monthlyBudgets[budgetIndex].items.append(item)
        result.createdCount += 1
    }

    private func applyUpdateWalletMonthlyBudgetItem(_ remote: WalletMonthlyBudgetItem, parentBudgetID: UUID, result: inout WalletSyncMasterDataApplyResult) {
        guard let budgetIndex = store.monthlyBudgets.firstIndex(where: { $0.id == parentBudgetID }) else {
            result.skippedCount += 1
            return
        }

        guard let itemIndex = store.monthlyBudgets[budgetIndex].items.firstIndex(where: { $0.id == remote.id }) else {
            result.skippedCount += 1
            return
        }

        store.monthlyBudgets[budgetIndex].items[itemIndex].categoryName = remote.categoryName
        store.monthlyBudgets[budgetIndex].items[itemIndex].plannedAmount = remote.plannedAmount
        store.monthlyBudgets[budgetIndex].items[itemIndex].createdAt = remote.createdAt
        store.monthlyBudgets[budgetIndex].items[itemIndex].updatedAt = remote.updatedAt
        store.monthlyBudgets[budgetIndex].items[itemIndex].isDeleted = remote.isDeleted
        store.monthlyBudgets[budgetIndex].items[itemIndex].deletedAt = remote.deletedAt
        result.updatedCount += 1
    }
}
