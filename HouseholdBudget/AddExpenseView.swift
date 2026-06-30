import SwiftUI

struct AddExpenseView: View {

    private enum PaymentMethod: String, CaseIterable, Identifiable {
        case direct = "Direct Payment"
        case instaPay = "InstaPay"
        case creditCard = "Credit Card"
        case installment = "Valu / Installment"

        var id: String { rawValue }

        var eventValue: String {
            switch self {
            case .direct:
                return "Direct"
            case .instaPay:
                return "InstaPay"
            case .creditCard:
                return "Credit Card"
            case .installment:
                return "Installment"
            }
        }

        func title(language: AppLanguage) -> String {
            switch self {
            case .direct:
                return language == .arabicEgyptian ? "دفع مباشر" : rawValue
            case .instaPay:
                return rawValue
            case .creditCard:
                return language == .arabicEgyptian ? "كارت ائتمان" : rawValue
            case .installment:
                return language == .arabicEgyptian ? "فالو / تقسيط" : rawValue
            }
        }
    }

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNewSubcategoryFocused: Bool
    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    let prefilledEvent: WalletEvent?
    let bankSMSDraft: BankSMSImportDraft?
    let onBankSMSImportSaved: ((BankSMSImportDraft) -> Void)?
    let onBankSMSImportDiscarded: ((BankSMSImportDraft) -> Void)?

    @State private var amountText: String = ""
    @State private var title: String = ""
    @State private var selectedEvent: WalletEvent?
    @State private var selectedCategoryName: String = ""
    @State private var selectedSubCategoryName: String = ""
    @State private var selectedAccountName: String = ""
    @State private var selectedCreditCardID: UUID?
    @State private var selectedPaymentMethod: PaymentMethod = .direct
    @State private var note: String = ""
    @State private var date: Date = Date()

    @State private var saveAsQuickEvent = false
    @State private var markQuickEventAsFavorite = true
    @State private var newSubcategoryName = ""
    @State private var isShowingInstallmentPlan = false
    @State private var didSetupInitialValues = false
    @State private var isSaving = false
    @State private var hasSaved = false
    @State private var savedImportIdentity: String?
    @State private var isShowingDiscardImportConfirmation = false
    @State private var isShowingMoreDetails = false
    @State private var isShowingDuplicateConfirmation = false
    @State private var duplicateCandidateToConfirm: TransactionDuplicateCandidate?
    @State private var duplicateCandidateToReview: TransactionDuplicateCandidate?
    @State private var shouldBypassDuplicateWarning = false

    init(
        prefilledEvent: WalletEvent? = nil,
        bankSMSDraft: BankSMSImportDraft? = nil,
        onBankSMSImportSaved: ((BankSMSImportDraft) -> Void)? = nil,
        onBankSMSImportDiscarded: ((BankSMSImportDraft) -> Void)? = nil
    ) {
        self.prefilledEvent = prefilledEvent
        self.bankSMSDraft = bankSMSDraft
        self.onBankSMSImportSaved = onBankSMSImportSaved
        self.onBankSMSImportDiscarded = onBankSMSImportDiscarded
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(isAr ? "المبلغ" : "Amount") {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                        .pocketWiseInputField(semanticColor: .spending, isProminent: true)

                    if shouldShowValidationMessages && amount <= 0 {
                        validationMessage(isAr ? "أدخل مبلغ أكبر من صفر." : "Enter an amount greater than zero.")
                    }
                }

                Section(isAr ? "التفاصيل" : "Details") {
                    TextField(isAr ? "عنوان أو وصف" : "Title or description", text: $title)
                        .pocketWiseInputField(semanticColor: .spending)

                    if shouldShowValidationMessages && trimmedTitle.isEmpty {
                        validationMessage(isAr ? "أدخل عنوانًا أو وصفًا." : "Enter a title or description.")
                    }

                    CategorySubcategoryPickerView(
                        categoryName: $selectedCategoryName,
                        subCategoryName: $selectedSubCategoryName,
                        showsValidation: shouldShowValidationMessages,
                        suggestion: categorySuggestion,
                        highlightsSelectedCategory: isNewSubcategoryFocused
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            TextField(isAr ? "تصنيف فرعي جديد" : "New subcategory", text: $newSubcategoryName)
                                .focused($isNewSubcategoryFocused)
                                .pocketWiseInputField(semanticColor: .categories)

                            Button(isAr ? "أضف" : "Add") {
                                addNewSubcategory()
                            }
                            .disabled(!canAddSubcategory)
                            .tint(PocketWiseSemanticColor.categories.tint)
                        }

                        if isNewSubcategoryFocused {
                            Text(newSubcategoryParentHint)
                                .font(.footnote)
                                .foregroundStyle(selectedCategoryName.isEmpty ? PocketWiseSemanticColor.warning.tint : .secondary)
                        }
                    }
                }

