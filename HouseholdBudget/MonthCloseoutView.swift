import SwiftUI

struct MonthCloseoutView: View {

    @EnvironmentObject private var store: WalletStore

    @State private var selectedMonthDate = MonthCloseoutView.startOfMonth(for: Date())

    private var monthComponents: (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedMonthDate)
        return (components.year ?? 2026, components.month ?? 1)
    }

    private var budget: WalletMonthlyBudget? {
        store.monthlyBudget(year: monthComponents.year, month: monthComponents.month)
    }

    private var plannedByCategory: [String: Double] {
        Dictionary(uniqueKeysWithValues: (budget?.items ?? []).map { item in
            (item.categoryName, item.plannedAmount)
        })
    }

    private var paidByCategory: [String: Double] {
        store.actualSpendingByCategory(year: monthComponents.year, month: monthComponents.month)
    }

    private var upcomingByCategory: [String: Double] {
        store.upcomingKnownExpensesByCategory(year: monthComponents.year, month: monthComponents.month)
    }

    private var historicalByCategory: [String: Double] {
        store.historicalSummarySpendingByCategory(year: monthComponents.year, month: monthComponents.month)
    }

    private var categoryNames: [String] {
        var names: [String] = []

        for name in Array(plannedByCategory.keys) + Array(paidByCategory.keys) + Array(upcomingByCategory.keys) + Array(historicalByCategory.keys) {
            if !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                names.append(name)
            }
        }

        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var plannedTotal: Double {
        categoryNames.map { plannedByCategory[$0] ?? 0 }.reduce(0, +)
    }

    private var paidTotal: Double {
        categoryNames.map { paidByCategory[$0] ?? 0 }.reduce(0, +)
    }

    private var upcomingTotal: Double {
        categoryNames.map { upcomingByCategory[$0] ?? 0 }.reduce(0, +)
    }

    private var historicalTotal: Double {
        categoryNames.map { historicalByCategory[$0] ?? 0 }.reduce(0, +)
    }

    private var difference: Double {
        plannedTotal - paidTotal - historicalTotal
    }

    private var warnings: [String] {
        var result: [String] = []

        if upcomingTotal > 0 {
            result.append(store.appLanguage == .arabicEgyptian ? "في مصاريف جاية لسه ما اتدفعتش." : "There are upcoming items still unpaid.")
        }

        if categoryNames.contains(where: { (plannedByCategory[$0] ?? 0) <= 0 && ((paidByCategory[$0] ?? 0) > 0 || (upcomingByCategory[$0] ?? 0) > 0) }) {
            result.append(store.appLanguage == .arabicEgyptian ? "في مصاريف على بنود مش متخططة." : "Some spending or upcoming items are not planned.")
        }

        if categoryNames.contains(where: { (paidByCategory[$0] ?? 0) > (plannedByCategory[$0] ?? 0) && (plannedByCategory[$0] ?? 0) > 0 }) {
            result.append(store.appLanguage == .arabicEgyptian ? "في بنود عدّت الميزانية." : "Some categories exceeded plan.")
        }

        if paidByCategory.keys.contains("Uncategorized") {
            result.append(store.appLanguage == .arabicEgyptian ? "في حركات من غير تصنيف." : "Some paid spending is uncategorized.")
        }

        if result.isEmpty {
            result.append(store.appLanguage == .arabicEgyptian ? "مفيش تحذيرات واضحة للشهر ده." : "No obvious closeout warnings for this month.")
        }

        return result
    }

    var body: some View {
        List {
            Section {
                monthSelector
            }

            Section(store.appLanguage == .arabicEgyptian ? "مراجعة الشهر" : "Closeout Review") {
                Text(store.appLanguage == .arabicEgyptian ? "استخدمها في آخر الشهر قبل ما تقفل بياناته." : "Use this at the end of the month before closing your records.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(store.appLanguage == .arabicEgyptian ? "المراجعة دي للقراءة بس. مش بتقفل الشهر فعليًا ومش بتغيّر الأرصدة." : "This is a read-only review. It does not lock the month or change balances.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                summaryGrid
            }

            Section(store.appLanguage == .arabicEgyptian ? "تحذيرات" : "Warnings") {
                ForEach(warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                }
            }

            Section(store.appLanguage == .arabicEgyptian ? "البنود" : "Categories") {
                if categoryNames.isEmpty {
                    Text(store.appLanguage == .arabicEgyptian ? "مفيش بيانات للشهر ده." : "No data for this month.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(categoryNames, id: \.self) { categoryName in
                        categoryRow(categoryName)
                    }
                }
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "مراجعة وقفل الشهر" : "Monthly Review & Closeout")
    }

    private var monthSelector: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            VStack(spacing: 3) {
                Text(monthTitle(selectedMonthDate))
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(store.appLanguage == .arabicEgyptian ? "مراجعة قبل القفل" : "Review before closing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricCard(title: store.appLanguage == .arabicEgyptian ? "المخطط" : "Planned", value: plannedTotal)
            metricCard(title: store.appLanguage == .arabicEgyptian ? "المدفوع" : "Paid Actual", value: paidTotal)
            metricCard(title: store.appLanguage == .arabicEgyptian ? "لسه جاي" : "Still Upcoming", value: upcomingTotal)
            metricCard(title: store.appLanguage == .arabicEgyptian ? "قديم ملخص" : "Historical Summary", value: historicalTotal)
            metricCard(title: difference >= 0 ? (store.appLanguage == .arabicEgyptian ? "فرق متبقي" : "Difference Left") : (store.appLanguage == .arabicEgyptian ? "فرق زيادة" : "Difference Over"), value: abs(difference), color: difference >= 0 ? .green : .red)
        }
        .padding(.vertical, 4)
    }

    private func categoryRow(_ categoryName: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppText.categoryDisplayName(categoryName, language: store.appLanguage))
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                metricCard(title: store.appLanguage == .arabicEgyptian ? "المخطط" : "Planned", value: plannedByCategory[categoryName] ?? 0)
                metricCard(title: store.appLanguage == .arabicEgyptian ? "المدفوع" : "Paid", value: paidByCategory[categoryName] ?? 0)
                metricCard(title: store.appLanguage == .arabicEgyptian ? "الجاي" : "Upcoming", value: upcomingByCategory[categoryName] ?? 0)
                metricCard(title: store.appLanguage == .arabicEgyptian ? "قديم" : "Historical", value: historicalByCategory[categoryName] ?? 0)
            }
        }
        .padding(.vertical, 5)
    }

    private func metricCard(title: String, value: Double, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(store.displayCurrency(value))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func moveMonth(by value: Int) {
        selectedMonthDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonthDate) ?? selectedMonthDate
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        if store.appLanguage == .arabicEgyptian {
            formatter.locale = Locale(identifier: "ar_EG")
        }
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private static func startOfMonth(for date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }
}
