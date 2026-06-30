import XCTest
@testable import WalletBoard

final class WalletStoreFinancialInvariantTests: XCTestCase {

    private let accountName = "Invariant Cash"
    private let startDate = DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: TimeZone(secondsFromGMT: 0),
        year: 2026,
        month: 6,
        day: 1
    ).date!
    private let futureDate = DateComponents(
        calendar: Calendar(identifier: .gregorian),
        timeZone: TimeZone(secondsFromGMT: 0),
        year: 2026,
        month: 6,
        day: 20
    ).date!

    private var suiteNames: [String] = []

    override func tearDown() {
        for suiteName in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        suiteNames.removeAll()
        super.tearDown()
    }

    func testFutureIncomeDoesNotIncreaseCurrentCash() {
        let store = makeStore(startingCash: 10_000)
        let futureIncome = FinancialEvent(
            type: .income,
            status: .expected,
            title: "Future Salary",
            amount: 20_000,
            date: futureDate,
            accountName: accountName,
            incomeType: .salary
        )

        store.addFinancialEvent(futureIncome)

        XCTAssertEqual(store.availableCash, 10_000, accuracy: 0.001)
        XCTAssertEqual(store.accounts.first?.balance ?? 0, 10_000, accuracy: 0.001)
        XCTAssertEqual(store.financialEvents.first(where: { $0.id == futureIncome.id })?.status, .expected)
    }

    func testFutureUnpaidObligationDoesNotDecreaseCurrentCash() {
        let store = makeStore(startingCash: 10_000)
        let futureRent = FinancialEvent(
            type: .obligation,
            status: .unpaid,
            title: "Future Rent",
            amount: 5_000,
            date: futureDate,
            accountName: accountName,
            categoryName: "Rent",
            subCategoryName: "Rent"
        )

        store.addFinancialEvent(futureRent)

        XCTAssertEqual(store.availableCash, 10_000, accuracy: 0.001)
        XCTAssertEqual(store.accounts.first?.balance ?? 0, 10_000, accuracy: 0.001)
        XCTAssertEqual(store.financialEvents.first(where: { $0.id == futureRent.id })?.status, .unpaid)
    }

    func testPaidCashExpenseDecreasesCashOnce() {
        let suiteName = makeSuiteName()
        let defaults = makeIsolatedUserDefaults(suiteName: suiteName)
        let store = makeStore(startingCash: 10_000, userDefaults: defaults)

        store.addManualExpense(
            title: "Groceries",
            amount: 500,
            date: startDate,
            accountName: accountName,
            paymentMethodName: "Cash",
            categoryName: "Groceries",
            subCategoryName: "Groceries"
        )

        XCTAssertEqual(store.availableCash, 9_500, accuracy: 0.001)
        XCTAssertEqual(store.availableCash, 9_500, accuracy: 0.001)

        let reloadedStore = WalletStore(userDefaults: defaults)
        XCTAssertEqual(reloadedStore.availableCash, 9_500, accuracy: 0.001)
    }

    func testPaidIncomeIncreasesCashOnce() {
        let suiteName = makeSuiteName()
        let defaults = makeIsolatedUserDefaults(suiteName: suiteName)
        let store = makeStore(startingCash: 10_000, userDefaults: defaults)

        store.addIncome(
            title: "Cash Bonus",
            amount: 2_000,
            date: startDate,
            accountName: accountName,
            incomeType: .oneTimeCashInflow
        )

        XCTAssertEqual(store.availableCash, 12_000, accuracy: 0.001)
        XCTAssertEqual(store.availableCash, 12_000, accuracy: 0.001)

        let reloadedStore = WalletStore(userDefaults: defaults)
        XCTAssertEqual(reloadedStore.availableCash, 12_000, accuracy: 0.001)
    }

    func testTransferMovesMoneyBetweenAccountsWithoutChangingTotalCash() {
        let store = makeStore(
            accounts: [
                Account(name: "Source Cash", balance: 10_000, type: .cash),
                Account(name: "Destination Bank", balance: 2_000, type: .bank)
            ]
        )

        store.addTransfer(
            amount: 1_500,
            date: startDate,
            fromAccountName: "Source Cash",
            toAccountName: "Destination Bank"
        )

        XCTAssertEqual(balance(named: "Source Cash", in: store), 8_500, accuracy: 0.001)
        XCTAssertEqual(balance(named: "Destination Bank", in: store), 3_500, accuracy: 0.001)
        XCTAssertEqual(totalCash(in: store), 12_000, accuracy: 0.001)
    }

    func testPaidExpenseWithMissingAccountDoesNotChangeCash() {
        let store = makeStore(startingCash: 10_000)
        let invalidExpense = FinancialEvent(
            type: .expense,
            status: .paid,
            title: "Invalid Paid Expense",
            amount: 500,
            date: startDate,
            accountName: "Missing Account",
            paymentMethodName: "Cash",
            categoryName: "Groceries",
            subCategoryName: "Groceries"
        )

        store.addFinancialEvent(invalidExpense)

        XCTAssertEqual(store.availableCash, 10_000, accuracy: 0.001)
        XCTAssertFalse(store.financialEvents.contains { $0.id == invalidExpense.id })
    }

    func testPaidIncomeWithMissingAccountDoesNotChangeCash() {
        let store = makeStore(startingCash: 10_000)
        let invalidIncome = FinancialEvent(
            type: .income,
            status: .paid,
            title: "Invalid Paid Income",
            amount: 2_000,
            date: startDate,
            accountName: "Missing Account",
            incomeType: .oneTimeCashInflow
        )

        store.addFinancialEvent(invalidIncome)

        XCTAssertEqual(store.availableCash, 10_000, accuracy: 0.001)
        XCTAssertFalse(store.financialEvents.contains { $0.id == invalidIncome.id })
    }

    func testRepeatedReadOrRecalculationDoesNotDuplicateAccountImpact() {
        let suiteName = makeSuiteName()
        let defaults = makeIsolatedUserDefaults(suiteName: suiteName)
        let store = makeStore(startingCash: 10_000, userDefaults: defaults)

        store.addManualExpense(
            title: "Single Expense",
            amount: 750,
            date: startDate,
            accountName: accountName,
            paymentMethodName: "Cash",
            categoryName: "Groceries",
            subCategoryName: "Groceries"
        )

        XCTAssertEqual(store.availableCash, 9_250, accuracy: 0.001)
        _ = store.runway(from: startDate)
        _ = store.monthlyForecasts(numberOfMonths: 1, from: startDate)
        XCTAssertEqual(store.availableCash, 9_250, accuracy: 0.001)

        let reloadedStore = WalletStore(userDefaults: defaults)
        XCTAssertEqual(reloadedStore.availableCash, 9_250, accuracy: 0.001)
    }

    func testCreditCardPurchaseDoesNotDecreaseCashImmediately() {
        let card = makeCreditCard(openingOutstandingBalance: 0)
        let store = makeStore(startingCash: 10_000)
        store.creditCards = [card]

        store.addCreditCardPurchase(
            cardID: card.id,
            title: "Card Groceries",
            amount: 1_000,
            purchaseDate: startDate,
            categoryName: "Groceries",
            subCategoryName: "Groceries",
            note: nil
        )

        XCTAssertEqual(store.availableCash, 10_000, accuracy: 0.001)
        XCTAssertEqual(store.accounts.first?.balance ?? 0, 10_000, accuracy: 0.001)
    }

    func testCreditCardPurchaseIncreasesOutstanding() {
        let card = makeCreditCard(openingOutstandingBalance: 0)
        let store = makeStore(startingCash: 10_000)
        store.creditCards = [card]

        store.addCreditCardPurchase(
            cardID: card.id,
            title: "Card Groceries",
            amount: 1_000,
            purchaseDate: startDate,
            categoryName: "Groceries",
            subCategoryName: "Groceries",
            note: nil
        )

        XCTAssertEqual(store.creditCardOutstanding(cardID: card.id), 1_000, accuracy: 0.001)
    }

    func testUpdatingCreditCardPurchaseMutatesExistingRecordOnly() {
        let card = makeCreditCard(openingOutstandingBalance: 0)
        let store = makeStore(startingCash: 10_000)
        store.creditCards = [card]

        store.addCreditCardPurchase(
            cardID: card.id,
            title: "Card Groceries",
            amount: 1_000,
            purchaseDate: startDate,
            categoryName: "Groceries",
            subCategoryName: "Groceries",
            note: nil
        )

        guard var purchase = store.creditCardPurchases.first else {
            XCTFail("Expected a credit card purchase.")
            return
        }

        let originalID = purchase.id
        let originalCreatedAt = purchase.createdAt
        let updatedDate = date(year: 2026, month: 7, day: 3)
        purchase.title = "Edited Card Groceries"
        purchase.amount = 1_250
        purchase.purchaseDate = updatedDate
        purchase.note = "Edited note"

        store.updateCreditCardPurchase(purchase)

        XCTAssertEqual(store.creditCardPurchases.count, 1)
        XCTAssertEqual(store.creditCardPurchases.first?.id, originalID)
        XCTAssertEqual(store.creditCardPurchases.first?.createdAt, originalCreatedAt)
        XCTAssertEqual(store.creditCardPurchases.first?.title, "Edited Card Groceries")
        XCTAssertEqual(store.creditCardPurchases.first?.purchaseDate, updatedDate)
        XCTAssertEqual(store.creditCardOutstanding(cardID: card.id), 1_250, accuracy: 0.001)
        XCTAssertEqual(store.availableCash, 10_000, accuracy: 0.001)
    }

    func testCreditCardPaymentReducesCashAndOutstanding() {
        let card = makeCreditCard(openingOutstandingBalance: 3_000)
        let store = makeStore(startingCash: 10_000)
        store.creditCards = [card]

        let didPay = store.addCreditCardPayment(
            cardID: card.id,
            fromAccountName: accountName,
            amount: 1_000,
            paymentDate: startDate,
            note: nil
        )

        XCTAssertTrue(didPay)
        XCTAssertEqual(store.availableCash, 9_000, accuracy: 0.001)
        XCTAssertEqual(store.creditCardOutstanding(cardID: card.id), 2_000, accuracy: 0.001)
    }

    func testCreditCardPaymentDoesNotCreateCategorySpending() {
        let card = makeCreditCard(openingOutstandingBalance: 3_000)
        let store = makeStore(startingCash: 10_000)
        store.creditCards = [card]

        let spendingBeforePayment = store.actualSpendingByCategory(year: 2026, month: 6)
        let didPay = store.addCreditCardPayment(
            cardID: card.id,
            fromAccountName: accountName,
            amount: 1_000,
            paymentDate: startDate,
            note: nil
        )
        let spendingAfterPayment = store.actualSpendingByCategory(year: 2026, month: 6)

        XCTAssertTrue(didPay)
        XCTAssertEqual(spendingBeforePayment.values.reduce(0, +), 0, accuracy: 0.001)
        XCTAssertEqual(spendingAfterPayment.values.reduce(0, +), 0, accuracy: 0.001)
    }

    func testFutureUnpaidInstallmentDoesNotDecreaseCash() {
        let store = makeStore(startingCash: 10_000)
        let plan = makeInstallmentPlan(
            totalAmount: 3_000,
            installmentCount: 3,
            firstDueDate: futureDate
        )

        store.addInstallmentPlanAndGenerateEvents(plan)

        XCTAssertEqual(store.availableCash, 10_000, accuracy: 0.001)
        XCTAssertEqual(store.installmentPlans.count, 1)
        XCTAssertEqual(store.financialEvents.count, 3)
        XCTAssertTrue(store.financialEvents.allSatisfy { $0.type == .installment && $0.status == .unpaid })
    }

    func testPaidInstallmentDecreasesCashOnce() throws {
        let suiteName = makeSuiteName()
        let defaults = makeIsolatedUserDefaults(suiteName: suiteName)
        let store = makeStore(startingCash: 10_000, userDefaults: defaults)
        let plan = makeInstallmentPlan(
            totalAmount: 2_000,
            installmentCount: 2,
            firstDueDate: startDate
        )
        store.addInstallmentPlanAndGenerateEvents(plan)

        let firstInstallment = try XCTUnwrap(
            store.financialEvents
                .filter { $0.type == .installment }
                .sorted { $0.date < $1.date }
                .first
        )

        store.markAsPaid(firstInstallment)

        XCTAssertEqual(store.availableCash, 9_000, accuracy: 0.001)
        XCTAssertEqual(store.availableCash, 9_000, accuracy: 0.001)
        _ = store.runway(from: startDate)
        XCTAssertEqual(store.availableCash, 9_000, accuracy: 0.001)

        let reloadedStore = WalletStore(userDefaults: defaults)
        XCTAssertEqual(reloadedStore.availableCash, 9_000, accuracy: 0.001)
        XCTAssertEqual(reloadedStore.financialEvents.filter { $0.type == .installment && $0.status == .paid }.count, 1)
    }

    func testInstallmentPaidCountExceedsTotalIsDetectedByValidation() {
        let store = makeStore(startingCash: 10_000)
        let plan = makeInstallmentPlan(
            totalAmount: 1_000,
            installmentCount: 1,
            firstDueDate: startDate
        )
        let firstPaid = makeInstallmentEvent(plan: plan, status: .paid, date: startDate)
        let secondPaid = makeInstallmentEvent(plan: plan, status: .paid, date: futureDate)
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            installmentPlans: [plan],
            financialEvents: [firstPaid, secondPaid],
            creditCards: []
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.issues.contains { $0.title == "Installment paid count exceeds total" })
    }

    func testInstallmentLinkedAccountOrCardReferenceValidationIfSupported() {
        let store = makeStore(startingCash: 10_000)
        let missingCardID = UUID()
        let plan = makeInstallmentPlan(
            totalAmount: 1_000,
            installmentCount: 1,
            firstDueDate: startDate,
            accountName: "Missing Account",
            linkedCreditCardID: missingCardID
        )
        let snapshot = makeSnapshot(
            accounts: store.accounts,
            categories: store.categories,
            installmentPlans: [plan],
            financialEvents: [],
            creditCards: []
        )

        let report = store.makeBackupValidationReport(for: snapshot)

        XCTAssertTrue(report.issues.contains { $0.title == "Installment plan missing account" })
        XCTAssertTrue(report.issues.contains { $0.title == "Installment plan missing linked card" })
    }

    func testFutureRecurringOccurrenceDoesNotDecreaseCashBeforePaid() throws {
        let store = makeStore(startingCash: 10_000)
        let series = makeRecurringExpenseSeries(
            title: "Monthly Rent",
            amount: 2_000,
            startDate: date(year: 2026, month: 6, day: 5)
        )

        store.addFinancialEvent(series)
        let occurrences = store.upcomingKnownExpenseEvents(year: 2026, month: 7)

        XCTAssertEqual(store.availableCash, 10_000, accuracy: 0.001)
        XCTAssertEqual(store.financialEvents.filter { $0.status == .paid }.count, 0)
        let occurrence = try XCTUnwrap(occurrences.first { $0.sourceRecurringEventID == series.id })
        XCTAssertEqual(occurrence.status, .unpaid)
        XCTAssertEqual(occurrence.amount, 2_000, accuracy: 0.001)
    }

    func testEditingRecurringPaymentDoesNotCreatePaidTransaction() {
        let store = makeStore(startingCash: 10_000)
        var series = makeRecurringExpenseSeries(
            title: "Monthly Rent",
            amount: 2_000,
            startDate: date(year: 2026, month: 6, day: 5)
        )
        store.addFinancialEvent(series)

        series.amount = 2_200
        series.note = "Edited planned amount"
        store.updateFinancialEvent(series)

        XCTAssertEqual(store.availableCash, 10_000, accuracy: 0.001)
        XCTAssertEqual(store.financialEvents.filter { $0.status == .paid }.count, 0)
        XCTAssertEqual(store.financialEvents.first(where: { $0.id == series.id })?.amount ?? 0, 2_200, accuracy: 0.001)
    }

    func testMarkingOneRecurringOccurrencePaidDoesNotMarkFutureOccurrencesPaid() throws {
        let store = makeStore(startingCash: 10_000)
        let series = makeRecurringExpenseSeries(
            title: "Monthly Rent",
            amount: 2_000,
            startDate: date(year: 2026, month: 6, day: 5)
        )
        store.addFinancialEvent(series)
        let juneOccurrence = try XCTUnwrap(store.upcomingKnownExpenseEvents(year: 2026, month: 6).first)

        let didPay = store.markRecurringOccurrencePaid(
            series: series,
            occurrenceDate: juneOccurrence.date,
            amount: juneOccurrence.amount,
            accountName: accountName,
            paymentDate: juneOccurrence.date,
            paymentMethodName: "Cash",
            categoryName: juneOccurrence.categoryName,
            subCategoryName: juneOccurrence.subCategoryName,
            note: nil
        )

        XCTAssertTrue(didPay)
        XCTAssertEqual(store.financialEvents.filter { $0.status == .paid && $0.sourceRecurringEventID == series.id }.count, 1)
        XCTAssertNil(store.paidRecurringOccurrence(sourceID: series.id, year: 2026, month: 7))
        let julyOccurrence = try XCTUnwrap(store.upcomingKnownExpenseEvents(year: 2026, month: 7).first { $0.sourceRecurringEventID == series.id })
        XCTAssertEqual(julyOccurrence.status, .unpaid)
    }

    func testRecurringOccurrencePaymentDoesNotDuplicateCashImpact() throws {
        let suiteName = makeSuiteName()
        let defaults = makeIsolatedUserDefaults(suiteName: suiteName)
        let store = makeStore(startingCash: 10_000, userDefaults: defaults)
        let series = makeRecurringExpenseSeries(
            title: "Monthly Rent",
            amount: 2_000,
            startDate: date(year: 2026, month: 6, day: 5)
        )
        store.addFinancialEvent(series)
        let juneOccurrence = try XCTUnwrap(store.upcomingKnownExpenseEvents(year: 2026, month: 6).first)

        let firstPayment = store.markRecurringOccurrencePaid(
            series: series,
            occurrenceDate: juneOccurrence.date,
            amount: juneOccurrence.amount,
            accountName: accountName,
            paymentDate: juneOccurrence.date,
            paymentMethodName: "Cash",
            categoryName: juneOccurrence.categoryName,
            subCategoryName: juneOccurrence.subCategoryName,
            note: nil
        )
        let duplicatePayment = store.markRecurringOccurrencePaid(
            series: series,
            occurrenceDate: juneOccurrence.date,
            amount: juneOccurrence.amount,
            accountName: accountName,
            paymentDate: juneOccurrence.date,
            paymentMethodName: "Cash",
            categoryName: juneOccurrence.categoryName,
            subCategoryName: juneOccurrence.subCategoryName,
            note: nil
        )

        XCTAssertTrue(firstPayment)
        XCTAssertFalse(duplicatePayment)
        XCTAssertEqual(store.availableCash, 8_000, accuracy: 0.001)
        _ = store.runway(from: startDate)
        XCTAssertEqual(store.availableCash, 8_000, accuracy: 0.001)

        let reloadedStore = WalletStore(userDefaults: defaults)
        XCTAssertEqual(reloadedStore.availableCash, 8_000, accuracy: 0.001)
        XCTAssertEqual(reloadedStore.financialEvents.filter { $0.status == .paid && $0.sourceRecurringEventID == series.id }.count, 1)
    }

    func testCalculateInstaPayFeeRespectsCap() {
        let store = makeStore(startingCash: 0)
        store.instaPayFeePercent = 0.1
        store.instaPayMinimumFee = 0.5
        store.instaPayMaximumFee = 20.0

        // Large amount: 0.1% of 50,000 = 50 EGP → capped at 20 EGP
        XCTAssertEqual(store.calculateInstaPayFee(for: 50_000), 20.0, accuracy: 0.001, "Fee must not exceed maximum cap")

        // Small amount: 0.1% of 100 = 0.10 EGP → floored to 0.50 EGP minimum
        XCTAssertEqual(store.calculateInstaPayFee(for: 100), 0.5, accuracy: 0.001, "Fee must not fall below minimum")

        // Normal amount: 0.1% of 5,000 = 5 EGP → within range
        XCTAssertEqual(store.calculateInstaPayFee(for: 5_000), 5.0, accuracy: 0.001, "Fee within range should be exact percentage")

        // Zero amount: no fee
        XCTAssertEqual(store.calculateInstaPayFee(for: 0), 0.0, accuracy: 0.001, "Zero amount produces zero fee")
    }

    func testVariableRecurringIncomeAppearsInActionableIncomeAndSkipsEmptyMonth() {
        let store = makeStore(startingCash: 10_000)
        let salary = makeVariableRecurringIncomeSeries(
            overrides: [
                RecurringScheduleOverride(year: 2026, month: 6, amount: 100_000),
                RecurringScheduleOverride(year: 2026, month: 7, amount: 80_000),
                RecurringScheduleOverride(year: 2026, month: 8, amount: 0, isSkipped: true)
            ]
        )

        store.addFinancialEvent(salary)

        XCTAssertEqual(store.upcomingKnownIncomeEvents(year: 2026, month: 6).map(\.amount), [100_000])
        XCTAssertEqual(store.upcomingKnownIncomeEvents(year: 2026, month: 7).map(\.amount), [80_000])
        XCTAssertTrue(store.upcomingKnownIncomeEvents(year: 2026, month: 8).isEmpty)
        XCTAssertEqual(store.availableCash, 10_000, accuracy: 0.001)
    }

    func testMarkRecurringIncomeOccurrenceReceivedKeepsFutureMonths() {
        let store = makeStore(startingCash: 10_000)
        let salary = makeVariableRecurringIncomeSeries(
            overrides: [
                RecurringScheduleOverride(year: 2026, month: 6, amount: 100_000),
                RecurringScheduleOverride(year: 2026, month: 7, amount: 80_000)
            ]
        )

        store.addFinancialEvent(salary)

        let didMarkReceived = store.markRecurringOccurrencePaid(
            series: salary,
            occurrenceDate: date(year: 2026, month: 6, day: 25),
            amount: 100_000,
            accountName: accountName,
            paymentDate: date(year: 2026, month: 6, day: 25),
            note: nil
        )

        XCTAssertTrue(didMarkReceived)
        XCTAssertEqual(store.availableCash, 110_000, accuracy: 0.001)
        XCTAssertTrue(store.upcomingKnownIncomeEvents(year: 2026, month: 6).isEmpty)
        XCTAssertEqual(store.upcomingKnownIncomeEvents(year: 2026, month: 7).map(\.amount), [80_000])
    }

    func testSkippingRecurringIncomeOccurrenceKeepsLaterMonths() {
        let store = makeStore(startingCash: 10_000)
        let salary = makeVariableRecurringIncomeSeries(
            overrides: [
                RecurringScheduleOverride(year: 2026, month: 6, amount: 100_000),
                RecurringScheduleOverride(year: 2026, month: 7, amount: 80_000)
            ]
        )

        store.addFinancialEvent(salary)

        XCTAssertTrue(store.skipRecurringOccurrence(seriesID: salary.id, occurrenceDate: date(year: 2026, month: 6, day: 25)))
        XCTAssertTrue(store.upcomingKnownIncomeEvents(year: 2026, month: 6).isEmpty)
        XCTAssertEqual(store.upcomingKnownIncomeEvents(year: 2026, month: 7).map(\.amount), [80_000])
        XCTAssertEqual(store.availableCash, 10_000, accuracy: 0.001)
    }

    func testDeletePersonDebtReversesLinkedEntryBalanceImpact() {
        let store = makeStore(startingCash: 1_000)

        // Lending 200 (owedToMe) reduces cash by 200 via initialLending entry impact.
        let didAdd = store.addPersonDebt(
            kind: .owedToMe,
            personName: "Test Borrower",
            amount: 200,
            accountName: accountName,
            date: startDate,
            dueDate: nil,
            note: nil
        )

        XCTAssertTrue(didAdd)
        XCTAssertEqual(store.availableCash, 800, accuracy: 0.001,
            "Lending must decrease cash by the lent amount.")

        guard let debt = store.personDebts.first else {
            XCTFail("Expected a person debt record after addPersonDebt.")
            return
        }

        let didDelete = store.deletePersonDebt(debt)

        XCTAssertTrue(didDelete)
        XCTAssertEqual(store.availableCash, 1_000, accuracy: 0.001,
            "Deleting a debt must reverse all linked entry balance impacts and restore original cash.")
        XCTAssertTrue(store.personDebts.isEmpty,
            "Deleted debt must be removed from personDebts.")
        XCTAssertTrue(store.personDebtEntries.isEmpty,
            "All child entries must be removed when parent debt is deleted.")
    }

    func testDeletingRecurringIncomeSeriesRemovesFutureGeneratedOccurrences() {
        let store = makeStore(startingCash: 10_000)
        let salary = makeVariableRecurringIncomeSeries(
            overrides: [
                RecurringScheduleOverride(year: 2026, month: 6, amount: 100_000),
                RecurringScheduleOverride(year: 2026, month: 7, amount: 80_000)
            ]
        )

        store.addFinancialEvent(salary)
        store.deleteFinancialEvent(salary)

        XCTAssertTrue(store.upcomingKnownIncomeEvents(year: 2026, month: 6).isEmpty)
        XCTAssertTrue(store.upcomingKnownIncomeEvents(year: 2026, month: 7).isEmpty)
        XCTAssertEqual(store.availableCash, 10_000, accuracy: 0.001)
    }

    func testFixedRecurringIncomeEndAfterThreeMonthsGeneratesOnlyThreeMonths() {
        let store = makeStore(startingCash: 10_000)
        let salary = makeFixedRecurringIncomeSeries(
            amount: 50_000,
            recurringEndKind: .afterNumberOfPayments,
            recurringEndPaymentCount: 3
        )

        store.addFinancialEvent(salary)

        XCTAssertEqual(store.upcomingKnownIncomeEvents(year: 2026, month: 6).map(\.amount), [50_000])
        XCTAssertEqual(store.upcomingKnownIncomeEvents(year: 2026, month: 7).map(\.amount), [50_000])
        XCTAssertEqual(store.upcomingKnownIncomeEvents(year: 2026, month: 8).map(\.amount), [50_000])
        XCTAssertTrue(store.upcomingKnownIncomeEvents(year: 2026, month: 9).isEmpty)
    }

    func testFixedRecurringIncomeEndDateStopsAfterEndDate() {
        let store = makeStore(startingCash: 10_000)
        let salary = makeFixedRecurringIncomeSeries(
            amount: 50_000,
            recurringEndKind: .onDate,
            recurringEndDate: date(year: 2026, month: 7, day: 25)
        )

        store.addFinancialEvent(salary)

        XCTAssertEqual(store.upcomingKnownIncomeEvents(year: 2026, month: 6).map(\.amount), [50_000])
        XCTAssertEqual(store.upcomingKnownIncomeEvents(year: 2026, month: 7).map(\.amount), [50_000])
        XCTAssertTrue(store.upcomingKnownIncomeEvents(year: 2026, month: 8).isEmpty)
    }

    func testFixedRecurringIncomeNeverGeneratesOnlyWithinRequestedHorizon() {
        let store = makeStore(startingCash: 10_000)
        let salary = makeFixedRecurringIncomeSeries(amount: 50_000)

        store.addFinancialEvent(salary)

        let occurrences = store.upcomingKnownIncomeEvents(
            numberOfMonths: 3,
            from: date(year: 2026, month: 6, day: 1)
        )

        XCTAssertEqual(occurrences.map(\.amount), [50_000, 50_000, 50_000])
        XCTAssertEqual(
            occurrences.map { Calendar.current.component(.month, from: $0.date) },
            [6, 7, 8]
        )
    }

    func testVariableRecurringIncomeDoesNotGenerateOutsidePlanningPeriod() {
        let store = makeStore(startingCash: 10_000)
        var salary = makeVariableRecurringIncomeSeries(
            overrides: [
                RecurringScheduleOverride(year: 2026, month: 6, amount: 100_000),
                RecurringScheduleOverride(year: 2026, month: 7, amount: 80_000),
                RecurringScheduleOverride(year: 2026, month: 8, amount: 0, isSkipped: true),
                RecurringScheduleOverride(year: 2026, month: 9, amount: 120_000)
            ]
        )
        salary.recurringEndKind = .afterNumberOfPayments
        salary.recurringEndPaymentCount = 3

        store.addFinancialEvent(salary)

        XCTAssertEqual(store.upcomingKnownIncomeEvents(year: 2026, month: 6).map(\.amount), [100_000])
        XCTAssertEqual(store.upcomingKnownIncomeEvents(year: 2026, month: 7).map(\.amount), [80_000])
        XCTAssertTrue(store.upcomingKnownIncomeEvents(year: 2026, month: 8).isEmpty)
        XCTAssertTrue(store.upcomingKnownIncomeEvents(year: 2026, month: 9).isEmpty)
    }

    func testForecastAndActionableIncomeUseSameVariableRecurringOccurrenceMonths() {
        let store = makeStore(startingCash: 10_000)
        var salary = makeVariableRecurringIncomeSeries(
            overrides: [
                RecurringScheduleOverride(year: 2026, month: 6, amount: 100_000),
                RecurringScheduleOverride(year: 2026, month: 7, amount: 80_000),
                RecurringScheduleOverride(year: 2026, month: 8, amount: 0, isSkipped: true)
            ]
        )
        salary.recurringEndKind = .afterNumberOfPayments
        salary.recurringEndPaymentCount = 3
        store.addFinancialEvent(salary)

        let actionableDates = store.upcomingKnownIncomeEvents(
            numberOfMonths: 3,
            from: date(year: 2026, month: 6, day: 1)
        ).map { Calendar.current.dateComponents([.year, .month], from: $0.date) }

        let result = ForecastEngine.calculateRunwayCheck(
            accounts: store.accounts,
            financialEvents: store.financialEvents,
            monthlyBudgets: [],
            minimumSafeBalance: 0,
            from: date(year: 2026, month: 6, day: 1),
            targetDate: date(year: 2026, month: 8, day: 31)
        )
        let forecastDates = result.breakdown.futureCashInflowItems.map {
            Calendar.current.dateComponents([.year, .month], from: $0.date)
        }

        XCTAssertEqual(actionableDates, forecastDates)
        XCTAssertEqual(result.breakdown.futureCashInflowItems.map(\.amount), [100_000, 80_000])
    }

    func testRunwayCheckMatchesBudgetIncomeForFutureVariableSalaryOverrides() {
        let store = makeStore(startingCash: 10_000)
        let salary = makeVariableRecurringIncomeSeries(
            startDate: date(year: 2026, month: 6, day: 25),
            overrides: [
                RecurringScheduleOverride(year: 2026, month: 8, amount: 5_000),
                RecurringScheduleOverride(year: 2026, month: 9, amount: 5_000),
                RecurringScheduleOverride(year: 2026, month: 10, amount: 5_000)
            ]
        )
        store.addFinancialEvent(salary)

        let result = store.runwayCheck(
            targetDate: date(year: 2026, month: 10, day: 31),
            from: date(year: 2026, month: 6, day: 1)
        )
        let timelineIncomeTotal = result.breakdown.futureCashInflowTotal
        let budgetIncomeTotal = [
            store.monthlyBudgetIncome(year: 2026, month: 8),
            store.monthlyBudgetIncome(year: 2026, month: 9),
            store.monthlyBudgetIncome(year: 2026, month: 10)
        ].reduce(0, +)

        XCTAssertEqual(result.breakdown.futureCashInflowItems.map(\.amount), [5_000, 5_000, 5_000])
        XCTAssertEqual(
            result.breakdown.futureCashInflowItems.map { Calendar.current.component(.month, from: $0.date) },
            [8, 9, 10]
        )
        XCTAssertEqual(timelineIncomeTotal, budgetIncomeTotal, accuracy: 0.001)
        XCTAssertEqual(store.availableCash, 10_000, accuracy: 0.001)
    }

    func testPaidExpenseAdvancesAffectedAccountUpdatedAtForSync() throws {
        let oldDate = Date(timeIntervalSince1970: 1_000)
        let account = Account(
            name: accountName,
            balance: 10_000,
            type: .cash,
            createdAt: oldDate,
            updatedAt: oldDate
        )
        let store = makeStore(accounts: [account])

        store.addManualExpense(
            title: "Timestamped Expense",
            amount: 500,
            date: startDate,
            accountName: accountName,
            paymentMethodName: "Cash",
            categoryName: "Groceries",
            subCategoryName: "Groceries"
        )

        let updatedAccount = try XCTUnwrap(store.accounts.first)
        XCTAssertEqual(updatedAccount.balance, 9_500, accuracy: 0.001)
        XCTAssertGreaterThan(updatedAccount.updatedAt, oldDate)
    }

    func testPaidIncomeAdvancesAffectedAccountUpdatedAtForSync() throws {
        let oldDate = Date(timeIntervalSince1970: 1_000)
        let account = Account(
            name: accountName,
            balance: 10_000,
            type: .cash,
            createdAt: oldDate,
            updatedAt: oldDate
        )
        let store = makeStore(accounts: [account])

        store.addIncome(
            title: "Timestamped Income",
            amount: 2_000,
            date: startDate,
            accountName: accountName,
            incomeType: .oneTimeCashInflow
        )

        let updatedAccount = try XCTUnwrap(store.accounts.first)
        XCTAssertEqual(updatedAccount.balance, 12_000, accuracy: 0.001)
        XCTAssertGreaterThan(updatedAccount.updatedAt, oldDate)
    }

    func testDeletingPaidExpenseAdvancesAffectedAccountUpdatedAtForSync() throws {
        let oldDate = Date(timeIntervalSince1970: 1_000)
        let account = Account(
            name: accountName,
            balance: 10_000,
            type: .cash,
            createdAt: oldDate,
            updatedAt: oldDate
        )
        let store = makeStore(accounts: [account])

        store.addManualExpense(
            title: "Delete Timestamped Expense",
            amount: 500,
            date: startDate,
            accountName: accountName,
            paymentMethodName: "Cash",
            categoryName: "Groceries",
            subCategoryName: "Groceries"
        )
        let event = try XCTUnwrap(store.financialEvents.first)
        store.accounts[0].updatedAt = oldDate

        store.deleteFinancialEvent(event)

        let updatedAccount = try XCTUnwrap(store.accounts.first)
        XCTAssertEqual(updatedAccount.balance, 10_000, accuracy: 0.001)
        XCTAssertGreaterThan(updatedAccount.updatedAt, oldDate)
    }

    func testTransferAdvancesBothAffectedAccountUpdatedAtForSync() throws {
        let oldDate = Date(timeIntervalSince1970: 1_000)
        let store = makeStore(
            accounts: [
                Account(
                    name: "Source Cash",
                    balance: 10_000,
                    type: .cash,
                    createdAt: oldDate,
                    updatedAt: oldDate
                ),
                Account(
                    name: "Destination Bank",
                    balance: 2_000,
                    type: .bank,
                    createdAt: oldDate,
                    updatedAt: oldDate
                )
            ]
        )

        store.addTransfer(
            amount: 1_500,
            date: startDate,
            fromAccountName: "Source Cash",
            toAccountName: "Destination Bank"
        )

        let source = try XCTUnwrap(store.accounts.first { $0.name == "Source Cash" })
        let destination = try XCTUnwrap(store.accounts.first { $0.name == "Destination Bank" })
        XCTAssertEqual(source.balance, 8_500, accuracy: 0.001)
        XCTAssertEqual(destination.balance, 3_500, accuracy: 0.001)
        XCTAssertGreaterThan(source.updatedAt, oldDate)
        XCTAssertGreaterThan(destination.updatedAt, oldDate)
    }

    private func makeStore(
        startingCash: Double,
        userDefaults: UserDefaults? = nil
    ) -> WalletStore {
        makeStore(
            accounts: [Account(name: accountName, balance: startingCash, type: .cash)],
            userDefaults: userDefaults
        )
    }

    private func makeStore(
        accounts: [Account],
        userDefaults: UserDefaults? = nil
    ) -> WalletStore {
        let defaults = userDefaults ?? makeIsolatedUserDefaults()
        let store = WalletStore(userDefaults: defaults)
        store.accounts = accounts
        store.categories = [
            WalletBoard.Category(name: "Groceries", subcategories: ["Groceries"]),
            WalletBoard.Category(name: "Rent", subcategories: ["Rent"])
        ]
        store.financialEvents = []
        store.creditCards = []
        store.creditCardPurchases = []
        store.creditCardPayments = []
        store.installmentPlans = []
        return store
    }

    private func balance(named accountName: String, in store: WalletStore) -> Double {
        store.accounts.first { $0.name == accountName }?.balance ?? 0
    }

    private func totalCash(in store: WalletStore) -> Double {
        store.accounts.map(\.balance).reduce(0, +)
    }

    private func makeCreditCard(openingOutstandingBalance: Double) -> CreditCard {
        CreditCard(
            name: "Invariant Card",
            bankName: "Test Bank",
            cardNetwork: .visa,
            creditLimit: 20_000,
            openingOutstandingBalance: openingOutstandingBalance,
            openingOutstandingDate: openingOutstandingBalance > 0 ? startDate : nil,
            statementClosingDay: 15,
            paymentDueDay: 25,
            defaultPaymentAccountName: accountName
        )
    }

    private func makeInstallmentPlan(
        totalAmount: Double,
        installmentCount: Int,
        firstDueDate: Date,
        accountName: String? = nil,
        linkedCreditCardID: UUID? = nil
    ) -> InstallmentPlan {
        InstallmentPlan(
            purchaseName: "Invariant Installment",
            totalAmount: totalAmount,
            installmentCount: installmentCount,
            firstDueDate: firstDueDate,
            accountName: accountName ?? self.accountName,
            categoryName: "Groceries",
            subCategoryName: "Groceries",
            paymentMethodName: "Valu",
            linkedCreditCardID: linkedCreditCardID
        )
    }

    private func makeInstallmentEvent(
        plan: InstallmentPlan,
        status: FinancialEventStatus,
        date: Date
    ) -> FinancialEvent {
        FinancialEvent(
            type: .installment,
            status: status,
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

    private func makeRecurringExpenseSeries(
        title: String,
        amount: Double,
        startDate: Date
    ) -> FinancialEvent {
        FinancialEvent(
            type: .obligation,
            status: .unpaid,
            title: title,
            amount: amount,
            date: startDate,
            accountName: accountName,
            paymentMethodName: "Cash",
            categoryName: "Rent",
            subCategoryName: "Rent",
            repeatRule: .monthly,
            recurringEndKind: .never,
            recurringAmountMode: .fixedAmount
        )
    }

    private func makeVariableRecurringIncomeSeries(
        startDate: Date? = nil,
        overrides: [RecurringScheduleOverride]
    ) -> FinancialEvent {
        FinancialEvent(
            type: .income,
            status: .expected,
            title: "Variable Salary",
            amount: overrides.first(where: { !$0.isSkipped && $0.amount > 0 })?.amount ?? 0,
            date: startDate ?? date(year: 2026, month: 6, day: 25),
            accountName: accountName,
            incomeType: .salary,
            repeatRule: .monthly,
            recurringEndKind: .never,
            recurringScheduleOverrides: overrides,
            recurringAmountMode: .variableEachMonth
        )
    }

    private func makeFixedRecurringIncomeSeries(
        amount: Double,
        recurringEndKind: RecurringEndKind? = nil,
        recurringEndDate: Date? = nil,
        recurringEndPaymentCount: Int? = nil
    ) -> FinancialEvent {
        FinancialEvent(
            type: .income,
            status: .expected,
            title: "Fixed Salary",
            amount: amount,
            date: date(year: 2026, month: 6, day: 25),
            accountName: accountName,
            incomeType: .salary,
            repeatRule: .monthly,
            recurringEndKind: recurringEndKind,
            recurringEndDate: recurringEndDate,
            recurringEndPaymentCount: recurringEndPaymentCount,
            recurringAmountMode: .fixedAmount
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day
        ).date!
    }

    private func makeSnapshot(
        accounts: [Account],
        categories: [WalletBoard.Category],
        installmentPlans: [InstallmentPlan],
        financialEvents: [FinancialEvent],
        creditCards: [CreditCard]
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
            creditCards: creditCards,
            monthlyLivingBurn: 0,
            instaPayFeePercent: 0.1,
            instaPayMinimumFee: 0.5,
            instaPayMaximumFee: 20
        )
    }

    private func makeIsolatedUserDefaults(
        suiteName: String = "WalletStoreFinancialInvariantTests-\(UUID().uuidString)"
    ) -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults suite.")
            return .standard
        }

        defaults.removePersistentDomain(forName: suiteName)
        suiteNames.append(suiteName)
        return defaults
    }

    private func makeSuiteName() -> String {
        "WalletStoreFinancialInvariantTests-\(UUID().uuidString)"
    }
}
