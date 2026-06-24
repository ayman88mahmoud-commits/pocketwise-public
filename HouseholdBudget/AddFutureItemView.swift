import SwiftUI

struct AddFutureItemView: View {

    private enum FutureItemType: String, CaseIterable, Identifiable {
        case expectedIncome = "Expected Income"
        case fixedObligation = "Fixed Obligation"
        case expectedExpense = "Expected Expense"

        var id: String { rawValue }

        var eventType: FinancialEventType {
            switch self {
            case .expectedIncome:
                return .income
            case .fixedObligation:
                return .obligation
            case .expectedExpense:
                return .expectedExpense
            }
        }

        var status: FinancialEventStatus {
            switch self {
            case .expectedIncome, .expectedExpense:
                return .expected
            case .fixedObligation:
                return .unpaid
            }
        }

        var defaultConfidence: ConfidenceLevel {
            switch self {
            case .expectedIncome, .expectedExpense:
                return .medium
            case .fixedObligation:
                return .high
            }
        }

        var needsCategory: Bool {
            self != .expectedIncome
        }
    }

    private enum IncomeReceiptStatus: String, CaseIterable, Identifiable {
        case expected
        case receivedNow

        var id: String { rawValue }

        func title(language: AppLanguage) -> String {
            switch self {
            case .expected:
                return language == .arabicEgyptian ? "متوقع / لم يتم استلامه" : "Expected / Not received yet"
            case .receivedNow:
                return language == .arabicEgyptian ? "تم استلامه الآن" : "Received now"
            }
        }
    }

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss
    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    let bankSMSDraft: BankSMSImportDraft?
    let onBankSMSImportSaved: ((BankSMSImportDraft) -> Void)?
    let onBankSMSImportDiscarded: ((BankSMSImportDraft) -> Void)?
    private let incomeOnlyFlow: Bool
    private let recurringIncomeFlow: Bool

    @State private var selectedItemType: FutureItemType = .expectedExpense
    @State private var incomeReceiptStatus: IncomeReceiptStatus = .expected
    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var date: Date = Date()
    @State private var selectedAccountName: String = ""
    @State private var selectedCategoryName: String = ""
    @State private var selectedSubCategoryName: String = ""
    @State private var incomeType: IncomeType = .oneTimeCashInflow
    @State private var reimbursementCategoryName: String = ""
    @State private var recurringIncomeAmountMode: RecurringAmountMode = .fixedAmount
    @State private var variableIncomePlanningMonthCount = 3
    @State private var recurringIncomeMonthAmountTexts: [String: String] = [:]
    @State private var repeatRule: RepeatRule = .none
    @State private var recurringEndKind: RecurringEndKind = .never
    @State private var recurringEndDate: Date = Date()
    @State private var recurringEndPaymentCountText: String = ""
    @State private var confidence: ConfidenceLevel = .medium
    @State private var note: String = ""
    @State private var didSetupInitialValues = false
    @State private var isSaving = false
    @State private var hasSaved = false
    @State private var savedImportIdentity: String?
    @State private var isShowingDiscardImportConfirmation = false
    @State private var isShowingDuplicateConfirmation = false
    @State private var duplicateCandidateToConfirm: TransactionDuplicateCandidate?
    @State private var duplicateCandidateToReview: TransactionDuplicateCandidate?
    @State private var shouldBypassDuplicateWarning = false

    init(
        startsAsIncome: Bool = false,
        startsAsReceivedIncome: Bool = true,
        startsAsRecurringIncome: Bool = false,
        bankSMSDraft: BankSMSImportDraft? = nil,
        onBankSMSImportSaved: ((BankSMSImportDraft) -> Void)? = nil,
        onBankSMSImportDiscarded: ((BankSMSImportDraft) -> Void)? = nil
    ) {
        self.bankSMSDraft = bankSMSDraft
        self.onBankSMSImportSaved = onBankSMSImportSaved
        self.onBankSMSImportDiscarded = onBankSMSImportDiscarded
        self.incomeOnlyFlow = startsAsIncome
        self.recurringIncomeFlow = startsAsRecurringIncome
        _selectedItemType = State(initialValue: startsAsIncome ? .expectedIncome : .expectedExpense)
        _incomeReceiptStatus = State(initialValue: startsAsIncome && startsAsReceivedIncome && !startsAsRecurringIncome ? .receivedNow : .expected)
        _repeatRule = State(initialValue: startsAsRecurringIncome ? .monthly : .none)
        _incomeType = State(initialValue: startsAsRecurringIncome ? .salary : .oneTimeCashInflow)
    }

