import SwiftUI

enum RunwayInsightRoute: String, Identifiable {
    case overview
    case nextMonths
    case lowestBalance
    case shortfall

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .overview:
            return language == .arabicEgyptian ? "تفاصيل اختبار الأمان" : "Runway Details"
        case .nextMonths:
            return language == .arabicEgyptian ? "أمان الشهور الجاية" : "Next Months Safety"
        case .lowestBalance:
            return language == .arabicEgyptian ? "أقل رصيد متوقع" : "Lowest Expected Balance"
        case .shortfall:
            return language == .arabicEgyptian ? "العجز عن حد الأمان" : "Safe Balance Shortfall"
        }
    }
}

struct MonthSafetyItem {
    let monthStart: Date
    let status: MonthSafetyStatus
}

enum MonthSafetyStatus {
    case safe
    case tight
    case risk

    func title(language: AppLanguage) -> String {
        switch self {
        case .safe:
            return language == .arabicEgyptian ? "آمن" : "Safe"
        case .tight:
            return language == .arabicEgyptian ? "ضيق" : "Tight"
        case .risk:
            return language == .arabicEgyptian ? "خطر" : "Risk"
        }
    }
}

struct RunwayInsightSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let route: RunwayInsightRoute
    let result: RunwayCheckResult
    let nextMonthSafetyItems: [MonthSafetyItem]

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(explanationText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section(isArabic ? "النتيجة" : "Result") {
                    metricRow(title: isArabic ? "تاريخ الهدف" : "Target date", value: formatDate(result.targetDate))
                    metricRow(title: isArabic ? "الرصيد المتاح الآن" : "Available now", value: store.displayCurrency(result.availableCash))
                    metricRow(title: AppText.keepAtLeast(store.appLanguage), value: store.displayCurrency(result.minimumSafeBalance))
                    metricRow(title: AppText.lowestCashReach(store.appLanguage), value: store.displayCurrency(result.lowestExpectedBalance))

                    if let dangerDate = result.dangerDate {
                        metricRow(title: isArabic ? "ينزل تحت حد الأمان يوم" : "Falls below safe balance on", value: formatDate(dangerDate))
                    }

                    if let cashShortageDate = result.cashShortageDate {
                        metricRow(title: isArabic ? "عجز كاش يوم" : "Cash shortage on", value: formatDate(cashShortageDate))
                    }

                    if let planIncompleteAfter = result.planIncompleteAfter {
                        metricRow(title: isArabic ? "الخطة ناقصة بعد" : "Plan incomplete after", value: formatMonth(planIncompleteAfter))
                    }

                    if result.shortfallToStaySafe > 0 {
                        metricRow(title: isArabic ? "العجز عن حد الأمان" : "Shortfall to stay safe", value: store.displayCurrency(result.shortfallToStaySafe))
                    }
                }

                if route == .nextMonths {
                    Section(isArabic ? "الشهور الجاية" : "Next months") {
                        ForEach(nextMonthSafetyItems, id: \.monthStart) { item in
                            metricRow(
                                title: formatMonth(item.monthStart),
                                value: item.status.title(language: store.appLanguage)
                            )
                        }
                    }
                }

                sourceSection(
                    title: isArabic ? "دخول فلوس داخل الحساب" : "Future cash inflows included",
                    items: result.breakdown.futureCashInflowItems,
                    total: result.breakdown.futureCashInflowTotal
                )

                sourceSection(
                    title: isArabic ? "مصاريف بتاريخ داخل الحساب" : "Dated obligations included",
                    items: result.breakdown.datedObligationItems,
                    total: result.breakdown.datedExpenseTotal
                )

                sourceSection(
                    title: isArabic ? "متكرر/أقساط داخل الحساب" : "Recurring/installments included",
                    items: result.breakdown.recurringInstallmentItems,
                    total: result.breakdown.recurringInstallmentTotal
                )

                monthlyBudgetSourceSection
            }
            .navigationTitle(route.title(language: store.appLanguage))
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

    private var explanationText: String {
        switch route {
        case .overview:
            return isArabic
                ? "عرض فقط لمصادر اختبار الأمان. لا يتم تعديل الرصيد أو تسجيل أي حركة من هنا."
                : "Read-only sources behind the Runway result. This does not change balances or post transactions."
        case .nextMonths:
            return isArabic
                ? "كل شهر محسوب بنفس اختبار الأمان حتى نهاية الشهر."
                : "Each month is checked with the same Runway calculation through that month end."
        case .lowestBalance:
            return isArabic
                ? "أقل رصيد متوقع ناتج من الرصيد الحالي مع البنود المستقبلية والمصاريف المقدرة المعروضة هنا."
                : "The lowest expected balance comes from current cash plus the future items and estimates shown here."
        case .shortfall:
            return isArabic
                ? "العجز هو الفرق المطلوب حتى لا ينزل الرصيد المتوقع تحت حد الأمان."
                : "The shortfall is the amount needed so projected cash does not fall below the safe balance target."
        }
    }

    private func sourceSection(title: String, items: [RunwayBreakdownItem], total: Double) -> some View {
        Section {
            if items.isEmpty {
                Text(isArabic ? "لا توجد عناصر داخلة في الحساب." : "No included source rows.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    sourceRow(item)
                }

                metricRow(title: isArabic ? "الإجمالي" : "Total", value: store.displayCurrency(total))
            }
        } header: {
            Text(title)
        }
    }

    private var monthlyBudgetSourceSection: some View {
        Section {
            if result.breakdown.monthlyBudgetItems.isEmpty {
                Text(isArabic ? "لا توجد تقديرات ميزانية شهرية داخلة في الحساب." : "No monthly budget estimates included.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(result.breakdown.monthlyBudgetItems) { item in
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
                    }
                    .padding(.vertical, 3)
                }

                metricRow(title: isArabic ? "الإجمالي" : "Total", value: store.displayCurrency(result.breakdown.monthlyEstimateTotal))
            }
        } header: {
            Text(isArabic ? "تقدير الميزانية الشهرية" : "Monthly budget estimate")
        }
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
                    sourceText: source.sourceType,
                    reasonText: isArabic
                        ? "مجدول بالفعل كتدفق نقدي منفصل، لذلك لا يضاف مرة أخرى كتقدير ميزانية شهرية."
                        : "Already scheduled as a separate cash outflow, so it is not added again as a monthly budget estimate."
                )
            }
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

    private func isSameMonth(_ date: Date, year: Int, month: Int) -> Bool {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return components.year == year && components.month == month
    }

    private func sourceRow(_ item: RunwayBreakdownItem) -> some View {
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

            Text("\(formatDate(item.date)) • \(item.sourceType)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }

    private func categoryText(for item: RunwayBreakdownItem) -> String {
        let values = [
            item.categoryName.map { AppText.categoryDisplayName($0, language: store.appLanguage) },
            item.subCategoryName.map { AppText.subcategoryDisplayName($0, language: store.appLanguage) }
        ]
            .compactMap { $0 }
            .filter { !$0.isEmpty }

        return values.isEmpty ? item.sourceType : values.joined(separator: " • ")
    }

    private func monthTitle(year: Int, month: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        return formatMonth(date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}
