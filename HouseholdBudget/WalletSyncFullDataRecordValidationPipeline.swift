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

protocol WalletSyncInitialCloudAdoptionSeedPruning: AnyObject {
    @discardableResult
    func removeSeedDataBeforeInitialCloudAdoptionIfSafe() -> Bool
}

struct WalletSyncFullDataRecordValidationPipelineSummary: Equatable {
    var zoneEnsured: Bool
    var totalEligibleCount: Int
    var uploadedCount: Int
    var batchCount: Int
    var uploadedCountsByBatch: [Int]
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

    enum ExecutionOrder {
        case uploadThenFetch
        case fetchThenUpload
    }

    private let zoneEnsurer: WalletSyncMasterDataZoneEnsuring
    private let recordSaver: WalletSyncMasterDataRecordSaving
    private let changedRecordFetcher: WalletSyncDryRunChangedRecordFetching
    private let tokenStore: WalletSyncChangeTokenStoring
    private let source: WalletSyncFullDataSourceReading
    private let localState: WalletSyncMergePlanLocalStateReading
    private let localFinancialEventDeletionStore: WalletSyncLocalFinancialEventDeletionStoring
    private let inboxParser: WalletSyncInboxParser
    private let applier: WalletSyncMasterDataPlanApplying
    private let uploadCap: Int
    private let executionOrder: ExecutionOrder

    init(
        zoneEnsurer: WalletSyncMasterDataZoneEnsuring,
        recordSaver: WalletSyncMasterDataRecordSaving,
        changedRecordFetcher: WalletSyncDryRunChangedRecordFetching,
        tokenStore: WalletSyncChangeTokenStoring,
        source: WalletSyncFullDataSourceReading,
        localState: WalletSyncMergePlanLocalStateReading,
        localFinancialEventDeletionStore: WalletSyncLocalFinancialEventDeletionStoring? = nil,
        inboxParser: WalletSyncInboxParser,
        applier: WalletSyncMasterDataPlanApplying,
        uploadCap: Int = WalletSyncFullDataRecordValidationPipeline.defaultUploadCap,
        executionOrder: ExecutionOrder = .uploadThenFetch
    ) {
        self.zoneEnsurer = zoneEnsurer
        self.recordSaver = recordSaver
        self.changedRecordFetcher = changedRecordFetcher
        self.tokenStore = tokenStore
        self.source = source
        self.localState = localState
        self.localFinancialEventDeletionStore = localFinancialEventDeletionStore ?? WalletSyncStateStore()
        self.inboxParser = inboxParser
        self.applier = applier
        self.uploadCap = uploadCap
        self.executionOrder = executionOrder
    }

    func run() async throws -> WalletSyncFullDataRecordValidationPipelineSummary {
        try await ensureSyncZoneForBootstrap()

        let savedTokenData = tokenStore.loadWalletSyncZoneChangeTokenData()
        switch executionOrder {
        case .uploadThenFetch:
            return try await runUploadThenFetch(savedTokenData: savedTokenData)
        case .fetchThenUpload:
            return try await runFetchThenUpload(savedTokenData: savedTokenData)
        }
    }

    private func runUploadThenFetch(savedTokenData: Data?) async throws -> WalletSyncFullDataRecordValidationPipelineSummary {
        let uploadPlan = makeUploadPlan()
        if savedTokenData == nil {
            let adoptionFetchResult = try await fetchInitialAdoptionChanges()
            if !adoptionFetchResult.records.isEmpty || !adoptionFetchResult.deletedRecordNames.isEmpty {
                (source as? WalletSyncInitialCloudAdoptionSeedPruning)?.removeSeedDataBeforeInitialCloudAdoptionIfSafe()
                return makeSummary(
                    uploadPlan: uploadPlan,
                    savedRecords: [],
                    uploadedCountsByBatch: [],
                    uploadedCountsByEntity: [:],
                    savedTokenData: nil,
                    fetchResult: adoptionFetchResult,
                    processedFetch: processFetchResult(adoptionFetchResult, uploadedRecordNames: [])
                )
            }
        }

        let uploadResult = try await uploadRecords(using: uploadPlan)
        let uploadedRecordNames = Set(uploadResult.savedRecords.map(\.recordID.recordName))
        let fetchResult = try await changedRecordFetcher.fetchChangedRecords(since: savedTokenData)
        return makeSummary(
            uploadPlan: uploadPlan,
            savedRecords: uploadResult.savedRecords,
            uploadedCountsByBatch: uploadResult.uploadedCountsByBatch,
            uploadedCountsByEntity: uploadPlan.countsByEntity,
            savedTokenData: savedTokenData,
            fetchResult: fetchResult,
            processedFetch: processFetchResult(fetchResult, uploadedRecordNames: uploadedRecordNames)
        )
    }

