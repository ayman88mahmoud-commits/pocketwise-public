import SwiftUI

struct CommitmentsView: View {

    @EnvironmentObject private var store: WalletStore
    @State private var selectedCreditCardPaymentRoute: CreditCardPaymentRoute?

    private var commitmentItems: [CommitmentItem] {
        store.financialEvents
            .filter { event in
                event.status != .paid &&
                event.status != .cancelled &&
                event.status != .skipped &&
                event.type != .income &&
                event.type != .transfer &&
                event.allowsRecurringOccurrence(on: event.date, occurrenceNumber: 1) &&
                !event.isRecurringOccurrenceSkipped(on: event.date)
            }
            .map { event in
                CommitmentItem(event: event, installmentProgressText: store.installmentProgressText(for: event))
            }
            .sorted { $0.date < $1.date }
    }

    private var dueSoonItems: [CommitmentItem] {
        commitmentItems.filter { item in
            item.date < startOfTomorrow(daysFromNow: 8)
        }
    }

    private var creditCardDueItems: [CreditCardDueItem] {
        store.creditCardDueItems(referenceDate: Date(), horizonMonths: store.forecastHorizonMonths)
    }

    private var dueSoonCreditCardDueItems: [CreditCardDueItem] {
        creditCardDueItems.filter { item in
            item.dueDate < startOfTomorrow(daysFromNow: 8)
        }
    }

    private var thisMonthItems: [CommitmentItem] {
        commitmentItems.filter { item in
            item.date >= startOfTomorrow(daysFromNow: 8) &&
            Calendar.current.isDate(item.date, equalTo: Date(), toGranularity: .month)
        }
    }

    private var thisMonthCreditCardDueItems: [CreditCardDueItem] {
        creditCardDueItems.filter { item in
            item.dueDate >= startOfTomorrow(daysFromNow: 8) &&
            Calendar.current.isDate(item.dueDate, equalTo: Date(), toGranularity: .month)
        }
    }

    private var laterItems: [CommitmentItem] {
        commitmentItems.filter { item in
            item.date >= startOfTomorrow(daysFromNow: 8) &&
            !Calendar.current.isDate(item.date, equalTo: Date(), toGranularity: .month)
        }
    }

    private var laterCreditCardDueItems: [CreditCardDueItem] {
        creditCardDueItems.filter { item in
            item.dueDate >= startOfTomorrow(daysFromNow: 8) &&
            !Calendar.current.isDate(item.dueDate, equalTo: Date(), toGranularity: .month)
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.appLanguage == .arabicEgyptian ? "التزامات جاية" : "Upcoming fixed obligations")
                        .font(.headline)

                    Text(store.appLanguage == .arabicEgyptian ? "عرض بس للحاجات اللي لسه متدفعتش. الدفع بيتم من نفس مسارات الحركات الموجودة." : "Read-only overview from existing unpaid recurring payments, installments, and future obligations. Paying still happens through the existing transaction flows.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            commitmentsSection(AppText.dueSoon(store.appLanguage), items: dueSoonItems, creditCardDueItems: dueSoonCreditCardDueItems)
            commitmentsSection(AppText.thisMonth(store.appLanguage), items: thisMonthItems, creditCardDueItems: thisMonthCreditCardDueItems)
            commitmentsSection(AppText.later(store.appLanguage), items: laterItems, creditCardDueItems: laterCreditCardDueItems)
        }
        .navigationTitle(AppText.commitments(store.appLanguage))
        .sheet(item: $selectedCreditCardPaymentRoute) { route in
            CreditCardPaymentView(route: route)
                .environmentObject(store)
        }
    }

