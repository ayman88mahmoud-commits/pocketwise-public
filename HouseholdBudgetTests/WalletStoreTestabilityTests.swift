import XCTest
@testable import HouseholdBudget

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
            HouseholdBudget.Category(name: "Dining & Delivery", subcategories: ["Restaurants"]),
            HouseholdBudget.Category(name: "Digital & Subscriptions", subcategories: ["Apps & Subscriptions"]),
            HouseholdBudget.Category(name: "Electronics", subcategories: ["Devices"]),
            HouseholdBudget.Category(name: "Banking & Fees", subcategories: ["InstaPay Fee"])
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
