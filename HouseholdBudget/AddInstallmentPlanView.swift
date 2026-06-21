import SwiftUI

enum InstallmentProviderOption: String, CaseIterable, Identifiable {
    case valu
    case souhoola
    case sympl
    case contact
    case creditCard
    case bankCashWallet
    case other

    var id: String { rawValue }

    var savedName: String {
        switch self {
        case .valu:
            return "Valu"
        case .souhoola:
            return "Souhoola"
        case .sympl:
            return "Sympl"
        case .contact:
            return "Contact"
        case .creditCard:
            return "Credit Card"
        case .bankCashWallet:
            return "Bank / Cash / Wallet"
        case .other:
            return "Other"
        }
    }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .valu:
            return "Valu"
        case .souhoola:
            return "Souhoola"
        case .sympl:
            return "Sympl"
        case .contact:
            return "Contact"
        case .creditCard:
            return language == .arabicEgyptian ? "كارت ائتمان" : "Credit Card"
        case .bankCashWallet:
            return language == .arabicEgyptian ? "بنك / كاش / محفظة" : "Bank / Cash / Wallet"
        case .other:
            return language == .arabicEgyptian ? "أخرى" : "Other"
        }
    }

    static func option(matching value: String) -> InstallmentProviderOption {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return allCases.first { option in
            option != .other &&
            option.savedName.caseInsensitiveCompare(trimmedValue) == .orderedSame
        } ?? .other
    }
}