    private func runFetchThenUpload(savedTokenData: Data?) async throws -> WalletSyncFullDataRecordValidationPipelineSummary {
        let fetchResult: WalletSyncCloudKitFetchResult
        if savedTokenData == nil {
            fetchResult = try await fetchInitialAdoptionChanges()
            if !fetchResult.records.isEmpty || !fetchResult.deletedRecordNames.isEmpty {
                let processedFetch = processFetchResult(fetchResult, uploadedRecordNames: [])
                (source as? WalletSyncInitialCloudAdoptionSeedPruning)?.removeSeedDataBeforeInitialCloudAdoptionIfSafe()
                let uploadPlan = makeUploadPlan()
                return makeSummary(
                    uploadPlan: uploadPlan,
                    savedRecords: [],
                    uploadedCountsByBatch: [],
                    uploadedCountsByEntity: [:],
                    savedTokenData: nil,
                    fetchResult: fetchResult,
                    processedFetch: processedFetch
                )
            }
        } else {
            fetchResult = try await changedRecordFetcher.fetchChangedRecords(since: savedTokenData)
        }

        let processedFetch = processFetchResult(fetchResult, uploadedRecordNames: [])
        let uploadPlan = makeUploadPlan()
        let uploadResult = try await uploadRecords(using: uploadPlan)
        return makeSummary(
            uploadPlan: uploadPlan,
            savedRecords: uploadResult.savedRecords,
            uploadedCountsByBatch: uploadResult.uploadedCountsByBatch,
            uploadedCountsByEntity: uploadPlan.countsByEntity,
            savedTokenData: savedTokenData,
            fetchResult: fetchResult,
            processedFetch: processedFetch
        )
    }

    private func uploadRecords(using uploadPlan: FullDataUploadPlan) async throws -> FullDataUploadResult {
        var savedRecords: [CKRecord] = []
        var uploadedCountsByBatch: [Int] = []

        for batch in uploadPlan.batches {
            let records = batch.map(WalletSyncCKRecordAdapter.ckRecord(from:))
            let batchSavedRecords = try await recordSaver.saveRecords(records)
            savedRecords.append(contentsOf: batchSavedRecords)
            uploadedCountsByBatch.append(batchSavedRecords.count)
        }

        return FullDataUploadResult(
            savedRecords: savedRecords,
            uploadedCountsByBatch: uploadedCountsByBatch
        )
    }

    private func ensureSyncZoneForBootstrap() async throws {
        do {
            try await zoneEnsurer.ensureSyncZone()
        } catch {
            guard Self.isMissingOrPurgedSyncZoneError(error) else {
                throw error
            }

            tokenStore.clearWalletSyncZoneChangeTokenData()
            try await zoneEnsurer.ensureSyncZone()
        }
    }

    private func fetchInitialAdoptionChanges() async throws -> WalletSyncCloudKitFetchResult {
        do {
            return try await changedRecordFetcher.fetchChangedRecords(since: nil)
        } catch {
            guard Self.isMissingOrPurgedSyncZoneError(error) else {
                throw error
            }

            tokenStore.clearWalletSyncZoneChangeTokenData()
            try await zoneEnsurer.ensureSyncZone()
            return WalletSyncCloudKitFetchResult(records: [])
        }
    }

