import XCTest
import CloudKit
@testable import WalletBoard

@MainActor
final class WalletSyncFullDataRecordValidationPipelineTests: XCTestCase {

    func testUploadIncludesAllSupportedFullDataEntities() async throws {
        let boundary = FakeFullDataBoundary()
        let store = FakeFullDataStore.withOneOfEachSupportedEntity()
        let pipeline = makePipeline(boundary: boundary, store: store)

        let summary = try await pipeline.run()
        let uploadedEntities = try boundary.savedRecords.map { try WalletSyncCKRecordAdapter.dto(from: $0).entity }

        XCTAssertEqual(Set(uploadedEntities), Set(Self.supportedEntities))
        XCTAssertEqual(summary.uploadedCount, Self.supportedEntities.count)
        for entity in Self.supportedEntities {
            XCTAssertEqual(summary.uploadedCountsByEntity[entity], 1)
        }
        XCTAssertEqual(summary.totalEligibleCount, Self.supportedEntities.count)
        XCTAssertEqual(summary.uploadCappedCount, 0)
    }

    func testPipelineSplitsEligibleRecordsIntoMultipleSequentialBatches() async throws {
        let boundary = FakeFullDataBoundary()
        let store = FakeFullDataStore(accounts: makeAccounts(count: 5))
        let pipeline = makePipeline(boundary: boundary, store: store, uploadCap: 2)

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.totalEligibleCount, 5)
        XCTAssertEqual(summary.uploadedCount, 5)
        XCTAssertEqual(summary.batchCount, 3)
        XCTAssertEqual(summary.uploadedCountsByBatch, [2, 2, 1])
        XCTAssertEqual(boundary.savedRecordBatches.map(\.count), [2, 2, 1])
        XCTAssertEqual(boundary.events, ["ensure", "save", "save", "save", "fetch"])
    }

    func testCappedRemainingCountIsZeroAfterBatchedUpload() async throws {
        let boundary = FakeFullDataBoundary()
        let store = FakeFullDataStore(accounts: makeAccounts(count: 7))
        let pipeline = makePipeline(boundary: boundary, store: store, uploadCap: 3)

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.uploadedCount, 7)
        XCTAssertEqual(summary.uploadCappedCount, 0)
        XCTAssertEqual(summary.uploadedCountsByEntity[.account], 7)
    }

    func testUploadExcludesMonthlyBudgetItemAndHouseholdSettings() async throws {
        let boundary = FakeFullDataBoundary()
        let store = FakeFullDataStore.withOneOfEachSupportedEntity()
        let pipeline = makePipeline(boundary: boundary, store: store)

        let summary = try await pipeline.run()
        let uploadedEntities = try boundary.savedRecords.map { try WalletSyncCKRecordAdapter.dto(from: $0).entity }

        XCTAssertFalse(uploadedEntities.contains(.monthlyBudgetItem))
        XCTAssertFalse(uploadedEntities.contains(.householdSettings))
        XCTAssertEqual(Set(summary.excludedEntities), [.monthlyBudgetItem, .householdSettings])
    }

    func testLocalEchoGuardStillPreventsSelfApply() async throws {
        let financialEvent = makeFinancialEvent()
        let echoRecord = WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: financialEvent))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [echoRecord], changeTokenData: Data([1]))
        )
        let store = FakeFullDataStore(financialEvents: [financialEvent])
        let applier = FakeFullDataApplier()
        let pipeline = makePipeline(boundary: boundary, store: store, applier: applier)

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.changedRecordCount, 1)
        XCTAssertEqual(summary.skippedLocalEchoCount, 1)
        XCTAssertEqual(summary.blockedCount, 0)
        XCTAssertEqual(applier.receivedPlan?.items.count, 0)
    }

    func testLocalEchoGuardIncludesRecordsFromAllBatches() async throws {
        let accounts = makeAccounts(count: 5)
        let echoRecords = accounts
            .map(WalletSyncRecordMappers.dto(for:))
            .map(WalletSyncCKRecordAdapter.ckRecord(from:))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: echoRecords, changeTokenData: Data([1]))
        )
        let store = FakeFullDataStore(accounts: accounts)
        let applier = FakeFullDataApplier()
        let pipeline = makePipeline(boundary: boundary, store: store, applier: applier, uploadCap: 2)

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.batchCount, 3)
        XCTAssertEqual(summary.changedRecordCount, 5)
        XCTAssertEqual(summary.skippedLocalEchoCount, 5)
        XCTAssertEqual(summary.parsedValidCount, 0)
        XCTAssertEqual(applier.receivedPlan?.items.count, 0)
    }

    func testParserClassifiesAllTargetEntities() {
        let records = Self.supportedDTOs().map(WalletSyncCKRecordAdapter.ckRecord(from:))

        let result = WalletSyncInboxParser().parse(changedRecords: records, deletedRecordNames: [])

        XCTAssertEqual(result.validCount, Self.supportedEntities.count)
        XCTAssertEqual(Set(result.items.compactMap(\.entity)), Set(Self.supportedEntities))
    }

    func testPlannerBlocksUnsafeApplyPaths() {
        let dtos = [
            WalletSyncRecordMappers.dto(for: makeFinancialEvent()),
            WalletSyncRecordMappers.dto(for: makePersonDebtEntry()),
            WalletSyncRecordMappers.dto(for: makeCreditCardPurchase()),
            WalletSyncRecordMappers.dto(for: makeCreditCardPayment()),
            WalletSyncRecordMappers.dto(for: makeInstallmentPlan())
        ]
        let records = dtos.map(WalletSyncCKRecordAdapter.ckRecord(from:))

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: FakeFullDataStore())
            .makePlan(changedRecords: records, deletedRecordNames: [])

        XCTAssertEqual(plan.blockedCount, dtos.count)
        XCTAssertTrue(plan.items.allSatisfy {
            if case .blocked(let reason) = $0.action {
                return reason == .unsafeFinancialApply
            }
            return false
        })
    }

    func testPlannerAllowsOnlyMasterDataDirectUpdatePaths() {
        let store = FakeFullDataStore(
            accounts: [makeAccount()],
            categories: [makeCategory()],
            walletEvents: [makeWalletEvent()],
            merchantMemories: [makeMerchantMemory()]
        )
        let records = [
            WalletSyncRecordMappers.dto(for: makeAccount()),
            WalletSyncRecordMappers.dto(for: makeCategory()),
            WalletSyncRecordMappers.dto(for: makeWalletEvent()),
            WalletSyncRecordMappers.dto(for: makeMerchantMemory())
        ].map(WalletSyncCKRecordAdapter.ckRecord(from:))

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: store)
            .makePlan(changedRecords: records, deletedRecordNames: [])

        XCTAssertEqual(plan.plannedUpdateCount, 4)
        XCTAssertEqual(plan.plannedCreateCount, 0)
        XCTAssertEqual(plan.blockedCount, 0)
    }

    func testMerchantMemoryCreateAndUpdateApplyIsSafe() async throws {
        let existing = makeMerchantMemory(id: deterministicID(index: 200), usageCount: 1)
        let updated = makeMerchantMemory(id: existing.id, usageCount: 2)
        let created = makeMerchantMemory(id: deterministicID(index: 201), usageCount: 3)
        let records = [updated, created]
            .map(WalletSyncRecordMappers.dto(for:))
            .map(WalletSyncCKRecordAdapter.ckRecord(from:))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: records, changeTokenData: Data([1]))
        )
        let store = FakeFullDataStore(merchantMemories: [existing])
        let pipeline = makePipeline(boundary: boundary, store: store, applier: WalletSyncMasterDataApplier(store: store))

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.appliedCreatedCount, 1)
        XCTAssertEqual(summary.appliedUpdatedCount, 1)
        XCTAssertEqual(store.merchantMemories.count, 2)
        XCTAssertEqual(store.merchantMemories.first { $0.id == existing.id }?.usageCount, 2)
        XCTAssertEqual(store.financialEventMutationCount, 0)
    }

    func testHistoricalMonthlySummaryCreateAndUpdateApplyIsSafe() async throws {
        let existing = makeHistoricalMonthlySummaryEntry(id: deterministicID(index: 210), amount: 10)
        let updated = makeHistoricalMonthlySummaryEntry(id: existing.id, amount: 20)
        let created = makeHistoricalMonthlySummaryEntry(id: deterministicID(index: 211), amount: 30)
        let records = [updated, created]
            .map(WalletSyncRecordMappers.dto(for:))
            .map(WalletSyncCKRecordAdapter.ckRecord(from:))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: records, changeTokenData: Data([1]))
        )
        let store = FakeFullDataStore(historicalMonthlySummaries: [existing])
        let pipeline = makePipeline(boundary: boundary, store: store, applier: WalletSyncMasterDataApplier(store: store))

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.appliedCreatedCount, 1)
        XCTAssertEqual(summary.appliedUpdatedCount, 1)
        XCTAssertEqual(store.historicalMonthlySummaries.count, 2)
        XCTAssertEqual(store.historicalMonthlySummaries.first { $0.id == existing.id }?.amount, 20)
        XCTAssertEqual(store.balanceRecalculationCount, 0)
    }

    func testPersonDebtCreateAndUpdateApplyIsSafeWithoutDebtEntryApply() async throws {
        let existing = makePersonDebt(id: deterministicID(index: 220), originalAmount: 10)
        let updated = makePersonDebt(id: existing.id, originalAmount: 20)
        let created = makePersonDebt(id: deterministicID(index: 221), originalAmount: 30)
        let records = [updated, created]
            .map(WalletSyncRecordMappers.dto(for:))
            .map(WalletSyncCKRecordAdapter.ckRecord(from:))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: records, changeTokenData: Data([1]))
        )
        let store = FakeFullDataStore(personDebts: [existing])
        let pipeline = makePipeline(boundary: boundary, store: store, applier: WalletSyncMasterDataApplier(store: store))

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.appliedCreatedCount, 1)
        XCTAssertEqual(summary.appliedUpdatedCount, 1)
        XCTAssertEqual(store.personDebts.count, 2)
        XCTAssertEqual(store.personDebts.first { $0.id == existing.id }?.originalAmount, 20)
        XCTAssertEqual(store.personDebtEntryMutationCount, 0)
    }

    func testCreditCardCreateAndUpdateApplyIsSafeWithoutPaymentApply() async throws {
        let existing = makeCreditCard(id: deterministicID(index: 230), creditLimit: 1000)
        let updated = makeCreditCard(id: existing.id, creditLimit: 2000)
        let created = makeCreditCard(id: deterministicID(index: 231), creditLimit: 3000)
        let records = [updated, created]
            .map(WalletSyncRecordMappers.dto(for:))
            .map(WalletSyncCKRecordAdapter.ckRecord(from:))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: records, changeTokenData: Data([1]))
        )
        let store = FakeFullDataStore(creditCards: [existing])
        let pipeline = makePipeline(boundary: boundary, store: store, applier: WalletSyncMasterDataApplier(store: store))

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.appliedCreatedCount, 1)
        XCTAssertEqual(summary.appliedUpdatedCount, 1)
        XCTAssertEqual(store.creditCards.count, 2)
        XCTAssertEqual(store.creditCards.first { $0.id == existing.id }?.creditLimit, 2000)
        XCTAssertEqual(store.creditCardPaymentMutationCount, 0)
        XCTAssertEqual(store.balanceRecalculationCount, 0)
    }

    func testInstallmentPlanCreateAndUpdateApplyIsSafeWithoutGeneratedEvents() async throws {
        let existing = makeInstallmentPlan(id: deterministicID(index: 240), totalAmount: 100)
        let updated = makeInstallmentPlan(id: existing.id, totalAmount: 200)
        let created = makeInstallmentPlan(id: deterministicID(index: 241), totalAmount: 300)
        let records = [updated, created]
            .map(WalletSyncRecordMappers.dto(for:))
            .map(WalletSyncCKRecordAdapter.ckRecord(from:))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: records, changeTokenData: Data([1]))
        )
        let store = FakeFullDataStore(installmentPlans: [existing])
        let pipeline = makePipeline(boundary: boundary, store: store, applier: WalletSyncMasterDataApplier(store: store))

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.appliedCreatedCount, 1)
        XCTAssertEqual(summary.appliedUpdatedCount, 1)
        XCTAssertEqual(store.installmentPlans.count, 2)
        XCTAssertEqual(store.installmentPlans.first { $0.id == existing.id }?.totalAmount, 200)
        XCTAssertEqual(store.financialEventMutationCount, 0)
    }

    func testFullDataValidationDoesNotCallFinancialPostingOrRecalculateBalances() async throws {
        let remoteRecord = WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: makeFinancialEvent()))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [remoteRecord], changeTokenData: Data([1]))
        )
        let store = FakeFullDataStore(accounts: [makeAccount(balance: 500)])
        let pipeline = makePipeline(
            boundary: boundary,
            store: store,
            applier: WalletSyncMasterDataApplier(store: store)
        )

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.blockedCount, 1)
        XCTAssertEqual(summary.appliedBlockedCount, 1)
        XCTAssertEqual(store.accounts.first?.balance, 500)
        XCTAssertEqual(store.financialEventMutationCount, 0)
        XCTAssertEqual(store.balanceRecalculationCount, 0)
    }

    func testFinancialAppEntitiesAreUploadedButNotAppliedWhenEchoedFromAllBatches() async throws {
        let events = (0..<5).map { index in makeFinancialEvent(id: deterministicID(index: index + 100)) }
        let echoRecords = events
            .map(WalletSyncRecordMappers.dto(for:))
            .map(WalletSyncCKRecordAdapter.ckRecord(from:))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: echoRecords, changeTokenData: Data([1]))
        )
        let store = FakeFullDataStore(financialEvents: events)
        let pipeline = makePipeline(
            boundary: boundary,
            store: store,
            applier: WalletSyncMasterDataApplier(store: store),
            uploadCap: 2
        )

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.uploadedCountsByEntity[.financialEvent], 5)
        XCTAssertEqual(summary.skippedLocalEchoCount, 5)
        XCTAssertEqual(summary.appliedUpdatedCount, 0)
        XCTAssertEqual(store.financialEventMutationCount, 0)
    }

    func testCreditCardPaymentAndPersonDebtEntryDoNotDoubleApply() async throws {
        let records = [
            WalletSyncRecordMappers.dto(for: makeCreditCardPayment()),
            WalletSyncRecordMappers.dto(for: makePersonDebtEntry())
        ].map(WalletSyncCKRecordAdapter.ckRecord(from:))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: records, changeTokenData: Data([1]))
        )
        let store = FakeFullDataStore()
        let pipeline = makePipeline(
            boundary: boundary,
            store: store,
            applier: WalletSyncMasterDataApplier(store: store)
        )

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.blockedCount, 2)
        XCTAssertEqual(summary.appliedBlockedCount, 2)
        XCTAssertEqual(store.creditCardPaymentMutationCount, 0)
        XCTAssertEqual(store.personDebtEntryMutationCount, 0)
    }

    func testRecurringAndFutureEventsAreNotMarkedPaidAndFutureIncomeIsNotReceived() async throws {
        var recurring = makeFinancialEvent(status: .unpaid)
        recurring.repeatRule = .monthly
        recurring.sourceRecurringEventID = UUID()
        recurring.recurringOccurrenceYear = 2026
        recurring.recurringOccurrenceMonth = 7
        var income = makeFinancialEvent(status: .unpaid)
        income.type = .income
        income.date = Date(timeIntervalSince1970: 1_900_000_000)
        let records = [
            WalletSyncRecordMappers.dto(for: recurring),
            WalletSyncRecordMappers.dto(for: income)
        ].map(WalletSyncCKRecordAdapter.ckRecord(from:))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: records, changeTokenData: Data([1]))
        )
        let store = FakeFullDataStore()
        let pipeline = makePipeline(
            boundary: boundary,
            store: store,
            applier: WalletSyncMasterDataApplier(store: store)
        )

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.blockedCount, 2)
        XCTAssertEqual(store.paidMutationCount, 0)
        XCTAssertEqual(store.futureIncomeReceivedCount, 0)
    }

    func testUnsupportedEntitiesAreBlockedWithSafeReason() {
        let itemDTO = WalletSyncRecordMappers.dto(for: makeMonthlyBudgetItem())
        let settingsDTO = WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .householdSettings, id: UUID()),
            updatedAt: Date()
        )
        let records = [itemDTO, settingsDTO].map(WalletSyncCKRecordAdapter.ckRecord(from:))

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: FakeFullDataStore())
            .makePlan(changedRecords: records, deletedRecordNames: [])

        XCTAssertEqual(plan.blockedCount, 2)
        XCTAssertTrue(plan.items.contains {
            if case .blocked(let reason) = $0.action { return reason == .monthlyBudgetItemNoParent }
            return false
        })
        XCTAssertTrue(plan.items.contains {
            if case .blocked(let reason) = $0.action { return reason == .householdSettingsNoModel }
            return false
        })
    }

    func testFinancialPaymentPurchaseDebtEntryAndMonthlyBudgetRemainBlocked() {
        let records = [
            WalletSyncRecordMappers.dto(for: makeFinancialEvent()),
            WalletSyncRecordMappers.dto(for: makeCreditCardPayment()),
            WalletSyncRecordMappers.dto(for: makeCreditCardPurchase()),
            WalletSyncRecordMappers.dto(for: makePersonDebtEntry()),
            WalletSyncRecordMappers.dto(for: makeMonthlyBudget())
        ].map(WalletSyncCKRecordAdapter.ckRecord(from:))

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: FakeFullDataStore())
            .makePlan(changedRecords: records, deletedRecordNames: [])

        XCTAssertEqual(plan.blockedCount, 5)
        XCTAssertEqual(plan.plannedCreateCount, 0)
        XCTAssertEqual(plan.plannedUpdateCount, 0)
    }

    func testLaterBatchFailureIsReportedByThrowingWithoutFetchOrTokenSave() async throws {
        let boundary = FakeFullDataBoundary(failingSaveBatchIndex: 1)
        let tokenStore = FakeFullDataTokenStore()
        let store = FakeFullDataStore(accounts: makeAccounts(count: 5))
        let pipeline = makePipeline(
            boundary: boundary,
            tokenStore: tokenStore,
            store: store,
            uploadCap: 2
        )

        do {
            _ = try await pipeline.run()
            XCTFail("Expected later batch failure")
        } catch {
            XCTAssertEqual(boundary.savedRecordBatches.map(\.count), [2])
            XCTAssertEqual(boundary.fetchCallCount, 0)
            XCTAssertNil(tokenStore.token)
        }
    }

    func testTokenSavingOnlyHappensWhenFetchReturnsToken() async throws {
        let withoutTokenBoundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [], changeTokenData: nil)
        )
        let withoutTokenStore = FakeFullDataTokenStore()
        let withoutTokenPipeline = makePipeline(
            boundary: withoutTokenBoundary,
            tokenStore: withoutTokenStore,
            store: FakeFullDataStore(accounts: [makeAccount()])
        )

        let withoutTokenSummary = try await withoutTokenPipeline.run()

        XCTAssertFalse(withoutTokenSummary.tokenSaved)
        XCTAssertNil(withoutTokenStore.token)

        let token = Data([9, 9])
        let withTokenBoundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [], changeTokenData: token)
        )
        let withTokenStore = FakeFullDataTokenStore()
        let withTokenPipeline = makePipeline(
            boundary: withTokenBoundary,
            tokenStore: withTokenStore,
            store: FakeFullDataStore(accounts: [makeAccount()])
        )

        let withTokenSummary = try await withTokenPipeline.run()

        XCTAssertTrue(withTokenSummary.tokenSaved)
        XCTAssertEqual(withTokenStore.token, token)
    }

    func testNoWalletICloudSyncServiceDependencyIsIntroduced() {
        let pipeline = makePipeline(boundary: FakeFullDataBoundary(), store: FakeFullDataStore())
        let propertyNames = Mirror(reflecting: pipeline).children.compactMap { $0.label?.lowercased() }

        XCTAssertFalse(propertyNames.contains { $0.contains("walleticloudsyncservice") })
    }

    func testNoBackupImportExportDependencyIsIntroduced() {
        let pipeline = makePipeline(boundary: FakeFullDataBoundary(), store: FakeFullDataStore())
        let propertyNames = Mirror(reflecting: pipeline).children.compactMap { $0.label?.lowercased() }

        XCTAssertFalse(propertyNames.contains { $0.contains("backup") })
        XCTAssertFalse(propertyNames.contains { $0.contains("import") })
        XCTAssertFalse(propertyNames.contains { $0.contains("export") })
    }

    private static let supportedEntities: [WalletSyncRecordEntity] = [
        .account,
        .category,
        .walletEvent,
        .financialEvent,
        .monthlyBudget,
        .personDebt,
        .personDebtEntry,
        .creditCard,
        .creditCardPurchase,
        .creditCardPayment,
        .installmentPlan,
        .historicalMonthlySummary,
        .merchantMemory
    ]

    private static func supportedDTOs() -> [WalletSyncRecordDTO] {
        [
            WalletSyncRecordMappers.dto(for: makeAccount()),
            WalletSyncRecordMappers.dto(for: makeCategory()),
            WalletSyncRecordMappers.dto(for: makeWalletEvent()),
            WalletSyncRecordMappers.dto(for: makeFinancialEvent()),
            WalletSyncRecordMappers.dto(for: makeMonthlyBudget()),
            WalletSyncRecordMappers.dto(for: makePersonDebt()),
            WalletSyncRecordMappers.dto(for: makePersonDebtEntry()),
            WalletSyncRecordMappers.dto(for: makeCreditCard()),
            WalletSyncRecordMappers.dto(for: makeCreditCardPurchase()),
            WalletSyncRecordMappers.dto(for: makeCreditCardPayment()),
            WalletSyncRecordMappers.dto(for: makeInstallmentPlan()),
            WalletSyncRecordMappers.dto(for: makeHistoricalMonthlySummaryEntry()),
            WalletSyncRecordMappers.dto(for: makeMerchantMemory())
        ]
    }

    private func makePipeline(
        boundary: FakeFullDataBoundary,
        tokenStore: FakeFullDataTokenStore = FakeFullDataTokenStore(),
        store: FakeFullDataStore,
        applier: WalletSyncMasterDataPlanApplying? = nil,
        uploadCap: Int = WalletSyncFullDataRecordValidationPipeline.defaultUploadCap
    ) -> WalletSyncFullDataRecordValidationPipeline {
        WalletSyncFullDataRecordValidationPipeline(
            zoneEnsurer: boundary,
            recordSaver: boundary,
            changedRecordFetcher: boundary,
            tokenStore: tokenStore,
            source: store,
            localState: store,
            inboxParser: WalletSyncInboxParser(),
            applier: applier ?? FakeFullDataApplier(),
            uploadCap: uploadCap
        )
    }
}

