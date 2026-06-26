import SwiftUI

struct CategoryUpcomingBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let selection: CategoryUpcomingSelection

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var items: [FinancialEvent] {
        store.upcomingKnownExpenseEvents(year: selection.year, month: selection.month)
            .filter { ($0.categoryName ?? "Uncategorized") == selection.categoryName }
            .sorted {
                if $0.date == $1.date {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }

                return $0.date < $1.date
            }
    }

    private var breakdownTotal: Double {
        items.map { $0.recurringAmount(for: $0.date) }.reduce(0, +)
    }

    private var totalMatches: Bool {
        abs(breakdownTotal - selection.displayedAmount) < 0.01
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    detailRow(title: isArabic ? "الشهر" : "Month", value: BudgetDateHelper.monthTitle(selection.monthDate))
                    detailRow(title: isArabic ? "البند" : "Category", value: selection.categoryName)
                    detailRow(title: AppText.upcoming(store.appLanguage), value: store.displayCurrency(selection.displayedAmount))
                }

                Section {
                    if items.isEmpty {
                        Text(isArabic ? "لا توجد بنود قادمة لهذا البند في الشهر المختار." : "No upcoming source items found for this category in the selected month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            if canNavigate(item) {
                                NavigationLink {
                                    destination(for: item)
                                } label: {
                                    upcomingRow(item)
                                }
                            } else {
                                upcomingRow(item)
                            }
                        }
                    }
                } header: {
                    Text(isArabic ? "مصادر القادم" : "Upcoming Sources")
                } footer: {
                    Text(isArabic ? "عرض فقط. لا يتم تسجيل دفع أو تعديل أي التزام من هنا." : "Read-only. This does not mark anything paid or change any commitment.")
                }

                Section {
                    detailRow(title: isArabic ? "إجمالي التفاصيل" : "Source Total", value: store.displayCurrency(breakdownTotal))

                    if !totalMatches {
                        Text(isArabic ? "إجمالي التفاصيل لا يطابق رقم القادم. برجاء مراجعة مصدر الحساب." : "Breakdown total does not match the Upcoming value. Please review the source logic.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(isArabic ? "تفاصيل القادم" : "Upcoming Breakdown")
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

    private func upcomingRow(_ item: FinancialEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NamedVisualMark(
                name: item.title,
                fallbackSystemImage: sourceIcon(for: item),
                size: 32
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(sourceType(for: item))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(statusText(for: item))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(store.displayCurrency(item.recurringAmount(for: item.date)))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(formatDate(item.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func destination(for item: FinancialEvent) -> some View {
        if let sourceID = item.sourceRecurringEventID,
           store.activeFinancialEvents.contains(where: { $0.id == sourceID }) {
            RecurringSeriesDetailView(eventID: sourceID)
                .environmentObject(store)
        } else if let planID = item.sourceInstallmentPlanID,
                  let plan = store.activeInstallmentPlans.first(where: { $0.id == planID }) {
            InstallmentPlanEditorView(plan: plan)
                .environmentObject(store)
        } else if item.repeatRule != .none {
            RecurringPaymentEditorView(event: item)
                .environmentObject(store)
        } else if item.sourceInstallmentPlanID == nil &&
                    item.sourceRecurringEventID == nil &&
                    item.repeatRule == .none {
            TransactionDetailView(event: item, isPresentedModally: false)
                .environmentObject(store)
        }
    }

    private func canNavigate(_ item: FinancialEvent) -> Bool {
        if let sourceID = item.sourceRecurringEventID,
           store.activeFinancialEvents.contains(where: { $0.id == sourceID }) {
            return true
        }

        if let planID = item.sourceInstallmentPlanID,
           store.activeInstallmentPlans.contains(where: { $0.id == planID }) {
            return true
        }

        if item.repeatRule != .none {
            return true
        }

        return item.sourceInstallmentPlanID == nil &&
        item.sourceRecurringEventID == nil &&
        item.repeatRule == .none
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }

    private func sourceType(for item: FinancialEvent) -> String {
        if item.sourceInstallmentPlanID != nil {
            return isArabic ? "قسط" : "Installment"
        }

        if item.sourceRecurringEventID != nil || item.repeatRule != .none {
            return isArabic ? "دفع متكرر" : "Recurring"
        }

        if item.type == .expectedExpense {
            return isArabic ? "مصروف مستقبلي" : "Future item"
        }

        if item.type == .obligation {
            return isArabic ? "التزام مرة واحدة" : "One-off obligation"
        }

        return isArabic ? "بند قادم" : "Upcoming item"
    }

    private func statusText(for item: FinancialEvent) -> String {
        if item.sourceRecurringEventID != nil {
            if item.recurringScheduleOverrides?.contains(where: { override in
                override.year == item.recurringOccurrenceYear && override.month == item.recurringOccurrenceMonth
            }) == true {
                return isArabic ? "مؤكد" : "confirmed"
            }

            if item.effectiveRecurringAmountMode != .fixedAmount {
                return isArabic ? "تقديري" : "estimated"
            }
        }

        switch item.status {
        case .paid:
            return isArabic ? "مدفوع" : "paid"
        case .unpaid:
            return isArabic ? "غير مدفوع" : "unpaid"
        case .expected:
            return isArabic ? "متوقع" : "expected"
        case .planned:
            return isArabic ? "مخطط" : "planned"
        case .cancelled:
            return isArabic ? "ملغي" : "cancelled"
        case .skipped:
            return isArabic ? "متخطي" : "skipped"
        }
    }

    private func sourceIcon(for item: FinancialEvent) -> String {
        if item.sourceInstallmentPlanID != nil {
            return "creditcard.fill"
        }

        if item.sourceRecurringEventID != nil || item.repeatRule != .none {
            return "repeat"
        }

        return "calendar.badge.clock"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

struct BudgetCommittedBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let selection: BudgetCellSelection

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var items: [FinancialEvent] {
        store.upcomingKnownExpenseEvents(year: selection.year, month: selection.month)
            .filter { ($0.categoryName ?? "Uncategorized") == selection.categoryName }
            .sorted {
                if $0.date == $1.date {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }

                return $0.date < $1.date
            }
    }

    private var breakdownTotal: Double {
        items.map(\.amount).reduce(0, +)
    }

    private var totalMatches: Bool {
        abs(breakdownTotal - selection.knownUpcomingAmount) < 0.01
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if items.isEmpty {
                        Text(isArabic ? "لا توجد تفاصيل لهذا الرقم." : "No committed source items found for this amount.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            breakdownRow(item)
                        }
                    }
                } header: {
                    Text(selection.categoryName)
                } footer: {
                    Text(isArabic ? "عرض فقط. لا يتم تسجيل دفع أو تعديل أي التزام من هنا." : "Read-only. This does not mark anything paid or change any commitment.")
                }

                Section {
                    HStack {
                        Text(isArabic ? "إجمالي الالتزامات" : "Total committed")
                        Spacer()
                        Text(store.displayCurrency(breakdownTotal))
                            .fontWeight(.semibold)
                    }

                    if !totalMatches {
                        Text(isArabic ? "إجمالي التفاصيل لا يطابق رقم الالتزامات. برجاء مراجعة مصدر الحساب." : "Breakdown total does not match committed total. Please review committed source logic.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(isArabic ? "تفاصيل الالتزامات" : "Committed Breakdown")
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

    private func breakdownRow(_ item: FinancialEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NamedVisualMark(
                name: item.title,
                fallbackSystemImage: sourceIcon(for: item),
                size: 32
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(sourceType(for: item))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(statusText(for: item))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(store.displayCurrency(item.amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(formatDate(item.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func sourceType(for item: FinancialEvent) -> String {
        if item.sourceInstallmentPlanID != nil {
            return isArabic ? "قسط" : "Installment"
        }

        if item.sourceRecurringEventID != nil || item.repeatRule != .none {
            return isArabic ? "دفع متكرر" : "Recurring Payment"
        }

        if item.type == .expectedExpense {
            return isArabic ? "مصروف مستقبلي" : "Future Expense"
        }

        return isArabic ? "مصدر ملتزم" : "Other committed source"
    }

    private func statusText(for item: FinancialEvent) -> String {
        if item.recurringOccurrenceYear != nil {
            if item.recurringScheduleOverrides?.contains(where: { override in
                override.year == item.recurringOccurrenceYear && override.month == item.recurringOccurrenceMonth
            }) == true {
                return isArabic ? "مؤكد" : "confirmed"
            }

            if item.effectiveRecurringAmountMode != .fixedAmount {
                return isArabic ? "تقديري" : "estimated"
            }
        }

        return isArabic ? "مجدول / غير مدفوع" : "scheduled / unpaid"
    }

    private func sourceIcon(for item: FinancialEvent) -> String {
        if item.sourceInstallmentPlanID != nil {
            return "creditcard.fill"
        }

        if item.sourceRecurringEventID != nil || item.repeatRule != .none {
            return "repeat"
        }

        return "calendar.badge.clock"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

struct BudgetPaidBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let selection: BudgetCellSelection

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var items: [ActualSpendingBreakdownItem] {
        store.actualSpendingBreakdownItems(
            year: selection.year,
            month: selection.month,
            categoryName: selection.categoryName
        )
    }

    private var breakdownTotal: Double {
        items.map(\.amount).reduce(0, +)
    }

    private var totalMatches: Bool {
        abs(breakdownTotal - selection.paidActualAmount) < 0.01
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    detailRow(title: isArabic ? "الشهر" : "Month", value: BudgetDateHelper.monthTitle(selection.date))
                    detailRow(title: isArabic ? "البند" : "Category", value: selection.categoryName)
                    detailRow(title: isArabic ? "إجمالي المدفوع" : "Total Paid", value: store.displayCurrency(selection.paidActualAmount))
                }

                Section {
                    if items.isEmpty {
                        Text(isArabic ? "مفيش معاملات مدفوعة في البند ده خلال الشهر ده." : "No paid transactions found for this category in this month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            paidBreakdownRow(item)
                        }
                    }
                } header: {
                    Text(isArabic ? "المعاملات المدفوعة" : "Paid Transactions")
                } footer: {
                    Text(isArabic ? "عرض فقط. لا يتم تعديل أو حذف معاملات من هنا." : "Read-only. This does not edit or delete transactions.")
                }

                Section {
                    HStack {
                        Text(isArabic ? "إجمالي المدفوع" : "Total Paid")
                        Spacer()
                        Text(store.displayCurrency(breakdownTotal))
                            .fontWeight(.semibold)
                    }

                    if !totalMatches {
                        Text(isArabic ? "إجمالي التفاصيل لا يطابق رقم المدفوع. برجاء مراجعة مصدر الحساب." : "Breakdown total does not match Paid So Far. Please review the source logic.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(isArabic ? "تفاصيل المدفوع" : "Paid Breakdown")
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

    private func paidBreakdownRow(_ item: ActualSpendingBreakdownItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NamedVisualMark(
                name: item.title,
                fallbackSystemImage: iconName(for: item),
                size: 32
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(item.categoryName) / \(item.subCategoryName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(metaText(for: item))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(store.displayCurrency(item.amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(formatDateTime(item.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }

    private func metaText(for item: ActualSpendingBreakdownItem) -> String {
        [
            item.transactionType,
            item.paymentMethodName,
            item.accountName
        ]
        .compactMap { value in
            guard let value,
                  !value.isEmpty else {
                return nil
            }

            return value
        }
        .joined(separator: " • ")
    }

    private func iconName(for item: ActualSpendingBreakdownItem) -> String {
        switch item.source {
        case .creditCardPurchase:
            return "creditcard.fill"
        case .financialEvent:
            if item.transactionType == FinancialEventType.obligation.rawValue {
                return "calendar.circle.fill"
            }
            if item.transactionType == FinancialEventType.installment.rawValue {
                return "creditcard.and.123"
            }
            return "creditcard.fill"
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
    }
}

struct ActualSpentBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let monthDate: Date
    let displayedAmount: Double

    private var monthKey: (year: Int, month: Int) {
        BudgetDateHelper.monthKey(for: monthDate)
    }

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var items: [ActualSpendingBreakdownItem] {
        store.actualSpendingBreakdownItems(year: monthKey.year, month: monthKey.month, categoryName: nil)
    }

    private var sourceTotal: Double {
        items.map(\.amount).reduce(0, +)
    }

    private var totalMatches: Bool {
        abs(sourceTotal - displayedAmount) < 0.01
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabelValueRow(
                        title: isArabic ? "الشهر" : "Month",
                        value: BudgetDateHelper.monthTitle(monthDate)
                    )
                    LabelValueRow(
                        title: isArabic ? "المصروف الفعلي" : "Actual Spent",
                        value: store.displayCurrency(displayedAmount)
                    )
                    LabelValueRow(
                        title: isArabic ? "إجمالي المصادر" : "Source Total",
                        value: store.displayCurrency(sourceTotal)
                    )

                    if !totalMatches {
                        Text(isArabic ? "إجمالي المصادر لا يطابق رقم المصروف الفعلي." : "Source total does not match the Actual Spent card value.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    if items.isEmpty {
                        Text(isArabic ? "مفيش مصروف فعلي مسجل للشهر ده." : "No actual spending source rows for this month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            if let event = financialEvent(for: item) {
                                NavigationLink {
                                    TransactionDetailView(event: event, isPresentedModally: false)
                                        .environmentObject(store)
                                } label: {
                                    actualSpentRow(item)
                                }
                            } else {
                                actualSpentRow(item)
                            }
                        }
                    }
                } header: {
                    Text(isArabic ? "مصادر المصروف الفعلي" : "Actual Spending Sources")
                } footer: {
                    Text(isArabic ? "نفس مصادر رقم المصروف الفعلي. مدفوعات كروت الائتمان كتسوية مش بتظهر هنا إلا لو مصدر الحساب نفسه ضافها." : "Uses the same source as the Actual Spent value. Credit card settlement payments do not appear unless the actual-spending helper includes them.")
                }
            }
            .navigationTitle(isArabic ? "المصروف الفعلي" : "Actual Spent")
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

    private func actualSpentRow(_ item: ActualSpendingBreakdownItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NamedVisualMark(
                name: item.title,
                fallbackSystemImage: sourceIcon(for: item),
                size: 32
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(item.categoryName) / \(item.subCategoryName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(sourceText(for: item))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(store.displayCurrency(item.amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(formatDate(item.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func financialEvent(for item: ActualSpendingBreakdownItem) -> FinancialEvent? {
        guard item.source == .financialEvent,
              item.id.hasPrefix("event-") else {
            return nil
        }

        let uuidString = String(item.id.dropFirst("event-".count))
        guard let eventID = UUID(uuidString: uuidString) else {
            return nil
        }

        return store.activeFinancialEvents.first { $0.id == eventID }
    }

    private func sourceText(for item: ActualSpendingBreakdownItem) -> String {
        switch item.source {
        case .creditCardPurchase:
            return isArabic ? "مشتريات كارت ائتمان" : "Credit card purchase"
        case .financialEvent:
            var parts = [item.transactionType]
            if let paymentMethodName = item.paymentMethodName,
               !paymentMethodName.isEmpty {
                parts.append(paymentMethodName)
            }
            if let accountName = item.accountName,
               !accountName.isEmpty {
                parts.append(accountName)
            }
            return parts.joined(separator: " • ")
        }
    }

    private func sourceIcon(for item: ActualSpendingBreakdownItem) -> String {
        switch item.source {
        case .creditCardPurchase:
            return "creditcard"
        case .financialEvent:
            if item.transactionType.caseInsensitiveCompare("Installment") == .orderedSame {
                return "creditcard.and.123"
            }

            return "banknote"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

struct AfterCommittedBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore
    let monthDate: Date

    private var monthKey: (year: Int, month: Int) {
        BudgetDateHelper.monthKey(for: monthDate)
    }

    private var plannedByCategory: [String: Double] {
        Dictionary(uniqueKeysWithValues: (store.monthlyBudget(year: monthKey.year, month: monthKey.month)?.items ?? []).map { ($0.categoryName, $0.plannedAmount) })
    }

    private var paidByCategory: [String: Double] {
        store.actualSpendingByCategory(year: monthKey.year, month: monthKey.month)
    }

    private var upcomingByCategory: [String: Double] {
        store.upcomingKnownExpensesByCategory(year: monthKey.year, month: monthKey.month)
    }

    private var allCategoryNames: [String] {
        var names: [String] = []
        for name in Array(plannedByCategory.keys) + Array(paidByCategory.keys) + Array(upcomingByCategory.keys) {
            if !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                names.append(name)
            }
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var plannedCategoryNames: [String] {
        allCategoryNames.filter { (plannedByCategory[$0] ?? 0) > 0 }
    }

    private var paidCategoryNames: [String] {
        allCategoryNames.filter { (paidByCategory[$0] ?? 0) > 0 }
    }

    private var upcomingCategoryNames: [String] {
        allCategoryNames.filter { (upcomingByCategory[$0] ?? 0) > 0 }
    }

    private var creditCardDueItems: [CreditCardDueItem] {
        CreditCardDueCashCommitmentHelper.dueItems(store: store, year: monthKey.year, month: monthKey.month)
    }

    private var creditCardDueTotal: Double {
        creditCardDueItems.map(\.dueAmount).reduce(0, +)
    }

    private var totalPlanned: Double {
        allCategoryNames.map { plannedByCategory[$0] ?? 0 }.reduce(0, +)
    }

    private var totalPaid: Double {
        allCategoryNames.map { paidByCategory[$0] ?? 0 }.reduce(0, +)
    }

    private var totalUpcoming: Double {
        allCategoryNames.map { upcomingByCategory[$0] ?? 0 }.reduce(0, +) + creditCardDueTotal
    }

    private var afterCommitted: Double {
        totalPlanned - totalPaid - totalUpcoming
    }

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabelValueRow(
                        title: isArabic ? "الشهر" : "Month",
                        value: BudgetDateHelper.monthTitle(monthDate)
                    )
                    LabelValueRow(
                        title: isArabic ? "المعادلة" : "Formula",
                        value: isArabic ? "مخطط − مدفوع − ملتزم به" : "Planned − Paid − Committed"
                    )
                }

                Section {
                    if plannedCategoryNames.isEmpty {
                        Text(isArabic ? "مفيش ميزانية محددة للشهر ده." : "No budget plan for this month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(plannedCategoryNames, id: \.self) { category in
                            LabelValueRow(title: category, value: store.displayCurrency(plannedByCategory[category] ?? 0))
                        }
                    }
                    LabelValueRow(title: isArabic ? "الإجمالي" : "Total", value: store.displayCurrency(totalPlanned))
                } header: {
                    Text(isArabic ? "المصاريف المخططة" : "Planned Expenses")
                } footer: {
                    Text(isArabic ? "من ميزانية الشهر المخططة." : "From the monthly budget plan.")
                }

                Section {
                    if paidCategoryNames.isEmpty {
                        Text(isArabic ? "مفيش مصاريف مسجلة للشهر ده." : "Nothing paid yet this month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(paidCategoryNames, id: \.self) { category in
                            LabelValueRow(title: category, value: store.displayCurrency(paidByCategory[category] ?? 0))
                        }
                    }
                    LabelValueRow(title: isArabic ? "الإجمالي" : "Total", value: store.displayCurrency(totalPaid))
                } header: {
                    Text(isArabic ? "− المصروف الفعلي" : "− Actual Spent")
                } footer: {
                    Text(isArabic ? "مصاريف مدفوعة ومشتريات بالبطاقة. للتفاصيل، ارجع للشاشة الرئيسية واضغط 'المصروف الفعلي'." : "Posted transactions and credit card purchases. For individual rows, tap Actual Spent on the main screen.")
                }

                Section {
                    if upcomingCategoryNames.isEmpty {
                        Text(isArabic ? "مفيش التزامات قادمة للشهر ده." : "No upcoming commitments this month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(upcomingCategoryNames, id: \.self) { category in
                            LabelValueRow(title: category, value: store.displayCurrency(upcomingByCategory[category] ?? 0))
                        }
                    }
                    if !creditCardDueItems.isEmpty {
                        ForEach(creditCardDueItems) { item in
                            LabelValueRow(
                                title: "\(item.cardName) \(isArabic ? "مستحق كارت" : "Card due")",
                                value: store.displayCurrency(item.dueAmount)
                            )
                        }
                    }
                    LabelValueRow(title: isArabic ? "الإجمالي" : "Total", value: store.displayCurrency(totalUpcoming))
                } header: {
                    Text(isArabic ? "− الملتزم به" : "− Committed")
                } footer: {
                    Text(isArabic ? "مصاريف مجدولة غير مدفوعة ومستحقات كروت ائتمان كالتزام كاش. مستحق الكارت مش مصروف جديد." : "Scheduled unpaid commitments plus credit card dues as cash obligations. Card dues are not new spending.")
                }

                Section {
                    HStack {
                        Text(isArabic ? "= بعد الملتزم به" : "= After Committed")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(store.displayCurrency(abs(afterCommitted)))
                            .fontWeight(.bold)
                            .foregroundStyle(afterCommitted >= 0 ? Color.green : Color.red)
                    }
                } footer: {
                    Text(isArabic
                         ? (afterCommitted >= 0 ? "هامش متبقي في الميزانية بعد المدفوع والملتزم به." : "تجاوزت الميزانية بعد حساب المدفوع والملتزم به.")
                         : (afterCommitted >= 0 ? "Budget headroom remaining after paid and committed expenses." : "Over budget after accounting for paid and committed expenses."))
                }
            }
            .navigationTitle(isArabic ? "بعد الملتزم به" : "After Committed")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