    private func makeSummary(
        uploadPlan: FullDataUploadPlan,
        savedRecords: [CKRecord],
        uploadedCountsByBatch: [Int],
        uploadedCountsByEntity: [WalletSyncRecordEntity: Int],
        savedTokenData: Data?,
        fetchResult: WalletSyncCloudKitFetchResult,
        processedFetch: FullDataFetchProcessingResult
    ) -> WalletSyncFullDataRecordValidationPipelineSummary {
        WalletSyncFullDataRecordValidationPipelineSummary(
            zoneEnsured: true,
            totalEligibleCount: uploadPlan.totalAvailableCount,
            uploadedCount: savedRecords.count,
            batchCount: uploadedCountsByBatch.count,
            uploadedCountsByBatch: uploadedCountsByBatch,
            uploadedCountsByEntity: uploadedCountsByEntity,
            excludedEntities: [.householdSettings],
            uploadCap: uploadCap,
            uploadCappedCount: uploadPlan.cappedCount,
            usedSavedToken: savedTokenData != nil,
            changedRecordCount: fetchResult.records.count,
            deletedRecordCount: fetchResult.deletedRecordNames.count,
            skippedLocalEchoCount: processedFetch.skippedLocalEchoCount,
            parsedValidCount: processedFetch.parsedValidCount,
            blockedCount: processedFetch.blockedCount,
            failedCount: processedFetch.failedCount,
            plannedCreateCount: processedFetch.plannedCreateCount,
            plannedUpdateCount: processedFetch.plannedUpdateCount,
            plannedDisableCount: processedFetch.plannedDisableCount,
            appliedCreatedCount: processedFetch.appliedCreatedCount,
            appliedUpdatedCount: processedFetch.appliedUpdatedCount,
            appliedDisabledCount: processedFetch.appliedDisabledCount,
            appliedBlockedCount: processedFetch.appliedBlockedCount,
            appliedFailedCount: processedFetch.appliedFailedCount,
            tokenReturned: fetchResult.changeTokenData != nil,
            tokenSaved: processedFetch.tokenSaved,
            moreComing: fetchResult.moreComing
        )
    }

    private func processFetchResult(
        _ fetchResult: WalletSyncCloudKitFetchResult,
        uploadedRecordNames: Set<String>
    ) -> FullDataFetchProcessingResult {
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
        let plan = WalletSyncMasterDataApplyPlanBuilder(
            localState: localState,
            localFinancialEventDeletionStore: localFinancialEventDeletionStore
        ).makePlan(
            changedRecords: nonEchoRecords,
            deletedRecordNames: fetchResult.deletedRecordNames
        )
        let applyResult = applier.apply(plan)

        return FullDataFetchProcessingResult(
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
            tokenSaved: tokenSaved
        )
    }

    private func makeUploadPlan() -> FullDataUploadPlan {
        let entityGroups: [(WalletSyncRecordEntity, [WalletSyncRecordDTO])] = [
            (.account, source.accounts.map(WalletSyncRecordMappers.dto(for:))),
            (.category, uploadableCategories().map(WalletSyncRecordMappers.dto(for:))),
            (.walletEvent, source.walletEvents.map(WalletSyncRecordMappers.dto(for:))),
            (.financialEvent, source.financialEvents.map(WalletSyncRecordMappers.dto(for:))),
            (.financialEventDeletion, localFinancialEventDeletionStore.syncableFinancialEventDeletionDTOs()),
            (.monthlyBudget, source.monthlyBudgets.map(WalletSyncRecordMappers.dto(for:))),
            (.monthlyBudgetItem, source.monthlyBudgets.flatMap { budget in
                budget.items.map { WalletSyncRecordMappers.dto(for: $0, parentBudgetID: budget.id) }
            }),
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
        let batches = allDTOs.chunked(maximumSize: uploadCap)
        let countsByEntity = Dictionary(grouping: allDTOs, by: \.entity).mapValues(\.count)

        return FullDataUploadPlan(
            batches: batches,
            totalAvailableCount: allDTOs.count,
            countsByEntity: countsByEntity
        )
    }

    private func uploadableCategories() -> [Category] {
#if DEBUG
        source.categories.filter { !WalletSyncDebugSyntheticMasterDataChangeFactory.isDebugCategory($0) }
#else
        source.categories
#endif
    }

    private static func isMissingOrPurgedSyncZoneError(_ error: Error) -> Bool {
        if let ckError = error as? CKError {
            return ckError.code == .zoneNotFound || ckError.code == .unknownItem
        }

        if let walletError = error as? WalletSyncCloudKitError {
            switch walletError {
            case .unknown(let underlying):
                return isMissingOrPurgedSyncZoneError(underlying)
            case .invalidRecord(let message):
                return isMissingOrPurgedMessage(message)
            default:
                return false
            }
        }

        let nsError = error as NSError
        if nsError.domain == CKError.errorDomain &&
            (nsError.code == CKError.Code.zoneNotFound.rawValue ||
             nsError.code == CKError.Code.unknownItem.rawValue) {
            return true
        }

        return isMissingOrPurgedMessage(nsError.localizedDescription)
    }

    private static func isMissingOrPurgedMessage(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName.lowercased()) &&
            (normalized.contains("zone was purged") ||
             normalized.contains("zone not found") ||
             normalized.contains("unknown item"))
    }