private final class FakeFullDataBoundary: WalletSyncMasterDataZoneEnsuring, WalletSyncMasterDataRecordSaving, WalletSyncDryRunChangedRecordFetching {
    var savedRecords: [CKRecord] = []
    var savedRecordBatches: [[CKRecord]] = []
    var events: [String] = []
    var fetchCallCount = 0
    var fetchResult: WalletSyncCloudKitFetchResult
    var failingSaveBatchIndex: Int?

    init(
        fetchResult: WalletSyncCloudKitFetchResult = WalletSyncCloudKitFetchResult(records: []),
        failingSaveBatchIndex: Int? = nil
    ) {
        self.fetchResult = fetchResult
        self.failingSaveBatchIndex = failingSaveBatchIndex
    }

    func ensureSyncZone() async throws {
        events.append("ensure")
    }

    func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord] {
        events.append("save")
        if savedRecordBatches.count == failingSaveBatchIndex {
            throw FakeFullDataBoundaryError.saveFailed
        }
        savedRecordBatches.append(records)
        savedRecords.append(contentsOf: records)
        return records
    }

    func fetchChangedRecords(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult {
        events.append("fetch")
        fetchCallCount += 1
        return fetchResult
    }

    enum FakeFullDataBoundaryError: Error {
        case saveFailed
    }
}

