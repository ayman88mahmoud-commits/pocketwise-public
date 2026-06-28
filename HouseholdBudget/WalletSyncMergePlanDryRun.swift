import Foundation

protocol WalletSyncMergePlanLocalStateReading {
    func containsAccount(id: UUID) -> Bool
    func containsCategory(id: UUID) -> Bool
    func containsWalletEvent(id: UUID) -> Bool
    func containsMerchantMemory(id: UUID) -> Bool
    func containsHistoricalMonthlySummary(id: UUID) -> Bool
    func containsPersonDebt(id: UUID) -> Bool
    func containsCreditCard(id: UUID) -> Bool
    func containsInstallmentPlan(id: UUID) -> Bool
    func containsFinancialEvent(id: UUID) -> Bool
    func financialEventUpdatedAt(id: UUID) -> Date?
    func containsCreditCardPurchase(id: UUID) -> Bool
    func creditCardPurchaseUpdatedAt(id: UUID) -> Date?
    func containsCreditCardPayment(id: UUID) -> Bool
    func creditCardPaymentUpdatedAt(id: UUID) -> Date?
    func containsPersonDebtEntry(id: UUID) -> Bool
    func personDebtEntryUpdatedAt(id: UUID) -> Date?
    func containsMonthlyBudget(id: UUID) -> Bool
    func monthlyBudgetUpdatedAt(id: UUID) -> Date?
    func containsMonthlyBudgetItem(id: UUID, inBudget parentID: UUID) -> Bool
    func monthlyBudgetItemUpdatedAt(id: UUID, inBudget parentID: UUID) -> Date?
}

extension WalletSyncMergePlanLocalStateReading {
    func containsMerchantMemory(id: UUID) -> Bool { false }
    func containsHistoricalMonthlySummary(id: UUID) -> Bool { false }
    func containsPersonDebt(id: UUID) -> Bool { false }
    func containsCreditCard(id: UUID) -> Bool { false }
    func containsInstallmentPlan(id: UUID) -> Bool { false }
    func containsFinancialEvent(id: UUID) -> Bool { false }
    func financialEventUpdatedAt(id: UUID) -> Date? { nil }
    func containsCreditCardPurchase(id: UUID) -> Bool { false }
    func creditCardPurchaseUpdatedAt(id: UUID) -> Date? { nil }
    func containsCreditCardPayment(id: UUID) -> Bool { false }
    func creditCardPaymentUpdatedAt(id: UUID) -> Date? { nil }
    func containsPersonDebtEntry(id: UUID) -> Bool { false }
    func personDebtEntryUpdatedAt(id: UUID) -> Date? { nil }
    func containsMonthlyBudget(id: UUID) -> Bool { false }
    func monthlyBudgetUpdatedAt(id: UUID) -> Date? { nil }
    func containsMonthlyBudgetItem(id: UUID, inBudget parentID: UUID) -> Bool { false }
    func monthlyBudgetItemUpdatedAt(id: UUID, inBudget parentID: UUID) -> Date? { nil }
}

extension WalletStore: WalletSyncMergePlanLocalStateReading {
    func containsAccount(id: UUID) -> Bool {
        accounts.contains { $0.id == id }
    }

    func containsCategory(id: UUID) -> Bool {
        categories.contains { $0.id == id }
    }

    func containsWalletEvent(id: UUID) -> Bool {
        walletEvents.contains { $0.id == id }
    }

    func containsMerchantMemory(id: UUID) -> Bool {
        merchantMemories.contains { $0.id == id }
    }

    func containsHistoricalMonthlySummary(id: UUID) -> Bool {
        historicalMonthlySummaries.contains { $0.id == id }
    }

    func containsPersonDebt(id: UUID) -> Bool {
        personDebts.contains { $0.id == id }
    }

    func containsCreditCard(id: UUID) -> Bool {
        creditCards.contains { $0.id == id }
    }

