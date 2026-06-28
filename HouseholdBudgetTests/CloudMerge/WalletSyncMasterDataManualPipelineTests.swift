import XCTest
import CloudKit
@testable import WalletBoard

@MainActor
final class WalletSyncMasterDataManualPipelineTests: XCTestCase {

    func testPipelineEnsuresZoneBeforeSavingFetchingAndApplying() async throws {
        let events = PipelineEvents()
        let boundary = FakePipelineBoundary(events: events)
        let store = FakePipelineStore(categories: [makeCategory()])
        let tokenStore = FakeTokenStore()
        let applier = FakePlanApplier(events: events)
        let pipeline = makePipeline(
            boundary: boundary,
            tokenStore: tokenStore,
            store: store,
            applier: applier
        )

        _ = try await pipeline.run()

        XCTAssertEqual(events.values, ["ensure", "save", "fetch", "apply"])
    }

    func testPipelineUploadsOnlyMasterDataEntities() async throws {
        let boundary = FakePipelineBoundary()
        let store = FakePipelineStore(
            accounts: [makeAccount()],
            categories: [makeCategory()],
            walletEvents: [makeWalletEvent()]
        )
        let pipeline = makePipeline(boundary: boundary, store: store)

        let summary = try await pipeline.run()
        let entities = try boundary.savedRecords.map { try WalletSyncCKRecordAdapter.dto(from: $0).entity }

        XCTAssertEqual(Set(entities), [.account, .category, .walletEvent])
        XCTAssertEqual(summary.uploadedCount, 3)
        XCTAssertEqual(summary.uploadedAccountCount, 1)
        XCTAssertEqual(summary.uploadedCategoryCount, 1)
        XCTAssertEqual(summary.uploadedWalletEventCount, 1)
        XCTAssertFalse(entities.contains(.financialEvent))
    }

    func testPipelineRespectsUploadCap() async throws {
        let boundary = FakePipelineBoundary()
        let store = FakePipelineStore(accounts: (0..<60).map { _ in makeAccount() })
        let pipeline = makePipeline(boundary: boundary, store: store, uploadCap: 50)

        let summary = try await pipeline.run()

        XCTAssertEqual(boundary.savedRecords.count, 50)
        XCTAssertEqual(summary.uploadedCount, 50)
        XCTAssertEqual(summary.uploadCappedCount, 10)
    }

    func testPipelineFetchesWithSavedTokenWhenAvailable() async throws {
        let boundary = FakePipelineBoundary()
        let token = Data([1, 2, 3])
        let tokenStore = FakeTokenStore(token: token)
        let pipeline = makePipeline(boundary: boundary, tokenStore: tokenStore)

        let summary = try await pipeline.run()

        XCTAssertEqual(boundary.fetchToken, token)
        XCTAssertTrue(summary.usedSavedToken)
    }

    func testPipelineFetchesWithNilTokenWhenNoTokenExists() async throws {
        let boundary = FakePipelineBoundary()
        let pipeline = makePipeline(boundary: boundary, tokenStore: FakeTokenStore())

        let summary = try await pipeline.run()

        XCTAssertNil(boundary.fetchToken)
        XCTAssertFalse(summary.usedSavedToken)
    }

