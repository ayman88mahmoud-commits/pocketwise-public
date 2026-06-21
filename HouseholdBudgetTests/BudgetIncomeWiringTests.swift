import XCTest
@testable import HouseholdBudget

final class BudgetIncomeWiringTests: XCTestCase {

    private let accountName = "Test Cash"
    private var suiteNames: [String] = []

    override func tearDown() {
        for suiteName in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        suiteNames.removeAll()
        super.tearDown()
    }

    // One-time expected income in a month appears in monthlyBudgetIncome; account balance is unchanged.
    func testOneTimeExpectedIncomeAppearsInMonthlyBudgetIncome() {
        let store = makeStore(startingCash: 10_000)
        let income = FinancialEvent(
            type: .income,
            status: .expected,
            title: "Bonus",
            amount: 5_000,
            date: date(2026, 8, 15),
            accountName: accountName,
            incomeType: .salary
        )
        store.addFinancialEvent(income)

        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 8), 5_000, accuracy: 0.001)
        XCTAssertEqual(store.availableCash, 10_000, accuracy: 0.001, "Expected income must not change account balance")
    }

    // A one-time paid (received) income event counts in monthlyBudgetIncome and also increases the balance.
    func testPaidOneTimeIncomeCountedInMonthlyBudgetIncome() {
        let store = makeStore(startingCash: 10_000)
        let income = FinancialEvent(
            type: .income,
            status: .paid,
            title: "Salary Received",
            amount: 5_000,
            date: date(2026, 8, 15),
            accountName: accountName,
            incomeType: .salary
        )
        store.addFinancialEvent(income)

        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 8), 5_000, accuracy: 0.001)
        XCTAssertEqual(store.availableCash, 15_000, accuracy: 0.001, "Received income must increase account balance")
    }

    // Fixed recurring income limited to 3 payments appears in months 8, 9, 10 and returns 0 in month 11.
    func testFixedRecurringIncomeAppearsInExactly3Months() {
        let store = makeStore(startingCash: 0)
        let income = FinancialEvent(
            type: .income,
            status: .expected,
            title: "Fixed Salary",
            amount: 5_000,
            date: date(2026, 8, 15),
            accountName: accountName,
            incomeType: .salary,
            repeatRule: .monthly,
            recurringEndKind: .afterNumberOfPayments,
            recurringEndPaymentCount: 3,
            recurringAmountMode: .fixedAmount
        )
        store.addFinancialEvent(income)

        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 8), 5_000, accuracy: 0.001)
        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 9), 5_000, accuracy: 0.001)
        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 10), 5_000, accuracy: 0.001)
        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 11), 0, accuracy: 0.001, "No income after end of series")
    }

    // After marking one recurring occurrence as received, that month still counts (via the paid path)
    // and subsequent months remain as expected income.
    func testPaidRecurringMonthCountedAlongsideExpectedFutureMonths() {
        let store = makeStore(startingCash: 10_000)
        let income = FinancialEvent(
            type: .income,
            status: .expected,
            title: "Monthly Salary",
            amount: 5_000,
            date: date(2026, 8, 15),
            accountName: accountName,
            incomeType: .salary,
            repeatRule: .monthly,
            recurringEndKind: .never,
            recurringAmountMode: .fixedAmount
        )
        store.addFinancialEvent(income)
        store.markRecurringOccurrencePaid(
            series: income,
            occurrenceDate: date(2026, 8, 15),
            amount: 5_000,
            accountName: accountName,
            paymentDate: date(2026, 8, 15),
            note: nil
        )

        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 8), 5_000, accuracy: 0.001, "Paid occurrence must still count in budget income")
        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 9), 5_000, accuracy: 0.001, "Next month remains expected")
    }

    // Variable recurring income reads per-month override amounts correctly for all three months.
    func testVariableRecurringIncomeCorrectAmountsPerMonth() {
        let store = makeStore(startingCash: 0)
        let overrides = [
            RecurringScheduleOverride(year: 2026, month: 8, amount: 5_000),
            RecurringScheduleOverride(year: 2026, month: 9, amount: 5_000),
            RecurringScheduleOverride(year: 2026, month: 10, amount: 5_000)
        ]
        let income = FinancialEvent(
            type: .income,
            status: .expected,
            title: "Variable Salary",
            amount: 5_000,
            date: date(2026, 8, 1),
            accountName: accountName,
            incomeType: .salary,
            repeatRule: .monthly,
            recurringEndKind: .never,
            recurringScheduleOverrides: overrides,
            recurringAmountMode: .variableEachMonth
        )
        store.addFinancialEvent(income)

        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 8), 5_000, accuracy: 0.001)
        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 9), 5_000, accuracy: 0.001)
        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 10), 5_000, accuracy: 0.001)
    }

    // A variable recurring month explicitly skipped contributes zero to monthlyBudgetIncome.
    func testSkippedVariableMonthExcludedFromBudgetIncome() {
        let store = makeStore(startingCash: 0)
        let overrides = [
            RecurringScheduleOverride(year: 2026, month: 8, amount: 5_000),
            RecurringScheduleOverride(year: 2026, month: 9, amount: 5_000, isSkipped: true),
            RecurringScheduleOverride(year: 2026, month: 10, amount: 5_000)
        ]
        let income = FinancialEvent(
            type: .income,
            status: .expected,
            title: "Variable Salary",
            amount: 5_000,
            date: date(2026, 8, 1),
            accountName: accountName,
            incomeType: .salary,
            repeatRule: .monthly,
            recurringEndKind: .never,
            recurringScheduleOverrides: overrides,
            recurringAmountMode: .variableEachMonth
        )
        store.addFinancialEvent(income)

        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 8), 5_000, accuracy: 0.001)
        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 9), 0, accuracy: 0.001, "Skipped month must not appear in budget income")
        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 10), 5_000, accuracy: 0.001)
    }

    // Recurring series that ends after 1 payment has no income in the second month.
    func testIncomeAfterRecurringEndIsZero() {
        let store = makeStore(startingCash: 0)
        let income = FinancialEvent(
            type: .income,
            status: .expected,
            title: "One-shot Recurring",
            amount: 5_000,
            date: date(2026, 8, 15),
            accountName: accountName,
            incomeType: .salary,
            repeatRule: .monthly,
            recurringEndKind: .afterNumberOfPayments,
            recurringEndPaymentCount: 1,
            recurringAmountMode: .fixedAmount
        )
        store.addFinancialEvent(income)

        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 8), 5_000, accuracy: 0.001)
        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 9), 0, accuracy: 0.001, "Series ended; no income in subsequent month")
    }

    // Expected income events do not touch account balance.
    func testExpectedIncomeDoesNotAffectAccountBalance() {
        let store = makeStore(startingCash: 10_000)
        let income = FinancialEvent(
            type: .income,
            status: .expected,
            title: "Future Income",
            amount: 20_000,
            date: date(2026, 8, 1),
            accountName: accountName,
            incomeType: .salary,
            repeatRule: .monthly,
            recurringEndKind: .never,
            recurringAmountMode: .fixedAmount
        )
        store.addFinancialEvent(income)

        XCTAssertEqual(store.availableCash, 10_000, accuracy: 0.001)
        XCTAssertEqual(store.accounts.first?.balance ?? 0, 10_000, accuracy: 0.001)
    }

    // monthlyBudgetIncome equals the sum from upcomingKnownIncomeEvents for a month with no paid occurrences.
    func testMonthlyBudgetIncomeMatchesUpcomingIncomeEventsForExpectedMonth() {
        let store = makeStore(startingCash: 0)
        let income = FinancialEvent(
            type: .income,
            status: .expected,
            title: "Recurring Income",
            amount: 8_000,
            date: date(2026, 9, 10),
            accountName: accountName,
            incomeType: .salary,
            repeatRule: .monthly,
            recurringEndKind: .never,
            recurringAmountMode: .fixedAmount
        )
        store.addFinancialEvent(income)

        let upcomingTotal = store.upcomingKnownIncomeEvents(year: 2026, month: 9)
            .map(\.amount).reduce(0, +)
        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 9), upcomingTotal, accuracy: 0.001)
    }

    // Expense and obligation events in the same month must not be included in monthlyBudgetIncome.
    func testExpensesNotCountedInMonthlyBudgetIncome() {
        let store = makeStore(startingCash: 10_000)
        let income = FinancialEvent(
            type: .income,
            status: .expected,
            title: "Income",
            amount: 5_000,
            date: date(2026, 8, 1),
            accountName: accountName,
            incomeType: .salary
        )
        let expense = FinancialEvent(
            type: .obligation,
            status: .unpaid,
            title: "Rent",
            amount: 3_000,
            date: date(2026, 8, 1),
            accountName: accountName,
            categoryName: "Rent",
            subCategoryName: "Rent"
        )
        store.addFinancialEvent(income)
        store.addFinancialEvent(expense)

        XCTAssertEqual(store.monthlyBudgetIncome(year: 2026, month: 8), 5_000, accuracy: 0.001, "Expenses must not be included in budget income")
    }

    // MARK: - Helpers

    private func makeStore(startingCash: Double) -> WalletStore {
        let store = WalletStore(userDefaults: makeIsolatedUserDefaults())
        store.accounts = [Account(name: accountName, balance: startingCash, type: .cash)]
        store.categories = [
            HouseholdBudget.Category(name: "Rent", subcategories: ["Rent"])
        ]
        store.financialEvents = []
        store.creditCards = []
        store.creditCardPurchases = []
        store.creditCardPayments = []
        store.installmentPlans = []
        return store
    }

    private func makeIsolatedUserDefaults() -> UserDefaults {
        let suiteName = "BudgetIncomeWiringTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults suite.")
            return .standard
        }
        defaults.removePersistentDomain(forName: suiteName)
        suiteNames.append(suiteName)
        return defaults
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day
        ).date!
    }
}
