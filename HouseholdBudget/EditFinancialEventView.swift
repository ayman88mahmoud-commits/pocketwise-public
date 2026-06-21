import SwiftUI

struct EditFinancialEventView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let event: FinancialEvent

    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var date: Date = Date()
    @State private var selectedAccountName: String = ""
    @State private var selectedDestinationAccountName: String = ""
    @State private var paymentMethodName: String = ""
    @State private var selectedCategoryName: String = ""
    @State private var selectedSubCategoryName: String = ""
    @State private var incomeType: IncomeType = .unknown
    @State private var reimbursementCategoryName: String = ""
    @State private var repeatRule: RepeatRule = .none
    @State private var confidence: ConfidenceLevel = .medium
    @State private var note: String = ""

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(isArabic ? "ثابت" : "Locked") {
                    detailRow(isArabic ? "النوع" : "Type", AppText.eventTypeLabel(event.type, language: store.appLanguage))
                    detailRow(isArabic ? "الحالة" : "Status", AppText.statusLabel(event.status, language: store.appLanguage))
                }

                Section(isArabic ? "التفاصيل" : "Details") {
                    TextField(isArabic ? "العنوان" : "Title", text: $title)

                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        validationMessage(isArabic ? "دخل عنوان أو وصف." : "Enter a title or description.")
                    }

                    TextField(isArabic ? "المبلغ" : "Amount", text: $amountText)
                        .keyboardType(.decimalPad)

                    if amount <= 0 {
                        validationMessage(isArabic ? "دخل مبلغ أكبر من صفر." : "Enter an amount greater than zero.")
                    }

                    DatePicker(
                        isArabic ? "التاريخ والوقت" : "Date & Time",
                        selection: $date,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section(isArabic ? "الدفع" : "Payment") {
                    AccountMenuPickerField(
                        title: isTransfer ? (isArabic ? "من حساب" : "From Account") : (isArabic ? "الحساب" : "Account"),
                        selection: $selectedAccountName,
                        accounts: accountsForEditing,
                        placeholder: isTransfer ? (isArabic ? "اختار حساب" : "Select account") : (isArabic ? "مفيش حساب" : "No account"),
                        emptyTitle: isTransfer ? nil : (isArabic ? "مفيش حساب" : "No account"),
                        inactiveSubtitle: true
                    )

                    if requiresAccount && selectedAccountName.isEmpty {
                        validationMessage(isArabic ? "اختار الحساب اللي هيتخصم منه." : "Select the account to deduct from.")
                    }

                    if isTransfer {
                        AccountMenuPickerField(
                            title: isArabic ? "إلى حساب" : "To Account",
                            selection: $selectedDestinationAccountName,
                            accounts: destinationAccountsForEditing,
                            emptyTitle: isArabic ? "اختار حساب" : "Select account",
                            inactiveSubtitle: true
                        )

                        if selectedDestinationAccountName.isEmpty {
                            validationMessage(isArabic ? "اختار حساب الوجهة." : "Select the destination account.")
                        }

                        if !selectedAccountName.isEmpty &&
                            selectedAccountName == selectedDestinationAccountName {
                            validationMessage(isArabic ? "حساب التحويل منه وإليه ما ينفعش يكونوا نفس الحساب." : "From and To accounts cannot be the same.")
                        }
                    }

                    if isInstaPay && !selectedAccountName.isEmpty && !isSelectedAccountBank {
                        validationMessage(isArabic ? "إنستاباي لازم يكون مرتبط بحساب بنكي." : "InstaPay must be linked to a bank account.")
                    }

                    if !isTransfer {
                        TextField(isArabic ? "طريقة الدفع" : "Payment method", text: $paymentMethodName)
                    }
                }

                if usesCategory {
                    Section(isArabic ? "التصنيف" : "Category") {
                        CategorySubcategoryPickerView(
                            categoryName: $selectedCategoryName,
                            subCategoryName: $selectedSubCategoryName,
                            showsValidation: true,
                            includesInactiveSelection: true,
                            suggestion: categorySuggestion
                        )
                    }
                }

                if event.type == .income {
                    Section(isArabic ? "نوع الدخل" : "Income Type") {
                        Picker(isArabic ? "نوع الدخل" : "Income Type", selection: $incomeType) {
                            ForEach(IncomeType.allCases) { type in
                                Text(type.title(language: store.appLanguage))
                                    .tag(type)
                            }
                        }

                        if incomeType == .transfer {
                            Text(store.appLanguage == .arabicEgyptian ? "التحويل بين حساباتك يفضل يتسجل كتحويل وليس دخل حقيقي." : "Transfers between your own accounts should normally be added as Transfer, not income.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if incomeType == .reimbursement {
                        Section(store.appLanguage == .arabicEgyptian ? "استرداد عن تصنيف" : "Reimbursement for Category") {
                            Picker(store.appLanguage == .arabicEgyptian ? "التصنيف" : "Category", selection: $reimbursementCategoryName) {
                                Text(store.appLanguage == .arabicEgyptian ? "اختر تصنيف" : "Select category")
                                    .tag("")

                                ForEach(reimbursementCategoriesForEditing) { category in
                                    Text(category.isActive ? AppText.categoryDisplayName(category.name, language: store.appLanguage) : "\(AppText.categoryDisplayName(category.name, language: store.appLanguage)) (\(isArabic ? "غير نشط" : "inactive"))")
                                        .tag(category.name)
                                }
                            }

                            if reimbursementCategoryName.isEmpty {
                                validationMessage(store.appLanguage == .arabicEgyptian ? "اختار التصنيف الأصلي للمصروف." : "Select the original expense category.")
                            }
                        }
                    }
                }

                if !isTransfer {
                    Section(isArabic ? "التخطيط" : "Planning") {
                        if !isGeneratedOccurrence {
                            Picker(isArabic ? "التكرار" : "Repeat", selection: $repeatRule) {
                                ForEach(RepeatRule.allCases) { rule in
                                    Text(AppText.repeatRuleLabel(rule, language: store.appLanguage))
                                        .tag(rule)
                                }
                            }
                        }

                        Picker(isArabic ? "الثقة" : "Confidence", selection: $confidence) {
                            Text(isArabic ? "غير محدد" : "Not set")
                                .tag(ConfidenceLevel.medium)

                            ForEach(ConfidenceLevel.allCases) { level in
                                Text(AppText.confidenceLevelLabel(level, language: store.appLanguage))
                                    .tag(level)
                            }
                        }
                    }
                }

                Section(isArabic ? "ملاحظات" : "Note") {
                    TextField(isArabic ? "ملاحظة اختيارية" : "Optional note", text: $note)
                }

                Section {
                    if !validationMessages.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(validationMessages, id: \.self) { message in
                                validationMessage(message)
                            }
                        }
                    }

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
            }
            .navigationTitle(isArabic ? "تعديل الحركة" : "Edit Transaction")
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
            .onChange(of: incomeType) { _, _ in
                updateReimbursementCategory()
            }
        }
    }

    private var amount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var usesCategory: Bool {
        switch event.type {
        case .expense, .obligation, .expectedExpense, .installment:
            return true
        case .income, .transfer:
            return false
        }
    }

    private var requiresAccount: Bool {
        event.status == .paid
    }

    private var isTransfer: Bool {
        event.type == .transfer
    }

    private var isGeneratedOccurrence: Bool {
        event.sourceRecurringEventID != nil || event.sourceInstallmentPlanID != nil
    }

    private var isInstaPay: Bool {
        paymentMethodName.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("InstaPay") == .orderedSame
    }

    private var isSelectedAccountBank: Bool {
        store.accounts.first { $0.name == selectedAccountName }?.type == .bank
    }

    private var availableSubcategories: [String] {
        store.subcategoriesForEditing(
            categoryName: selectedCategoryName,
            selectedSubcategoryName: selectedSubCategoryName
        )
    }

    private var accountsForEditing: [Account] {
        var accounts = store.accounts.filter { $0.isActive }

        if let inactiveAccount = store.accounts.first(where: { $0.name == selectedAccountName && !$0.isActive }),
           !accounts.contains(where: { $0.id == inactiveAccount.id }) {
            accounts.append(inactiveAccount)
        }

        return accounts.sorted { $0.name < $1.name }
    }

    private var destinationAccountsForEditing: [Account] {
        var accounts = store.accounts.filter { $0.isActive }

        if let inactiveAccount = store.accounts.first(where: { $0.name == selectedDestinationAccountName && !$0.isActive }),
           !accounts.contains(where: { $0.id == inactiveAccount.id }) {
            accounts.append(inactiveAccount)
        }

        return accounts.sorted { $0.name < $1.name }
    }

    private var categoriesForEditing: [Category] {
        var categories = store.categories.filter { $0.isActive }

        if let inactiveCategory = store.categories.first(where: { $0.name == selectedCategoryName && !$0.isActive }),
           !categories.contains(where: { $0.id == inactiveCategory.id }) {
            categories.append(inactiveCategory)
        }

        return categories.sorted { $0.name < $1.name }
    }

    private var reimbursementCategoriesForEditing: [Category] {
        var categories = store.categories.filter { $0.isActive }

        if let inactiveCategory = store.categories.first(where: { $0.name == reimbursementCategoryName && !$0.isActive }),
           !categories.contains(where: { $0.id == inactiveCategory.id }) {
            categories.append(inactiveCategory)
        }

        return categories.sorted { $0.name < $1.name }
    }

    private var validationMessages: [String] {
        var messages: [String] = []

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Enter a title or description.")
        }

        if amount <= 0 {
            messages.append("Enter an amount greater than zero.")
        }

        if usesCategory && selectedCategoryName.isEmpty {
            messages.append("Select a category.")
        }

        if usesCategory && selectedSubCategoryName.isEmpty {
            messages.append("Select a subcategory.")
        }

        if requiresAccount && selectedAccountName.isEmpty {
            messages.append("Select the account to deduct from.")
        }

        if event.type == .income &&
            incomeType == .reimbursement &&
            reimbursementCategoryName.isEmpty {
            messages.append("Select the original expense category for this reimbursement.")
        }

        if isTransfer && selectedDestinationAccountName.isEmpty {
            messages.append("Select the destination account.")
        }

        if isTransfer &&
            !selectedAccountName.isEmpty &&
            selectedAccountName == selectedDestinationAccountName {
            messages.append("From and To accounts cannot be the same.")
        }

        if isInstaPay && !selectedAccountName.isEmpty && !isSelectedAccountBank {
            messages.append("InstaPay must be linked to a bank account.")
        }

        return messages
    }

    private var canSave: Bool {
        validationMessages.isEmpty
    }

    private var categorySuggestion: CategorySubcategorySuggestion? {
        guard usesCategory,
              (event.categoryName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                (event.subCategoryName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return store.suggestedCategorySubcategory(
            for: CategorySuggestionRequest(
                title: title,
                note: note,
                accountName: selectedAccountName,
                paymentMethodName: paymentMethodName,
                allowedEventTypes: [event.type],
                includeCreditCardPurchases: event.type == .expense,
                excludingFinancialEventID: event.id
            )
        )
    }

    private func setupInitialValues() {
        title = event.title
        amountText = cleanNumberText(event.amount)
        date = event.date
        selectedAccountName = event.accountName ?? ""
        selectedDestinationAccountName = event.destinationAccountName ?? ""
        paymentMethodName = event.paymentMethodName ?? ""
        selectedCategoryName = event.categoryName ?? store.categories.first { $0.isActive }?.name ?? ""
        selectedSubCategoryName = event.subCategoryName ?? ""
        incomeType = event.incomeType ?? .unknown
        reimbursementCategoryName = event.reimbursementCategoryName ?? store.categories.first { $0.isActive }?.name ?? ""
        repeatRule = event.repeatRule
        confidence = event.confidence ?? .medium
        note = event.note ?? ""

        if usesCategory && selectedSubCategoryName.isEmpty {
            selectedSubCategoryName = availableSubcategories.first ?? ""
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

    private func updateReimbursementCategory() {
        guard incomeType == .reimbursement else {
            return
        }

        if reimbursementCategoryName.isEmpty ||
            !store.categories.contains(where: { $0.name == reimbursementCategoryName }) {
            reimbursementCategoryName = store.categories.first { $0.isActive }?.name ?? ""
        }
    }

    private func saveChanges() {
        var updatedEvent = event
        updatedEvent.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedEvent.amount = amount
        updatedEvent.date = date
        updatedEvent.accountName = selectedAccountName.isEmpty ? nil : selectedAccountName
        updatedEvent.destinationAccountName = isTransfer ? selectedDestinationAccountName : nil
        updatedEvent.paymentMethodName = paymentMethodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : paymentMethodName.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedEvent.categoryName = usesCategory ? selectedCategoryName : nil
        updatedEvent.subCategoryName = usesCategory ? selectedSubCategoryName : nil
        updatedEvent.incomeType = event.type == .income ? incomeType : nil
        updatedEvent.reimbursementCategoryName = event.type == .income && incomeType == .reimbursement ? reimbursementCategoryName : nil
        updatedEvent.repeatRule = repeatRule
        updatedEvent.confidence = confidence
        updatedEvent.note = note.isEmpty ? nil : note

        store.updateFinancialEvent(originalEvent: event, updatedEvent: updatedEvent)
        dismiss()
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
    }

    private func cleanNumberText(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return "\(amount)"
    }
}

struct EditFinancialEventView_Previews: PreviewProvider {
    static var previews: some View {
        EditFinancialEventView(event: SampleWalletData.financialEvents[0])
            .environmentObject(WalletStore())
    }
}
