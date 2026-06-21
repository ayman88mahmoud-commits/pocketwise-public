import SwiftUI

struct MonthlySummaryView: View {

    @EnvironmentObject private var store: WalletStore

    @State private var selectedMonthDate: Date

    init(initialMonthDate: Date = Date()) {
        _selectedMonthDate = State(initialValue: initialMonthDate)
    }

    private var monthComponents: (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedMonthDate)
        return (components.year ?? 2026, components.month ?? 1)
    }

    private var monthStart: Date {
        var components = DateComponents()
        components.year = monthComponents.year
        components.month = monthComponents.month
        components.day = 1
        return Calendar.current.date(from: components) ?? selectedMonthDate
    }

    private var currentMonthStart: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        return Calendar.current.date(from: components) ?? Date()
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(monthStart, equalTo: Date(), toGranularity: .month)
    }

    private var isFutureMonth: Bool {
        monthStart > currentMonthStart
    }

    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    private var elapsedDays: Int {
        if isFutureMonth && totalActual == 0 {
            return 0
        }

        if isCurrentMonth {
            return min(Calendar.current.component(.day, from: Date()), daysInMonth)
        }

        return daysInMonth
    }

    private var budget: WalletMonthlyBudget? {
        store.monthlyBudget(year: monthComponents.year, month: monthComponents.month)
    }

    private var plannedByCategory: [String: Double] {
        var values: [String: Double] = [:]

        for item in budget?.items ?? [] {
            values[item.categoryName, default: 0] += item.plannedAmount
        }

        return values
    }

    private var detailedActualByCategory: [String: Double] {
        store.actualSpendingByCategory(year: monthComponents.year, month: monthComponents.month)
    }

    private var historicalActualByCategory: [String: Double] {
        store.historicalSummarySpendingByCategory(year: monthComponents.year, month: monthComponents.month)
    }

    private var actualByCategory: [String: Double] {
        var values = detailedActualByCategory

        for (categoryName, amount) in historicalActualByCategory {
            values[categoryName, default: 0] += amount
        }

        return values
    }

    private var historicalSummaryTotal: Double {
        historicalActualByCategory.values.reduce(0, +)
    }

    private var cashMovementRows: [MonthlySummaryCashMovementRow] {
        peopleDebtCashMovementRows()
    }

    private var categoryRows: [MonthlySummaryCategoryRow] {
        let allNames = Array(Set(plannedByCategory.keys).union(actualByCategory.keys))

        return allNames
            .map { name in
                MonthlySummaryCategoryRow(
                    categoryName: name,
                    plannedAmount: plannedByCategory[name] ?? 0,
                    actualAmount: actualByCategory[name] ?? 0,
                    historicalAmount: historicalActualByCategory[name] ?? 0
                )
            }
            .sorted { lhs, rhs in
                if lhs.actualAmount == rhs.actualAmount {
                    return lhs.categoryName.localizedCaseInsensitiveCompare(rhs.categoryName) == .orderedAscending
                }

                return lhs.actualAmount > rhs.actualAmount
            }
    }

    private var topSpendingRows: [MonthlySummaryCategoryRow] {
        Array(categoryRows.filter { $0.actualAmount > 0 }.prefix(5))
    }

    private var overBudgetRows: [MonthlySummaryCategoryRow] {
        categoryRows
            .filter { $0.plannedAmount > 0 && $0.actualAmount > $0.plannedAmount }
            .sorted { $0.overAmount > $1.overAmount }
    }

    private var totalPlanned: Double {
        plannedByCategory.values.reduce(0, +)
    }

    private var totalActual: Double {
        actualByCategory.values.reduce(0, +)
    }

    private var remaining: Double {
        totalPlanned - totalActual
    }

    private var dailyBurnRate: Double {
        flexibleDailyAverage
    }

    private var flexibleActualByCategory: [String: Double] {
        actualByCategory.filter { !isFixedOrCommittedCategory($0.key) }
    }

    private var fixedActualByCategory: [String: Double] {
        actualByCategory.filter { isFixedOrCommittedCategory($0.key) }
    }

    private var flexibleActualTotal: Double {
        flexibleActualByCategory.values.reduce(0, +)
    }

    private var flexiblePlannedTotal: Double {
        plannedByCategory
            .filter { !isFixedOrCommittedCategory($0.key) }
            .values
            .reduce(0, +)
    }

    private var fixedCommittedAlreadyOverBudget: Double {
        fixedActualByCategory.reduce(0) { partialResult, item in
            let planned = plannedByCategory[item.key] ?? 0
            return partialResult + max(0, item.value - planned)
        }
    }

    private var flexibleDailyAverage: Double {
        guard elapsedDays > 0 else {
            return 0
        }

        return flexibleActualTotal / Double(elapsedDays)
    }

    private var projectedMonthEndSpend: Double? {
        if isCurrentMonth {
            return flexibleDailyAverage * Double(daysInMonth)
        }

        if isFutureMonth && totalActual == 0 {
            return nil
        }

        return flexibleActualTotal
    }

    private var projectedRemaining: Double? {
        guard let projectedMonthEndSpend else {
            return nil
        }

        return flexiblePlannedTotal - projectedMonthEndSpend
    }

    private var expectedOverspend: Double? {
        guard let projectedMonthEndSpend else {
            return nil
        }

        return max(0, projectedMonthEndSpend - flexiblePlannedTotal) + fixedCommittedAlreadyOverBudget
    }

    private var status: MonthlySummaryStatus {
        guard totalPlanned > 0 else {
            return .notPlanned
        }

        if totalActual > totalPlanned {
            return .overBudget
        }

        if isCurrentMonth,
           let expectedOverspend,
           expectedOverspend > 0 {
            return .overBudget
        }

        if totalActual > totalPlanned * 0.8 {
            return .watch
        }

        if isCurrentMonth,
           let projectedMonthEndSpend,
           flexiblePlannedTotal > 0,
           projectedMonthEndSpend > flexiblePlannedTotal * 0.8 {
            return .watch
        }

        return .onTrack
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                monthSelector
                statusCard
                plannedActualCard
                historicalSummaryCard
                cashMovementsCard
                burnRateCard
                topCategoriesSection
                overBudgetSection
                insightCard
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Monthly Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monthSelector: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.borderless)

            Spacer()

            VStack(spacing: 4) {
                Text(formatMonth(selectedMonthDate))
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Monthly spending dashboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatMonth(selectedMonthDate))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(status.title)
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                Text(status.badgeText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(status.color)
                    .background(status.color.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(statusExplanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var plannedActualCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Planned vs Actual")
                .font(.headline)
                .fontWeight(.semibold)

            metricRow(title: "Total Planned", value: totalPlanned)
            metricRow(title: "Total Actual", value: totalActual)

            if historicalSummaryTotal > 0 {
                metricRow(title: "Summary-only historical data", value: historicalSummaryTotal)
            }

            Divider()

            HStack {
                Text(remaining >= 0 ? "Remaining" : "Over")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatCurrency(abs(remaining)))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(remaining >= 0 ? .green : .red)
            }

            HStack {
                Text("Categories Over Budget")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(overBudgetRows.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var burnRateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Burn Rate")
                .font(.headline)
                .fontWeight(.semibold)

            if isFutureMonth && totalActual == 0 {
                Text("No actual spending recorded for this future month yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                metricRow(title: store.appLanguage == .arabicEgyptian ? "متوسط الصرف المرن اليومي" : "Flexible Daily Average", value: dailyBurnRate)

                if isCurrentMonth {
                    metricRow(title: store.appLanguage == .arabicEgyptian ? "الصرف المرن المتوقع" : "Projected Flexible Month End", value: projectedMonthEndSpend ?? 0)

                    if let expectedOverspend {
                        HStack {
                            Text(store.appLanguage == .arabicEgyptian ? "الزيادة المتوقعة" : "Expected Overspend")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(formatCurrency(expectedOverspend))
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(expectedOverspend > 0 ? .red : .green)
                        }

                        Text(store.appLanguage == .arabicEgyptian ? "لا يحتسب الالتزامات الثابتة ضمن متوسط الصرف اليومي." : "Excludes fixed/committed obligations from daily pace.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Past months show final actual spending instead of a projection.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var historicalSummaryCard: some View {
        Group {
            if historicalSummaryTotal > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Summary-only Historical Data")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text("This month includes \(formatCurrency(historicalSummaryTotal)) entered as category totals. These amounts do not appear in Transactions and do not affect account balances.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(spacing: 8) {
                        ForEach(categoryRows.filter { $0.historicalAmount > 0 }) { row in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.categoryName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Text("Summary-only")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(formatCurrency(row.historicalAmount))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                .padding(18)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var cashMovementsCard: some View {
        Group {
            if !cashMovementRows.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(store.appLanguage == .arabicEgyptian ? "حركات نقدية" : "Cash Movements")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text(store.appLanguage == .arabicEgyptian ? "حركات الأشخاص والديون غير محسوبة ضمن مصاريف البيت أو حالة الميزانية." : "People/Debts cash movements are not counted in household spending or budget status.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(spacing: 8) {
                        ForEach(cashMovementRows) { row in
                            HStack(spacing: 10) {
                                Image(systemName: row.iconName)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    Text(store.appLanguage == .arabicEgyptian ? "حركة نقدية غير مصروف" : "Non-spending cash movement")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(formatCurrency(row.amount))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                .padding(18)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var topCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Categories")
                .font(.headline)
                .fontWeight(.semibold)

            if topSpendingRows.isEmpty {
                emptyText("No paid spending recorded for this month.")
            } else {
                VStack(spacing: 10) {
                    ForEach(topSpendingRows) { row in
                        categorySummaryRow(row)
                    }
                }
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var overBudgetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Over Budget")
                .font(.headline)
                .fontWeight(.semibold)

            if overBudgetRows.isEmpty {
                emptyText("No categories over budget.")
            } else {
                VStack(spacing: 10) {
                    ForEach(overBudgetRows) { row in
                        categorySummaryRow(row)
                    }
                }
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var insightCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(helpfulInsight)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusExplanation: String {
        switch status {
        case .notPlanned:
            return "No monthly budget has been saved for this month yet."

        case .onTrack:
            return "Actual spending is within the safe range of the monthly plan."

        case .watch:
            return "Spending is close to the monthly plan. Keep an eye on the remaining days."

        case .overBudget:
            if totalActual > totalPlanned {
                return "Actual spending is over the monthly plan."
            }

            return "At the current pace, this month may exceed the plan."
        }
    }

    private var helpfulInsight: String {
        if totalPlanned <= 0 {
            return "Create a monthly budget first to compare planned and actual spending."
        }

        if totalActual > totalPlanned {
            return "You are currently over budget by \(formatCurrency(totalActual - totalPlanned))."
        }

        if isCurrentMonth,
           let expectedOverspend,
           expectedOverspend > 0 {
            return "At the current flexible-spending pace, expected overspend is \(formatCurrency(expectedOverspend)). Fixed/committed obligations are excluded from daily pace."
        }

        if let topCategory = topSpendingRows.first {
            return "\(topCategory.categoryName) is the highest spending category this month."
        }

        if isFutureMonth {
            return "This future month has a plan but no actual spending yet."
        }

        return "No paid spending has been recorded for this month yet."
    }

    private func categorySummaryRow(_ row: MonthlySummaryCategoryRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.categoryName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text(formatCurrency(row.actualAmount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            HStack(spacing: 10) {
                Text("Plan: \(formatCurrency(row.plannedAmount))")
                Text("Actual: \(formatCurrency(row.actualAmount))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if row.historicalAmount > 0 {
                Text("Includes \(formatCurrency(row.historicalAmount)) summary-only historical data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(row.remainingAmount >= 0 ? "Remaining" : "Over")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatCurrency(abs(row.remainingAmount)))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(row.remainingAmount >= 0 ? .green : .red)
            }

            ProgressView(value: row.progressValue)
                .tint(row.isOverBudget ? .red : .green)
        }
        .padding(.vertical, 4)
    }

    private func metricRow(title: String, value: Double) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(formatCurrency(value))
                .font(.headline)
                .fontWeight(.semibold)
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
    }

    private func moveMonth(by value: Int) {
        selectedMonthDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonthDate) ?? selectedMonthDate
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount)
    }

    private func peopleDebtCashMovementRows() -> [MonthlySummaryCashMovementRow] {
        guard let range = monthRange(year: monthComponents.year, month: monthComponents.month) else {
            return []
        }

        let entries = store.personDebtEntries.filter { entry in
            entry.date >= range.start && entry.date < range.end
        }

        let moneyLent = entries
            .filter { $0.entryType == .initialLending }
            .map(\.amount)
            .reduce(0, +)

        let repaymentsReceived = entries
            .filter { $0.entryType == .repaymentReceived }
            .map(\.amount)
            .reduce(0, +)

        let moneyBorrowed = entries
            .filter { $0.entryType == .initialBorrowing }
            .map(\.amount)
            .reduce(0, +)

        let repaymentsPaid = entries
            .filter { $0.entryType == .repaymentPaid }
            .map(\.amount)
            .reduce(0, +)

        let isArabic = store.appLanguage == .arabicEgyptian
        var rows: [MonthlySummaryCashMovementRow] = []

        if moneyLent > 0 {
            rows.append(MonthlySummaryCashMovementRow(
                id: "moneyLent",
                title: isArabic ? "فلوس اتسلفت لحد" : "Money lent",
                amount: moneyLent,
                iconName: "arrow.up.forward.circle"
            ))
        }

        if repaymentsReceived > 0 {
            rows.append(MonthlySummaryCashMovementRow(
                id: "repaymentsReceived",
                title: isArabic ? "سداد مستلم" : "Repayments received",
                amount: repaymentsReceived,
                iconName: "arrow.down.circle"
            ))
        }

        if moneyBorrowed > 0 {
            rows.append(MonthlySummaryCashMovementRow(
                id: "moneyBorrowed",
                title: isArabic ? "فلوس مستلفة من حد" : "Money borrowed",
                amount: moneyBorrowed,
                iconName: "arrow.down.forward.circle"
            ))
        }

        if repaymentsPaid > 0 {
            rows.append(MonthlySummaryCashMovementRow(
                id: "repaymentsPaid",
                title: isArabic ? "سداد مدفوع" : "Repayments paid",
                amount: repaymentsPaid,
                iconName: "arrow.up.circle"
            ))
        }

        return rows
    }

    private func isFixedOrCommittedCategory(_ categoryName: String) -> Bool {
        let normalized = categoryName
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        let fixedTerms = [
            "fixed",
            "obligation",
            "commitment",
            "rent",
            "valu",
            "installment",
            "school",
            "fees",
            "money fellow",
            "club",
            "قسط",
            "اقساط",
            "التزام",
            "التزامات",
            "ايجار",
            "مدرسة",
            "فاليو",
            "ڤاليو"
        ]

        return fixedTerms.contains { normalized.contains($0) }
    }

    private func monthRange(year: Int, month: Int) -> (start: Date, end: Date)? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let start = Calendar.current.date(from: components),
              let end = Calendar.current.date(byAdding: .month, value: 1, to: start) else {
            return nil
        }

        return (start, end)
    }
}

private struct MonthlySummaryCashMovementRow: Identifiable {
    let id: String
    let title: String
    let amount: Double
    let iconName: String
}

private struct MonthlySummaryCategoryRow: Identifiable {
    var id: String { categoryName }

    let categoryName: String
    let plannedAmount: Double
    let actualAmount: Double
    let historicalAmount: Double

    var remainingAmount: Double {
        plannedAmount - actualAmount
    }

    var overAmount: Double {
        max(actualAmount - plannedAmount, 0)
    }

    var isOverBudget: Bool {
        plannedAmount > 0 && actualAmount > plannedAmount
    }

    var progressValue: Double {
        guard plannedAmount > 0 else {
            return actualAmount > 0 ? 1 : 0
        }

        return min(actualAmount / plannedAmount, 1)
    }
}

private enum MonthlySummaryStatus {
    case notPlanned
    case onTrack
    case watch
    case overBudget

    var title: String {
        switch self {
        case .notPlanned:
            return "Not Planned"
        case .onTrack:
            return "On Track"
        case .watch:
            return "Watch"
        case .overBudget:
            return "Over Budget"
        }
    }

    var badgeText: String {
        switch self {
        case .notPlanned:
            return "Not Planned"
        case .onTrack:
            return "Green"
        case .watch:
            return "Yellow"
        case .overBudget:
            return "Red"
        }
    }

    var color: Color {
        switch self {
        case .notPlanned:
            return .secondary
        case .onTrack:
            return .green
        case .watch:
            return .orange
        case .overBudget:
            return .red
        }
    }
}

struct MonthlySummaryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            MonthlySummaryView()
                .environmentObject(WalletStore())
        }
    }
}
