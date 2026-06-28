import Foundation
import CloudKit

protocol WalletSyncFullDataSourceReading: WalletSyncMasterDataSourceReading {
    var merchantMemories: [MerchantMemory] { get }
    var installmentPlans: [InstallmentPlan] { get }
    var financialEvents: [FinancialEvent] { get }
    var monthlyBudgets: [WalletMonthlyBudget] { get }
    var personDebts: [PersonDebt] { get }
    var personDebtEntries: [PersonDebtEntry] { get }
    var creditCards: [CreditCard] { get }
    var creditCardPurchases: [CreditCardPurchase] { get }
    var creditCardPayments: [CreditCardPayment] { get }
    var historicalMonthlySummaries: [HistoricalMonthlySummaryEntry] { get }
}

extension WalletStore: WalletSyncFullDataSourceReading {}

struct WalletSyncFullDataRecordValidationPipelineSummary: Equatable {
    var zoneEnsured: Bool
    var uploadedCount: Int
    var uploadedCountsByEntity: [WalletSyncRecordEntity: Int]
    var excludedEntities: [WalletSyncRecordEntity]
    var uploadCap: Int
    var uploadCappedCount: Int
    var usedSavedToken: Bool
    var changedRecordCount: Int
    var deletedRecordCount: Int
    var skippedLocalEchoCount: Int
    var parsedValidCount: Int
    var blockedCount: Int
    var failedCount: Int
    var plannedCreateCount: Int
    var plannedUpdateCount: Int
    var plannedDisableCount: Int
    var appliedCreatedCount: Int
    var appliedUpdatedCount: Int
    var appliedDisabledCount: Int
    var appliedBlockedCount: Int
    var appliedFailedCount: Int
    var tokenReturned: Bool
    var tokenSaved: Bool
    var moreComing: Bool
}

@MainActor
struct WalletSyncFullDataRecordValidationPipeline {
    nonisolated static let defaultUploadCap = 200

    private let zoneEnsurer: WalletSyncMasterDataZoneEnsuring
    private let recordSaver: WalletSyncMasterDataRecordSaving
    private let changedRecordFetcher: WalletSyncDryRunChangedRecordFetching
    private let tokenStore: WalletSyncChangeTokenStoring
    private let source: WalletSyncFullDataSourceReading
    private let localState: WalletSyncMergePlanLocalStateReading
    private let inboxParser: WalletSyncInboxParser
    private let applier: WalletSyncMasterDataPlanApplying
    private let uploadCap: Int

    init(
        zoneEnsurer: WalletSyncMasterDataZoneEnsuring,
        recordSaver: WalletSyncMasterDataRecordSaving,
        changedRecordFetcher: WalletSyncDryRunChangedRecordFetching,
        tokenStore: WalletSyncChangeTokenStoring,
        source: WalletSyncFullDataSourceReading,
        localState: WalletSyncMergePlanLocalStateReading,
        inboxParser: WalletSyncInboxParser,
        applier: WalletSyncMasterDataPlanApplying,
        uploadCap: Int = WalletSyncFullDataRecordValidationPipeline.defaultUploadCap
    ) {
        self.zoneEnsurer = zoneEnsurer
        self.recordSaver = recordSaver
        self.changedRecordFetcher = changedRecordFetcher
        self.tokenStore = tokenStore
        self.source = source
        self.localState = localState
        self.inboxParser = inboxParser
        self.applier = applier
        self.uploadCap = uploadCap
    }

    func run() async throws -> WalletSyncFullDataRecordValidationPipelineSummary {
        try await zoneEnsurer.ensureSyncZone()

        let uploadPlan = makeUploadPlan()
        let records = uploadPlan.dtos.map(WalletSyncCKRecordAdapter.ckRecord(from:))
        let savedRecords = try await recordSaver.saveRecords(records)
        let uploadedRecordNames = Set(savedRecords.map(\.recordID.recordName))

        let savedTokenData = tokenStore.loadWalletSyncZoneChangeTokenData()
        let fetchResult = try await changedRecordFetcher.fetchChangedRecords(since: savedTokenData)
        let tokenSaved: Bool
        if let returnedTokenData = fetchResult.changeTokenData {
            tokenStore.saveWalletSyncZoneChangeTokenData(returnedTokenData)
            tokenSaved = true
        } else {
            tokenSaved = false
        }

        let nonEchoRecords = fetchResult.records.filter { !uploadedRecordNames.contains($0.recordID.recordName) }
        let skippedLocalEchoCount = fetchResult.records.count - nonEchoRecords.count
        let inbox = inboxParser.parse(
            changedRecords: nonEchoRecords,
            deletedRecordNames: fetchResult.deletedRecordNames
        )
        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: localState).makePlan(
            changedRecords: nonEchoRecords,
            deletedRecordNames: fetchResult.deletedRecordNames
        )
        let applyResult = applier.apply(plan)

