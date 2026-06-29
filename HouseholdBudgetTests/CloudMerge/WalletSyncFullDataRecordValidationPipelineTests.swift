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

    func testUploadIncludesLocalFinancialEventDeletionMarkers() async throws {
        let boundary = FakeFullDataBoundary()
        let deletedID = UUID()
        let deletedAt = Date(timeIntervalSince1970: 1_800_001_000)
        let deletionStore = FakeFinancialEventDeletionStore(deletedAtByID: [deletedID: deletedAt])
        let pipeline = makePipeline(
            boundary: boundary,
            store: FakeFullDataStore(),
            localFinancialEventDeletionStore: deletionStore
        )

        let summary = try await pipeline.run()
        let uploadedDTOs = try boundary.savedRecords.map { try WalletSyncCKRecordAdapter.dto(from: $0) }

        XCTAssertEqual(summary.uploadedCountsByEntity[.financialEventDeletion], 1)
        XCTAssertEqual(uploadedDTOs.first?.entity, .financialEventDeletion)
        XCTAssertEqual(uploadedDTOs.first?.id, deletedID)
        XCTAssertEqual(uploadedDTOs.first?.deletedAt, deletedAt)
        XCTAssertEqual(uploadedDTOs.first?.isDeleted, true)
    }

    func testUploadIncludesLocalInstallmentPlanDeletionMarkers() async throws {
        let boundary = FakeFullDataBoundary()
        let deletedID = UUID()
        let deletedAt = Date(timeIntervalSince1970: 1_800_001_500)
        let deletionStore = FakeInstallmentPlanDeletionStore(deletedAtByID: [deletedID: deletedAt])
        let pipeline = makePipeline(
            boundary: boundary,
            store: FakeFullDataStore(),
            localInstallmentPlanDeletionStore: deletionStore
        )

        let summary = try await pipeline.run()
        let uploadedDTOs = try boundary.savedRecords.map { try WalletSyncCKRecordAdapter.dto(from: $0) }

        XCTAssertEqual(summary.uploadedCountsByEntity[.installmentPlanDeletion], 1)
        XCTAssertEqual(uploadedDTOs.first?.entity, .installmentPlanDeletion)
        XCTAssertEqual(uploadedDTOs.first?.id, deletedID)
        XCTAssertEqual(uploadedDTOs.first?.deletedAt, deletedAt)
        XCTAssertEqual(uploadedDTOs.first?.isDeleted, true)
    }

    func testUploadIncludesLocalHighRiskDeletionMarkers() async throws {
        let boundary = FakeFullDataBoundary()
        let purchaseID = UUID()
        let paymentID = UUID()
        let debtID = UUID()
        let entryID = UUID()
        let budgetItemID = UUID()
        let deletedAt = Date(timeIntervalSince1970: 1_800_002_000)
        let deletionStore = FakeHighRiskRecordDeletionStore(deletedAtByRecord: [
            WalletSyncRecordEntity.creditCardPurchase.recordName(for: purchaseID): deletedAt,
            WalletSyncRecordEntity.creditCardPayment.recordName(for: paymentID): deletedAt,
            WalletSyncRecordEntity.personDebt.recordName(for: debtID): deletedAt,
            WalletSyncRecordEntity.personDebtEntry.recordName(for: entryID): deletedAt,
            WalletSyncRecordEntity.monthlyBudgetItem.recordName(for: budgetItemID): deletedAt
        ])
        let pipeline = makePipeline(
            boundary: boundary,
            store: FakeFullDataStore(),
            localHighRiskRecordDeletionStore: deletionStore
        )

        let summary = try await pipeline.run()
        let uploadedDTOs = try boundary.savedRecords.map { try WalletSyncCKRecordAdapter.dto(from: $0) }

        XCTAssertEqual(summary.uploadedCountsByEntity[.creditCardPurchaseDeletion], 1)
        XCTAssertEqual(summary.uploadedCountsByEntity[.creditCardPaymentDeletion], 1)
        XCTAssertEqual(summary.uploadedCountsByEntity[.personDebtDeletion], 1)
        XCTAssertEqual(summary.uploadedCountsByEntity[.personDebtEntryDeletion], 1)
        XCTAssertEqual(summary.uploadedCountsByEntity[.monthlyBudgetItemDeletion], 1)
        XCTAssertEqual(
            Set(uploadedDTOs.map(\.entity)),
            [
                .creditCardPurchaseDeletion,
                .creditCardPaymentDeletion,
                .personDebtDeletion,
                .personDebtEntryDeletion,
                .monthlyBudgetItemDeletion
            ]
        )
        XCTAssertTrue(uploadedDTOs.allSatisfy { $0.deletedAt == deletedAt && $0.isDeleted })
        XCTAssertTrue(uploadedDTOs.contains { $0.entity == .creditCardPurchaseDeletion && $0.id == purchaseID })
        XCTAssertTrue(uploadedDTOs.contains { $0.entity == .creditCardPaymentDeletion && $0.id == paymentID })
        XCTAssertTrue(uploadedDTOs.contains { $0.entity == .personDebtDeletion && $0.id == debtID })
        XCTAssertTrue(uploadedDTOs.contains { $0.entity == .personDebtEntryDeletion && $0.id == entryID })
        XCTAssertTrue(uploadedDTOs.contains { $0.entity == .monthlyBudgetItemDeletion && $0.id == budgetItemID })
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
        XCTAssertEqual(boundary.events, ["ensure", "fetch", "save", "save", "save", "fetch"])
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

    func testUploadExcludesOnlyHouseholdSettings() async throws {
        let boundary = FakeFullDataBoundary()
        let store = FakeFullDataStore.withOneOfEachSupportedEntity()
        let pipeline = makePipeline(boundary: boundary, store: store)

        let summary = try await pipeline.run()
        let uploadedEntities = try boundary.savedRecords.map { try WalletSyncCKRecordAdapter.dto(from: $0).entity }

        XCTAssertFalse(uploadedEntities.contains(.householdSettings))
        XCTAssertEqual(summary.excludedEntities, [.householdSettings])
    }

    func testLocalEchoGuardStillPreventsSelfApply() async throws {
        let financialEvent = makeFinancialEvent()
        let echoRecord = WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: financialEvent))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [echoRecord], changeTokenData: Data([1]))
        )
        let store = FakeFullDataStore(financialEvents: [financialEvent])
        let applier = FakeFullDataApplier()
        let pipeline = makePipeline(
            boundary: boundary,
            tokenStore: FakeFullDataTokenStore(token: Data([9])),
            store: store,
            applier: applier
        )

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
        let pipeline = makePipeline(
            boundary: boundary,
            tokenStore: FakeFullDataTokenStore(token: Data([9])),
            store: store,
            applier: applier,
            uploadCap: 2
        )

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.batchCount, 3)
        XCTAssertEqual(summary.changedRecordCount, 5)
        XCTAssertEqual(summary.skippedLocalEchoCount, 5)
        XCTAssertEqual(summary.parsedValidCount, 0)
        XCTAssertEqual(applier.receivedPlan?.items.count, 0)
    }

    func testLocalEchoParentDoesNotAuthorizeNonEchoChildPlanning() async throws {
        let card = makeCreditCard(id: deterministicID(index: 430))
        let purchase = makeCreditCardPurchase(id: deterministicID(index: 431), cardID: card.id)
        let parentEcho = WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: card))
        let childRecord = WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: purchase))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [parentEcho, childRecord], changeTokenData: Data([1]))
        )
        let source = FakeFullDataStore(creditCards: [card])
        let localState = FakeFullDataStore()
        let applier = FakeFullDataApplier()
        let pipeline = WalletSyncFullDataRecordValidationPipeline(
            zoneEnsurer: boundary,
            recordSaver: boundary,
            changedRecordFetcher: boundary,
            tokenStore: FakeFullDataTokenStore(token: Data([9])),
            source: source,
            localState: localState,
            inboxParser: WalletSyncInboxParser(),
            applier: applier
        )

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.skippedLocalEchoCount, 1)
        XCTAssertEqual(summary.blockedCount, 1)
        XCTAssertTrue(applier.receivedPlan?.items.contains {
            if case .blocked(let reason) = $0.action { return reason == .missingParentRecord }
            return false
        } ?? false)
    }

    func testParserClassifiesAllTargetEntities() {
        let records = Self.supportedDTOs().map(WalletSyncCKRecordAdapter.ckRecord(from:))

        let result = WalletSyncInboxParser().parse(changedRecords: records, deletedRecordNames: [])

        XCTAssertEqual(result.validCount, Self.supportedEntities.count)
        XCTAssertEqual(Set(result.items.compactMap(\.entity)), Set(Self.supportedEntities))
    }

    func testPlannerBlocksChildApplyWithoutParents() {
        let dtos = [
            WalletSyncRecordMappers.dto(for: makePersonDebtEntry()),
            WalletSyncRecordMappers.dto(for: makeCreditCardPurchase()),
            WalletSyncRecordMappers.dto(for: makeCreditCardPayment())
        ]
        let records = dtos.map(WalletSyncCKRecordAdapter.ckRecord(from:))

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: FakeFullDataStore())
            .makePlan(changedRecords: records, deletedRecordNames: [])

        XCTAssertEqual(plan.blockedCount, dtos.count)
        XCTAssertTrue(plan.items.allSatisfy {
            if case .blocked(let reason) = $0.action {
                return reason == .missingParentRecord
            }
            return false
        })
    }

    func testFinancialEventCreateAppendsByIDOnlyWithoutPosting() async throws {
        let event = makeFinancialEvent(id: deterministicID(index: 300), updatedAt: Date(timeIntervalSince1970: 1_800_000_100))
        let record = WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: event))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [record], changeTokenData: Data([1]))
        )
        let store = FakeFullDataStore(accounts: [makeAccount(balance: 500)])
        let pipeline = makePipeline(
            boundary: boundary,
            store: store,
            applier: WalletSyncMasterDataApplier(store: store)
        )

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.appliedCreatedCount, 1)
        XCTAssertEqual(store.financialEvents.map(\.id), [event.id])
        XCTAssertEqual(store.accounts.first?.balance, 500)
        XCTAssertEqual(store.postingCallCount, 0)
        XCTAssertEqual(store.balanceRecalculationCount, 0)
    }

    func testFinancialEventUpdateReplacesByIDOnlyWithoutDuplicate() async throws {
        let id = deterministicID(index: 301)
        let local = makeFinancialEvent(id: id, amount: 10, updatedAt: Date(timeIntervalSince1970: 1_800_000_000))
        let remote = makeFinancialEvent(id: id, amount: 20, updatedAt: Date(timeIntervalSince1970: 1_800_000_100))
        let record = WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: remote))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [record], changeTokenData: Data([1]))
        )
        let store = FakeFullDataStore(accounts: [makeAccount(balance: 500)], financialEvents: [local])
        let pipeline = makePipeline(
            boundary: boundary,
            store: store,
            applier: WalletSyncMasterDataApplier(store: store)
        )

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.appliedUpdatedCount, 1)
        XCTAssertEqual(store.financialEvents.count, 1)
        XCTAssertEqual(store.financialEvents.first?.amount, 20)
        XCTAssertEqual(store.accounts.first?.balance, 500)
        XCTAssertEqual(store.postingCallCount, 0)
        XCTAssertEqual(store.balanceRecalculationCount, 0)
    }

    func testFinancialEventDeleteRemainsBlocked() {
        let id = deterministicID(index: 302)
        let deletedRecordName = WalletSyncRecordEntity.financialEvent.recordName(for: id)

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: FakeFullDataStore(financialEvents: [makeFinancialEvent(id: id)]))
            .makePlan(changedRecords: [], deletedRecordNames: [deletedRecordName])

        XCTAssertEqual(plan.blockedCount, 1)
        XCTAssertEqual(plan.plannedDisableCount, 0)
    }

    func testFinancialEventUpdateBlocksWhenLocalIsNewer() {
        let id = deterministicID(index: 303)
        let local = makeFinancialEvent(id: id, updatedAt: Date(timeIntervalSince1970: 1_800_000_200))
        let remote = makeFinancialEvent(id: id, updatedAt: Date(timeIntervalSince1970: 1_800_000_100))
        let record = WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: remote))

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: FakeFullDataStore(financialEvents: [local]))
            .makePlan(changedRecords: [record], deletedRecordNames: [])

        XCTAssertEqual(plan.blockedCount, 1)
        XCTAssertTrue(plan.items.contains {
            if case .blocked(let reason) = $0.action { return reason == .localFinancialEventNewer }
            return false
        })
    }

    func testFinancialEventUpdateBlocksWhenTimestampsAreAmbiguous() {
        let id = deterministicID(index: 304)
        let local = makeFinancialEvent(id: id, updatedAt: Date(timeIntervalSince1970: 1_800_000_100))
        var dto = WalletSyncRecordMappers.dto(for: makeFinancialEvent(id: id, updatedAt: Date(timeIntervalSince1970: 1_800_000_100)))
        dto.updatedAt = nil
        let record = WalletSyncCKRecordAdapter.ckRecord(from: dto)

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: FakeFullDataStore(financialEvents: [local]))
            .makePlan(changedRecords: [record], deletedRecordNames: [])

        XCTAssertEqual(plan.blockedCount, 1)
        XCTAssertTrue(plan.items.contains {
            if case .blocked(let reason) = $0.action { return reason == .ambiguousFinancialEventTimestamp }
            return false
        })
    }

    func testFutureFinancialEventAndFutureIncomeRemainUnpaidAndFuture() async throws {
        let futureDate = Date(timeIntervalSince1970: 1_900_000_000)
        var futureExpense = makeFinancialEvent(
            id: deterministicID(index: 305),
            status: .unpaid,
            date: futureDate,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_100)
        )
        futureExpense.repeatRule = .monthly
        var futureIncome = makeFinancialEvent(
            id: deterministicID(index: 306),
            status: .unpaid,
            date: futureDate,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_100)
        )
        futureIncome.type = .income
        let records = [futureExpense, futureIncome]
            .map(WalletSyncRecordMappers.dto(for:))
            .map(WalletSyncCKRecordAdapter.ckRecord(from:))
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

        XCTAssertEqual(summary.appliedCreatedCount, 2)
        XCTAssertTrue(store.financialEvents.allSatisfy { $0.status == .unpaid && $0.date == futureDate })
        XCTAssertEqual(store.paidMutationCount, 0)
        XCTAssertEqual(store.futureIncomeReceivedCount, 0)
    }

    func testRecurringPaidOccurrenceIdentityIsPreservedWithoutDuplication() async throws {
        var occurrence = makeFinancialEvent(
            id: deterministicID(index: 307),
            status: .paid,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_100)
        )
        occurrence.sourceRecurringEventID = deterministicID(index: 308)
        occurrence.recurringOccurrenceYear = 2026
        occurrence.recurringOccurrenceMonth = 7
        let record = WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: occurrence))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [record], changeTokenData: Data([1]))
        )
        let store = FakeFullDataStore()
        let pipeline = makePipeline(
            boundary: boundary,
            store: store,
            applier: WalletSyncMasterDataApplier(store: store)
        )

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.appliedCreatedCount, 1)
        XCTAssertEqual(store.financialEvents.count, 1)
        XCTAssertEqual(store.financialEvents.first?.recurringPaidOccurrenceIdentity, occurrence.recurringPaidOccurrenceIdentity)
        XCTAssertEqual(store.paidMutationCount, 0)
    }

    func testCreditCardPurchaseCreateAndUpdateApplyByIDOnly() {
        let card = makeCreditCard(id: deterministicID(index: 320))
        let existing = makeCreditCardPurchase(id: deterministicID(index: 321), cardID: card.id, amount: 10)
        let updated = makeCreditCardPurchase(id: existing.id, cardID: card.id, amount: 20)
        let created = makeCreditCardPurchase(id: deterministicID(index: 322), cardID: card.id, amount: 30)
        let store = FakeFullDataStore(
            creditCards: [card],
            creditCardPurchases: [existing]
        )
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makePlanItem(action: .updateCreditCardPurchase(updated), entity: .creditCardPurchase, id: updated.id),
            makePlanItem(action: .createCreditCardPurchase(created), entity: .creditCardPurchase, id: created.id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.updatedCount, 1)
        XCTAssertEqual(result.createdCount, 1)
        XCTAssertEqual(store.creditCardPurchases.count, 2)
        XCTAssertEqual(store.creditCardPurchases.first { $0.id == existing.id }?.amount, 20)
        XCTAssertEqual(store.cardOutstandingMutationCount, 0)
        XCTAssertEqual(store.financialEventMutationCount, 0)
    }

    func testCreditCardPaymentCreateAndUpdateApplyByIDOnlyWithoutBalances() {
        let card = makeCreditCard(id: deterministicID(index: 330))
        let account = makeAccount(balance: 500)
        let existing = makeCreditCardPayment(id: deterministicID(index: 331), cardID: card.id, amount: 10)
        let updated = makeCreditCardPayment(id: existing.id, cardID: card.id, amount: 20)
        let created = makeCreditCardPayment(id: deterministicID(index: 332), cardID: card.id, amount: 30)
        let store = FakeFullDataStore(
            accounts: [account],
            creditCards: [card],
            creditCardPayments: [existing]
        )
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makePlanItem(action: .updateCreditCardPayment(updated), entity: .creditCardPayment, id: updated.id),
            makePlanItem(action: .createCreditCardPayment(created), entity: .creditCardPayment, id: created.id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.updatedCount, 1)
        XCTAssertEqual(result.createdCount, 1)
        XCTAssertEqual(store.creditCardPayments.count, 2)
        XCTAssertEqual(store.creditCardPayments.first { $0.id == existing.id }?.amount, 20)
        XCTAssertEqual(store.accounts.first?.balance, 500)
        XCTAssertEqual(store.creditCardPaymentApplyCount, 0)
        XCTAssertEqual(store.cardOutstandingMutationCount, 0)
    }

    func testPersonDebtEntryCreateAndUpdateApplyByIDOnlyWithoutSettlement() {
        let debt = makePersonDebt(id: deterministicID(index: 340), originalAmount: 100)
        let account = makeAccount(balance: 500)
        let existing = makePersonDebtEntry(id: deterministicID(index: 341), debtID: debt.id, amount: 10)
        let updated = makePersonDebtEntry(id: existing.id, debtID: debt.id, amount: 20)
        let created = makePersonDebtEntry(id: deterministicID(index: 342), debtID: debt.id, amount: 30)
        let store = FakeFullDataStore(
            accounts: [account],
            personDebts: [debt],
            personDebtEntries: [existing]
        )
        let plan = WalletSyncMasterDataApplyPlanSummary(items: [
            makePlanItem(action: .updatePersonDebtEntry(updated), entity: .personDebtEntry, id: updated.id),
            makePlanItem(action: .createPersonDebtEntry(created), entity: .personDebtEntry, id: created.id)
        ])

        let result = WalletSyncMasterDataApplier(store: store).apply(plan)

        XCTAssertEqual(result.updatedCount, 1)
        XCTAssertEqual(result.createdCount, 1)
        XCTAssertEqual(store.personDebtEntries.count, 2)
        XCTAssertEqual(store.personDebtEntries.first { $0.id == existing.id }?.amount, 20)
        XCTAssertEqual(store.accounts.first?.balance, 500)
        XCTAssertEqual(store.debtSettlementCount, 0)
    }

    func testChildRecordDeletesAndMissingParentsBlock() {
        let card = makeCreditCard(id: deterministicID(index: 350))
        let debt = makePersonDebt(id: deterministicID(index: 351), originalAmount: 100)
        let purchase = makeCreditCardPurchase(id: deterministicID(index: 352), cardID: card.id, updatedAt: Date(timeIntervalSince1970: 1_800_000_100))
        let payment = makeCreditCardPayment(id: deterministicID(index: 353), cardID: card.id, updatedAt: Date(timeIntervalSince1970: 1_800_000_100))
        let entry = makePersonDebtEntry(id: deterministicID(index: 354), debtID: debt.id, updatedAt: Date(timeIntervalSince1970: 1_800_000_100))
        let changedRecords = [
            WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: purchase)),
            WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: payment)),
            WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: entry))
        ]
        let missingParentPlan = WalletSyncMasterDataApplyPlanBuilder(localState: FakeFullDataStore())
            .makePlan(
                changedRecords: changedRecords,
                deletedRecordNames: []
            )
        let deletePlan = WalletSyncMasterDataApplyPlanBuilder(localState: FakeFullDataStore(personDebts: [debt], creditCards: [card]))
            .makePlan(
                changedRecords: [],
                deletedRecordNames: [
                    WalletSyncRecordEntity.creditCardPurchase.recordName(for: purchase.id),
                    WalletSyncRecordEntity.creditCardPayment.recordName(for: payment.id),
                    WalletSyncRecordEntity.personDebtEntry.recordName(for: entry.id)
                ]
            )

        XCTAssertEqual(missingParentPlan.blockedCount, 3)
        XCTAssertTrue(missingParentPlan.items.allSatisfy {
            if case .blocked(let reason) = $0.action { return reason == .missingParentRecord }
            return false
        })
        XCTAssertEqual(deletePlan.blockedCount, 3)
    }

    func testChildRecordTimestampConflictsBlock() {
        let card = makeCreditCard(id: deterministicID(index: 360))
        let oldRemote = makeCreditCardPurchase(
            id: deterministicID(index: 361),
            cardID: card.id,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_100)
        )
        let localNewer = makeCreditCardPurchase(
            id: oldRemote.id,
            cardID: card.id,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_200)
        )
        var ambiguousDTO = WalletSyncRecordMappers.dto(
            for: makeCreditCardPayment(
                id: deterministicID(index: 362),
                cardID: card.id,
                updatedAt: Date(timeIntervalSince1970: 1_800_000_100)
            )
        )
        ambiguousDTO.updatedAt = nil
        let plan = WalletSyncMasterDataApplyPlanBuilder(
            localState: FakeFullDataStore(creditCards: [card], creditCardPurchases: [localNewer])
        )
        .makePlan(
            changedRecords: [
                WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: oldRemote)),
                WalletSyncCKRecordAdapter.ckRecord(from: ambiguousDTO)
            ],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.blockedCount, 2)
        XCTAssertTrue(plan.items.contains {
            if case .blocked(let reason) = $0.action { return reason == .localChildRecordNewer }
            return false
        })
        XCTAssertTrue(plan.items.contains {
            if case .blocked(let reason) = $0.action { return reason == .ambiguousChildRecordTimestamp }
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
        let remoteRecord = WalletSyncCKRecordAdapter.ckRecord(
            from: WalletSyncRecordMappers.dto(for: makeFinancialEvent(updatedAt: Date(timeIntervalSince1970: 1_800_000_100)))
        )
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

        XCTAssertEqual(summary.appliedCreatedCount, 1)
        XCTAssertEqual(store.accounts.first?.balance, 500)
        XCTAssertEqual(store.postingCallCount, 0)
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
            tokenStore: FakeFullDataTokenStore(token: Data([9])),
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
        var recurring = makeFinancialEvent(status: .unpaid, updatedAt: Date(timeIntervalSince1970: 1_800_000_100))
        recurring.repeatRule = .monthly
        recurring.sourceRecurringEventID = UUID()
        recurring.recurringOccurrenceYear = 2026
        recurring.recurringOccurrenceMonth = 7
        var income = makeFinancialEvent(status: .unpaid, updatedAt: Date(timeIntervalSince1970: 1_800_000_100))
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

        XCTAssertEqual(summary.appliedCreatedCount, 2)
        XCTAssertTrue(store.financialEvents.allSatisfy { $0.status == .unpaid })
        XCTAssertEqual(store.paidMutationCount, 0)
        XCTAssertEqual(store.futureIncomeReceivedCount, 0)
    }

    func testUnsupportedEntitiesAreBlockedWithSafeReason() {
        let itemWithoutParentDTO = WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .monthlyBudgetItem, id: UUID()),
            updatedAt: Date(),
            fields: ["categoryName": .string("Food"), "plannedAmount": .double(500)]
        )
        let settingsDTO = WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .householdSettings, id: UUID()),
            updatedAt: Date()
        )
        let records = [itemWithoutParentDTO, settingsDTO].map(WalletSyncCKRecordAdapter.ckRecord(from:))

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

    func testFinancialPaymentPurchaseAndDebtEntryRemainBlockedWithoutParent() {
        let records = [
            WalletSyncRecordMappers.dto(for: makeCreditCardPayment()),
            WalletSyncRecordMappers.dto(for: makeCreditCardPurchase()),
            WalletSyncRecordMappers.dto(for: makePersonDebtEntry())
        ].map(WalletSyncCKRecordAdapter.ckRecord(from:))

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: FakeFullDataStore())
            .makePlan(changedRecords: records, deletedRecordNames: [])

        XCTAssertEqual(plan.blockedCount, 3)
        XCTAssertEqual(plan.plannedCreateCount, 0)
        XCTAssertEqual(plan.plannedUpdateCount, 0)
    }

    func testMonthlyBudgetPlansAsCreateWhenNotLocal() {
        let budget = makeMonthlyBudget()
        let record = WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: budget))

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: FakeFullDataStore())
            .makePlan(changedRecords: [record], deletedRecordNames: [])

        XCTAssertEqual(plan.plannedCreateCount, 1)
        XCTAssertEqual(plan.blockedCount, 0)
        XCTAssertTrue(plan.items.contains {
            if case .createWalletMonthlyBudget(let b) = $0.action { return b.id == budget.id }
            return false
        })
    }

    func testMonthlyBudgetPlansAsUpdateWhenLocal() {
        let budget = makeMonthlyBudget()
        let store = FakeFullDataStore(monthlyBudgets: [budget])
        let record = WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: budget))

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: store)
            .makePlan(changedRecords: [record], deletedRecordNames: [])

        XCTAssertEqual(plan.plannedUpdateCount, 1)
        XCTAssertEqual(plan.blockedCount, 0)
    }

    func testMonthlyBudgetItemBlockedWhenNoParentBudgetIDField() {
        let itemDTO = WalletSyncRecordDTO(
            identity: WalletSyncRecordIdentity(entity: .monthlyBudgetItem, id: UUID()),
            updatedAt: Date(),
            fields: ["categoryName": .string("Food"), "plannedAmount": .double(500)]
        )
        let record = WalletSyncCKRecordAdapter.ckRecord(from: itemDTO)

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: FakeFullDataStore())
            .makePlan(changedRecords: [record], deletedRecordNames: [])

        XCTAssertEqual(plan.blockedCount, 1)
        XCTAssertTrue(plan.items.contains {
            if case .blocked(let reason) = $0.action { return reason == .monthlyBudgetItemNoParent }
            return false
        })
    }

    func testMonthlyBudgetItemBlockedWhenParentNotLocal() {
        let budget = makeMonthlyBudget()
        var item = makeMonthlyBudgetItem()
        item.id = UUID()
        let itemDTO = WalletSyncRecordMappers.dto(for: item, parentBudgetID: budget.id)
        let record = WalletSyncCKRecordAdapter.ckRecord(from: itemDTO)

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: FakeFullDataStore())
            .makePlan(changedRecords: [record], deletedRecordNames: [])

        XCTAssertEqual(plan.blockedCount, 1)
        XCTAssertTrue(plan.items.contains {
            if case .blocked(let reason) = $0.action { return reason == .missingParentRecord }
            return false
        })
    }

    func testMonthlyBudgetItemPlansAsCreateWhenParentExistsAndItemNotLocal() {
        let budget = makeMonthlyBudget()
        var item = makeMonthlyBudgetItem()
        item.id = UUID()
        let store = FakeFullDataStore(monthlyBudgets: [budget])
        let itemDTO = WalletSyncRecordMappers.dto(for: item, parentBudgetID: budget.id)
        let record = WalletSyncCKRecordAdapter.ckRecord(from: itemDTO)

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: store)
            .makePlan(changedRecords: [record], deletedRecordNames: [])

        XCTAssertEqual(plan.plannedCreateCount, 1)
        XCTAssertEqual(plan.blockedCount, 0)
    }

    func testMonthlyBudgetItemPlansAsUpdateWhenRemoteIsNewer() {
        let budget = makeMonthlyBudget()
        var item = makeMonthlyBudgetItem()
        item.id = UUID()
        item.updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        var budgetWithItem = budget
        budgetWithItem.items = [item]
        let store = FakeFullDataStore(monthlyBudgets: [budgetWithItem])
        var remoteItem = item
        remoteItem.updatedAt = Date(timeIntervalSince1970: 1_800_000_200)
        let itemDTO = WalletSyncRecordMappers.dto(for: remoteItem, parentBudgetID: budget.id)
        let record = WalletSyncCKRecordAdapter.ckRecord(from: itemDTO)

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: store)
            .makePlan(changedRecords: [record], deletedRecordNames: [])

        XCTAssertEqual(plan.plannedUpdateCount, 1)
        XCTAssertEqual(plan.blockedCount, 0)
    }

    func testMonthlyBudgetItemBlockedWhenLocalIsNewer() {
        let budget = makeMonthlyBudget()
        var item = makeMonthlyBudgetItem()
        item.id = UUID()
        item.updatedAt = Date(timeIntervalSince1970: 1_800_000_200)
        var budgetWithItem = budget
        budgetWithItem.items = [item]
        let store = FakeFullDataStore(monthlyBudgets: [budgetWithItem])
        var remoteItem = item
        remoteItem.updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let itemDTO = WalletSyncRecordMappers.dto(for: remoteItem, parentBudgetID: budget.id)
        let record = WalletSyncCKRecordAdapter.ckRecord(from: itemDTO)

        let plan = WalletSyncMasterDataApplyPlanBuilder(localState: store)
            .makePlan(changedRecords: [record], deletedRecordNames: [])

        XCTAssertEqual(plan.blockedCount, 1)
        XCTAssertTrue(plan.items.contains {
            if case .blocked(let reason) = $0.action { return reason == .localChildRecordNewer }
            return false
        })
    }

    func testMonthlyBudgetItemsAreIncludedInUploadWhenParentHasItems() async throws {
        let budgetID = deterministicID(index: 400)
        var budget = WalletMonthlyBudget(year: 2026, month: 6, items: [])
        budget.id = budgetID
        var item = WalletMonthlyBudgetItem(categoryName: "Food", plannedAmount: 500)
        item.id = deterministicID(index: 401)
        budget.items = [item]
        let boundary = FakeFullDataBoundary()
        let store = FakeFullDataStore(monthlyBudgets: [budget])
        let pipeline = makePipeline(boundary: boundary, store: store)

        _ = try await pipeline.run()

        let uploadedEntities = try boundary.savedRecords.map { try WalletSyncCKRecordAdapter.dto(from: $0).entity }
        XCTAssertTrue(uploadedEntities.contains(.monthlyBudgetItem))
    }

    func testMonthlyBudgetItemUploadIncludesParentBudgetID() async throws {
        let budgetID = deterministicID(index: 410)
        var budget = WalletMonthlyBudget(year: 2026, month: 6, items: [])
        budget.id = budgetID
        var item = WalletMonthlyBudgetItem(categoryName: "Transport", plannedAmount: 300)
        item.id = deterministicID(index: 411)
        budget.items = [item]
        let boundary = FakeFullDataBoundary()
        let store = FakeFullDataStore(monthlyBudgets: [budget])
        let pipeline = makePipeline(boundary: boundary, store: store)

        _ = try await pipeline.run()

        let itemDTOs = try boundary.savedRecords
            .map { try WalletSyncCKRecordAdapter.dto(from: $0) }
            .filter { $0.entity == .monthlyBudgetItem }
        XCTAssertEqual(itemDTOs.count, 1)
        if case .uuid(let parentID) = itemDTOs.first?.fields["parentBudgetID"] {
            XCTAssertEqual(parentID, budgetID)
        } else {
            XCTFail("parentBudgetID field missing or not a UUID")
        }
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
            XCTAssertEqual(boundary.fetchCallCount, 1)
            XCTAssertNil(tokenStore.token)
        }
    }

    func testFreshDeviceWithRemoteRecordsAdoptsBeforeUploadingLocalSeedRecords() async throws {
        let remoteAccount = makeAccount(id: deterministicID(index: 800), balance: 42_000)
        let remoteRecord = WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: remoteAccount))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [remoteRecord], changeTokenData: Data([4]))
        )
        let tokenStore = FakeFullDataTokenStore()
        let localSeedCategory = makeCategory(id: deterministicID(index: 801))
        let store = FakeFullDataStore(
            accounts: [makeAccount(id: deterministicID(index: 802), balance: 100)],
            categories: [localSeedCategory]
        )
        let pipeline = makePipeline(
            boundary: boundary,
            tokenStore: tokenStore,
            store: store,
            applier: WalletSyncMasterDataApplier(store: store)
        )

        let summary = try await pipeline.run()

        XCTAssertEqual(boundary.events, ["ensure", "fetch"])
        XCTAssertEqual(summary.uploadedCount, 0)
        XCTAssertEqual(summary.batchCount, 0)
        XCTAssertEqual(summary.changedRecordCount, 1)
        XCTAssertEqual(summary.skippedLocalEchoCount, 0)
        XCTAssertEqual(summary.appliedCreatedCount, 1)
        XCTAssertEqual(tokenStore.token, Data([4]))
        XCTAssertTrue(store.categories.contains { $0.id == localSeedCategory.id })
        XCTAssertTrue(boundary.savedRecords.isEmpty)
    }

    func testAutomaticFetchThenUploadAppliesRemoteAccountBeforeUploadingLocalAccounts() async throws {
        let accountID = deterministicID(index: 820)
        let localUpdatedAt = Date(timeIntervalSince1970: 1_000)
        let remoteUpdatedAt = Date(timeIntervalSince1970: 2_000)
        let localAccount = Account(
            id: accountID,
            name: "Cash",
            balance: 100,
            type: .cash,
            createdAt: localUpdatedAt,
            updatedAt: localUpdatedAt
        )
        let remoteAccount = Account(
            id: accountID,
            name: "Cash",
            balance: 500,
            type: .cash,
            createdAt: localUpdatedAt,
            updatedAt: remoteUpdatedAt
        )
        let remoteRecord = WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: remoteAccount))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [remoteRecord], changeTokenData: Data([5]))
        )
        let tokenStore = FakeFullDataTokenStore(token: Data([4]))
        let store = FakeFullDataStore(accounts: [localAccount])
        let pipeline = makePipeline(
            boundary: boundary,
            tokenStore: tokenStore,
            store: store,
            applier: WalletSyncMasterDataApplier(store: store),
            executionOrder: .fetchThenUpload
        )

        let summary = try await pipeline.run()
        let uploadedAccountDTO = try XCTUnwrap(
            boundary.savedRecords
                .map { try WalletSyncCKRecordAdapter.dto(from: $0) }
                .first { $0.entity == .account && $0.id == accountID }
        )

        XCTAssertEqual(boundary.events, ["ensure", "fetch", "save"])
        XCTAssertEqual(try XCTUnwrap(store.accounts.first?.balance), 500, accuracy: 0.001)
        XCTAssertEqual(uploadedAccountDTO.fields["balance"], .double(500))
        XCTAssertEqual(uploadedAccountDTO.updatedAt, remoteUpdatedAt)
        XCTAssertEqual(summary.plannedUpdateCount, 1)
        XCTAssertEqual(summary.appliedUpdatedCount, 1)
        XCTAssertEqual(summary.uploadedCount, 1)
        XCTAssertEqual(tokenStore.token, Data([5]))
    }

    func testNoTokenPurgedZoneBootstrapReEnsuresZoneAndUploadsSourceRecords() async throws {
        let tokenStore = FakeFullDataTokenStore(token: Data([7]))
        tokenStore.clearWalletSyncZoneChangeTokenData()
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [], changeTokenData: Data([8])),
            fetchErrors: [
                NSError(
                    domain: CKError.errorDomain,
                    code: CKError.Code.zoneNotFound.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: "Error fetching record zone \(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName) from server: Zone was purged by user"]
                )
            ]
        )
        let store = FakeFullDataStore(accounts: [makeAccount(id: deterministicID(index: 805), balance: 42_000)])
        let pipeline = makePipeline(
            boundary: boundary,
            tokenStore: tokenStore,
            store: store
        )

        let summary = try await pipeline.run()

        XCTAssertEqual(boundary.events, ["ensure", "fetch", "ensure", "save", "fetch"])
        XCTAssertEqual(summary.uploadedCount, 1)
        XCTAssertEqual(summary.changedRecordCount, 0)
        XCTAssertEqual(summary.skippedLocalEchoCount, 0)
        XCTAssertEqual(summary.tokenSaved, true)
        XCTAssertEqual(tokenStore.token, Data([8]))
    }

    func testNoTokenPurgedZoneDuringInitialEnsureRecoversAndUploadsSourceRecords() async throws {
        let tokenStore = FakeFullDataTokenStore()
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [], changeTokenData: Data([9])),
            ensureErrors: [
                NSError(
                    domain: CKError.errorDomain,
                    code: CKError.Code.unknownItem.rawValue,
                    userInfo: [NSLocalizedDescriptionKey: "Error fetching record zone \(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName) from server: Zone was purged by user"]
                )
            ]
        )
        let store = FakeFullDataStore(accounts: [makeAccount(id: deterministicID(index: 807), balance: 15_000)])
        let pipeline = makePipeline(
            boundary: boundary,
            tokenStore: tokenStore,
            store: store
        )

        let summary = try await pipeline.run()

        XCTAssertEqual(boundary.events, ["ensure", "ensure", "fetch", "save", "fetch"])
        XCTAssertEqual(summary.uploadedCount, 1)
        XCTAssertEqual(summary.tokenSaved, true)
        XCTAssertEqual(tokenStore.clearCallCount, 1)
        XCTAssertEqual(tokenStore.token, Data([9]))
    }

    func testNoTokenPurgedZoneBootstrapClearsStaleTokenBeforeUpload() async throws {
        let tokenStore = FakeFullDataTokenStore()
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [], changeTokenData: nil),
            fetchErrors: [
                WalletSyncCloudKitError.unknown(
                    underlying: NSError(
                        domain: CKError.errorDomain,
                        code: CKError.Code.unknownItem.rawValue,
                        userInfo: [NSLocalizedDescriptionKey: "Error fetching record zone \(WalletSyncRealCloudKitPrivateDatabaseBoundary.syncZoneName) from server: Zone was purged by user"]
                    )
                )
            ]
        )
        let store = FakeFullDataStore(accounts: [makeAccount(id: deterministicID(index: 806), balance: 10)])
        let pipeline = makePipeline(
            boundary: boundary,
            tokenStore: tokenStore,
            store: store
        )

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.uploadedCount, 1)
        XCTAssertFalse(summary.usedSavedToken)
        XCTAssertNil(tokenStore.token)
        XCTAssertEqual(tokenStore.clearCallCount, 1)
    }

    func testFreshDeviceAdoptionDoesNotIntroduceDuplicateSeedCategories() async throws {
        let remoteCategory = makeCategory(id: deterministicID(index: 810))
        let remoteRecord = WalletSyncCKRecordAdapter.ckRecord(from: WalletSyncRecordMappers.dto(for: remoteCategory))
        let boundary = FakeFullDataBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [remoteRecord], changeTokenData: Data([4]))
        )
        let store = FakeFullDataStore(
            categories: [makeCategory(id: deterministicID(index: 811))],
            pruneSeedDataOnAdoption: true
        )
        let pipeline = makePipeline(
            boundary: boundary,
            store: store,
            applier: WalletSyncMasterDataApplier(store: store)
        )

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.uploadedCount, 0)
        XCTAssertEqual(boundary.savedRecords.count, 0)
        XCTAssertEqual(store.seedPruneCallCount, 1)
        XCTAssertEqual(store.categories.count, 1)
        XCTAssertEqual(store.categories.filter { $0.id == remoteCategory.id }.count, 1)
    }

    func testSyntheticDebugCategoryIsNotUploadedByFullDataValidation() async throws {
        let debugCategory = WalletBoard.Category(
            id: WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryID,
            name: WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryName,
            subcategories: [WalletSyncDebugSyntheticMasterDataChangeFactory.debugSubcategoryName],
            isActive: false
        )
        let boundary = FakeFullDataBoundary()
        let store = FakeFullDataStore(categories: [debugCategory, makeCategory(id: deterministicID(index: 820))])
        let pipeline = makePipeline(boundary: boundary, store: store)

        let summary = try await pipeline.run()

        let uploadedDTOs = try boundary.savedRecords.map { try WalletSyncCKRecordAdapter.dto(from: $0) }
        XCTAssertEqual(summary.uploadedCountsByEntity[.category], 1)
        XCTAssertFalse(uploadedDTOs.contains { $0.id == WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryID })
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

    private func makePlanItem(
        action: WalletSyncMasterDataApplyAction,
        entity: WalletSyncRecordEntity,
        id: UUID
    ) -> WalletSyncMasterDataApplyPlanItem {
        WalletSyncMasterDataApplyPlanItem(
            recordName: entity.recordName(for: id),
            entity: entity,
            id: id,
            action: action
        )
    }

    private static let supportedEntities: [WalletSyncRecordEntity] = [
        .account,
        .category,
        .walletEvent,
        .financialEvent,
        .monthlyBudget,
        .monthlyBudgetItem,
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
        let budget = makeMonthlyBudget()
        return [
            WalletSyncRecordMappers.dto(for: makeAccount()),
            WalletSyncRecordMappers.dto(for: makeCategory()),
            WalletSyncRecordMappers.dto(for: makeWalletEvent()),
            WalletSyncRecordMappers.dto(for: makeFinancialEvent()),
            WalletSyncRecordMappers.dto(for: budget),
            WalletSyncRecordMappers.dto(for: makeMonthlyBudgetItem(), parentBudgetID: budget.id),
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
        localFinancialEventDeletionStore: WalletSyncLocalFinancialEventDeletionStoring? = nil,
        localInstallmentPlanDeletionStore: WalletSyncLocalInstallmentPlanDeletionStoring? = nil,
        localHighRiskRecordDeletionStore: WalletSyncLocalHighRiskRecordDeletionStoring? = nil,
        applier: WalletSyncMasterDataPlanApplying? = nil,
        uploadCap: Int = WalletSyncFullDataRecordValidationPipeline.defaultUploadCap,
        executionOrder: WalletSyncFullDataRecordValidationPipeline.ExecutionOrder = .uploadThenFetch
    ) -> WalletSyncFullDataRecordValidationPipeline {
        WalletSyncFullDataRecordValidationPipeline(
            zoneEnsurer: boundary,
            recordSaver: boundary,
            changedRecordFetcher: boundary,
            tokenStore: tokenStore,
            source: store,
            localState: store,
            localFinancialEventDeletionStore: localFinancialEventDeletionStore ?? FakeFinancialEventDeletionStore(),
            localInstallmentPlanDeletionStore: localInstallmentPlanDeletionStore ?? FakeInstallmentPlanDeletionStore(),
            localHighRiskRecordDeletionStore: localHighRiskRecordDeletionStore ?? FakeHighRiskRecordDeletionStore(),
            inboxParser: WalletSyncInboxParser(),
            applier: applier ?? FakeFullDataApplier(),
            uploadCap: uploadCap,
            executionOrder: executionOrder
        )
    }
}

private final class FakeFullDataBoundary: WalletSyncMasterDataZoneEnsuring, WalletSyncMasterDataRecordSaving, WalletSyncDryRunChangedRecordFetching {
    var savedRecords: [CKRecord] = []
    var savedRecordBatches: [[CKRecord]] = []
    var events: [String] = []
    var fetchCallCount = 0
    var fetchResult: WalletSyncCloudKitFetchResult
    var ensureErrors: [Error]
    var fetchErrors: [Error]
    var failingSaveBatchIndex: Int?

    init(
        fetchResult: WalletSyncCloudKitFetchResult = WalletSyncCloudKitFetchResult(records: []),
        ensureErrors: [Error] = [],
        fetchErrors: [Error] = [],
        failingSaveBatchIndex: Int? = nil
    ) {
        self.fetchResult = fetchResult
        self.ensureErrors = ensureErrors
        self.fetchErrors = fetchErrors
        self.failingSaveBatchIndex = failingSaveBatchIndex
    }

    func ensureSyncZone() async throws {
        events.append("ensure")
        if !ensureErrors.isEmpty {
            throw ensureErrors.removeFirst()
        }
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
        if !fetchErrors.isEmpty {
            throw fetchErrors.removeFirst()
        }
        return fetchResult
    }

    enum FakeFullDataBoundaryError: Error {
        case saveFailed
    }
}

private final class FakeFullDataTokenStore: WalletSyncChangeTokenStoring {
    var token: Data?
    var clearCallCount = 0

    init(token: Data? = nil) {
        self.token = token
    }

    func loadWalletSyncZoneChangeTokenData() -> Data? { token }
    func saveWalletSyncZoneChangeTokenData(_ tokenData: Data) { token = tokenData }
    func clearWalletSyncZoneChangeTokenData() {
        clearCallCount += 1
        token = nil
    }
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

private final class FakeFinancialEventDeletionStore: WalletSyncLocalFinancialEventDeletionStoring {
    var deletedAtByID: [UUID: Date]

    init(deletedAtByID: [UUID: Date] = [:]) {
        self.deletedAtByID = deletedAtByID
    }

    func markFinancialEventDeletedLocally(id: UUID, deletedAt: Date) {
        let existingDeletedAt = deletedAtByID[id] ?? .distantPast
        deletedAtByID[id] = max(existingDeletedAt, deletedAt)
    }

    func isFinancialEventDeletedLocally(id: UUID) -> Bool {
        deletedAtByID[id] != nil
    }

    func locallyDeletedFinancialEventDeletedAt(id: UUID) -> Date? {
        deletedAtByID[id]
    }

    func syncableFinancialEventDeletionDTOs() -> [WalletSyncRecordDTO] {
        deletedAtByID.map { id, deletedAt in
            WalletSyncRecordMappers.dtoForFinancialEventDeletion(id: id, deletedAt: deletedAt)
        }
    }
}

private final class FakeInstallmentPlanDeletionStore: WalletSyncLocalInstallmentPlanDeletionStoring {
    var deletedAtByID: [UUID: Date]

    init(deletedAtByID: [UUID: Date] = [:]) {
        self.deletedAtByID = deletedAtByID
    }

    func markInstallmentPlanDeletedLocally(id: UUID, deletedAt: Date) {
        let existingDeletedAt = deletedAtByID[id] ?? .distantPast
        deletedAtByID[id] = max(existingDeletedAt, deletedAt)
    }

    func isInstallmentPlanDeletedLocally(id: UUID) -> Bool {
        deletedAtByID[id] != nil
    }

    func locallyDeletedInstallmentPlanDeletedAt(id: UUID) -> Date? {
        deletedAtByID[id]
    }

    func syncableInstallmentPlanDeletionDTOs() -> [WalletSyncRecordDTO] {
        deletedAtByID.map { id, deletedAt in
            WalletSyncRecordMappers.dtoForInstallmentPlanDeletion(id: id, deletedAt: deletedAt)
        }
    }
}

private final class FakeHighRiskRecordDeletionStore: WalletSyncLocalHighRiskRecordDeletionStoring {
    var deletedAtByRecord: [String: Date]

    init(deletedAtByRecord: [String: Date] = [:]) {
        self.deletedAtByRecord = deletedAtByRecord
    }

    func markHighRiskRecordDeletedLocally(entity: WalletSyncRecordEntity, id: UUID, deletedAt: Date) {
        let recordName = entity.recordName(for: id)
        let existingDeletedAt = deletedAtByRecord[recordName] ?? .distantPast
        deletedAtByRecord[recordName] = max(existingDeletedAt, deletedAt)
    }

    func isHighRiskRecordDeletedLocally(entity: WalletSyncRecordEntity, id: UUID) -> Bool {
        deletedAtByRecord[entity.recordName(for: id)] != nil
    }

    func locallyDeletedHighRiskRecordDeletedAt(entity: WalletSyncRecordEntity, id: UUID) -> Date? {
        deletedAtByRecord[entity.recordName(for: id)]
    }

    func syncableHighRiskRecordDeletionDTOs() -> [WalletSyncRecordDTO] {
        deletedAtByRecord.compactMap { recordName, deletedAt in
            guard let identity = identityFromRecordName(recordName) else { return nil }
            return WalletSyncRecordMappers.dtoForHighRiskRecordDeletion(
                entity: identity.entity,
                id: identity.id,
                deletedAt: deletedAt
            )
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
}

private final class FakeFullDataStore: WalletSyncFullDataSourceReading, WalletSyncMergePlanLocalStateReading, WalletSyncMasterDataApplyingStore, WalletSyncInitialCloudAdoptionSeedPruning {
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
    var postingCallCount = 0
    var creditCardPaymentApplyCount = 0
    var cardOutstandingMutationCount = 0
    var debtSettlementCount = 0
    var paidMutationCount = 0
    var futureIncomeReceivedCount = 0
    var pruneSeedDataOnAdoption: Bool
    var seedPruneCallCount = 0

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
        historicalMonthlySummaries: [HistoricalMonthlySummaryEntry] = [],
        pruneSeedDataOnAdoption: Bool = false
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
        self.pruneSeedDataOnAdoption = pruneSeedDataOnAdoption
    }

    static func withOneOfEachSupportedEntity() -> FakeFullDataStore {
        var budgetWithItem = makeMonthlyBudget()
        budgetWithItem.items = [makeMonthlyBudgetItem()]
        return FakeFullDataStore(
            accounts: [makeAccount()],
            categories: [makeCategory()],
            walletEvents: [makeWalletEvent()],
            merchantMemories: [makeMerchantMemory()],
            installmentPlans: [makeInstallmentPlan()],
            financialEvents: [makeFinancialEvent()],
            monthlyBudgets: [budgetWithItem],
            personDebts: [makePersonDebt()],
            personDebtEntries: [makePersonDebtEntry()],
            creditCards: [makeCreditCard()],
            creditCardPurchases: [makeCreditCardPurchase()],
            creditCardPayments: [makeCreditCardPayment()],
            historicalMonthlySummaries: [makeHistoricalMonthlySummaryEntry()]
        )
    }

    func containsAccount(id: UUID) -> Bool { accounts.contains { $0.id == id } }
    func accountUpdatedAt(id: UUID) -> Date? { accounts.first { $0.id == id }?.updatedAt }
    func containsCategory(id: UUID) -> Bool { categories.contains { $0.id == id } }
    func containsWalletEvent(id: UUID) -> Bool { walletEvents.contains { $0.id == id } }
    func containsMerchantMemory(id: UUID) -> Bool { merchantMemories.contains { $0.id == id } }
    func containsHistoricalMonthlySummary(id: UUID) -> Bool { historicalMonthlySummaries.contains { $0.id == id } }
    func containsPersonDebt(id: UUID) -> Bool { personDebts.contains { $0.id == id } }
    func containsCreditCard(id: UUID) -> Bool { creditCards.contains { $0.id == id } }
    func containsInstallmentPlan(id: UUID) -> Bool { installmentPlans.contains { $0.id == id } }
    func containsFinancialEvent(id: UUID) -> Bool { financialEvents.contains { $0.id == id } }
    func financialEventUpdatedAt(id: UUID) -> Date? { financialEvents.first { $0.id == id }?.updatedAt }
    func containsCreditCardPurchase(id: UUID) -> Bool { creditCardPurchases.contains { $0.id == id } }
    func creditCardPurchaseUpdatedAt(id: UUID) -> Date? { creditCardPurchases.first { $0.id == id }?.updatedAt }
    func containsCreditCardPayment(id: UUID) -> Bool { creditCardPayments.contains { $0.id == id } }
    func creditCardPaymentUpdatedAt(id: UUID) -> Date? { creditCardPayments.first { $0.id == id }?.updatedAt }
    func containsPersonDebtEntry(id: UUID) -> Bool { personDebtEntries.contains { $0.id == id } }
    func personDebtEntryUpdatedAt(id: UUID) -> Date? { personDebtEntries.first { $0.id == id }?.updatedAt }
    func containsMonthlyBudget(id: UUID) -> Bool { monthlyBudgets.contains { $0.id == id } }
    func monthlyBudgetUpdatedAt(id: UUID) -> Date? { monthlyBudgets.first { $0.id == id }?.updatedAt }
    func containsMonthlyBudgetItem(id: UUID, inBudget parentID: UUID) -> Bool {
        guard let budget = monthlyBudgets.first(where: { $0.id == parentID }) else { return false }
        return budget.items.contains { $0.id == id }
    }
    func monthlyBudgetItemUpdatedAt(id: UUID, inBudget parentID: UUID) -> Date? {
        guard let budget = monthlyBudgets.first(where: { $0.id == parentID }) else { return nil }
        return budget.items.first { $0.id == id }?.updatedAt
    }

    @discardableResult
    func removeSeedDataBeforeInitialCloudAdoptionIfSafe() -> Bool {
        seedPruneCallCount += 1
        guard pruneSeedDataOnAdoption else { return false }
        accounts = []
        categories = []
        walletEvents = []
        merchantMemories = []
        installmentPlans = []
        financialEvents = []
        monthlyBudgets = []
        personDebts = []
        personDebtEntries = []
        creditCards = []
        creditCardPurchases = []
        creditCardPayments = []
        historicalMonthlySummaries = []
        return true
    }
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
    status: FinancialEventStatus = .unpaid,
    amount: Double = 100,
    date: Date = Date(timeIntervalSince1970: 1_800_000_000),
    updatedAt: Date = Date(timeIntervalSince1970: 1_800_000_000)
) -> FinancialEvent {
    var event = FinancialEvent(
        type: .expense,
        status: status,
        title: "Remote Event",
        amount: amount,
        date: date
    )
    event.id = id
    event.createdAt = updatedAt
    event.updatedAt = updatedAt
    return event
}

private func makeMonthlyBudget(id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!) -> WalletMonthlyBudget {
    var budget = WalletMonthlyBudget(year: 2026, month: 6, items: [])
    budget.id = id
    return budget
}

private func makeMonthlyBudgetItem(id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!) -> WalletMonthlyBudgetItem {
    var item = WalletMonthlyBudgetItem(categoryName: "Food", plannedAmount: 500)
    item.id = id
    return item
}

private func makePersonDebt(
    id: UUID = UUID(),
    originalAmount: Double = 300
) -> PersonDebt {
    var debt = PersonDebt(personName: "Person", kind: .owedToMe, originalAmount: originalAmount)
    debt.id = id
    return debt
}

private func makePersonDebtEntry(
    id: UUID = UUID(),
    debtID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
    amount: Double = 50,
    updatedAt: Date = Date(timeIntervalSince1970: 1_800_000_000)
) -> PersonDebtEntry {
    PersonDebtEntry(
        id: id,
        debtID: debtID,
        entryType: .repaymentReceived,
        amount: amount,
        accountName: "Cash",
        date: Date(timeIntervalSince1970: 1_800_000_000),
        note: nil,
        createdAt: updatedAt,
        updatedAt: updatedAt
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

private func makeCreditCardPurchase(
    id: UUID = UUID(),
    cardID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
    amount: Double = 2_000,
    updatedAt: Date = Date(timeIntervalSince1970: 1_800_000_000)
) -> CreditCardPurchase {
    CreditCardPurchase(
        id: id,
        cardID: cardID,
        title: "Laptop",
        amount: amount,
        purchaseDate: Date(timeIntervalSince1970: 1_800_000_000),
        categoryName: "Electronics",
        subCategoryName: "Computers",
        note: nil,
        createdAt: updatedAt,
        updatedAt: updatedAt
    )
}

private func makeCreditCardPayment(
    id: UUID = UUID(),
    cardID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
    amount: Double = 1_000,
    updatedAt: Date = Date(timeIntervalSince1970: 1_800_000_000)
) -> CreditCardPayment {
    CreditCardPayment(
        id: id,
        cardID: cardID,
        fromAccountName: "Cash",
        amount: amount,
        paymentDate: Date(timeIntervalSince1970: 1_800_000_000),
        note: nil,
        createdAt: updatedAt,
        updatedAt: updatedAt
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
