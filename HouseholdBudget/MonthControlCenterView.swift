import SwiftUI

struct MonthControlCenterView: View {

    @EnvironmentObject private var store: WalletStore

    @State private var selectedMonthDate = MonthControlCenterView.startOfMonth(for: Date())

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

    private var categoryNames: [String] {
        var names: [String] = []

        for name in Array(plannedByCategory.keys) + Array(paidByCategory.keys) + Array(upcomingByCategory.keys) {
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

    private var remainingNow: Double {
        plannedTotal - paidTotal
    }

    private var remainingAfterUpcoming: Double {
        plannedTotal - paidTotal - upcomingTotal
    }

    var body: some View {
        List {
            Section {
                monthSelector
            }

            Section {
                Text(store.appLanguage == .arabicEgyptian ? "دي لوحة متابعة الشهر. استخدمها للمراجعة مش لإدخال كل التفاصيل." : "This is your monthly dashboard. Use it to review the month, not to enter every detail.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(store.appLanguage == .arabicEgyptian ? "ملخص الشهر" : "Month Summary") {
                summaryGrid
            }

            Section(store.appLanguage == .arabicEgyptian ? "إجراءات سريعة" : "Quick Actions") {
                NavigationLink {
                    MonthlyBudgetView()
                        .environmentObject(store)
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "تعديل ميزانية الشهر" : "Edit Monthly Budget", systemImage: "calendar.badge.clock")
                }

                NavigationLink {
                    MultiMonthPlannerView()
                        .environmentObject(store)
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "مخطط الشهور" : "Multi-Month Planner", systemImage: "tablecells")
                }

                NavigationLink {
                    MonthCloseoutView()
                        .environmentObject(store)
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "مراجعة وقفل الشهر" : "Monthly Review & Closeout", systemImage: "checkmark.seal")
                }
            }

            Section(store.appLanguage == .arabicEgyptian ? "البنود" : "Categories") {
                if categoryNames.isEmpty {
                    Text(store.appLanguage == .arabicEgyptian ? "لسه مفيش خطة أو حركات للشهر ده." : "No plan, paid spending, or upcoming items for this month yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(categoryNames, id: \.self) { categoryName in
                        categoryRow(categoryName)
                    }
                }
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "مركز الشهر" : "Month Control Center")
    }

    private var monthSelector: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "السابق" : "Previous", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                }

                Spacer()

                Text(monthTitle(selectedMonthDate))
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    moveMonth(by: 1)
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "التالي" : "Next", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                }
            }

            Button {
                selectedMonthDate = Self.startOfMonth(for: Date())
            } label: {
                Text(store.appLanguage == .arabicEgyptian ? "الشهر ده" : "This Month")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 4)
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricCard(title: store.appLanguage == .arabicEgyptian ? "المخطط" : "Planned", value: plannedTotal)
            metricCard(title: store.appLanguage == .arabicEgyptian ? "المدفوع" : "Paid", value: paidTotal)
            metricCard(title: store.appLanguage == .arabicEgyptian ? "الجاي" : "Upcoming", value: upcomingTotal)
            metricCard(title: store.appLanguage == .arabicEgyptian ? "بعد الجاي" : "After Upcoming", value: abs(remainingAfterUpcoming), color: remainingAfterUpcoming >= 0 ? .green : .red)
        }
        .padding(.vertical, 4)
    }

    private func categoryRow(_ categoryName: String) -> some View {
        let planned = plannedByCategory[categoryName] ?? 0
        let paid = paidByCategory[categoryName] ?? 0
        let upcoming = upcomingByCategory[categoryName] ?? 0
        let afterUpcoming = planned - paid - upcoming

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(AppText.categoryDisplayName(categoryName, language: store.appLanguage))
                    .font(.headline)

                Spacer()

                Text(statusText(planned: planned, paid: paid, upcoming: upcoming))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(statusColor(planned: planned, paid: paid, upcoming: upcoming))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(planned: planned, paid: paid, upcoming: upcoming).opacity(0.12))
                    .clipShape(Capsule())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                metricCard(title: store.appLanguage == .arabicEgyptian ? "المخطط" : "Planned", value: planned)
                metricCard(title: store.appLanguage == .arabicEgyptian ? "المدفوع" : "Paid", value: paid)
                metricCard(title: store.appLanguage == .arabicEgyptian ? "الجاي" : "Upcoming", value: upcoming)
                metricCard(title: store.appLanguage == .arabicEgyptian ? "بعد الجاي" : "After Upcoming", value: abs(afterUpcoming), color: afterUpcoming >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 6)
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

    private func statusText(planned: Double, paid: Double, upcoming: Double) -> String {
        if planned <= 0 && upcoming > 0 {
            return store.appLanguage == .arabicEgyptian ? "جاي مش متخطط" : "Unplanned upcoming"
        }

        if planned > 0 && paid > planned {
            return store.appLanguage == .arabicEgyptian ? "فوق الخطة" : "Over plan"
        }

        if planned > 0 && paid + upcoming > planned {
            return store.appLanguage == .arabicEgyptian ? "محتاج متابعة" : "Watch"
        }

        return store.appLanguage == .arabicEgyptian ? "ماشي كويس" : "On track"
    }

    private func statusColor(planned: Double, paid: Double, upcoming: Double) -> Color {
        if planned <= 0 && upcoming > 0 {
            return .orange
        }

        if planned > 0 && paid > planned {
            return .red
        }

        if planned > 0 && paid + upcoming > planned {
            return .orange
        }

        return .green
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
