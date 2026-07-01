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
        // Paid non-transfer event referencing a non-existent account produces .warning,
        // not .error — validateBackupSnapshot does not check non-transfer account references.
        let paidWithMissingAccount = FinancialEvent(
            type: .expense,
            status: .paid,
            title: "Paid Warning-Only Event",
            amount: 100,
            date: startDate,
            accountName: "Non-Existent Account",
            paymentMethodName: "Cash",
            categoryName: "Groceries",
            subCategoryName: "Groceries"
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            financialEvents: [paidWithMissingAccount]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertFalse(report.hasErrors, "Paid event missing account should be .warning, not a blocking .error")
        XCTAssertTrue(report.warningCount > 0)
    }

    // MARK: - Severity alignment: conditions that block restore must report .error

    func testDuplicateFinancialEventIDsReportedAsError() {
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
        let issue = report.issues.first { $0.title == "Duplicate financial event ID" && $0.recordID == duplicateID }

        XCTAssertNotNil(issue, "Duplicate financial event ID must produce an issue")
        XCTAssertEqual(issue?.severity, .error, "Duplicate financial event IDs block restore — must be .error")
        XCTAssertTrue(report.hasErrors)
        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot),
                             "Store must throw when restoring a snapshot with duplicate financial event IDs")
    }

    func testMissingCreditCardPurchaseReferenceReportedAsError() {
        let store = makeStore()
        let missingCardID = UUID()
        let purchase = CreditCardPurchase(
            id: UUID(),
            cardID: missingCardID,
            title: "Orphaned Purchase",
            amount: 500,
            purchaseDate: startDate,
            categoryName: "Groceries",
            subCategoryName: "Groceries",
            note: nil,
            createdAt: startDate,
            updatedAt: startDate
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            creditCardPurchases: [purchase]
        )

        let report = store.makeBackupValidationReport(for: snapshot)
        let issue = report.issues.first { $0.title == "Credit card purchase missing card" && $0.recordID == purchase.id }

        XCTAssertNotNil(issue, "Credit card purchase with missing card must produce an issue")
        XCTAssertEqual(issue?.severity, .error, "Missing credit card on purchase blocks restore — must be .error")
        XCTAssertTrue(report.hasErrors)
        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot),
                             "Store must throw when restoring a snapshot with a purchase referencing a missing credit card")
    }

    func testMissingCreditCardPaymentReferenceReportedAsError() {
        let store = makeStore()
        let missingCardID = UUID()
        let payment = CreditCardPayment(
            id: UUID(),
            cardID: missingCardID,
            fromAccountName: accountName,
            amount: 300,
            paymentDate: startDate,
            note: nil,
            createdAt: startDate,
            updatedAt: startDate
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            creditCardPayments: [payment]
        )

        let report = store.makeBackupValidationReport(for: snapshot)
        let issue = report.issues.first { $0.title == "Credit card payment missing card" && $0.recordID == payment.id }

        XCTAssertNotNil(issue, "Credit card payment with missing card must produce an issue")
        XCTAssertEqual(issue?.severity, .error, "Missing credit card on payment blocks restore — must be .error")
        XCTAssertTrue(report.hasErrors)
        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot),
                             "Store must throw when restoring a snapshot with a payment referencing a missing credit card")
    }

    func testInvalidFinancialEventAmountReportedAsError() {
        let store = makeStore()
        let zeroAmountEvent = FinancialEvent(
            type: .expense,
            status: .unpaid,
            title: "Zero Amount Event",
            amount: 0,
            date: startDate,
            accountName: accountName,
            paymentMethodName: "Cash",
            categoryName: "Groceries",
            subCategoryName: "Groceries"
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            financialEvents: [zeroAmountEvent]
        )

        let report = store.makeBackupValidationReport(for: snapshot)
        let issue = report.issues.first { $0.title == "Invalid financial event amount" && $0.recordID == zeroAmountEvent.id }

        XCTAssertNotNil(issue, "Zero amount financial event must produce an issue")
        XCTAssertEqual(issue?.severity, .error, "Invalid financial event amount blocks restore — must be .error")
        XCTAssertTrue(report.hasErrors)
        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot),
                             "Store must throw when restoring a snapshot with a zero-amount event")
    }

    func testWarningOnlyConditionsDoNotSetHasErrors() {
        let store = makeStore()
        // "Paid event missing account" is the canonical .warning case:
        // validateBackupSnapshot does NOT throw for non-transfer events with missing accounts.
        let paidWithMissingAccount = FinancialEvent(
            type: .expense,
            status: .paid,
            title: "Warning Only Event",
            amount: 100,
            date: startDate,
            accountName: "Non-Existent Account",
            paymentMethodName: "Cash",
            categoryName: "Groceries",
            subCategoryName: "Groceries"
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            financialEvents: [paidWithMissingAccount]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertFalse(report.hasErrors, "Paid event missing account must remain .warning, not .error")
        XCTAssertTrue(report.warningCount > 0)
        XCTAssertNoThrow(try store.restoreFromBackupSnapshot(snapshot),
                         "Warning-only report must not block restore at store level")
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

    func testDuplicateMonthlyBudgetItemIDsAreReportedAsBlockingError() {
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

        XCTAssertNotNil(issue, "Duplicate budget item ID must produce an issue")
        XCTAssertEqual(
            issue?.severity, .error,
            "Duplicate monthly budget item IDs are now .error because validateBackupSnapshot throws for them"
        )
        XCTAssertTrue(report.hasErrors, "hasErrors must be true when duplicate budget item IDs are present")
    }

    // MARK: - Restore blocking gate

    func testRestoreIsBlockedAtStoreForFutureSchemaVersion() throws {
        let store = makeStore()
        let futureVersion = WalletDataSnapshot.currentSchemaVersion + 1
        let snapshot = makeSnapshot(
            schemaVersion: futureVersion,
            accounts: store.accounts,
            categories: store.categories
        )

        let report = store.makeBackupValidationReport(for: snapshot)
        XCTAssertTrue(report.hasErrors, "Future schema version must produce a blocking error")

        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot)) { error in
            guard let backupError = error as? WalletBackupError,
                  case .unsupportedSchemaVersion = backupError else {
                XCTFail("Expected WalletBackupError.unsupportedSchemaVersion, got \(error)")
                return
            }
        }
    }

    func testRestoreDoesNotMutateStoreWhenBlockedBySchemaVersion() throws {
        let store = makeStore()
        let originalAccounts = store.accounts
        let originalFinancialEvents = store.financialEvents
        let futureVersion = WalletDataSnapshot.currentSchemaVersion + 1
        let snapshot = makeSnapshot(
            schemaVersion: futureVersion,
            accounts: [Account(name: "Replacement Account", balance: 99_999, type: .cash)],
            categories: store.categories
        )

        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot))

        XCTAssertEqual(store.accounts.map(\.name), originalAccounts.map(\.name),
                       "Store accounts must be unchanged after a blocked restore")
        XCTAssertEqual(store.financialEvents.count, originalFinancialEvents.count,
                       "Store financial events must be unchanged after a blocked restore")
    }

    func testRestoreSucceedsForCurrentSchemaVersion() throws {
        let store = makeStore()
        let snapshot = makeSnapshot(
            schemaVersion: WalletDataSnapshot.currentSchemaVersion,
            accounts: [Account(name: "Restored Account", balance: 5_000, type: .cash)],
            categories: store.categories
        )

        let report = store.makeBackupValidationReport(for: snapshot)
        XCTAssertFalse(report.hasErrors, "Current schema version must not produce blocking errors")

        XCTAssertNoThrow(try store.restoreFromBackupSnapshot(snapshot))
        XCTAssertEqual(store.accounts.first?.name, "Restored Account",
                       "Store must reflect the restored snapshot after a successful restore")
    }

    func testWarningOnlyReportDoesNotBlockRestoreAtStoreLevel() throws {
        let store = makeStore()
        // A paid non-transfer event referencing a non-existent account name produces .warning
        // in makeBackupValidationReport but does NOT cause validateBackupSnapshot to throw
        // (validateBackupSnapshot only enforces account names on transfer events).
        let paidEventWithMissingAccount = FinancialEvent(
            type: .expense,
            status: .paid,
            title: "Paid With Missing Account",
            amount: 100,
            date: startDate,
            accountName: "Non-Existent Account",
            paymentMethodName: "Cash",
            categoryName: "Groceries",
            subCategoryName: "Groceries"
        )
        let snapshot = makeSnapshot(
            schemaVersion: WalletDataSnapshot.currentSchemaVersion,
            accounts: store.accounts,
            categories: store.categories,
            financialEvents: [paidEventWithMissingAccount]
        )

        let report = store.makeBackupValidationReport(for: snapshot)
        XCTAssertFalse(report.hasErrors, "Missing account on paid event must be a .warning, not a blocking .error")
        XCTAssertTrue(report.warningCount > 0, "Missing account on paid event must produce a warning")

        XCTAssertNoThrow(
            try store.restoreFromBackupSnapshot(snapshot),
            "Warning-only report must not block restore at the store level"
        )
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
        walletEvents: [WalletEvent] = [],
        merchantMemories: [MerchantMemory] = [],
        installmentPlans: [InstallmentPlan] = [],
        financialEvents: [FinancialEvent] = [],
        personDebts: [PersonDebt] = [],
        personDebtEntries: [PersonDebtEntry] = [],
        monthlyBudgets: [WalletMonthlyBudget] = [],
        historicalMonthlySummaries: [HistoricalMonthlySummaryEntry] = [],
        creditCards: [CreditCard] = [],
        creditCardPurchases: [CreditCardPurchase] = [],
        creditCardPayments: [CreditCardPayment] = [],
        monthlyLivingBurn: Double = 0,
        instaPayFeePercent: Double = 0,
        instaPayMinimumFee: Double = 0,
        instaPayMaximumFee: Double = 0
    ) -> WalletDataSnapshot {
        WalletDataSnapshot(
            schemaVersion: schemaVersion,
            exportedAt: startDate,
            accounts: accounts,
            categories: categories,
            walletEvents: walletEvents,
            merchantMemories: merchantMemories,
            installmentPlans: installmentPlans,
            financialEvents: financialEvents,
            personDebts: personDebts,
            personDebtEntries: personDebtEntries,
            monthlyBudgets: monthlyBudgets,
            historicalMonthlySummaries: historicalMonthlySummaries,
            creditCards: creditCards,
            creditCardPurchases: creditCardPurchases,
            creditCardPayments: creditCardPayments,
            monthlyLivingBurn: monthlyLivingBurn,
            instaPayFeePercent: instaPayFeePercent,
            instaPayMinimumFee: instaPayMinimumFee,
            instaPayMaximumFee: instaPayMaximumFee
        )
    }

    // MARK: - Account name validation

    func testEmptyAccountNameIsReportedAsBlockingError() {
        let store = makeStore()
        let badAccount = Account(name: "", balance: 0, type: .cash)
        let snapshot = makeSnapshot(
            accounts: store.accounts + [badAccount],
            categories: store.categories
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Account missing name", recordID: badAccount.id))
        XCTAssertTrue(report.hasErrors)
    }

    func testEmptyAccountNameBlocksRestoreAtStoreLevel() {
        let store = makeStore()
        let badAccount = Account(name: "", balance: 0, type: .cash)
        let snapshot = makeSnapshot(
            accounts: store.accounts + [badAccount],
            categories: store.categories
        )

        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot))
    }

    func testDuplicateAccountNameIsReportedAsBlockingError() {
        let store = makeStore()
        let dupName = "Duplicate Account"
        let first = Account(name: dupName, balance: 0, type: .cash)
        let second = Account(name: dupName, balance: 0, type: .cash)
        let snapshot = makeSnapshot(
            accounts: store.accounts + [first, second],
            categories: store.categories
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Duplicate account name"))
        XCTAssertTrue(report.hasErrors)
    }

    func testDuplicateAccountNameBlocksRestoreAtStoreLevel() {
        let store = makeStore()
        let dupName = "Duplicate Account"
        let first = Account(name: dupName, balance: 0, type: .cash)
        let second = Account(name: dupName, balance: 0, type: .cash)
        let snapshot = makeSnapshot(
            accounts: store.accounts + [first, second],
            categories: store.categories
        )

        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot))
    }

    // MARK: - Category name validation

    func testEmptyCategoryNameIsReportedAsBlockingError() {
        let store = makeStore()
        let badCat = WalletBoard.Category(name: "", subcategories: [])
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories + [badCat]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Category missing name", recordID: badCat.id))
        XCTAssertTrue(report.hasErrors)
    }

    func testEmptyCategoryNameBlocksRestoreAtStoreLevel() {
        let store = makeStore()
        let badCat = WalletBoard.Category(name: "", subcategories: [])
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories + [badCat]
        )

        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot))
    }

    func testDuplicateCategoryNameIsReportedAsBlockingError() {
        let store = makeStore()
        let dupName = "Duplicate Category"
        let first = WalletBoard.Category(name: dupName, subcategories: [])
        let second = WalletBoard.Category(name: dupName, subcategories: [])
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories + [first, second]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Duplicate category name"))
        XCTAssertTrue(report.hasErrors)
    }

    func testDuplicateCategoryNameBlocksRestoreAtStoreLevel() {
        let store = makeStore()
        let dupName = "Duplicate Category"
        let first = WalletBoard.Category(name: dupName, subcategories: [])
        let second = WalletBoard.Category(name: dupName, subcategories: [])
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories + [first, second]
        )

        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot))
    }

    // MARK: - Merchant memory validation

    func testInvalidMerchantMemoryIsReportedAsBlockingError() {
        let store = makeStore()
        var badMerchant = MerchantMemory(
            merchantName: "",
            defaultCategoryName: "Groceries",
            defaultSubCategoryName: "Groceries"
        )
        badMerchant.id = UUID()
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            merchantMemories: [badMerchant]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Invalid merchant memory", recordID: badMerchant.id))
        XCTAssertTrue(report.hasErrors)
    }

    func testInvalidMerchantMemoryBlocksRestoreAtStoreLevel() {
        let store = makeStore()
        var badMerchant = MerchantMemory(
            merchantName: "",
            defaultCategoryName: "Groceries",
            defaultSubCategoryName: "Groceries"
        )
        badMerchant.id = UUID()
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            merchantMemories: [badMerchant]
        )

        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot))
    }

    func testMerchantWithUnknownCategoryIsReportedAsBlockingError() {
        let store = makeStore()
        var badMerchant = MerchantMemory(
            merchantName: "Shop",
            defaultCategoryName: "Nonexistent Category",
            defaultSubCategoryName: "Sub"
        )
        badMerchant.id = UUID()
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            merchantMemories: [badMerchant]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Invalid merchant memory", recordID: badMerchant.id))
        XCTAssertTrue(report.hasErrors)
    }

    // MARK: - Historical summary validation

    func testInvalidHistoricalSummaryIsReportedAsBlockingError() {
        let store = makeStore()
        let badEntry = HistoricalMonthlySummaryEntry(
            year: 1800,
            month: 1,
            categoryName: "Groceries",
            subCategoryName: "Groceries",
            amount: 100
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            historicalMonthlySummaries: [badEntry]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Invalid historical summary entry", recordID: badEntry.id))
        XCTAssertTrue(report.hasErrors)
    }

    func testInvalidHistoricalSummaryBlocksRestoreAtStoreLevel() {
        let store = makeStore()
        let badEntry = HistoricalMonthlySummaryEntry(
            year: 1800,
            month: 1,
            categoryName: "Groceries",
            subCategoryName: "Groceries",
            amount: 100
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            historicalMonthlySummaries: [badEntry]
        )

        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot))
    }

    func testHistoricalSummaryWithUnknownCategoryIsReportedAsBlockingError() {
        let store = makeStore()
        let badEntry = HistoricalMonthlySummaryEntry(
            year: 2024,
            month: 6,
            categoryName: "Nonexistent Category",
            subCategoryName: "Sub",
            amount: 200
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            historicalMonthlySummaries: [badEntry]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Invalid historical summary entry", recordID: badEntry.id))
        XCTAssertTrue(report.hasErrors)
    }

    // MARK: - Credit card validation

    func testInvalidCreditCardIsReportedAsBlockingError() {
        let store = makeStore()
        let badCard = CreditCard(
            name: "",
            bankName: "Test Bank",
            creditLimit: 1000,
            statementClosingDay: 15,
            paymentDueDay: 25
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            creditCards: [badCard]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Invalid credit card", recordID: badCard.id))
        XCTAssertTrue(report.hasErrors)
    }

    func testInvalidCreditCardBlocksRestoreAtStoreLevel() {
        let store = makeStore()
        let badCard = CreditCard(
            name: "",
            bankName: "Test Bank",
            creditLimit: 1000,
            statementClosingDay: 15,
            paymentDueDay: 25
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            creditCards: [badCard]
        )

        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot))
    }

    func testCreditCardWithNegativeLimitIsReportedAsBlockingError() {
        let store = makeStore()
        let badCard = CreditCard(
            name: "My Card",
            bankName: "Test Bank",
            creditLimit: -500,
            statementClosingDay: 15,
            paymentDueDay: 25
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            creditCards: [badCard]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Invalid credit card", recordID: badCard.id))
        XCTAssertTrue(report.hasErrors)
    }

    // MARK: - Person debt validation

    func testInvalidPersonDebtEmptyNameIsReportedAsBlockingError() {
        let store = makeStore()
        let badDebt = PersonDebt(
            personName: "",
            kind: .owedToMe,
            originalAmount: 100
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            personDebts: [badDebt]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Invalid person debt", recordID: badDebt.id))
        XCTAssertTrue(report.hasErrors)
    }

    func testInvalidPersonDebtZeroAmountIsReportedAsBlockingError() {
        let store = makeStore()
        let badDebt = PersonDebt(
            personName: "Alice",
            kind: .owedToMe,
            originalAmount: 0
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            personDebts: [badDebt]
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Invalid person debt", recordID: badDebt.id))
        XCTAssertTrue(report.hasErrors)
    }

    func testInvalidPersonDebtBlocksRestoreAtStoreLevel() {
        let store = makeStore()
        let badDebt = PersonDebt(
            personName: "",
            kind: .iOwe,
            originalAmount: 50
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            personDebts: [badDebt]
        )

        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot))
    }

    // MARK: - Settings validation

    func testNegativeMonthlyLivingBurnIsReportedAsBlockingError() {
        let store = makeStore()
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            monthlyLivingBurn: -1
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Invalid backup settings"))
        XCTAssertTrue(report.hasErrors)
    }

    func testInstaPayMaxBelowMinIsReportedAsBlockingError() {
        let store = makeStore()
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            instaPayMinimumFee: 10,
            instaPayMaximumFee: 5
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.containsIssue(titled: "Invalid backup settings"))
        XCTAssertTrue(report.hasErrors)
    }

    func testInvalidSettingsBlocksRestoreAtStoreLevel() {
        let store = makeStore()
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            monthlyLivingBurn: -100
        )

        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot))
    }

    // MARK: - Relationship integrity: FinancialEvent category/subcategory

    func testFinancialEventWithValidCategoryProducesNoCategoryWarning() {
        let store = makeStore()
        let event = FinancialEvent(
            type: .expense, status: .unpaid, title: "Valid", amount: 100,
            date: startDate, accountName: accountName, paymentMethodName: "Cash",
            categoryName: "Groceries", subCategoryName: "Groceries"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, financialEvents: [event]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Financial event unknown category", recordID: event.id))
        XCTAssertFalse(report.containsIssue(titled: "Financial event unknown subcategory", recordID: event.id))
    }

    func testFinancialEventWithUnknownCategoryIsReportedAsWarning() {
        let store = makeStore()
        let event = FinancialEvent(
            type: .expense, status: .unpaid, title: "Bad Category", amount: 100,
            date: startDate, accountName: accountName, paymentMethodName: "Cash",
            categoryName: "Nonexistent Category", subCategoryName: "Sub"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, financialEvents: [event]
        ))
        let issue = report.issue(titled: "Financial event unknown category", recordID: event.id)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.severity, .warning)
    }

    func testFinancialEventWithUnknownSubcategoryUnderValidCategoryIsReportedAsWarning() {
        let store = makeStore()
        let event = FinancialEvent(
            type: .expense, status: .unpaid, title: "Bad Sub", amount: 100,
            date: startDate, accountName: accountName, paymentMethodName: "Cash",
            categoryName: "Groceries", subCategoryName: "Nonexistent Sub"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, financialEvents: [event]
        ))
        let issue = report.issue(titled: "Financial event unknown subcategory", recordID: event.id)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.severity, .warning)
    }

    func testFinancialEventWithUnknownParentCategoryDoesNotAlsoProduceSubcategoryWarning() {
        let store = makeStore()
        let event = FinancialEvent(
            type: .expense, status: .unpaid, title: "Missing Both", amount: 100,
            date: startDate, accountName: accountName, paymentMethodName: "Cash",
            categoryName: "Nonexistent Category", subCategoryName: "Nonexistent Sub"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, financialEvents: [event]
        ))
        XCTAssertTrue(report.containsIssue(titled: "Financial event unknown category", recordID: event.id))
        XCTAssertFalse(report.containsIssue(titled: "Financial event unknown subcategory", recordID: event.id))
    }

    // MARK: - Relationship integrity: WalletEvent category/subcategory

    func testWalletEventWithValidCategoryProducesNoWarning() {
        let store = makeStore()
        let event = WalletEvent(
            name: "Coffee", categoryName: "Groceries", subCategoryName: "Groceries"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, walletEvents: [event]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Quick event unknown category", recordID: event.id))
        XCTAssertFalse(report.containsIssue(titled: "Quick event unknown subcategory", recordID: event.id))
    }

    func testWalletEventWithUnknownCategoryIsReportedAsWarning() {
        let store = makeStore()
        let event = WalletEvent(
            name: "Coffee", categoryName: "Nonexistent Category", subCategoryName: "Sub"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, walletEvents: [event]
        ))
        let issue = report.issue(titled: "Quick event unknown category", recordID: event.id)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.severity, .warning)
    }

    func testWalletEventWithUnknownSubcategoryUnderValidCategoryIsReportedAsWarning() {
        let store = makeStore()
        let event = WalletEvent(
            name: "Coffee", categoryName: "Groceries", subCategoryName: "Nonexistent Sub"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, walletEvents: [event]
        ))
        let issue = report.issue(titled: "Quick event unknown subcategory", recordID: event.id)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.severity, .warning)
    }

    // MARK: - Relationship integrity: InstallmentPlan category/subcategory

    func testInstallmentPlanWithValidCategoryProducesNoWarning() {
        let store = makeStore()
        let plan = InstallmentPlan(
            purchaseName: "Laptop", totalAmount: 1200, installmentCount: 12,
            firstDueDate: startDate, categoryName: "Groceries", subCategoryName: "Groceries"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, installmentPlans: [plan]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Installment plan unknown category", recordID: plan.id))
        XCTAssertFalse(report.containsIssue(titled: "Installment plan unknown subcategory", recordID: plan.id))
    }

    func testInstallmentPlanWithUnknownCategoryIsReportedAsWarning() {
        let store = makeStore()
        let plan = InstallmentPlan(
            purchaseName: "Laptop", totalAmount: 1200, installmentCount: 12,
            firstDueDate: startDate, categoryName: "Nonexistent Category", subCategoryName: "Sub"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, installmentPlans: [plan]
        ))
        let issue = report.issue(titled: "Installment plan unknown category", recordID: plan.id)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.severity, .warning)
    }

    func testInstallmentPlanWithUnknownSubcategoryUnderValidCategoryIsReportedAsWarning() {
        let store = makeStore()
        let plan = InstallmentPlan(
            purchaseName: "Laptop", totalAmount: 1200, installmentCount: 12,
            firstDueDate: startDate, categoryName: "Groceries", subCategoryName: "Nonexistent Sub"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, installmentPlans: [plan]
        ))
        let issue = report.issue(titled: "Installment plan unknown subcategory", recordID: plan.id)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.severity, .warning)
    }

    // MARK: - Relationship integrity: MonthlyBudgetItem category

    func testMonthlyBudgetItemWithValidCategoryProducesNoWarning() {
        let store = makeStore()
        let item = WalletMonthlyBudgetItem(categoryName: "Groceries", plannedAmount: 500)
        let budget = WalletMonthlyBudget(year: 2026, month: 6, items: [item])
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, monthlyBudgets: [budget]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Budget item unknown category", recordID: item.id))
    }

    func testMonthlyBudgetItemWithUnknownCategoryIsReportedAsWarning() {
        let store = makeStore()
        let item = WalletMonthlyBudgetItem(categoryName: "Nonexistent Category", plannedAmount: 500)
        let budget = WalletMonthlyBudget(year: 2026, month: 6, items: [item])
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, monthlyBudgets: [budget]
        ))
        let issue = report.issue(titled: "Budget item unknown category", recordID: item.id)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.severity, .warning)
    }

    func testMonthlyBudgetItemWithEmptyCategoryRemainsBlockingError() {
        let store = makeStore()
        let item = WalletMonthlyBudgetItem(categoryName: "", plannedAmount: 500)
        let budget = WalletMonthlyBudget(year: 2026, month: 6, items: [item])
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, monthlyBudgets: [budget]
        ))
        let issue = report.issue(titled: "Invalid monthly budget item", recordID: item.id)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.severity, .error)
        XCTAssertTrue(report.hasErrors)
    }

    // MARK: - Relationship integrity: FinancialEvent account reference (unpaid non-transfer)

    func testUnpaidFinancialEventWithValidAccountProducesNoAccountWarning() {
        let store = makeStore()
        let event = FinancialEvent(
            type: .expense, status: .unpaid, title: "Valid Unpaid", amount: 100,
            date: startDate, accountName: accountName, paymentMethodName: "Cash",
            categoryName: "Groceries", subCategoryName: "Groceries"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, financialEvents: [event]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Event references unknown account", recordID: event.id))
    }

    func testUnpaidFinancialEventWithMissingNonEmptyAccountIsReportedAsWarning() {
        let store = makeStore()
        let event = FinancialEvent(
            type: .expense, status: .unpaid, title: "Missing Account", amount: 100,
            date: startDate, accountName: "Nonexistent Account", paymentMethodName: "Cash",
            categoryName: "Groceries", subCategoryName: "Groceries"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, financialEvents: [event]
        ))
        let issue = report.issue(titled: "Event references unknown account", recordID: event.id)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.severity, .warning)
    }

    func testUnpaidFinancialEventWithNilAccountProducesNoNewAccountWarning() {
        let store = makeStore()
        let event = FinancialEvent(
            type: .expense, status: .unpaid, title: "Nil Account", amount: 100,
            date: startDate, accountName: nil, paymentMethodName: "Cash",
            categoryName: "Groceries", subCategoryName: "Groceries"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, financialEvents: [event]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Event references unknown account", recordID: event.id))
    }

    func testTransferEventIsNotCoveredByUnpaidAccountCheck() {
        let store = makeStore()
        let transfer = FinancialEvent(
            type: .transfer, status: .unpaid, title: "Transfer", amount: 200,
            date: startDate, accountName: accountName, destinationAccountName: accountName,
            paymentMethodName: nil, categoryName: nil, subCategoryName: nil
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, financialEvents: [transfer]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Event references unknown account", recordID: transfer.id))
    }

    // MARK: - Relationship integrity: WalletEvent default account reference

    func testWalletEventWithValidDefaultAccountProducesNoAccountWarning() {
        let store = makeStore()
        let event = WalletEvent(
            name: "Coffee", categoryName: "Groceries", subCategoryName: "Groceries",
            defaultAccountName: accountName
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, walletEvents: [event]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Quick event unknown default account", recordID: event.id))
    }

    func testWalletEventWithMissingDefaultAccountIsReportedAsWarning() {
        let store = makeStore()
        let event = WalletEvent(
            name: "Coffee", categoryName: "Groceries", subCategoryName: "Groceries",
            defaultAccountName: "Nonexistent Account"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, walletEvents: [event]
        ))
        let issue = report.issue(titled: "Quick event unknown default account", recordID: event.id)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.severity, .warning)
    }

    func testWalletEventWithNilDefaultAccountProducesNoAccountWarning() {
        let store = makeStore()
        let event = WalletEvent(
            name: "Coffee", categoryName: "Groceries", subCategoryName: "Groceries",
            defaultAccountName: nil
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, walletEvents: [event]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Quick event unknown default account", recordID: event.id))
    }

    // MARK: - Relationship integrity: InstallmentPlan account reference (already covered — regression)

    func testInstallmentPlanWithValidAccountProducesNoAccountWarning() {
        let store = makeStore()
        let plan = InstallmentPlan(
            purchaseName: "Phone", totalAmount: 600, installmentCount: 6,
            firstDueDate: startDate, accountName: accountName,
            categoryName: "Groceries", subCategoryName: "Groceries"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, installmentPlans: [plan]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Installment plan missing account", recordID: plan.id))
    }

    func testInstallmentPlanWithMissingAccountIsReportedAsWarning() {
        let store = makeStore()
        let plan = InstallmentPlan(
            purchaseName: "Phone", totalAmount: 600, installmentCount: 6,
            firstDueDate: startDate, accountName: "Nonexistent Account",
            categoryName: "Groceries", subCategoryName: "Groceries"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, installmentPlans: [plan]
        ))
        let issue = report.issue(titled: "Installment plan missing account", recordID: plan.id)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.severity, .warning)
    }

    func testInstallmentPlanWithNilAccountProducesNoAccountWarning() {
        let store = makeStore()
        let plan = InstallmentPlan(
            purchaseName: "Phone", totalAmount: 600, installmentCount: 6,
            firstDueDate: startDate, accountName: nil,
            categoryName: "Groceries", subCategoryName: "Groceries"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, installmentPlans: [plan]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Installment plan missing account", recordID: plan.id))
    }

    // MARK: - Relationship integrity: CreditCardPurchase.cardID (existing .error — regression)

    func testCreditCardPurchaseWithValidCardProducesNoPurchaseCardWarning() {
        let store = makeStore()
        let card = CreditCard(
            name: "Test Card", bankName: "Test Bank",
            creditLimit: 5000, statementClosingDay: 15, paymentDueDay: 25
        )
        let purchase = CreditCardPurchase(
            id: UUID(), cardID: card.id, title: "Valid Purchase", amount: 200,
            purchaseDate: startDate, categoryName: "Groceries", subCategoryName: "Groceries",
            note: nil, createdAt: startDate, updatedAt: startDate
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories,
            creditCards: [card], creditCardPurchases: [purchase]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Credit card purchase missing card", recordID: purchase.id))
    }

    func testCreditCardPurchaseMissingCardIsBlockingError() {
        let store = makeStore()
        let purchase = CreditCardPurchase(
            id: UUID(), cardID: UUID(), title: "Orphaned Purchase", amount: 200,
            purchaseDate: startDate, categoryName: "Groceries", subCategoryName: "Groceries",
            note: nil, createdAt: startDate, updatedAt: startDate
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories,
            creditCardPurchases: [purchase]
        ))
        let issue = report.issue(titled: "Credit card purchase missing card", recordID: purchase.id)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.severity, .error)
        XCTAssertTrue(report.hasErrors)
    }

    // MARK: - Relationship integrity: CreditCardPayment.cardID (existing .error — regression)

    func testCreditCardPaymentWithValidCardProducesNoPaymentCardWarning() {
        let store = makeStore()
        let card = CreditCard(
            name: "Test Card", bankName: "Test Bank",
            creditLimit: 5000, statementClosingDay: 15, paymentDueDay: 25
        )
        let payment = CreditCardPayment(
            id: UUID(), cardID: card.id, fromAccountName: accountName, amount: 500,
            paymentDate: startDate, note: nil, createdAt: startDate, updatedAt: startDate
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories,
            creditCards: [card], creditCardPayments: [payment]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Credit card payment missing card", recordID: payment.id))
    }

    func testCreditCardPaymentMissingCardIsBlockingError() {
        let store = makeStore()
        let payment = CreditCardPayment(
            id: UUID(), cardID: UUID(), fromAccountName: accountName, amount: 500,
            paymentDate: startDate, note: nil, createdAt: startDate, updatedAt: startDate
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories,
            creditCardPayments: [payment]
        ))
        let issue = report.issue(titled: "Credit card payment missing card", recordID: payment.id)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.severity, .error)
        XCTAssertTrue(report.hasErrors)
    }

    // MARK: - Relationship integrity: InstallmentPlan.linkedCreditCardID (existing .warning — regression)

    func testInstallmentPlanWithValidLinkedCardProducesNoLinkedCardWarning() {
        let store = makeStore()
        let card = CreditCard(
            name: "Test Card", bankName: "Test Bank",
            creditLimit: 5000, statementClosingDay: 15, paymentDueDay: 25
        )
        let plan = InstallmentPlan(
            purchaseName: "Laptop", totalAmount: 1200, installmentCount: 12,
            firstDueDate: startDate, categoryName: "Groceries", subCategoryName: "Groceries",
            linkedCreditCardID: card.id
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories,
            installmentPlans: [plan], creditCards: [card]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Installment plan missing linked card", recordID: plan.id))
    }

    func testInstallmentPlanWithMissingLinkedCardIsReportedAsWarning() {
        let store = makeStore()
        let plan = InstallmentPlan(
            purchaseName: "Laptop", totalAmount: 1200, installmentCount: 12,
            firstDueDate: startDate, categoryName: "Groceries", subCategoryName: "Groceries",
            linkedCreditCardID: UUID()
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories,
            installmentPlans: [plan]
        ))
        let issue = report.issue(titled: "Installment plan missing linked card", recordID: plan.id)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.severity, .warning)
    }

    func testInstallmentPlanWithNilLinkedCardProducesNoLinkedCardWarning() {
        let store = makeStore()
        let plan = InstallmentPlan(
            purchaseName: "Laptop", totalAmount: 1200, installmentCount: 12,
            firstDueDate: startDate, categoryName: "Groceries", subCategoryName: "Groceries",
            linkedCreditCardID: nil
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories,
            installmentPlans: [plan]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Installment plan missing linked card", recordID: plan.id))
    }

    // MARK: - Relationship integrity: credit card reference cross-cutting

    func testCreditCardWarningOnlyReportDoesNotSetHasErrors() {
        let store = makeStore()
        let plan = InstallmentPlan(
            purchaseName: "Phone", totalAmount: 600, installmentCount: 6,
            firstDueDate: startDate, categoryName: "Groceries", subCategoryName: "Groceries",
            linkedCreditCardID: UUID()
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories,
            installmentPlans: [plan]
        ))
        XCTAssertTrue(report.containsIssue(titled: "Installment plan missing linked card", recordID: plan.id))
        XCTAssertFalse(report.hasErrors)
    }

    func testCreditCardWarningOnlyReportDoesNotBlockRestore() {
        let store = makeStore()
        let plan = InstallmentPlan(
            purchaseName: "Phone", totalAmount: 600, installmentCount: 6,
            firstDueDate: startDate, categoryName: "Groceries", subCategoryName: "Groceries",
            linkedCreditCardID: UUID()
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts, categories: store.categories,
            installmentPlans: [plan]
        )
        XCTAssertNoThrow(try store.restoreFromBackupSnapshot(snapshot))
    }

    // MARK: - Relationship integrity: account reference cross-cutting

    func testAccountReferenceWarningDoesNotSetHasErrors() {
        let store = makeStore()
        let event = FinancialEvent(
            type: .expense, status: .unpaid, title: "Missing Acct", amount: 100,
            date: startDate, accountName: "Nonexistent Account", paymentMethodName: "Cash",
            categoryName: "Groceries", subCategoryName: "Groceries"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, financialEvents: [event]
        ))
        XCTAssertTrue(report.hasIssues)
        XCTAssertFalse(report.hasErrors)
    }

    func testAccountReferenceWarningDoesNotBlockRestore() {
        let store = makeStore()
        let event = FinancialEvent(
            type: .expense, status: .unpaid, title: "Missing Acct", amount: 100,
            date: startDate, accountName: "Nonexistent Account", paymentMethodName: "Cash",
            categoryName: "Groceries", subCategoryName: "Groceries"
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts, categories: store.categories, financialEvents: [event]
        )
        XCTAssertNoThrow(try store.restoreFromBackupSnapshot(snapshot))
    }

    // MARK: - Relationship integrity: cross-cutting

    func testWarningOnlyRelationshipIssuesDoNotSetHasErrors() {
        let store = makeStore()
        let event = FinancialEvent(
            type: .expense, status: .unpaid, title: "Bad Cat", amount: 100,
            date: startDate, accountName: accountName, paymentMethodName: "Cash",
            categoryName: "Nonexistent Category", subCategoryName: "Sub"
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts, categories: store.categories, financialEvents: [event]
        ))
        XCTAssertTrue(report.hasIssues)
        XCTAssertFalse(report.hasErrors)
    }

    func testWarningOnlyRelationshipIssuesDoNotBlockRestore() {
        let store = makeStore()
        let event = FinancialEvent(
            type: .expense, status: .unpaid, title: "Bad Cat", amount: 100,
            date: startDate, accountName: accountName, paymentMethodName: "Cash",
            categoryName: "Nonexistent Category", subCategoryName: "Sub"
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts, categories: store.categories, financialEvents: [event]
        )
        XCTAssertNoThrow(try store.restoreFromBackupSnapshot(snapshot))
    }

    // MARK: - Relationship integrity: PersonDebtEntry references

    func testPersonDebtEntryWithValidParentDebtProducesNoParentWarning() {
        let store = makeStore()
        let debt = PersonDebt(personName: "Alice", kind: .owedToMe, originalAmount: 200)
        let entry = PersonDebtEntry(
            debtID: debt.id,
            entryType: .initialLending,
            amount: 200,
            accountName: accountName,
            date: startDate
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            personDebts: [debt],
            personDebtEntries: [entry]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Debt entry missing parent debt", recordID: entry.id))
    }

    func testPersonDebtEntryMissingParentDebtIsBlockingError() {
        let store = makeStore()
        let entry = PersonDebtEntry(
            debtID: UUID(),
            entryType: .initialLending,
            amount: 100,
            accountName: accountName,
            date: startDate
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            personDebtEntries: [entry]
        ))
        XCTAssertTrue(report.containsIssue(titled: "Debt entry missing parent debt", recordID: entry.id))
        XCTAssertTrue(report.hasErrors)
    }

    func testPersonDebtEntryMissingParentDebtBlocksRestore() {
        let store = makeStore()
        let entry = PersonDebtEntry(
            debtID: UUID(),
            entryType: .initialBorrowing,
            amount: 50,
            accountName: accountName,
            date: startDate
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            personDebtEntries: [entry]
        )
        XCTAssertThrowsError(try store.restoreFromBackupSnapshot(snapshot))
    }

    func testPersonDebtEntryWithValidAccountProducesNoAccountWarning() {
        let store = makeStore()
        let debt = PersonDebt(personName: "Bob", kind: .iOwe, originalAmount: 100)
        let entry = PersonDebtEntry(
            debtID: debt.id,
            entryType: .initialBorrowing,
            amount: 100,
            accountName: accountName,
            date: startDate
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            personDebts: [debt],
            personDebtEntries: [entry]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Debt entry missing account", recordID: entry.id))
    }

    func testPersonDebtEntryWithEmptyAccountIsBlockingError() {
        let store = makeStore()
        let debt = PersonDebt(personName: "Carol", kind: .owedToMe, originalAmount: 75)
        let entry = PersonDebtEntry(
            debtID: debt.id,
            entryType: .initialLending,
            amount: 75,
            accountName: "",
            date: startDate
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            personDebts: [debt],
            personDebtEntries: [entry]
        ))
        XCTAssertTrue(report.containsIssue(titled: "Debt entry missing account", recordID: entry.id))
        XCTAssertTrue(report.hasErrors)
    }

    func testPersonDebtEntryWithMissingNonEmptyAccountIsReportedAsWarning() {
        let store = makeStore()
        let debt = PersonDebt(personName: "Dave", kind: .iOwe, originalAmount: 300)
        let entry = PersonDebtEntry(
            debtID: debt.id,
            entryType: .initialBorrowing,
            amount: 300,
            accountName: "Deleted Account",
            date: startDate
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            personDebts: [debt],
            personDebtEntries: [entry]
        ))
        let issue = report.issue(titled: "Debt entry missing account", recordID: entry.id)
        XCTAssertNotNil(issue)
        XCTAssertEqual(issue?.severity, .warning)
        XCTAssertFalse(report.hasErrors)
    }

    func testPersonDebtEntryMissingAccountWarningDoesNotBlockRestore() {
        let store = makeStore()
        let debt = PersonDebt(personName: "Eve", kind: .owedToMe, originalAmount: 150)
        let entry = PersonDebtEntry(
            debtID: debt.id,
            entryType: .initialLending,
            amount: 150,
            accountName: "Ghost Account",
            date: startDate
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            personDebts: [debt],
            personDebtEntries: [entry]
        )
        XCTAssertNoThrow(try store.restoreFromBackupSnapshot(snapshot))
    }

    func testPersonDebtWarningOnlyReportDoesNotSetHasErrors() {
        let store = makeStore()
        let debt = PersonDebt(personName: "Frank", kind: .owedToMe, originalAmount: 500)
        let entry = PersonDebtEntry(
            debtID: debt.id,
            entryType: .initialLending,
            amount: 500,
            accountName: "Missing Account",
            date: startDate
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            personDebts: [debt],
            personDebtEntries: [entry]
        ))
        XCTAssertTrue(report.hasIssues)
        XCTAssertFalse(report.hasErrors)
    }

    func testValidPersonDebtAndEntryProduceNoRelationshipIssues() {
        let store = makeStore()
        let debt = PersonDebt(personName: "Grace", kind: .iOwe, originalAmount: 250)
        let entry = PersonDebtEntry(
            debtID: debt.id,
            entryType: .initialBorrowing,
            amount: 250,
            accountName: accountName,
            date: startDate
        )
        let report = store.makeBackupValidationReport(for: makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            personDebts: [debt],
            personDebtEntries: [entry]
        ))
        XCTAssertFalse(report.containsIssue(titled: "Debt entry missing parent debt", recordID: entry.id))
        XCTAssertFalse(report.containsIssue(titled: "Debt entry missing account", recordID: entry.id))
        XCTAssertFalse(report.containsIssue(titled: "Invalid person debt", recordID: debt.id))
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