private final class FakeFullDataTokenStore: WalletSyncChangeTokenStoring {
    var token: Data?

    func loadWalletSyncZoneChangeTokenData() -> Data? { token }
    func saveWalletSyncZoneChangeTokenData(_ tokenData: Data) { token = tokenData }
    func clearWalletSyncZoneChangeTokenData() { token = nil }
    func hasWalletSyncZoneChangeToken() -> Bool { token != nil }
}

private final class FakeFullDataApplier: WalletSyncMasterDataPlanApplying {
    var receivedPlan: WalletSyncMasterDataApplyPlanSummary?

    func apply(_ plan: WalletSyncMasterDataApplyPlanSummary) -> WalletSyncMasterDataApplyResult {
        receivedPlan = plan
        return WalletSyncMasterDataApplyResult(
            createdCount: plan.plannedCreateCount,
            updatedCount: plan.plannedUpdateCount,
            disabledCount: plan.plannedDisableCount,
            blockedCount: plan.blockedCount,
            failedCount: plan.failedCount
        )
    }
}

private final class FakeFullDataStore: WalletSyncFullDataSourceReading, WalletSyncMergePlanLocalStateReading, WalletSyncMasterDataApplyingStore {
    var accounts: [Account]
    var categories: [WalletBoard.Category]
    var walletEvents: [WalletEvent]
    var merchantMemories: [MerchantMemory]
    var installmentPlans: [InstallmentPlan]
    var financialEvents: [FinancialEvent] {
        didSet { financialEventMutationCount += 1 }
    }
    var monthlyBudgets: [WalletMonthlyBudget] {
        didSet { budgetMutationCount += 1 }
    }
    var personDebts: [PersonDebt]
    var personDebtEntries: [PersonDebtEntry] {
        didSet { personDebtEntryMutationCount += 1 }
    }
    var creditCards: [CreditCard]
    var creditCardPurchases: [CreditCardPurchase]
    var creditCardPayments: [CreditCardPayment] {
        didSet { creditCardPaymentMutationCount += 1 }
    }
    var historicalMonthlySummaries: [HistoricalMonthlySummaryEntry]

