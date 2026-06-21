import Foundation

// MARK: - Forecast Breakdown

struct MonthlyForecastBreakdown: Identifiable, Hashable {
    var id = UUID()
    var monthStartDate: Date
    var incomeItems: [ForecastBreakdownItem]
    var fixedOutflowItems: [ForecastBreakdownItem]
    var expectedExpenseItems: [ForecastBreakdownItem]
    var flexibleSpendingAmount: Double

    var topItems: [ForecastBreakdownItem] {
        (incomeItems + fixedOutflowItems + expectedExpenseItems)
            .sorted { $0.amount > $1.amount }
    }
}

struct ForecastBreakdownItem: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var amount: Double
    var date: Date
    var type: FinancialEventType
    var repeatRule: RepeatRule
    var isProjected: Bool
}

enum RunwayCheckStatus: String, Codable, Hashable {
    case safe
    case notSafe
    case cashShortage
    case planIncomplete
}

enum CashInflowKind: String, Codable, Hashable {
    case salary
    case oneTimeCashInflow
    case reimbursement
    case expectedRepayment
    case transfer
    case loanOrDebt
    case unknown
}

struct RunwayCashInflow: Codable, Hashable {
    var title: String
    var amount: Double
    var date: Date
    var kind: CashInflowKind
}

struct RunwayBreakdownItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var amount: Double
    var date: Date
    var status: FinancialEventStatus
    var sourceType: String
    var categoryName: String?
    var subCategoryName: String?
}

struct RunwayBudgetBreakdownItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var year: Int
    var month: Int
    var categoryName: String
    var plannedAmount: Double
    var paidActualAmount: Double = 0
    var committedElsewhereAmount: Double = 0
    var remainingEstimateAmount: Double = 0
    var includedAmount: Double
    var coveredStart: Date
    var coveredEnd: Date
}

struct RunwayCheckBreakdown: Codable, Hashable {
    var futureCashInflowCount: Int
    var futureCashInflowTotal: Double
    var firstCashInflowDate: Date?
    var lastCashInflowDate: Date?
    var datedExpenseCount: Int
    var datedExpenseTotal: Double
    var firstDatedExpenseDate: Date?
    var lastDatedExpenseDate: Date?
    var recurringInstallmentCount: Int
    var recurringInstallmentTotal: Double
    var monthlyEstimateTotal: Double
    var futureCashInflowItems: [RunwayBreakdownItem] = []
    var datedObligationItems: [RunwayBreakdownItem] = []
    var recurringInstallmentItems: [RunwayBreakdownItem] = []
    var monthlyBudgetItems: [RunwayBudgetBreakdownItem] = []
    var monthlyBudgetCoveredElsewhereItems: [RunwayBudgetBreakdownItem] = []
}

struct RunwayCheckResult: Codable, Hashable {
    var availableCash: Double
    var targetDate: Date
    var calculationEndDate: Date
    var minimumSafeBalance: Double
    var status: RunwayCheckStatus
    var lowestExpectedBalance: Double
    var lowestBalanceDate: Date
    var dangerDate: Date?
    var dangerBalance: Double?
    var cashShortageDate: Date?
    var cashShortageBalance: Double?
    var shortfallToStaySafe: Double
    var nextCashInflow: RunwayCashInflow?
    var planIncompleteAfter: Date?
    var bufferAtTarget: Double
    var breakdown: RunwayCheckBreakdown
}

struct RunwayProjectionPoint: Identifiable, Hashable {
    var id: Date { date }
    var date: Date
    var balance: Double
}

// MARK: - Forecast Engine

struct ForecastEngine {

    // MARK: - Projected Event

    private struct ProjectedCashEvent {
        let title: String
        let type: FinancialEventType
        let amount: Double
        let date: Date
        let status: FinancialEventStatus
        let repeatRule: RepeatRule
        let incomeType: IncomeType?
        let categoryName: String?
        let subCategoryName: String?
        let sourceID: UUID
        let isProjected: Bool
        let sourceTypeOverride: String?
    }

    // MARK: - Main Runway Calculation

    static func calculateRunway(
        accounts: [Account],
        financialEvents: [FinancialEvent],
        monthlyLivingBurn: Double,
        from startDate: Date = Date()
    ) -> FinancialRunwayResult {

        let availableCash = calculateAvailableCash(accounts: accounts)

        let projectedEvents = buildProjectedCashEvents(
            financialEvents: financialEvents,
            from: startDate,
            horizonDays: 730
        )

        let nextIncome = findNextIncome(
            projectedEvents: projectedEvents,
            from: startDate
        )

        let nextIncomeDate = nextIncome?.date

        let requiredUntilNextIncome = calculateRequiredOutflow(
            projectedEvents: projectedEvents,
            monthlyLivingBurn: monthlyLivingBurn,
            from: startDate,
            until: nextIncomeDate
        )

        let safetyBuffer = availableCash - requiredUntilNextIncome

        let trueSafeUntilDate = calculateTrueSafeUntilDate(
            availableCash: availableCash,
            projectedEvents: projectedEvents,
            monthlyLivingBurn: monthlyLivingBurn,
            from: startDate
        )

        return FinancialRunwayResult(
            availableCash: availableCash,
            requiredUntilNextIncome: requiredUntilNextIncome,
            safetyBuffer: safetyBuffer,
            safeUntilDate: trueSafeUntilDate,
            nextIncomeDate: nextIncomeDate,
            isSafe: safetyBuffer >= 0
        )
    }

