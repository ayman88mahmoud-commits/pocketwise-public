import SwiftUI

struct WhereMoneyWentReportView: View {

    @EnvironmentObject private var store: WalletStore
    @State private var selectedMonthDate = Date()

    private var monthComponents: (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedMonthDate)
        return (components.year ?? 2026, components.month ?? 1)
    }

    private var rows: [AnalysisCategorySpendRow] {
        analysisRows(
            store: store,
            year: monthComponents.year,
            month: monthComponents.month
        )
    }

    private var total: Double {
        rows.map { $0.totalAmount }.reduce(0, +)
    }

    private var cashMovementRows: [PeopleDebtCashMovementRow] {
        peopleDebtCashMovementRows(
            store: store,
            year: monthComponents.year,
            month: monthComponents.month
        )
    }

    var body: some View {
        AnalysisReportShell(
            title: store.appLanguage == .arabicEgyptian ? "الفلوس راحت فين؟" : "Where Did My Money Go",
            subtitle: store.appLanguage == .arabicEgyptian ? "تقسيم مصروفات البيت حسب التصنيف" : "Category breakdown for household spending. People/Debts cash movements are shown separately.",
            selectedMonthDate: $selectedMonthDate
        ) {
            if rows.isEmpty && cashMovementRows.isEmpty {
                AnalysisEmptyState(text: store.appLanguage == .arabicEgyptian ? "مفيش مصاريف أو حركات أشخاص/ديون للشهر ده." : "No spending or People/Debts cash movements recorded for this month.")
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    if !rows.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(AppText.householdSpending(store.appLanguage))
                                .font(.headline)
                                .fontWeight(.semibold)

                            ForEach(rows) { row in
                                NavigationLink {
                                    TransactionsView(
                                        initialFilter: TransactionInitialFilter(
                                            categoryName: row.categoryName,
                                            monthDate: selectedMonthDate,
                                            paidOnly: true
                                        )
                                    )
                                    .environmentObject(store)
                                } label: {
                                    AnalysisSpendRow(row: row, total: total)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !cashMovementRows.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(AppText.cashMovements(store.appLanguage))
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text(store.appLanguage == .arabicEgyptian ? "حركات الأشخاص والديون غير محسوبة كمصروفات منزلية." : "People/Debts movements are not counted as household spending.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(cashMovementRows) { row in
                                NavigationLink {
                                    PeopleDebtsView()
                                        .environmentObject(store)
                                } label: {
                                    PeopleDebtCashMovementReportRow(row: row)
                                        .environmentObject(store)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct BiggestDrainsReportView: View {

    @EnvironmentObject private var store: WalletStore
    @State private var selectedMonthDate = Date()

    private var monthComponents: (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedMonthDate)
        return (components.year ?? 2026, components.month ?? 1)
    }

    private var rows: [AnalysisCategorySpendRow] {
        Array(
            analysisRows(
                store: store,
                year: monthComponents.year,
                month: monthComponents.month
            )
            .prefix(8)
        )
    }

    private var total: Double {
        rows.map { $0.totalAmount }.reduce(0, +)
    }

    var body: some View {
        AnalysisReportShell(
            title: store.appLanguage == .arabicEgyptian ? "أكبر مصاريف سحبت الفلوس" : "Biggest Drains",
            subtitle: store.appLanguage == .arabicEgyptian ? "أعلى مصروفات في الشهر المختار." : "Top spending areas for the selected month.",
            selectedMonthDate: $selectedMonthDate
        ) {
            if rows.isEmpty {
                AnalysisEmptyState(text: store.appLanguage == .arabicEgyptian ? "مفيش مصاريف مسجلة للشهر ده." : "No spending recorded for this month.")
            } else {
                VStack(spacing: 10) {
                    Text(store.appLanguage == .arabicEgyptian ? "بيتم عرض أعلى ٨ تصنيفات" : "Showing top 8 categories")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(rows) { row in
                        NavigationLink {
                            TransactionsView(
                                initialFilter: TransactionInitialFilter(
                                    categoryName: row.categoryName,
                                    monthDate: selectedMonthDate,
                                    paidOnly: true
                                )
                            )
                            .environmentObject(store)
                        } label: {
                            AnalysisSpendRow(row: row, total: total)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct WhatChangedReportView: View {

    @EnvironmentObject private var store: WalletStore
    @State private var selectedMonthDate = Date()

    private var selectedMonthComponents: (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedMonthDate)
        return (components.year ?? 2026, components.month ?? 1)
    }

    private var previousMonthDate: Date {
        Calendar.current.date(byAdding: .month, value: -1, to: selectedMonthDate) ?? selectedMonthDate
    }

    private var previousMonthComponents: (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: previousMonthDate)
        return (components.year ?? 2026, components.month ?? 1)
    }

    private var rows: [AnalysisChangeRow] {
        let current = combinedSpending(
            store: store,
            year: selectedMonthComponents.year,
            month: selectedMonthComponents.month
        )
        let previous = combinedSpending(
            store: store,
            year: previousMonthComponents.year,
            month: previousMonthComponents.month
        )

        return Array(Set(current.keys).union(previous.keys))
            .map { categoryName in
                AnalysisChangeRow(
                    categoryName: categoryName,
                    currentAmount: current[categoryName] ?? 0,
                    previousAmount: previous[categoryName] ?? 0
                )
            }
            .filter { $0.currentAmount > 0 || $0.previousAmount > 0 }
            .sorted { abs($0.changeAmount) > abs($1.changeAmount) }
    }

    var body: some View {
        AnalysisReportShell(
            title: store.appLanguage == .arabicEgyptian ? "إيه اللي اتغيّر؟" : "What Changed",
            subtitle: store.appLanguage == .arabicEgyptian ? "مقارنة الشهر المختار بالشهر اللي قبله." : "Selected month compared with the previous month.",
            selectedMonthDate: $selectedMonthDate
        ) {
            if rows.isEmpty {
                AnalysisEmptyState(text: store.appLanguage == .arabicEgyptian ? "مفيش مصاريف في الشهر الحالي أو اللي قبله للمقارنة." : "No current or previous month spending to compare.")
            } else {
                VStack(spacing: 10) {
                    Text(store.appLanguage == .arabicEgyptian ? "بيتم عرض أعلى ١٠ تغييرات" : "Showing top 10 changes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(rows.prefix(10)) { row in
                        NavigationLink {
                            TransactionsView(
                                initialFilter: TransactionInitialFilter(
                                    categoryName: row.categoryName,
                                    monthDate: selectedMonthDate,
                                    paidOnly: true
                                )
                            )
                            .environmentObject(store)
                        } label: {
                            AnalysisChangeReportRow(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct SubcategoryBreakdownReportView: View {

    @EnvironmentObject private var store: WalletStore
    @State private var selectedMonthDate = Date()

    private var monthComponents: (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedMonthDate)
        return (components.year ?? 2026, components.month ?? 1)
    }

    private var previousMonthDate: Date {
        Calendar.current.date(byAdding: .month, value: -1, to: selectedMonthDate) ?? selectedMonthDate
    }

    private var previousMonthComponents: (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: previousMonthDate)
        return (components.year ?? 2026, components.month ?? 1)
    }

    private var rows: [AnalysisSubcategoryRow] {
        let current = subcategorySpending(year: monthComponents.year, month: monthComponents.month)
        let previous = subcategorySpending(year: previousMonthComponents.year, month: previousMonthComponents.month)

        return current.map { key, value in
            AnalysisSubcategoryRow(
                categoryName: key.category,
                subcategoryName: key.subcategory,
                totalAmount: value.total,
                transactionCount: value.count,
                previousAmount: previous[key]?.total ?? 0
            )
        }
        .sorted { $0.totalAmount > $1.totalAmount }
    }

    var body: some View {
        AnalysisReportShell(
            title: store.appLanguage == .arabicEgyptian ? "التصنيفات الفرعية" : "Subcategory Breakdown",
            subtitle: store.appLanguage == .arabicEgyptian ? "الإجمالي، عدد الحركات، متوسط الحركة، ومقارنة بالشهر اللي فات." : "Total, transaction count, average transaction, and previous-month comparison.",
            selectedMonthDate: $selectedMonthDate
        ) {
            if rows.isEmpty {
                AnalysisEmptyState(text: AppText.noPaidSpendingThisMonth(store.appLanguage))
            } else {
                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        NavigationLink {
                            TransactionsView(
                                initialFilter: TransactionInitialFilter(
                                    searchText: row.subcategoryName,
                                    categoryName: row.categoryName,
                                    monthDate: selectedMonthDate,
                                    paidOnly: true
                                )
                            )
                            .environmentObject(store)
                        } label: {
                            AnalysisSubcategoryReportRow(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func subcategorySpending(year: Int, month: Int) -> [AnalysisSubcategoryKey: (total: Double, count: Int)] {
        Dictionary(uniqueKeysWithValues: store.actualSpendingBySubcategory(year: year, month: month).map { item in
            (
                AnalysisSubcategoryKey(
                    category: item.categoryName,
                    subcategory: item.subCategoryName
                ),
                (item.totalAmount, item.transactionCount)
            )
        })
    }
}

struct MonthlyDriverAnalysisReportView: View {

    @EnvironmentObject private var store: WalletStore
    @State private var selectedMonthDate = Date()

    private var monthComponents: (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedMonthDate)
        return (components.year ?? 2026, components.month ?? 1)
    }

    private var rows: [AnalysisDriverRow] {
        let budget = store.monthlyBudget(year: monthComponents.year, month: monthComponents.month)
        let planned = Dictionary(uniqueKeysWithValues: (budget?.items ?? []).map { ($0.categoryName, $0.plannedAmount) })
        let paid = store.actualSpendingByCategory(year: monthComponents.year, month: monthComponents.month)
        let historical = store.historicalSummarySpendingByCategory(year: monthComponents.year, month: monthComponents.month)

        return Array(Set(planned.keys).union(paid.keys).union(historical.keys))
            .map { categoryName in
                let paidAmount = paid[categoryName] ?? 0
                let historicalAmount = historical[categoryName] ?? 0
                let actualLikeAmount = paidAmount + historicalAmount
                return AnalysisDriverRow(
                    categoryName: categoryName,
                    plannedAmount: planned[categoryName] ?? 0,
                    actualAmount: actualLikeAmount,
                    historicalAmount: historicalAmount
                )
            }
            .filter { $0.gapAmount != 0 || $0.actualAmount > 0 }
            .sorted { abs($0.gapAmount) > abs($1.gapAmount) }
    }

    var body: some View {
        AnalysisReportShell(
            title: store.appLanguage == .arabicEgyptian ? "سبب الزيادة" : "Monthly Driver Analysis",
            subtitle: store.appLanguage == .arabicEgyptian ? "أكبر الفروق بين الخطة واللي اتصرف فعليًا." : "Largest gaps between plan and actual spending.",
            selectedMonthDate: $selectedMonthDate
        ) {
            if rows.isEmpty {
                AnalysisEmptyState(text: store.appLanguage == .arabicEgyptian ? "مفيش بيانات كفاية للتحليل." : "Not enough data for driver analysis.")
            } else {
                VStack(spacing: 10) {
                    ForEach(rows.prefix(10)) { row in
                        NavigationLink {
                            TransactionsView(
                                initialFilter: TransactionInitialFilter(
                                    categoryName: row.categoryName,
                                    monthDate: selectedMonthDate,
                                    paidOnly: true
                                )
                            )
                            .environmentObject(store)
                        } label: {
                            AnalysisDriverReportRow(row: row)
                        }
                        .buttonStyle(.plain)
                    }

                    Text(store.appLanguage == .arabicEgyptian ? "الملخصات القديمة بتظهر كإجمالي بس، مش بتدي عدد حركات أو تجار." : "Summary-only historical data is included as totals only; it cannot provide merchant or frequency detail.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct AnalysisReportShell<Content: View>: View {

    let title: String
    let subtitle: String
    @Binding var selectedMonthDate: Date
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                monthSelector

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                content
                    .padding(18)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monthSelector: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)

            Spacer()

            Text(formatMonth(selectedMonthDate))
                .font(.headline)
                .fontWeight(.semibold)

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func moveMonth(by value: Int) {
        selectedMonthDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonthDate) ?? selectedMonthDate
    }
}

private struct AnalysisSpendRow: View {

    @EnvironmentObject private var store: WalletStore

    let row: AnalysisCategorySpendRow
    let total: Double

    private var share: Double {
        guard total > 0 else {
            return 0
        }

        return row.totalAmount / total
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(AppText.categoryDisplayName(row.categoryName, language: store.appLanguage))
                    .font(.headline)

                Spacer()

                Text(store.displayCurrency(row.reimbursementAmount > 0 ? row.netAmount : row.totalAmount))
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            ProgressView(value: share)

            HStack {
                Text(store.appLanguage == .arabicEgyptian ? "\(Int((share * 100).rounded()))٪ من المصروفات المعروضة" : "\(Int((share * 100).rounded()))% of shown spending")

                Spacer()

                if row.historicalAmount > 0 {
                    Text(store.appLanguage == .arabicEgyptian ? "يشمل \(store.displayCurrency(row.historicalAmount)) من ملخص قديم فقط" : "Includes \(store.displayCurrency(row.historicalAmount)) summary-only")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if row.reimbursementAmount > 0 {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.appLanguage == .arabicEgyptian ? "إجمالي المصروف: \(store.displayCurrency(row.totalAmount))" : "Gross Spend: \(store.displayCurrency(row.totalAmount))")
                    Text(store.appLanguage == .arabicEgyptian ? "تم استرداده: \(store.displayCurrency(row.reimbursementAmount))" : "Reimbursed: \(store.displayCurrency(row.reimbursementAmount))")
                    Text(store.appLanguage == .arabicEgyptian ? "الصافي عليك: \(store.displayCurrency(row.netAmount))" : "Net Cost: \(store.displayCurrency(row.netAmount))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PeopleDebtCashMovementReportRow: View {

    @EnvironmentObject private var store: WalletStore

    let row: PeopleDebtCashMovementRow

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.iconName)
                .font(.headline)
                .frame(width: 34, height: 34)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(AppText.managedInPeopleDebts(store.appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(store.displayCurrency(row.amount))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

private struct AnalysisChangeReportRow: View {

    @EnvironmentObject private var store: WalletStore

    let row: AnalysisChangeRow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(AppText.categoryDisplayName(row.categoryName, language: store.appLanguage))
                    .font(.headline)

                Spacer()

                Text(changeText)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(row.changeAmount >= 0 ? .red : .green)
            }

            HStack {
                Text(store.appLanguage == .arabicEgyptian ? "السابق: \(store.displayCurrency(row.previousAmount))" : "Previous: \(store.displayCurrency(row.previousAmount))")
                Spacer()
                Text(store.appLanguage == .arabicEgyptian ? "الحالي: \(store.displayCurrency(row.currentAmount))" : "Current: \(store.displayCurrency(row.currentAmount))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var changeText: String {
        let prefix = row.changeAmount >= 0 ? "+" : "-"
        return store.signedDisplayCurrency(abs(row.changeAmount), prefix: prefix)
    }
}

private struct AnalysisEmptyState: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
    }
}

private struct AnalysisSubcategoryReportRow: View {

    @EnvironmentObject private var store: WalletStore

    let row: AnalysisSubcategoryRow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(AppText.subcategoryDisplayName(row.subcategoryName, language: store.appLanguage))
                        .font(.headline)

                    Text(AppText.categoryDisplayName(row.categoryName, language: store.appLanguage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(store.displayCurrency(row.totalAmount))
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            HStack {
                Text(store.appLanguage == .arabicEgyptian ? "\(row.transactionCount) عملية" : "\(row.transactionCount) tx")
                Spacer()
                Text(store.appLanguage == .arabicEgyptian ? "المتوسط \(store.displayCurrency(row.averageAmount))" : "Avg \(store.displayCurrency(row.averageAmount))")
                Spacer()
                Text(row.changeAmount >= 0 ? "+\(store.displayCurrency(row.changeAmount))" : "-\(store.displayCurrency(abs(row.changeAmount)))")
                    .foregroundStyle(row.changeAmount >= 0 ? .red : .green)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct AnalysisDriverReportRow: View {

    @EnvironmentObject private var store: WalletStore

    let row: AnalysisDriverRow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(AppText.categoryDisplayName(row.categoryName, language: store.appLanguage))
                    .font(.headline)

                Spacer()

                Text(row.gapAmount >= 0 ? "+\(store.displayCurrency(row.gapAmount))" : "-\(store.displayCurrency(abs(row.gapAmount)))")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(row.gapAmount >= 0 ? .red : .green)
            }

            HStack {
                Text(store.appLanguage == .arabicEgyptian ? "المخطط \(store.displayCurrency(row.plannedAmount))" : "Plan \(store.displayCurrency(row.plannedAmount))")
                Spacer()
                Text(store.appLanguage == .arabicEgyptian ? "الفعلي \(store.displayCurrency(row.actualAmount))" : "Actual \(store.displayCurrency(row.actualAmount))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if row.historicalAmount > 0 {
                Text(store.appLanguage == .arabicEgyptian ? "يشمل \(store.displayCurrency(row.historicalAmount)) من ملخص قديم فقط." : "Includes \(store.displayCurrency(row.historicalAmount)) summary-only historical data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AnalysisCategorySpendRow: Identifiable {
    var id: String { categoryName }
    let categoryName: String
    let detailedAmount: Double
    let historicalAmount: Double
    let reimbursementAmount: Double

    var totalAmount: Double {
        detailedAmount + historicalAmount
    }

    var netAmount: Double {
        max(0, totalAmount - reimbursementAmount)
    }
}

private struct AnalysisChangeRow: Identifiable {
    var id: String { categoryName }
    let categoryName: String
    let currentAmount: Double
    let previousAmount: Double

    var changeAmount: Double {
        currentAmount - previousAmount
    }
}

private struct AnalysisSubcategoryKey: Hashable {
    let category: String
    let subcategory: String
}

private struct AnalysisSubcategoryRow: Identifiable {
    var id: String { "\(categoryName)-\(subcategoryName)" }
    let categoryName: String
    let subcategoryName: String
    let totalAmount: Double
    let transactionCount: Int
    let previousAmount: Double

    var averageAmount: Double {
        guard transactionCount > 0 else { return 0 }
        return totalAmount / Double(transactionCount)
    }

    var changeAmount: Double {
        totalAmount - previousAmount
    }
}

private struct AnalysisDriverRow: Identifiable {
    var id: String { categoryName }
    let categoryName: String
    let plannedAmount: Double
    let actualAmount: Double
    let historicalAmount: Double

    var gapAmount: Double {
        actualAmount - plannedAmount
    }
}

private struct PeopleDebtCashMovementRow: Identifiable {
    let id: String
    let title: String
    let amount: Double
    let iconName: String
}

private func analysisRows(store: WalletStore, year: Int, month: Int) -> [AnalysisCategorySpendRow] {
    let detailed = store.actualSpendingByCategory(year: year, month: month)
    let historical = store.historicalSummarySpendingByCategory(year: year, month: month)
    let reimbursements = store.reimbursementIncomeByCategory(year: year, month: month)

    return Array(Set(detailed.keys).union(historical.keys).union(reimbursements.keys))
        .map { categoryName in
            AnalysisCategorySpendRow(
                categoryName: categoryName,
                detailedAmount: detailed[categoryName] ?? 0,
                historicalAmount: historical[categoryName] ?? 0,
                reimbursementAmount: reimbursements[categoryName] ?? 0
            )
        }
        .filter { $0.totalAmount > 0 || $0.reimbursementAmount > 0 }
        .sorted { $0.totalAmount > $1.totalAmount }
}

private func peopleDebtCashMovementRows(store: WalletStore, year: Int, month: Int) -> [PeopleDebtCashMovementRow] {
    guard let range = monthRange(year: year, month: month) else {
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
    var rows: [PeopleDebtCashMovementRow] = []

    if moneyLent > 0 {
        rows.append(PeopleDebtCashMovementRow(
            id: "moneyLent",
            title: isArabic ? "فلوس اتسلفت لحد" : "Money lent",
            amount: moneyLent,
            iconName: "arrow.up.forward.circle"
        ))
    }

    if repaymentsReceived > 0 {
        rows.append(PeopleDebtCashMovementRow(
            id: "repaymentsReceived",
            title: isArabic ? "سداد مستلم" : "Repayments received",
            amount: repaymentsReceived,
            iconName: "arrow.down.circle"
        ))
    }

    if moneyBorrowed > 0 {
        rows.append(PeopleDebtCashMovementRow(
            id: "moneyBorrowed",
            title: isArabic ? "فلوس مستلفة من حد" : "Money borrowed",
            amount: moneyBorrowed,
            iconName: "arrow.down.forward.circle"
        ))
    }

    if repaymentsPaid > 0 {
        rows.append(PeopleDebtCashMovementRow(
            id: "repaymentsPaid",
            title: isArabic ? "سداد مدفوع" : "Repayments paid",
            amount: repaymentsPaid,
            iconName: "arrow.up.circle"
        ))
    }

    return rows
}

private func combinedSpending(store: WalletStore, year: Int, month: Int) -> [String: Double] {
    Dictionary(uniqueKeysWithValues: analysisRows(store: store, year: year, month: month).map { row in
        (row.categoryName, row.totalAmount)
    })
}

private func isSpendingType(_ type: FinancialEventType) -> Bool {
    switch type {
    case .expense, .obligation, .expectedExpense, .installment:
        return true
    case .income, .transfer:
        return false
    }
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

private func formatMonth(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter.string(from: date)
}

private func formatCurrency(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0

    let number = NSNumber(value: amount)
    let formatted = formatter.string(from: number) ?? "\(Int(amount))"

    return "\(formatted) EGP"
}