    func containsInstallmentPlan(id: UUID) -> Bool {
        installmentPlans.contains { $0.id == id }
    }

    func containsFinancialEvent(id: UUID) -> Bool {
        financialEvents.contains { $0.id == id }
    }

    func financialEventUpdatedAt(id: UUID) -> Date? {
        financialEvents.first { $0.id == id }?.updatedAt
    }

    func containsCreditCardPurchase(id: UUID) -> Bool {
        creditCardPurchases.contains { $0.id == id }
    }

    func creditCardPurchaseUpdatedAt(id: UUID) -> Date? {
        creditCardPurchases.first { $0.id == id }?.updatedAt
    }

    func containsCreditCardPayment(id: UUID) -> Bool {
        creditCardPayments.contains { $0.id == id }
    }

    func creditCardPaymentUpdatedAt(id: UUID) -> Date? {
        creditCardPayments.first { $0.id == id }?.updatedAt
    }

    func containsPersonDebtEntry(id: UUID) -> Bool {
        personDebtEntries.contains { $0.id == id }
    }

    func personDebtEntryUpdatedAt(id: UUID) -> Date? {
        personDebtEntries.first { $0.id == id }?.updatedAt
    }

    func containsMonthlyBudget(id: UUID) -> Bool {
        monthlyBudgets.contains { $0.id == id }
    }

    func monthlyBudgetUpdatedAt(id: UUID) -> Date? {
        monthlyBudgets.first { $0.id == id }?.updatedAt
    }

    func containsMonthlyBudgetItem(id: UUID, inBudget parentID: UUID) -> Bool {
        guard let budget = monthlyBudgets.first(where: { $0.id == parentID }) else { return false }
        return budget.items.contains { $0.id == id }
    }

    func monthlyBudgetItemUpdatedAt(id: UUID, inBudget parentID: UUID) -> Date? {
        guard let budget = monthlyBudgets.first(where: { $0.id == parentID }) else { return nil }
        return budget.items.first { $0.id == id }?.updatedAt
    }
}

enum WalletSyncMergePlanAction: Equatable {
    case wouldCreate
    case wouldUpdate
    case wouldDelete
    case wouldIgnoreNoChange
    case blocked
    case failed
}

enum WalletSyncMergePlanBlockReason: Equatable {
    case monthlyBudgetItemNoParent
    case householdSettingsNoModel
    case pendingApplyImplementation
    case unsupportedEntity
}

struct WalletSyncMergePlanItem: Equatable {
    var recordName: String
    var entity: WalletSyncRecordEntity?
    var id: UUID?
    var action: WalletSyncMergePlanAction
    var blockReason: WalletSyncMergePlanBlockReason?
}

struct WalletSyncMergePlanDryRunSummary: Equatable {
    var items: [WalletSyncMergePlanItem]

    var wouldCreateCount: Int { count(.wouldCreate) }
    var wouldUpdateCount: Int { count(.wouldUpdate) }
    var wouldDeleteCount: Int { count(.wouldDelete) }
    var wouldIgnoreCount: Int { count(.wouldIgnoreNoChange) }
    var blockedCount: Int { count(.blocked) }
    var failedCount: Int { count(.failed) }

    func sampleRecordNames(limit: Int = 10) -> [String] {
        Array(items.map(\.recordName).prefix(limit))
    }

    private func count(_ action: WalletSyncMergePlanAction) -> Int {
        items.filter { $0.action == action }.count
    }
}

struct WalletSyncMergePlanDryRun {
    private let localState: WalletSyncMergePlanLocalStateReading

    init(localState: WalletSyncMergePlanLocalStateReading) {
        self.localState = localState
    }

    func makePlan(for inboxItems: [WalletSyncInboxItem]) -> WalletSyncMergePlanDryRunSummary {
        let planItems = inboxItems.map(planItem)
        return WalletSyncMergePlanDryRunSummary(items: planItems)
    }