                Section(isAr ? "طريقة الدفع" : "Payment Method") {
                    PaymentMethodMenuPickerField(
                        title: isAr ? "طريقة الدفع" : "Payment Method",
                        selection: $selectedPaymentMethod,
                        options: PaymentMethod.allCases,
                        optionTitle: { $0.title(language: store.appLanguage) },
                        identityName: { $0.rawValue }
                    )
                    .pocketWiseInputField(semanticColor: .accounts)

                    if shouldShowValidationMessages && selectedPaymentMethod.eventValue.isEmpty {
                        validationMessage(isAr ? "اختر طريقة الدفع." : "Select a payment method.")
                    }

                    if selectedPaymentMethod == .installment {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(isAr ? "الأقساط تُعالَج كخطط محدودة وليس مصاريف نقدية." : "Installments are handled as finite plans, not paid cash expenses.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button(isAr ? "افتح خطة التقسيط" : "Open Installment Plan") {
                                isShowingInstallmentPlan = true
                            }
                            .tint(PocketWiseSemanticColor.obligations.tint)
                        }
                    }
                }

                if selectedPaymentMethod == .creditCard {
                    Section(isAr ? "كارت الائتمان" : "Credit Card") {
                        if activeCreditCards.isEmpty {
                            Text(isAr ? "أضف كارت ائتمان من الإعدادات أولًا" : "Add a credit card first from Settings.")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        } else {
                            Picker(isAr ? "اختر الكارت" : "Select Credit Card", selection: creditCardSelectionBinding) {
                                Text(isAr ? "اختر الكارت" : "Select Credit Card")
                                    .tag(UUID?.none)

                                ForEach(activeCreditCards) { card in
                                    Text(creditCardPickerTitle(card))
                                        .tag(Optional(card.id))
                                }
                            }
                            .pocketWiseInputField(semanticColor: .creditCards)

                            if shouldShowValidationMessages && selectedCreditCardID == nil {
                                validationMessage(isAr ? "اختر الكارت" : "Select Credit Card.")
                            }

                            Text(isAr ? "الشراء بالكارت لا يخصم من رصيد البنك وقت التسجيل." : "Credit card purchases do not deduct bank cash at purchase time.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if selectedPaymentMethod != .installment {
                    Section(selectedPaymentMethod == .instaPay ? (isAr ? "حساب المصدر" : "Source Account") : (isAr ? "الحساب" : "Account")) {
                        AccountMenuPickerField(
                            title: selectedPaymentMethod == .instaPay ? (isAr ? "حساب البنك" : "Bank Source") : (isAr ? "الحساب" : "Account"),
                            selection: $selectedAccountName,
                            accounts: availableAccounts
                        )
                        .pocketWiseInputField(semanticColor: .accounts)

                        if shouldShowValidationMessages && selectedAccountName.isEmpty {
                            validationMessage(isAr ? "اختر الحساب للخصم منه." : "Select the account to deduct from.")
                        }

                        if shouldShowValidationMessages && selectedPaymentMethod == .instaPay && !isSelectedAccountBank {
                            validationMessage(isAr ? "InstaPay يجب ربطه بحساب بنكي." : "InstaPay must be linked to a bank account.")
                        }

                        if selectedPaymentMethod == .instaPay {
                            HStack {
                                Text(isAr ? "رسوم InstaPay المقدرة" : "Estimated InstaPay fee")
                                Spacer()
                                Text(formatCurrency(instaPayFee))
                                    .fontWeight(.semibold)
                            }

                            Text(isAr
                                 ? "الرسوم بناءً على: \(cleanNumberText(store.instaPayFeePercent))%، أدنى \(formatCurrency(store.instaPayMinimumFee))، أقصى \(formatCurrency(store.instaPayMaximumFee))."
                                 : "Fee uses configurable assumptions: \(cleanNumberText(store.instaPayFeePercent))%, min \(formatCurrency(store.instaPayMinimumFee)), max \(formatCurrency(store.instaPayMaximumFee)).")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button {
                        saveExpense()
                    } label: {
                        HStack {
                            Spacer()

                            if isSaving {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            Text(saveButtonTitle)
                                .fontWeight(.semibold)

                            Spacer()
                        }
                    }
                    .disabled(!canSave || isSaving || hasSaved)
                    .tint(PocketWiseSemanticColor.spending.tint)
                }

                Section {
                    DisclosureGroup(isExpanded: $isShowingMoreDetails) {
                        VStack(alignment: .leading, spacing: 14) {
                            Picker(isAr ? "اختصار" : "Shortcut", selection: $selectedEvent) {
                                Text(isAr ? "إدخال يدوي" : "Manual Entry")
                                    .tag(nil as WalletEvent?)

                                ForEach(store.activeWalletEvents.filter { $0.isActive }) { event in
                                    Text(event.name)
                                        .tag(event as WalletEvent?)
                                }
                            }
                            .pocketWiseInputField(semanticColor: .spending)

                            Text(isAr ? "الاختصارات السريعة مجرد اختصارات. يمكنك إدخال أي مصروف يدويًا." : "Quick events are shortcuts only. You can still enter any expense manually.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Divider()

                            DatePicker(
                                isAr ? "التاريخ والوقت" : "Date & Time",
                                selection: $date,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .pocketWiseInputField(semanticColor: .obligations)

                            Divider()

                            Toggle(isAr ? "احفظ كاختصار سريع" : "Save as Quick Event", isOn: $saveAsQuickEvent)

                            if saveAsQuickEvent {
                                Toggle(isAr ? "اعرض في الإضافة السريعة" : "Show in Quick Add", isOn: $markQuickEventAsFavorite)
                            }

                            Divider()

                            TextField(isAr ? "ملاحظة اختيارية" : "Optional note", text: $note)
                                .pocketWiseInputField(semanticColor: .neutral)
                        }
                        .padding(.top, 8)
                    } label: {
                        Label(isAr ? "تفاصيل أكثر" : "More details", systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.semibold))
                    }
                    .tint(PocketWiseSemanticColor.neutral.tint)
                }
            }
            .navigationTitle(isAr ? "إضافة مصروف" : "Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(bankSMSDraft == nil ? (isAr ? "إلغاء" : "Cancel") : (isAr ? "إغلاق" : "Close")) {
                        dismiss()
                    }
                }

                if bankSMSDraft != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(isAr ? "تجاهل" : "Discard", role: .destructive) {
                            isShowingDiscardImportConfirmation = true
                        }
                        .disabled(isSaving || hasSaved)
                    }
                }
            }
            .confirmationDialog(
                isAr ? "تجاهل مسودة الرسالة البنكية؟" : "Discard this bank message draft?",
                isPresented: $isShowingDiscardImportConfirmation,
                titleVisibility: .visible
            ) {
                Button(isAr ? "تجاهل المسودة" : "Discard Draft", role: .destructive) {
                    discardBankSMSImport()
                }

                Button(isAr ? "احتفظ به لاحقًا" : "Keep for Later", role: .cancel) {}
            } message: {
                Text(isAr ? "سيتم حذف المسودة القادمة من نص الاختصار بدون إنشاء معاملة." : "This removes the draft created from shortcut text without creating a transaction.")
            }
            .confirmationDialog(
                isAr ? "يشبه معاملة موجودة. تحفظ على أي حال؟" : "This looks similar to an existing transaction. Save anyway?",
                isPresented: $isShowingDuplicateConfirmation,
                titleVisibility: .visible
            ) {
                Button(isAr ? "راجع الموجود" : "Review existing") {
                    duplicateCandidateToReview = duplicateCandidateToConfirm
                    duplicateCandidateToConfirm = nil
                }

                Button(isAr ? "احفظ على أي حال" : "Save anyway") {
                    duplicateCandidateToConfirm = nil
                    shouldBypassDuplicateWarning = true
                    saveExpense()
                }

                Button(isAr ? "إلغاء" : "Cancel", role: .cancel) {
                    duplicateCandidateToConfirm = nil
                }
            } message: {
                if let duplicateCandidateToConfirm {
                    Text(duplicateSummaryText(for: duplicateCandidateToConfirm))
                }
            }
            .onAppear {
                setupInitialValues()
            }
            .onChange(of: selectedEvent) { _, newValue in
                applyQuickEvent(newValue)
            }
            .onChange(of: selectedCategoryName) { _, newValue in
                updateSubcategoryForCategory(newValue)
            }
            .onChange(of: selectedPaymentMethod) { _, _ in
                ensureSelectedAccountIsValid()
            }
            .sheet(isPresented: $isShowingInstallmentPlan) {
                AddInstallmentPlanView()
                    .environmentObject(store)
            }
            .sheet(item: $duplicateCandidateToReview) { candidate in
                DuplicateTransactionReviewSheet(candidate: candidate)
                    .environmentObject(store)
            }
        }
    }

    private var amount: Double {
        RecurringMonthlyAmountsSection.parseAmountText(amountText)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var availableSubcategories: [String] {
        store.activeSubcategories(for: selectedCategoryName)
    }

    private var availableAccounts: [Account] {
        let activeAccounts = store.activeAccounts.filter { $0.isActive }

        if selectedPaymentMethod == .instaPay {
            return activeAccounts.filter { $0.type == .bank }
        }

        return activeAccounts
    }

    private var activeCreditCards: [CreditCard] {
        store.activeCreditCards
    }

    private var creditCardSelectionBinding: Binding<UUID?> {
        Binding(
            get: { selectedCreditCardID },
            set: { selectedCreditCardID = $0 }
        )
    }

    private var instaPayFee: Double {
        store.calculateInstaPayFee(for: amount)
    }

    private var isSelectedAccountBank: Bool {
        store.activeAccounts.first { $0.name == selectedAccountName }?.type == .bank
    }

    private var shouldShowValidationMessages: Bool {
        !canSave
    }

    private var validationMessages: [String] {
        var messages: [String] = []

        if selectedPaymentMethod == .installment {
            return []
        }

        if amount <= 0 {
            messages.append(isAr ? "أدخل مبلغ أكبر من صفر." : "Enter an amount greater than zero.")
        }

        if trimmedTitle.isEmpty {
            messages.append(isAr ? "أدخل عنوانًا أو وصفًا." : "Enter a title or description.")
        }

        if selectedCategoryName.isEmpty {
            messages.append(isAr ? "اختر تصنيفًا." : "Select a category.")
        }

        if selectedSubCategoryName.isEmpty {
            messages.append(isAr ? "اختر تصنيفًا فرعيًا." : "Select a subcategory.")
        }

        if selectedPaymentMethod.eventValue.isEmpty {
            messages.append(isAr ? "اختر طريقة الدفع." : "Select a payment method.")
        }

        if selectedPaymentMethod == .creditCard {
            if activeCreditCards.isEmpty {
                messages.append(isAr ? "أضف كارت ائتمان من الإعدادات أولًا" : "Add a credit card first from Settings.")
            } else if selectedCreditCardID == nil {
                messages.append(isAr ? "اختر الكارت" : "Select Credit Card.")
            }
        } else if selectedAccountName.isEmpty {
            messages.append(isAr ? "اختر الحساب للخصم منه." : "Select the account to deduct from.")
        } else if selectedPaymentMethod == .instaPay && !isSelectedAccountBank {
            messages.append(isAr ? "InstaPay يجب ربطه بحساب بنكي." : "InstaPay must be linked to a bank account.")
        }

        return messages
    }

    private var canAddSubcategory: Bool {
        !selectedCategoryName.isEmpty &&
        !newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var newSubcategoryParentHint: String {
        if selectedCategoryName.isEmpty {
            return isAr ? "اختر تصنيفًا رئيسيًا أولًا." : "Select a main category first."
        }

        return isAr ? "سيُضاف تحت: \(selectedCategoryName)" : "Will be added under: \(selectedCategoryName)"
    }

    private var categorySuggestion: CategorySubcategorySuggestion? {
        store.suggestedCategorySubcategory(
            for: CategorySuggestionRequest(
                title: trimmedTitle,
                merchant: bankSMSDraft?.merchant,
                note: note,
                rawText: bankSMSDraft?.note,
                accountName: selectedAccountName,
                paymentMethodName: selectedPaymentMethod.eventValue,
                allowedEventTypes: [.expense],
                includeCreditCardPurchases: true
            )
        )
    }

    private var canSave: Bool {
        if selectedPaymentMethod == .installment {
            return true
        }

        guard amount > 0,
              !trimmedTitle.isEmpty,
              !selectedCategoryName.isEmpty,
              !selectedSubCategoryName.isEmpty else {
            return false
        }

        if selectedPaymentMethod == .creditCard {
            guard let selectedCreditCardID else {
                return false
            }

            return activeCreditCards.contains { $0.id == selectedCreditCardID }
        }

        guard !selectedAccountName.isEmpty else {
            return false
        }

        if selectedPaymentMethod == .instaPay {
            return isSelectedAccountBank
        }

        return true
    }

    private var duplicateCheckRequest: TransactionDuplicateCheckRequest? {
        if selectedPaymentMethod == .creditCard {
            guard let selectedCreditCardID,
                  let card = activeCreditCards.first(where: { $0.id == selectedCreditCardID }) else {
                return nil
            }

            return TransactionDuplicateCheckRequest(
                title: trimmedTitle,
                amount: amount,
                date: date,
                cardID: selectedCreditCardID,
                cardName: card.name,
                categoryName: selectedCategoryName,
                subCategoryName: selectedSubCategoryName,
                importIdentity: bankSMSDraft?.importIdentity,
                rawImportNote: bankSMSDraft?.note,
                eventType: .expense
            )
        }

        return TransactionDuplicateCheckRequest(
            title: trimmedTitle,
            amount: amount,
            date: date,
            accountName: selectedAccountName,
            paymentMethodName: selectedPaymentMethod.eventValue,
            categoryName: selectedCategoryName,
            subCategoryName: selectedSubCategoryName,
            importIdentity: bankSMSDraft?.importIdentity,
            rawImportNote: bankSMSDraft?.note,
            eventType: .expense
        )
    }

    private var saveButtonTitle: String {
        if isSaving {
            return isAr ? "جاري الحفظ..." : "Saving..."
        }

        return selectedPaymentMethod == .installment
            ? (isAr ? "افتح خطة التقسيط" : "Open Installment Plan")
            : (isAr ? "حفظ المصروف" : "Save Expense")
    }

    private func setupInitialValues() {
        guard !didSetupInitialValues else {
            return
        }

        didSetupInitialValues = true
        selectedEvent = prefilledEvent

        if let bankSMSDraft {
            applyBankSMSDraft(bankSMSDraft)
        } else if let prefilledEvent {
            applyQuickEvent(prefilledEvent)
        } else {
            selectedCategoryName = store.activeCategories.first { $0.isActive }?.name ?? ""
            selectedSubCategoryName = availableSubcategories.first ?? ""
            selectedAccountName = availableAccounts.first?.name ?? ""
            selectedCreditCardID = activeCreditCards.first?.id
        }
    }

    private func applyBankSMSDraft(_ draft: BankSMSImportDraft) {
        if let amount = draft.amount {
            amountText = formatAmountForInput(amount)
        }

        if let transactionDate = draft.transactionDate {
            date = transactionDate
        }

        title = draft.merchant ?? "Review imported draft"
        note = draft.note
        selectedCategoryName = ""
        selectedSubCategoryName = ""
        newSubcategoryName = ""
        selectedEvent = nil

        if draft.transactionType == "transfer" {
            selectedPaymentMethod = .instaPay
            selectedAccountName = uniqueMatchingAccount(for: draft.sourceEnding)?.name ?? ""
            selectedCreditCardID = nil
            appendSourceMatchNote(for: draft.sourceEnding, matched: !selectedAccountName.isEmpty, multiple: hasMultipleMatchingAccounts(for: draft.sourceEnding))
            return
        }

        let sourceMatch = uniquePaymentSourceMatch(for: draft)
        switch sourceMatch {
        case .creditCard(let card):
            selectedPaymentMethod = .creditCard
            selectedCreditCardID = card.id
            selectedAccountName = ""
            return
        case .account(let account):
            selectedPaymentMethod = .direct
            selectedAccountName = account.name
            return
        case .multiple:
            appendSourceMatchNote(for: draft.sourceEnding, matched: false, multiple: true, multipleMessage: "Multiple sources match ending")
        case .none:
            appendSourceMatchNote(for: draft.sourceEnding, matched: false, multiple: false)
        }

        selectedPaymentMethod = .direct
        selectedAccountName = ""
        selectedCreditCardID = nil
    }

    private func applyQuickEvent(_ event: WalletEvent?) {
        guard let event else {
            return
        }

        title = event.name
        selectedCategoryName = event.categoryName
        selectedSubCategoryName = event.subCategoryName

        if let accountName = event.defaultAccountName {
            selectedAccountName = accountName
        }
    }

    private func updateSubcategoryForCategory(_ categoryName: String) {
        let subcategories = store.activeSubcategories(for: categoryName)

        if !subcategories.contains(selectedSubCategoryName) {
            selectedSubCategoryName = subcategories.first ?? ""
        }
    }

    private func ensureSelectedAccountIsValid() {
        if selectedPaymentMethod == .creditCard {
            if let selectedCreditCardID,
               !activeCreditCards.contains(where: { $0.id == selectedCreditCardID }) {
                self.selectedCreditCardID = activeCreditCards.first?.id
            } else if selectedCreditCardID == nil {
                selectedCreditCardID = activeCreditCards.first?.id
            }
            return
        }

        if selectedPaymentMethod == .instaPay,
           !isSelectedAccountBank {
            selectedAccountName = availableAccounts.first?.name ?? ""
            return
        }

        if !availableAccounts.contains(where: { $0.name == selectedAccountName }) {
            selectedAccountName = availableAccounts.first?.name ?? ""
        }
    }

    private enum PaymentSourceMatch {
        case creditCard(CreditCard)
        case account(Account)
        case multiple
        case none
    }

    private func uniquePaymentSourceMatch(for draft: BankSMSImportDraft) -> PaymentSourceMatch {
        guard let sourceEnding = draft.sourceEnding, !sourceEnding.isEmpty else {
            return .none
        }

        let cardMatches = activeCreditCards.filter { $0.lastFourDigits == sourceEnding }
        let accountMatches = matchingAccounts(for: sourceEnding)

        if draft.sourceSubtype == "creditCard" {
            guard cardMatches.count == 1 else {
                return cardMatches.count > 1 ? .multiple : .none
            }

            return .creditCard(cardMatches[0])
        }

        if draft.sourceSubtype == "debitCard" {
            guard accountMatches.count == 1 else {
                return accountMatches.count > 1 ? .multiple : .none
            }

            return .account(accountMatches[0])
        }

        let totalMatches = cardMatches.count + accountMatches.count
        guard totalMatches == 1 else {
            return totalMatches > 1 ? .multiple : .none
        }

        if let card = cardMatches.first {
            return .creditCard(card)
        }

        if let account = accountMatches.first {
            return .account(account)
        }

        return .none
    }

    private func uniqueMatchingAccount(for sourceEnding: String?) -> Account? {
        guard let sourceEnding else {
            return nil
        }

        let matches = matchingAccounts(for: sourceEnding)
        return matches.count == 1 ? matches.first : nil
    }

    private func hasMultipleMatchingAccounts(for sourceEnding: String?) -> Bool {
        guard let sourceEnding else {
            return false
        }

        return matchingAccounts(for: sourceEnding).count > 1
    }

    private func matchingAccounts(for sourceEnding: String) -> [Account] {
        store.activeAccounts.filter { account in
            account.isActive && account.recognitionCardEndings.contains(sourceEnding)
        }
    }

    private func appendSourceMatchNote(
        for sourceEnding: String?,
        matched: Bool,
        multiple: Bool,
        multipleMessage: String = "Multiple accounts match ending"
    ) {
        guard let sourceEnding, !sourceEnding.isEmpty else {
            return
        }

        let line: String
        if multiple {
            line = "\(multipleMessage) \(sourceEnding), please choose manually."
        } else if matched {
            return
        } else {
            line = "Detected ending: \(sourceEnding)"
        }

        if !note.contains(line) {
            note = note.isEmpty ? line : "\(note)\n\(line)"
        }
    }

    private func addNewSubcategory() {
        let cleanSubcategory = newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        store.addSubcategory(cleanSubcategory, to: selectedCategoryName)
        selectedSubCategoryName = cleanSubcategory
        newSubcategoryName = ""
    }

    private func saveExpense() {
        if selectedPaymentMethod == .installment {
            guard !isShowingInstallmentPlan else {
                return
            }

            isShowingInstallmentPlan = true
            return
        }

        guard canSave, !isSaving, !hasSaved else {
            return
        }

        if let importIdentity = bankSMSDraft?.importIdentity,
           savedImportIdentity == importIdentity {
            return
        }

        if !shouldBypassDuplicateWarning,
           let duplicateCheckRequest,
           let duplicate = store.possibleDuplicateTransaction(for: duplicateCheckRequest) {
            duplicateCandidateToConfirm = duplicate
            isShowingDuplicateConfirmation = true
            return
        }

        shouldBypassDuplicateWarning = false

        isSaving = true
        Task { @MainActor in
            await Task.yield()
            performSaveExpense()
        }
    }

    private func performSaveExpense() {
        guard canSave, isSaving, !hasSaved else {
            isSaving = false
            return
        }

        switch selectedPaymentMethod {
        case .direct:
            store.addManualExpense(
                title: trimmedTitle,
                amount: amount,
                date: date,
                accountName: selectedAccountName,
                paymentMethodName: selectedPaymentMethod.eventValue,
                walletEventName: selectedEvent?.name,
                categoryName: selectedCategoryName,
                subCategoryName: selectedSubCategoryName,
                note: note.isEmpty ? nil : note
            )

        case .instaPay:
            store.addInstaPayExpense(
                title: trimmedTitle,
                amount: amount,
                date: date,
                sourceAccountName: selectedAccountName,
                walletEventName: selectedEvent?.name,
                categoryName: selectedCategoryName,
                subCategoryName: selectedSubCategoryName,
                note: note.isEmpty ? nil : note
            )

        case .creditCard:
            guard let selectedCreditCardID else {
                isSaving = false
                return
            }

            store.addCreditCardPurchase(
                cardID: selectedCreditCardID,
                title: trimmedTitle,
                amount: amount,
                purchaseDate: date,
                categoryName: selectedCategoryName,
                subCategoryName: selectedSubCategoryName,
                note: note.isEmpty ? nil : note
            )

        case .installment:
            isSaving = false
            return
        }

        if saveAsQuickEvent {
            store.addQuickEvent(
                name: trimmedTitle,
                categoryName: selectedCategoryName,
                subCategoryName: selectedSubCategoryName,
                defaultAccountName: selectedPaymentMethod == .direct || selectedPaymentMethod == .instaPay ? selectedAccountName : nil,
                isFavorite: markQuickEventAsFavorite
            )
        }

        if let importIdentity = bankSMSDraft?.importIdentity {
            savedImportIdentity = importIdentity
        }

        hasSaved = true
        if let bankSMSDraft {
            onBankSMSImportSaved?(bankSMSDraft)
        }
        dismiss()
    }

    private func discardBankSMSImport() {
        guard let bankSMSDraft else {
            return
        }

        onBankSMSImportDiscarded?(bankSMSDraft)
        dismiss()
    }

    private func duplicateSummaryText(for candidate: TransactionDuplicateCandidate) -> String {
        "\(candidate.title) • \(formatCurrency(candidate.amount)) • \(formatDate(candidate.date)) • \(candidate.accountOrCardName)"
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(PocketWiseSemanticColor.danger.tint)
    }

    private func cleanNumberText(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return "\(amount)"
    }

    private func formatAmountForInput(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return String(format: "%.2f", amount)
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2

        let number = NSNumber(value: amount)
        let formatted = formatter.string(from: number) ?? "\(amount)"

        return "\(formatted) EGP"
    }

    private func creditCardPickerTitle(_ card: CreditCard) -> String {
        if let lastFourDigits = card.lastFourDigits {
            return "\(card.name) •••• \(lastFourDigits)"
        }

        return card.name
    }
}

struct DuplicateTransactionReviewSheet: View {
    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let candidate: TransactionDuplicateCandidate
    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    var body: some View {
        NavigationStack {
            Form {
                Section(isAr ? "المعاملة الموجودة" : "Existing Transaction") {
                    detailRow(isAr ? "العنوان" : "Title", candidate.title)
                    detailRow(isAr ? "المبلغ" : "Amount", store.displayCurrency(candidate.amount))
                    detailRow(isAr ? "التاريخ" : "Date", candidate.date.formatted(date: .abbreviated, time: .shortened))
                    detailRow(candidate.sourceKind == .creditCardPurchase ? (isAr ? "الكارت" : "Card") : (isAr ? "الحساب" : "Account"), candidate.accountOrCardName)

                    if let paymentMethodName = candidate.paymentMethodName,
                       !paymentMethodName.isEmpty {
                        detailRow(isAr ? "طريقة الدفع" : "Payment Method", paymentMethodName)
                    }
                }

                if candidate.categoryName != nil || candidate.subCategoryName != nil {
                    Section(isAr ? "التصنيف" : "Category") {
                        if let categoryName = candidate.categoryName {
                            detailRow(isAr ? "التصنيف" : "Category", categoryName)
                        }

                        if let subCategoryName = candidate.subCategoryName {
                            detailRow(isAr ? "التصنيف الفرعي" : "Subcategory", subCategoryName)
                        }
                    }
                }

                Section {
                    Text(isAr ? "هذا للمراجعة فقط. لا يتغير شيء إلا إذا عدت واخترت حفظ على أي حال." : "This is a read-only duplicate check. Nothing is changed unless you return and choose Save anyway.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(isAr ? "تكرار محتمل" : "Possible Duplicate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isAr ? "إغلاق" : "Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Preview

struct AddExpenseView_Previews: PreviewProvider {
    static var previews: some View {
        AddExpenseView(prefilledEvent: SampleWalletData.favoriteEvents.first)
            .environmentObject(WalletStore())
    }
}
