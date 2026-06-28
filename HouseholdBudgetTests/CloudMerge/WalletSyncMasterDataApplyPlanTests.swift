import XCTest
import CloudKit
@testable import WalletBoard

final class WalletSyncMasterDataApplyPlanTests: XCTestCase {

    func testSyntheticDebugCategoryRecordNameIsStable() throws {
        let first = WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryRecord()
        let second = WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryRecord()

        XCTAssertEqual(first.recordID.recordName, second.recordID.recordName)
        XCTAssertEqual(first.recordID.recordName, WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryRecordName)
    }

    func testSyntheticDebugCategoryIsCategoryOnly() throws {
        let dto = try WalletSyncCKRecordAdapter.dto(
            from: WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryRecord()
        )

        XCTAssertEqual(dto.entity, .category)
        XCTAssertEqual(dto.id, WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryID)
    }

    func testSyntheticDebugCategoryContainsNoFinancialOrAccountFields() throws {
        let dto = try WalletSyncCKRecordAdapter.dto(
            from: WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryRecord()
        )
        let forbiddenFields = [
            "balance",
            "amount",
            "accountName",
            "defaultAccountName",
            "transactionID",
            "financialEventID",
            "cardID"
        ]

        for field in forbiddenFields {
            XCTAssertNil(dto.fields[field])
        }
    }

    func testSyntheticDebugCategoryIsInactive() throws {
        let dto = try WalletSyncCKRecordAdapter.dto(
            from: WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryRecord()
        )

        XCTAssertEqual(dto.fields["name"], .string(WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryName))
        XCTAssertEqual(dto.fields["isActive"], .bool(false))
    }

    func testMasterDataApplyPlanIncludesAccountCategoryAndWalletEventOnly() {
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())
        let records = [
            record(for: accountDTO(id: UUID())),
            record(for: categoryDTO(id: UUID())),
            record(for: walletEventDTO(id: UUID()))
        ]

        let plan = planner.makePlan(changedRecords: records, deletedRecordNames: [])