struct AddInstallmentPlanView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var purchaseName: String = ""
    @State private var totalAmountText: String = ""
    @State private var installmentCount: Int = 12
    @State private var firstDueDate: Date = Date()
    @State private var selectedAccountName: String = ""
    @State private var selectedCategoryName: String = ""
    @State private var selectedSubCategoryName: String = ""
    @State private var selectedProviderOption: InstallmentProviderOption = .valu
    @State private var customPaymentMethodName: String = ""
    @State private var selectedLinkedCreditCardID: UUID?
    @State private var note: String = ""

    private var language: AppLanguage { store.appLanguage }
    private var shouldShowValidationMessages: Bool { !canSave }

    var body: some View {
        NavigationStack {
            Form {
                Section(language == .arabicEgyptian ? "تفاصيل الشراء" : "Purchase Details") {
                    TextField(language == .arabicEgyptian ? "اسم الشيء" : "Item Name", text: $purchaseName)
                        .pocketWiseInputField(semanticColor: .neutral)

                    if shouldShowValidationMessages && purchaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        validationMessage(language == .arabicEgyptian ? "أدخل اسم الشيء" : "Enter item name")
                    }

                    TextField(language == .arabicEgyptian ? "إجمالي المبلغ" : "Total Amount", text: $totalAmountText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .obligations, isProminent: true)

                    if shouldShowValidationMessages && totalAmount <= 0 {
                        validationMessage(language == .arabicEgyptian ? "أدخل مبلغ صحيح" : "Enter a valid amount")
                    }

                    Stepper(
                        language == .arabicEgyptian
                            ? "عدد الأقساط: \(installmentCount)"
                            : "Number of Installments: \(installmentCount)",
                        value: $installmentCount,
                        in: 1...60
                    )
                }

                Section(language == .arabicEgyptian ? "تفاصيل الدفع" : "Payment Details") {
                    Picker(language == .arabicEgyptian ? "جهة التمويل" : "Financing Provider", selection: $selectedProviderOption) {
                        ForEach(InstallmentProviderOption.allCases) { option in
                            Text(option.title(language))
                                .tag(option)
                        }
                    }
                    .pocketWiseInputField(semanticColor: .obligations)

                    if selectedProviderOption == .other {
                        TextField(language == .arabicEgyptian ? "اسم المزود" : "Provider name", text: $customPaymentMethodName)
                            .pocketWiseInputField(semanticColor: .obligations)

                        if shouldShowValidationMessages && resolvedPaymentMethodName.isEmpty {
                            validationMessage(language == .arabicEgyptian ? "أدخل اسم المزود" : "Enter provider name")
                        }
                    }

                    if selectedProviderOption == .creditCard {
                        Picker(language == .arabicEgyptian ? "الكارت المرتبط" : "Linked Card", selection: $selectedLinkedCreditCardID) {
                            Text(language == .arabicEgyptian ? "اختار كارت" : "Select a card")
                                .tag(UUID?.none)

                            ForEach(store.activeCreditCards) { card in
                                Text(card.name)
                                    .tag(Optional(card.id))
                            }
                        }
                        .disabled(store.activeCreditCards.isEmpty)
                        .pocketWiseInputField(semanticColor: .creditCards)

                        if store.activeCreditCards.isEmpty {
                            Text(language == .arabicEgyptian ? "أضف كارت ائتمان الأول عشان تربط الخطة بكارت." : "Add a credit card first to link this plan to a card.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if shouldShowValidationMessages && selectedLinkedCreditCardID == nil {
                            validationMessage(language == .arabicEgyptian ? "اختار الكارت المرتبط" : "Select the linked card")
                        }

                        Text(language == .arabicEgyptian
                             ? "الربط ده للتتبع بس. مش هيضيف القسط لكشف الكارت دلوقتي."
                             : "This only links the installment to a card for tracking. It does not add it to the card statement yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    DatePicker(
                        language == .arabicEgyptian ? "تاريخ أول قسط" : "First Payment Date",
                        selection: $firstDueDate,
                        displayedComponents: .date
                    )
                    .pocketWiseInputField(semanticColor: .obligations)
                }

                Section(language == .arabicEgyptian ? "الحساب" : "Account") {
                    AccountMenuPickerField(
                        title: language == .arabicEgyptian ? "الحساب" : "Account",
                        selection: $selectedAccountName,
                        accounts: store.accounts.filter { $0.isActive }
                    )
                    .pocketWiseInputField(semanticColor: .accounts)
                }

                Section(language == .arabicEgyptian ? "التصنيف" : "Category") {
                    CategorySubcategoryPickerView(
                        categoryName: $selectedCategoryName,
                        subCategoryName: $selectedSubCategoryName,
                        title: language == .arabicEgyptian ? "التصنيف" : "Category",
                        showsValidation: shouldShowValidationMessages,
                        categoryValidationMessage: language == .arabicEgyptian ? "اختر التصنيف" : "Select a category",
                        subcategoryValidationMessage: language == .arabicEgyptian ? "اختر التصنيف الفرعي" : "Select a subcategory"
                    )
                }

                Section(language == .arabicEgyptian ? "حساب القسط" : "Installment Calculation") {
                    HStack {
                        Text(language == .arabicEgyptian ? "قيمة القسط الشهري" : "Monthly Amount")
                        Spacer()
                        Text(store.displayCurrency(monthlyAmount, maximumFractionDigits: 0))
                            .fontWeight(.semibold)
                    }

                    Text(language == .arabicEgyptian
                        ? "التطبيق هيعمل \(installmentCount) قسط غير مدفوع. مش هيتكرر للأبد."
                        : "The app will create exactly \(installmentCount) unpaid installment payments. They will not repeat forever.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(language == .arabicEgyptian ? "ملاحظة" : "Note") {
                    TextField(language == .arabicEgyptian ? "ملاحظة اختيارية" : "Optional note", text: $note)
                        .pocketWiseInputField(semanticColor: .neutral)
                }

                Section {
                    Button {
                        saveInstallmentPlan()
                    } label: {
                        HStack {
                            Spacer()
                            Text(language == .arabicEgyptian ? "حفظ خطة التقسيط" : "Save Installment Plan")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(language == .arabicEgyptian ? "إضافة خطة تقسيط" : "Add Installment Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(language == .arabicEgyptian ? "إلغاء" : "Cancel") {
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
            .onChange(of: selectedProviderOption) { _, newValue in
                if newValue != .creditCard {
                    selectedLinkedCreditCardID = nil
                }
            }
        }
    }

    private var totalAmount: Double {
        RecurringMonthlyAmountsSection.parseAmountText(totalAmountText)
    }

    private var monthlyAmount: Double {
        guard installmentCount > 0 else { return 0 }
        return totalAmount / Double(installmentCount)
    }

    private var canSave: Bool {
        !purchaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        totalAmount > 0 &&
        installmentCount > 0 &&
        !selectedAccountName.isEmpty &&
        !selectedCategoryName.isEmpty &&
        !selectedSubCategoryName.isEmpty &&
        !resolvedPaymentMethodName.isEmpty &&
        canSaveLinkedCreditCard
    }

    private var availableSubcategories: [String] {
        store.activeSubcategories(for: selectedCategoryName)
    }

    private var resolvedPaymentMethodName: String {
        if selectedProviderOption == .other {
            return customPaymentMethodName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return selectedProviderOption.savedName
    }

    private var resolvedLinkedCreditCardID: UUID? {
        selectedProviderOption == .creditCard ? selectedLinkedCreditCardID : nil
    }

    private var canSaveLinkedCreditCard: Bool {
        selectedProviderOption != .creditCard ||
        store.activeCreditCards.isEmpty ||
        selectedLinkedCreditCardID != nil
    }

    private func setupInitialValues() {
        if selectedAccountName.isEmpty {
            selectedAccountName = store.accounts.first { $0.isActive }?.name ?? ""
        }

        if selectedCategoryName.isEmpty {
            selectedCategoryName =
            store.categories.first { $0.name == "Fixed Obligations" && $0.isActive }?.name ??
            store.categories.first { $0.isActive }?.name ??
            ""
        }

        if selectedSubCategoryName.isEmpty {
            selectedSubCategoryName =
            availableSubcategories.first { $0 == "Valu" } ??
            availableSubcategories.first ?? ""
        }
    }

    private func updateSubcategoryForCategory(_ categoryName: String) {
        let subcategories = store.activeSubcategories(for: categoryName)

        selectedSubCategoryName = subcategories.first ?? ""
    }

    private func saveInstallmentPlan() {
        let plan = InstallmentPlan(
            purchaseName: purchaseName.trimmingCharacters(in: .whitespacesAndNewlines),
            totalAmount: totalAmount,
            installmentCount: installmentCount,
            firstDueDate: firstDueDate,
            accountName: selectedAccountName,
            categoryName: selectedCategoryName,
            subCategoryName: selectedSubCategoryName,
            paymentMethodName: resolvedPaymentMethodName,
            linkedCreditCardID: resolvedLinkedCreditCardID,
            note: note.isEmpty ? nil : note
        )

        store.addInstallmentPlanAndGenerateEvents(plan)
        dismiss()
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
    }
}

// MARK: - Preview

struct AddInstallmentPlanView_Previews: PreviewProvider {
    static var previews: some View {
        AddInstallmentPlanView()
            .environmentObject(WalletStore())
    }
}
