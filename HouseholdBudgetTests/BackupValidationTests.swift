import XCTest
@testable import WalletBoard

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

    @MainActor
    func testDemoFixtureDecodesAndPassesValidation() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/PocketWise-Demo-Household-TestData.json")

        let data = try Data(contentsOf: fixtureURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(WalletDataSnapshot.self, from: data)

        let store = makeStore()
        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertFalse(
            report.issues.contains { $0.severity == .warning },
            "Demo fixture produced validation warnings: \(report.issues.map { $0.title })"
        )
        XCTAssertEqual(snapshot.accounts.count, 5)
        XCTAssertEqual(snapshot.financialEvents.count, 27)
        XCTAssertLessThanOrEqual(snapshot.schemaVersion, WalletDataSnapshot.currentSchemaVersion)
    }

    func testValidationDetectsDuplicateMonthlyBudgetItemIDs() {
        let store = makeStore()
        let duplicateID = UUID()
        let firstItem = WalletMonthlyBudgetItem(
            id: duplicateID,
            categoryName: "Groceries",
            plannedAmount: 100,
            createdAt: startDate,
            updatedAt: startDate
        )
        let secondItem = WalletMonthlyBudgetItem(
            id: duplicateID,
            categoryName: "Transport",
            plannedAmount: 200,
            createdAt: startDate,
            updatedAt: startDate
        )
        let budget = WalletMonthlyBudget(
            year: 2026,
            month: 6,
            items: [firstItem, secondItem],
            createdAt: startDate,
            updatedAt: startDate
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            monthlyBudgets: [budget]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Duplicate monthly budget item ID", recordID: duplicateID))
        let issue = report.issue(titled: "Duplicate monthly budget item ID", recordID: duplicateID)
        XCTAssertTrue(issue?.detail.localizedCaseInsensitiveContains("duplicate") == true)
        XCTAssertTrue(issue?.detail.localizedCaseInsensitiveContains("monthly budget item") == true)
        XCTAssertTrue(issue?.detail.contains("2026-06") == true)
    }

    func testValidationDetectsDuplicateMonthlyBudgetItemIDsAcrossBudgets() {
        let store = makeStore()
        let duplicateID = UUID()
        let juneBudget = WalletMonthlyBudget(
            year: 2026,
            month: 6,
            items: [
                WalletMonthlyBudgetItem(
                    id: duplicateID,
                    categoryName: "Groceries",
                    plannedAmount: 100,
                    createdAt: startDate,
                    updatedAt: startDate
                )
            ],
            createdAt: startDate,
            updatedAt: startDate
        )
        let julyBudget = WalletMonthlyBudget(
            year: 2026,
            month: 7,
            items: [
                WalletMonthlyBudgetItem(
                    id: duplicateID,
                    categoryName: "Groceries",
                    plannedAmount: 125,
                    createdAt: startDate,
                    updatedAt: startDate
                )
            ],
            createdAt: startDate,
            updatedAt: startDate
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            monthlyBudgets: [juneBudget, julyBudget]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Duplicate monthly budget item ID", recordID: duplicateID))
        let issue = report.issue(titled: "Duplicate monthly budget item ID", recordID: duplicateID)
        XCTAssertTrue(issue?.detail.contains("2026-06") == true)
        XCTAssertTrue(issue?.detail.contains("2026-07") == true)
    }

    // MARK: - Error severity and blocking flag

    func testErrorSeverityCanBeRepresentedInReport() {
        var report = BackupValidationReport()
        report.issues = [
            BackupValidationIssue(
                severity: .error,
                title: "Test blocking error",
                detail: "A test error issue.",
                recordID: nil
            )
        ]

        XCTAssertEqual(report.errorCount, 1)
        XCTAssertTrue(report.hasErrors)
        XCTAssertTrue(report.hasIssues)
        XCTAssertEqual(report.warningCount, 0)
        XCTAssertEqual(report.infoCount, 0)
    }

    func testReportHasErrorsIsFalseWhenNoErrors() {
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

        XCTAssertFalse(report.hasErrors, "Duplicate financial event ID should be a warning, not a blocking error")
        XCTAssertTrue(report.warningCount > 0)
    }

    // MARK: - Schema version gate

    func testSchemaVersionGateFlagsNewerVersionAsError() {
        let store = makeStore()
        let futureVersion = WalletDataSnapshot.currentSchemaVersion + 1
        let snapshot = makeSnapshot(
            schemaVersion: futureVersion,
            accounts: store.accounts,
            categories: store.categories
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.hasErrors, "A snapshot from a newer schema version must produce a blocking error")
        XCTAssertTrue(
            report.containsIssue(titled: "Unsupported schema version"),
            "Expected 'Unsupported schema version' error but got: \(report.issues.map { $0.title })"
        )
        let issue = report.issues.first { $0.title == "Unsupported schema version" }
        XCTAssertEqual(issue?.severity, .error)
        XCTAssertTrue(issue?.detail.contains("\(futureVersion)") == true)
        XCTAssertTrue(issue?.detail.contains("\(WalletDataSnapshot.currentSchemaVersion)") == true)
    }

    func testCurrentSchemaVersionProducesNoSchemaError() {
        let store = makeStore()
        let snapshot = makeSnapshot(
            schemaVersion: WalletDataSnapshot.currentSchemaVersion,
            accounts: store.accounts,
            categories: store.categories
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertFalse(report.containsIssue(titled: "Unsupported schema version"))
        XCTAssertFalse(report.hasErrors)
    }

    func testPreviousSchemaVersionProducesNoSchemaError() {
        let store = makeStore()
        let previousVersion = max(1, WalletDataSnapshot.currentSchemaVersion - 1)
        let snapshot = makeSnapshot(
            schemaVersion: previousVersion,
            accounts: store.accounts,
            categories: store.categories
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertFalse(
            report.containsIssue(titled: "Unsupported schema version"),
            "Older supported schema versions must not produce a blocking error"
        )
        XCTAssertFalse(report.hasErrors)
    }

    func testDuplicateMonthlyBudgetItemIDsRemainWarningNotError() {
        let store = makeStore()
        let duplicateID = UUID()
        let budget = WalletMonthlyBudget(
            year: 2026,
            month: 6,
            items: [
                WalletMonthlyBudgetItem(
                    id: duplicateID,
                    categoryName: "Groceries",
                    plannedAmount: 100,
                    createdAt: startDate,
                    updatedAt: startDate
                ),
                WalletMonthlyBudgetItem(
                    id: duplicateID,
                    categoryName: "Transport",
                    plannedAmount: 200,
                    createdAt: startDate,
                    updatedAt: startDate
                )
            ],
            createdAt: startDate,
            updatedAt: startDate
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            monthlyBudgets: [budget]
        )

        let report = store.makeBackupValidationReport(for: snapshot)
        let issue = report.issue(titled: "Duplicate monthly budget item ID", recordID: duplicateID)

        XCTAssertNotNil(issue, "Duplicate budget item ID must still produce an issue")
        XCTAssertEqual(
            issue?.severity, .warning,
            "Duplicate monthly budget item IDs are a .warning, not a blocking .error — they do not prevent restore"
        )
        XCTAssertFalse(report.hasErrors)
    }

    func testValidationDoesNotFlagUniqueMonthlyBudgetItemIDs() {
        let store = makeStore()
        let budget = WalletMonthlyBudget(
            year: 2026,
            month: 6,
            items: [
                WalletMonthlyBudgetItem(
                    id: UUID(),
                    categoryName: "Groceries",
                    plannedAmount: 100,
                    createdAt: startDate,
                    updatedAt: startDate
                ),
                WalletMonthlyBudgetItem(
                    id: UUID(),
                    categoryName: "Transport",
                    plannedAmount: 200,
                    createdAt: startDate,
                    updatedAt: startDate
                )
            ],
            createdAt: startDate,
            updatedAt: startDate
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            monthlyBudgets: [budget]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertFalse(report.containsIssue(titled: "Duplicate monthly budget item ID"))
    }

    private func makeStore() -> WalletStore {
        let defaults = makeIsolatedUserDefaults()
        let store = WalletStore(userDefaults: defaults)
        store.accounts = [
            Account(name: accountName, balance: 10_000, type: .cash)
        ]
        store.categories = [
            WalletBoard.Category(name: "Groceries", subcategories: ["Groceries"])
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
        schemaVersion: Int = WalletDataSnapshot.currentSchemaVersion,
        accounts: [Account],
        categories: [WalletBoard.Category],
        installmentPlans: [InstallmentPlan] = [],
        financialEvents: [FinancialEvent] = [],
        monthlyBudgets: [WalletMonthlyBudget] = [],
        creditCardPurchases: [CreditCardPurchase] = [],
        creditCardPayments: [CreditCardPayment] = []
    ) -> WalletDataSnapshot {
        WalletDataSnapshot(
            schemaVersion: schemaVersion,
            exportedAt: startDate,
            accounts: accounts,
            categories: categories,
            walletEvents: [],
            installmentPlans: installmentPlans,
            financialEvents: financialEvents,
            personDebts: [],
            personDebtEntries: [],
            monthlyBudgets: monthlyBudgets,
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

    func containsIssue(titled title: String) -> Bool {
        issues.contains { issue in
            issue.title == title
        }
    }

    func issue(titled title: String, recordID: UUID) -> BackupValidationIssue? {
        issues.first { issue in
            issue.title == title && issue.recordID == recordID
        }
    }
}
