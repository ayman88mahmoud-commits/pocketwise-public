import XCTest
@testable import PocketWise

final class DemoBackupFixtureTests: XCTestCase {

    private var suiteNames: [String] = []

    override func tearDown() {
        for suiteName in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        suiteNames.removeAll()
        super.tearDown()
    }

    func testDemoBackupFixtureDecodesAndImports() throws {
        let store = try importDemoFixture()

        XCTAssertEqual(store.accounts.count, 5)
        XCTAssertEqual(store.categories.count, 24)
        XCTAssertEqual(store.financialEvents.count, 27)
        XCTAssertEqual(store.monthlyBudgets.count, 3)
        XCTAssertEqual(store.creditCards.count, 1)
        XCTAssertEqual(store.creditCardPurchases.count, 3)
        XCTAssertEqual(store.creditCardPayments.count, 1)
        XCTAssertEqual(store.personDebts.count, 2)
        XCTAssertEqual(store.personDebtEntries.count, 2)
        XCTAssertEqual(installmentLinkedEvents(in: store.financialEvents).count, 6)
        XCTAssertTrue(hasMonthlyBudget(year: 2026, month: 6, in: store.monthlyBudgets))
        XCTAssertTrue(hasMonthlyBudget(year: 2026, month: 7, in: store.monthlyBudgets))
        XCTAssertTrue(hasMonthlyBudget(year: 2026, month: 8, in: store.monthlyBudgets))
    }

    func testDemoBackupFixtureContainsExpectedIncomePlanningScenarios() throws {
        let snapshot = try loadDemoSnapshot()
        let incomeEvents = snapshot.financialEvents.filter { $0.type == .income }
        let variableSalary = try XCTUnwrap(
            incomeEvents.first { $0.title == "Demo Employer Variable Salary" }
        )

        XCTAssertTrue(incomeEvents.contains { $0.title == "Demo Employer Salary" && $0.status == .paid })
        XCTAssertTrue(incomeEvents.contains { $0.title == "Demo Employer Expected Salary" && $0.status == .expected })
        XCTAssertTrue(incomeEvents.contains { $0.title == "Demo Retainer" && $0.repeatRule == .monthly })
        XCTAssertEqual(variableSalary.repeatRule, .monthly)
        XCTAssertEqual(variableSalary.effectiveRecurringAmountMode, .variableEachMonth)
        XCTAssertEqual(variableSalary.recurringScheduleOverrides?.filter { !$0.isSkipped }.count, 3)
        XCTAssertEqual(variableSalary.recurringScheduleOverrides?.filter(\.isSkipped).count, 1)

        let recurringRuleIDs = Set(incomeEvents.filter { $0.repeatRule != .none }.map(\.id))
        let paidRecurringOccurrence = try XCTUnwrap(
            incomeEvents.first { $0.title == "Demo Employer Variable Salary - August Received" }
        )

        XCTAssertEqual(paidRecurringOccurrence.status, .paid)
        XCTAssertEqual(paidRecurringOccurrence.recurringOccurrenceYear, 2026)
        XCTAssertEqual(paidRecurringOccurrence.recurringOccurrenceMonth, 8)
        XCTAssertTrue(recurringRuleIDs.contains(try XCTUnwrap(paidRecurringOccurrence.sourceRecurringEventID)))
    }

    func testDemoBackupFixtureDoesNotCountExpectedIncomeInRealBalances() throws {
        let store = try importDemoFixture()
        let accountBalanceTotal = store.accounts.map(\.balance).reduce(0, +)
        let expectedIncomeTotal = store.financialEvents
            .filter { $0.type == .income && $0.status == .expected }
            .map(\.amount)
            .reduce(0, +)

        XCTAssertGreaterThan(expectedIncomeTotal, 0)
        XCTAssertEqual(store.availableCash, accountBalanceTotal, accuracy: 0.001)
        XCTAssertLessThan(store.availableCash, accountBalanceTotal + expectedIncomeTotal)
    }

    func testDemoBackupFixtureHasValidCreditCardAndInstallmentReferences() throws {
        let snapshot = try loadDemoSnapshot()
        let cardIDs = Set(snapshot.creditCards.map(\.id))
        let installmentPlanIDs = Set(snapshot.installmentPlans.map(\.id))

        XCTAssertFalse(cardIDs.isEmpty)
        XCTAssertTrue(snapshot.creditCardPurchases.allSatisfy { cardIDs.contains($0.cardID) })
        XCTAssertTrue(snapshot.creditCardPayments.allSatisfy { cardIDs.contains($0.cardID) })
        XCTAssertTrue(snapshot.installmentPlans.allSatisfy { plan in
            guard let linkedCreditCardID = plan.linkedCreditCardID else {
                return true
            }

            return cardIDs.contains(linkedCreditCardID)
        })
        XCTAssertTrue(snapshot.financialEvents.allSatisfy { event in
            guard let sourceInstallmentPlanID = event.sourceInstallmentPlanID else {
                return true
            }

            return installmentPlanIDs.contains(sourceInstallmentPlanID)
        })
        XCTAssertEqual(installmentLinkedEvents(in: snapshot.financialEvents).count, 6)
    }

    private func importDemoFixture() throws -> WalletStore {
        let defaults = makeIsolatedUserDefaults()
        let store = WalletStore(userDefaults: defaults)
        try store.importBackupSnapshotFromJSON(loadDemoFixtureData())
        return store
    }

    private func loadDemoSnapshot() throws -> WalletDataSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WalletDataSnapshot.self, from: loadDemoFixtureData())
    }

    private func loadDemoFixtureData() throws -> Data {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/PocketWise-Demo-Household-TestData.json")
        return try Data(contentsOf: fixtureURL)
    }

    private func hasMonthlyBudget(
        year: Int,
        month: Int,
        in budgets: [WalletMonthlyBudget]
    ) -> Bool {
        budgets.contains { $0.year == year && $0.month == month }
    }

    private func installmentLinkedEvents(in events: [FinancialEvent]) -> [FinancialEvent] {
        events.filter {
            $0.sourceInstallmentPlanID == UUID(uuidString: "55555555-5555-5555-5555-555555555501")
        }
    }

    private func makeIsolatedUserDefaults() -> UserDefaults {
        let suiteName = "DemoBackupFixtureTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults suite.")
            return .standard
        }

        defaults.removePersistentDomain(forName: suiteName)
        suiteNames.append(suiteName)
        return defaults
    }
}
