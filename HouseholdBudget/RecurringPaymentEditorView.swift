import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RecurringPaymentEditorView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss
    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    let event: FinancialEvent

    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var selectedAccountName: String = ""
    @State private var selectedCategoryName: String = ""
    @State private var selectedSubCategoryName: String = ""
    @State private var incomeType: IncomeType = .unknown
    @State private var reimbursementCategoryName: String = ""
    @State private var dueDate: Date = Date()
    @State private var amountMode: RecurringAmountMode = .fixedAmount
    @State private var variableIncomePlanningMonthCount = 3
    @State private var estimatedAmountText: String = ""
    @State private var repeatRule: RepeatRule = .monthly
    @State private var recurringEndKind: RecurringEndKind = .never
    @State private var recurringEndDate: Date = Date()
    @State private var recurringEndPaymentCountText: String = ""
    @State private var overrideMonthDate: Date = Date()
    @State private var overrideAmountText: String = ""
    @State private var overrideIsSkipped = false
    @State private var overrideNote: String = ""
    @State private var overrideDrafts: [RecurringScheduleOverride] = []
    @State private var monthAmountTexts: [String: String] = [:]
    @State private var note: String = ""
    @State private var selectionRoute: AddRecurringSelectionRoute?

    @State private var showDeleteConfirmation = false

    private var isIncomeSeries: Bool {
        event.type == .income
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(store.appLanguage == .arabicEgyptian ? "نطاق التعديل" : "Edit Scope") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isIncomeSeries
                             ? (store.appLanguage == .arabicEgyptian ? "بيانات الدخل تحت بتعدّل السلسلة كلها." : "Income details below update the entire series.")
                             : (store.appLanguage == .arabicEgyptian ? "بيانات الدفع تحت بتعدّل السلسلة كلها." : "Payment details below update the entire series."))

                        Text(isIncomeSeries
                             ? (store.appLanguage == .arabicEgyptian ? "تعديل شهر معين يغيّر شهر واحد بس من غير ما يعمل دخل مكرر." : "Month changes affect one expected income only without creating duplicate income.")
                             : (store.appLanguage == .arabicEgyptian ? "تعديل شهر معين يغيّر شهر واحد بس من غير ما يعمل حركة مكررة." : "Month Overrides change one month only without creating a duplicate transaction."))

                        Text(store.appLanguage == .arabicEgyptian ? "تعديل من شهر ده واللي بعده لسه مش متفعل عشان ما نكسرش التخطيط بالغلط." : "This-and-future editing is not automatic yet to avoid accidental planning changes.")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section(isIncomeSeries ? (isAr ? "تفاصيل الدخل" : "Income Details") : (isAr ? "تفاصيل الدفعة" : "Payment Details")) {
                    TextField(isIncomeSeries ? (isAr ? "اسم الدخل" : "Income name") : (isAr ? "اسم الدفعة" : "Payment name"), text: $title)

                    TextField(amountMode == .fixedAmount ? (isAr ? "المبلغ" : "Amount") : (isAr ? "المبلغ الافتراضي" : "Default amount"), text: $amountText)
                        .keyboardType(.decimalPad)
                }

                Section(isIncomeSeries ? (store.appLanguage == .arabicEgyptian ? "نمط الدخل" : "Income Pattern") : (store.appLanguage == .arabicEgyptian ? "نوع المبلغ" : "Amount Mode")) {
                    Picker(isIncomeSeries ? (store.appLanguage == .arabicEgyptian ? "نمط الدخل" : "Income Pattern") : (store.appLanguage == .arabicEgyptian ? "نوع المبلغ" : "Amount Mode"), selection: $amountMode) {
                        if isIncomeSeries {
                            Text(store.appLanguage == .arabicEgyptian ? "نفس المبلغ كل شهر" : "Same amount every month")
                                .tag(RecurringAmountMode.fixedAmount)

                            Text(store.appLanguage == .arabicEgyptian ? "مبلغ مختلف كل شهر" : "Different amount each month")
                                .tag(RecurringAmountMode.variableEachMonth)
                        } else {
                            ForEach(RecurringAmountMode.allCases) { mode in
                                Text(mode.title(language: store.appLanguage))
                                    .tag(mode)
                            }
                        }
                    }

                    if amountMode != .fixedAmount {
                        if !isIncomeSeries {
                            TextField(store.appLanguage == .arabicEgyptian ? "مبلغ شهري تقديري" : "Estimated monthly amount", text: $estimatedAmountText)
                                .keyboardType(.decimalPad)
                        }

                        Text(isIncomeSeries
                             ? (store.appLanguage == .arabicEgyptian ? "حدد الدخل المتوقع لكل شهر. هذا لا يغير الرصيد حتى تسجل الدخل كمستلم." : "Set the expected income for each month. This does not change your balance until you mark the income received.")
                             : (store.appLanguage == .arabicEgyptian ? "الشهور غير المؤكدة تستخدم المبلغ التقديري للتخطيط فقط." : "Unconfirmed months use the estimate for planning only."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(isIncomeSeries ? (isAr ? "تاريخ الدخل" : "Income Date") : (isAr ? "تاريخ الاستحقاق" : "Due Date")) {
                    DatePicker(
                        isIncomeSeries ? (isAr ? "أول تاريخ متوقع" : "First Expected Date") : (isAr ? "أول تاريخ استحقاق" : "First Due Date"),
                        selection: $dueDate,
                        displayedComponents: .date
                    )
                }

                if !(isIncomeSeries && amountMode == .variableEachMonth) {
                    Section(isAr ? "التكرار" : "Repeat") {
                        Picker(isAr ? "التكرار" : "Repeat", selection: $repeatRule) {
                            Text(AppText.repeatRuleLabel(.monthly, language: store.appLanguage)).tag(RepeatRule.monthly)
                            Text(AppText.repeatRuleLabel(.quarterly, language: store.appLanguage)).tag(RepeatRule.quarterly)
                            Text(AppText.repeatRuleLabel(.yearly, language: store.appLanguage)).tag(RepeatRule.yearly)
                        }

                        Picker(endLabel, selection: $recurringEndKind) {
                            Text(neverLabel).tag(RecurringEndKind.never)
                            Text(onDateLabel).tag(RecurringEndKind.onDate)
                            Text(afterPaymentsLabel).tag(RecurringEndKind.afterNumberOfPayments)
                        }

                        if recurringEndKind == .onDate {
                            DatePicker(
                                onDateLabel,
                                selection: $recurringEndDate,
                                displayedComponents: .date
                            )
                        }

                        if recurringEndKind == .afterNumberOfPayments {
                            TextField(afterPaymentsLabel, text: $recurringEndPaymentCountText)
                                .keyboardType(.numberPad)
                        }
                    }
                }

                if amountMode == .variableEachMonth {
                    if isIncomeSeries {
                        Section(store.appLanguage == .arabicEgyptian ? "فترة التخطيط" : "Planning Period") {
                            Picker(store.appLanguage == .arabicEgyptian ? "خطط لمدة" : "Plan for", selection: $variableIncomePlanningMonthCount) {
                                Text("3").tag(3)
                                Text("6").tag(6)
                                Text("12").tag(12)
                            }
                            .pickerStyle(.segmented)

                            Button(store.appLanguage == .arabicEgyptian ? "أضف 3 شهور" : "Add 3 more months") {
                                variableIncomePlanningMonthCount = min(variableIncomePlanningMonthCount + 3, 24)
                            }

                            Text(store.appLanguage == .arabicEgyptian ? "الشهور خارج فترة التخطيط لا تظهر في القادم أو التوقعات." : "Months outside the planning period do not appear in Upcoming or forecasts.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    RecurringMonthlyAmountsSection(
                        startDate: dueDate,
                        monthAmountTexts: $monthAmountTexts,
                        visibleMonthCount: isIncomeSeries ? variableIncomePlanningMonthCount : 12,
                        title: isIncomeSeries ? (store.appLanguage == .arabicEgyptian ? "المبلغ المتوقع حسب الشهر" : "Expected amount by month") : nil,
                        helpText: isIncomeSeries ? (store.appLanguage == .arabicEgyptian ? "حدد الدخل المتوقع لكل شهر. الشهر الفارغ لا يظهر في التوقعات." : "Set the expected income for each month. Empty months do not appear in forecasts.") : nil,
                        positiveStatusText: isIncomeSeries ? (store.appLanguage == .arabicEgyptian ? "دخل متوقع" : "Expected income") : nil,
                        emptyStatusText: isIncomeSeries ? (store.appLanguage == .arabicEgyptian ? "غير محدد" : "Not set") : nil,
                        semanticColor: isIncomeSeries ? .accounts : .obligations
                    )
                } else {
                    Section(isIncomeSeries ? (store.appLanguage == .arabicEgyptian ? "استثناءات شهرية" : "Monthly Exceptions") : (store.appLanguage == .arabicEgyptian ? "تعديل شهر معين" : "Month Overrides")) {
                        Text(isIncomeSeries
                             ? (store.appLanguage == .arabicEgyptian ? "غيّر مبلغ دخل شهر واحد أو تخطى الدخل لهذا الشهر." : "Change one month's expected amount or skip this income.")
                             : (store.appLanguage == .arabicEgyptian ? "غيّر مبلغ شهر واحد أو خلّيه متخطي من غير ما تعمل حركة مكررة." : "Change one month or skip it without creating a duplicate transaction."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        DatePicker(
                            store.appLanguage == .arabicEgyptian ? "الشهر" : "Month",
                            selection: $overrideMonthDate,
                            displayedComponents: .date
                        )

                        Toggle(isIncomeSeries ? (store.appLanguage == .arabicEgyptian ? "تخطي الدخل هذا الشهر" : "Skip this income") : (store.appLanguage == .arabicEgyptian ? "تخطي الشهر ده" : "Skip this month"), isOn: $overrideIsSkipped)

                        if !overrideIsSkipped {
                            TextField(isIncomeSeries ? (store.appLanguage == .arabicEgyptian ? "مبلغ الدخل المتوقع هذا الشهر" : "Expected amount this month") : (store.appLanguage == .arabicEgyptian ? "مبلغ الشهر" : "Month amount"), text: $overrideAmountText)
                                .keyboardType(.decimalPad)
                        }

                        TextField(store.appLanguage == .arabicEgyptian ? "ملاحظة اختيارية" : "Optional note", text: $overrideNote)

                        Button {
                            saveOverrideDraft()
                        } label: {
                            Text(isIncomeSeries ? (store.appLanguage == .arabicEgyptian ? "احفظ تغيير الشهر" : "Save Month Change") : (store.appLanguage == .arabicEgyptian ? "احفظ تعديل الشهر" : "Save Month Override"))
                        }
                        .disabled(!canSaveOverrideDraft)

                        if !overrideDrafts.isEmpty {
                            ForEach(sortedOverrideDrafts) { override in
                                overrideRow(override)
                            }
                        }
                    }
                }

                Section(isAr ? "الحساب" : "Account") {
                    Button {
                        dismissKeyboard()
                        selectionRoute = .account
                    } label: {
                        selectionRow(
                            title: isAr ? "الحساب" : "Account",
                            value: selectedAccountName
                        )
                    }
                    .buttonStyle(.plain)
                }

                if isIncomeSeries {
                    Section(store.appLanguage == .arabicEgyptian ? "نوع الدخل" : "Income Type") {
                        Picker(store.appLanguage == .arabicEgyptian ? "نوع الدخل" : "Income Type", selection: $incomeType) {
                            ForEach(IncomeType.allCases) { type in
                                Text(type.title(language: store.appLanguage))
                                    .tag(type)
                            }
                        }

                        if incomeType == .reimbursement {
                            Picker(store.appLanguage == .arabicEgyptian ? "استرداد عن" : "Reimbursement for", selection: $reimbursementCategoryName) {
                                Text(store.appLanguage == .arabicEgyptian ? "اختر تصنيف" : "Select category")
                                    .tag("")

                                ForEach(store.categories.filter { $0.isActive }) { category in
                                    Text(category.name)
                                        .tag(category.name)
                                }
                            }
                        }
                    }
                } else {
                    Section(isAr ? "التصنيف" : "Category") {
                        CategorySubcategoryPickerView(
                            categoryName: $selectedCategoryName,
                            subCategoryName: $selectedSubCategoryName,
                            includesInactiveSelection: true
                        )
                    }
                }

                Section(isAr ? "ملاحظة" : "Note") {
                    TextField(isAr ? "ملاحظة اختيارية" : "Optional note", text: $note)
                }

                Section {
                    Text(isIncomeSeries
                         ? (isAr ? "تعديل هذا الدخل يغيّر التوقعات القادمة فقط. لا يغير الرصيد إلا عند التسجيل كمستلم." : "Editing this income changes future expected income only. It does not change balance until marked received.")
                         : (isAr ? "تعديل هذه الدفعة يغيّر التوقع المستقبلي لهذه الدفعة المتكررة." : "Editing this payment changes the future forecast for this recurring payment."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        saveChanges()
                    } label: {
                        HStack {
                            Spacer()
                            Text(store.appLanguage == .arabicEgyptian ? "حفظ التغييرات" : "Save Changes")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }

                Section(isAr ? "منطقة الخطر" : "Danger Zone") {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text(isIncomeSeries ? (isAr ? "حذف الدخل المتكرر" : "Delete Recurring Income") : (isAr ? "حذف الدفعة المتكررة" : "Delete Recurring Payment"))
                    }
                }
            }
            .navigationTitle(isIncomeSeries ? (isAr ? "تعديل دخل متكرر" : "Edit Recurring Income") : (isAr ? "تعديل دفعة متكررة" : "Edit Recurring"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isAr ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupInitialValues()
            }
            .onChange(of: selectedCategoryName) { _, newValue in
                updateSubcategoryForCategory(newValue)
            }
            .onChange(of: amountMode) { _, newValue in
                if newValue != .variableEachMonth {
                    monthAmountTexts = [:]
                }
            }
            .sheet(item: $selectionRoute) { route in
                AddRecurringCategorySelectionSheet(
                    route: route,
                    accounts: accountsForEditing,
                    categories: categoriesForEditing,
                    subcategories: availableSubcategories,
                    selectedAccountName: selectedAccountName,
                    selectedCategoryName: selectedCategoryName,
                    selectedSubCategoryName: selectedSubCategoryName,
                    onSelectAccount: { accountName in
                        selectedAccountName = accountName
                        selectionRoute = nil
                    },
                    onSelectCategory: { categoryName in
                        selectedCategoryName = categoryName
                        updateSubcategoryForCategory(categoryName)
                        selectionRoute = nil
                    },
                    onSelectSubcategory: { subcategoryName in
                        selectedSubCategoryName = subcategoryName
                        selectionRoute = nil
                    }
                )
                .environmentObject(store)
            }
            .confirmationDialog(
                isIncomeSeries ? (isAr ? "حذف هذا الدخل المتكرر؟" : "Delete this recurring income?") : (isAr ? "حذف هذه الدفعة المتكررة؟" : "Delete this recurring payment?"),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(isIncomeSeries ? (isAr ? "حذف الدخل المتكرر" : "Delete Recurring Income") : (isAr ? "حذف الدفعة المتكررة" : "Delete Recurring Payment"), role: .destructive) {
                    store.deleteFinancialEvent(event)
                    dismiss()
                }

                Button(isAr ? "إلغاء" : "Cancel", role: .cancel) { }
            } message: {
                Text(isAr ? "سيُزال من التخطيط والتوقعات المستقبلية." : "This will remove it from future planning and forecast.")
            }
        }
    }

    private var amount: Double {
        parseAmountText(amountText)
    }

    private var estimatedAmount: Double {
        parseAmountText(estimatedAmountText)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        amountIsValid &&
        !selectedAccountName.isEmpty &&
        (isIncomeSeries || (!selectedCategoryName.isEmpty && !selectedSubCategoryName.isEmpty)) &&
        (!isIncomeSeries || incomeType != .reimbursement || !reimbursementCategoryName.isEmpty) &&
        repeatRule != .none &&
        recurringEndIsValid
    }

    private var amountIsValid: Bool {
        if amountMode == .fixedAmount {
            return amount > 0
        }

        if amountMode == .variableEachMonth {
            return firstPositiveInlineMonthAmount > 0
        }

        return recurringBaseAmount > 0
    }

    private var availableSubcategories: [String] {
        store.subcategoriesForEditing(
            categoryName: selectedCategoryName,
            selectedSubcategoryName: selectedSubCategoryName
        )
    }

    private var categoriesForEditing: [Category] {
        var categories = store.categories.filter { $0.isActive }

        if let inactiveCategory = store.categories.first(where: { $0.name == selectedCategoryName && !$0.isActive }),
           !categories.contains(where: { $0.id == inactiveCategory.id }) {
            categories.append(inactiveCategory)
        }

        return categories.sorted { $0.name < $1.name }
    }

    private var accountsForEditing: [Account] {
        var accounts = store.accounts.filter { $0.isActive }

        if let inactiveAccount = store.accounts.first(where: { $0.name == selectedAccountName && !$0.isActive }),
           !accounts.contains(where: { $0.id == inactiveAccount.id }) {
            accounts.append(inactiveAccount)
        }

        return accounts.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var sortedOverrideDrafts: [RecurringScheduleOverride] {
        overrideDrafts.sorted {
            if $0.year == $1.year {
                return $0.month < $1.month
            }

            return $0.year < $1.year
        }
    }

    private var firstPositiveOverrideAmount: Double {
        sortedOverrideDrafts.first { !$0.isSkipped && $0.amount > 0 }?.amount ?? 0
    }

    private var inlineMonthlyOverrides: [RecurringScheduleOverride] {
        RecurringMonthlyAmountsSection.visibleMonthKeys(
            startDate: dueDate,
            visibleMonthCount: isIncomeSeries && amountMode == .variableEachMonth ? variableIncomePlanningMonthCount : 12
        ).compactMap { key in
            let amount = RecurringMonthlyAmountsSection.parseAmountText(monthAmountTexts[key.id] ?? "")
            guard amount > 0 else {
                return nil
            }

            let existingID = overrideDrafts.first { $0.year == key.year && $0.month == key.month }?.id
            return RecurringScheduleOverride(
                id: existingID ?? UUID(),
                year: key.year,
                month: key.month,
                amount: amount,
                isSkipped: false,
                note: nil,
                updatedAt: Date()
            )
        }
    }

    private var firstPositiveInlineMonthAmount: Double {
        inlineMonthlyOverrides.first?.amount ?? 0
    }

    private var recurringBaseAmount: Double {
        if amountMode == .variableEachMonth {
            return firstPositiveInlineMonthAmount
        }

        if amount > 0 {
            return amount
        }

        if estimatedAmount > 0 {
            return estimatedAmount
        }

        return firstPositiveOverrideAmount
    }

    private var recurringEndPaymentCount: Int? {
        Int(recurringEndPaymentCountText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var overrideAmount: Double {
        parseAmountText(overrideAmountText)
    }

    private var canSaveOverrideDraft: Bool {
        overrideIsSkipped || overrideAmount > 0
    }

    private var recurringEndIsValid: Bool {
        if isIncomeSeries && amountMode == .variableEachMonth {
            return variableIncomePlanningMonthCount > 0
        }

        switch recurringEndKind {
        case .never:
            return true
        case .onDate:
            return recurringEndDate >= dueDate
        case .afterNumberOfPayments:
            return (recurringEndPaymentCount ?? 0) > 0
        }
    }

    private var recurringEndKindForSave: RecurringEndKind? {
        if isIncomeSeries && amountMode == .variableEachMonth {
            return .afterNumberOfPayments
        }

        return recurringEndKind == .never ? nil : recurringEndKind
    }

    private var recurringEndDateForSave: Date? {
        guard !(isIncomeSeries && amountMode == .variableEachMonth),
              recurringEndKind == .onDate else {
            return nil
        }

        return recurringEndDate
    }

    private var recurringEndPaymentCountForSave: Int? {
        if isIncomeSeries && amountMode == .variableEachMonth {
            return variableIncomePlanningMonthCount
        }

        return recurringEndKind == .afterNumberOfPayments ? recurringEndPaymentCount : nil
    }

    private var endLabel: String {
        store.appLanguage == .arabicEgyptian ? "ينتهي" : "Ends"
    }

    private var neverLabel: String {
        store.appLanguage == .arabicEgyptian ? "بدون نهاية" : "Never"
    }

    private var onDateLabel: String {
        store.appLanguage == .arabicEgyptian ? "في تاريخ" : "On date"
    }

    private var afterPaymentsLabel: String {
        store.appLanguage == .arabicEgyptian ? "بعد عدد دفعات" : "After number of payments"
    }

    private func setupInitialValues() {
        title = event.title
        amountText = cleanNumberText(event.amount)
        selectedAccountName = event.accountName ?? store.accounts.first?.name ?? ""
        selectedCategoryName = event.categoryName ?? store.categories.first { $0.isActive }?.name ?? ""
        selectedSubCategoryName = event.subCategoryName ?? ""
        incomeType = event.incomeType ?? .unknown
        reimbursementCategoryName = event.reimbursementCategoryName ?? ""
        dueDate = event.date
        amountMode = event.effectiveRecurringAmountMode
        let savedEstimate = event.effectiveRecurringEstimatedAmount
        estimatedAmountText = savedEstimate > 0 ? cleanNumberText(savedEstimate) : ""
        repeatRule = event.repeatRule == .none ? .monthly : event.repeatRule
        recurringEndKind = event.recurringEndKind ?? .never
        recurringEndDate = event.recurringEndDate ?? event.date
        recurringEndPaymentCountText = event.recurringEndPaymentCount.map { "\($0)" } ?? ""
        variableIncomePlanningMonthCount = max(event.recurringEndPaymentCount ?? 3, 3)
        overrideMonthDate = Self.startOfMonth(for: Date())
        overrideAmountText = cleanNumberText(event.amount)
        overrideDrafts = event.recurringScheduleOverrides ?? []
        monthAmountTexts = monthTexts(from: overrideDrafts)
        note = event.note ?? ""

        if !isIncomeSeries && selectedSubCategoryName.isEmpty {
            selectedSubCategoryName =
            availableSubcategories.first ?? ""
        }
    }

    private func updateSubcategoryForCategory(_ categoryName: String) {
        let subcategories = store.subcategoriesForEditing(
            categoryName: categoryName,
            selectedSubcategoryName: selectedSubCategoryName
        )

        if !subcategories.contains(selectedSubCategoryName) {
            selectedSubCategoryName = subcategories.first ?? ""
        }
    }

    private func saveChanges() {
        var updatedEvent = event
        let baseAmount = recurringBaseAmount

        updatedEvent.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedEvent.amount = baseAmount
        updatedEvent.date = dueDate
        updatedEvent.accountName = selectedAccountName
        updatedEvent.categoryName = isIncomeSeries ? nil : selectedCategoryName
        updatedEvent.subCategoryName = isIncomeSeries ? nil : selectedSubCategoryName
        updatedEvent.incomeType = isIncomeSeries ? incomeType : nil
        updatedEvent.reimbursementCategoryName = isIncomeSeries && incomeType == .reimbursement ? reimbursementCategoryName : nil
        updatedEvent.repeatRule = isIncomeSeries && amountMode == .variableEachMonth ? .monthly : repeatRule
        updatedEvent.recurringEndKind = recurringEndKindForSave
        updatedEvent.recurringEndDate = recurringEndDateForSave
        updatedEvent.recurringEndPaymentCount = recurringEndPaymentCountForSave
        let savedOverrides = amountMode == .variableEachMonth ? inlineMonthlyOverrides : sortedOverrideDrafts
        updatedEvent.recurringScheduleOverrides = savedOverrides.isEmpty ? nil : savedOverrides
        updatedEvent.recurringAmountMode = amountMode == .fixedAmount ? nil : amountMode
        updatedEvent.recurringEstimatedAmount = amountMode == .estimatedUntilConfirmed && estimatedAmount > 0 ? estimatedAmount : nil
        updatedEvent.confidence = .high
        updatedEvent.note = note.isEmpty ? nil : note

        store.updateFinancialEvent(updatedEvent)
        dismiss()
    }

    private func upsertOverride(year: Int, month: Int, amount: Double, isSkipped: Bool, note: String?) {
        var override = RecurringScheduleOverride(
            year: year,
            month: month,
            amount: max(amount, 0),
            isSkipped: isSkipped,
            note: note,
            updatedAt: Date()
        )

        if let index = overrideDrafts.firstIndex(where: { $0.year == year && $0.month == month }) {
            override.id = overrideDrafts[index].id
            overrideDrafts[index] = override
        } else {
            overrideDrafts.append(override)
        }

        overrideDrafts.sort {
            if $0.year == $1.year {
                return $0.month < $1.month
            }

            return $0.year < $1.year
        }
    }

    private func removeOverride(year: Int, month: Int) {
        overrideDrafts.removeAll { $0.year == year && $0.month == month }
    }

    private func monthTexts(from overrides: [RecurringScheduleOverride]) -> [String: String] {
        var texts: [String: String] = [:]

        for override in overrides where !override.isSkipped && override.amount > 0 {
            texts[RecurringMonthlyAmountsSection.monthID(year: override.year, month: override.month)] = cleanNumberText(override.amount)
        }

        return texts
    }

    private func selectionRow(title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            Text(value.isEmpty ? "-" : value)
                .foregroundStyle(value.isEmpty ? .secondary : .primary)
                .multilineTextAlignment(.trailing)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private func dismissKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }

    private func cleanNumberText(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return "\(amount)"
    }

    private func parseAmountText(_ text: String) -> Double {
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

    private func overrideRow(_ override: RecurringScheduleOverride) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(monthTitle(year: override.year, month: override.month))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(override.isSkipped ? (store.appLanguage == .arabicEgyptian ? "متخطي" : "Skipped") : store.displayCurrency(override.amount))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let note = override.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(role: .destructive) {
                deleteOverrideDraft(override)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    private func saveOverrideDraft() {
        let components = Calendar.current.dateComponents([.year, .month], from: overrideMonthDate)

        guard let year = components.year,
              let month = components.month else {
            return
        }

        let override = RecurringScheduleOverride(
            year: year,
            month: month,
            amount: overrideIsSkipped ? 0 : overrideAmount,
            isSkipped: overrideIsSkipped,
            note: overrideNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : overrideNote.trimmingCharacters(in: .whitespacesAndNewlines),
            updatedAt: Date()
        )

        if let index = overrideDrafts.firstIndex(where: { $0.year == year && $0.month == month }) {
            overrideDrafts[index] = override
        } else {
            overrideDrafts.append(override)
        }

        overrideAmountText = cleanNumberText(amount)
        overrideIsSkipped = false
        overrideNote = ""
    }

    private func deleteOverrideDraft(_ override: RecurringScheduleOverride) {
        overrideDrafts.removeAll { $0.id == override.id }
    }

    private func monthTitle(year: Int, month: Int) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let date = Calendar.current.date(from: components) else {
            return "\(month)/\(year)"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    private static func startOfMonth(for date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }
}

// MARK: - Preview

struct RecurringPaymentEditorView_Previews: PreviewProvider {
    static var previews: some View {
        RecurringPaymentEditorView(
            event: SampleWalletData.financialEvents.first {
                $0.repeatRule != .none
            } ?? SampleWalletData.financialEvents[0]
        )
        .environmentObject(WalletStore())
    }
}
