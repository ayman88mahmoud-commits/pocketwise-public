import SwiftUI

struct MultiMonthPlannerView: View {

    private enum PendingPlannerAction: Identifiable {
        case copyToNextMonth
        case copyToNextThreeMonths
        case fillVisibleMonths

        var id: String {
            switch self {
            case .copyToNextMonth:
                return "copyToNextMonth"
            case .copyToNextThreeMonths:
                return "copyToNextThreeMonths"
            case .fillVisibleMonths:
                return "fillVisibleMonths"
            }
        }
    }

    @EnvironmentObject private var store: WalletStore

    @State private var startMonthDate = MultiMonthPlannerView.startOfMonth(for: Date())
    @State private var monthCount = 6
    @State private var amountTexts: [String: String] = [:]
    @State private var selectedFillCategoryName = ""
    @State private var fillAmountText = ""
    @State private var pendingPlannerAction: PendingPlannerAction?
    @State private var showPlannerConfirmation = false
    @State private var saveMessage: String?

    private let monthCountOptions = [3, 6, 12]

    private var monthDates: [Date] {
        (0..<monthCount).compactMap { offset in
            Calendar.current.date(byAdding: .month, value: offset, to: startMonthDate)
        }
    }

    private var monthKeys: [(date: Date, year: Int, month: Int)] {
        monthDates.map { date in
            let components = Calendar.current.dateComponents([.year, .month], from: date)
            return (date, components.year ?? 2026, components.month ?? 1)
        }
    }

