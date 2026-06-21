import SwiftUI

enum RunwayBreakdownRoute: String, Identifiable {
    case startingBalance
    case futureInflows
    case datedObligations
    case recurringInstallments
    case monthlyBudget

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .startingBalance:
            return language == .arabicEgyptian ? "الرصيد الحالي" : "Starting balance"
        case .futureInflows:
            return language == .arabicEgyptian ? "دخول فلوس داخل الحساب" : "Future cash inflows included"
        case .datedObligations:
            return language == .arabicEgyptian ? "مصاريف بتاريخ داخل الحساب" : "Dated obligations included"
        case .recurringInstallments:
            return language == .arabicEgyptian ? "متكرر/أقساط داخل الحساب" : "Recurring/installments included"
        case .monthlyBudget:
            return language == .arabicEgyptian ? "تقدير الميزانية الشهرية" : "Monthly budget included"
        }
    }
}

struct RunwayBudgetSourceRow: Identifiable, Hashable {
    let id: String
    let title: String
    let amount: Double
    let dateText: String
    let statusText: String
    let sourceText: String
    let reasonText: String
}

struct RunwayBudgetSourceListView: View {

    @EnvironmentObject private var store: WalletStore

    let title: String
    let total: Double
    let rows: [RunwayBudgetSourceRow]
    let emptyText: String

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text(isArabic ? "الإجمالي" : "Total")
                    Spacer()
                    Text(store.displayCurrency(total))
                        .fontWeight(.semibold)
                }
            }

            Section {
                if rows.isEmpty {
                    Text(emptyText)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rows) { row in
                        sourceRow(row)
                    }
                }
            } header: {
                Text(isArabic ? "مصادر الرقم" : "Source rows")
            } footer: {
                Text(isArabic ? "عرض فقط. لا يتم تعديل أو تسجيل أو حذف أي بيانات من هنا." : "Read-only. This does not edit, post, or delete anything.")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sourceRow(_ row: RunwayBudgetSourceRow) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer(minLength: 8)

                Text(store.displayCurrency(row.amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Text("\(row.dateText) • \(row.statusText) • \(row.sourceText)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(row.reasonText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

struct RunwayBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let route: RunwayBreakdownRoute
    let result: RunwayCheckResult
    let accounts: [Account]

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(route.title(language: store.appLanguage))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                switch route {
                case .startingBalance:
                    startingBalanceSection
                case .futureInflows:
                    eventBreakdownSection(
                        items: result.breakdown.futureCashInflowItems,
                        displayedTotal: result.breakdown.futureCashInflowTotal
                    )
                case .datedObligations:
                    eventBreakdownSection(
                        items: result.breakdown.datedObligationItems,
                        displayedTotal: result.breakdown.datedExpenseTotal
                    )
                case .recurringInstallments:
                    eventBreakdownSection(
                        items: result.breakdown.recurringInstallmentItems,
                        displayedTotal: result.breakdown.recurringInstallmentTotal
                    )
                case .monthlyBudget:
                    monthlyBudgetSection
                }
            }
            .navigationTitle(isArabic ? "تفاصيل الحساب" : "Runway Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isArabic ? "تم" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var startingBalanceSection: some View {
        Section {
            if accounts.isEmpty {
                emptyRow
            } else {
                ForEach(accounts) { account in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(account.type.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(store.displayCurrency(account.balance))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 3)
                }

                totalRow(total: result.availableCash)
            }
        }
    }

    private func eventBreakdownSection(items: [RunwayBreakdownItem], displayedTotal: Double) -> some View {
        Section {
            if items.isEmpty {
                emptyRow
            } else {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(item.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Spacer(minLength: 8)

                            Text(store.displayCurrency(item.amount))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }

                        Text(categoryText(for: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(formatDate(item.date)) • \(statusText(item.status)) • \(localizedSourceType(item.sourceType))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }

                totalRow(total: displayedTotal)

                if !totalsMatch(items.map(\.amount).reduce(0, +), displayedTotal) {
                    mismatchWarning
                }
            }
        }
    }

    private var monthlyBudgetSection: some View {
        Group {
            Section {
                if result.breakdown.monthlyBudgetItems.isEmpty {
                    emptyRow
                } else {
                    ForEach(result.breakdown.monthlyBudgetItems) { item in
                        monthlyBudgetRow(item, reason: nil)
                    }

                    totalRow(total: result.breakdown.monthlyEstimateTotal)

                    if !totalsMatch(result.breakdown.monthlyBudgetItems.map(\.includedAmount).reduce(0, +), result.breakdown.monthlyEstimateTotal) {
                        mismatchWarning
                    }
                }
            } header: {
                Text(isArabic ? "داخل حساب الميزانية الشهرية" : "Included in monthly budget")
            }
        }
    }

    private func monthlyBudgetRow(_ item: RunwayBudgetBreakdownItem, reason: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(monthTitle(year: item.year, month: item.month)) • \(AppText.categoryDisplayName(item.categoryName, language: store.appLanguage))")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer(minLength: 8)

                Text(store.displayCurrency(item.includedAmount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Text(isArabic ? "داخل الميزانية الشهرية: \(store.displayCurrency(item.includedAmount))" : "Included in monthly budget: \(store.displayCurrency(item.includedAmount))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(isArabic ? "المخطط: \(store.displayCurrency(item.plannedAmount))" : "Planned: \(store.displayCurrency(item.plannedAmount))")
                .font(.caption)
                .foregroundStyle(.secondary)

            sourceValueRow(
                title: isArabic ? "المدفوع حتى الآن" : "Paid so far",
                value: item.paidActualAmount,
                rows: paidSourceRows(for: item),
                emptyText: isArabic ? "لا توجد معاملات مدفوعة لهذا الرقم." : "No paid source rows found for this value."
            )

            sourceValueRow(
                title: isArabic ? "ملتزم محسوب في مكان تاني" : "Committed elsewhere",
                value: item.committedElsewhereAmount,
                rows: committedSourceRows(for: item),
                emptyText: isArabic ? "لا توجد التزامات مجدولة لهذا الرقم." : "No committed source rows found for this value."
            )

            Text(isArabic ? "التقدير المتبقي: \(store.displayCurrency(item.remainingEstimateAmount))" : "Remaining estimate: \(store.displayCurrency(item.remainingEstimateAmount))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let reason {
                Text(isArabic ? "السبب: \(reason)" : "Reason: \(reason)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(budgetCoverageText(for: item))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func sourceValueRow(title: String, value: Double, rows: [RunwayBudgetSourceRow], emptyText: String) -> some View {
        if value > 0 {
            NavigationLink {
                RunwayBudgetSourceListView(
                    title: title,
                    total: value,
                    rows: rows,
                    emptyText: emptyText
                )
                .environmentObject(store)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(title):")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(store.displayCurrency(value))
                        .fontWeight(.semibold)
                }
                .font(.caption)
            }
        } else {
            Text("\(title): \(store.displayCurrency(value))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func paidSourceRows(for item: RunwayBudgetBreakdownItem) -> [RunwayBudgetSourceRow] {
        store.actualSpendingBreakdownItems(
            year: item.year,
            month: item.month,
            categoryName: item.categoryName
        )
        .map { source in
            RunwayBudgetSourceRow(
                id: source.id,
                title: source.title,
                amount: source.amount,
                dateText: formatDate(source.date),
                statusText: isArabic ? "مدفوع" : "paid",
                sourceText: source.transactionType,
                reasonText: isArabic
                    ? "مدفوع بالفعل في نفس الشهر والبند، لذلك لا يضاف مرة أخرى كتقدير متبقي."
                    : "Already paid in this month and category, so it is not added again as remaining budget."
            )
        }
    }

    private func committedSourceRows(for item: RunwayBudgetBreakdownItem) -> [RunwayBudgetSourceRow] {
        (result.breakdown.datedObligationItems + result.breakdown.recurringInstallmentItems)
            .filter { source in
                isSameMonth(source.date, year: item.year, month: item.month) &&
                (source.categoryName ?? "Uncategorized") == item.categoryName
            }
            .map { source in
                RunwayBudgetSourceRow(
                    id: source.id.uuidString,
                    title: source.title,
                    amount: source.amount,
                    dateText: formatDate(source.date),
                    statusText: statusText(source.status),
                    sourceText: localizedSourceType(source.sourceType),
                    reasonText: isArabic
                        ? "مجدول بالفعل كتدفق نقدي منفصل، لذلك لا يضاف مرة أخرى كتقدير ميزانية شهرية."
                        : "Already scheduled as a separate cash outflow, so it is not added again as a monthly budget estimate."
                )
            }
    }

    private func isSameMonth(_ date: Date, year: Int, month: Int) -> Bool {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return components.year == year && components.month == month
    }

    private var emptyRow: some View {
        Text(isArabic ? "لا توجد عناصر داخلة في الحساب." : "No items included.")
            .foregroundStyle(.secondary)
    }

    private func totalRow(total: Double) -> some View {
        HStack {
            Text(isArabic ? "الإجمالي" : "Total")
                .fontWeight(.semibold)

            Spacer()

            Text(store.displayCurrency(total))
                .fontWeight(.semibold)
        }
    }

    private var mismatchWarning: some View {
        Text(isArabic ? "الإجماليات غير متطابقة تمامًا. راجع البنود المحتسبة." : "The totals do not match exactly. Please review the included items.")
            .font(.caption)
            .foregroundStyle(.orange)
    }

    private func totalsMatch(_ breakdownTotal: Double, _ displayedTotal: Double) -> Bool {
        abs(breakdownTotal - displayedTotal) < 0.01
    }

    private func categoryText(for item: RunwayBreakdownItem) -> String {
        let values = [
            item.categoryName.map { AppText.categoryDisplayName($0, language: store.appLanguage) },
            item.subCategoryName.map { AppText.subcategoryDisplayName($0, language: store.appLanguage) }
        ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        return values.isEmpty ? localizedSourceType(item.sourceType) : values.joined(separator: " • ")
    }

    private func statusText(_ status: FinancialEventStatus) -> String {
        switch status {
        case .paid:
            return isArabic ? "مدفوع" : "paid"
        case .unpaid:
            return isArabic ? "غير مدفوع" : "unpaid"
        case .expected:
            return isArabic ? "متوقع" : "expected"
        case .planned:
            return isArabic ? "مجدول" : "scheduled"
        case .cancelled:
            return isArabic ? "ملغي" : "cancelled"
        case .skipped:
            return isArabic ? "متخطي" : "skipped"
        }
    }

    private func localizedSourceType(_ sourceType: String) -> String {
        guard isArabic else {
            return sourceType
        }

        switch sourceType {
        case "Expected income":
            return "دخل متوقع"
        case "Reimbursement":
            return "تعويض"
        case "Debt repayment":
            return "سداد دين"
        case "Other future inflow", "Future inflow":
            return "دخول فلوس مستقبلي"
        case "Future expense":
            return "مصروف قادم"
        case "Obligation":
            return "التزام"
        case "Scheduled item":
            return "بند مجدول"
        case "Recurring":
            return "متكرر"
        case "Installment":
            return "قسط"
        case "Transfer":
            return "تحويل"
        case "Loan / Debt":
            return "قرض / دين"
        default:
            return sourceType
        }
    }

    private func budgetCoverageText(for item: RunwayBudgetBreakdownItem) -> String {
        isArabic
            ? "محسوب للفترة: \(formatDate(item.coveredStart)) - \(formatDate(item.coveredEnd))"
            : "Included for: \(formatDate(item.coveredStart)) - \(formatDate(item.coveredEnd))"
    }

    private func monthTitle(year: Int, month: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
