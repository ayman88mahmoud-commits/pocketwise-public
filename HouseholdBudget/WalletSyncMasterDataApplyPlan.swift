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
            return false
        }.count
    }

    var plannedUpdateCount: Int {
        items.filter {
            if case .updateAccount = $0.action { return true }
            if case .updateCategory = $0.action { return true }
            if case .updateWalletEvent = $0.action { return true }
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
        default:
            return blockedItem(recordName: dto.recordName, entity: dto.entity, id: dto.id)
        }
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
        case .financialEvent,
             .personDebtEntry,
             .creditCardPurchase,
             .creditCardPayment,
             .installmentPlan:
            return true
        default:
            return false
        }
    }

    private func isFullDataEntityPendingDirectApplyValidation(_ entity: WalletSyncRecordEntity?) -> Bool {
        switch entity {
        case .monthlyBudget,
             .personDebt,
             .creditCard,
             .historicalMonthlySummary,
             .merchantMemory:
            return true
        default:
            return false
        }
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

    private func stringArrayField(_ name: String, in dto: WalletSyncRecordDTO) -> [String]? {
        guard case .some(.stringArray(let value)) = dto.fields[name] else { return nil }
        return value
    }

    private func providerAppearanceColorField(_ name: String, in dto: WalletSyncRecordDTO) -> ProviderAppearanceColor? {
        guard let rawValue = nullableStringField(name, in: dto) else { return nil }
        return ProviderAppearanceColor(rawValue: rawValue)
    }
}
