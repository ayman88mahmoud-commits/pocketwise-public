import SwiftUI

struct ObligationsCenterView: View {

    @EnvironmentObject private var store: WalletStore

    private var recurringPayments: [RecurringObligationPreview] {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()

        return (0..<12)
            .compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
            .flatMap { monthDate -> [RecurringObligationPreview] in
                let components = calendar.dateComponents([.year, .month], from: monthDate)
                guard let year = components.year, let month = components.month else {
                    return []
                }

                return store.upcomingKnownExpenseEvents(year: year, month: month)
                    .compactMap { occurrence in
                        guard let sourceID = occurrence.sourceRecurringEventID,
                              let source = store.activeFinancialEvents.first(where: { $0.id == sourceID }) else {
                            return nil
                        }

                        return RecurringObligationPreview(source: source, occurrence: occurrence)
                    }
            }
            .sorted { $0.occurrence.date < $1.occurrence.date }
    }

    private var installmentPlans: [InstallmentPlan] {
        store.activeInstallmentPlans.sorted {
            let first = store.installmentPlanSummary(for: $0).nextDueDate ?? $0.firstDueDate
            let second = store.installmentPlanSummary(for: $1).nextDueDate ?? $1.firstDueDate
            return first < second
        }
    }

    private var creditCardDueItems: [CreditCardDueItem] {
        store.creditCardDueItems(referenceDate: Date(), horizonMonths: store.forecastHorizonMonths)
    }

    private var futureExpenseItems: [FinancialEvent] {
        store.activeFinancialEvents
            .filter { event in
                event.repeatRule == .none &&
                event.sourceInstallmentPlanID == nil &&
                event.status != .paid &&
                event.status != .cancelled &&
                event.type != .income &&
                event.type != .transfer
            }
            .sorted { $0.date < $1.date }
    }

    private var expectedIncomeItems: [FinancialEvent] {
        store.activeFinancialEvents
            .filter { event in
                event.repeatRule == .none &&
                event.status != .paid &&
                event.status != .cancelled &&
                event.type == .income
            }
            .sorted { $0.date < $1.date }
    }

    private var expectedRepayments: [FinancialEvent] {
        store.expectedRepaymentEvents().sorted { $0.date < $1.date }
    }

    private var recurringUpcomingTotal: Double {
        recurringPayments.map(\.occurrence.amount).reduce(0, +)
    }

    private var installmentRemainingTotal: Double {
        installmentPlans
            .map { store.installmentPlanSummary(for: $0).remainingUnpaidAmount }
            .reduce(0, +)
    }

    private var creditCardDueTotal: Double {
        creditCardDueItems.map(\.dueAmount).reduce(0, +)
    }

    private var futureExpenseTotal: Double {
        futureExpenseItems.map(\.amount).reduce(0, +)
    }

    private var expectedIncomeTotal: Double {
        expectedIncomeItems.map(\.amount).reduce(0, +)
    }

    private var expectedRepaymentTotal: Double {
        expectedRepayments.map(\.amount).reduce(0, +)
    }

