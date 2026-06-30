import XCTest
@testable import WalletBoard

final class WalletStoreTestabilityTests: XCTestCase {

    private var suiteNames: [String] = []

    override func tearDown() {
        for suiteName in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        suiteNames.removeAll()
        super.tearDown()
    }

    func testWalletStoreCanInitializeCleanlyWithIsolatedUserDefaults() {
        let defaults = makeIsolatedUserDefaults()

        let store = WalletStore(userDefaults: defaults)

        XCTAssertTrue(store.accounts.isEmpty)
        XCTAssertTrue(store.categories.isEmpty)
        XCTAssertTrue(store.walletEvents.isEmpty)
        XCTAssertTrue(store.financialEvents.isEmpty)
        XCTAssertTrue(store.installmentPlans.isEmpty)
    }

    func testWalletStoreDoesNotReadFromStandardUserDefaultsWhenInjected() throws {
        let defaults = makeIsolatedUserDefaults()
        let isolatedDisplayName = "Isolated Test Wallet"
        try write(isolatedDisplayName, key: "wallet_display_name", to: defaults)

        let store = WalletStore(userDefaults: defaults)

        XCTAssertEqual(store.displayName, isolatedDisplayName)
    }

    func testWalletStorePersistsToInjectedUserDefaults() {
        let defaults = makeIsolatedUserDefaults()
        let firstStore = WalletStore(userDefaults: defaults)

        firstStore.displayName = "Persisted Test Wallet"
        let secondStore = WalletStore(userDefaults: defaults)

        XCTAssertEqual(secondStore.displayName, "Persisted Test Wallet")
    }

    func testUpdateAccountAdvancesAccountUpdatedAtAndLocalDataTimestamp() throws {
        let store = WalletStore(userDefaults: makeIsolatedUserDefaults())
        let oldDate = Date(timeIntervalSince1970: 1_000)
        let account = Account(
            name: "Manual Balance Account",
            balance: 100,
            type: .bank,
            createdAt: oldDate,
            updatedAt: oldDate
        )
        store.accounts = [account]
        store.localDataUpdatedAt = oldDate

        store.updateAccount(
            accountID: account.id,
            name: account.name,
            type: account.type,
            balance: 250,
            isActive: true
        )

        let updatedAccount = try XCTUnwrap(store.accounts.first)
        XCTAssertEqual(updatedAccount.balance, 250, accuracy: 0.001)
        XCTAssertGreaterThan(updatedAccount.updatedAt, oldDate)
        XCTAssertGreaterThan(store.localDataUpdatedAt, oldDate)
    }

    func testUpdateAccountBalanceAdvancesAccountUpdatedAtAndLocalDataTimestamp() throws {
        let store = WalletStore(userDefaults: makeIsolatedUserDefaults())
        let oldDate = Date(timeIntervalSince1970: 1_000)
        let account = Account(
            name: "Direct Balance Account",
            balance: 100,
            type: .cash,
            createdAt: oldDate,
            updatedAt: oldDate
        )
        store.accounts = [account]
        store.localDataUpdatedAt = oldDate

        store.updateAccountBalance(accountID: account.id, newBalance: 300)

        let updatedAccount = try XCTUnwrap(store.accounts.first)
        XCTAssertEqual(updatedAccount.balance, 300, accuracy: 0.001)
        XCTAssertGreaterThan(updatedAccount.updatedAt, oldDate)
        XCTAssertGreaterThan(store.localDataUpdatedAt, oldDate)
    }

    func testDeleteFinancialEventRecordsSyncableLocalDeletionMarker() throws {
        let defaults = makeIsolatedUserDefaults()
        let store = WalletStore(userDefaults: defaults)
        var event = FinancialEvent(
            type: .expense,
            status: .unpaid,
            title: "Delete Marker Event",
            amount: 50,
            date: Date(),
            accountName: nil,
            paymentMethodName: nil,
            categoryName: "Groceries",
            subCategoryName: "Groceries"
        )
        event.id = UUID()
        store.financialEvents = [event]

        store.deleteFinancialEvent(event)

        let syncState = WalletSyncStateStore(keyValueStore: defaults)
        XCTAssertTrue(syncState.isFinancialEventDeletedLocally(id: event.id))
        XCTAssertTrue(syncState.isRecordDeletedLocally(entity: .financialEvent, id: event.id))
        XCTAssertEqual(syncState.syncableFinancialEventDeletionDTOs().first?.id, event.id)
        XCTAssertTrue(store.financialEvents.isEmpty)
    }