    var financialEventMutationCount = 0
    var budgetMutationCount = 0
    var creditCardPaymentMutationCount = 0
    var personDebtEntryMutationCount = 0
    var balanceRecalculationCount = 0
    var paidMutationCount = 0
    var futureIncomeReceivedCount = 0

    init(
        accounts: [Account] = [],
        categories: [WalletBoard.Category] = [],
        walletEvents: [WalletEvent] = [],
        merchantMemories: [MerchantMemory] = [],
        installmentPlans: [InstallmentPlan] = [],
        financialEvents: [FinancialEvent] = [],
        monthlyBudgets: [WalletMonthlyBudget] = [],
        personDebts: [PersonDebt] = [],
        personDebtEntries: [PersonDebtEntry] = [],
        creditCards: [CreditCard] = [],
        creditCardPurchases: [CreditCardPurchase] = [],
        creditCardPayments: [CreditCardPayment] = [],
        historicalMonthlySummaries: [HistoricalMonthlySummaryEntry] = []
    ) {
        self.accounts = accounts
        self.categories = categories
        self.walletEvents = walletEvents
        self.merchantMemories = merchantMemories
        self.installmentPlans = installmentPlans
        self.financialEvents = financialEvents
        self.monthlyBudgets = monthlyBudgets
        self.personDebts = personDebts
        self.personDebtEntries = personDebtEntries
        self.creditCards = creditCards
        self.creditCardPurchases = creditCardPurchases
        self.creditCardPayments = creditCardPayments
        self.historicalMonthlySummaries = historicalMonthlySummaries
    }