        return WalletSyncFullDataRecordValidationPipelineSummary(
            zoneEnsured: true,
            uploadedCount: savedRecords.count,
            uploadedCountsByEntity: uploadPlan.countsByEntity,
            excludedEntities: [.monthlyBudgetItem, .householdSettings],
            uploadCap: uploadCap,
            uploadCappedCount: uploadPlan.cappedCount,
            usedSavedToken: savedTokenData != nil,
            changedRecordCount: fetchResult.records.count,
            deletedRecordCount: fetchResult.deletedRecordNames.count,
            skippedLocalEchoCount: skippedLocalEchoCount,
            parsedValidCount: inbox.validCount,
            blockedCount: plan.blockedCount,
            failedCount: plan.failedCount,
            plannedCreateCount: plan.plannedCreateCount,
            plannedUpdateCount: plan.plannedUpdateCount,
            plannedDisableCount: plan.plannedDisableCount,
            appliedCreatedCount: applyResult.createdCount,
            appliedUpdatedCount: applyResult.updatedCount,
            appliedDisabledCount: applyResult.disabledCount,
            appliedBlockedCount: applyResult.blockedCount,
            appliedFailedCount: applyResult.failedCount,
            tokenReturned: fetchResult.changeTokenData != nil,
            tokenSaved: tokenSaved,
            moreComing: fetchResult.moreComing
        )
    }

    private func makeUploadPlan() -> FullDataUploadPlan {
        let entityGroups: [(WalletSyncRecordEntity, [WalletSyncRecordDTO])] = [
            (.account, source.accounts.map(WalletSyncRecordMappers.dto(for:))),
            (.category, source.categories.map(WalletSyncRecordMappers.dto(for:))),
            (.walletEvent, source.walletEvents.map(WalletSyncRecordMappers.dto(for:))),
            (.financialEvent, source.financialEvents.map(WalletSyncRecordMappers.dto(for:))),
            (.monthlyBudget, source.monthlyBudgets.map(WalletSyncRecordMappers.dto(for:))),
            (.personDebt, source.personDebts.map(WalletSyncRecordMappers.dto(for:))),
            (.personDebtEntry, source.personDebtEntries.map(WalletSyncRecordMappers.dto(for:))),
            (.creditCard, source.creditCards.map(WalletSyncRecordMappers.dto(for:))),
            (.creditCardPurchase, source.creditCardPurchases.map(WalletSyncRecordMappers.dto(for:))),
            (.creditCardPayment, source.creditCardPayments.map(WalletSyncRecordMappers.dto(for:))),
            (.installmentPlan, source.installmentPlans.map(WalletSyncRecordMappers.dto(for:))),
            (.historicalMonthlySummary, source.historicalMonthlySummaries.map(WalletSyncRecordMappers.dto(for:))),
            (.merchantMemory, source.merchantMemories.map(WalletSyncRecordMappers.dto(for:)))
        ]

        let allDTOs = entityGroups.flatMap(\.1)
        let limitedDTOs = Array(allDTOs.prefix(uploadCap))
        let countsByEntity = Dictionary(grouping: limitedDTOs, by: \.entity).mapValues(\.count)

        return FullDataUploadPlan(
            dtos: limitedDTOs,
            totalAvailableCount: allDTOs.count,
            countsByEntity: countsByEntity
        )
    }

    private struct FullDataUploadPlan {
        var dtos: [WalletSyncRecordDTO]
        var totalAvailableCount: Int
        var countsByEntity: [WalletSyncRecordEntity: Int]

        var cappedCount: Int {
            max(0, totalAvailableCount - dtos.count)
        }
    }
}
