import SwiftUI

struct TodayActualSpendingBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let monthDate: Date
    let displayedAmount: Double

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var monthKey: (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: monthDate)
        return (components.year ?? 2026, components.month ?? 1)
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
                    metricRow(
                        title: isArabic ? "الشهر" : "Month",
                        value: monthTitle(monthDate)
                    )
                    metricRow(
                        title: isArabic ? "المصروف الفعلي" : "Actual",
                        value: store.displayCurrency(displayedAmount)
                    )
                    metricRow(
                        title: isArabic ? "إجمالي المصادر" : "Source Total",
                        value: store.displayCurrency(sourceTotal)
                    )

                    if !totalMatches {
                        Text(isArabic ? "إجمالي المصادر لا يطابق رقم المصروف الفعلي." : "Source total does not match the Actual value shown on Today.")
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
                                    sourceRow(item)
                                }
                            } else {
                                sourceRow(item)
                            }
                        }
                    }
                } header: {
                    Text(isArabic ? "مصادر المصروف الفعلي" : "Actual Spending Sources")
                } footer: {
                    Text(isArabic ? "نفس مصادر رقم المصروف الفعلي. تسويات كروت الائتمان مش بتظهر هنا إلا لو مصدر الحساب نفسه ضافها." : "Uses the same source as the Today Actual value. Credit card settlement payments do not appear unless the actual-spending helper includes them.")
                }
            }
            .navigationTitle(isArabic ? "المصروف الفعلي" : "Actual")
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

    private func sourceRow(_ item: ActualSpendingBreakdownItem) -> some View {
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

    private func metricRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
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

        return store.financialEvents.first { $0.id == eventID }
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

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}