    private var categoryNames: [String] {
        var names = store.categories
            .filter { $0.isActive }
            .map { $0.name }

        for monthKey in monthKeys {
            if let budget = store.monthlyBudget(year: monthKey.year, month: monthKey.month) {
                for item in budget.items where !names.contains(where: { $0.caseInsensitiveCompare(item.categoryName) == .orderedSame }) {
                    names.append(item.categoryName)
                }
            }
        }

        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var hasInvalidAmounts: Bool {
        amountTexts.values.contains { text in
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            Double(text.replacingOccurrences(of: ",", with: ".")) == nil
        }
    }

    var body: some View {
        List {
            Section {
                controls
            }

            Section {
                Text(store.appLanguage == .arabicEgyptian ? "عدّل المخطط بس. المدفوع والأرصدة مش بيتغيروا من هنا." : "Edit planned budget values only. Paid spending and balances do not change here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(store.appLanguage == .arabicEgyptian ? "استخدمها لتخطيط كذا شهر قدام بسرعة." : "Use this for fast planning across future months.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(store.appLanguage == .arabicEgyptian ? "أدوات التخطيط السريع" : "Fast Planning Tools") {
                planningTools
            }

            Section(store.appLanguage == .arabicEgyptian ? "البنود" : "Categories") {
                ForEach(categoryNames, id: \.self) { categoryName in
                    categoryPlannerRow(categoryName)
                }
            }

            Section {
                Button {
                    savePlannerValues()
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "احفظ التخطيط" : "Save Planner")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(hasInvalidAmounts)

                if let saveMessage {
                    Text(saveMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "مخطط الشهور" : "Multi-Month Planner")
        .onAppear {
            loadPlannerValues()
        }
        .onChange(of: startMonthDate) { _, _ in
            loadPlannerValues()
        }
        .onChange(of: monthCount) { _, _ in
            loadPlannerValues()
        }
        .onChange(of: categoryNames) { _, newValue in
            updateFillCategoryIfNeeded(newValue)
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: $showPlannerConfirmation,
            titleVisibility: .visible
        ) {
            if let pendingPlannerAction {
                Button(confirmationConfirmTitle(for: pendingPlannerAction), role: .destructive) {
                    applyPlannerAction(pendingPlannerAction)
                    self.pendingPlannerAction = nil
                }
            }

            Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel", role: .cancel) {
                pendingPlannerAction = nil
            }
        } message: {
            if let pendingPlannerAction {
                Text(confirmationMessage(for: pendingPlannerAction))
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    moveStartMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                VStack(spacing: 3) {
                    Text(store.appLanguage == .arabicEgyptian ? "بداية التخطيط" : "Start Month")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(monthTitle(startMonthDate))
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                Spacer()

                Button {
                    moveStartMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            Picker(store.appLanguage == .arabicEgyptian ? "عدد الشهور" : "Months", selection: $monthCount) {
                ForEach(monthCountOptions, id: \.self) { option in
                    Text("\(option)").tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }

    private var planningTools: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                requestConfirmation(.copyToNextMonth)
            } label: {
                Label(
                    store.appLanguage == .arabicEgyptian ? "انسخ الشهر ده للشهر الجاي" : "Copy this month to next month",
                    systemImage: "doc.on.doc"
                )
            }

            Button {
                requestConfirmation(.copyToNextThreeMonths)
            } label: {
                Label(
                    store.appLanguage == .arabicEgyptian ? "انسخ لـ ٣ شهور جاية" : "Copy this month to next 3 months",
                    systemImage: "square.stack.3d.up"
                )
            }

            Divider()

            Picker(store.appLanguage == .arabicEgyptian ? "البند" : "Category", selection: $selectedFillCategoryName) {
                ForEach(categoryNames, id: \.self) { categoryName in
                    Text(categoryName).tag(categoryName)
                }
            }

            TextField(store.appLanguage == .arabicEgyptian ? "المبلغ" : "Amount", text: $fillAmountText)
                .keyboardType(.decimalPad)

            Button {
                requestConfirmation(.fillVisibleMonths)
            } label: {
                Label(
                    store.appLanguage == .arabicEgyptian ? "ملء نفس المبلغ للشهور المعروضة" : "Fill same amount across visible months",
                    systemImage: "arrow.left.and.right"
                )
            }
            .disabled(selectedFillCategoryName.isEmpty || fillAmount <= 0)

            Text(store.appLanguage == .arabicEgyptian ? "الأدوات دي بتغيّر المخطط بس. المدفوع والأرصدة مش بيتغيروا." : "These tools change planned values only. Paid spending and balances do not change.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .onAppear {
            updateFillCategoryIfNeeded(categoryNames)
        }
    }

    private func categoryPlannerRow(_ categoryName: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(categoryName)
                .font(.headline)

            ForEach(monthKeys, id: \.date) { monthKey in
                HStack {
                    Text(shortMonthTitle(monthKey.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 78, alignment: .leading)

                    TextField("0", text: binding(for: categoryName, year: monthKey.year, month: monthKey.month))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func binding(for categoryName: String, year: Int, month: Int) -> Binding<String> {
        let key = textKey(categoryName: categoryName, year: year, month: month)

        return Binding(
            get: {
                amountTexts[key] ?? ""
            },
            set: { newValue in
                amountTexts[key] = newValue
                saveMessage = nil
            }
        )
    }

    private func loadPlannerValues() {
        var values: [String: String] = [:]

        for monthKey in monthKeys {
            let budget = store.monthlyBudget(year: monthKey.year, month: monthKey.month)

            for categoryName in categoryNames {
                let plannedAmount = budget?.items.first { $0.categoryName == categoryName }?.plannedAmount ?? 0
                values[textKey(categoryName: categoryName, year: monthKey.year, month: monthKey.month)] = plannedAmount > 0 ? cleanNumberText(plannedAmount) : ""
            }
        }

        amountTexts = values
        saveMessage = nil
    }

    private func savePlannerValues() {
        guard !hasInvalidAmounts else {
            return
        }

        for monthKey in monthKeys {
            var plannedAmounts: [String: Double] = [:]

            for categoryName in categoryNames {
                let key = textKey(categoryName: categoryName, year: monthKey.year, month: monthKey.month)
                let text = amountTexts[key] ?? ""
                plannedAmounts[categoryName] = Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
            }

            store.saveMonthlyBudget(
                year: monthKey.year,
                month: monthKey.month,
                plannedAmountsByCategory: plannedAmounts
            )
        }

        loadPlannerValues()
        saveMessage = store.appLanguage == .arabicEgyptian ? "تم حفظ التخطيط." : "Planner saved."
    }

    private var fillAmount: Double {
        Double(fillAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var confirmationTitle: String {
        store.appLanguage == .arabicEgyptian ? "تأكيد التغيير" : "Confirm Planning Change"
    }

    private func confirmationConfirmTitle(for action: PendingPlannerAction) -> String {
        switch action {
        case .copyToNextMonth, .copyToNextThreeMonths:
            return store.appLanguage == .arabicEgyptian ? "انسخ المخطط" : "Copy Plan"
        case .fillVisibleMonths:
            return store.appLanguage == .arabicEgyptian ? "املأ المبلغ" : "Fill Amount"
        }
    }

    private func confirmationMessage(for action: PendingPlannerAction) -> String {
        switch action {
        case .copyToNextMonth:
            return store.appLanguage == .arabicEgyptian ? "هيتم نسخ مخطط \(monthTitle(startMonthDate)) للشهر الجاي. ده هيستبدل المخطط الموجود للشهر الجاي فقط." : "This copies \(monthTitle(startMonthDate)) planned values to the next month and replaces that month’s planned values only."
        case .copyToNextThreeMonths:
            return store.appLanguage == .arabicEgyptian ? "هيتم نسخ مخطط \(monthTitle(startMonthDate)) لـ ٣ شهور جاية. ده هيستبدل المخطط الموجود للشهور دي فقط." : "This copies \(monthTitle(startMonthDate)) planned values to the next 3 months and replaces planned values for those months only."
        case .fillVisibleMonths:
            return store.appLanguage == .arabicEgyptian ? "هيتم ملء \(selectedFillCategoryName) بنفس المبلغ في الشهور المعروضة. المدفوع والأرصدة مش هيتغيروا." : "This fills \(selectedFillCategoryName) with the same amount across the visible months. Paid spending and balances will not change."
        }
    }

    private func applyPlannerAction(_ action: PendingPlannerAction) {
        switch action {
        case .copyToNextMonth:
            copyStartMonth(toFutureMonthCount: 1)
        case .copyToNextThreeMonths:
            copyStartMonth(toFutureMonthCount: 3)
        case .fillVisibleMonths:
            fillSelectedCategoryAcrossVisibleMonths()
        }
    }

    private func requestConfirmation(_ action: PendingPlannerAction) {
        pendingPlannerAction = action
        showPlannerConfirmation = true
    }

    private func copyStartMonth(toFutureMonthCount futureMonthCount: Int) {
        guard !hasInvalidAmounts else {
            return
        }

        let sourceValues = plannedAmountsFromVisibleFields(for: startMonthDate)

        for offset in 1...futureMonthCount {
            guard let targetDate = Calendar.current.date(byAdding: .month, value: offset, to: startMonthDate) else {
                continue
            }

            let components = Calendar.current.dateComponents([.year, .month], from: targetDate)

            guard let year = components.year,
                  let month = components.month else {
                continue
            }

            store.saveMonthlyBudget(
                year: year,
                month: month,
                plannedAmountsByCategory: sourceValues
            )
        }

        loadPlannerValues()
        saveMessage = futureMonthCount == 1
        ? (store.appLanguage == .arabicEgyptian ? "تم نسخ الشهر للشهر الجاي." : "Copied this month to next month.")
        : (store.appLanguage == .arabicEgyptian ? "تم نسخ الشهر لـ ٣ شهور جاية." : "Copied this month to the next 3 months.")
    }

    private func fillSelectedCategoryAcrossVisibleMonths() {
        guard fillAmount > 0,
              !selectedFillCategoryName.isEmpty else {
            return
        }

        for monthKey in monthKeys {
            amountTexts[textKey(categoryName: selectedFillCategoryName, year: monthKey.year, month: monthKey.month)] = cleanNumberText(fillAmount)
        }

        savePlannerValues()
        saveMessage = store.appLanguage == .arabicEgyptian ? "تم ملء المبلغ للشهور المعروضة." : "Filled amount across visible months."
    }

    private func plannedAmountsFromVisibleFields(for date: Date) -> [String: Double] {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        let year = components.year ?? 2026
        let month = components.month ?? 1
        var plannedAmounts: [String: Double] = [:]

        for categoryName in categoryNames {
            let key = textKey(categoryName: categoryName, year: year, month: month)
            let text = amountTexts[key] ?? ""
            plannedAmounts[categoryName] = Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
        }

        return plannedAmounts
    }

    private func updateFillCategoryIfNeeded(_ names: [String]) {
        guard !names.isEmpty else {
            selectedFillCategoryName = ""
            return
        }

        if selectedFillCategoryName.isEmpty || !names.contains(selectedFillCategoryName) {
            selectedFillCategoryName = names[0]
        }
    }

    private func textKey(categoryName: String, year: Int, month: Int) -> String {
        "\(year)-\(month)-\(categoryName)"
    }

    private func moveStartMonth(by value: Int) {
        startMonthDate = Calendar.current.date(byAdding: .month, value: value, to: startMonthDate) ?? startMonthDate
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func shortMonthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
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