    static func withOneOfEachSupportedEntity() -> FakeFullDataStore {
        FakeFullDataStore(
            accounts: [makeAccount()],
            categories: [makeCategory()],
            walletEvents: [makeWalletEvent()],
            merchantMemories: [makeMerchantMemory()],
            installmentPlans: [makeInstallmentPlan()],
            financialEvents: [makeFinancialEvent()],
            monthlyBudgets: [makeMonthlyBudget()],
            personDebts: [makePersonDebt()],
            personDebtEntries: [makePersonDebtEntry()],
            creditCards: [makeCreditCard()],
            creditCardPurchases: [makeCreditCardPurchase()],
            creditCardPayments: [makeCreditCardPayment()],
            historicalMonthlySummaries: [makeHistoricalMonthlySummaryEntry()]
        )
    }

    func containsAccount(id: UUID) -> Bool { accounts.contains { $0.id == id } }
    func containsCategory(id: UUID) -> Bool { categories.contains { $0.id == id } }
    func containsWalletEvent(id: UUID) -> Bool { walletEvents.contains { $0.id == id } }
    func containsMerchantMemory(id: UUID) -> Bool { merchantMemories.contains { $0.id == id } }
    func containsHistoricalMonthlySummary(id: UUID) -> Bool { historicalMonthlySummaries.contains { $0.id == id } }
    func containsPersonDebt(id: UUID) -> Bool { personDebts.contains { $0.id == id } }
    func containsCreditCard(id: UUID) -> Bool { creditCards.contains { $0.id == id } }
    func containsInstallmentPlan(id: UUID) -> Bool { installmentPlans.contains { $0.id == id } }
}