    private struct FullDataUploadPlan {
        var batches: [[WalletSyncRecordDTO]]
        var totalAvailableCount: Int
        var countsByEntity: [WalletSyncRecordEntity: Int]

        var cappedCount: Int {
            0
        }
    }

    private struct FullDataUploadResult {
        var savedRecords: [CKRecord]
        var uploadedCountsByBatch: [Int]
    }

    private struct FullDataFetchProcessingResult {
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
        var tokenSaved: Bool
    }
}

@MainActor
final class WalletSyncFullDataAutomaticSyncRunner {
    enum Trigger {
        case launch
        case foreground
        case localDataChanged
    }

    private let minimumRunInterval: TimeInterval
    private let localChangeDebounceInterval: TimeInterval
    private var scheduledTask: Task<Void, Never>?
    private var isRunning = false
    private var queuedRunRequested = false
    private var lastRunAt: Date?

    init(
        minimumRunInterval: TimeInterval = 30,
        localChangeDebounceInterval: TimeInterval = 5
    ) {
        self.minimumRunInterval = minimumRunInterval
        self.localChangeDebounceInterval = localChangeDebounceInterval
    }

    func requestSync(
        trigger: Trigger,
        operation: @escaping @MainActor () async -> Void
    ) {
        guard !isRunning else {
            queuedRunRequested = true
            return
        }

        scheduledTask?.cancel()
        scheduledTask = Task { [weak self] in
            let debounceInterval = trigger == .localDataChanged ? self?.localChangeDebounceInterval ?? 0 : 0
            if debounceInterval > 0 {
                try? await Task.sleep(for: .seconds(debounceInterval))
            }

            guard !Task.isCancelled else { return }
            await self?.runWhenAllowed(operation, enforceMinimumInterval: true)
        }
    }

    func runUserInitiatedSync(operation: @escaping @MainActor () async -> Void) async {
        scheduledTask?.cancel()
        await runWhenAllowed(operation, enforceMinimumInterval: false)
    }

    private func runWhenAllowed(
        _ operation: @escaping @MainActor () async -> Void,
        enforceMinimumInterval: Bool
    ) async {
        guard !isRunning else {
            queuedRunRequested = true
            return
        }

        if enforceMinimumInterval, let lastRunAt {
            let elapsed = Date().timeIntervalSince(lastRunAt)
            let remaining = minimumRunInterval - elapsed
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
        }

        guard !Task.isCancelled else { return }

        isRunning = true
        await operation()
        lastRunAt = Date()
        isRunning = false
        scheduledTask = nil

        if queuedRunRequested {
            queuedRunRequested = false
            requestSync(trigger: .localDataChanged, operation: operation)
        }
    }
}

private extension Array {
    func chunked(maximumSize: Int) -> [[Element]] {
        guard maximumSize > 0 else { return isEmpty ? [] : [self] }

        var result: [[Element]] = []
        var startIndex = 0
        while startIndex < count {
            let endIndex = Swift.min(startIndex + maximumSize, count)
            result.append(Array(self[startIndex..<endIndex]))
            startIndex = endIndex
        }
        return result
    }
}
