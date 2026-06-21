import XCTest
@testable import PocketWise

final class ForecastEngineTests: XCTestCase {

    private let startDate = TestFixtures.date(year: 2026, month: 6, day: 1)
    private let targetDate = TestFixtures.date(year: 2026, month: 6, day: 30)

    func testFutureIncomeDoesNotCountAsAlreadyReceivedCash() {
        let accounts = [TestFixtures.cashAccount(balance: 10_000)]
        let salary = TestFixtures.futureIncome(
            title: "Future Salary",
            amount: 20_000,
            date: TestFixtures.date(year: 2026, month: 6, day: 15)
        )

        let result = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: [salary],
            monthlyBudgets: [],
            minimumSafeBalance: 0,
            from: startDate,
            targetDate: targetDate
        )

        XCTAssertEqual(result.availableCash, 10_000, accuracy: 0.001)
        XCTAssertEqual(result.breakdown.futureCashInflowTotal, 20_000, accuracy: 0.001)
        XCTAssertNotNil(result.nextCashInflow)
        XCTAssertEqual(result.nextCashInflow?.amount ?? 0, 20_000, accuracy: 0.001)
    }

    func testFutureUnpaidObligationAppearsInForecastPressureWithoutMarkingPaid() {
        let accounts = [TestFixtures.cashAccount(balance: 10_000)]
        let rent = TestFixtures.futureObligation(
            title: "Rent",
            amount: 5_000,
            date: TestFixtures.date(year: 2026, month: 6, day: 10),
            categoryName: "Rent"
        )
        let originalEvents = [rent]

        let result = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: originalEvents,
            monthlyBudgets: [],
            minimumSafeBalance: 0,
            from: startDate,
            targetDate: targetDate
        )

        XCTAssertEqual(result.breakdown.datedExpenseTotal, 5_000, accuracy: 0.001)
        XCTAssertEqual(result.lowestExpectedBalance, 5_000, accuracy: 0.001)
        XCTAssertEqual(originalEvents, [rent])
        XCTAssertEqual(rent.status, .unpaid)
    }

    func testBudgetAwareRunwayIncludesFlexiblePlannedBudgetSpending() {
        let accounts = [TestFixtures.cashAccount(balance: 10_000)]
        let budget = TestFixtures.monthlyBudget(
            year: 2026,
            month: 6,
            categoryName: "Groceries",
            plannedAmount: 8_000
        )

        let result = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: [],
            monthlyBudgets: [budget],
            minimumSafeBalance: 0,
            from: startDate,
            targetDate: targetDate
        )

        XCTAssertEqual(result.breakdown.monthlyEstimateTotal, 8_000, accuracy: 0.001)
        XCTAssertNotNil(result.breakdown.monthlyBudgetItems.first)
        XCTAssertEqual(result.breakdown.monthlyBudgetItems.first?.includedAmount ?? 0, 8_000, accuracy: 0.001)
        XCTAssertEqual(result.lowestExpectedBalance, 2_000, accuracy: 0.001)
        XCTAssertEqual(result.bufferAtTarget, 2_000, accuracy: 0.001)
    }

    func testRunwayCanBecomeUnsafeDueToBudgetAwareDeductions() {
        let accounts = [TestFixtures.cashAccount(balance: 5_000)]
        let budget = TestFixtures.monthlyBudget(
            year: 2026,
            month: 6,
            categoryName: "Groceries",
            plannedAmount: 8_000
        )

        let result = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: [],
            monthlyBudgets: [budget],
            minimumSafeBalance: 1_000,
            from: startDate,
            targetDate: targetDate
        )

        XCTAssertEqual(result.breakdown.monthlyEstimateTotal, 8_000, accuracy: 0.001)
        XCTAssertEqual(result.lowestExpectedBalance, -3_000, accuracy: 0.001)
        XCTAssertEqual(result.status, .cashShortage)
        XCTAssertNotNil(result.cashShortageDate)
        XCTAssertEqual(result.shortfallToStaySafe, 4_000, accuracy: 0.001)
    }

    func testForecastEngineDoesNotMutateInputArrays() {
        let accounts = [TestFixtures.cashAccount(balance: 10_000)]
        let events = [
            TestFixtures.futureIncome(
                title: "Future Salary",
                amount: 20_000,
                date: TestFixtures.date(year: 2026, month: 6, day: 15)
            ),
            TestFixtures.futureObligation(
                title: "Rent",
                amount: 5_000,
                date: TestFixtures.date(year: 2026, month: 6, day: 10),
                categoryName: "Rent"
            )
        ]
        let budgets = [
            TestFixtures.monthlyBudget(
                year: 2026,
                month: 6,
                categoryName: "Groceries",
                plannedAmount: 8_000
            )
        ]
        let originalAccounts = accounts
        let originalEvents = events
        let originalBudgets = budgets

        _ = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: events,
            monthlyBudgets: budgets,
            minimumSafeBalance: 0,
            from: startDate,
            targetDate: targetDate
        )

        XCTAssertEqual(accounts, originalAccounts)
        XCTAssertEqual(events, originalEvents)
        XCTAssertEqual(budgets, originalBudgets)
    }

    func testSameDayObligationIsIncludedInForecastHorizon() {
        let accounts = [TestFixtures.cashAccount(balance: 10_000)]
        let sameDayBill = TestFixtures.futureObligation(
            title: "Same Day Bill",
            amount: 1_000,
            date: startDate,
            categoryName: "Bills"
        )

        let result = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: [sameDayBill],
            monthlyBudgets: [],
            minimumSafeBalance: 0,
            from: startDate,
            targetDate: targetDate
        )

        XCTAssertEqual(result.breakdown.datedExpenseTotal, 1_000, accuracy: 0.001)
        XCTAssertEqual(result.lowestExpectedBalance, 9_000, accuracy: 0.001)
        XCTAssertEqual(result.breakdown.datedObligationItems.count, 1)
        assertSameDay(result.breakdown.datedObligationItems.first?.date, startDate)
    }

    func testPastDueObligationBeforeForecastStartIsIgnoredByForecastEngine() {
        let accounts = [TestFixtures.cashAccount(balance: 10_000)]
        let pastDueBill = TestFixtures.futureObligation(
            title: "Past Due Bill",
            amount: 2_000,
            date: TestFixtures.date(year: 2026, month: 5, day: 31),
            categoryName: "Bills"
        )

        let result = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: [pastDueBill],
            monthlyBudgets: [],
            minimumSafeBalance: 0,
            from: startDate,
            targetDate: targetDate
        )

        XCTAssertEqual(result.breakdown.datedExpenseTotal, 0, accuracy: 0.001)
        XCTAssertTrue(result.breakdown.datedObligationItems.isEmpty)
        XCTAssertEqual(result.lowestExpectedBalance, 10_000, accuracy: 0.001)
    }

    func testMultipleFutureObligationsAreAppliedInChronologicalOrder() {
        let accounts = [TestFixtures.cashAccount(balance: 10_000)]
        let firstBill = TestFixtures.futureObligation(
            title: "First Bill",
            amount: 1_000,
            date: TestFixtures.date(year: 2026, month: 6, day: 10),
            categoryName: "Bills"
        )
        let secondBill = TestFixtures.futureObligation(
            title: "Second Bill",
            amount: 3_000,
            date: TestFixtures.date(year: 2026, month: 6, day: 20),
            categoryName: "Bills"
        )

        let result = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: [secondBill, firstBill],
            monthlyBudgets: [],
            minimumSafeBalance: 0,
            from: startDate,
            targetDate: targetDate
        )

        XCTAssertEqual(result.breakdown.datedExpenseTotal, 4_000, accuracy: 0.001)
        XCTAssertEqual(result.lowestExpectedBalance, 6_000, accuracy: 0.001)
        XCTAssertEqual(result.breakdown.datedObligationItems.map(\.title), ["First Bill", "Second Bill"])
    }

    func testCashShortageDateIsProducedWhenKnownObligationPushesCashBelowZero() {
        let accounts = [TestFixtures.cashAccount(balance: 3_000)]
        let largeBill = TestFixtures.futureObligation(
            title: "Large Bill",
            amount: 5_000,
            date: TestFixtures.date(year: 2026, month: 6, day: 10),
            categoryName: "Bills"
        )

        let result = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: [largeBill],
            monthlyBudgets: [],
            minimumSafeBalance: 0,
            from: startDate,
            targetDate: targetDate
        )

        XCTAssertEqual(result.lowestExpectedBalance, -2_000, accuracy: 0.001)
        XCTAssertNotNil(result.cashShortageDate)
        assertSameDay(result.cashShortageDate, TestFixtures.date(year: 2026, month: 6, day: 10))
    }

    func testDangerDateIsProducedWhenCashFallsBelowSafeTargetButNotBelowZero() {
        let accounts = [TestFixtures.cashAccount(balance: 10_000)]
        let bill = TestFixtures.futureObligation(
            title: "Safety Target Bill",
            amount: 6_000,
            date: TestFixtures.date(year: 2026, month: 6, day: 10),
            categoryName: "Bills"
        )

        let result = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: [bill],
            monthlyBudgets: [],
            minimumSafeBalance: 5_000,
            from: startDate,
            targetDate: targetDate
        )

        XCTAssertEqual(result.lowestExpectedBalance, 4_000, accuracy: 0.001)
        XCTAssertNotNil(result.dangerDate)
        XCTAssertNil(result.cashShortageDate)
        assertSameDay(result.dangerDate, TestFixtures.date(year: 2026, month: 6, day: 10))
    }

    func testNoFutureEventsAndNoLivingBurnRemainSafeInBasicRunway() {
        let accounts = [TestFixtures.cashAccount(balance: 10_000)]

        let result = ForecastEngine.calculateRunway(
            accounts: accounts,
            financialEvents: [],
            monthlyLivingBurn: 0,
            from: startDate
        )

        XCTAssertEqual(result.availableCash, 10_000, accuracy: 0.001)
        XCTAssertEqual(result.requiredUntilNextIncome, 0, accuracy: 0.001)
        XCTAssertEqual(result.safetyBuffer, 10_000, accuracy: 0.001)
        XCTAssertTrue(result.isSafe)
        XCTAssertNil(result.nextIncomeDate)
    }

    func testFutureIncomeAndFutureObligationTogetherProduceExpectedRunwayResult() {
        let accounts = [TestFixtures.cashAccount(balance: 10_000)]
        let bill = TestFixtures.futureObligation(
            title: "Bill Before Salary",
            amount: 5_000,
            date: TestFixtures.date(year: 2026, month: 6, day: 10),
            categoryName: "Bills"
        )
        let salary = TestFixtures.futureIncome(
            title: "Future Salary",
            amount: 7_000,
            date: TestFixtures.date(year: 2026, month: 6, day: 15)
        )

        let result = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: [bill, salary],
            monthlyBudgets: [],
            minimumSafeBalance: 0,
            from: startDate,
            targetDate: targetDate
        )

        XCTAssertEqual(result.breakdown.datedExpenseTotal, 5_000, accuracy: 0.001)
        XCTAssertEqual(result.breakdown.futureCashInflowTotal, 7_000, accuracy: 0.001)
        XCTAssertEqual(result.lowestExpectedBalance, 5_000, accuracy: 0.001)
        XCTAssertEqual(result.bufferAtTarget, 12_000, accuracy: 0.001)
        XCTAssertEqual(result.nextCashInflow?.amount ?? 0, 7_000, accuracy: 0.001)
    }

    func testVariableRecurringIncomeUsesMonthlyAmountsAndSkipsEmptyMonth() {
        let accounts = [TestFixtures.cashAccount(balance: 10_000)]
        let salary = TestFixtures.variableRecurringIncome(
            title: "Variable Salary",
            startDate: TestFixtures.date(year: 2026, month: 6, day: 25),
            overrides: [
                RecurringScheduleOverride(year: 2026, month: 6, amount: 100_000),
                RecurringScheduleOverride(year: 2026, month: 7, amount: 80_000),
                RecurringScheduleOverride(year: 2026, month: 8, amount: 120_000),
                RecurringScheduleOverride(year: 2026, month: 9, amount: 0, isSkipped: true)
            ]
        )

        let result = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: [salary],
            monthlyBudgets: [],
            minimumSafeBalance: 0,
            from: startDate,
            targetDate: TestFixtures.date(year: 2026, month: 9, day: 30)
        )

        let inflows = result.breakdown.futureCashInflowItems
        XCTAssertEqual(inflows.map(\.amount), [100_000, 80_000, 120_000])
        XCTAssertEqual(inflows.map(\.title), ["Variable Salary", "Variable Salary", "Variable Salary"])
        XCTAssertFalse(inflows.contains { Calendar.current.component(.month, from: $0.date) == 9 })
        XCTAssertEqual(result.availableCash, 10_000, accuracy: 0.001)
    }

    func testVariableRecurringIncomeFutureOverridesAppearWhenCurrentMonthHasNoAmount() {
        let accounts = [TestFixtures.cashAccount(balance: 10_000)]
        let salary = TestFixtures.variableRecurringIncome(
            title: "Variable Salary",
            startDate: TestFixtures.date(year: 2026, month: 6, day: 25),
            overrides: [
                RecurringScheduleOverride(year: 2026, month: 8, amount: 5_000),
                RecurringScheduleOverride(year: 2026, month: 9, amount: 5_000),
                RecurringScheduleOverride(year: 2026, month: 10, amount: 5_000)
            ]
        )
        let start = TestFixtures.date(year: 2026, month: 6, day: 1)
        let target = TestFixtures.date(year: 2026, month: 10, day: 31)

        let result = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: [salary],
            monthlyBudgets: [],
            minimumSafeBalance: 0,
            from: start,
            targetDate: target
        )
        let projectionPoints = ForecastEngine.calculateRunwayProjectionPoints(
            accounts: accounts,
            financialEvents: [salary],
            monthlyBudgets: [],
            from: start,
            targetDate: target
        )

        XCTAssertEqual(result.breakdown.futureCashInflowItems.map(\.amount), [5_000, 5_000, 5_000])
        XCTAssertEqual(
            result.breakdown.futureCashInflowItems.map { Calendar.current.component(.month, from: $0.date) },
            [8, 9, 10]
        )
        XCTAssertEqual(result.breakdown.futureCashInflowTotal, 15_000, accuracy: 0.001)
        XCTAssertEqual(result.availableCash, 10_000, accuracy: 0.001)
        XCTAssertEqual(balance(on: TestFixtures.date(year: 2026, month: 8, day: 25), in: projectionPoints), 15_000, accuracy: 0.001)
        XCTAssertEqual(balance(on: TestFixtures.date(year: 2026, month: 9, day: 25), in: projectionPoints), 20_000, accuracy: 0.001)
        XCTAssertEqual(balance(on: TestFixtures.date(year: 2026, month: 10, day: 25), in: projectionPoints), 25_000, accuracy: 0.001)
    }

    func testPaidRecurringIncomeOccurrenceDoesNotRemoveFutureMonths() {
        let accounts = [TestFixtures.cashAccount(balance: 10_000)]
        let seriesID = UUID()
        let salary = TestFixtures.variableRecurringIncome(
            id: seriesID,
            title: "Variable Salary",
            startDate: TestFixtures.date(year: 2026, month: 6, day: 25),
            overrides: [
                RecurringScheduleOverride(year: 2026, month: 6, amount: 100_000),
                RecurringScheduleOverride(year: 2026, month: 7, amount: 80_000),
                RecurringScheduleOverride(year: 2026, month: 8, amount: 120_000)
            ]
        )
        let paidJune = FinancialEvent(
            type: .income,
            status: .paid,
            title: "Variable Salary",
            amount: 100_000,
            date: TestFixtures.date(year: 2026, month: 6, day: 25),
            accountName: "Cash",
            incomeType: .salary,
            sourceRecurringEventID: seriesID,
            recurringOccurrenceYear: 2026,
            recurringOccurrenceMonth: 6
        )

        let result = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: [salary, paidJune],
            monthlyBudgets: [],
            minimumSafeBalance: 0,
            from: startDate,
            targetDate: TestFixtures.date(year: 2026, month: 8, day: 31)
        )

        XCTAssertEqual(result.availableCash, 10_000, accuracy: 0.001)
        XCTAssertEqual(result.breakdown.futureCashInflowItems.map(\.amount), [80_000, 120_000])
    }

    func testPlanIncompleteIsReportedWhenMonthlyBudgetDataIsMissing() {
        let accounts = [TestFixtures.cashAccount(balance: 10_000)]

        let result = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: [],
            monthlyBudgets: [],
            minimumSafeBalance: 0,
            from: startDate,
            targetDate: targetDate
        )

        XCTAssertEqual(result.status, .planIncomplete)
        XCTAssertNotNil(result.planIncompleteAfter)
        assertSameDay(result.planIncompleteAfter, startDate)
    }

    private func assertSameDay(
        _ actual: Date?,
        _ expected: Date,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("Expected a date, got nil", file: file, line: line)
            return
        }

        let calendar = Calendar.current
        XCTAssertEqual(
            calendar.dateComponents([.year, .month, .day], from: actual),
            calendar.dateComponents([.year, .month, .day], from: expected),
            file: file,
            line: line
        )
    }

    private func balance(on date: Date, in points: [RunwayProjectionPoint]) -> Double {
        points.first { Calendar.current.isDate($0.date, inSameDayAs: date) }?.balance ?? .nan
    }
}