    func testPipelineSavesReturnedTokenWhenPresent() async throws {
        let returnedToken = Data([9, 8, 7])
        let boundary = FakePipelineBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [], changeTokenData: returnedToken)
        )
        let tokenStore = FakeTokenStore()
        let pipeline = makePipeline(boundary: boundary, tokenStore: tokenStore)

        let summary = try await pipeline.run()

        XCTAssertEqual(tokenStore.token, returnedToken)
        XCTAssertEqual(tokenStore.saveCount, 1)
        XCTAssertTrue(summary.tokenReturned)
        XCTAssertTrue(summary.tokenSaved)
    }

    func testPipelineDoesNotOverwriteExistingTokenWhenNoTokenIsReturned() async throws {
        let existingToken = Data([4, 5, 6])
        let boundary = FakePipelineBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [], changeTokenData: nil)
        )
        let tokenStore = FakeTokenStore(token: existingToken)
        let pipeline = makePipeline(boundary: boundary, tokenStore: tokenStore)

        let summary = try await pipeline.run()

        XCTAssertEqual(tokenStore.token, existingToken)
        XCTAssertEqual(tokenStore.saveCount, 0)
        XCTAssertFalse(summary.tokenReturned)
        XCTAssertFalse(summary.tokenSaved)
    }

    func testPipelineParsesBuildsPlanAndAppliesMasterDataAction() async throws {
        let categoryID = UUID()
        let changedRecord = record(for: categoryDTO(id: categoryID))
        let boundary = FakePipelineBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [changedRecord], changeTokenData: Data([1]))
        )
        let store = FakePipelineStore()
        let applier = FakePlanApplier()
        let pipeline = makePipeline(boundary: boundary, store: store, applier: applier)

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.changedRecordCount, 1)
        XCTAssertEqual(summary.parsedValidCount, 1)
        XCTAssertEqual(summary.plannedCreateCount, 1)
        XCTAssertEqual(applier.receivedPlan?.plannedCreateCount, 1)
        XCTAssertEqual(summary.appliedCreatedCount, 1)
    }

    func testPipelineWithRealApplierDoesNotMutateNonMasterCollectionsOrAccountBalance() async throws {
        let accountID = UUID()
        let existingBalance = 500.0
        let changedRecord = record(for: accountDTO(id: accountID, balance: 99_999))
        let boundary = FakePipelineBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [changedRecord], changeTokenData: Data([1]))
        )
        let store = FakePipelineStore(accounts: [makeAccount(id: accountID, balance: existingBalance)])
        let pipeline = makePipeline(
            boundary: boundary,
            store: store,
            applier: WalletSyncMasterDataApplier(store: store)
        )

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.appliedUpdatedCount, 1)
        XCTAssertEqual(store.accounts.first?.balance, existingBalance)
        XCTAssertEqual(store.financialEventMutationCount, 0)
        XCTAssertEqual(store.budgetMutationCount, 0)
        XCTAssertEqual(store.creditCardMutationCount, 0)
        XCTAssertEqual(store.debtMutationCount, 0)
        XCTAssertEqual(store.recurringMutationCount, 0)
    }

    func testPipelineSummaryCountsAndSamplesAreSafe() async throws {
        let changedRecord = record(for: categoryDTO(id: UUID()))
        let boundary = FakePipelineBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(
                records: [changedRecord],
                deletedRecordNames: [WalletSyncRecordEntity.walletEvent.recordName(for: UUID())],
                changeTokenData: Data([1]),
                moreComing: true
            )
        )
        let store = FakePipelineStore(categories: [makeCategory()])
        let pipeline = makePipeline(boundary: boundary, store: store, sampleLimit: 2)

        let summary = try await pipeline.run()
        let summaryText = String(describing: summary)

        XCTAssertEqual(summary.changedRecordCount, 1)
        XCTAssertEqual(summary.deletedRecordCount, 1)
        XCTAssertEqual(summary.sampleRecordNames.count, 2)
        XCTAssertTrue(summary.moreComing)
        XCTAssertFalse(summaryText.contains("Remote Category"))
        XCTAssertFalse(summaryText.contains("99_999"))
        XCTAssertFalse(summaryText.contains("DEBUG_SYNC_TEST_CATEGORY"))
    }

    func testLocalEchoRecordsAreExcludedFromApplyPlan() async throws {
        let accountID = UUID()
        let store = FakePipelineStore(accounts: [makeAccount(id: accountID)])
        let echoRecord = record(for: accountDTO(id: accountID))
        let boundary = FakePipelineBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [echoRecord], changeTokenData: Data([1]))
        )
        let applier = FakePlanApplier()
        let pipeline = makePipeline(boundary: boundary, store: store, applier: applier)

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.skippedLocalEchoCount, 1)
        XCTAssertEqual(summary.plannedCreateCount, 0)
        XCTAssertEqual(summary.plannedUpdateCount, 0)
        XCTAssertEqual(applier.receivedPlan?.plannedUpdateCount, 0)
        XCTAssertEqual(applier.receivedPlan?.plannedCreateCount, 0)
    }

    func testSkippedLocalEchoCountMatchesNumberOfEchoedRecords() async throws {
        let id1 = UUID()
        let id2 = UUID()
        let store = FakePipelineStore(accounts: [makeAccount(id: id1), makeAccount(id: id2)])
        let boundary = FakePipelineBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(
                records: [record(for: accountDTO(id: id1)), record(for: accountDTO(id: id2))],
                changeTokenData: Data([1])
            )
        )
        let pipeline = makePipeline(boundary: boundary, store: store)

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.skippedLocalEchoCount, 2)
        XCTAssertEqual(summary.changedRecordCount, 2)
    }

    func testSkippedLocalEchoRecordNamesAreLimitedBySampleLimit() async throws {
        let ids = (0..<5).map { _ in UUID() }
        let store = FakePipelineStore(accounts: ids.map { makeAccount(id: $0) })
        let boundary = FakePipelineBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(
                records: ids.map { record(for: accountDTO(id: $0)) },
                changeTokenData: Data([1])
            )
        )
        let pipeline = makePipeline(boundary: boundary, store: store, sampleLimit: 3)

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.skippedLocalEchoCount, 5)
        XCTAssertLessThanOrEqual(summary.skippedLocalEchoRecordNames.count, 3)
    }

    func testChangedRecordCountReflectsAllRecordsBeforeEchoFiltering() async throws {
        let accountID = UUID()
        let store = FakePipelineStore(accounts: [makeAccount(id: accountID)])
        let echoRecord = record(for: accountDTO(id: accountID))
        let boundary = FakePipelineBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(records: [echoRecord], changeTokenData: Data([1]))
        )
        let pipeline = makePipeline(boundary: boundary, store: store)

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.changedRecordCount, 1)
        XCTAssertEqual(summary.skippedLocalEchoCount, 1)
        XCTAssertEqual(summary.parsedValidCount, 0)
    }

    func testNonEchoChangedRecordsStillFlowThroughParserAndPlanner() async throws {
        let accountID = UUID()
        let nonEchoCategoryID = UUID()
        let store = FakePipelineStore(accounts: [makeAccount(id: accountID)])
        let echoRecord = record(for: accountDTO(id: accountID))
        let nonEchoRecord = record(for: categoryDTO(id: nonEchoCategoryID))
        let boundary = FakePipelineBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(
                records: [echoRecord, nonEchoRecord],
                changeTokenData: Data([1])
            )
        )
        let applier = FakePlanApplier()
        let pipeline = makePipeline(boundary: boundary, store: store, applier: applier)

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.skippedLocalEchoCount, 1)
        XCTAssertEqual(summary.parsedValidCount, 1)
        XCTAssertEqual(summary.plannedCreateCount, 1)
        XCTAssertEqual(applier.receivedPlan?.plannedCreateCount, 1)
    }

    func testDeletedRecordNamesAreNotTreatedAsLocalEcho() async throws {
        let accountID = UUID()
        let store = FakePipelineStore(accounts: [makeAccount(id: accountID)])
        let uploadedName = WalletSyncRecordEntity.account.recordName(for: accountID)
        let boundary = FakePipelineBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(
                records: [],
                deletedRecordNames: [uploadedName],
                changeTokenData: Data([1])
            )
        )
        let pipeline = makePipeline(boundary: boundary, store: store)

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.deletedRecordCount, 1)
        XCTAssertEqual(summary.skippedLocalEchoCount, 0)
    }

    func testZeroSkippedLocalEchoWhenFetchReturnsOnlyNewRecords() async throws {
        let uploadedAccountID = UUID()
        let newCategoryID = UUID()
        let store = FakePipelineStore(accounts: [makeAccount(id: uploadedAccountID)])
        let boundary = FakePipelineBoundary(
            fetchResult: WalletSyncCloudKitFetchResult(
                records: [record(for: categoryDTO(id: newCategoryID))],
                changeTokenData: Data([1])
            )
        )
        let pipeline = makePipeline(boundary: boundary, store: store)

        let summary = try await pipeline.run()

        XCTAssertEqual(summary.skippedLocalEchoCount, 0)
        XCTAssertTrue(summary.skippedLocalEchoRecordNames.isEmpty)
        XCTAssertEqual(summary.parsedValidCount, 1)
    }

    func testPipelineDoesNotExposeICloudBackupServiceDependency() {
        let pipeline = makePipeline(boundary: FakePipelineBoundary())
        let propertyNames = Mirror(reflecting: pipeline).children.compactMap { $0.label?.lowercased() }

        XCTAssertFalse(propertyNames.contains { $0.contains("walleticloudsyncservice") })
    }

    private func makePipeline(
        boundary: FakePipelineBoundary,
        tokenStore: FakeTokenStore = FakeTokenStore(),
        store: FakePipelineStore = FakePipelineStore(),
        applier: WalletSyncMasterDataPlanApplying? = nil,
        uploadCap: Int = WalletSyncMasterDataManualPipeline.defaultUploadCap,
        sampleLimit: Int = WalletSyncMasterDataManualPipeline.defaultSampleLimit
    ) -> WalletSyncMasterDataManualPipeline {
        WalletSyncMasterDataManualPipeline(
            zoneEnsurer: boundary,
            recordSaver: boundary,
            changedRecordFetcher: boundary,
            tokenStore: tokenStore,
            source: store,
            localState: store,
            inboxParser: WalletSyncInboxParser(),
            applier: applier ?? FakePlanApplier(),
            uploadCap: uploadCap,
            sampleLimit: sampleLimit
        )
    }

    private func record(for dto: WalletSyncRecordDTO) -> CKRecord {
        WalletSyncCKRecordAdapter.ckRecord(from: dto)
    }

    private func accountDTO(id: UUID, balance: Double = 123) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.account.recordName(for: id),
            entity: .account,
            id: id,
            updatedAt: Date(),
            fields: [
                "name": .string("Remote Account"),
                "balance": .double(balance),
                "type": .string(AccountType.cash.rawValue),
                "isActive": .bool(true),
                "recognitionAliases": .stringArray([]),
                "recognitionCardEndings": .stringArray([]),
                "appearanceColor": .null,
                "createdAt": .date(Date())
            ]
        )
    }

    private func categoryDTO(id: UUID) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.category.recordName(for: id),
            entity: .category,
            id: id,
            updatedAt: Date(),
            fields: [
                "name": .string("Remote Category"),
                "subcategories": .stringArray(["One"]),
                "isActive": .bool(true),
                "inactiveSubcategoryNames": .stringArray([]),
                "createdAt": .date(Date())
            ]
        )
    }

    private func makeAccount(id: UUID = UUID(), balance: Double = 0) -> Account {
        Account(id: id, name: "Cash", balance: balance, type: .cash)
    }

    private func makeCategory(id: UUID = UUID()) -> WalletBoard.Category {
        WalletBoard.Category(id: id, name: "Food", subcategories: ["Supermarket"])
    }

    private func makeWalletEvent(id: UUID = UUID()) -> WalletEvent {
        var event = WalletEvent(
            name: "Groceries",
            categoryName: "Food",
            subCategoryName: "Supermarket",
            defaultAccountName: nil,
            isFavorite: false
        )
        event.id = id
        return event
    }

    private final class PipelineEvents {
        var values: [String] = []
    }

    private final class FakePipelineBoundary: WalletSyncMasterDataZoneEnsuring, WalletSyncMasterDataRecordSaving, WalletSyncDryRunChangedRecordFetching {
        var events: PipelineEvents?
        var savedRecords: [CKRecord] = []
        var fetchToken: Data?
        var fetchResult: WalletSyncCloudKitFetchResult

        init(
            events: PipelineEvents? = nil,
            fetchResult: WalletSyncCloudKitFetchResult = WalletSyncCloudKitFetchResult(records: [])
        ) {
            self.events = events
            self.fetchResult = fetchResult
        }

        func ensureSyncZone() async throws {
            events?.values.append("ensure")
        }

        func saveRecords(_ records: [CKRecord]) async throws -> [CKRecord] {
            events?.values.append("save")
            savedRecords = records
            return records
        }

        func fetchChangedRecords(since changeToken: Data?) async throws -> WalletSyncCloudKitFetchResult {
            events?.values.append("fetch")
            fetchToken = changeToken
            return fetchResult
        }
    }

    private final class FakeTokenStore: WalletSyncChangeTokenStoring {
        var token: Data?
        var saveCount = 0

        init(token: Data? = nil) {
            self.token = token
        }

        func loadWalletSyncZoneChangeTokenData() -> Data? { token }
        func saveWalletSyncZoneChangeTokenData(_ tokenData: Data) {
            token = tokenData
            saveCount += 1
        }
        func clearWalletSyncZoneChangeTokenData() { token = nil }
        func hasWalletSyncZoneChangeToken() -> Bool { token != nil }
    }

    private final class FakePlanApplier: WalletSyncMasterDataPlanApplying {
        var events: PipelineEvents?
        var receivedPlan: WalletSyncMasterDataApplyPlanSummary?

        init(events: PipelineEvents? = nil) {
            self.events = events
        }

        func apply(_ plan: WalletSyncMasterDataApplyPlanSummary) -> WalletSyncMasterDataApplyResult {
            events?.values.append("apply")
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

    private final class FakePipelineStore: WalletSyncMasterDataSourceReading, WalletSyncMergePlanLocalStateReading, WalletSyncMasterDataApplyingStore {
        var accounts: [Account]
        var categories: [WalletBoard.Category]
        var walletEvents: [WalletEvent]

        var financialEventMutationCount = 0
        var budgetMutationCount = 0
        var creditCardMutationCount = 0
        var debtMutationCount = 0
        var recurringMutationCount = 0

        init(
            accounts: [Account] = [],
            categories: [WalletBoard.Category] = [],
            walletEvents: [WalletEvent] = []
        ) {
            self.accounts = accounts
            self.categories = categories
            self.walletEvents = walletEvents
        }

        func containsAccount(id: UUID) -> Bool {
            accounts.contains { $0.id == id }
        }

        func containsCategory(id: UUID) -> Bool {
            categories.contains { $0.id == id }
        }

        func containsWalletEvent(id: UUID) -> Bool {
            walletEvents.contains { $0.id == id }
        }
    }
}