    var body: some View {
        List {
            Section {
                Text(store.appLanguage == .arabicEgyptian ? "التزامات قادمة، فلوس داخلة متوقعة، وسداد." : "Upcoming commitments, expected money in, and repayments.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                if recurringPayments.isEmpty {
                    emptyText(store.appLanguage == .arabicEgyptian ? "مفيش التزامات متكررة." : "No recurring obligations.")
                } else {
                    ForEach(recurringPayments) { preview in
                        NavigationLink {
                            RecurringSeriesDetailView(eventID: preview.source.id)
                                .environmentObject(store)
                        } label: {
                            obligationRow(
                                icon: "repeat",
                                title: preview.occurrence.title,
                                amount: preview.occurrence.amount,
                                date: preview.occurrence.date,
                                subtitle: "\(preview.source.repeatRule.rawValue) • \(preview.occurrence.subCategoryName ?? preview.occurrence.categoryName ?? preview.occurrence.type.rawValue)",
                                status: recurringStatus(for: preview.occurrence)
                            )
                        }
                    }
                }
            } header: {
                recurringSummaryHeader
            }

            Section(
                summaryHeader(
                    title: AppText.installments(store.appLanguage),
                    count: installmentPlans.count,
                    amount: installmentRemainingTotal,
                    qualifier: AppText.remainingUnpaid(store.appLanguage)
                )
            ) {
                if installmentPlans.isEmpty {
                    emptyText(store.appLanguage == .arabicEgyptian ? "مفيش خطط تقسيط." : "No installment plans.")
                } else {
                    ForEach(installmentPlans) { plan in
                        NavigationLink {
                            InstallmentPlanEditorView(plan: plan)
                                .environmentObject(store)
                        } label: {
                            let summary = store.installmentPlanSummary(for: plan)
                            obligationRow(
                                icon: "creditcard.and.123",
                                title: "\(plan.paymentMethodName) - \(plan.purchaseName)",
                                amount: plan.monthlyAmount,
                                date: summary.nextDueDate ?? plan.firstDueDate,
                                subtitle: "\(summary.paidCount) paid of \(summary.totalCount) • \(plan.subCategoryName)",
                                status: summary.remainingUnpaidAmount > 0 ? activeText : endedText
                            )
                        }
                    }
                }
            }

            Section(
                summaryHeader(
                    title: store.appLanguage == .arabicEgyptian ? "مستحقات كروت الائتمان" : "Credit Card Dues",
                    count: creditCardDueItems.count,
                    amount: creditCardDueTotal,
                    qualifier: store.appLanguage == .arabicEgyptian ? "مستحق" : "due"
                )
            ) {
                if creditCardDueItems.isEmpty {
                    emptyText(store.appLanguage == .arabicEgyptian ? "مفيش مستحقات كروت ائتمان غير مدفوعة." : "No unpaid credit card dues.")
                } else {
                    ForEach(creditCardDueItems) { item in
                        obligationRow(
                            icon: "creditcard.trianglebadge.exclamationmark",
                            title: item.cardName,
                            amount: item.dueAmount,
                            date: item.dueDate,
                            subtitle: store.appLanguage == .arabicEgyptian
                            ? "التزام كاش لسداد الكارت - مش مصروف جديد"
                            : "Cash obligation to pay the card - not new spending",
                            status: creditCardDueStatus(for: item.dueDate)
                        )
                    }
                }
            }

            Section(
                summaryHeader(
                    title: store.appLanguage == .arabicEgyptian ? "بنود مخططة / غير مدفوعة" : "Planned / Unpaid Items",
                    count: futureExpenseItems.count,
                    amount: futureExpenseTotal,
                    qualifier: AppText.planned(store.appLanguage).lowercased()
                )
            ) {
                if futureExpenseItems.isEmpty {
                    emptyText(store.appLanguage == .arabicEgyptian ? "مفيش بنود مخططة أو غير مدفوعة." : "No planned or unpaid items.")
                } else {
                    ForEach(futureExpenseItems) { event in
                        NavigationLink {
                            TransactionDetailView(event: event, isPresentedModally: false)
                                .environmentObject(store)
                        } label: {
                            obligationRow(
                                icon: "calendar",
                                title: event.title,
                                amount: event.amount,
                                date: event.date,
                                subtitle: event.subCategoryName ?? event.categoryName ?? event.type.rawValue,
                                status: event.status.rawValue
                            )
                        }
                    }
                }
            }

            Section(
                summaryHeader(
                    title: AppText.expectedIncome(store.appLanguage),
                    count: expectedIncomeItems.count,
                    amount: expectedIncomeTotal,
                    qualifier: AppText.total(store.appLanguage)
                )
            ) {
                if expectedIncomeItems.isEmpty {
                    emptyText(store.appLanguage == .arabicEgyptian ? "مفيش دخل متوقع." : "No expected income.")
                } else {
                    ForEach(expectedIncomeItems) { event in
                        NavigationLink {
                            TransactionDetailView(event: event, isPresentedModally: false)
                                .environmentObject(store)
                        } label: {
                            obligationRow(
                                icon: "arrow.down.circle",
                                title: event.title,
                                amount: event.amount,
                                date: event.date,
                                subtitle: event.effectiveIncomeType.title(language: store.appLanguage),
                                status: event.status.rawValue
                            )
                        }
                    }
                }
            }

            Section(
                summaryHeader(
                    title: AppText.peopleDebts(store.appLanguage),
                    count: expectedRepayments.count,
                    amount: expectedRepaymentTotal,
                    qualifier: AppText.total(store.appLanguage)
                )
            ) {
                if !expectedRepayments.isEmpty {
                    ForEach(expectedRepayments) { event in
                        NavigationLink {
                            PeopleDebtsView()
                                .environmentObject(store)
                        } label: {
                            obligationRow(
                                icon: "person.2",
                                title: event.title,
                                amount: event.amount,
                                date: event.date,
                                subtitle: store.appLanguage == .arabicEgyptian ? "سداد متوقع" : "Expected repayment",
                                status: peopleDebtDueStatus(for: event.date)
                            )
                        }
                    }
                }

                NavigationLink {
                    PeopleDebtsView()
                        .environmentObject(store)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.headline)
                            .frame(width: 34, height: 34)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.appLanguage == .arabicEgyptian ? "افتح الأشخاص والديون" : "Open People & Debts")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(store.appLanguage == .arabicEgyptian ? "إدارة السلف، الديون، والسداد" : "Manage money lent, borrowed, and repayments")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "مركز التخطيط" : "Planning Center")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summaryHeader(title: String, count: Int, amount: Double, qualifier: String) -> String {
        "\(title) • \(count) • \(store.displayCurrency(amount)) \(qualifier)"
    }

    private var recurringSummaryHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(store.appLanguage == .arabicEgyptian ? "دفعات متكررة قادمة" : "Upcoming recurring payments") • \(recurringPayments.count)")
            Text("\(store.appLanguage == .arabicEgyptian ? "الـ ١٢ شهر الجايين" : "Next 12 months") • \(store.displayCurrency(recurringUpcomingTotal))")
            Text(store.appLanguage == .arabicEgyptian ? "مولدة من قواعد الدفع المتكرر. المدفوع والمتخطي غير محسوب هنا." : "Generated from recurring rules. Paid and skipped occurrences are not included here.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }

    private var activeText: String {
        store.appLanguage == .arabicEgyptian ? "نشط" : "Active"
    }

    private var upcomingPaymentText: String {
        store.appLanguage == .arabicEgyptian ? "دفعة قادمة" : "Upcoming payment"
    }

    private var endedText: String {
        store.appLanguage == .arabicEgyptian ? "منتهي" : "Ended"
    }

    private var overdueText: String {
        store.appLanguage == .arabicEgyptian ? "متأخر" : "Overdue"
    }

    private func peopleDebtDueStatus(for date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())

        if day < today {
            return overdueText
        }

        if day == today {
            return store.appLanguage == .arabicEgyptian ? "مستحق اليوم" : "Due today"
        }

        return upcomingPaymentText
    }

    private func creditCardDueStatus(for date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())
        let dueSoonEnd = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today

        if day < today {
            return overdueText
        }

        if day == today {
            return store.appLanguage == .arabicEgyptian ? "مستحق اليوم" : "Due today"
        }

        if day < dueSoonEnd {
            return store.appLanguage == .arabicEgyptian ? "قريب" : "Due soon"
        }

        return store.appLanguage == .arabicEgyptian ? "غير مدفوع" : "Unpaid"
    }