    func testDeleteCreditCardPurchaseRecordsLocalTombstone() {
        let defaults = makeIsolatedUserDefaults()
        let store = WalletStore(userDefaults: defaults)
        let purchase = CreditCardPurchase(
            id: UUID(),
            cardID: UUID(),
            title: "Deleted Purchase",
            amount: 100,
            purchaseDate: Date(),
            categoryName: "Groceries",
            subCategoryName: "Groceries",
            note: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        store.creditCardPurchases = [purchase]

        store.deleteCreditCardPurchase(purchase)

        let syncState = WalletSyncStateStore(keyValueStore: defaults)
        XCTAssertTrue(syncState.isRecordDeletedLocally(entity: .creditCardPurchase, id: purchase.id))
        XCTAssertTrue(syncState.isHighRiskRecordDeletedLocally(entity: .creditCardPurchase, id: purchase.id))
        XCTAssertEqual(syncState.syncableHighRiskRecordDeletionDTOs().first?.entity, .creditCardPurchaseDeletion)
        XCTAssertTrue(store.creditCardPurchases.isEmpty)
    }

    func testDeleteCreditCardPaymentRecordsSyncableHighRiskDeletionMarker() {
        let defaults = makeIsolatedUserDefaults()
        let store = WalletStore(userDefaults: defaults)
        let account = Account(name: "Cash", balance: 500, type: .cash)
        let cardID = UUID()
        let payment = CreditCardPayment(
            id: UUID(),
            cardID: cardID,
            fromAccountName: account.name,
            amount: 100,
            paymentDate: Date(),
            note: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        store.accounts = [account]
        store.creditCardPayments = [payment]

        XCTAssertTrue(store.deleteCreditCardPayment(payment))

        let syncState = WalletSyncStateStore(keyValueStore: defaults)
        XCTAssertTrue(syncState.isHighRiskRecordDeletedLocally(entity: .creditCardPayment, id: payment.id))
        XCTAssertEqual(syncState.syncableHighRiskRecordDeletionDTOs().first?.entity, .creditCardPaymentDeletion)
        XCTAssertTrue(store.creditCardPayments.isEmpty)
        XCTAssertEqual(store.accounts.first?.balance, 600)
    }

    func testDeletePersonDebtRecordsParentAndLinkedEntryDeletionMarkers() {
        let defaults = makeIsolatedUserDefaults()
        let store = WalletStore(userDefaults: defaults)
        let debt = PersonDebt(personName: "Test Person", kind: .iOwe, originalAmount: 500)
        let entry = PersonDebtEntry(
            id: UUID(),
            debtID: debt.id,
            entryType: .repaymentPaid,
            amount: 100,
            accountName: "Cash",
            date: Date()
        )
        store.personDebts = [debt]
        store.personDebtEntries = [entry]

        XCTAssertTrue(store.deletePersonDebt(debt))

        let syncState = WalletSyncStateStore(keyValueStore: defaults)
        XCTAssertTrue(syncState.isHighRiskRecordDeletedLocally(entity: .personDebt, id: debt.id))
        XCTAssertTrue(syncState.isHighRiskRecordDeletedLocally(entity: .personDebtEntry, id: entry.id))
        XCTAssertTrue(syncState.syncableHighRiskRecordDeletionDTOs().contains {
            $0.entity == .personDebtDeletion && $0.id == debt.id
        })
        XCTAssertTrue(syncState.syncableHighRiskRecordDeletionDTOs().contains {
            $0.entity == .personDebtEntryDeletion && $0.id == entry.id
        })
        XCTAssertTrue(store.personDebts.isEmpty)
        XCTAssertTrue(store.personDebtEntries.isEmpty)
    }

    func testSaveMonthlyBudgetRecordsHighRiskDeletionMarkerForRemovedItems() throws {
        let defaults = makeIsolatedUserDefaults()
        let store = WalletStore(userDefaults: defaults)
        let removedItem = WalletMonthlyBudgetItem(categoryName: "Food", plannedAmount: 100)
        let existingBudget = WalletMonthlyBudget(year: 2026, month: 6, items: [removedItem])
        store.monthlyBudgets = [existingBudget]

        store.saveMonthlyBudget(year: 2026, month: 6, plannedAmountsByCategory: [:])

        let syncState = WalletSyncStateStore(keyValueStore: defaults)
        XCTAssertTrue(syncState.isHighRiskRecordDeletedLocally(entity: .monthlyBudgetItem, id: removedItem.id))
        XCTAssertTrue(syncState.isRecordDeletedLocally(entity: .monthlyBudgetItem, id: removedItem.id))
        let dto = try XCTUnwrap(syncState.syncableHighRiskRecordDeletionDTOs().first)
        XCTAssertEqual(dto.entity, .monthlyBudgetItemDeletion)
        XCTAssertEqual(dto.id, removedItem.id)
        XCTAssertTrue(store.monthlyBudgets.first?.items.isEmpty == true)
    }

    func testSaveMonthlyBudgetPreservesExistingItemIdentityByCategory() throws {
        let defaults = makeIsolatedUserDefaults()
        let store = WalletStore(userDefaults: defaults)
        let oldCreatedAt = Date(timeIntervalSince1970: 1_000)
        let oldUpdatedAt = Date(timeIntervalSince1970: 2_000)
        let unchangedItem = WalletMonthlyBudgetItem(
            id: UUID(),
            categoryName: "Food",
            plannedAmount: 100,
            createdAt: oldCreatedAt,
            updatedAt: oldUpdatedAt
        )
        let editedItem = WalletMonthlyBudgetItem(
            id: UUID(),
            categoryName: "Transport",
            plannedAmount: 200,
            createdAt: oldCreatedAt,
            updatedAt: oldUpdatedAt
        )
        let removedItem = WalletMonthlyBudgetItem(
            id: UUID(),
            categoryName: "Subscriptions",
            plannedAmount: 300,
            createdAt: oldCreatedAt,
            updatedAt: oldUpdatedAt
        )
        let existingBudget = WalletMonthlyBudget(
            id: UUID(),
            year: 2026,
            month: 6,
            items: [unchangedItem, editedItem, removedItem],
            createdAt: oldCreatedAt,
            updatedAt: oldUpdatedAt
        )
        store.monthlyBudgets = [existingBudget]

        store.saveMonthlyBudget(
            year: 2026,
            month: 6,
            plannedAmountsByCategory: [
                "Food": 100,
                "Transport": 250,
                "Utilities": 400
            ]
        )

        let savedBudget = try XCTUnwrap(store.monthlyBudget(year: 2026, month: 6))
        XCTAssertEqual(savedBudget.id, existingBudget.id)

        let savedFood = try XCTUnwrap(savedBudget.items.first { $0.categoryName == "Food" })
        XCTAssertEqual(savedFood.id, unchangedItem.id)
        XCTAssertEqual(savedFood.createdAt, unchangedItem.createdAt)
        XCTAssertEqual(savedFood.updatedAt, unchangedItem.updatedAt)

        let savedTransport = try XCTUnwrap(savedBudget.items.first { $0.categoryName == "Transport" })
        XCTAssertEqual(savedTransport.id, editedItem.id)
        XCTAssertEqual(savedTransport.createdAt, editedItem.createdAt)
        XCTAssertGreaterThan(savedTransport.updatedAt, editedItem.updatedAt)
        XCTAssertEqual(savedTransport.plannedAmount, 250, accuracy: 0.001)

        let savedUtilities = try XCTUnwrap(savedBudget.items.first { $0.categoryName == "Utilities" })
        XCTAssertNotEqual(savedUtilities.id, unchangedItem.id)
        XCTAssertNotEqual(savedUtilities.id, editedItem.id)
        XCTAssertNotEqual(savedUtilities.id, removedItem.id)

        XCTAssertFalse(savedBudget.items.contains { $0.id == removedItem.id })
        let syncState = WalletSyncStateStore(keyValueStore: defaults)
        XCTAssertTrue(syncState.isHighRiskRecordDeletedLocally(entity: .monthlyBudgetItem, id: removedItem.id))
        XCTAssertFalse(syncState.isHighRiskRecordDeletedLocally(entity: .monthlyBudgetItem, id: unchangedItem.id))
        XCTAssertFalse(syncState.isHighRiskRecordDeletedLocally(entity: .monthlyBudgetItem, id: editedItem.id))
    }

    func testSaveMonthlyBudgetPreservesItemIdentityAcrossRepeatedSaves() throws {
        let store = WalletStore(userDefaults: makeIsolatedUserDefaults())

        store.saveMonthlyBudget(
            year: 2026,
            month: 7,
            plannedAmountsByCategory: [
                "Food": 100,
                "Transport": 200
            ]
        )

        let firstSave = try XCTUnwrap(store.monthlyBudget(year: 2026, month: 7))
        let firstBudgetID = firstSave.id
        let firstFood = try XCTUnwrap(firstSave.items.first { $0.categoryName == "Food" })
        let firstTransport = try XCTUnwrap(firstSave.items.first { $0.categoryName == "Transport" })

        store.saveMonthlyBudget(
            year: 2026,
            month: 7,
            plannedAmountsByCategory: [
                "Food": 100,
                "Transport": 250
            ]
        )

        let secondSave = try XCTUnwrap(store.monthlyBudget(year: 2026, month: 7))
        let secondFood = try XCTUnwrap(secondSave.items.first { $0.categoryName == "Food" })
        let secondTransport = try XCTUnwrap(secondSave.items.first { $0.categoryName == "Transport" })

        XCTAssertEqual(secondSave.id, firstBudgetID)
        XCTAssertEqual(secondFood.id, firstFood.id)
        XCTAssertEqual(secondFood.createdAt, firstFood.createdAt)
        XCTAssertEqual(secondFood.updatedAt, firstFood.updatedAt)
        XCTAssertEqual(secondTransport.id, firstTransport.id)
        XCTAssertEqual(secondTransport.createdAt, firstTransport.createdAt)
        XCTAssertGreaterThan(secondTransport.updatedAt, firstTransport.updatedAt)

        store.saveMonthlyBudget(
            year: 2026,
            month: 7,
            plannedAmountsByCategory: [
                "Food": 125,
                "Utilities": 300
            ]
        )

        let thirdSave = try XCTUnwrap(store.monthlyBudget(year: 2026, month: 7))
        let thirdFood = try XCTUnwrap(thirdSave.items.first { $0.categoryName == "Food" })
        let utilities = try XCTUnwrap(thirdSave.items.first { $0.categoryName == "Utilities" })

        XCTAssertEqual(thirdSave.id, firstBudgetID)
        XCTAssertEqual(thirdFood.id, firstFood.id)
        XCTAssertEqual(thirdFood.createdAt, firstFood.createdAt)
        XCTAssertGreaterThan(thirdFood.updatedAt, secondFood.updatedAt)
        XCTAssertFalse(thirdSave.items.contains { $0.id == firstTransport.id })
        XCTAssertNotEqual(utilities.id, firstFood.id)
        XCTAssertNotEqual(utilities.id, firstTransport.id)
    }

    func testBackupSnapshotRoundTripPreservesMonthlyBudgetAndItemIDs() throws {
        let store = WalletStore(userDefaults: makeIsolatedUserDefaults())
        let budgetID = UUID()
        let foodID = UUID()
        let transportID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let updatedAt = Date(timeIntervalSince1970: 2_000)
        store.monthlyBudgets = [
            WalletMonthlyBudget(
                id: budgetID,
                year: 2026,
                month: 8,
                items: [
                    WalletMonthlyBudgetItem(
                        id: foodID,
                        categoryName: "Food",
                        plannedAmount: 100,
                        createdAt: createdAt,
                        updatedAt: updatedAt
                    ),
                    WalletMonthlyBudgetItem(
                        id: transportID,
                        categoryName: "Transport",
                        plannedAmount: 200,
                        createdAt: createdAt,
                        updatedAt: updatedAt
                    )
                ],
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        ]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(store.makeBackupSnapshot())
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedSnapshot = try decoder.decode(WalletDataSnapshot.self, from: data)

        let restoredBudget = try XCTUnwrap(decodedSnapshot.monthlyBudgets.first)
        XCTAssertEqual(restoredBudget.id, budgetID)
        XCTAssertEqual(restoredBudget.items.map(\.id).sorted { $0.uuidString < $1.uuidString }, [foodID, transportID].sorted { $0.uuidString < $1.uuidString })
        XCTAssertEqual(restoredBudget.items.first { $0.id == foodID }?.createdAt, createdAt)
        XCTAssertEqual(restoredBudget.items.first { $0.id == foodID }?.updatedAt, updatedAt)
        XCTAssertEqual(restoredBudget.items.first { $0.id == transportID }?.createdAt, createdAt)
        XCTAssertEqual(restoredBudget.items.first { $0.id == transportID }?.updatedAt, updatedAt)
    }

    func testDeleteSubcategoryIfUnusedRemovesSubcategoryAndWritesNoTombstone() {
        let defaults = makeIsolatedUserDefaults()
        let store = WalletStore(userDefaults: defaults)
        let category = WalletBoard.Category(name: "Food", subcategories: ["Groceries", "Restaurants"])
        store.categories = [category]

        store.deleteSubcategoryIfUnused("Groceries", in: category)

        let updatedCategory = store.categories.first { $0.id == category.id }
        XCTAssertFalse(updatedCategory?.subcategories.contains("Groceries") == true,
            "The deleted subcategory must be removed from the category.")
        XCTAssertTrue(updatedCategory?.subcategories.contains("Restaurants") == true,
            "Other subcategories must not be affected.")
        XCTAssertEqual(store.categories.count, 1,
            "The parent category must not be removed.")
        XCTAssertTrue(store.financialEvents.isEmpty,
            "Deleting a subcategory must not affect financial events.")

        // Subcategories have no sync identity — no tombstone must be written.
        let syncState = WalletSyncStateStore(keyValueStore: defaults)
        XCTAssertFalse(syncState.isRecordDeletedLocally(entity: .category, id: category.id),
            "Deleting a subcategory must not write a tombstone for the parent category.")
    }

    func testResetToSampleDataWritesNoTombstonesForClearedRecords() {
        let defaults = makeIsolatedUserDefaults()
        let store = WalletStore(userDefaults: defaults)

        let event = FinancialEvent(
            type: .expense,
            status: .unpaid,
            title: "Pre-Reset Expense",
            amount: 100,
            date: Date(),
            accountName: nil,
            paymentMethodName: nil,
            categoryName: "Groceries",
            subCategoryName: "Groceries"
        )
        let payment = CreditCardPayment(
            id: UUID(),
            cardID: UUID(),
            fromAccountName: "Cash",
            amount: 500,
            paymentDate: Date(),
            note: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        let eventID = event.id
        let paymentID = payment.id
        store.financialEvents = [event]
        store.creditCardPayments = [payment]

        store.resetToSampleData()

        XCTAssertFalse(store.financialEvents.contains { $0.id == eventID },
            "The pre-reset event must not appear after resetToSampleData.")
        XCTAssertFalse(store.creditCardPayments.contains { $0.id == paymentID },
            "The pre-reset payment must not appear after resetToSampleData.")

        // resetToSampleData silently wipes arrays — it must not write tombstones.
        // A future sync engine must never treat this as a deletion event.
        let syncState = WalletSyncStateStore(keyValueStore: defaults)
        XCTAssertFalse(syncState.isFinancialEventDeletedLocally(id: eventID),
            "resetToSampleData must not write a financial event tombstone for cleared records.")
        XCTAssertFalse(syncState.isHighRiskRecordDeletedLocally(entity: .creditCardPayment, id: paymentID),
            "resetToSampleData must not write a high-risk tombstone for cleared credit card payments.")
    }

    func testDeleteInstallmentPlanRecordsSyncableLocalDeletionMarker() {
        let defaults = makeIsolatedUserDefaults()
        let store = WalletStore(userDefaults: defaults)
        let plan = InstallmentPlan(
            purchaseName: "Valu test",
            totalAmount: 1000,
            installmentCount: 4,
            firstDueDate: Date(),
            categoryName: "Debt",
            subCategoryName: "Installment"
        )
        store.installmentPlans = [plan]

        store.deleteInstallmentPlanAndFutureEvents(plan)

        let syncState = WalletSyncStateStore(keyValueStore: defaults)
        XCTAssertTrue(syncState.isInstallmentPlanDeletedLocally(id: plan.id))
        XCTAssertTrue(syncState.isRecordDeletedLocally(entity: .installmentPlan, id: plan.id))
        XCTAssertEqual(syncState.syncableInstallmentPlanDeletionDTOs().first?.id, plan.id)
        XCTAssertTrue(store.installmentPlans.isEmpty)
    }

    func testClearingIsolatedSuiteGivesCleanWalletStore() {
        let suiteName = makeSuiteName()
        let defaults = makeIsolatedUserDefaults(suiteName: suiteName)
        let firstStore = WalletStore(userDefaults: defaults)

        firstStore.displayName = "Temporary Test Wallet"
        XCTAssertEqual(WalletStore(userDefaults: defaults).displayName, "Temporary Test Wallet")

        defaults.removePersistentDomain(forName: suiteName)
        let cleanStore = WalletStore(userDefaults: defaults)

        XCTAssertEqual(cleanStore.displayName, "")
    }

    func testBankSMSParserUsesCurrentYearForDayMonthOnlyDate() throws {
        let draft = BankSMSImportParser.parse("خصم مبلغ EGP 100.00 عند TEST يوم 15/6")
        let components = try XCTUnwrap(dateComponents(from: draft.transactionDate))
        let currentYear = Calendar.current.component(.year, from: Date())

        XCTAssertEqual(components.year, currentYear)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 15)
    }

    func testBankSMSParserUsesClearFullDateWhenPresent() throws {
        let draft = BankSMSImportParser.parse("خصم مبلغ EGP 100.00 عند TEST بتاريخ 2024/05/12")
        let components = try XCTUnwrap(dateComponents(from: draft.transactionDate))

        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 5)
        XCTAssertEqual(components.day, 12)
    }

    func testBankSMSParserFallsBackToTodayForFarFutureParsedDate() throws {
        let futureYear = Calendar.current.component(.year, from: Date()) + 5
        let draft = BankSMSImportParser.parse("خصم مبلغ EGP 100.00 عند TEST بتاريخ 01/01/\(futureYear)")
        let components = try XCTUnwrap(dateComponents(from: draft.transactionDate))
        let todayComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())

        XCTAssertEqual(components.year, todayComponents.year)
        XCTAssertEqual(components.month, todayComponents.month)
        XCTAssertEqual(components.day, todayComponents.day)
    }

    func testCategorySuggestionDoesNotUseWeakAccountOrPaymentOverlap() {
        let store = makeSuggestionStore()
        store.financialEvents = [
            paidEvent(
                title: "Family Restaurant",
                accountName: "Main Card",
                paymentMethodName: "Credit Card",
                categoryName: "Dining & Delivery",
                subCategoryName: "Restaurants"
            )
        ]

        let suggestion = store.suggestedCategorySubcategory(
            for: CategorySuggestionRequest(
                title: "APPLE",
                accountName: "Main Card",
                paymentMethodName: "Credit Card",
                allowedEventTypes: [.expense],
                includeCreditCardPurchases: false
            )
        )

        XCTAssertNil(suggestion)
    }

    func testCategorySuggestionDoesNotUseApplePayNoteAsAppleMerchantEvidence() {
        let store = makeSuggestionStore()
        store.financialEvents = [
            paidEvent(
                title: "Talabat",
                note: "Paid with Apple Pay",
                categoryName: "Dining & Delivery",
                subCategoryName: "Restaurants"
            ),
            paidEvent(
                title: "Family Restaurant",
                note: "Apple Pay",
                categoryName: "Dining & Delivery",
                subCategoryName: "Restaurants"
            )
        ]

        let suggestion = store.suggestedCategorySubcategory(
            for: CategorySuggestionRequest(
                title: "APPLE",
                merchant: "APPLE",
                allowedEventTypes: [.expense],
                includeCreditCardPurchases: false
            )
        )

        XCTAssertNil(suggestion)
    }

    func testCategorySuggestionUsesStrongAppleMerchantHistory() throws {
        let store = makeSuggestionStore()
        store.financialEvents = [
            paidEvent(
                title: "APPLE.COM/BILL",
                accountName: "Main Card",
                paymentMethodName: "Credit Card",
                categoryName: "Digital & Subscriptions",
                subCategoryName: "Apps & Subscriptions"
            ),
            paidEvent(
                title: "APPLE BILL",
                accountName: "Main Card",
                paymentMethodName: "Credit Card",
                categoryName: "Digital & Subscriptions",
                subCategoryName: "Apps & Subscriptions"
            )
        ]

        let suggestion = try XCTUnwrap(
            store.suggestedCategorySubcategory(
                for: CategorySuggestionRequest(
                    title: "APPLE",
                    merchant: "APPLE",
                    accountName: "Main Card",
                    paymentMethodName: "Credit Card",
                    allowedEventTypes: [.expense],
                    includeCreditCardPurchases: false
                )
            )
        )

        XCTAssertEqual(suggestion.categoryName, "Digital & Subscriptions")
        XCTAssertEqual(suggestion.subCategoryName, "Apps & Subscriptions")
    }

    func testCategorySuggestionSuppressesConflictingMerchantHistory() {
        let store = makeSuggestionStore()
        store.financialEvents = [
            paidEvent(
                title: "APPLE.COM/BILL",
                categoryName: "Digital & Subscriptions",
                subCategoryName: "Apps & Subscriptions"
            ),
            paidEvent(
                title: "APPLE STORE",
                categoryName: "Electronics",
                subCategoryName: "Devices"
            )
        ]

        let suggestion = store.suggestedCategorySubcategory(
            for: CategorySuggestionRequest(
                title: "APPLE",
                merchant: "APPLE",
                allowedEventTypes: [.expense],
                includeCreditCardPurchases: false
            )
        )

        XCTAssertNil(suggestion)
    }

    func testDuplicateDetectionFindsSameSMSImportLikeTransaction() {
        let store = makeSuggestionStore()
        let date = fixedDate()
        store.financialEvents = [
            paidEvent(
                title: "APPLE",
                amount: 199,
                date: date,
                note: "Raw bank SMS text\nDetected ending: 1234",
                categoryName: "Digital & Subscriptions",
                subCategoryName: "Apps & Subscriptions"
            )
        ]

        let duplicate = store.possibleDuplicateTransaction(
            for: TransactionDuplicateCheckRequest(
                title: "APPLE",
                amount: 199,
                date: date,
                accountName: "Main Card",
                paymentMethodName: "Credit Card",
                categoryName: "Digital & Subscriptions",
                subCategoryName: "Apps & Subscriptions",
                importIdentity: "sms-import-identity",
                rawImportNote: "Raw bank SMS text",
                eventType: .expense
            )
        )

        XCTAssertNotNil(duplicate)
    }

    func testDuplicateDetectionDoesNotWarnForSameSMSAmountDifferentMerchantAndSource() {
        let store = makeSuggestionStore()
        let date = fixedDate()
        store.financialEvents = [
            paidEvent(
                title: "Talabat",
                amount: 199,
                date: date,
                accountName: "Food Card",
                paymentMethodName: "Credit Card",
                note: "Talabat raw SMS text\nDetected ending: 9876",
                categoryName: "Dining & Delivery",
                subCategoryName: "Restaurants"
            )
        ]

        let duplicate = store.possibleDuplicateTransaction(
            for: TransactionDuplicateCheckRequest(
                title: "APPLE",
                amount: 199,
                date: date,
                accountName: "Main Card",
                paymentMethodName: "Credit Card",
                categoryName: "Digital & Subscriptions",
                subCategoryName: "Apps & Subscriptions",
                importIdentity: "sms-import-identity",
                rawImportNote: "Apple raw SMS text",
                eventType: .expense
            )
        )

        XCTAssertNil(duplicate)
    }

    func testDuplicateDetectionFindsSameCreditCardPurchaseSameDay() {
        let store = makeSuggestionStore()
        let card = CreditCard(
            name: "Main Card",
            bankName: "Test Bank",
            creditLimit: 10_000,
            statementClosingDay: 15,
            paymentDueDay: 25
        )
        let date = fixedDate()
        store.creditCards = [card]
        store.creditCardPurchases = [
            CreditCardPurchase(
                id: UUID(),
                cardID: card.id,
                title: "APPLE.COM/BILL",
                amount: 199,
                purchaseDate: date,
                categoryName: "Digital & Subscriptions",
                subCategoryName: "Apps & Subscriptions",
                note: nil,
                createdAt: date,
                updatedAt: date
            )
        ]

        let duplicate = store.possibleDuplicateTransaction(
            for: TransactionDuplicateCheckRequest(
                title: "APPLE.COM",
                amount: 199,
                date: date.addingTimeInterval(60 * 60),
                cardID: card.id,
                cardName: card.name,
                categoryName: "Digital & Subscriptions",
                subCategoryName: "Apps & Subscriptions",
                eventType: .expense
            )
        )

        XCTAssertNotNil(duplicate)
    }

    func testDuplicateDetectionDoesNotWarnForRepeatedStandaloneInstaPayFees() {
        let store = makeSuggestionStore()
        let date = fixedDate()
        store.financialEvents = [
            paidEvent(
                title: "InstaPay Fee",
                amount: 2,
                date: date,
                paymentMethodName: "InstaPay",
                categoryName: "Banking & Fees",
                subCategoryName: "InstaPay Fee"
            )
        ]

        let duplicate = store.possibleDuplicateTransaction(
            for: TransactionDuplicateCheckRequest(
                title: "InstaPay Fee",
                amount: 2,
                date: date,
                accountName: "Main Card",
                paymentMethodName: "InstaPay",
                categoryName: "Banking & Fees",
                subCategoryName: "InstaPay Fee",
                eventType: .expense
            )
        )

        XCTAssertNil(duplicate)
    }

    func testDuplicateDetectionDoesNotWarnForDifferentMerchantSameAmount() {
        let store = makeSuggestionStore()
        let date = fixedDate()
        store.financialEvents = [
            paidEvent(
                title: "Talabat",
                amount: 199,
                date: date,
                categoryName: "Dining & Delivery",
                subCategoryName: "Restaurants"
            )
        ]

        let duplicate = store.possibleDuplicateTransaction(
            for: TransactionDuplicateCheckRequest(
                title: "APPLE",
                amount: 199,
                date: date,
                accountName: "Main Card",
                paymentMethodName: "Credit Card",
                categoryName: "Digital & Subscriptions",
                subCategoryName: "Apps & Subscriptions",
                eventType: .expense
            )
        )

        XCTAssertNil(duplicate)
    }

    private func makeIsolatedUserDefaults(
        suiteName: String = "WalletStoreTestabilityTests-\(UUID().uuidString)"
    ) -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults suite.")
            return .standard
        }