    var body: some View {
        NavigationStack {
            Form {
                if incomeOnlyFlow {
                    Section(store.appLanguage == .arabicEgyptian ? "الدخل" : "Income") {
                        Label(incomeFlowTitle, systemImage: recurringIncomeFlow ? "repeat.circle.fill" : "arrow.down.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(PocketWiseSemanticColor.income.tint)

                        Text(incomeFlowHelpText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section(isAr ? "نوع البند" : "Item Type") {
                        Picker(isAr ? "النوع" : "Type", selection: $selectedItemType) {
                            ForEach(FutureItemType.allCases) { itemType in
                                Text(itemTypeTitle(itemType))
                                    .tag(itemType)
                            }
                        }
                        .pocketWiseInputField(semanticColor: selectedItemType == .expectedIncome ? .income : .obligations)
                    }
                }

                Section(isAr ? "التفاصيل" : "Details") {
                    TextField(isAr ? "عنوان أو وصف" : "Title or description", text: $title)
                        .pocketWiseInputField(semanticColor: selectedItemType == .expectedIncome ? .income : .obligations)

                    if !(recurringIncomeFlow && recurringIncomeAmountMode == .variableEachMonth) {
                        TextField(recurringIncomeFlow ? (store.appLanguage == .arabicEgyptian ? "المبلغ الشهري" : "Monthly amount") : "Amount", text: $amountText)
                            .keyboardType(.decimalPad)
                            .pocketWiseInputField(semanticColor: selectedItemType == .expectedIncome ? .income : .obligations, isProminent: true)
                    }

                    DatePicker(
                        store.appLanguage == .arabicEgyptian ? "التاريخ والوقت" : "Date & Time",
                        selection: $date,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .pocketWiseInputField(semanticColor: selectedItemType == .expectedIncome ? .income : .obligations)
                }

                Section(isAr ? "الحساب" : "Account") {
                    AccountMenuPickerField(
                        title: isAr ? "الحساب" : "Account",
                        selection: $selectedAccountName,
                        accounts: store.activeAccounts.filter { $0.isActive },
                        placeholder: isAr ? "لا يوجد حساب بعد" : "No account yet",
                        emptyTitle: isAr ? "لا يوجد حساب بعد" : "No account yet"
                    )
                    .pocketWiseInputField(semanticColor: .accounts)
                }

                if selectedItemType.needsCategory {
                    Section(isAr ? "التصنيف" : "Category") {
                        CategorySubcategoryPickerView(
                            categoryName: $selectedCategoryName,
                            subCategoryName: $selectedSubCategoryName,
                            suggestion: categorySuggestion
                        )
                    }
                }

                if selectedItemType == .expectedIncome {
                    if !recurringIncomeFlow {
                        Section(store.appLanguage == .arabicEgyptian ? "الحالة" : "Status") {
                            Picker(store.appLanguage == .arabicEgyptian ? "الحالة" : "Status", selection: $incomeReceiptStatus) {
                                ForEach(IncomeReceiptStatus.allCases) { status in
                                    Text(status.title(language: store.appLanguage))
                                        .tag(status)
                                }
                            }
                            .pocketWiseInputField(semanticColor: .income)

                            Text(incomeReceiptStatus == .receivedNow ? receivedIncomeHelpText : expectedIncomeHelpText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section(isAr ? "نوع الدخل" : "Income Type") {
                        Picker(isAr ? "نوع الدخل" : "Income Type", selection: $incomeType) {
                            ForEach(IncomeType.allCases) { type in
                                Text(type.title(language: store.appLanguage))
                                    .tag(type)
                            }
                        }
                        .pocketWiseInputField(semanticColor: .income)

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

                                ForEach(store.activeCategories.filter { $0.isActive }) { category in
                                    Text(category.name)
                                        .tag(category.name)
                                }
                            }
                            .pocketWiseInputField(semanticColor: .categories)

                            if reimbursementCategoryName.isEmpty {
                                Text(store.appLanguage == .arabicEgyptian ? "اختار التصنيف الأصلي للمصروف، زي Health & Medical." : "Choose the original expense category, such as Health & Medical.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if recurringIncomeFlow {
                        Section(store.appLanguage == .arabicEgyptian ? "نمط الدخل" : "Income Pattern") {
                            Picker(store.appLanguage == .arabicEgyptian ? "نمط الدخل" : "Income Pattern", selection: $recurringIncomeAmountMode) {
                                Text(store.appLanguage == .arabicEgyptian ? "نفس المبلغ كل شهر" : "Same amount every month")
                                    .tag(RecurringAmountMode.fixedAmount)

                                Text(store.appLanguage == .arabicEgyptian ? "مبلغ مختلف كل شهر" : "Different amount each month")
                                    .tag(RecurringAmountMode.variableEachMonth)
                            }
                            .pocketWiseInputField(semanticColor: .income)

                            Text(recurringIncomeAmountMode == .variableEachMonth
                                 ? (store.appLanguage == .arabicEgyptian ? "حدد الدخل المتوقع لكل شهر. هذا لا يغير الرصيد حتى تسجل الدخل كمستلم." : "Set the expected income for each month. This does not change your balance until you mark the income received.")
                                 : (store.appLanguage == .arabicEgyptian ? "استخدم هذا إذا كان الدخل المتوقع ثابتًا كل شهر." : "Use this when the expected income is the same each month."))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if recurringIncomeAmountMode == .variableEachMonth {
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

                                Text(store.appLanguage == .arabicEgyptian ? "سيتم إنشاء دخل متوقع فقط داخل فترة التخطيط. الشهور الفارغة لا تظهر كتخطي إلا إذا تخطيتها لاحقًا." : "Expected income is generated only inside this planning period. Empty months stay unset rather than becoming skipped rows.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            RecurringMonthlyAmountsSection(
                                startDate: date,
                                monthAmountTexts: $recurringIncomeMonthAmountTexts,
                                visibleMonthCount: variableIncomePlanningMonthCount,
                                title: store.appLanguage == .arabicEgyptian ? "المبلغ المتوقع حسب الشهر" : "Expected amount by month",
                                helpText: store.appLanguage == .arabicEgyptian ? "حدد الدخل المتوقع لكل شهر. الشهر الفارغ لا يظهر في التوقعات." : "Set the expected income for each month. Empty months do not appear in forecasts.",
                                positiveStatusText: store.appLanguage == .arabicEgyptian ? "دخل متوقع" : "Expected income",
                                emptyStatusText: store.appLanguage == .arabicEgyptian ? "غير محدد" : "Not set",
                                semanticColor: .accounts
                            )
                        }
                    }
                }

                if !(selectedItemType == .expectedIncome && incomeReceiptStatus == .receivedNow) {
                    Section(selectedItemType == .expectedIncome ? (store.appLanguage == .arabicEgyptian ? "جدول الدخل" : "Income Schedule") : "Planning") {
                        if !(recurringIncomeFlow && recurringIncomeAmountMode == .variableEachMonth) {
                            Picker(isAr ? "التكرار" : "Repeat", selection: $repeatRule) {
                                ForEach(RepeatRule.allCases) { rule in
                                    Text(AppText.repeatRuleLabel(rule, language: store.appLanguage))
                                        .tag(rule)
                                }
                            }
                            .pocketWiseInputField(semanticColor: selectedItemType == .expectedIncome ? .income : .obligations)

                            if recurringIncomeFlow {
                                Picker(store.appLanguage == .arabicEgyptian ? "ينتهي" : "Ends", selection: $recurringEndKind) {
                                    Text(store.appLanguage == .arabicEgyptian ? "بدون نهاية" : "Never")
                                        .tag(RecurringEndKind.never)

                                    Text(store.appLanguage == .arabicEgyptian ? "بعد عدد شهور" : "After number of months")
                                        .tag(RecurringEndKind.afterNumberOfPayments)

                                    Text(store.appLanguage == .arabicEgyptian ? "في تاريخ" : "On date")
                                        .tag(RecurringEndKind.onDate)
                                }
                                .pocketWiseInputField(semanticColor: .income)

                                if recurringEndKind == .afterNumberOfPayments {
                                    TextField(store.appLanguage == .arabicEgyptian ? "عدد الشهور" : "Number of months", text: $recurringEndPaymentCountText)
                                        .keyboardType(.numberPad)
                                        .pocketWiseInputField(semanticColor: .income)
                                }

                                if recurringEndKind == .onDate {
                                    DatePicker(
                                        store.appLanguage == .arabicEgyptian ? "تاريخ النهاية" : "End date",
                                        selection: $recurringEndDate,
                                        displayedComponents: .date
                                    )
                                    .pocketWiseInputField(semanticColor: .income)
                                }
                            }
                        }

                        Picker(isAr ? "مستوى الثقة" : "Confidence", selection: $confidence) {
                            ForEach(ConfidenceLevel.allCases) { level in
                                Text(AppText.confidenceLevelLabel(level, language: store.appLanguage))
                                    .tag(level)
                            }
                        }
                        .pocketWiseInputField(semanticColor: .setup)

                        if recurringIncomeFlow {
                            Text(store.appLanguage == .arabicEgyptian ? "سيظهر كدخل متوقع متكرر. لا يغير الرصيد إلا عند تسجيله كمستلم." : "This appears as recurring expected income. It does not change balance until marked received.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(isAr ? "ملاحظة" : "Note") {
                    TextField(isAr ? "ملاحظة اختيارية" : "Optional note", text: $note)
                        .pocketWiseInputField(semanticColor: .neutral)
                }

                Section {
                    Button {
                        saveFutureItem()
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
                }
            }
            .navigationTitle(navigationTitle)
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
                isAr ? "تجاهل الاستيراد المعلق؟" : "Discard this pending import?",
                isPresented: $isShowingDiscardImportConfirmation,
                titleVisibility: .visible
            ) {
                Button(isAr ? "تجاهل الاستيراد" : "Discard Import", role: .destructive) {
                    discardBankSMSImport()
                }

                Button(isAr ? "احتفظ به لاحقًا" : "Keep for Later", role: .cancel) {}
            } message: {
                Text(isAr ? "سيُزال مسودة استيراد الرسالة بدون إنشاء معاملة." : "This removes the SMS import draft without creating a transaction.")
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
                    saveFutureItem()
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
            .onChange(of: selectedItemType) { _, newValue in
                updateForItemType(newValue)
            }
            .onChange(of: selectedCategoryName) { _, newValue in
                updateSubcategoryForCategory(newValue)
            }
            .onChange(of: incomeType) { _, _ in
                updateReimbursementCategory()
            }
            .sheet(item: $duplicateCandidateToReview) { candidate in
                DuplicateTransactionReviewSheet(candidate: candidate)
                    .environmentObject(store)
            }
        }
    }

    private var amount: Double {
        parseAmountText(amountText)
    }

    private var recurringIncomeInlineMonthlyOverrides: [RecurringScheduleOverride] {
        RecurringMonthlyAmountsSection.visibleMonthKeys(
            startDate: date,
            visibleMonthCount: recurringIncomeAmountMode == .variableEachMonth ? variableIncomePlanningMonthCount : 12
        ).compactMap { key in
            let amount = RecurringMonthlyAmountsSection.parseAmountText(recurringIncomeMonthAmountTexts[key.id] ?? "")
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

    private var firstPositiveRecurringIncomeMonthAmount: Double {
        recurringIncomeInlineMonthlyOverrides.first?.amount ?? 0
    }

    private var amountForSave: Double {
        recurringIncomeFlow && recurringIncomeAmountMode == .variableEachMonth
            ? firstPositiveRecurringIncomeMonthAmount
            : amount
    }

    private var recurringEndPaymentCount: Int? {
        Int(recurringEndPaymentCountText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var recurringEndIsValid: Bool {
        if recurringIncomeFlow && recurringIncomeAmountMode == .variableEachMonth {
            return variableIncomePlanningMonthCount > 0
        }

        switch recurringEndKind {
        case .never:
            return true
        case .onDate:
            return recurringEndDate >= date
        case .afterNumberOfPayments:
            return (recurringEndPaymentCount ?? 0) > 0
        }
    }

    private var recurringEndKindForSave: RecurringEndKind? {
        if recurringIncomeFlow && recurringIncomeAmountMode == .variableEachMonth {
            return .afterNumberOfPayments
        }

        return recurringEndKind == .never ? nil : recurringEndKind
    }

    private var recurringEndPaymentCountForSave: Int? {
        if recurringIncomeFlow && recurringIncomeAmountMode == .variableEachMonth {
            return variableIncomePlanningMonthCount
        }

        return recurringEndKind == .afterNumberOfPayments ? recurringEndPaymentCount : nil
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var categoryNameForSave: String? {
        selectedItemType.needsCategory ? selectedCategoryName : nil
    }

    private var subCategoryNameForSave: String? {
        selectedItemType.needsCategory ? selectedSubCategoryName : nil
    }

    private var availableSubcategories: [String] {
        store.activeSubcategories(for: selectedCategoryName)
    }

    private var canSave: Bool {
        guard !trimmedTitle.isEmpty,
              amountForSave > 0 else {
            return false
        }

        if selectedItemType == .expectedIncome,
           incomeReceiptStatus == .receivedNow {
            return !selectedAccountName.isEmpty && reimbursementSelectionIsValid
        }

        if recurringIncomeFlow {
            return !selectedAccountName.isEmpty &&
            repeatRule != .none &&
            recurringEndIsValid &&
            reimbursementSelectionIsValid
        }

        if selectedItemType == .expectedIncome {
            return reimbursementSelectionIsValid
        }

        if selectedItemType.needsCategory {
            return !selectedCategoryName.isEmpty && !selectedSubCategoryName.isEmpty
        }

        return true
    }

    private var categorySuggestion: CategorySubcategorySuggestion? {
        guard selectedItemType.needsCategory else {
            return nil
        }

        let allowedTypes: Set<FinancialEventType> = selectedItemType == .fixedObligation
            ? [.obligation, .expense]
            : [.expectedExpense, .expense]

        return store.suggestedCategorySubcategory(
            for: CategorySuggestionRequest(
                title: trimmedTitle,
                merchant: bankSMSDraft?.merchant,
                note: note,
                rawText: bankSMSDraft?.note,
                accountName: selectedAccountName,
                paymentMethodName: "",
                allowedEventTypes: allowedTypes,
                includeCreditCardPurchases: true
            )
        )
    }

    private var navigationTitle: String {
        if recurringIncomeFlow {
            return store.appLanguage == .arabicEgyptian ? "إضافة دخل متكرر" : "Add Recurring Income"
        }

        if selectedItemType == .expectedIncome,
           incomeReceiptStatus == .receivedNow {
            return store.appLanguage == .arabicEgyptian ? "إضافة دخل" : "Add Income"
        }

        if selectedItemType == .expectedIncome {
            return store.appLanguage == .arabicEgyptian ? "إضافة دخل متوقع" : "Add Expected Income"
        }

        return store.appLanguage == .arabicEgyptian ? "إضافة حاجة جاية" : "Add Future Item"
    }

    private var saveButtonTitle: String {
        if isSaving {
            return store.appLanguage == .arabicEgyptian ? "جاري الحفظ..." : "Saving..."
        }

        if selectedItemType == .expectedIncome,
           incomeReceiptStatus == .receivedNow {
            return store.appLanguage == .arabicEgyptian ? "حفظ الدخل المستلم" : "Save Received Income"
        }

        if recurringIncomeFlow {
            return store.appLanguage == .arabicEgyptian ? "حفظ الدخل المتكرر" : "Save Recurring Income"
        }

        if selectedItemType == .expectedIncome {
            return store.appLanguage == .arabicEgyptian ? "حفظ الدخل المتوقع" : "Save Expected Income"
        }

        return store.appLanguage == .arabicEgyptian ? "حفظ كمتوقع" : "Save Future Item"
    }

    private var duplicateCheckRequest: TransactionDuplicateCheckRequest? {
        guard selectedItemType == .expectedIncome,
              incomeReceiptStatus == .receivedNow else {
            return nil
        }

        return TransactionDuplicateCheckRequest(
            title: trimmedTitle,
            amount: amount,
            date: date,
            accountName: selectedAccountName,
            paymentMethodName: nil,
            importIdentity: bankSMSDraft?.importIdentity,
            rawImportNote: bankSMSDraft?.note,
            eventType: .income
        )
    }

    private var expectedIncomeHelpText: String {
        store.appLanguage == .arabicEgyptian
            ? "الدخل المتوقع يظهر في القادم وتشغيل السيولة، لكنه لا يغير رصيد الحساب لحد ما يتم استلامه."
            : "Expected income appears in Upcoming and Runway, but it does not change the account balance until received."
    }

    private var receivedIncomeHelpText: String {
        store.appLanguage == .arabicEgyptian
            ? "الدخل المستلم يزيد رصيد الحساب المختار فورًا ويظهر كمعاملة دخل فعلية."
            : "Received income increases the selected account balance now and appears as an actual income transaction."
    }

    private var incomeFlowTitle: String {
        if recurringIncomeFlow {
            return store.appLanguage == .arabicEgyptian ? "دخل متكرر / مرتب" : "Recurring income / salary"
        }

        if incomeReceiptStatus == .receivedNow {
            return store.appLanguage == .arabicEgyptian ? "دخل تم استلامه" : "Received income"
        }

        return store.appLanguage == .arabicEgyptian ? "دخل متوقع" : "Expected income"
    }

    private var incomeFlowHelpText: String {
        if recurringIncomeFlow {
            return store.appLanguage == .arabicEgyptian
                ? "استخدمه للمرتب أو أي دخل يتكرر. سيظهر في القادم والتوقعات ولا يغير الرصيد إلا عند استلامه."
                : "Use this for salary or income that repeats. It appears in Upcoming and forecasts, and changes balance only when received."
        }

        if incomeReceiptStatus == .receivedNow {
            return receivedIncomeHelpText
        }

        return expectedIncomeHelpText
    }

    private func setupInitialValues() {
        guard !didSetupInitialValues else {
            return
        }

        didSetupInitialValues = true
        selectedAccountName = store.activeAccounts.first { $0.isActive }?.name ?? ""
        selectedCategoryName = store.activeCategories.first { $0.isActive }?.name ?? ""
        selectedSubCategoryName = availableSubcategories.first ?? ""
        reimbursementCategoryName = store.activeCategories.first { $0.isActive }?.name ?? ""
        confidence = selectedItemType.defaultConfidence
        recurringEndDate = date

        if let bankSMSDraft {
            applyBankSMSDraft(bankSMSDraft)
        }
    }

    private func applyBankSMSDraft(_ draft: BankSMSImportDraft) {
        selectedItemType = .expectedIncome
        incomeReceiptStatus = .receivedNow
        title = draft.sender?.isEmpty == false ? draft.sender ?? "" : draft.merchant ?? "InstaPay incoming transfer"
        note = draft.note
        incomeType = .oneTimeCashInflow
        repeatRule = .none
        confidence = .high
        selectedAccountName = ""

        if let amount = draft.amount {
            amountText = formatAmountForInput(amount)
        }

        if let transactionDate = draft.transactionDate {
            date = transactionDate
        }

        if let matchingAccount = uniqueMatchingAccount(for: draft.sourceEnding) {
            selectedAccountName = matchingAccount.name
        }

        appendSourceMatchNote(
            for: draft.sourceEnding,
            matched: !selectedAccountName.isEmpty,
            multiple: hasMultipleMatchingAccounts(for: draft.sourceEnding)
        )
    }

    private func updateForItemType(_ itemType: FutureItemType) {
        confidence = itemType.defaultConfidence

        if itemType == .expectedIncome,
           selectedAccountName.isEmpty {
            selectedAccountName = store.activeAccounts.first { $0.isActive }?.name ?? ""
        }

        if itemType.needsCategory {
            if selectedCategoryName.isEmpty {
                selectedCategoryName = store.activeCategories.first { $0.isActive }?.name ?? ""
            }

            if selectedSubCategoryName.isEmpty {
                selectedSubCategoryName = availableSubcategories.first ?? ""
            }
        }
    }

    private func updateSubcategoryForCategory(_ categoryName: String) {
        let subcategories = store.activeSubcategories(for: categoryName)

        if !subcategories.contains(selectedSubCategoryName) {
            selectedSubCategoryName = subcategories.first ?? ""
        }
    }

    private var reimbursementSelectionIsValid: Bool {
        incomeType != .reimbursement || !reimbursementCategoryName.isEmpty
    }

    private func updateReimbursementCategory() {
        guard incomeType == .reimbursement else {
            return
        }

        if reimbursementCategoryName.isEmpty ||
            !store.activeCategories.contains(where: { $0.name == reimbursementCategoryName }) {
            reimbursementCategoryName = store.activeCategories.first { $0.isActive }?.name ?? ""
        }
    }

    private func uniqueMatchingAccount(for sourceEnding: String?) -> Account? {
        guard let sourceEnding, !sourceEnding.isEmpty else {
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

    private func appendSourceMatchNote(for sourceEnding: String?, matched: Bool, multiple: Bool) {
        guard let sourceEnding, !sourceEnding.isEmpty else {
            return
        }

        let line: String
        if multiple {
            line = "Multiple accounts match ending \(sourceEnding), please choose manually."
        } else if matched {
            return
        } else {
            line = "Detected ending: \(sourceEnding)"
        }

        if !note.contains(line) {
            note = note.isEmpty ? line : "\(note)\n\(line)"
        }
    }

    private func itemTypeTitle(_ itemType: FutureItemType) -> String {
        switch itemType {
        case .expectedIncome:
            if incomeReceiptStatus == .receivedNow {
                return store.appLanguage == .arabicEgyptian ? "دخل تم استلامه" : "Income received"
            }

            return store.appLanguage == .arabicEgyptian ? "دخل متوقع" : "Expected Income"
        case .fixedObligation:
            return store.appLanguage == .arabicEgyptian ? "التزام ثابت" : "Fixed Obligation"
        case .expectedExpense:
            return store.appLanguage == .arabicEgyptian ? "مصروف متوقع" : "Expected Expense"
        }
    }

    private func saveFutureItem() {
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
            performSaveFutureItem()
        }
    }

    private func performSaveFutureItem() {
        guard canSave, isSaving, !hasSaved else {
            isSaving = false
            return
        }

        if selectedItemType == .expectedIncome,
           incomeReceiptStatus == .receivedNow {
            store.addIncome(
                title: trimmedTitle,
                amount: amount,
                date: date,
                accountName: selectedAccountName,
                incomeType: incomeType,
                reimbursementCategoryName: incomeType == .reimbursement ? reimbursementCategoryName : nil,
                note: note.isEmpty ? nil : note
            )
            if let importIdentity = bankSMSDraft?.importIdentity {
                savedImportIdentity = importIdentity
            }
            hasSaved = true
            if let bankSMSDraft {
                onBankSMSImportSaved?(bankSMSDraft)
            }
            dismiss()
            return
        }

        let event = FinancialEvent(
            type: selectedItemType.eventType,
            status: selectedItemType.status,
            title: trimmedTitle,
            amount: amountForSave,
            date: date,
            accountName: selectedAccountName.isEmpty ? nil : selectedAccountName,
            paymentMethodName: nil,
            walletEventName: nil,
            categoryName: categoryNameForSave,
            subCategoryName: subCategoryNameForSave,
            incomeType: selectedItemType == .expectedIncome ? incomeType : nil,
            reimbursementCategoryName: incomeType == .reimbursement ? reimbursementCategoryName : nil,
            repeatRule: recurringIncomeFlow && recurringIncomeAmountMode == .variableEachMonth ? .monthly : repeatRule,
            recurringEndKind: recurringIncomeFlow ? recurringEndKindForSave : nil,
            recurringEndDate: recurringIncomeFlow && recurringIncomeAmountMode != .variableEachMonth && recurringEndKind == .onDate ? recurringEndDate : nil,
            recurringEndPaymentCount: recurringIncomeFlow ? recurringEndPaymentCountForSave : nil,
            recurringScheduleOverrides: recurringIncomeFlow && recurringIncomeAmountMode == .variableEachMonth ? recurringIncomeInlineMonthlyOverrides : nil,
            recurringAmountMode: recurringIncomeFlow && recurringIncomeAmountMode == .variableEachMonth ? .variableEachMonth : nil,
            confidence: confidence,
            note: note.isEmpty ? nil : note,
            createdAt: Date()
        )

        store.addFinancialEvent(event)
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
        "\(candidate.title) • \(store.displayCurrency(candidate.amount)) • \(candidate.date.formatted(date: .abbreviated, time: .shortened)) • \(candidate.accountOrCardName)"
    }

    private func parseAmountText(_ text: String) -> Double {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return 0
        }

        if cleaned.contains(",") && cleaned.contains(".") {
            return Double(cleaned.replacingOccurrences(of: ",", with: "")) ?? 0
        }

        if cleaned.contains(",") {
            let parts = cleaned.split(separator: ",")
            if let last = parts.last,
               last.count == 3 {
                return Double(cleaned.replacingOccurrences(of: ",", with: "")) ?? 0
            }

            return Double(cleaned.replacingOccurrences(of: ",", with: ".")) ?? 0
        }

        return Double(cleaned) ?? 0
    }

    private func formatAmountForInput(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return String(format: "%.2f", amount)
    }
}

// MARK: - Preview

struct AddFutureItemView_Previews: PreviewProvider {
    static var previews: some View {
        AddFutureItemView()
            .environmentObject(WalletStore())
    }
}
