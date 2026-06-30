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