    // MARK: - Available Cash

    static func calculateAvailableCash(accounts: [Account]) -> Double {
        accounts
            .filter { $0.isActive }
            .map { $0.balance }
            .reduce(0, +)
    }

    // MARK: - Target-Date Runway Check

    static func calculateRunwayCheck(
        accounts: [Account],
        financialEvents: [FinancialEvent],
        monthlyBudgets: [WalletMonthlyBudget],
        creditCardPurchases: [CreditCardPurchase] = [],
        creditCardDueItems: [CreditCardDueItem] = [],
        minimumSafeBalance: Double,
        from startDate: Date = Date(),
        targetDate: Date
    ) -> RunwayCheckResult {

        let availableCash = calculateAvailableCash(accounts: accounts)
        let start = startOfDay(startDate)
        let target = maxDate(startOfDay(targetDate), start)
        let calculationEnd = target
        let eventEndBoundary = calendarDayAfter(calculationEnd)
        let horizonDays = max(Calendar.current.dateComponents([.day], from: start, to: calculationEnd).day ?? 0, 0)

        let projectedEvents = buildProjectedCashEvents(
            financialEvents: financialEvents,
            from: start,
            horizonDays: max(horizonDays, 1)
        )
        + creditCardDueItems.map { dueItem in
            ProjectedCashEvent(
                title: "Credit Card Due - \(dueItem.cardName)",
                type: .obligation,
                amount: dueItem.dueAmount,
                date: startOfDay(dueItem.dueDate),
                status: .unpaid,
                repeatRule: .none,
                incomeType: nil,
                categoryName: "Credit Card Due",
                subCategoryName: dueItem.defaultPaymentAccountName.map { "Pay from \($0)" },
                sourceID: dueItem.cardID,
                isProjected: false,
                sourceTypeOverride: dueItem.statusLabel
            )
        }
        .filter { $0.date >= start && $0.date < eventEndBoundary }

        let eventsByDay = Dictionary(grouping: projectedEvents) { event in
            startOfDay(event.date)
        }

        let allMonthlyBudgetItems = plannedBudgetBreakdownItems(
            monthlyBudgets: monthlyBudgets,
            financialEvents: financialEvents,
            creditCardPurchases: creditCardPurchases,
            projectedEvents: projectedEvents,
            from: start,
            targetDate: calculationEnd
        )
        let monthlyBudgetItems = allMonthlyBudgetItems.filter { $0.includedAmount > 0 }
        let monthlyBudgetCoveredElsewhereItems = allMonthlyBudgetItems.filter { item in
            item.includedAmount <= 0 &&
            item.plannedAmount > 0 &&
            (item.paidActualAmount > 0 || item.committedElsewhereAmount > 0)
        }
        let plannedTopUpByDay = plannedBudgetTopUpByDay(monthlyBudgetItems: monthlyBudgetItems)
        let monthlyEstimateTotal = monthlyBudgetItems.map(\.includedAmount).reduce(0, +)
        let breakdown = runwayCheckBreakdown(
            projectedEvents: projectedEvents,
            monthlyEstimateTotal: monthlyEstimateTotal,
            monthlyBudgetItems: monthlyBudgetItems,
            monthlyBudgetCoveredElsewhereItems: monthlyBudgetCoveredElsewhereItems
        )

        var runningCash = availableCash
        var lowestBalance = availableCash
        var lowestDate = start
        var dangerDate: Date?
        var dangerBalance: Double?
        var shortageDate: Date?
        var shortageBalance: Double?

        for dayOffset in 0...horizonDays {
            guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: start) else {
                continue
            }

            let eventImpact = (eventsByDay[day] ?? [])
                .map { cashImpact($0.type, amount: $0.amount) }
                .reduce(0, +)

            runningCash += eventImpact
            runningCash -= plannedTopUpByDay[day] ?? 0

            if runningCash < lowestBalance {
                lowestBalance = runningCash
                lowestDate = day
            }

            if dangerDate == nil && runningCash < minimumSafeBalance {
                dangerDate = day
                dangerBalance = runningCash
            }

            if shortageDate == nil && runningCash < 0 {
                shortageDate = day
                shortageBalance = runningCash
            }
        }

        let incompleteMonth = firstIncompleteBudgetMonth(
            monthlyBudgets: monthlyBudgets,
            from: start,
            targetDate: calculationEnd
        )

        let nextCashInflow = projectedEvents
            .filter { $0.type == .income && $0.date >= start }
            .sorted { $0.date < $1.date }
            .first
            .map { event in
                RunwayCashInflow(
                    title: event.title,
                    amount: event.amount,
                    date: event.date,
                    kind: cashInflowKind(for: event)
                )
            }

        let status: RunwayCheckStatus
        if incompleteMonth != nil {
            status = .planIncomplete
        } else if shortageDate != nil {
            status = .cashShortage
        } else if dangerDate != nil {
            status = .notSafe
        } else {
            status = .safe
        }