private func makeAccount(id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, balance: Double = 0) -> Account {
    Account(id: id, name: "Cash", balance: balance, type: .cash)
}

private func makeAccounts(count: Int) -> [Account] {
    (0..<count).map { index in
        makeAccount(id: deterministicID(index: index + 1))
    }
}

private func deterministicID(index: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
}

private func makeCategory(id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!) -> WalletBoard.Category {
    WalletBoard.Category(id: id, name: "Food", subcategories: ["Groceries"])
}

private func makeWalletEvent(id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!) -> WalletEvent {
    var event = WalletEvent(
        name: "Groceries",
        categoryName: "Food",
        subCategoryName: "Groceries",
        defaultAccountName: nil,
        isFavorite: false
    )
    event.id = id
    return event
}

private func makeFinancialEvent(
    id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
    status: FinancialEventStatus = .unpaid
) -> FinancialEvent {
    var event = FinancialEvent(
        type: .expense,
        status: status,
        title: "Remote Event",
        amount: 100,
        date: Date(timeIntervalSince1970: 1_800_000_000)
    )
    event.id = id
    return event
}

private func makeMonthlyBudget() -> WalletMonthlyBudget {
    WalletMonthlyBudget(year: 2026, month: 6, items: [])
}

private func makeMonthlyBudgetItem() -> WalletMonthlyBudgetItem {
    WalletMonthlyBudgetItem(categoryName: "Food", plannedAmount: 500)
}