        XCTAssertEqual(plan.plannedCreateCount, 3)
        XCTAssertEqual(plan.blockedCount, 0)
    }

    func testMalformedFinancialEventIsBlocked() {
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())
        let dto = WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.financialEvent.recordName(for: UUID()),
            entity: .financialEvent,
            id: UUID()
        )

        let plan = planner.makePlan(changedRecords: [record(for: dto)], deletedRecordNames: [])

        XCTAssertEqual(plan.blockedCount, 1)
    }

    func testFinancialEventCreateAndUpdatePlansUseTimestampGuards() {
        let existingID = UUID()
        let newID = UUID()
        let localUpdatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let remoteUpdatedAt = Date(timeIntervalSince1970: 1_800_000_100)
        let planner = WalletSyncMasterDataApplyPlanBuilder(
            localState: FakeLocalState(financialEventUpdatedAtByID: [existingID: localUpdatedAt])
        )

        let plan = planner.makePlan(
            changedRecords: [
                record(for: financialEventDTO(id: newID, updatedAt: remoteUpdatedAt)),
                record(for: financialEventDTO(id: existingID, updatedAt: remoteUpdatedAt))
            ],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.plannedCreateCount, 1)
        XCTAssertEqual(plan.plannedUpdateCount, 1)
    }

    func testMonthlyBudgetItemAndHouseholdSettingsAreBlocked() {
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())
        let records = [
            record(for: WalletSyncRecordDTO(recordName: WalletSyncRecordEntity.monthlyBudgetItem.recordName(for: UUID()), entity: .monthlyBudgetItem, id: UUID())),
            record(for: WalletSyncRecordDTO(recordName: WalletSyncRecordEntity.householdSettings.recordName(for: UUID()), entity: .householdSettings, id: UUID()))
        ]

        let plan = planner.makePlan(changedRecords: records, deletedRecordNames: [])

        XCTAssertEqual(plan.blockedCount, 2)
    }

    func testDecodeFailuresBecomeFailedPlanItems() {
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())
        let badRecord = CKRecord(recordType: WalletSyncCKRecordAdapter.recordType)

        let plan = planner.makePlan(changedRecords: [badRecord], deletedRecordNames: [])

        XCTAssertEqual(plan.failedCount, 1)
    }

    func testAccountCreateAndUpdatePlansAreProducedByIDExistence() {
        let existingID = UUID()
        let newID = UUID()
        let localUpdatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let remoteUpdatedAt = Date(timeIntervalSince1970: 1_800_000_100)
        let planner = WalletSyncMasterDataApplyPlanBuilder(
            localState: FakeLocalState(accountUpdatedAtByID: [existingID: localUpdatedAt])
        )

        let plan = planner.makePlan(
            changedRecords: [record(for: accountDTO(id: newID)), record(for: accountDTO(id: existingID, updatedAt: remoteUpdatedAt))],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.plannedCreateCount, 1)
        XCTAssertEqual(plan.plannedUpdateCount, 1)
    }

    func testAccountDeleteIsPlannedAsSoftDisableOnly() {
        let id = UUID()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState(accountIDs: [id]))

        let plan = planner.makePlan(changedRecords: [], deletedRecordNames: [WalletSyncRecordEntity.account.recordName(for: id)])

        XCTAssertEqual(plan.plannedDisableCount, 1)
    }

    func testCategoryCreateUpdateDeleteBehaviorIsPlannedSafely() {
        let existingID = UUID()
        let newID = UUID()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState(categoryIDs: [existingID]))

        let plan = planner.makePlan(
            changedRecords: [record(for: categoryDTO(id: newID)), record(for: categoryDTO(id: existingID))],
            deletedRecordNames: [WalletSyncRecordEntity.category.recordName(for: existingID)]
        )

        XCTAssertEqual(plan.plannedCreateCount, 1)
        XCTAssertEqual(plan.plannedUpdateCount, 1)
        XCTAssertEqual(plan.plannedDisableCount, 1)
    }

    func testPlanBlocksSyntheticCategoryCreateSoDebugCategoryIsNotUserData() {
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())

        let plan = planner.makePlan(
            changedRecords: [WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryRecord()],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.plannedCreateCount, 0)
        XCTAssertEqual(plan.blockedCount, 1)
    }

    func testPlanBlocksSyntheticCategoryUpdateSoDebugCategoryIsNotUserData() {
        let planner = WalletSyncMasterDataApplyPlanBuilder(
            localState: FakeLocalState(categoryIDs: [WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryID])
        )

        let plan = planner.makePlan(
            changedRecords: [WalletSyncDebugSyntheticMasterDataChangeFactory.debugCategoryRecord()],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.plannedUpdateCount, 0)
        XCTAssertEqual(plan.blockedCount, 1)
    }

    func testWalletEventCreateUpdateDeleteBehaviorIsPlannedSafely() {
        let existingID = UUID()
        let newID = UUID()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState(walletEventIDs: [existingID]))

        let plan = planner.makePlan(
            changedRecords: [record(for: walletEventDTO(id: newID)), record(for: walletEventDTO(id: existingID))],
            deletedRecordNames: [WalletSyncRecordEntity.walletEvent.recordName(for: existingID)]
        )

        XCTAssertEqual(plan.plannedCreateCount, 1)
        XCTAssertEqual(plan.plannedUpdateCount, 1)
        XCTAssertEqual(plan.plannedDisableCount, 1)
    }

    func testAccountCreateCopiesStoredBalanceFieldIntoApplyPlan() {
        let id = UUID()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())
        var dto = accountDTO(id: id)
        dto.fields["balance"] = .double(99_999)

        let plan = planner.makePlan(changedRecords: [record(for: dto)], deletedRecordNames: [])

        guard case .createAccount(let account) = plan.items.first?.action else {
            XCTFail("Expected create account action")
            return
        }
        XCTAssertEqual(account.balance, 99_999)
    }

    func testAccountUpdateCopiesBalanceOnlyWhenRemoteIsClearlyNewer() {
        let id = UUID()
        let localUpdatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let remoteUpdatedAt = Date(timeIntervalSince1970: 1_800_000_100)
        let planner = WalletSyncMasterDataApplyPlanBuilder(
            localState: FakeLocalState(accountUpdatedAtByID: [id: localUpdatedAt])
        )
        var dto = accountDTO(id: id, updatedAt: remoteUpdatedAt)
        dto.fields["balance"] = .double(77_777)

        let plan = planner.makePlan(changedRecords: [record(for: dto)], deletedRecordNames: [])

        guard case .updateAccount(let account) = plan.items.first?.action else {
            XCTFail("Expected update account action")
            return
        }
        XCTAssertEqual(account.balance, 77_777)
    }

    func testAccountUpdateBlocksWhenLocalIsNewer() {
        let id = UUID()
        let planner = WalletSyncMasterDataApplyPlanBuilder(
            localState: FakeLocalState(accountUpdatedAtByID: [id: Date(timeIntervalSince1970: 1_800_000_200)])
        )

        let plan = planner.makePlan(
            changedRecords: [record(for: accountDTO(id: id, updatedAt: Date(timeIntervalSince1970: 1_800_000_100)))],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.blockedCount, 1)
        XCTAssertTrue(plan.items.contains {
            if case .blocked(.localAccountNewer) = $0.action { return true }
            return false
        })
    }

    func testAccountUpdateBlocksWhenTimestampIsMissingOrEqual() {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_800_000_100)
        let planner = WalletSyncMasterDataApplyPlanBuilder(
            localState: FakeLocalState(accountUpdatedAtByID: [id: timestamp])
        )
        var missingTimestampDTO = accountDTO(id: id, updatedAt: timestamp)
        missingTimestampDTO.updatedAt = nil

        let missingPlan = planner.makePlan(changedRecords: [record(for: missingTimestampDTO)], deletedRecordNames: [])
        let equalPlan = planner.makePlan(changedRecords: [record(for: accountDTO(id: id, updatedAt: timestamp))], deletedRecordNames: [])

        XCTAssertEqual(missingPlan.blockedCount, 1)
        XCTAssertEqual(equalPlan.blockedCount, 1)
        XCTAssertTrue((missingPlan.items + equalPlan.items).allSatisfy {
            if case .blocked(.ambiguousAccountTimestamp) = $0.action { return true }
            return false
        })
    }

    func testSummaryCountsAreCorrect() {
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())
        let badRecord = CKRecord(recordType: WalletSyncCKRecordAdapter.recordType)

        let plan = planner.makePlan(
            changedRecords: [
                record(for: accountDTO(id: UUID())),
                record(for: WalletSyncRecordDTO(recordName: WalletSyncRecordEntity.financialEvent.recordName(for: UUID()), entity: .financialEvent, id: UUID())),
                badRecord
            ],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.plannedCreateCount, 1)
        XCTAssertEqual(plan.blockedCount, 1)
        XCTAssertEqual(plan.failedCount, 1)
    }

    // MARK: - Same-run parent availability tests

    func testCreditCardPurchasePlansAsCreateWhenParentCreditCardIsInSameBatch() {
        let cardID = UUID()
        let purchaseID = UUID()
        let updatedAt = Date()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())

        let plan = planner.makePlan(
            changedRecords: [
                record(for: creditCardDTO(id: cardID)),
                record(for: creditCardPurchaseDTO(id: purchaseID, cardID: cardID, updatedAt: updatedAt))
            ],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.plannedCreateCount, 2)
        XCTAssertEqual(plan.blockedCount, 0)
    }

    func testCreditCardPaymentPlansAsCreateWhenParentCreditCardIsInSameBatch() {
        let cardID = UUID()
        let paymentID = UUID()
        let updatedAt = Date()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())

        let plan = planner.makePlan(
            changedRecords: [
                record(for: creditCardDTO(id: cardID)),
                record(for: creditCardPaymentDTO(id: paymentID, cardID: cardID, updatedAt: updatedAt))
            ],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.plannedCreateCount, 2)
        XCTAssertEqual(plan.blockedCount, 0)
    }

    func testPersonDebtEntryPlansAsCreateWhenParentPersonDebtIsInSameBatch() {
        let debtID = UUID()
        let entryID = UUID()
        let updatedAt = Date()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())

        let plan = planner.makePlan(
            changedRecords: [
                record(for: personDebtDTO(id: debtID)),
                record(for: personDebtEntryDTO(id: entryID, debtID: debtID, updatedAt: updatedAt))
            ],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.plannedCreateCount, 2)
        XCTAssertEqual(plan.blockedCount, 0)
    }

    func testMonthlyBudgetItemPlansAsCreateWhenParentBudgetIsInSameBatch() {
        let budgetID = UUID()
        let itemID = UUID()
        let updatedAt = Date()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())

        let plan = planner.makePlan(
            changedRecords: [
                record(for: monthlyBudgetDTO(id: budgetID)),
                record(for: monthlyBudgetItemDTO(id: itemID, parentBudgetID: budgetID, updatedAt: updatedAt))
            ],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.plannedCreateCount, 2)
        XCTAssertEqual(plan.blockedCount, 0)
    }

    func testChildRemainsBlockedWhenParentNeitherLocalNorInBatch() {
        let cardID = UUID()
        let purchaseID = UUID()
        let updatedAt = Date()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())

        let plan = planner.makePlan(
            changedRecords: [
                record(for: creditCardPurchaseDTO(id: purchaseID, cardID: cardID, updatedAt: updatedAt))
            ],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.plannedCreateCount, 0)
        XCTAssertEqual(plan.blockedCount, 1)
        XCTAssertEqual(plan.items.first?.action, .blocked(reason: .missingParentRecord))
    }

    func testChildRemainsBlockedWhenParentInBatchIsInvalid() {
        let cardID = UUID()
        let purchaseID = UUID()
        let updatedAt = Date()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())
        let invalidCardDTO = WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.creditCard.recordName(for: cardID),
            entity: .creditCard,
            id: cardID
        )

        let plan = planner.makePlan(
            changedRecords: [
                record(for: invalidCardDTO),
                record(for: creditCardPurchaseDTO(id: purchaseID, cardID: cardID, updatedAt: updatedAt))
            ],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.plannedCreateCount, 0)
        XCTAssertEqual(plan.blockedCount, 2)
    }

    func testLocalParentStillAuthorizesChildWhenParentNotInBatch() {
        let cardID = UUID()
        let purchaseID = UUID()
        let updatedAt = Date()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState(creditCardIDs: [cardID]))

        let plan = planner.makePlan(
            changedRecords: [
                record(for: creditCardPurchaseDTO(id: purchaseID, cardID: cardID, updatedAt: updatedAt))
            ],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.plannedCreateCount, 1)
        XCTAssertEqual(plan.blockedCount, 0)
    }

    func testChildOrderInBatchDoesNotMatterForPlanning() {
        let cardID = UUID()
        let purchaseID = UUID()
        let updatedAt = Date()
        let planner = WalletSyncMasterDataApplyPlanBuilder(localState: FakeLocalState())

        let plan = planner.makePlan(
            changedRecords: [
                record(for: creditCardPurchaseDTO(id: purchaseID, cardID: cardID, updatedAt: updatedAt)),
                record(for: creditCardDTO(id: cardID))
            ],
            deletedRecordNames: []
        )

        XCTAssertEqual(plan.plannedCreateCount, 2)
        XCTAssertEqual(plan.blockedCount, 0)
    }

    // MARK: - Helpers

    private func record(for dto: WalletSyncRecordDTO) -> CKRecord {
        WalletSyncCKRecordAdapter.ckRecord(from: dto)
    }

    private func creditCardDTO(id: UUID) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.creditCard.recordName(for: id),
            entity: .creditCard,
            id: id,
            updatedAt: Date(),
            fields: [
                "name": .string("Test Card"),
                "bankName": .string("Test Bank"),
                "cardNetwork": .string(CreditCardNetwork.visa.rawValue),
                "creditLimit": .double(5000),
                "openingOutstandingBalance": .double(0),
                "statementClosingDay": .int(25),
                "paymentDueDay": .int(15),
                "isActive": .bool(true),
                "createdAt": .date(Date())
            ]
        )
    }

    private func creditCardPurchaseDTO(id: UUID, cardID: UUID, updatedAt: Date) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.creditCardPurchase.recordName(for: id),
            entity: .creditCardPurchase,
            id: id,
            updatedAt: updatedAt,
            fields: [
                "cardID": .uuid(cardID),
                "title": .string("Test Purchase"),
                "amount": .double(100),
                "purchaseDate": .date(updatedAt),
                "categoryName": .string("Food"),
                "subCategoryName": .string("Supermarket"),
                "createdAt": .date(updatedAt)
            ]
        )
    }

    private func creditCardPaymentDTO(id: UUID, cardID: UUID, updatedAt: Date) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.creditCardPayment.recordName(for: id),
            entity: .creditCardPayment,
            id: id,
            updatedAt: updatedAt,
            fields: [
                "cardID": .uuid(cardID),
                "fromAccountName": .string("Cash"),
                "amount": .double(200),
                "paymentDate": .date(updatedAt),
                "createdAt": .date(updatedAt)
            ]
        )
    }

    private func personDebtDTO(id: UUID) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.personDebt.recordName(for: id),
            entity: .personDebt,
            id: id,
            updatedAt: Date(),
            fields: [
                "personName": .string("Test Person"),
                "kind": .string(PersonDebtKind.iOwe.rawValue),
                "originalAmount": .double(500),
                "createdAt": .date(Date())
            ]
        )
    }

    private func personDebtEntryDTO(id: UUID, debtID: UUID, updatedAt: Date) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.personDebtEntry.recordName(for: id),
            entity: .personDebtEntry,
            id: id,
            updatedAt: updatedAt,
            fields: [
                "debtID": .uuid(debtID),
                "entryType": .string(PersonDebtEntryType.repaymentPaid.rawValue),
                "amount": .double(100),
                "accountName": .string("Cash"),
                "date": .date(updatedAt),
                "createdAt": .date(updatedAt)
            ]
        )
    }

    private func monthlyBudgetDTO(id: UUID) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.monthlyBudget.recordName(for: id),
            entity: .monthlyBudget,
            id: id,
            updatedAt: Date(),
            fields: [
                "year": .int(2026),
                "month": .int(6),
                "createdAt": .date(Date())
            ]
        )
    }

    private func monthlyBudgetItemDTO(id: UUID, parentBudgetID: UUID, updatedAt: Date) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.monthlyBudgetItem.recordName(for: id),
            entity: .monthlyBudgetItem,
            id: id,
            updatedAt: updatedAt,
            fields: [
                "parentBudgetID": .uuid(parentBudgetID),
                "categoryName": .string("Food"),
                "plannedAmount": .double(500),
                "createdAt": .date(updatedAt)
            ]
        )
    }

    private func accountDTO(id: UUID, updatedAt: Date = Date()) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.account.recordName(for: id),
            entity: .account,
            id: id,
            updatedAt: updatedAt,
            fields: [
                "name": .string("Remote Account"),
                "balance": .double(123),
                "type": .string(AccountType.cash.rawValue),
                "isActive": .bool(true),
                "recognitionAliases": .stringArray(["Alias"]),
                "recognitionCardEndings": .stringArray(["1234"]),
                "appearanceColor": .string(ProviderAppearanceColor.green.rawValue),
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

    private func walletEventDTO(id: UUID) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.walletEvent.recordName(for: id),
            entity: .walletEvent,
            id: id,
            updatedAt: Date(),
            fields: [
                "name": .string("Remote Event"),
                "categoryName": .string("Food"),
                "subCategoryName": .string("Supermarket"),
                "defaultAccountName": .null,
                "isFavorite": .bool(true),
                "isActive": .bool(true),
                "createdAt": .date(Date())
            ]
        )
    }

    private func financialEventDTO(id: UUID, updatedAt: Date) -> WalletSyncRecordDTO {
        WalletSyncRecordDTO(
            recordName: WalletSyncRecordEntity.financialEvent.recordName(for: id),
            entity: .financialEvent,
            id: id,
            updatedAt: updatedAt,
            fields: [
                "type": .string(FinancialEventType.expense.rawValue),
                "status": .string(FinancialEventStatus.unpaid.rawValue),
                "title": .string("Remote Event"),
                "amount": .double(100),
                "date": .date(updatedAt),
                "accountName": .null,
                "destinationAccountName": .null,
                "paymentMethodName": .null,
                "walletEventName": .null,
                "categoryName": .null,
                "subCategoryName": .null,
                "incomeType": .null,
                "reimbursementCategoryName": .null,
                "repeatRule": .string(RepeatRule.none.rawValue),
                "recurringEndKind": .null,
                "recurringEndDate": .null,
                "recurringEndPaymentCount": .null,
                "recurringAmountMode": .null,
                "recurringEstimatedAmount": .null,
                "confidence": .null,
                "sourceInstallmentPlanID": .null,
                "sourceRecurringEventID": .null,
                "recurringOccurrenceYear": .null,
                "recurringOccurrenceMonth": .null,
                "note": .null,
                "createdAt": .date(updatedAt)
            ]
        )
    }

    private final class FakeLocalState: WalletSyncMergePlanLocalStateReading {
        var accountIDs: Set<UUID>
        var categoryIDs: Set<UUID>
        var walletEventIDs: Set<UUID>
        var creditCardIDs: Set<UUID>
        var personDebtIDs: Set<UUID>
        var monthlyBudgetIDs: Set<UUID>
        var accountUpdatedAtByID: [UUID: Date]
        var financialEventUpdatedAtByID: [UUID: Date]

        init(
            accountIDs: Set<UUID> = [],
            categoryIDs: Set<UUID> = [],
            walletEventIDs: Set<UUID> = [],
            creditCardIDs: Set<UUID> = [],
            personDebtIDs: Set<UUID> = [],
            monthlyBudgetIDs: Set<UUID> = [],
            accountUpdatedAtByID: [UUID: Date] = [:],
            financialEventUpdatedAtByID: [UUID: Date] = [:]
        ) {
            self.accountIDs = accountIDs
            self.categoryIDs = categoryIDs
            self.walletEventIDs = walletEventIDs
            self.creditCardIDs = creditCardIDs
            self.personDebtIDs = personDebtIDs
            self.monthlyBudgetIDs = monthlyBudgetIDs
            self.accountUpdatedAtByID = accountUpdatedAtByID
            self.financialEventUpdatedAtByID = financialEventUpdatedAtByID
        }

        func containsAccount(id: UUID) -> Bool { accountIDs.contains(id) || accountUpdatedAtByID[id] != nil }
        func accountUpdatedAt(id: UUID) -> Date? { accountUpdatedAtByID[id] }
        func containsCategory(id: UUID) -> Bool { categoryIDs.contains(id) }
        func containsWalletEvent(id: UUID) -> Bool { walletEventIDs.contains(id) }
        func containsCreditCard(id: UUID) -> Bool { creditCardIDs.contains(id) }
        func containsPersonDebt(id: UUID) -> Bool { personDebtIDs.contains(id) }
        func containsMonthlyBudget(id: UUID) -> Bool { monthlyBudgetIDs.contains(id) }
        func containsFinancialEvent(id: UUID) -> Bool { financialEventUpdatedAtByID[id] != nil }
        func financialEventUpdatedAt(id: UUID) -> Date? { financialEventUpdatedAtByID[id] }
    }
}