        return RunwayCheckResult(
            availableCash: availableCash,
            targetDate: target,
            calculationEndDate: calculationEnd,
            minimumSafeBalance: minimumSafeBalance,
            status: status,
            lowestExpectedBalance: lowestBalance,
            lowestBalanceDate: lowestDate,
            dangerDate: dangerDate,
            dangerBalance: dangerBalance,
            cashShortageDate: shortageDate,
            cashShortageBalance: shortageBalance,
            shortfallToStaySafe: max(0, minimumSafeBalance - lowestBalance),
            nextCashInflow: nextCashInflow,
            planIncompleteAfter: incompleteMonth,
            bufferAtTarget: runningCash - minimumSafeBalance,
            breakdown: breakdown
        )
    }

    static func calculateRunwayProjectionPoints(
        accounts: [Account],
        financialEvents: [FinancialEvent],
        monthlyBudgets: [WalletMonthlyBudget],
        creditCardPurchases: [CreditCardPurchase] = [],
        creditCardDueItems: [CreditCardDueItem] = [],
        from startDate: Date = Date(),
        targetDate: Date
    ) -> [RunwayProjectionPoint] {

        let availableCash = calculateAvailableCash(accounts: accounts)
        let start = startOfDay(startDate)
        let target = maxDate(startOfDay(targetDate), start)
        let calculationEnd = target
        let eventEndBoundary = calendarDayAfter(calculationEnd)
        let horizonDays = max(Calendar.current.dateComponents([.day], from: start, to: calculationEnd).day ?? 0, 0)

        let projectedEvents = buildProjectedCashEvents(
            financialEvents: financialEvents,
            from: start,
            horizonDays: max(horizonDays, 1)
        )
        + creditCardDueItems.map { dueItem in
            ProjectedCashEvent(
                title: "Credit Card Due - \(dueItem.cardName)",
                type: .obligation,
                amount: dueItem.dueAmount,
                date: startOfDay(dueItem.dueDate),
                status: .unpaid,
                repeatRule: .none,
                incomeType: nil,
                categoryName: "Credit Card Due",
                subCategoryName: dueItem.defaultPaymentAccountName.map { "Pay from \($0)" },
                sourceID: dueItem.cardID,
                isProjected: false,
                sourceTypeOverride: dueItem.statusLabel
            )
        }
        .filter { $0.date >= start && $0.date < eventEndBoundary }

        let eventsByDay = Dictionary(grouping: projectedEvents) { event in
            startOfDay(event.date)
        }

        let monthlyBudgetItems = plannedBudgetBreakdownItems(
            monthlyBudgets: monthlyBudgets,
            financialEvents: financialEvents,
            creditCardPurchases: creditCardPurchases,
            projectedEvents: projectedEvents,
            from: start,
            targetDate: calculationEnd
        )
        .filter { $0.includedAmount > 0 }

        let plannedTopUpByDay = plannedBudgetTopUpByDay(monthlyBudgetItems: monthlyBudgetItems)

        var runningCash = availableCash
        var points: [RunwayProjectionPoint] = [
            RunwayProjectionPoint(date: start, balance: availableCash)
        ]

        for dayOffset in 0...horizonDays {
            guard let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: start) else {
                continue
            }

            let eventImpact = (eventsByDay[day] ?? [])
                .map { cashImpact($0.type, amount: $0.amount) }
                .reduce(0, +)

            runningCash += eventImpact
            runningCash -= plannedTopUpByDay[day] ?? 0

            if dayOffset == 0 {
                points[0] = RunwayProjectionPoint(date: day, balance: min(availableCash, runningCash))
            } else {
                points.append(RunwayProjectionPoint(date: day, balance: runningCash))
            }
        }

        return points
    }

    // MARK: - Project Future Events

    private static func buildProjectedCashEvents(
        financialEvents: [FinancialEvent],
        from startDate: Date,
        horizonDays: Int
    ) -> [ProjectedCashEvent] {

        let calendar = Calendar.current
        let start = startOfDay(startDate)

        guard let horizonEnd = calendar.date(
            byAdding: .day,
            value: horizonDays,
            to: start
        ) else {
            return []
        }

        var projectedEvents: [ProjectedCashEvent] = []

        for event in financialEvents {
            guard event.status != .cancelled else {
                continue
            }

            guard event.status != .skipped else {
                continue
            }

            guard isCashImpactEvent(event.type) else {
                continue
            }

            // 1. Add the original event if it is still future and planned/expected/unpaid.
            if event.date >= start &&
                isFutureProjectionStatus(event.status) &&
                recurringOccurrenceIsAllowed(event, occurrenceDate: event.date, occurrenceNumber: 1) &&
                !event.isRecurringOccurrenceSkipped(on: event.date) &&
                !paidRecurringOccurrenceExists(sourceID: event.id, occurrenceDate: event.date, financialEvents: financialEvents) {
                let projectedAmount = event.recurringAmount(for: event.date)
                if projectedAmount > 0 {
                    projectedEvents.append(
                        ProjectedCashEvent(
                            title: event.title,
                            type: event.type,
                            amount: projectedAmount,
                            date: startOfDay(event.date),
                            status: event.status,
                            repeatRule: event.repeatRule,
                            incomeType: event.incomeType,
                            categoryName: event.categoryName,
                            subCategoryName: event.subCategoryName,
                            sourceID: event.id,
                            isProjected: false,
                            sourceTypeOverride: nil
                        )
                    )
                }
            }

            // 2. Generate future repeated occurrences.
            // Important:
            // Even if the current month was paid, the next months must still exist.
            if event.repeatRule != .none {
                let repeatedDates = generateRepeatedDates(
                    event: event,
                    startDate: start,
                    horizonEnd: horizonEnd
                )

                for repeatedDate in repeatedDates {
                    if !paidRecurringOccurrenceExists(sourceID: event.id, occurrenceDate: repeatedDate, financialEvents: financialEvents) {
                        let projectedAmount = event.recurringAmount(for: repeatedDate)
                        guard projectedAmount > 0 else {
                            continue
                        }

                        projectedEvents.append(
                            ProjectedCashEvent(
                                title: event.title,
                                type: event.type,
                                amount: projectedAmount,
                                date: startOfDay(repeatedDate),
                                status: projectedStatus(for: event),
                                repeatRule: event.repeatRule,
                                incomeType: event.incomeType,
                                categoryName: event.categoryName,
                                subCategoryName: event.subCategoryName,
                                sourceID: event.id,
                                isProjected: true,
                                sourceTypeOverride: nil
                            )
                        )
                    }
                }
            }
        }

        return projectedEvents
            .sorted { $0.date < $1.date }
    }

    private static func generateRepeatedDates(
        event: FinancialEvent,
        startDate: Date,
        horizonEnd: Date
    ) -> [Date] {

        guard event.repeatRule != .none else {
            return []
        }

        let calendar = Calendar.current
        let originalDay = calendar.component(.day, from: event.date)

        var dates: [Date] = []
        var currentDate = event.date
        var occurrenceNumber = 1

        while currentDate <= horizonEnd {
            guard let nextDate = nextOccurrenceDate(
                after: currentDate,
                repeatRule: event.repeatRule,
                originalDay: originalDay
            ) else {
                break
            }

            currentDate = nextDate
            occurrenceNumber += 1

            if currentDate > horizonEnd {
                break
            }

            guard event.allowsRecurringOccurrence(
                on: currentDate,
                occurrenceNumber: occurrenceNumber
            ) else {
                if event.effectiveRecurringEndKind != .never {
                    break
                }

                continue
            }

            if event.isRecurringOccurrenceSkipped(on: currentDate) {
                continue
            }

            if currentDate >= startDate {
                dates.append(currentDate)
            }
        }

        return dates
    }

    private static func recurringOccurrenceIsAllowed(
        _ event: FinancialEvent,
        occurrenceDate: Date,
        occurrenceNumber: Int
    ) -> Bool {

        event.allowsRecurringOccurrence(
            on: occurrenceDate,
            occurrenceNumber: occurrenceNumber
        )
    }

    private static func paidRecurringOccurrenceExists(sourceID: UUID, occurrenceDate: Date, financialEvents: [FinancialEvent]) -> Bool {
        let components = Calendar.current.dateComponents([.year, .month], from: occurrenceDate)
        guard let year = components.year,
              let month = components.month else {
            return false
        }

        return financialEvents.contains { event in
            event.status == .paid &&
            event.sourceRecurringEventID == sourceID &&
            event.recurringOccurrenceYear == year &&
            event.recurringOccurrenceMonth == month
        }
    }

    private static func nextOccurrenceDate(
        after date: Date,
        repeatRule: RepeatRule,
        originalDay: Int
    ) -> Date? {

        let calendar = Calendar.current

        switch repeatRule {
        case .none:
            return nil

        case .monthly:
            return addMonthsPreservingDay(
                to: date,
                months: 1,
                preferredDay: originalDay
            )

        case .quarterly:
            return addMonthsPreservingDay(
                to: date,
                months: 3,
                preferredDay: originalDay
            )

        case .yearly:
            return calendar.date(
                byAdding: .year,
                value: 1,
                to: date
            )
        }
    }

    private static func addMonthsPreservingDay(
        to date: Date,
        months: Int,
        preferredDay: Int
    ) -> Date? {

        let calendar = Calendar.current

        guard let roughDate = calendar.date(
            byAdding: .month,
            value: months,
            to: date
        ) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month], from: roughDate)

        guard let year = components.year,
              let month = components.month else {
            return roughDate
        }

        let daysInTargetMonth = calendar.range(
            of: .day,
            in: .month,
            for: roughDate
        )?.count ?? preferredDay

        components.year = year
        components.month = month
        components.day = min(preferredDay, daysInTargetMonth)

        return calendar.date(from: components)
    }

    private static func projectedStatus(for event: FinancialEvent) -> FinancialEventStatus {
        switch event.type {
        case .income:
            return .expected

        case .expense, .obligation, .expectedExpense, .installment:
            return .unpaid

        case .transfer:
            return .paid
        }
    }

    // MARK: - Next Income

    private static func findNextIncome(
        projectedEvents: [ProjectedCashEvent],
        from startDate: Date = Date()
    ) -> ProjectedCashEvent? {

        projectedEvents
            .filter { event in
                event.type == .income &&
                event.date >= startOfDay(startDate)
            }
            .sorted { $0.date < $1.date }
            .first
    }

    // MARK: - Required Until Next Income

    private static func calculateRequiredOutflow(
        projectedEvents: [ProjectedCashEvent],
        monthlyLivingBurn: Double,
        from startDate: Date = Date(),
        until endDate: Date?
    ) -> Double {

        let futureOutflows = projectedEvents
            .filter { event in
                isOutflow(event.type) &&
                event.date >= startOfDay(startDate) &&
                isBeforeOrEqual(event.date, endDate)
            }
            .map { $0.amount }
            .reduce(0, +)

        let burn = flexibleSpendingAmount(
            monthlyEstimate: monthlyLivingBurn,
            from: startDate,
            until: endDate
        )

        return futureOutflows + burn
    }

    // MARK: - Legacy Zero-Cash Date

    private static func calculateTrueSafeUntilDate(
        availableCash: Double,
        projectedEvents: [ProjectedCashEvent],
        monthlyLivingBurn: Double,
        from startDate: Date = Date(),
        horizonDays: Int = 730
    ) -> Date? {

        let calendar = Calendar.current
        let start = startOfDay(startDate)
        let dailyFlexibleSpending = max(monthlyLivingBurn, 0) / 30

        if availableCash <= 0 {
            return start
        }

        let eventsByDay = Dictionary(grouping: projectedEvents) { event in
            startOfDay(event.date)
        }

        var runningCash = availableCash
        var lastSafeDate = start

        for dayOffset in 0...horizonDays {
            guard let currentDay = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: start
            ) else {
                continue
            }

            let eventsForDay = eventsByDay[currentDay] ?? []

            let dayEventImpact = eventsForDay
                .map { cashImpact($0.type, amount: $0.amount) }
                .reduce(0, +)

            runningCash += dayEventImpact

            if dailyFlexibleSpending > 0 {
                runningCash -= dailyFlexibleSpending
            }

            if runningCash < 0 {
                let previousDay = calendar.date(
                    byAdding: .day,
                    value: -1,
                    to: currentDay
                ) ?? lastSafeDate

                return previousDay < start ? start : previousDay
            }

            if runningCash == 0 {
                return currentDay
            }

            lastSafeDate = currentDay
        }

        return nil
    }

    private static func plannedBudgetTopUpByDay(
        monthlyBudgetItems: [RunwayBudgetBreakdownItem]
    ) -> [Date: Double] {
        let calendar = Calendar.current
        var result: [Date: Double] = [:]

        for item in monthlyBudgetItems {
            let activeDays = inclusiveDayCount(from: item.coveredStart, through: item.coveredEnd)
            let dailyTopUp = activeDays > 0 ? item.includedAmount / Double(activeDays) : 0

            if dailyTopUp > 0 {
                for dayOffset in 0..<activeDays {
                    if let day = calendar.date(byAdding: .day, value: dayOffset, to: item.coveredStart) {
                        let key = startOfDay(day)
                        result[key, default: 0] += dailyTopUp
                    }
                }
            }
        }

        return result
    }

    private static func plannedBudgetBreakdownItems(
        monthlyBudgets: [WalletMonthlyBudget],
        financialEvents: [FinancialEvent],
        creditCardPurchases: [CreditCardPurchase],
        projectedEvents: [ProjectedCashEvent],
        from startDate: Date,
        targetDate: Date
    ) -> [RunwayBudgetBreakdownItem] {
        let calendar = Calendar.current
        let start = startOfDay(startDate)
        let target = startOfDay(targetDate)
        let budgetsByMonth = Dictionary(uniqueKeysWithValues: monthlyBudgets.map { budget in
            ("\(budget.year)-\(budget.month)", budget)
        })
        let paidActualsByMonthCategory = paidActualsByMonthCategory(
            financialEvents: financialEvents,
            creditCardPurchases: creditCardPurchases
        )
        let committedByMonthCategory = committedElsewhereByMonthCategory(projectedEvents: projectedEvents)

        var items: [RunwayBudgetBreakdownItem] = []
        var monthCursor = startOfMonth(start)

        while monthCursor <= target {
            let components = calendar.dateComponents([.year, .month], from: monthCursor)
            let year = components.year ?? 0
            let month = components.month ?? 0
            let monthID = "\(year)-\(month)"
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthCursor) ?? monthCursor
            let rangeStart = maxDate(monthCursor, start)
            let lastCoveredDay = minDate(
                calendar.date(byAdding: .day, value: -1, to: monthEnd) ?? monthCursor,
                target
            )

            for budgetItem in budgetsByMonth[monthID]?.items ?? [] {
                let plannedAmount = max(budgetItem.plannedAmount, 0)
                let categoryName = budgetItem.categoryName
                let paidActualAmount = paidActualsByMonthCategory[monthID]?[categoryName] ?? 0
                let committedElsewhereAmount = committedByMonthCategory[monthID]?[categoryName] ?? 0
                let remainingEstimateAmount = max(0, plannedAmount - paidActualAmount - committedElsewhereAmount)
                let includedAmount = includedFlexibleAmount(
                    remainingEstimateAmount: remainingEstimateAmount,
                    monthStart: monthCursor,
                    monthEnd: monthEnd,
                    coveredStart: rangeStart,
                    coveredEnd: lastCoveredDay
                )

                guard plannedAmount > 0 || paidActualAmount > 0 || committedElsewhereAmount > 0 else {
                    continue
                }

                items.append(
                    RunwayBudgetBreakdownItem(
                        year: year,
                        month: month,
                        categoryName: categoryName,
                        plannedAmount: plannedAmount,
                        paidActualAmount: paidActualAmount,
                        committedElsewhereAmount: committedElsewhereAmount,
                        remainingEstimateAmount: remainingEstimateAmount,
                        includedAmount: includedAmount,
                        coveredStart: rangeStart,
                        coveredEnd: lastCoveredDay
                    )
                )
            }

            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthCursor) else {
                break
            }
            monthCursor = nextMonth
        }

        return items
    }

    private static func runwayCheckBreakdown(
        projectedEvents: [ProjectedCashEvent],
        monthlyEstimateTotal: Double,
        monthlyBudgetItems: [RunwayBudgetBreakdownItem],
        monthlyBudgetCoveredElsewhereItems: [RunwayBudgetBreakdownItem]
    ) -> RunwayCheckBreakdown {
        let inflows = projectedEvents
            .filter { $0.type == .income }
            .sorted { $0.date < $1.date }

        let outflows = projectedEvents
            .filter { isOutflow($0.type) }
            .sorted { $0.date < $1.date }

        let recurringInstallments = outflows
            .filter { $0.type == .installment || $0.repeatRule != .none || $0.isProjected }

        let datedOnlyOutflows = outflows
            .filter { $0.type != .installment && $0.repeatRule == .none && !$0.isProjected }

        return RunwayCheckBreakdown(
            futureCashInflowCount: inflows.count,
            futureCashInflowTotal: inflows.map(\.amount).reduce(0, +),
            firstCashInflowDate: inflows.first?.date,
            lastCashInflowDate: inflows.last?.date,
            datedExpenseCount: datedOnlyOutflows.count,
            datedExpenseTotal: datedOnlyOutflows.map(\.amount).reduce(0, +),
            firstDatedExpenseDate: datedOnlyOutflows.first?.date,
            lastDatedExpenseDate: datedOnlyOutflows.last?.date,
            recurringInstallmentCount: recurringInstallments.count,
            recurringInstallmentTotal: recurringInstallments.map(\.amount).reduce(0, +),
            monthlyEstimateTotal: monthlyEstimateTotal,
            futureCashInflowItems: inflows.map(makeRunwayBreakdownItem),
            datedObligationItems: datedOnlyOutflows.map(makeRunwayBreakdownItem),
            recurringInstallmentItems: recurringInstallments.map(makeRunwayBreakdownItem),
            monthlyBudgetItems: monthlyBudgetItems,
            monthlyBudgetCoveredElsewhereItems: monthlyBudgetCoveredElsewhereItems
        )
    }

    nonisolated private static func makeRunwayBreakdownItem(from event: ProjectedCashEvent) -> RunwayBreakdownItem {
        RunwayBreakdownItem(
            title: event.title,
            amount: event.amount,
            date: event.date,
            status: event.status,
            sourceType: runwaySourceType(for: event),
            categoryName: event.categoryName,
            subCategoryName: event.subCategoryName
        )
    }

    nonisolated private static func runwaySourceType(for event: ProjectedCashEvent) -> String {
        if let sourceTypeOverride = event.sourceTypeOverride {
            return sourceTypeOverride
        }

        if event.type == .income {
            switch cashInflowKind(for: event) {
            case .reimbursement:
                return "Reimbursement"
            case .expectedRepayment:
                return "Debt repayment"
            case .salary:
                return "Expected income"
            case .oneTimeCashInflow:
                return "Future inflow"
            case .transfer:
                return "Transfer"
            case .loanOrDebt:
                return "Loan / Debt"
            case .unknown:
                return "Other future inflow"
            }
        }

        if event.type == .installment {
            return "Installment"
        }

        if event.repeatRule != .none || event.isProjected {
            return "Recurring"
        }

        switch event.type {
        case .expectedExpense:
            return "Future expense"
        case .obligation:
            return "Obligation"
        case .expense:
            return "Scheduled item"
        case .income:
            return "Expected income"
        case .installment:
            return "Installment"
        case .transfer:
            return "Transfer"
        }
    }

    private static func includedFlexibleAmount(
        remainingEstimateAmount: Double,
        monthStart: Date,
        monthEnd: Date,
        coveredStart: Date,
        coveredEnd: Date
    ) -> Double {
        guard remainingEstimateAmount > 0,
              coveredEnd >= coveredStart else {
            return 0
        }

        let coveredDays = inclusiveDayCount(from: coveredStart, through: coveredEnd)
        let prorateStart = maxDate(monthStart, coveredStart)
        let lastMonthDay = Calendar.current.date(byAdding: .day, value: -1, to: monthEnd) ?? monthStart
        let remainingDays = max(inclusiveDayCount(from: prorateStart, through: lastMonthDay), 1)
        guard coveredDays > 0 else {
            return 0
        }

        return remainingEstimateAmount * min(Double(coveredDays) / Double(remainingDays), 1)
    }

    private static func paidActualsByMonthCategory(
        financialEvents: [FinancialEvent],
        creditCardPurchases: [CreditCardPurchase]
    ) -> [String: [String: Double]] {
        var result: [String: [String: Double]] = [:]

        for event in financialEvents
        where event.status == .paid && isOutflow(event.type) {
            let monthID = monthID(for: event.date)
            let categoryName = event.categoryName ?? "Uncategorized"
            result[monthID, default: [:]][categoryName, default: 0] += event.amount
        }

        for purchase in creditCardPurchases {
            let monthID = monthID(for: purchase.purchaseDate)
            result[monthID, default: [:]][purchase.categoryName, default: 0] += purchase.amount
        }

        return result
    }

    private static func committedElsewhereByMonthCategory(
        projectedEvents: [ProjectedCashEvent]
    ) -> [String: [String: Double]] {
        var result: [String: [String: Double]] = [:]

        for event in projectedEvents
        where isOutflow(event.type) {
            let monthID = monthID(for: event.date)
            let categoryName = event.categoryName ?? "Uncategorized"
            result[monthID, default: [:]][categoryName, default: 0] += event.amount
        }

        return result
    }

    private static func monthID(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    private static func inclusiveDayCount(from startDate: Date, through endDate: Date) -> Int {
        let start = startOfDay(startDate)
        let end = startOfDay(endDate)

        guard end >= start else {
            return 0
        }

        let exclusiveEnd = Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end
        return max(Calendar.current.dateComponents([.day], from: start, to: exclusiveEnd).day ?? 0, 0)
    }

    private static func firstIncompleteBudgetMonth(
        monthlyBudgets: [WalletMonthlyBudget],
        from startDate: Date,
        targetDate: Date
    ) -> Date? {
        let calendar = Calendar.current
        let budgetIDs = Set(monthlyBudgets.filter { budget in
            budget.items.contains { $0.plannedAmount > 0 }
        }.map { "\($0.year)-\($0.month)" })

        var monthCursor = startOfMonth(startDate)
        let targetMonth = startOfMonth(targetDate)

        while monthCursor <= targetMonth {
            let components = calendar.dateComponents([.year, .month], from: monthCursor)
            let monthID = "\(components.year ?? 0)-\(components.month ?? 0)"

            if !budgetIDs.contains(monthID) {
                return monthCursor
            }

            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthCursor) else {
                return nil
            }
            monthCursor = nextMonth
        }

        return nil
    }

    nonisolated private static func inferCashInflowKind(title: String, repeatRule: RepeatRule) -> CashInflowKind {
        let lowercased = title.lowercased()

        if repeatRule != .none || lowercased.contains("salary") || lowercased.contains("payroll") || lowercased.contains("مرتب") || lowercased.contains("راتب") {
            return .salary
        }

        if lowercased.contains("expected repayment") || lowercased.contains("سداد متوقع") {
            return .expectedRepayment
        }

        if lowercased.contains("loan") || lowercased.contains("debt") || lowercased.contains("قرض") || lowercased.contains("دين") {
            return .loanOrDebt
        }

        if lowercased.contains("transfer") || lowercased.contains("تحويل") {
            return .transfer
        }

        if lowercased.contains("money fellow") || lowercased.contains("جمعية") {
            return .oneTimeCashInflow
        }

        return .unknown
    }

    nonisolated private static func cashInflowKind(for event: ProjectedCashEvent) -> CashInflowKind {
        if event.title.localizedCaseInsensitiveContains("Expected repayment") ||
            event.title.contains("سداد متوقع") {
            return .expectedRepayment
        }

        switch event.incomeType {
        case .salary:
            return .salary
        case .oneTimeCashInflow:
            return .oneTimeCashInflow
        case .reimbursement:
            return .reimbursement
        case .transfer:
            return .transfer
        case .loanOrDebt:
            return .loanOrDebt
        case .unknown:
            return .unknown
        case nil:
            return inferCashInflowKind(title: event.title, repeatRule: event.repeatRule)
        }
    }

    // MARK: - Monthly Forecast

    static func buildMonthlyForecast(
        accounts: [Account],
        financialEvents: [FinancialEvent],
        monthlyLivingBurn: Double,
        numberOfMonths: Int = 6,
        from startDate: Date = Date()
    ) -> [MonthlyForecast] {

        var forecasts: [MonthlyForecast] = []
        var runningCash = calculateAvailableCash(accounts: accounts)

        let calendar = Calendar.current
        let firstMonth = startOfMonth(startDate)

        guard let horizonEnd = calendar.date(
            byAdding: .month,
            value: numberOfMonths,
            to: firstMonth
        ) else {
            return []
        }

        let horizonDays = calendar.dateComponents(
            [.day],
            from: startOfDay(startDate),
            to: horizonEnd
        ).day ?? 180

        let projectedEvents = buildProjectedCashEvents(
            financialEvents: financialEvents,
            from: startDate,
            horizonDays: max(horizonDays, 180)
        )

        for monthOffset in 0..<numberOfMonths {
            guard let monthStart = calendar.date(
                byAdding: .month,
                value: monthOffset,
                to: firstMonth
            ) else {
                continue
            }

            guard let nextMonthStart = calendar.date(
                byAdding: .month,
                value: 1,
                to: monthStart
            ) else {
                continue
            }

            let eventsInMonth = projectedEvents.filter { event in
                event.date >= monthStart &&
                event.date < nextMonthStart
            }

            let confirmedOutflow = eventsInMonth
                .filter { event in
                    isOutflow(event.type) &&
                    event.type != .expectedExpense
                }
                .map { $0.amount }
                .reduce(0, +)

            let expectedExpenseOutflow = eventsInMonth
                .filter { event in
                    event.type == .expectedExpense
                }
                .map { $0.amount }
                .reduce(0, +)

            let expectedIncome = eventsInMonth
                .filter { event in
                    event.type == .income
                }
                .map { $0.amount }
                .reduce(0, +)

            let flexibleSpendingForMonth = flexibleSpendingForMonth(
                monthlyEstimate: monthlyLivingBurn,
                monthStart: monthStart,
                nextMonthStart: nextMonthStart,
                from: startDate
            )

            let expectedOutflow = expectedExpenseOutflow + flexibleSpendingForMonth

            let forecast = MonthlyForecast(
                monthStartDate: monthStart,
                startingCash: runningCash,
                confirmedOutflow: confirmedOutflow,
                expectedOutflow: expectedOutflow,
                expectedIncome: expectedIncome
            )

            forecasts.append(forecast)
            runningCash = forecast.endingCash
        }

        return forecasts
    }

    // MARK: - Monthly Forecast Breakdown

    static func buildMonthlyForecastBreakdowns(
        financialEvents: [FinancialEvent],
        monthlyLivingBurn: Double,
        numberOfMonths: Int = 6,
        from startDate: Date = Date()
    ) -> [MonthlyForecastBreakdown] {

        let calendar = Calendar.current
        let firstMonth = startOfMonth(startDate)

        guard let horizonEnd = calendar.date(
            byAdding: .month,
            value: numberOfMonths,
            to: firstMonth
        ) else {
            return []
        }

        let horizonDays = calendar.dateComponents(
            [.day],
            from: startOfDay(startDate),
            to: horizonEnd
        ).day ?? 180

        let projectedEvents = buildProjectedCashEvents(
            financialEvents: financialEvents,
            from: startDate,
            horizonDays: max(horizonDays, 180)
        )

        return (0..<numberOfMonths).compactMap { monthOffset in
            guard let monthStart = calendar.date(
                byAdding: .month,
                value: monthOffset,
                to: firstMonth
            ) else {
                return nil
            }

            guard let nextMonthStart = calendar.date(
                byAdding: .month,
                value: 1,
                to: monthStart
            ) else {
                return nil
            }

            let eventsInMonth = projectedEvents.filter { event in
                event.date >= monthStart &&
                event.date < nextMonthStart
            }

            let incomeItems = eventsInMonth
                .filter { $0.type == .income }
                .map { makeBreakdownItem(from: $0) }

            let fixedOutflowItems = eventsInMonth
                .filter { event in
                    isOutflow(event.type) && event.type != .expectedExpense
                }
                .map { makeBreakdownItem(from: $0) }

            let expectedExpenseItems = eventsInMonth
                .filter { $0.type == .expectedExpense }
                .map { makeBreakdownItem(from: $0) }

            let flexibleSpendingForMonth = flexibleSpendingForMonth(
                monthlyEstimate: monthlyLivingBurn,
                monthStart: monthStart,
                nextMonthStart: nextMonthStart,
                from: startDate
            )

            return MonthlyForecastBreakdown(
                monthStartDate: monthStart,
                incomeItems: incomeItems,
                fixedOutflowItems: fixedOutflowItems,
                expectedExpenseItems: expectedExpenseItems,
                flexibleSpendingAmount: flexibleSpendingForMonth
            )
        }
    }

    private static func makeBreakdownItem(from event: ProjectedCashEvent) -> ForecastBreakdownItem {
        ForecastBreakdownItem(
            title: event.title,
            amount: event.amount,
            date: event.date,
            type: event.type,
            repeatRule: event.repeatRule,
            isProjected: event.isProjected
        )
    }

    // MARK: - Flexible Spending Estimate

    static func flexibleSpendingAmount(
        monthlyEstimate: Double,
        from startDate: Date,
        until endDate: Date?
    ) -> Double {

        guard let endDate else {
            return 0
        }

        let dailyEstimate = max(monthlyEstimate, 0) / 30
        let start = startOfDay(startDate)
        let end = startOfDay(endDate)

        let days = Calendar.current.dateComponents(
            [.day],
            from: start,
            to: end
        ).day ?? 0

        return Double(max(days, 0)) * dailyEstimate
    }

    static func flexibleSpendingForMonth(
        monthlyEstimate: Double,
        monthStart: Date,
        nextMonthStart: Date,
        from startDate: Date
    ) -> Double {

        let dailyEstimate = max(monthlyEstimate, 0) / 30

        let effectiveStart = maxDate(
            startOfDay(monthStart),
            startOfDay(startDate)
        )

        let days = Calendar.current.dateComponents(
            [.day],
            from: effectiveStart,
            to: startOfDay(nextMonthStart)
        ).day ?? 0

        return Double(max(days, 0)) * dailyEstimate
    }

    // MARK: - Helpers

    static func isOutflow(_ type: FinancialEventType) -> Bool {
        switch type {
        case .expense, .obligation, .expectedExpense, .installment:
            return true

        case .income, .transfer:
            return false
        }
    }

    static func isCashImpactEvent(_ type: FinancialEventType) -> Bool {
        switch type {
        case .income, .obligation, .expectedExpense, .installment:
            return true

        case .expense, .transfer:
            return false
        }
    }

    static func isFutureProjectionStatus(_ status: FinancialEventStatus) -> Bool {
        switch status {
        case .expected, .unpaid, .planned:
            return true

        case .paid, .skipped, .cancelled:
            return false
        }
    }

    static func cashImpact(_ type: FinancialEventType, amount: Double) -> Double {
        switch type {
        case .income:
            return amount

        case .expense, .obligation, .expectedExpense, .installment:
            return -amount

        case .transfer:
            return 0
        }
    }

    static func isBeforeOrEqual(_ date: Date, _ endDate: Date?) -> Bool {
        guard let endDate else {
            return true
        }

        return date <= endDate
    }

    static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    static func startOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func calendarDayAfter(_ date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay(date)) ?? startOfDay(date)
    }

    static func maxDate(_ first: Date, _ second: Date) -> Date {
        first > second ? first : second
    }

    static func minDate(_ first: Date, _ second: Date) -> Date {
        first < second ? first : second
    }
}