private enum TestFixtures {

    static func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day

        return components.date!
    }

    static func cashAccount(balance: Double) -> Account {
        Account(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Cash",
            balance: balance,
            type: .cash,
            isActive: true
        )
    }

    static func futureIncome(title: String, amount: Double, date: Date) -> FinancialEvent {
        FinancialEvent(
            type: .income,
            status: .expected,
            title: title,
            amount: amount,
            date: date,
            accountName: "Cash",
            incomeType: .salary
        )
    }

    static func variableRecurringIncome(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        overrides: [RecurringScheduleOverride]
    ) -> FinancialEvent {
        FinancialEvent(
            id: id,
            type: .income,
            status: .expected,
            title: title,
            amount: overrides.first(where: { !$0.isSkipped && $0.amount > 0 })?.amount ?? 0,
            date: startDate,
            accountName: "Cash",
            incomeType: .salary,
            repeatRule: .monthly,
            recurringScheduleOverrides: overrides,
            recurringAmountMode: .variableEachMonth
        )
    }

    static func futureObligation(
        title: String,
        amount: Double,
        date: Date,
        categoryName: String
    ) -> FinancialEvent {
        FinancialEvent(
            type: .obligation,
            status: .unpaid,
            title: title,
            amount: amount,
            date: date,
            accountName: "Cash",
            categoryName: categoryName
        )
    }

    static func monthlyBudget(
        year: Int,
        month: Int,
        categoryName: String,
        plannedAmount: Double
    ) -> WalletMonthlyBudget {
        WalletMonthlyBudget(
            year: year,
            month: month,
            items: [
                WalletMonthlyBudgetItem(
                    categoryName: categoryName,
                    plannedAmount: plannedAmount
                )
            ]
        )
    }
}