private func makePersonDebt(
    id: UUID = UUID(),
    originalAmount: Double = 300
) -> PersonDebt {
    var debt = PersonDebt(personName: "Person", kind: .owedToMe, originalAmount: originalAmount)
    debt.id = id
    return debt
}

private func makePersonDebtEntry() -> PersonDebtEntry {
    PersonDebtEntry(
        debtID: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        entryType: .repaymentReceived,
        amount: 50,
        accountName: "Cash",
        date: Date(timeIntervalSince1970: 1_800_000_000)
    )
}

private func makeCreditCard(
    id: UUID = UUID(),
    creditLimit: Double = 10_000
) -> CreditCard {
    CreditCard(
        id: id,
        name: "Visa",
        bankName: "Bank",
        cardNetwork: .visa,
        creditLimit: creditLimit,
        statementClosingDay: 25,
        paymentDueDay: 10
    )
}

private func makeCreditCardPurchase() -> CreditCardPurchase {
    CreditCardPurchase(
        id: UUID(),
        cardID: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        title: "Laptop",
        amount: 2_000,
        purchaseDate: Date(timeIntervalSince1970: 1_800_000_000),
        categoryName: "Electronics",
        subCategoryName: "Computers",
        note: nil,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
}

private func makeCreditCardPayment() -> CreditCardPayment {
    CreditCardPayment(
        id: UUID(),
        cardID: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        fromAccountName: "Cash",
        amount: 1_000,
        paymentDate: Date(timeIntervalSince1970: 1_800_000_000),
        note: nil,
        createdAt: Date(timeIntervalSince1970: 1_800_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
    )
}

private func makeInstallmentPlan(
    id: UUID = UUID(),
    totalAmount: Double = 1_200
) -> InstallmentPlan {
    InstallmentPlan(
        id: id,
        purchaseName: "Phone",
        totalAmount: totalAmount,
        installmentCount: 12,
        firstDueDate: Date(timeIntervalSince1970: 1_800_000_000),
        categoryName: "Electronics",
        subCategoryName: "Phones"
    )
}

private func makeHistoricalMonthlySummaryEntry(
    id: UUID = UUID(),
    amount: Double = 300
) -> HistoricalMonthlySummaryEntry {
    HistoricalMonthlySummaryEntry(
        id: id,
        year: 2025,
        month: 12,
        categoryName: "Food",
        subCategoryName: "Groceries",
        amount: amount
    )
}

private func makeMerchantMemory(
    id: UUID = UUID(),
    usageCount: Int = 1
) -> MerchantMemory {
    var memory = MerchantMemory(
        merchantName: "Merchant",
        defaultCategoryName: "Food",
        defaultSubCategoryName: "Groceries",
        defaultAccountName: nil,
        usageCount: usageCount
    )
    memory.id = id
    return memory
}