    private func planItem(for item: WalletSyncInboxItem) -> WalletSyncMergePlanItem {
        switch item.status {
        case .decodeFailed:
            return makeItem(from: item, action: .failed)
        case .unsupportedEntity:
            return makeItem(from: item, action: .blocked, blockReason: .unsupportedEntity)
        case .blockedMonthlyBudgetItemNoParent:
            return makeItem(from: item, action: .blocked, blockReason: .monthlyBudgetItemNoParent)
        case .blockedHouseholdSettingsNoModel:
            return makeItem(from: item, action: .blocked, blockReason: .householdSettingsNoModel)
        case .validChangedRecord, .validDeletedTombstone, .deletedRecordNameOnly:
            break
        }

        guard let entity = item.entity, let id = item.id else {
            return makeItem(from: item, action: .blocked, blockReason: .unsupportedEntity)
        }

        switch entity {
        case .account:
            return planMasterDataItem(item, exists: localState.containsAccount(id: id))
        case .category:
            return planMasterDataItem(item, exists: localState.containsCategory(id: id))
        case .walletEvent:
            return planMasterDataItem(item, exists: localState.containsWalletEvent(id: id))
        case .merchantMemory:
            return planMasterDataItem(item, exists: localState.containsMerchantMemory(id: id))
        case .historicalMonthlySummary:
            return planMasterDataItem(item, exists: localState.containsHistoricalMonthlySummary(id: id))
        case .personDebt:
            return planMasterDataItem(item, exists: localState.containsPersonDebt(id: id))
        case .creditCard:
            return planMasterDataItem(item, exists: localState.containsCreditCard(id: id))
        case .installmentPlan:
            return planMasterDataItem(item, exists: localState.containsInstallmentPlan(id: id))
        case .financialEvent:
            return planMasterDataItem(item, exists: localState.containsFinancialEvent(id: id))
        case .creditCardPurchase:
            return planMasterDataItem(item, exists: localState.containsCreditCardPurchase(id: id))
        case .creditCardPayment:
            return planMasterDataItem(item, exists: localState.containsCreditCardPayment(id: id))
        case .personDebtEntry:
            return planMasterDataItem(item, exists: localState.containsPersonDebtEntry(id: id))
        case .monthlyBudget:
            return planMasterDataItem(item, exists: localState.containsMonthlyBudget(id: id))
        case .monthlyBudgetItem:
            guard let parentBudgetID = item.parentBudgetID else {
                return makeItem(from: item, action: .blocked, blockReason: .monthlyBudgetItemNoParent)
            }
            guard localState.containsMonthlyBudget(id: parentBudgetID) else {
                return makeItem(from: item, action: .blocked, blockReason: .monthlyBudgetItemNoParent)
            }
            return planMasterDataItem(item, exists: localState.containsMonthlyBudgetItem(id: id, inBudget: parentBudgetID))
        case .householdSettings:
            return makeItem(from: item, action: .blocked, blockReason: .householdSettingsNoModel)
        default:
            return makeItem(from: item, action: .blocked, blockReason: .pendingApplyImplementation)
        }
    }

    private func planMasterDataItem(
        _ item: WalletSyncInboxItem,
        exists: Bool
    ) -> WalletSyncMergePlanItem {
        if item.isDeleted {
            return makeItem(from: item, action: exists ? .wouldDelete : .wouldIgnoreNoChange)
        }

        return makeItem(from: item, action: exists ? .wouldUpdate : .wouldCreate)
    }

    private func makeItem(
        from item: WalletSyncInboxItem,
        action: WalletSyncMergePlanAction,
        blockReason: WalletSyncMergePlanBlockReason? = nil
    ) -> WalletSyncMergePlanItem {
        WalletSyncMergePlanItem(
            recordName: item.recordName,
            entity: item.entity,
            id: item.id,
            action: action,
            blockReason: blockReason
        )
    }
}
