import SwiftUI

struct InstallmentPlanEditorView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let plan: InstallmentPlan

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
    @State private var showDeleteConfirmation = false

    private var language: AppLanguage { store.appLanguage }
    private var isArabic: Bool { language == .arabicEgyptian }

    var body: some View {
        NavigationStack {
            Form {
                Section(isArabic ? "الشراء" : "Purchase") {
                    TextField(isArabic ? "اسم الشراء" : "Purchase name", text: $purchaseName)

                    TextField(isArabic ? "إجمالي المبلغ" : "Total amount", text: $totalAmountText)
                        .keyboardType(.decimalPad)

                    Stepper(
                        "\(isArabic ? "الأقساط" : "Installments"): \(installmentCount)",
                        value: $installmentCount,
                        in: 1...60
                    )
                }

                Section(isArabic ? "الدفع" : "Payment") {
                    Picker(isArabic ? "جهة التمويل" : "Financing Provider", selection: $selectedProviderOption) {
                        ForEach(InstallmentProviderOption.allCases) { option in
                            Text(option.title(language))
                                .tag(option)
                        }
                    }

                    if selectedProviderOption == .other {
                        TextField(isArabic ? "اسم المزود" : "Provider name", text: $customPaymentMethodName)
                    }

                    if selectedProviderOption == .creditCard {
                        Picker(isArabic ? "الكارت المرتبط" : "Linked Card", selection: $selectedLinkedCreditCardID) {
                            Text(isArabic ? "كارت ائتمان (غير مرتبط)" : "Credit Card (unlinked)")
                                .tag(UUID?.none)

                            ForEach(creditCardsForLinking) { card in
                                Text(card.name)
                                    .tag(Optional(card.id))
                            }
                        }
                        .disabled(creditCardsForLinking.isEmpty)

                        if creditCardsForLinking.isEmpty {
                            Text(isArabic ? "أضف كارت ائتمان الأول عشان تربط الخطة بكارت." : "Add a credit card first to link this plan to a card.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if selectedLinkedCreditCardID == nil {
                            Text(isArabic ? "اختار كارت قبل الحفظ لو القسط ده متمول بكارت ائتمان." : "Select a card before saving if this installment is financed by a credit card.")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }

                        Text(isArabic ? "ده بيربط القسط بالكارت للمتابعة فقط. مش بيضيفه لكشف الكارت دلوقتي." : "This only links the installment to a card for tracking. It does not add it to the card statement yet.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    DatePicker(
                        isArabic ? "أول تاريخ استحقاق" : "First Due Date",
                        selection: $firstDueDate,
                        displayedComponents: .date
                    )
                }

                Section(isArabic ? "الحساب" : "Account") {
                    AccountMenuPickerField(
                        title: isArabic ? "الحساب" : "Account",
                        selection: $selectedAccountName,
                        accounts: store.activeAccounts.filter { $0.isActive }
                    )
                }

                Section(isArabic ? "التصنيف" : "Category") {
                    CategorySubcategoryPickerView(
                        categoryName: $selectedCategoryName,
                        subCategoryName: $selectedSubCategoryName,
                        includesInactiveSelection: true
                    )
                }

                Section(isArabic ? "المبلغ الشهري" : "Monthly Amount") {
                    HStack {
                        Text(isArabic ? "لكل قسط" : "Per installment")
                        Spacer()
                        Text(formatCurrency(monthlyAmount))
                            .fontWeight(.semibold)
                    }

                    Text(isArabic ? "حفظ التعديلات هيعيد إنشاء الأقساط غير المدفوعة فقط. الأقساط المدفوعة هتفضل في النشاط الأخير." : "Saving changes regenerates only unpaid generated installments. Paid installments remain in Recent Activity.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(isArabic ? "ملاحظات" : "Note") {
                    TextField(isArabic ? "ملاحظة اختيارية" : "Optional note", text: $note)
                }

                Section {
                    Button {
                        saveChanges()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isArabic ? "حفظ التعديلات" : "Save Changes")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }

                Section(isArabic ? "منطقة خطرة" : "Danger Zone") {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text(isArabic ? "حذف خطة الأقساط" : "Delete Installment Plan")
                    }
                }
            }
            .navigationTitle(isArabic ? "تعديل القسط" : "Edit Installment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isArabic ? "إلغاء" : "Cancel") {
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
            .confirmationDialog(
                isArabic ? "تحذف خطة الأقساط دي؟" : "Delete this installment plan?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(isArabic ? "حذف خطة الأقساط" : "Delete Installment Plan", role: .destructive) {
                    store.deleteInstallmentPlanAndFutureEvents(plan)
                    dismiss()
                }

                Button(isArabic ? "إلغاء" : "Cancel", role: .cancel) { }
            } message: {
                Text(isArabic ? "الأقساط غير المدفوعة اللي اتولدت فقط هي اللي هتتشال. الأقساط المدفوعة هتفضل في السجل." : "Only unpaid generated installments will be removed. Paid installments stay in history.")
            }
        }
    }

    private var totalAmount: Double {
        Double(totalAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0
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
        store.subcategoriesForEditing(
            categoryName: selectedCategoryName,
            selectedSubcategoryName: selectedSubCategoryName
        )
    }

    private var categoriesForEditing: [Category] {
        var categories = store.activeCategories.filter { $0.isActive }

        if let inactiveCategory = store.categories.first(where: { $0.name == selectedCategoryName && !$0.isActive }),
           !categories.contains(where: { $0.id == inactiveCategory.id }) {
            categories.append(inactiveCategory)
        }

        return categories.sorted { $0.name < $1.name }
    }

    private var creditCardsForLinking: [CreditCard] {
        var cards = store.activeCreditCards

        if let selectedLinkedCreditCardID,
           let linkedCard = store.creditCards.first(where: { $0.id == selectedLinkedCreditCardID }),
           !cards.contains(where: { $0.id == linkedCard.id }) {
            cards.append(linkedCard)
        }

        return cards.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
        creditCardsForLinking.isEmpty ||
        selectedLinkedCreditCardID != nil
    }

    private func setupInitialValues() {
        purchaseName = plan.purchaseName
        totalAmountText = cleanNumberText(plan.totalAmount)
        installmentCount = max(plan.installmentCount, 1)
        firstDueDate = plan.firstDueDate
        selectedAccountName = plan.accountName ?? store.activeAccounts.first { $0.isActive }?.name ?? ""
        selectedCategoryName = plan.categoryName
        selectedSubCategoryName = plan.subCategoryName
        selectedProviderOption = InstallmentProviderOption.option(matching: plan.paymentMethodName)
        customPaymentMethodName = selectedProviderOption == .other ? plan.paymentMethodName : ""
        selectedLinkedCreditCardID = selectedProviderOption == .creditCard ? plan.linkedCreditCardID : nil
        note = plan.note ?? ""

        if selectedCategoryName.isEmpty {
            selectedCategoryName = store.activeCategories.first { $0.isActive }?.name ?? ""
        }

        if selectedSubCategoryName.isEmpty {
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
        let updatedPlan = InstallmentPlan(
            id: plan.id,
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

        store.updateInstallmentPlanAndRegenerateFutureEvents(updatedPlan)
        dismiss()
    }

    private func cleanNumberText(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return "\(amount)"
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let number = NSNumber(value: amount)
        let formatted = formatter.string(from: number) ?? "\(Int(amount))"

        return "\(formatted) EGP"
    }
}

// MARK: - Preview

struct InstallmentPlanEditorView_Previews: PreviewProvider {
    static var previews: some View {
        InstallmentPlanEditorView(plan: SampleWalletData.installmentPlans[0])
            .environmentObject(WalletStore())
    }
}
