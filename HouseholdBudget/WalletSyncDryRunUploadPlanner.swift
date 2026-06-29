import Foundation
import CloudKit

struct WalletSyncDryRunUploadSummary {
    var totalDTOCount: Int
    var totalRecordCount: Int
    var countsByEntity: [WalletSyncRecordEntity: Int]
    var skippedEntities: [WalletSyncRecordEntity]
    var warnings: [String]
    var recordType: String
    var sampleRecordNames: [String]
}

struct WalletSyncDryRunUploadPlanner {

    static let sampleRecordNameLimit = 5

    @MainActor
    func plan(from store: WalletStore) -> WalletSyncDryRunUploadSummary {
        let syncStateStore = WalletSyncStateStore()
        let highRiskDeletionDTOs = syncStateStore.syncableHighRiskRecordDeletionDTOs()
        let entityGroups: [(WalletSyncRecordEntity, [WalletSyncRecordDTO])] = [
            (.account,                  store.accounts.map(WalletSyncRecordMappers.dto(for:))),
            (.category,                 store.categories.map(WalletSyncRecordMappers.dto(for:))),
            (.walletEvent,              store.walletEvents.map(WalletSyncRecordMappers.dto(for:))),
            (.merchantMemory,           store.merchantMemories.map(WalletSyncRecordMappers.dto(for:))),
            (.installmentPlan,          store.installmentPlans.map(WalletSyncRecordMappers.dto(for:))),
            (.installmentPlanDeletion,  syncStateStore.syncableInstallmentPlanDeletionDTOs()),
            (.creditCardPurchaseDeletion, highRiskDeletionDTOs.filter { $0.entity == .creditCardPurchaseDeletion }),
            (.creditCardPaymentDeletion, highRiskDeletionDTOs.filter { $0.entity == .creditCardPaymentDeletion }),
            (.personDebtDeletion, highRiskDeletionDTOs.filter { $0.entity == .personDebtDeletion }),
            (.personDebtEntryDeletion, highRiskDeletionDTOs.filter { $0.entity == .personDebtEntryDeletion }),
            (.monthlyBudgetItemDeletion, highRiskDeletionDTOs.filter { $0.entity == .monthlyBudgetItemDeletion }),
            (.financialEvent,           store.financialEvents.map(WalletSyncRecordMappers.dto(for:))),
            (.monthlyBudget,            store.monthlyBudgets.map(WalletSyncRecordMappers.dto(for:))),
            (.personDebt,               store.personDebts.map(WalletSyncRecordMappers.dto(for:))),
            (.personDebtEntry,          store.personDebtEntries.map(WalletSyncRecordMappers.dto(for:))),
            (.creditCard,               store.creditCards.map(WalletSyncRecordMappers.dto(for:))),
            (.creditCardPurchase,       store.creditCardPurchases.map(WalletSyncRecordMappers.dto(for:))),
            (.creditCardPayment,        store.creditCardPayments.map(WalletSyncRecordMappers.dto(for:))),
            (.historicalMonthlySummary, store.historicalMonthlySummaries.map(WalletSyncRecordMappers.dto(for:))),
        ]

        var allDTOs: [WalletSyncRecordDTO] = []
        var countsByEntity: [WalletSyncRecordEntity: Int] = [:]

        for (entity, dtos) in entityGroups {
            if !dtos.isEmpty {
                countsByEntity[entity] = dtos.count
            }
            allDTOs.append(contentsOf: dtos)
        }

        let recordCount = allDTOs.map(WalletSyncCKRecordAdapter.ckRecord(from:)).count
        let sampleRecordNames = Array(allDTOs.prefix(Self.sampleRecordNameLimit).map(\.recordName))

        return WalletSyncDryRunUploadSummary(
            totalDTOCount: allDTOs.count,
            totalRecordCount: recordCount,
            countsByEntity: countsByEntity,
            skippedEntities: [.monthlyBudgetItem, .householdSettings],
            warnings: [
                "monthlyBudgetItem skipped: DTO mapper does not encode a parentBudgetID field, preventing safe remote hierarchy reassembly.",
                "householdSettings skipped: entity is reserved with no mapped model."
            ],
            recordType: WalletSyncCKRecordAdapter.recordType,
            sampleRecordNames: sampleRecordNames
        )
    }
}
