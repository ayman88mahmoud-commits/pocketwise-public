import Foundation
import CloudKit

#if DEBUG
enum WalletSyncDebugSyntheticMasterDataChangeFactory {
    static let debugCategoryID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
    static let debugCategoryName = "DEBUG_SYNC_TEST_CATEGORY"
    static let debugSubcategoryName = "DEBUG_SYNC_TEST_SUBCATEGORY"

    static var debugCategoryRecordName: String {
        WalletSyncRecordEntity.category.recordName(for: debugCategoryID)
    }

    static func debugCategoryDTO(updatedAt: Date = Date()) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: debugCategoryRecordName,
            entity: .category,
            id: debugCategoryID,
            updatedAt: updatedAt,
            fields: [
                "name": .string(debugCategoryName),
                "subcategories": .stringArray([debugSubcategoryName]),
                "isActive": .bool(false),
                "inactiveSubcategoryNames": .stringArray([]),
                "createdAt": .date(updatedAt)
            ]
        )
    }

    static func debugCategoryRecord(updatedAt: Date = Date()) -> CKRecord {
        WalletSyncCKRecordAdapter.ckRecord(from: debugCategoryDTO(updatedAt: updatedAt))
    }
}
#endif

enum WalletSyncMasterDataApplyAction: Equatable {
    case createAccount(Account)
    case updateAccount(Account)
    case deleteAccountSoftOrDisableOnly(id: UUID)
    case createCategory(Category)
    case updateCategory(Category)
    case deleteCategorySoftOrDisableOnly(id: UUID)
    case createWalletEvent(WalletEvent)
    case updateWalletEvent(WalletEvent)
    case deleteWalletEventSoftOrDisableOnly(id: UUID)
    case createMerchantMemory(MerchantMemory)
    case updateMerchantMemory(MerchantMemory)
    case createHistoricalMonthlySummary(HistoricalMonthlySummaryEntry)
    case updateHistoricalMonthlySummary(HistoricalMonthlySummaryEntry)
    case createPersonDebt(PersonDebt)
    case updatePersonDebt(PersonDebt)
    case createCreditCard(CreditCard)
    case updateCreditCard(CreditCard)
    case createInstallmentPlan(InstallmentPlan)
    case updateInstallmentPlan(InstallmentPlan)
    case createFinancialEvent(FinancialEvent)
    case updateFinancialEvent(FinancialEvent)
    case createCreditCardPurchase(CreditCardPurchase)
    case updateCreditCardPurchase(CreditCardPurchase)
    case createCreditCardPayment(CreditCardPayment)
    case updateCreditCardPayment(CreditCardPayment)
    case createPersonDebtEntry(PersonDebtEntry)
    case updatePersonDebtEntry(PersonDebtEntry)
    case createWalletMonthlyBudget(WalletMonthlyBudget)
    case updateWalletMonthlyBudget(WalletMonthlyBudget)
    case createWalletMonthlyBudgetItem(WalletMonthlyBudgetItem, parentBudgetID: UUID)
    case updateWalletMonthlyBudgetItem(WalletMonthlyBudgetItem, parentBudgetID: UUID)
    case blocked(reason: WalletSyncMasterDataApplyBlockReason)
    case failed
}

enum WalletSyncMasterDataApplyBlockReason: Equatable {
    case nonMasterDataEntity
    case unsafeFinancialApply
    case directApplyNotValidated
    case monthlyBudgetItemNoParent
    case householdSettingsNoModel
    case unsupportedEntity
    case missingRequiredField
    case invalidFieldValue
    case localFinancialEventNewer
    case ambiguousFinancialEventTimestamp
    case missingParentRecord
    case localChildRecordNewer
    case ambiguousChildRecordTimestamp
}

struct WalletSyncMasterDataApplyPlanItem: Equatable {
    var recordName: String
    var entity: WalletSyncRecordEntity?
    var id: UUID?
    var action: WalletSyncMasterDataApplyAction
}

struct WalletSyncMasterDataApplyPlanSummary: Equatable {
    var items: [WalletSyncMasterDataApplyPlanItem]

    var plannedCreateCount: Int {
        items.filter {
            if case .createAccount = $0.action { return true }
            if case .createCategory = $0.action { return true }
            if case .createWalletEvent = $0.action { return true }
            if case .createMerchantMemory = $0.action { return true }
            if case .createHistoricalMonthlySummary = $0.action { return true }
            if case .createPersonDebt = $0.action { return true }
            if case .createCreditCard = $0.action { return true }
            if case .createInstallmentPlan = $0.action { return true }
            if case .createFinancialEvent = $0.action { return true }
            if case .createCreditCardPurchase = $0.action { return true }
            if case .createCreditCardPayment = $0.action { return true }
            if case .createPersonDebtEntry = $0.action { return true }
            if case .createWalletMonthlyBudget = $0.action { return true }
            if case .createWalletMonthlyBudgetItem = $0.action { return true }
            return false
        }.count
    }

