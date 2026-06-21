import SwiftUI

struct RecurringMonthlyAmountsSection: View {

    @EnvironmentObject private var store: WalletStore

    let startDate: Date
    @Binding var monthAmountTexts: [String: String]
    var visibleMonthCount: Int = 12
    var title: String? = nil
    var helpText: String? = nil
    var positiveStatusText: String? = nil
    var emptyStatusText: String? = nil
    var semanticColor: PocketWiseSemanticColor = .obligations

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var visibleMonths: [Date] {
        let start = Self.startOfMonth(for: startDate)
        return (0..<max(visibleMonthCount, 1)).compactMap { offset in
            Calendar.current.date(byAdding: .month, value: offset, to: start)
        }
    }

    var body: some View {
        Section(title ?? (isArabic ? "مبالغ الشهور" : "Monthly Amounts")) {
            Text(helpText ?? (isArabic ? "اكتب مبلغ كل شهر. لو المبلغ صفر أو فاضي، مش هيظهر دفع للشهر ده." : "Type each month amount. Zero or empty means no payment for that month."))
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(visibleMonths, id: \.self) { month in
                monthRow(month)
            }
        }
    }

    private func localizedMonthTitle(_ month: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        if isArabic {
            formatter.locale = Locale(identifier: "ar_EG")
        }
        return formatter.string(from: month)
    }

    private func monthRow(_ month: Date) -> some View {
        let key = Self.monthKey(for: month)
        let id = Self.monthID(year: key.year, month: key.month)
        let amount = parseAmountText(monthAmountTexts[id] ?? "")

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(localizedMonthTitle(month))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(amount > 0 ? (positiveStatusText ?? (isArabic ? "مؤكد" : "Confirmed")) : (emptyStatusText ?? (isArabic ? "لا يوجد دفع" : "No payment")))
                    .font(.caption)
                    .foregroundStyle(amount > 0 ? Color.green : Color.secondary)
            }

            Spacer(minLength: 12)

            TextField("0", text: monthAmountBinding(for: id))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
                .pocketWiseInputField(semanticColor: semanticColor)
        }
        .contentShape(Rectangle())
    }

    private func monthAmountBinding(for id: String) -> Binding<String> {
        Binding(
            get: { monthAmountTexts[id] ?? "" },
            set: { newValue in
                monthAmountTexts[id] = newValue
            }
        )
    }

    private func parseAmountText(_ text: String) -> Double {
        Self.parseAmountText(text)
    }

    static func parseAmountText(_ text: String) -> Double {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return 0 }

        if cleaned.contains(",") && cleaned.contains(".") {
            return Double(cleaned.replacingOccurrences(of: ",", with: "")) ?? 0
        }

        if cleaned.contains(",") {
            let parts = cleaned.split(separator: ",")
            if let last = parts.last, last.count == 3 {
                return Double(cleaned.replacingOccurrences(of: ",", with: "")) ?? 0
            }

            return Double(cleaned.replacingOccurrences(of: ",", with: ".")) ?? 0
        }

        return Double(cleaned) ?? 0
    }

    static func startOfMonth(for date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }

    static func visibleMonthKeys(startDate: Date, visibleMonthCount: Int = 12) -> [(year: Int, month: Int, id: String)] {
        let start = startOfMonth(for: startDate)
        return (0..<max(visibleMonthCount, 1)).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .month, value: offset, to: start) else {
                return nil
            }

            let key = monthKey(for: date)
            return (key.year, key.month, monthID(year: key.year, month: key.month))
        }
    }

    static func monthKey(for date: Date) -> (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return (components.year ?? 2026, components.month ?? 1)
    }

    static func monthID(year: Int, month: Int) -> String {
        "\(year)-\(month)"
    }

    static func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}
