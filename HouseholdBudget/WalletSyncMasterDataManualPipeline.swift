import Foundation
import CloudKit

protocol WalletSyncMasterDataZoneEnsuring {
    func ensureSyncZone() async throws
}

protocol WalletSyncMasterDataRecordSaving {
    func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord]
}

protocol WalletSyncMasterDataSourceReading {
    var accounts: [Account] { get }
    var categories: [Category] { get }
    var walletEvents: [WalletEvent] { get }
}

@MainActor
protocol WalletSyncMasterDataPlanApplying {
    func apply(_ plan: WalletSyncMasterDataApplyPlanSummary) -> WalletSyncMasterDataApplyResult
}

extension WalletSyncRealCloudKitPrivateDatabaseBoundary: WalletSyncMasterDataZoneEnsuring {}
extension WalletSyncRealCloudKitPrivateDatabaseBoundary: WalletSyncMasterDataRecordSaving {}
extension WalletStore: WalletSyncMasterDataSourceReading {}
extension WalletSyncMasterDataApplier: WalletSyncMasterDataPlanApplying {}

struct WalletSyncMasterDataManualPipelineSummary: Equatable {
    var zoneEnsured: Bool
    var uploadedCount: Int
    var uploadedAccountCount: Int
    var uploadedCategoryCount: Int
    var uploadedWalletEventCount: Int
    var uploadCap: Int
    var uploadCappedCount: Int
    var usedSavedToken: Bool
    var changedRecordCount: Int
    var deletedRecordCount: Int
    var skippedLocalEchoCount: Int
    var skippedLocalEchoRecordNames: [String]
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
    var sampleRecordNames: [String]
}

@MainActor
struct WalletSyncMasterDataManualPipeline {
    nonisolated static let defaultUploadCap = 50
    nonisolated static let defaultSampleLimit = 10

    private let zoneEnsurer: WalletSyncMasterDataZoneEnsuring
    private let recordSaver: WalletSyncMasterDataRecordSaving
    private let changedRecordFetcher: WalletSyncDryRunChangedRecordFetching
    private let tokenStore: WalletSyncChangeTokenStoring
    private let source: WalletSyncMasterDataSourceReading
    private let localState: WalletSyncMergePlanLocalStateReading
    private let inboxParser: WalletSyncInboxParser
    private let applier: WalletSyncMasterDataPlanApplying
    private let uploadCap: Int
    private let sampleLimit: Int

    init(
        zoneEnsurer: WalletSyncMasterDataZoneEnsuring,
        recordSaver: WalletSyncMasterDataRecordSaving,
        changedRecordFetcher: WalletSyncDryRunChangedRecordFetching,
        tokenStore: WalletSyncChangeTokenStoring,
        source: WalletSyncMasterDataSourceReading,
        localState: WalletSyncMergePlanLocalStateReading,
        inboxParser: WalletSyncInboxParser,
        applier: WalletSyncMasterDataPlanApplying,
        uploadCap: Int,
        sampleLimit: Int
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
        self.sampleLimit = sampleLimit
    }

