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

    init(store: WalletSyncMasterDataApplyingStore) {
        self.store = store
    }

    func apply(_ plan: WalletSyncMasterDataApplyPlanSummary) -> WalletSyncMasterDataApplyResult {
        var result = WalletSyncMasterDataApplyResult()

        for item in plan.items {
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
            case .blocked:
                result.blockedCount += 1
            case .failed:
                result.failedCount += 1
            }
        }

        return result
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

        let existingBalance = store.accounts[index].balance
        store.accounts[index].name = remote.name
        store.accounts[index].type = remote.type
        store.accounts[index].isActive = remote.isActive
        store.accounts[index].recognitionAliases = remote.recognitionAliases
        store.accounts[index].recognitionCardEndings = remote.recognitionCardEndings
        store.accounts[index].appearanceColor = remote.appearanceColor
        store.accounts[index].createdAt = remote.createdAt
        store.accounts[index].updatedAt = remote.updatedAt
        store.accounts[index].isDeleted = remote.isDeleted
        store.accounts[index].deletedAt = remote.deletedAt
        store.accounts[index].balance = existingBalance
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
}