    private func commitmentsSection(_ title: String, items: [CommitmentItem], creditCardDueItems: [CreditCardDueItem]) -> some View {
        Section(title) {
            if items.isEmpty && creditCardDueItems.isEmpty {
                Text(emptyText(for: title))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    CommitmentRow(item: item)
                }

                ForEach(creditCardDueItems) { item in
                    CreditCardDueCommitmentRow(item: item) { dueItem in
                        openCreditCardPayment(dueItem)
                    }
                }
            }
        }
    }

    private func openCreditCardPayment(_ dueItem: CreditCardDueItem) {
        guard dueItem.dueAmount > 0,
              let card = store.creditCards.first(where: { $0.id == dueItem.cardID }) else {
            return
        }

        selectedCreditCardPaymentRoute = CreditCardPaymentRoute(
            card: card,
            prefilledAmount: dueItem.dueAmount,
            maximumPaymentAmount: dueItem.dueAmount,
            source: .due
        )
    }

    private func emptyText(for title: String) -> String {
        switch title {
        case "Due Soon", "قريب":
            return store.appLanguage == .arabicEgyptian ? "مفيش التزامات مستحقة خلال ٧ أيام." : "No unpaid commitments due in the next 7 days."
        case "This Month", "الشهر ده":
            return store.appLanguage == .arabicEgyptian ? "مفيش التزامات تانية في الشهر ده." : "No additional unpaid commitments later this month."
        default:
            return store.appLanguage == .arabicEgyptian ? "مفيش التزامات بعد كده." : "No later unpaid commitments."
        }
    }

    private func startOfTomorrow(daysFromNow: Int) -> Date {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: daysFromNow, to: startOfToday) ?? Date()
    }
}

private struct CreditCardDueCommitmentRow: View {

    @EnvironmentObject private var store: WalletStore

    let item: CreditCardDueItem
    let onPayDue: (CreditCardDueItem) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.orange)
                .frame(width: 34, height: 34)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(AppText.creditCardDue(store.appLanguage))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(item.cardName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(store.appLanguage == .arabicEgyptian ? "كشف الحساب يوم \(formatDate(item.statementClosingDate))" : "Statement closes \(formatDate(item.statementClosingDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(store.appLanguage == .arabicEgyptian ? "إجمالي المستحق على الكارت: \(formatCurrency(item.outstandingAmount))" : "Card outstanding: \(formatCurrency(item.outstandingAmount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(formatDate(item.dueDate))
                    if let defaultPaymentAccountName = item.defaultPaymentAccountName {
                        Text(store.appLanguage == .arabicEgyptian ? "السداد من \(defaultPaymentAccountName)" : "Pay from \(defaultPaymentAccountName)")
                            .fontWeight(.semibold)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(item.dueAmount))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(AppText.dueAmount(store.appLanguage))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button {
                    onPayDue(item)
                } label: {
                    Text(AppText.payDue(store.appLanguage))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount)
    }
}

private struct CommitmentItem: Identifiable {
    let event: FinancialEvent
    let installmentProgressText: String?

    var id: UUID { event.id }
    var title: String { event.title }
    var amount: Double { event.recurringAmount(for: event.date) }
    var date: Date { event.date }
    var type: FinancialEventType { event.type }
    var status: FinancialEventStatus { event.status }

    var subtitle: String {
        if let installmentProgressText {
            return installmentProgressText
        }

        if event.repeatRule != .none {
            return "\(event.repeatRule.rawValue) recurring"
        }

        return event.type.rawValue
    }
}

private struct CommitmentRow: View {

    @EnvironmentObject private var store: WalletStore

    let item: CommitmentItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NamedVisualMark(
                name: item.title,
                fallbackSystemImage: iconName,
                size: 34,
                fallbackColor: iconColor
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(formatDate(item.date))
                    Text(item.status.rawValue)
                        .fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatCurrency(item.amount))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch item.type {
        case .installment:
            return "creditcard.and.123"
        case .obligation:
            return "calendar.badge.exclamationmark"
        case .expectedExpense:
            return "calendar.badge.clock"
        case .expense:
            return "cart"
        case .income, .transfer:
            return "circle"
        }
    }

    private var iconColor: Color {
        if item.date < Calendar.current.startOfDay(for: Date()) {
            return .red
        }

        switch item.type {
        case .installment:
            return .purple
        case .obligation:
            return .orange
        default:
            return .blue
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount)
    }
}