    var plannedUpdateCount: Int {
        items.filter {
            if case .updateAccount = $0.action { return true }
            if case .updateCategory = $0.action { return true }
            if case .updateWalletEvent = $0.action { return true }
            if case .updateMerchantMemory = $0.action { return true }
            if case .updateHistoricalMonthlySummary = $0.action { return true }
            if case .updatePersonDebt = $0.action { return true }
            if case .updateCreditCard = $0.action { return true }
            if case .updateInstallmentPlan = $0.action { return true }
            if case .updateFinancialEvent = $0.action { return true }
            if case .updateCreditCardPurchase = $0.action { return true }
            if case .updateCreditCardPayment = $0.action { return true }
            if case .updatePersonDebtEntry = $0.action { return true }
            if case .updateWalletMonthlyBudget = $0.action { return true }
            if case .updateWalletMonthlyBudgetItem = $0.action { return true }
            return false
        }.count
    }

    var plannedDisableCount: Int {
        items.filter {
            if case .deleteAccountSoftOrDisableOnly = $0.action { return true }
            if case .deleteCategorySoftOrDisableOnly = $0.action { return true }
            if case .deleteWalletEventSoftOrDisableOnly = $0.action { return true }
            return false
        }.count
    }

    var blockedCount: Int {
        items.filter {
            if case .blocked = $0.action { return true }
            return false
        }.count
    }

    var failedCount: Int {
        items.filter { $0.action == .failed }.count
    }

    func sampleRecordNames(limit: Int = 10) -> [String] {
        Array(items.map(\.recordName).prefix(limit))
    }
}

struct WalletSyncMasterDataApplyPlanBuilder {
    private let localState: WalletSyncMergePlanLocalStateReading

    init(localState: WalletSyncMergePlanLocalStateReading) {
        self.localState = localState
    }

    func makePlan(
        changedRecords: [CKRecord],
        deletedRecordNames: [String]
    ) -> WalletSyncMasterDataApplyPlanSummary {
        let changedItems = changedRecords.map(planChangedRecord)
        let deletedItems = deletedRecordNames.map(planDeletedRecordName)
        return WalletSyncMasterDataApplyPlanSummary(items: changedItems + deletedItems)
    }

    private func planChangedRecord(_ record: CKRecord) -> WalletSyncMasterDataApplyPlanItem {
        let recordName = record.recordID.recordName

        do {
            let dto = try WalletSyncCKRecordAdapter.dto(from: record)
            return planDTO(dto)
        } catch {
            return WalletSyncMasterDataApplyPlanItem(
                recordName: recordName,
                entity: nil,
                id: nil,
                action: .failed
            )
        }
    }

    private func planDeletedRecordName(_ recordName: String) -> WalletSyncMasterDataApplyPlanItem {
        guard let identity = identityFromRecordName(recordName) else {
            return WalletSyncMasterDataApplyPlanItem(
                recordName: recordName,
                entity: nil,
                id: nil,
                action: .blocked(reason: .unsupportedEntity)
            )
        }

        switch identity.entity {
        case .account:
            return WalletSyncMasterDataApplyPlanItem(
                recordName: recordName,
                entity: .account,
                id: identity.id,
                action: .deleteAccountSoftOrDisableOnly(id: identity.id)
            )
        case .category:
            return WalletSyncMasterDataApplyPlanItem(
                recordName: recordName,
                entity: .category,
                id: identity.id,
                action: .deleteCategorySoftOrDisableOnly(id: identity.id)
            )
        case .walletEvent:
            return WalletSyncMasterDataApplyPlanItem(
                recordName: recordName,
                entity: .walletEvent,
                id: identity.id,
                action: .deleteWalletEventSoftOrDisableOnly(id: identity.id)
            )
        default:
            return blockedItem(recordName: recordName, entity: identity.entity, id: identity.id)
        }
    }

