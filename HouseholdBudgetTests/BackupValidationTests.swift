import XCTest
@testable import PocketWise

final class BackupValidationTests: XCTestCase {

    private let accountName = "Validation Cash"
    private let startDate = DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: TimeZone(secondsFromGMT: 0),
        year: 2026,
        month: 6,
        day: 1
    ).date!

    private var suiteNames: [String] = []

    override func tearDown() {
        for suiteName in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        suiteNames.removeAll()
        super.tearDown()
    }

    func testValidationDetectsPaidFinancialEventWithMissingAccount() {
        let store = makeStore()
        let invalidPaidExpense = FinancialEvent(
            type: .expense,
            status: .paid,
            title: "Paid Expense Missing Account",
            amount: 500,
            date: startDate,
            accountName: "Missing Account",
            paymentMethodName: "Cash",
            categoryName: "Groceries",
            subCategoryName: "Groceries"
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            financialEvents: [invalidPaidExpense]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.hasIssues)
        XCTAssertTrue(report.containsIssue(titled: "Paid event missing account", recordID: invalidPaidExpense.id))
    }

    func testValidationDetectsDuplicateFinancialEventIDs() {
        let store = makeStore()
        let duplicateID = UUID()
        var firstEvent = makeUnpaidExpense(title: "First Event")
        var secondEvent = makeUnpaidExpense(title: "Second Event")
        firstEvent.id = duplicateID
        secondEvent.id = duplicateID
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            financialEvents: [firstEvent, secondEvent]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Duplicate financial event ID", recordID: duplicateID))
    }

    func testValidationDetectsMissingCreditCardReference() {
        let store = makeStore()
        let missingCardID = UUID()
        let purchase = CreditCardPurchase(
            id: UUID(),
            cardID: missingCardID,
            title: "Missing Card Purchase",
            amount: 1_000,
            purchaseDate: startDate,
            categoryName: "Groceries",
            subCategoryName: "Groceries",
            note: nil,
            createdAt: startDate,
            updatedAt: startDate
        )
        let payment = CreditCardPayment(
            id: UUID(),
            cardID: missingCardID,
            fromAccountName: accountName,
            amount: 500,
            paymentDate: startDate,
            note: nil,
            createdAt: startDate,
            updatedAt: startDate
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            creditCardPurchases: [purchase],
            creditCardPayments: [payment]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Credit card purchase missing card", recordID: purchase.id))
        XCTAssertTrue(report.containsIssue(titled: "Credit card payment missing card", recordID: payment.id))
    }

    func testValidationDetectsInstallmentPaidCountExceedingTotal() {
        let store = makeStore()
        let plan = InstallmentPlan(
            purchaseName: "Validation Installment",
            totalAmount: 1_000,
            installmentCount: 1,
            firstDueDate: startDate,
            accountName: accountName,
            categoryName: "Groceries",
            subCategoryName: "Groceries"
        )
        let firstPaid = makeInstallmentEvent(plan: plan, date: startDate)
        let secondPaid = makeInstallmentEvent(plan: plan, date: startDate)
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            installmentPlans: [plan],
            financialEvents: [firstPaid, secondPaid]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Installment paid count exceeds total", recordID: plan.id))
    }

    func testValidationIsReadOnly() {
        let store = makeStore()
        let originalAccountCount = store.accounts.count
        let originalFinancialEventCount = store.financialEvents.count
        let originalCreditCardCount = store.creditCards.count
        let originalAccountBalance = store.accounts.first?.balance
        let invalidPaidExpense = FinancialEvent(
            type: .expense,
            status: .paid,
            title: "Read Only Missing Account",
            amount: 500,
            date: startDate,
            accountName: "Missing Account",
            paymentMethodName: "Cash",
            categoryName: "Groceries",
            subCategoryName: "Groceries"
        )
        let snapshot = makeSnapshot(
            accounts: [Account(name: "Snapshot Account", balance: 1, type: .cash)],
            categories: store.categories,
            financialEvents: [invalidPaidExpense]
        )

        _ = store.makeBackupValidationReport(for: snapshot)

        XCTAssertEqual(store.accounts.count, originalAccountCount)
        XCTAssertEqual(store.financialEvents.count, originalFinancialEventCount)
        XCTAssertEqual(store.creditCards.count, originalCreditCardCount)
        XCTAssertEqual(store.accounts.first?.balance, originalAccountBalance)
    }

    private func makeStore() -> WalletStore {
        let defaults = makeIsolatedUserDefaults()
        let store = WalletStore(userDefaults: defaults)
        store.accounts = [
            Account(name: accountName, balance: 10_000, type: .cash)
        ]
        store.categories = [
            PocketWise.Category(name: "Groceries", subcategories: ["Groceries"])
        ]
        store.walletEvents = []
        store.installmentPlans = []
        store.financialEvents = []
        store.personDebts = []
        store.personDebtEntries = []
        store.monthlyBudgets = []
        store.creditCards = []
        store.creditCardPurchases = []
        store.creditCardPayments = []
        return store
    }

    private func makeUnpaidExpense(title: String) -> FinancialEvent {
        FinancialEvent(
            type: .expense,
            status: .unpaid,
            title: title,
            amount: 500,
            date: startDate,
            accountName: accountName,
            paymentMethodName: "Cash",
            categoryName: "Groceries",
            subCategoryName: "Groceries"
        )
    }

    private func makeInstallmentEvent(plan: InstallmentPlan, date: Date) -> FinancialEvent {
        FinancialEvent(
            type: .installment,
            status: .paid,
            title: "Valu - \(plan.purchaseName)",
            amount: plan.monthlyAmount,
            date: date,
            accountName: plan.accountName,
            paymentMethodName: plan.paymentMethodName,
            categoryName: plan.categoryName,
            subCategoryName: plan.subCategoryName,
            sourceInstallmentPlanID: plan.id
        )
    }

    private func makeSnapshot(
        accounts: [Account],
        categories: [PocketWise.Category],
        installmentPlans: [InstallmentPlan] = [],
        financialEvents: [FinancialEvent] = [],
        creditCardPurchases: [CreditCardPurchase] = [],
        creditCardPayments: [CreditCardPayment] = []
    ) -> WalletDataSnapshot {
        WalletDataSnapshot(
            exportedAt: startDate,
            accounts: accounts,
            categories: categories,
            walletEvents: [],
            installmentPlans: installmentPlans,
            financialEvents: financialEvents,
            personDebts: [],
            personDebtEntries: [],
            monthlyBudgets: [],
            creditCards: [],
            creditCardPurchases: creditCardPurchases,
            creditCardPayments: creditCardPayments,
            monthlyLivingBurn: 0,
            instaPayFeePercent: 0,
            instaPayMinimumFee: 0,
            instaPayMaximumFee: 0
        )
    }

    private func makeIsolatedUserDefaults(
        suiteName: String = "BackupValidationTests-\(UUID().uuidString)"
    ) -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults suite.")
            return .standard
        }

        defaults.removePersistentDomain(forName: suiteName)
        suiteNames.append(suiteName)
        return defaults
    }
}

private extension BackupValidationReport {
    func containsIssue(titled title: String, recordID: UUID) -> Bool {
        issues.contains { issue in
            issue.title == title && issue.recordID == recordID
        }
    }
}
