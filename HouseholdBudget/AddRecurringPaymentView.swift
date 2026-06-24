import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AddRecurringPaymentView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss
    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var selectedAccountName: String = ""
    @State private var selectedCategoryName: String = ""
    @State private var selectedSubCategoryName: String = ""
    @State private var dueDate: Date = Date()
    @State private var amountMode: RecurringAmountMode = .fixedAmount
    @State private var estimatedAmountText: String = ""
    @State private var monthAmountTexts: [String: String] = [:]
    @State private var repeatRule: RepeatRule = .monthly
    @State private var recurringEndKind: RecurringEndKind = .never
    @State private var recurringEndDate: Date = Date()
    @State private var recurringEndPaymentCountText: String = ""
    @State private var note: String = ""
    @State private var selectionRoute: AddRecurringSelectionRoute?

    var body: some View {
        NavigationStack {
            Form {
                Section(isAr ? "تفاصيل الدفعة" : "Payment Details") {
                    TextField(isAr ? "مثال: إيجار، حضانة، نتفليكس" : "Example: Rent, Nursery, Netflix", text: $title)
                        .pocketWiseInputField(semanticColor: .obligations)

                    TextField(amountMode == .fixedAmount ? (isAr ? "المبلغ" : "Amount") : (isAr ? "المبلغ الافتراضي" : "Default amount"), text: $amountText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .obligations, isProminent: true)
                }

                Section(store.appLanguage == .arabicEgyptian ? "نوع المبلغ" : "Amount Mode") {
                    Picker(store.appLanguage == .arabicEgyptian ? "نوع المبلغ" : "Amount Mode", selection: $amountMode) {
                        ForEach(RecurringAmountMode.allCases) { mode in
                            Text(mode.title(language: store.appLanguage))
                                .tag(mode)
                        }
                    }
                    .pocketWiseInputField(semanticColor: .obligations)

                    if amountMode != .fixedAmount {
                        TextField(store.appLanguage == .arabicEgyptian ? "مبلغ شهري تقديري" : "Estimated monthly amount", text: $estimatedAmountText)
                            .keyboardType(.decimalPad)
                            .pocketWiseInputField(semanticColor: .obligations)

                        Text(store.appLanguage == .arabicEgyptian ? "المبلغ التقديري يظهر في التخطيط والقادم فقط. الرصيد لا يتغير إلا عند التسجيل كمدفوع." : "The estimate appears in planning and Upcoming only. Balance changes only when marked paid.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if amountMode == .variableEachMonth {
                    RecurringMonthlyAmountsSection(
                        startDate: dueDate,
                        monthAmountTexts: $monthAmountTexts
                    )
                }

                Section(isAr ? "تاريخ الاستحقاق" : "Due Date") {
                    DatePicker(
                        isAr ? "أول تاريخ استحقاق" : "First Due Date",
                        selection: $dueDate,
                        displayedComponents: .date
                    )
                    .pocketWiseInputField(semanticColor: .obligations)
                }

                Section(isAr ? "التكرار" : "Repeat") {
                    Picker(isAr ? "التكرار" : "Repeat", selection: $repeatRule) {
                        Text(AppText.repeatRuleLabel(.monthly, language: store.appLanguage)).tag(RepeatRule.monthly)
                        Text(AppText.repeatRuleLabel(.quarterly, language: store.appLanguage)).tag(RepeatRule.quarterly)
                        Text(AppText.repeatRuleLabel(.yearly, language: store.appLanguage)).tag(RepeatRule.yearly)
                    }
                    .pocketWiseInputField(semanticColor: .obligations)

                    Picker(endLabel, selection: $recurringEndKind) {
                        Text(neverLabel).tag(RecurringEndKind.never)
                        Text(onDateLabel).tag(RecurringEndKind.onDate)
                        Text(afterPaymentsLabel).tag(RecurringEndKind.afterNumberOfPayments)
                    }
                    .pocketWiseInputField(semanticColor: .obligations)

                    if recurringEndKind == .onDate {
                        DatePicker(
                            onDateLabel,
                            selection: $recurringEndDate,
                            displayedComponents: .date
                        )
                        .pocketWiseInputField(semanticColor: .obligations)
                    }

                    if recurringEndKind == .afterNumberOfPayments {
                        TextField(afterPaymentsLabel, text: $recurringEndPaymentCountText)
                            .keyboardType(.numberPad)
                            .pocketWiseInputField(semanticColor: .obligations)
                    }
                }

                Section(isAr ? "الحساب" : "Account") {
                    Button {
                        dismissKeyboard()
                        selectionRoute = .account
                    } label: {
                        selectionRow(
                            title: store.appLanguage == .arabicEgyptian ? "الحساب" : "Account",
                            value: selectedAccountName
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section(isAr ? "التصنيف" : "Category") {
                    CategorySubcategoryPickerView(
                        categoryName: $selectedCategoryName,
                        subCategoryName: $selectedSubCategoryName
                    )
                }

                Section(isAr ? "ملاحظة" : "Note") {
                    TextField(isAr ? "ملاحظة اختيارية" : "Optional note", text: $note)
                        .pocketWiseInputField(semanticColor: .neutral)
                }

                Section {
                    Text(isAr ? "استخدمه فقط للدفعات المتكررة المستمرة. الأقساط المحدودة زي Valu 12 شهر لها شاشة تقسيط منفصلة." : "Use this only for ongoing repeated payments. Finite installments like Valu 12 months will have a separate installment screen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        saveRecurringPayment()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isAr ? "حفظ الدفعة المتكررة" : "Save Recurring Payment")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(isAr ? "دفعة متكررة جديدة" : "Recurring Payment")
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
                    accounts: store.activeAccounts.filter { $0.isActive },
                    categories: store.activeCategories.filter { $0.isActive }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
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
        !selectedCategoryName.isEmpty &&
        !selectedSubCategoryName.isEmpty &&
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

    private var recurringEndPaymentCount: Int? {
        Int(recurringEndPaymentCountText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var recurringEndIsValid: Bool {
        switch recurringEndKind {
        case .never:
            return true
        case .onDate:
            return recurringEndDate >= dueDate
        case .afterNumberOfPayments:
            return (recurringEndPaymentCount ?? 0) > 0
        }
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
        if selectedAccountName.isEmpty {
            selectedAccountName = store.activeAccounts.first { $0.isActive }?.name ?? ""
        }

        if selectedCategoryName.isEmpty {
            selectedCategoryName =
            store.activeCategories.first { $0.name == "Fixed Obligations" && $0.isActive }?.name ??
            store.activeCategories.first { $0.isActive }?.name ??
            ""
        }

        if selectedSubCategoryName.isEmpty {
            selectedSubCategoryName =
            availableSubcategories.first ?? ""
        }

        if estimatedAmountText.isEmpty {
            estimatedAmountText = amountText
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

    private func saveRecurringPayment() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseAmount = recurringBaseAmount
        let monthlyOverrides = inlineMonthlyOverrides

        let event = FinancialEvent(
            type: .obligation,
            status: .unpaid,
            title: cleanTitle,
            amount: baseAmount,
            date: dueDate,
            accountName: selectedAccountName,
            walletEventName: nil,
            categoryName: selectedCategoryName,
            subCategoryName: selectedSubCategoryName,
            repeatRule: repeatRule,
            recurringEndKind: recurringEndKind == .never ? nil : recurringEndKind,
            recurringEndDate: recurringEndKind == .onDate ? recurringEndDate : nil,
            recurringEndPaymentCount: recurringEndKind == .afterNumberOfPayments ? recurringEndPaymentCount : nil,
            recurringScheduleOverrides: monthlyOverrides.isEmpty ? nil : monthlyOverrides,
            recurringAmountMode: amountMode == .fixedAmount ? nil : amountMode,
            recurringEstimatedAmount: amountMode == .estimatedUntilConfirmed && estimatedAmount > 0 ? estimatedAmount : nil,
            confidence: .high,
            note: note.isEmpty ? nil : note,
            createdAt: Date()
        )

        store.addFinancialEvent(event)
        dismiss()
    }

    private var inlineMonthlyOverrides: [RecurringScheduleOverride] {
        RecurringMonthlyAmountsSection.visibleMonthKeys(startDate: dueDate).compactMap { key in
            let amount = RecurringMonthlyAmountsSection.parseAmountText(monthAmountTexts[key.id] ?? "")
            guard amount > 0 else {
                return nil
            }

            return RecurringScheduleOverride(
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

        return 0
    }

    private func dismissKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
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
}

enum AddRecurringSelectionRoute: String, Identifiable {
    case account
    case category
    case subcategory

    var id: String { rawValue }
}

struct AddRecurringCategorySelectionSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let route: AddRecurringSelectionRoute
    let accounts: [Account]
    let categories: [Category]
    let subcategories: [String]
    let selectedAccountName: String
    let selectedCategoryName: String
    let selectedSubCategoryName: String
    let onSelectAccount: (String) -> Void
    let onSelectCategory: (String) -> Void
    let onSelectSubcategory: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                switch route {
                case .account:
                    ForEach(accounts) { account in
                        Button {
                            onSelectAccount(account.name)
                        } label: {
                            HStack {
                                AccountIdentityLabel(account: account, markSize: 24)

                                Spacer()

                                if account.name == selectedAccountName {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                case .category:
                    ForEach(categories) { category in
                        selectionButton(
                            title: category.name,
                            isSelected: category.name == selectedCategoryName
                        ) {
                            onSelectCategory(category.name)
                        }
                    }
                case .subcategory:
                    ForEach(subcategories, id: \.self) { subcategory in
                        selectionButton(
                            title: subcategory,
                            isSelected: subcategory == selectedSubCategoryName
                        ) {
                            onSelectSubcategory(subcategory)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.appLanguage == .arabicEgyptian ? "تم" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var title: String {
        switch route {
        case .account:
            return store.appLanguage == .arabicEgyptian ? "اختر الحساب" : "Choose Account"
        case .category:
            return store.appLanguage == .arabicEgyptian ? "اختر التصنيف" : "Choose Category"
        case .subcategory:
            return store.appLanguage == .arabicEgyptian ? "اختر التصنيف الفرعي" : "Choose Subcategory"
        }
    }

    private func selectionButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

struct AddRecurringPaymentView_Previews: PreviewProvider {
    static var previews: some View {
        AddRecurringPaymentView()
            .environmentObject(WalletStore())
    }
}