    func run() async throws -> WalletSyncMasterDataManualPipelineSummary {
        try await zoneEnsurer.ensureSyncZone()

        let uploadPlan = makeUploadPlan()
        let records = uploadPlan.dtos.map(WalletSyncCKRecordAdapter.ckRecord(from:))
        let savedRecords = try await recordSaver.saveRecords(records)
        let savedRecordNameArray = savedRecords.map(\.recordID.recordName)
        let uploadedRecordNames = Set(savedRecordNameArray)

        let savedTokenData = tokenStore.loadWalletSyncZoneChangeTokenData()
        let fetchResult = try await changedRecordFetcher.fetchChangedRecords(since: savedTokenData)
        let tokenSaved: Bool
        if let returnedTokenData = fetchResult.changeTokenData {
            tokenStore.saveWalletSyncZoneChangeTokenData(returnedTokenData)
            tokenSaved = true
        } else {
            tokenSaved = false
        }

        let echoRecords = fetchResult.records.filter { uploadedRecordNames.contains($0.recordID.recordName) }
        let nonEchoRecords = fetchResult.records.filter { !uploadedRecordNames.contains($0.recordID.recordName) }
        let skippedLocalEchoCount = echoRecords.count
        let skippedLocalEchoRecordNames = Array(echoRecords.prefix(sampleLimit).map(\.recordID.recordName))

        let inbox = inboxParser.parse(
            changedRecords: nonEchoRecords,
            deletedRecordNames: fetchResult.deletedRecordNames
        )
        let stateStore = WalletSyncStateStore()
        let plan = WalletSyncMasterDataApplyPlanBuilder(
            localState: localState,
            localFinancialEventDeletionStore: stateStore,
            localRecordTombstoneStore: stateStore
        ).makePlan(
            changedRecords: nonEchoRecords,
            deletedRecordNames: fetchResult.deletedRecordNames
        )
        let applyResult = applier.apply(plan)

        return WalletSyncMasterDataManualPipelineSummary(
            zoneEnsured: true,
            uploadedCount: savedRecords.count,
            uploadedAccountCount: uploadPlan.accountCount,
            uploadedCategoryCount: uploadPlan.categoryCount,
            uploadedWalletEventCount: uploadPlan.walletEventCount,
            uploadCap: uploadCap,
            uploadCappedCount: uploadPlan.cappedCount,
            usedSavedToken: savedTokenData != nil,
            changedRecordCount: fetchResult.records.count,
            deletedRecordCount: fetchResult.deletedRecordNames.count,
            skippedLocalEchoCount: skippedLocalEchoCount,
            skippedLocalEchoRecordNames: skippedLocalEchoRecordNames,
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
            moreComing: fetchResult.moreComing,
            sampleRecordNames: sampleRecordNames(
                savedRecordNames: savedRecordNameArray,
                changedRecords: fetchResult.records,
                deletedRecordNames: fetchResult.deletedRecordNames
            )
        )
    }

    private func makeUploadPlan() -> MasterDataUploadPlan {
        let accountDTOs = source.accounts.map(WalletSyncRecordMappers.dto(for:))
        let categoryDTOs = source.categories.map(WalletSyncRecordMappers.dto(for:))
        let walletEventDTOs = source.walletEvents.map(WalletSyncRecordMappers.dto(for:))
        let allDTOs = accountDTOs + categoryDTOs + walletEventDTOs
        let limitedDTOs = Array(allDTOs.prefix(uploadCap))

        return MasterDataUploadPlan(
            dtos: limitedDTOs,
            totalAvailableCount: allDTOs.count,
            accountCount: limitedDTOs.filter { $0.entity == .account }.count,
            categoryCount: limitedDTOs.filter { $0.entity == .category }.count,
            walletEventCount: limitedDTOs.filter { $0.entity == .walletEvent }.count
        )
    }

    private func sampleRecordNames(
        savedRecordNames: [String],
        changedRecords: [CKRecord],
        deletedRecordNames: [String]
    ) -> [String] {
        let changedRecordNames = changedRecords.map(\.recordID.recordName)
        let combined = savedRecordNames + changedRecordNames + deletedRecordNames
        var seen: Set<String> = []
        var samples: [String] = []

        for recordName in combined {
            guard seen.insert(recordName).inserted else { continue }
            samples.append(recordName)
            if samples.count == sampleLimit {
                break
            }
        }

        return samples
    }

    private struct MasterDataUploadPlan {
        var dtos: [WalletSyncRecordDTO]
        var totalAvailableCount: Int
        var accountCount: Int
        var categoryCount: Int
        var walletEventCount: Int

        var cappedCount: Int {
            max(0, totalAvailableCount - dtos.count)
        }
    }
}