    private func obligationRow(icon: String, title: String, amount: Double, date: Date, subtitle: String, status: String) -> some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(
                systemName: icon,
                semanticColor: .obligations,
                size: 34,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(store.displayCurrency(amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(PocketWiseSemanticColor.obligations.tint)

                Text(formatDate(date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(status)
                    .pocketWiseChip(semanticColor: .obligations)
            }
        }
        .padding(.vertical, 4)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }

    private func recurringStatus(for event: FinancialEvent) -> String {
        if event.isRecurringOccurrenceSkipped(on: event.date) {
            return store.appLanguage == .arabicEgyptian ? "متخطي" : "Skipped"
        }

        if event.effectiveRecurringAmountMode != .fixedAmount {
            return store.appLanguage == .arabicEgyptian ? "يحتاج تأكيد" : "Needs confirmation"
        }

        return upcomingPaymentText
    }

    private func nextDate(for event: FinancialEvent) -> Date? {
        RecurringSeriesDateHelper.nextOccurrence(for: event, from: Date())
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

struct RecurringObligationPreview: Identifiable {
    let source: FinancialEvent
    let occurrence: FinancialEvent

    var id: String {
        "\(source.id.uuidString)-\(occurrence.recurringOccurrenceYear ?? 0)-\(occurrence.recurringOccurrenceMonth ?? 0)"
    }
}