        defaults.removePersistentDomain(forName: suiteName)
        suiteNames.append(suiteName)
        return defaults
    }

    private func makeSuggestionStore() -> WalletStore {
        let store = WalletStore(userDefaults: makeIsolatedUserDefaults())
        store.categories = [
            WalletBoard.Category(name: "Dining & Delivery", subcategories: ["Restaurants"]),
            WalletBoard.Category(name: "Digital & Subscriptions", subcategories: ["Apps & Subscriptions"]),
            WalletBoard.Category(name: "Electronics", subcategories: ["Devices"]),
            WalletBoard.Category(name: "Banking & Fees", subcategories: ["InstaPay Fee"])
        ]
        store.financialEvents = []
        store.creditCardPurchases = []
        return store
    }

    private func paidEvent(
        title: String,
        amount: Double = 100,
        date: Date = Date(),
        accountName: String = "Main Card",
        paymentMethodName: String = "Credit Card",
        note: String? = nil,
        categoryName: String,
        subCategoryName: String
    ) -> FinancialEvent {
        FinancialEvent(
            type: .expense,
            status: .paid,
            title: title,
            amount: amount,
            date: date,
            accountName: accountName,
            paymentMethodName: paymentMethodName,
            categoryName: categoryName,
            subCategoryName: subCategoryName,
            note: note
        )
    }

    private func fixedDate() -> Date {
        DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 6,
            day: 19,
            hour: 12
        ).date!
    }

    private func makeSuiteName() -> String {
        "WalletStoreTestabilityTests-\(UUID().uuidString)"
    }

    private func dateComponents(from date: Date?) -> DateComponents? {
        guard let date else {
            return nil
        }

        return Calendar.current.dateComponents([.year, .month, .day], from: date)
    }

    private func write<T: Codable>(_ value: T, key: String, to defaults: UserDefaults) throws {
        let data = try JSONEncoder().encode(value)
        defaults.set(data, forKey: key)
    }
}