    private func planDTO(_ dto: WalletSyncRecordDTO) -> WalletSyncMasterDataApplyPlanItem {
        if dto.isDeleted {
            return planDeletedRecordName(dto.recordName)
        }

        switch dto.entity {
        case .account:
            guard let account = account(from: dto) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingRequiredField)
            }
            return WalletSyncMasterDataApplyPlanItem(
                recordName: dto.recordName,
                entity: .account,
                id: dto.id,
                action: localState.containsAccount(id: dto.id) ? .updateAccount(account) : .createAccount(account)
            )
        case .category:
            guard let category = category(from: dto) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingRequiredField)
            }
            return WalletSyncMasterDataApplyPlanItem(
                recordName: dto.recordName,
                entity: .category,
                id: dto.id,
                action: localState.containsCategory(id: dto.id) ? .updateCategory(category) : .createCategory(category)
            )
        case .walletEvent:
            guard let walletEvent = walletEvent(from: dto) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingRequiredField)
            }
            return WalletSyncMasterDataApplyPlanItem(
                recordName: dto.recordName,
                entity: .walletEvent,
                id: dto.id,
                action: localState.containsWalletEvent(id: dto.id) ? .updateWalletEvent(walletEvent) : .createWalletEvent(walletEvent)
            )
        case .merchantMemory:
            guard let memory = merchantMemory(from: dto) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingRequiredField)
            }
            return WalletSyncMasterDataApplyPlanItem(
                recordName: dto.recordName,
                entity: .merchantMemory,
                id: dto.id,
                action: localState.containsMerchantMemory(id: dto.id) ? .updateMerchantMemory(memory) : .createMerchantMemory(memory)
            )
        case .historicalMonthlySummary:
            guard let entry = historicalMonthlySummary(from: dto) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingRequiredField)
            }
            return WalletSyncMasterDataApplyPlanItem(
                recordName: dto.recordName,
                entity: .historicalMonthlySummary,
                id: dto.id,
                action: localState.containsHistoricalMonthlySummary(id: dto.id) ? .updateHistoricalMonthlySummary(entry) : .createHistoricalMonthlySummary(entry)
            )
        case .personDebt:
            guard let debt = personDebt(from: dto) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingRequiredField)
            }
            return WalletSyncMasterDataApplyPlanItem(
                recordName: dto.recordName,
                entity: .personDebt,
                id: dto.id,
                action: localState.containsPersonDebt(id: dto.id) ? .updatePersonDebt(debt) : .createPersonDebt(debt)
            )
        case .creditCard:
            guard let card = creditCard(from: dto) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingRequiredField)
            }
            return WalletSyncMasterDataApplyPlanItem(
                recordName: dto.recordName,
                entity: .creditCard,
                id: dto.id,
                action: localState.containsCreditCard(id: dto.id) ? .updateCreditCard(card) : .createCreditCard(card)
            )
        case .installmentPlan:
            guard let plan = installmentPlan(from: dto) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingRequiredField)
            }
            return WalletSyncMasterDataApplyPlanItem(
                recordName: dto.recordName,
                entity: .installmentPlan,
                id: dto.id,
                action: localState.containsInstallmentPlan(id: dto.id) ? .updateInstallmentPlan(plan) : .createInstallmentPlan(plan)
            )
        case .financialEvent:
            guard let event = financialEvent(from: dto) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingRequiredField)
            }
            return planFinancialEvent(dto: dto, event: event)
        case .creditCardPurchase:
            guard let purchase = creditCardPurchase(from: dto) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingRequiredField)
            }
            return planCreditCardPurchase(dto: dto, purchase: purchase)
        case .creditCardPayment:
            guard let payment = creditCardPayment(from: dto) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingRequiredField)
            }
            return planCreditCardPayment(dto: dto, payment: payment)
        case .personDebtEntry:
            guard let entry = personDebtEntry(from: dto) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingRequiredField)
            }
            return planPersonDebtEntry(dto: dto, entry: entry)
        case .monthlyBudget:
            guard let budget = walletMonthlyBudget(from: dto) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingRequiredField)
            }
            return WalletSyncMasterDataApplyPlanItem(
                recordName: dto.recordName,
                entity: .monthlyBudget,
                id: dto.id,
                action: localState.containsMonthlyBudget(id: dto.id) ? .updateWalletMonthlyBudget(budget) : .createWalletMonthlyBudget(budget)
            )
        case .monthlyBudgetItem:
            guard let parentBudgetID = uuidField("parentBudgetID", in: dto) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .monthlyBudgetItemNoParent)
            }
            guard localState.containsMonthlyBudget(id: parentBudgetID) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingParentRecord)
            }
            guard let item = walletMonthlyBudgetItem(from: dto) else {
                return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingRequiredField)
            }
            return planChildRecord(
                dto: dto,
                localUpdatedAt: localState.monthlyBudgetItemUpdatedAt(id: dto.id, inBudget: parentBudgetID),
                createAction: .createWalletMonthlyBudgetItem(item, parentBudgetID: parentBudgetID),
                updateAction: .updateWalletMonthlyBudgetItem(item, parentBudgetID: parentBudgetID)
            )
        default:
            return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id)
        }
    }

    private func planFinancialEvent(
        dto: WalletSyncRecordDTO,
        event: FinancialEvent
    ) -> WalletSyncMasterDataApplyPlanItem {
        guard let remoteUpdatedAt = dto.updatedAt else {
            return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .ambiguousFinancialEventTimestamp)
        }

        guard let localUpdatedAt = localState.financialEventUpdatedAt(id: dto.id) else {
            return WalletSyncMasterDataApplyPlanItem(
                recordName: dto.recordName,
                entity: .financialEvent,
                id: dto.id,
                action: .createFinancialEvent(event)
            )
        }

        if localUpdatedAt > remoteUpdatedAt.addingTimeInterval(1) {
            return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .localFinancialEventNewer)
        }

        guard remoteUpdatedAt > localUpdatedAt.addingTimeInterval(1) else {
            return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .ambiguousFinancialEventTimestamp)
        }

        return WalletSyncMasterDataApplyPlanItem(
            recordName: dto.recordName,
            entity: .financialEvent,
            id: dto.id,
            action: .updateFinancialEvent(event)
        )
    }

    private func planCreditCardPurchase(
        dto: WalletSyncRecordDTO,
        purchase: CreditCardPurchase
    ) -> WalletSyncMasterDataApplyPlanItem {
        guard localState.containsCreditCard(id: purchase.cardID) else {
            return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingParentRecord)
        }

        return planChildRecord(
            dto: dto,
            localUpdatedAt: localState.creditCardPurchaseUpdatedAt(id: dto.id),
            createAction: .createCreditCardPurchase(purchase),
            updateAction: .updateCreditCardPurchase(purchase)
        )
    }

    private func planCreditCardPayment(
        dto: WalletSyncRecordDTO,
        payment: CreditCardPayment
    ) -> WalletSyncMasterDataApplyPlanItem {
        guard localState.containsCreditCard(id: payment.cardID) else {
            return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingParentRecord)
        }

        return planChildRecord(
            dto: dto,
            localUpdatedAt: localState.creditCardPaymentUpdatedAt(id: dto.id),
            createAction: .createCreditCardPayment(payment),
            updateAction: .updateCreditCardPayment(payment)
        )
    }

    private func planPersonDebtEntry(
        dto: WalletSyncRecordDTO,
        entry: PersonDebtEntry
    ) -> WalletSyncMasterDataApplyPlanItem {
        guard localState.containsPersonDebt(id: entry.debtID) else {
            return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .missingParentRecord)
        }

        return planChildRecord(
            dto: dto,
            localUpdatedAt: localState.personDebtEntryUpdatedAt(id: dto.id),
            createAction: .createPersonDebtEntry(entry),
            updateAction: .updatePersonDebtEntry(entry)
        )
    }

    private func planChildRecord(
        dto: WalletSyncRecordDTO,
        localUpdatedAt: Date?,
        createAction: WalletSyncMasterDataApplyAction,
        updateAction: WalletSyncMasterDataApplyAction
    ) -> WalletSyncMasterDataApplyPlanItem {
        guard let remoteUpdatedAt = dto.updatedAt else {
            return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .ambiguousChildRecordTimestamp)
        }

        guard let localUpdatedAt else {
            return WalletSyncMasterDataApplyPlanItem(
                recordName: dto.recordName,
                entity: dto.entity,
                id: dto.id,
                action: createAction
            )
        }

        if localUpdatedAt > remoteUpdatedAt.addingTimeInterval(1) {
            return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .localChildRecordNewer)
        }

        guard remoteUpdatedAt > localUpdatedAt.addingTimeInterval(1) else {
            return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id, reason: .ambiguousChildRecordTimestamp)
        }

        return WalletSyncMasterDataApplyPlanItem(
            recordName: dto.recordName,
            entity: dto.entity,
            id: dto.id,
            action: updateAction
        )
    }

    private func account(from dto: WalletSyncRecordDTO) -> Account? {
        guard let name = stringField("name", in: dto),
              let typeRawValue = stringField("type", in: dto),
              let type = AccountType(rawValue: typeRawValue) else {
            return nil
        }

        return Account(
            id: dto.id,
            name: name,
            balance: 0,
            type: type,
            isActive: boolField("isActive", in: dto) ?? true,
            recognitionAliases: stringArrayField("recognitionAliases", in: dto) ?? [],
            recognitionCardEndings: stringArrayField("recognitionCardEndings", in: dto) ?? [],
            appearanceColor: providerAppearanceColorField("appearanceColor", in: dto),
            createdAt: dateField("createdAt", in: dto) ?? dto.updatedAt ?? Date(),
            updatedAt: dto.updatedAt ?? Date(),
            isDeleted: false,
            deletedAt: nil
        )
    }

    private func category(from dto: WalletSyncRecordDTO) -> Category? {
        guard let name = stringField("name", in: dto) else {
            return nil
        }

        return Category(
            id: dto.id,
            name: name,
            subcategories: stringArrayField("subcategories", in: dto) ?? [],
            isActive: boolField("isActive", in: dto) ?? true,
            inactiveSubcategoryNames: stringArrayField("inactiveSubcategoryNames", in: dto) ?? [],
            createdAt: dateField("createdAt", in: dto) ?? dto.updatedAt ?? Date(),
            updatedAt: dto.updatedAt ?? Date(),
            isDeleted: false,
            deletedAt: nil
        )
    }

    private func walletEvent(from dto: WalletSyncRecordDTO) -> WalletEvent? {
        guard let name = stringField("name", in: dto),
              let categoryName = stringField("categoryName", in: dto),
              let subCategoryName = stringField("subCategoryName", in: dto) else {
            return nil
        }

        var walletEvent = WalletEvent(
            name: name,
            categoryName: categoryName,
            subCategoryName: subCategoryName,
            defaultAccountName: nullableStringField("defaultAccountName", in: dto),
            isFavorite: boolField("isFavorite", in: dto) ?? false
        )
        walletEvent.id = dto.id
        walletEvent.isActive = boolField("isActive", in: dto) ?? true
        walletEvent.createdAt = dateField("createdAt", in: dto) ?? dto.updatedAt ?? Date()
        walletEvent.updatedAt = dto.updatedAt ?? Date()
        walletEvent.isDeleted = false
        walletEvent.deletedAt = nil
        return walletEvent
    }

    private func merchantMemory(from dto: WalletSyncRecordDTO) -> MerchantMemory? {
        guard let merchantName = stringField("merchantName", in: dto),
              let defaultCategoryName = stringField("defaultCategoryName", in: dto),
              let defaultSubCategoryName = stringField("defaultSubCategoryName", in: dto),
              let defaultTypeRawValue = stringField("defaultType", in: dto),
              let defaultType = FinancialEventType(rawValue: defaultTypeRawValue) else {
            return nil
        }

        var memory = MerchantMemory(
            merchantName: merchantName,
            defaultCategoryName: defaultCategoryName,
            defaultSubCategoryName: defaultSubCategoryName,
            defaultAccountName: nullableStringField("defaultAccountName", in: dto),
            usageCount: intField("usageCount", in: dto) ?? 0
        )
        memory.id = dto.id
        memory.aliases = stringArrayField("aliases", in: dto) ?? []
        memory.defaultType = defaultType
        memory.lastUsedAt = nullableDateField("lastUsedAt", in: dto)
        memory.isActive = boolField("isActive", in: dto) ?? true
        memory.createdAt = dateField("createdAt", in: dto) ?? dto.updatedAt ?? Date()
        memory.updatedAt = dto.updatedAt ?? Date()
        memory.isDeleted = false
        memory.deletedAt = nil
        return memory
    }

    private func historicalMonthlySummary(from dto: WalletSyncRecordDTO) -> HistoricalMonthlySummaryEntry? {
        guard let year = intField("year", in: dto),
              let month = intField("month", in: dto),
              let categoryName = stringField("categoryName", in: dto),
              let subCategoryName = stringField("subCategoryName", in: dto),
              let amount = doubleField("amount", in: dto) else {
            return nil
        }

        return HistoricalMonthlySummaryEntry(
            id: dto.id,
            year: year,
            month: month,
            categoryName: categoryName,
            subCategoryName: subCategoryName,
            amount: amount,
            note: nullableStringField("note", in: dto),
            createdAt: dateField("createdAt", in: dto) ?? dto.updatedAt ?? Date(),
            updatedAt: dto.updatedAt ?? Date(),
            isDeleted: false,
            deletedAt: nil
        )
    }

    private func personDebt(from dto: WalletSyncRecordDTO) -> PersonDebt? {
        guard let personName = stringField("personName", in: dto),
              let kindRawValue = stringField("kind", in: dto),
              let kind = PersonDebtKind(rawValue: kindRawValue),
              let originalAmount = doubleField("originalAmount", in: dto) else {
            return nil
        }

        var debt = PersonDebt(
            personName: personName,
            kind: kind,
            originalAmount: originalAmount
        )
        debt.id = dto.id
        debt.note = nullableStringField("note", in: dto)
        debt.createdAt = dateField("createdAt", in: dto) ?? dto.updatedAt ?? Date()
        debt.updatedAt = dto.updatedAt ?? Date()
        debt.dueDate = nullableDateField("dueDate", in: dto)
        debt.isArchived = boolField("isArchived", in: dto) ?? false
        debt.isDeleted = false
        debt.deletedAt = nil
        return debt
    }

    private func creditCard(from dto: WalletSyncRecordDTO) -> CreditCard? {
        guard let name = stringField("name", in: dto),
              let bankName = stringField("bankName", in: dto),
              let cardNetworkRawValue = stringField("cardNetwork", in: dto),
              let cardNetwork = CreditCardNetwork(rawValue: cardNetworkRawValue),
              let creditLimit = doubleField("creditLimit", in: dto),
              let openingOutstandingBalance = doubleField("openingOutstandingBalance", in: dto),
              let statementClosingDay = intField("statementClosingDay", in: dto),
              let paymentDueDay = intField("paymentDueDay", in: dto) else {
            return nil
        }

        return CreditCard(
            id: dto.id,
            name: name,
            bankName: bankName,
            lastFourDigits: nullableStringField("lastFourDigits", in: dto),
            cardNetwork: cardNetwork,
            appearanceColor: providerAppearanceColorField("appearanceColor", in: dto),
            creditLimit: creditLimit,
            openingOutstandingBalance: openingOutstandingBalance,
            openingOutstandingDate: nullableDateField("openingOutstandingDate", in: dto),
            statementClosingDay: statementClosingDay,
            paymentDueDay: paymentDueDay,
            defaultPaymentAccountName: nullableStringField("defaultPaymentAccountName", in: dto),
            isActive: boolField("isActive", in: dto) ?? true,
            createdAt: dateField("createdAt", in: dto) ?? dto.updatedAt ?? Date(),
            updatedAt: dto.updatedAt ?? Date(),
            note: nullableStringField("note", in: dto),
            isDeleted: false,
            deletedAt: nil
        )
    }

    private func installmentPlan(from dto: WalletSyncRecordDTO) -> InstallmentPlan? {
        guard let purchaseName = stringField("purchaseName", in: dto),
              let totalAmount = doubleField("totalAmount", in: dto),
              let installmentCount = intField("installmentCount", in: dto),
              let firstDueDate = dateField("firstDueDate", in: dto),
              let categoryName = stringField("categoryName", in: dto),
              let subCategoryName = stringField("subCategoryName", in: dto),
              let paymentMethodName = stringField("paymentMethodName", in: dto) else {
            return nil
        }

        return InstallmentPlan(
            id: dto.id,
            purchaseName: purchaseName,
            totalAmount: totalAmount,
            installmentCount: installmentCount,
            firstDueDate: firstDueDate,
            accountName: nullableStringField("accountName", in: dto),
            categoryName: categoryName,
            subCategoryName: subCategoryName,
            paymentMethodName: paymentMethodName,
            linkedCreditCardID: nullableUUIDField("linkedCreditCardID", in: dto),
            note: nullableStringField("note", in: dto),
            createdAt: dateField("createdAt", in: dto) ?? dto.updatedAt ?? Date(),
            updatedAt: dto.updatedAt ?? Date(),
            isDeleted: false,
            deletedAt: nil
        )
    }

    private func financialEvent(from dto: WalletSyncRecordDTO) -> FinancialEvent? {
        guard let typeRawValue = stringField("type", in: dto),
              let type = FinancialEventType(rawValue: typeRawValue),
              let statusRawValue = stringField("status", in: dto),
              let status = FinancialEventStatus(rawValue: statusRawValue),
              let title = stringField("title", in: dto),
              let amount = doubleField("amount", in: dto),
              let date = dateField("date", in: dto) else {
            return nil
        }

        var event = FinancialEvent(
            type: type,
            status: status,
            title: title,
            amount: amount,
            date: date
        )
        event.id = dto.id
        event.accountName = nullableStringField("accountName", in: dto)
        event.destinationAccountName = nullableStringField("destinationAccountName", in: dto)
        event.paymentMethodName = nullableStringField("paymentMethodName", in: dto)
        event.walletEventName = nullableStringField("walletEventName", in: dto)
        event.categoryName = nullableStringField("categoryName", in: dto)
        event.subCategoryName = nullableStringField("subCategoryName", in: dto)
        event.incomeType = incomeTypeField("incomeType", in: dto)
        event.reimbursementCategoryName = nullableStringField("reimbursementCategoryName", in: dto)
        event.repeatRule = repeatRuleField("repeatRule", in: dto) ?? .none
        event.recurringEndKind = recurringEndKindField("recurringEndKind", in: dto)
        event.recurringEndDate = nullableDateField("recurringEndDate", in: dto)
        event.recurringEndPaymentCount = nullableIntField("recurringEndPaymentCount", in: dto)
        event.recurringAmountMode = recurringAmountModeField("recurringAmountMode", in: dto)
        event.recurringEstimatedAmount = nullableDoubleField("recurringEstimatedAmount", in: dto)
        event.confidence = confidenceField("confidence", in: dto)
        event.sourceInstallmentPlanID = nullableUUIDField("sourceInstallmentPlanID", in: dto)
        event.sourceRecurringEventID = nullableUUIDField("sourceRecurringEventID", in: dto)
        event.recurringOccurrenceYear = nullableIntField("recurringOccurrenceYear", in: dto)
        event.recurringOccurrenceMonth = nullableIntField("recurringOccurrenceMonth", in: dto)
        event.note = nullableStringField("note", in: dto)
        event.createdAt = dateField("createdAt", in: dto) ?? dto.updatedAt ?? Date()
        event.updatedAt = dto.updatedAt ?? event.createdAt
        event.isDeleted = false
        event.deletedAt = nil
        return event
    }

    private func creditCardPurchase(from dto: WalletSyncRecordDTO) -> CreditCardPurchase? {
        guard let cardID = uuidField("cardID", in: dto),
              let title = stringField("title", in: dto),
              let amount = doubleField("amount", in: dto),
              let purchaseDate = dateField("purchaseDate", in: dto),
              let categoryName = stringField("categoryName", in: dto),
              let subCategoryName = stringField("subCategoryName", in: dto) else {
            return nil
        }

        return CreditCardPurchase(
            id: dto.id,
            cardID: cardID,
            title: title,
            amount: amount,
            purchaseDate: purchaseDate,
            categoryName: categoryName,
            subCategoryName: subCategoryName,
            note: nullableStringField("note", in: dto),
            createdAt: dateField("createdAt", in: dto) ?? dto.updatedAt ?? Date(),
            updatedAt: dto.updatedAt ?? Date(),
            isDeleted: false,
            deletedAt: nil
        )
    }

    private func creditCardPayment(from dto: WalletSyncRecordDTO) -> CreditCardPayment? {
        guard let cardID = uuidField("cardID", in: dto),
              let fromAccountName = stringField("fromAccountName", in: dto),
              let amount = doubleField("amount", in: dto),
              let paymentDate = dateField("paymentDate", in: dto) else {
            return nil
        }

        return CreditCardPayment(
            id: dto.id,
            cardID: cardID,
            fromAccountName: fromAccountName,
            amount: amount,
            paymentDate: paymentDate,
            note: nullableStringField("note", in: dto),
            createdAt: dateField("createdAt", in: dto) ?? dto.updatedAt ?? Date(),
            updatedAt: dto.updatedAt ?? Date(),
            isDeleted: false,
            deletedAt: nil
        )
    }

    private func personDebtEntry(from dto: WalletSyncRecordDTO) -> PersonDebtEntry? {
        guard let debtID = uuidField("debtID", in: dto),
              let entryTypeRawValue = stringField("entryType", in: dto),
              let entryType = PersonDebtEntryType(rawValue: entryTypeRawValue),
              let amount = doubleField("amount", in: dto),
              let accountName = stringField("accountName", in: dto),
              let date = dateField("date", in: dto) else {
            return nil
        }

        return PersonDebtEntry(
            id: dto.id,
            debtID: debtID,
            entryType: entryType,
            amount: amount,
            accountName: accountName,
            date: date,
            note: nullableStringField("note", in: dto),
            createdAt: dateField("createdAt", in: dto) ?? dto.updatedAt ?? Date(),
            updatedAt: dto.updatedAt ?? Date(),
            isDeleted: false,
            deletedAt: nil
        )
    }

    private func walletMonthlyBudget(from dto: WalletSyncRecordDTO) -> WalletMonthlyBudget? {
        guard let year = intField("year", in: dto),
              let month = intField("month", in: dto) else {
            return nil
        }

        var budget = WalletMonthlyBudget(year: year, month: month, items: [])
        budget.id = dto.id
        budget.createdAt = dateField("createdAt", in: dto) ?? dto.updatedAt ?? Date()
        budget.updatedAt = dto.updatedAt ?? Date()
        budget.isDeleted = false
        budget.deletedAt = nil
        return budget
    }

    private func walletMonthlyBudgetItem(from dto: WalletSyncRecordDTO) -> WalletMonthlyBudgetItem? {
        guard let categoryName = stringField("categoryName", in: dto),
              let plannedAmount = doubleField("plannedAmount", in: dto) else {
            return nil
        }

        var item = WalletMonthlyBudgetItem(categoryName: categoryName, plannedAmount: plannedAmount)
        item.id = dto.id
        item.createdAt = dateField("createdAt", in: dto) ?? dto.updatedAt ?? Date()
        item.updatedAt = dto.updatedAt ?? Date()
        item.isDeleted = false
        item.deletedAt = nil
        return item
    }

    private func blockedItem(
        recordName: String,
        entity: WalletSyncRecordEntity?,
        id: UUID?,
        reason: WalletSyncMasterDataApplyBlockReason? = nil
    ) -> WalletSyncMasterDataApplyPlanItem {
        let blockReason: WalletSyncMasterDataApplyBlockReason
        if let reason {
            blockReason = reason
        } else if entity == .monthlyBudgetItem {
            blockReason = .monthlyBudgetItemNoParent
        } else if entity == .householdSettings {
            blockReason = .householdSettingsNoModel
        } else if isFinancialSideEffectSensitive(entity) {
            blockReason = .unsafeFinancialApply
        } else if isFullDataEntityPendingDirectApplyValidation(entity) {
            blockReason = .directApplyNotValidated
        } else {
            blockReason = .nonMasterDataEntity
        }

        return WalletSyncMasterDataApplyPlanItem(
            recordName: recordName,
            entity: entity,
            id: id,
            action: .blocked(reason: blockReason)
        )
    }

    private func isFinancialSideEffectSensitive(_ entity: WalletSyncRecordEntity?) -> Bool {
        switch entity {
        case .none:
            return false
        default:
            return false
        }
    }

    private func isFullDataEntityPendingDirectApplyValidation(_ entity: WalletSyncRecordEntity?) -> Bool {
        return false
    }

    private func identityFromRecordName(_ recordName: String) -> WalletSyncRecordIdentity? {
        for entity in WalletSyncRecordEntity.allCases {
            let prefix = "\(entity.recordNamePrefix)_"
            guard recordName.hasPrefix(prefix) else { continue }
            let idText = String(recordName.dropFirst(prefix.count))
            guard let id = UUID(uuidString: idText) else { return nil }
            return WalletSyncRecordIdentity(entity: entity, id: id)
        }

        return nil
    }

    private func stringField(_ name: String, in dto: WalletSyncRecordDTO) -> String? {
        guard case .some(.string(let value)) = dto.fields[name] else { return nil }
        return value
    }

    private func nullableStringField(_ name: String, in dto: WalletSyncRecordDTO) -> String? {
        switch dto.fields[name] {
        case .string(let value):
            return value
        case .null:
            return nil
        default:
            return nil
        }
    }

    private func boolField(_ name: String, in dto: WalletSyncRecordDTO) -> Bool? {
        guard case .some(.bool(let value)) = dto.fields[name] else { return nil }
        return value
    }

    private func dateField(_ name: String, in dto: WalletSyncRecordDTO) -> Date? {
        guard case .some(.date(let value)) = dto.fields[name] else { return nil }
        return value
    }

    private func nullableDateField(_ name: String, in dto: WalletSyncRecordDTO) -> Date? {
        switch dto.fields[name] {
        case .date(let value):
            return value
        case .null:
            return nil
        default:
            return nil
        }
    }

    private func doubleField(_ name: String, in dto: WalletSyncRecordDTO) -> Double? {
        guard case .some(.double(let value)) = dto.fields[name] else { return nil }
        return value
    }

    private func intField(_ name: String, in dto: WalletSyncRecordDTO) -> Int? {
        guard case .some(.int(let value)) = dto.fields[name] else { return nil }
        return value
    }

    private func nullableUUIDField(_ name: String, in dto: WalletSyncRecordDTO) -> UUID? {
        switch dto.fields[name] {
        case .uuid(let value):
            return value
        case .null:
            return nil
        default:
            return nil
        }
    }

    private func uuidField(_ name: String, in dto: WalletSyncRecordDTO) -> UUID? {
        guard case .some(.uuid(let value)) = dto.fields[name] else { return nil }
        return value
    }

    private func stringArrayField(_ name: String, in dto: WalletSyncRecordDTO) -> [String]? {
        guard case .some(.stringArray(let value)) = dto.fields[name] else { return nil }
        return value
    }

    private func nullableIntField(_ name: String, in dto: WalletSyncRecordDTO) -> Int? {
        switch dto.fields[name] {
        case .int(let value):
            return value
        case .null:
            return nil
        default:
            return nil
        }
    }

    private func nullableDoubleField(_ name: String, in dto: WalletSyncRecordDTO) -> Double? {
        switch dto.fields[name] {
        case .double(let value):
            return value
        case .null:
            return nil
        default:
            return nil
        }
    }

    private func incomeTypeField(_ name: String, in dto: WalletSyncRecordDTO) -> IncomeType? {
        guard let rawValue = nullableStringField(name, in: dto) else { return nil }
        return IncomeType(rawValue: rawValue)
    }

    private func repeatRuleField(_ name: String, in dto: WalletSyncRecordDTO) -> RepeatRule? {
        guard let rawValue = nullableStringField(name, in: dto) else { return nil }
        return RepeatRule(rawValue: rawValue)
    }

    private func recurringEndKindField(_ name: String, in dto: WalletSyncRecordDTO) -> RecurringEndKind? {
        guard let rawValue = nullableStringField(name, in: dto) else { return nil }
        return RecurringEndKind(rawValue: rawValue)
    }

    private func recurringAmountModeField(_ name: String, in dto: WalletSyncRecordDTO) -> RecurringAmountMode? {
        guard let rawValue = nullableStringField(name, in: dto) else { return nil }
        return RecurringAmountMode(rawValue: rawValue)
    }

    private func confidenceField(_ name: String, in dto: WalletSyncRecordDTO) -> ConfidenceLevel? {
        guard let rawValue = nullableStringField(name, in: dto) else { return nil }
        return ConfidenceLevel(rawValue: rawValue)
    }

    private func providerAppearanceColorField(_ name: String, in dto: WalletSyncRecordDTO) -> ProviderAppearanceColor? {
        guard let rawValue = nullableStringField(name, in: dto) else { return nil }
        return ProviderAppearanceColor(rawValue: rawValue)
    }
}
