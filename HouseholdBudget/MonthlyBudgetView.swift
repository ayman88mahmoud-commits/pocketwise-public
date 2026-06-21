import SwiftUI

struct MonthlyBudgetView: View {

    @EnvironmentObject private var store: WalletStore

    @State private var selectedMonthDate: Date
    @State private var copySourceMonthDate: Date
    @State private var copyTargetMonthDate: Date
    @State private var plannedAmountTexts: [String: String] = [:]
    @State private var showCopyConfirmation = false
    @State private var isShowingCopyPlanner = false
    @State private var saveMessage: String?

    init(initialMonthDate: Date = Date()) {
        let monthDate = MonthlyBudgetView.startOfMonth(for: initialMonthDate)
        _selectedMonthDate = State(initialValue: monthDate)
        _copySourceMonthDate = State(initialValue: Calendar.current.date(byAdding: .month, value: -1, to: monthDate) ?? monthDate)
        _copyTargetMonthDate = State(initialValue: monthDate)
    }

    private var monthComponents: (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedMonthDate)
        return (components.year ?? 2026, components.month ?? 1)
    }

    private var previousMonthComponents: (year: Int, month: Int) {
        let previousDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonthDate) ?? selectedMonthDate
        let components = Calendar.current.dateComponents([.year, .month], from: previousDate)
        return (components.year ?? monthComponents.year, components.month ?? monthComponents.month)
    }

    private var budget: WalletMonthlyBudget? {
        store.monthlyBudget(
            year: monthComponents.year,
            month: monthComponents.month
        )
    }

    private var previousBudget: WalletMonthlyBudget? {
        store.monthlyBudget(
            year: previousMonthComponents.year,
            month: previousMonthComponents.month
        )
    }

    private var actualSpending: [String: Double] {
        store.actualSpendingByCategory(
            year: monthComponents.year,
            month: monthComponents.month
        )
    }

    private var upcomingKnownSpending: [String: Double] {
        store.upcomingKnownExpensesByCategory(
            year: monthComponents.year,
            month: monthComponents.month
        )
    }

    private var upcomingKnownEvents: [FinancialEvent] {
        store.upcomingKnownExpenseEvents(
            year: monthComponents.year,
            month: monthComponents.month
        )
    }

    private var categoryNames: [String] {
        let plannedNames = Array(plannedAmountTexts.keys)
        let actualNames = Array(actualSpending.keys)
        let upcomingNames = Array(upcomingKnownSpending.keys)
        let storeNames = store.budgetCategoryNames(for: budget)
        var names: [String] = []

        for name in storeNames + plannedNames + actualNames + upcomingNames where !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            names.append(name)
        }

        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var totalPlanned: Double {
        categoryNames
            .map { plannedAmount(for: $0) }
            .reduce(0, +)
    }

    private var totalActual: Double {
        categoryNames
            .map { actualSpending[$0] ?? 0 }
            .reduce(0, +)
    }

    private var totalUpcomingKnown: Double {
        categoryNames
            .map { upcomingKnownSpending[$0] ?? 0 }
            .reduce(0, +)
    }

    private var remainingNow: Double {
        totalPlanned - totalActual
    }

    private var remainingAfterUpcoming: Double {
        totalPlanned - totalActual - totalUpcomingKnown
    }

    private var upcomingNotPlannedCategories: [String] {
        categoryNames.filter { categoryName in
            plannedAmount(for: categoryName) <= 0 &&
            (upcomingKnownSpending[categoryName] ?? 0) > 0
        }
    }

    private var overBudgetCount: Int {
        categoryNames.filter { categoryName in
            let planned = plannedAmount(for: categoryName)
            let actual = actualSpending[categoryName] ?? 0
            return planned > 0 && actual > planned
        }.count
    }

    private var hasInvalidAmounts: Bool {
        categoryNames.contains { categoryName in
            amountValue(from: plannedAmountTexts[categoryName] ?? "") == nil
        }
    }

    private var hasExistingBudgetValues: Bool {
        budget?.items.contains { $0.plannedAmount > 0 } == true ||
        plannedAmountTexts.values.contains { (Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 }
    }

    private var isViewingCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonthDate, equalTo: Date(), toGranularity: .month)
    }

    var body: some View {
        List {
            Section {
                monthSelector
            }

            Section {
                Text(store.appLanguage == .arabicEgyptian ? "استخدمها لتعديل المبالغ المخططة للشهر المختار." : "Use this to edit planned amounts for the selected month.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(AppText.summary(store.appLanguage)) {
                summaryCard
            }

            if !upcomingKnownEvents.isEmpty {
                Section(AppText.committedExpenses(store.appLanguage)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.appLanguage == .arabicEgyptian ? "الملتزم بيه بيتسحب تلقائيًا من المصاريف اللي لسه ما اتدفعتش. مش محسوب كمدفوع." : "Committed comes from your future/unpaid items automatically. It is not counted as paid.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        ForEach(upcomingKnownEvents.prefix(5)) { event in
                            upcomingEventRow(event)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if !upcomingNotPlannedCategories.isEmpty {
                Section(store.appLanguage == .arabicEgyptian ? "مصروفات جاية مش متخططة" : "Upcoming Not Planned") {
                    ForEach(upcomingNotPlannedCategories, id: \.self) { categoryName in
                        HStack {
                            Text(AppText.categoryDisplayName(categoryName, language: store.appLanguage))
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Spacer()

                            Text(formatCurrency(upcomingKnownSpending[categoryName] ?? 0))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            Section {
                Button {
                    handleCopyPreviousMonth()
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text(store.appLanguage == .arabicEgyptian ? "انسخ الشهر اللي فات" : "Copy Previous Month")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(previousBudget == nil)

                if previousBudget == nil {
                    Text(store.appLanguage == .arabicEgyptian ? "مفيش ميزانية محفوظة للشهر اللي فات." : "No saved budget found for the previous month.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    copySourceMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonthDate) ?? selectedMonthDate
                    copyTargetMonthDate = selectedMonthDate
                    isShowingCopyPlanner = true
                } label: {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text(store.appLanguage == .arabicEgyptian ? "انسخ ميزانية بين شهرين" : "Copy Budget Between Months")
                            .fontWeight(.semibold)
                    }
                }
            }

            if categoryNames.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppText.noCategoriesYet(store.appLanguage))
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text(store.appLanguage == .arabicEgyptian ? "أضف بنود من الإعدادات عشان تبدأ ميزانية الشهر." : "Add categories in Settings to start monthly budget planning.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            } else {
                Section(AppText.categories(store.appLanguage)) {
                    ForEach(categoryNames, id: \.self) { categoryName in
                        budgetRow(categoryName: categoryName)
                    }
                }
            }

            Section {
                if hasInvalidAmounts {
                    validationMessage(store.appLanguage == .arabicEgyptian ? "دخل أرقام صحيحة للمخطط." : "Enter valid planned amounts.")
                }

                if let saveMessage {
                    Text(saveMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    saveBudget()
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "احفظ ميزانية الشهر" : "Save Monthly Budget")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(hasInvalidAmounts)
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "تعديل ميزانية الشهر" : "Edit Monthly Budget")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBudgetForSelectedMonth()
        }
        .onChange(of: selectedMonthDate) { _, _ in
            loadBudgetForSelectedMonth()
        }
        .confirmationDialog(
            store.appLanguage == .arabicEgyptian ? "تستبدل ميزانية الشهر؟" : "Replace this month’s budget?",
            isPresented: $showCopyConfirmation,
            titleVisibility: .visible
        ) {
            Button(store.appLanguage == .arabicEgyptian ? "استبدال الميزانية" : "Replace Budget", role: .destructive) {
                copyPreviousMonth()
            }

            Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel", role: .cancel) { }
        } message: {
            Text(store.appLanguage == .arabicEgyptian ? "ده بينسخ المبالغ المخططة بس. الحركات والمصاريف الفعلية مش هتتغير." : "This copies planned amounts only. Transactions and actual spending will not change.")
        }
        .sheet(isPresented: $isShowingCopyPlanner) {
            BudgetCopyPlannerView(
                sourceMonthDate: $copySourceMonthDate,
                targetMonthDate: $copyTargetMonthDate,
                selectedMonthDate: $selectedMonthDate
            )
            .environmentObject(store)
        }
    }

    private var monthSelector: some View {
        VStack(spacing: 10) {
            VStack(spacing: 4) {
                Text(formatMonth(selectedMonthDate))
                    .font(.title3)
                    .fontWeight(.bold)

                Text(store.appLanguage == .arabicEgyptian ? "المخطط مقابل المصروف الفعلي" : "Plan vs actual spending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "السابق" : "Previous", systemImage: "chevron.left")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                if !isViewingCurrentMonth {
                    Button {
                        selectedMonthDate = Self.startOfMonth(for: Date())
                    } label: {
                        Text(AppText.thisMonth(store.appLanguage))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    moveMonth(by: 1)
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "التالي" : "Next", systemImage: "chevron.right")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 12) {
            summaryRow(store.appLanguage == .arabicEgyptian ? "إجمالي المخطط" : "Total Planned", totalPlanned)
            summaryRow(store.appLanguage == .arabicEgyptian ? "المدفوع لحد دلوقتي" : "Paid So Far", totalActual)
            summaryRow(AppText.committed(store.appLanguage), totalUpcomingKnown)

            Divider()

            summaryRow(
                remainingNow >= 0 ? (store.appLanguage == .arabicEgyptian ? "المتبقي دلوقتي" : "Remaining Now") : (store.appLanguage == .arabicEgyptian ? "زيادة دلوقتي" : "Over Now"),
                abs(remainingNow),
                color: remainingNow >= 0 ? .green : .red
            )

            summaryRow(
                remainingAfterUpcoming >= 0 ? (store.appLanguage == .arabicEgyptian ? "المتبقي بعد الجاي" : "Remaining After Upcoming") : (store.appLanguage == .arabicEgyptian ? "زيادة بعد الجاي" : "Over After Upcoming"),
                abs(remainingAfterUpcoming),
                color: remainingAfterUpcoming >= 0 ? .green : .red
            )

            HStack {
                Text(store.appLanguage == .arabicEgyptian ? "بنود زادت عن الميزانية" : "Categories Over Budget")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(overBudgetCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 4)
    }

    private func budgetRow(categoryName: String) -> some View {
        let planned = plannedAmount(for: categoryName)
        let actual = actualSpending[categoryName] ?? 0
        let upcoming = upcomingKnownSpending[categoryName] ?? 0
        let remainingAfterKnown = planned - actual - upcoming
        let isOver = planned > 0 && remainingAfterKnown < 0
        let progressValue = planned > 0 ? min(actual / planned, 1) : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(AppText.categoryDisplayName(categoryName, language: store.appLanguage))
                        .font(.headline)

                    if isInactiveSavedCategory(categoryName) {
                        Text(store.appLanguage == .arabicEgyptian ? "تصنيف محفوظ غير نشط" : "Inactive saved category")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(isOver ? (store.appLanguage == .arabicEgyptian ? "زيادة" : "Over") : AppText.remaining(store.appLanguage))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(formatCurrency(abs(remainingAfterKnown)))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(isOver ? .red : .green)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                amountMetric(
                    title: AppText.planned(store.appLanguage),
                    value: nil,
                    field: TextField("0", text: binding(for: categoryName))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.leading)
                )

                amountMetric(
                    title: store.appLanguage == .arabicEgyptian ? "المدفوع" : "Paid",
                    value: formatCurrency(actual)
                )

                amountMetric(
                    title: AppText.upcoming(store.appLanguage),
                    value: formatCurrency(upcoming)
                )

                amountMetric(
                    title: store.appLanguage == .arabicEgyptian ? "بعد الجاي" : "After Upcoming",
                    value: formatCurrency(abs(remainingAfterKnown)),
                    valueColor: remainingAfterKnown >= 0 ? .green : .red
                )
            }

            if amountValue(from: plannedAmountTexts[categoryName] ?? "") == nil {
                validationMessage(store.appLanguage == .arabicEgyptian ? "دخل مبلغ صحيح." : "Enter a valid amount.")
            }

            ProgressView(value: progressValue)
                .tint(isOver ? .red : .green)
        }
        .padding(.vertical, 6)
    }

    private func summaryRow(_ title: String, _ amount: Double, color: Color = .primary) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(formatCurrency(amount))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }

    private func amountMetric<Field: View>(
        title: String,
        value: String?,
        valueColor: Color = .primary,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let value {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else {
                field
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func amountMetric(title: String, value: String, valueColor: Color = .primary) -> some View {
        amountMetric(title: title, value: value, valueColor: valueColor, field: EmptyView())
    }

    private func upcomingEventRow(_ event: FinancialEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(formatDate(event.date)) • \(AppText.categoryDisplayName(event.categoryName ?? "Uncategorized", language: store.appLanguage))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(formatCurrency(event.recurringAmount(for: event.date)))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private func binding(for categoryName: String) -> Binding<String> {
        Binding(
            get: {
                plannedAmountTexts[categoryName] ?? ""
            },
            set: { newValue in
                plannedAmountTexts[categoryName] = newValue
                saveMessage = nil
            }
        )
    }

    private func loadBudgetForSelectedMonth() {
        var values: [String: String] = [:]

        if let budget {
            for item in budget.items {
                values[item.categoryName] = cleanNumberText(item.plannedAmount)
            }
        }

        for category in store.categories where category.isActive {
            values[category.name] = values[category.name] ?? ""
        }

        plannedAmountTexts = values
        saveMessage = nil
    }

    private func saveBudget() {
        guard !hasInvalidAmounts else {
            return
        }

        var plannedAmounts: [String: Double] = [:]
        for categoryName in categoryNames {
            plannedAmounts[categoryName] = plannedAmount(for: categoryName)
        }

        store.saveMonthlyBudget(
            year: monthComponents.year,
            month: monthComponents.month,
            plannedAmountsByCategory: plannedAmounts
        )
        loadBudgetForSelectedMonth()
        saveMessage = store.appLanguage == .arabicEgyptian ? "تم حفظ الميزانية." : "Budget saved."
    }

    private func handleCopyPreviousMonth() {
        guard previousBudget != nil else {
            return
        }

        if hasExistingBudgetValues {
            showCopyConfirmation = true
        } else {
            copyPreviousMonth()
        }
    }

    private func copyPreviousMonth() {
        store.copyMonthlyBudget(
            from: previousMonthComponents.year,
            sourceMonth: previousMonthComponents.month,
            to: monthComponents.year,
            targetMonth: monthComponents.month
        )
        loadBudgetForSelectedMonth()
        saveMessage = store.appLanguage == .arabicEgyptian ? "تم نسخ الشهر اللي فات." : "Copied previous month."
    }

    private func moveMonth(by value: Int) {
        let newDate = Calendar.current.date(
            byAdding: .month,
            value: value,
            to: selectedMonthDate
        ) ?? selectedMonthDate

        selectedMonthDate = Self.startOfMonth(for: newDate)
    }

    private func plannedAmount(for categoryName: String) -> Double {
        amountValue(from: plannedAmountTexts[categoryName] ?? "") ?? 0
    }

    private func amountValue(from text: String) -> Double? {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            return 0
        }

        guard let value = Double(cleanText.replacingOccurrences(of: ",", with: ".")),
              value >= 0 else {
            return nil
        }

        return value
    }

    private func isInactiveSavedCategory(_ categoryName: String) -> Bool {
        guard budget?.items.contains(where: { $0.categoryName == categoryName }) == true else {
            return false
        }

        return store.categories.first(where: { $0.name == categoryName })?.isActive == false
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        if store.appLanguage == .arabicEgyptian {
            formatter.locale = Locale(identifier: "ar_EG")
        }
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if store.appLanguage == .arabicEgyptian {
            formatter.locale = Locale(identifier: "ar_EG")
        }
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount)
    }

    private func cleanNumberText(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return "\(amount)"
    }

    private static func startOfMonth(for date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }
}

private struct BudgetCopyPlannerView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @Binding var sourceMonthDate: Date
    @Binding var targetMonthDate: Date
    @Binding var selectedMonthDate: Date

    @State private var showOverwriteConfirmation = false

    private var isAr: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var sourceComponents: (year: Int, month: Int) {
        monthComponents(for: sourceMonthDate)
    }

    private var targetComponents: (year: Int, month: Int) {
        monthComponents(for: targetMonthDate)
    }

    private var sourceBudget: WalletMonthlyBudget? {
        store.monthlyBudget(year: sourceComponents.year, month: sourceComponents.month)
    }

    private var targetBudget: WalletMonthlyBudget? {
        store.monthlyBudget(year: targetComponents.year, month: targetComponents.month)
    }

    private var targetHasBudgetValues: Bool {
        targetBudget?.items.contains { $0.plannedAmount > 0 } == true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(isAr ? "شهر المصدر" : "Source Month") {
                    monthStepper(date: $sourceMonthDate)

                    if sourceBudget == nil {
                        Text(isAr ? "مفيش ميزانية محفوظة لشهر المصدر." : "No saved budget found for this source month.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(isAr ? "شهر الهدف" : "Target Month") {
                    monthStepper(date: $targetMonthDate)

                    if targetHasBudgetValues {
                        Text(isAr ? "شهر الهدف فيه ميزانية بالفعل. هنسألك قبل الاستبدال." : "Target month already has a budget. You will be asked before overwriting it.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    Button {
                        copyBudget()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isAr ? "نسخ الميزانية" : "Copy Budget")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(sourceBudget == nil)
                }
            }
            .navigationTitle(isAr ? "نسخ الميزانية" : "Copy Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isAr ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                isAr ? "تستبدل شهر الهدف؟" : "Overwrite target month?",
                isPresented: $showOverwriteConfirmation,
                titleVisibility: .visible
            ) {
                Button(isAr ? "استبدال الميزانية" : "Overwrite Budget", role: .destructive) {
                    performCopy()
                }

                Button(isAr ? "إلغاء" : "Cancel", role: .cancel) { }
            } message: {
                Text(isAr ? "ده بيستبدل المبالغ المخططة لشهر الهدف بس. الحركات والمصاريف الفعلية مش هتتغير." : "This replaces planned amounts for the target month only. Transactions and actual spending will not change.")
            }
        }
    }

    private func monthStepper(date: Binding<Date>) -> some View {
        HStack {
            Button {
                date.wrappedValue = Calendar.current.date(byAdding: .month, value: -1, to: date.wrappedValue) ?? date.wrappedValue
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(formatMonth(date.wrappedValue))
                .font(.headline)

            Spacer()

            Button {
                date.wrappedValue = Calendar.current.date(byAdding: .month, value: 1, to: date.wrappedValue) ?? date.wrappedValue
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private func copyBudget() {
        if targetHasBudgetValues {
            showOverwriteConfirmation = true
        } else {
            performCopy()
        }
    }

    private func performCopy() {
        store.copyMonthlyBudget(
            from: sourceComponents.year,
            sourceMonth: sourceComponents.month,
            to: targetComponents.year,
            targetMonth: targetComponents.month
        )
        selectedMonthDate = targetMonthDate
        dismiss()
    }

    private func monthComponents(for date: Date) -> (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return (components.year ?? 2026, components.month ?? 1)
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        if isAr {
            formatter.locale = Locale(identifier: "ar_EG")
        }
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

struct MonthlyBudgetView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            MonthlyBudgetView()
                .environmentObject(WalletStore())
        }
    }
}
