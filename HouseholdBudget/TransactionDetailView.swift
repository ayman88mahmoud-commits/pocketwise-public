import SwiftUI

struct TransactionDetailView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let event: FinancialEvent
    let isPresentedModally: Bool

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false
    @State private var isMarkingIncomeReceived = false
    @State private var isManagingRecurringSeries = false
    @State private var selectedInstallmentPlan: InstallmentPlan?

    init(event: FinancialEvent, isPresentedModally: Bool = true) {
        self.event = event
        self.isPresentedModally = isPresentedModally
    }

    var body: some View {
        if isPresentedModally {
            NavigationStack {
                content
            }
        } else {
            content
        }
    }

    private var content: some View {
        List {
            Section(store.appLanguage == .arabicEgyptian ? "المعاملة" : "Transaction") {
                HStack(spacing: 10) {
                    NamedVisualMark(
                        name: event.title,
                        fallbackSystemImage: "tag.fill",
                        size: 28
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.appLanguage == .arabicEgyptian ? "العنوان" : "Title")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(event.title)
                            .fontWeight(.semibold)
                    }
                }
                detailRow(amountDetailTitle, formatCurrency(event.amount))
                detailRow(store.appLanguage == .arabicEgyptian ? "النوع" : "Type", AppText.eventTypeLabel(event.type, language: store.appLanguage))
                detailRow(store.appLanguage == .arabicEgyptian ? "الحالة" : "Status", AppText.statusLabel(event.status, language: store.appLanguage))
                detailRow(store.appLanguage == .arabicEgyptian ? "التاريخ والوقت" : "Date & Time", formatDate(event.date))
            }

            Section(store.appLanguage == .arabicEgyptian ? "الدفع" : "Payment") {
                if event.type == .transfer {
                    accountDetailRow(store.appLanguage == .arabicEgyptian ? "من حساب" : "From Account", event.accountName)
                    accountDetailRow(store.appLanguage == .arabicEgyptian ? "إلى حساب" : "To Account", event.destinationAccountName)
                } else {
                    accountDetailRow(store.appLanguage == .arabicEgyptian ? "الحساب" : "Account", event.accountName)
                    detailRow(store.appLanguage == .arabicEgyptian ? "طريقة الدفع" : "Payment Method", event.paymentMethodName ?? notSetText)
                }
            }

            if event.type != .transfer {
                Section(store.appLanguage == .arabicEgyptian ? "التصنيف" : "Classification") {
                    if event.type == .income {
                        detailRow(store.appLanguage == .arabicEgyptian ? "نوع الدخل" : "Income Type", event.effectiveIncomeType.title(language: store.appLanguage))

                        if event.effectiveIncomeType == .reimbursement {
                            detailRow(
                                store.appLanguage == .arabicEgyptian ? "استرداد عن" : "Reimbursement for",
                                event.reimbursementCategoryName.map { AppText.categoryDisplayName($0, language: store.appLanguage) } ?? notSetText
                            )
                        }
                    } else {
                        detailRow(store.appLanguage == .arabicEgyptian ? "التصنيف" : "Category", event.categoryName.map { AppText.categoryDisplayName($0, language: store.appLanguage) } ?? notSetText)
                        detailRow(store.appLanguage == .arabicEgyptian ? "التصنيف الفرعي" : "Subcategory", event.subCategoryName.map { AppText.subcategoryDisplayName($0, language: store.appLanguage) } ?? notSetText)
                        detailRow(store.appLanguage == .arabicEgyptian ? "التكرار" : "Repeat", AppText.repeatRuleLabel(event.repeatRule, language: store.appLanguage).isEmpty ? notSetText : AppText.repeatRuleLabel(event.repeatRule, language: store.appLanguage))
                    }

                    if let confidence = event.confidence {
                        detailRow(store.appLanguage == .arabicEgyptian ? "الثقة" : "Confidence", AppText.confidenceLevelLabel(confidence, language: store.appLanguage))
                    }
                }
            }

            if let note = event.note,
               !note.isEmpty {
                Section(store.appLanguage == .arabicEgyptian ? "ملاحظة" : "Note") {
                    Text(note)
                }
            }

            if canMarkIncomeReceived {
                Section(store.appLanguage == .arabicEgyptian ? "حالة الدخل" : "Income Status") {
                    Text(store.appLanguage == .arabicEgyptian ? "الدخل المتوقع لا يغير رصيد الحساب لحد ما يتم تسجيله كمستلم." : "Expected income does not change an account balance until it is marked received.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        isMarkingIncomeReceived = true
                    } label: {
                        HStack {
                            Spacer()
                            Text(store.appLanguage == .arabicEgyptian ? "تسجيل كـ مستلم" : "Mark Received")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }

            if canManageSeries {
                Section(store.appLanguage == .arabicEgyptian ? "المصدر" : "Source") {
                    Text(seriesSourceText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        openSeriesSource()
                    } label: {
                        HStack {
                            Spacer()
                            Text(store.appLanguage == .arabicEgyptian ? "إدارة السلسلة" : "Manage series")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }

            Section {
                Button {
                    isEditing = true
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "تعديل" : "Edit")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "حذف المعاملة" : "Delete Transaction")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "تفاصيل المعاملة" : "Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isPresentedModally {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.appLanguage == .arabicEgyptian ? "إغلاق" : "Close") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditFinancialEventView(event: event)
                .environmentObject(store)
        }
        .sheet(isPresented: $isMarkingIncomeReceived) {
            MarkIncomeReceivedView(event: event)
                .environmentObject(store)
        }
        .sheet(isPresented: $isManagingRecurringSeries) {
            if let linkedRecurringSeries {
                RecurringPaymentEditorView(event: linkedRecurringSeries)
                    .environmentObject(store)
            } else {
                RecurringPaymentEditorView(event: event)
                    .environmentObject(store)
            }
        }
        .sheet(item: $selectedInstallmentPlan) { plan in
            InstallmentPlanEditorView(plan: plan)
                .environmentObject(store)
        }
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if let recurringIncomeSeries {
                Button(store.appLanguage == .arabicEgyptian ? "تخطي هذا الشهر" : "Skip this month", role: .destructive) {
                    _ = store.skipRecurringOccurrence(seriesID: recurringIncomeSeries.id, occurrenceDate: event.date)
                    dismiss()
                }

                Button(store.appLanguage == .arabicEgyptian ? "حذف الدخل المتكرر بالكامل" : "Delete entire recurring income", role: .destructive) {
                    store.deleteFinancialEvent(recurringIncomeSeries)
                    dismiss()
                }
            } else {
                Button(store.appLanguage == .arabicEgyptian ? "حذف المعاملة" : "Delete Transaction", role: .destructive) {
                    store.deleteFinancialEvent(event)
                    dismiss()
                }
            }

            Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel", role: .cancel) { }
        } message: {
            Text(deleteDialogMessage)
        }
    }

    private var canMarkIncomeReceived: Bool {
        event.type == .income && event.status != .paid
    }

    private var linkedInstallmentPlan: InstallmentPlan? {
        guard let planID = event.sourceInstallmentPlanID else {
            return nil
        }

        return store.installmentPlans.first { $0.id == planID }
    }

    private var linkedRecurringSeries: FinancialEvent? {
        guard let seriesID = event.sourceRecurringEventID else {
            return nil
        }

        return store.activeFinancialEvents.first { $0.id == seriesID }
    }

    private var recurringIncomeSeries: FinancialEvent? {
        guard event.type == .income,
              event.status != .paid,
              event.sourceRecurringEventID != nil else {
            return nil
        }

        return linkedRecurringSeries
    }

    private var deleteDialogTitle: String {
        if recurringIncomeSeries != nil {
            return store.appLanguage == .arabicEgyptian ? "حذف دخل متكرر؟" : "Delete recurring income?"
        }

        return store.appLanguage == .arabicEgyptian ? "حذف المعاملة؟" : "Delete this transaction?"
    }

    private var deleteDialogMessage: String {
        if recurringIncomeSeries != nil {
            return store.appLanguage == .arabicEgyptian
                ? "هذا دخل متوقع من سلسلة متكررة. تخطي هذا الشهر لا يحذف الشهور القادمة."
                : "This is expected income from a recurring series. Skipping this month keeps future months."
        }

        return store.appLanguage == .arabicEgyptian ? "المعاملات المدفوعة هتعكس أثرها على رصيد الحساب قبل الحذف." : "Paid transactions will reverse their account balance impact before being removed."
    }

    private var amountDetailTitle: String {
        switch event.type {
        case .income:
            return store.appLanguage == .arabicEgyptian ? "فلوس داخلة" : "Money in"
        case .transfer:
            return store.appLanguage == .arabicEgyptian ? "المبلغ" : "Amount"
        case .expense, .obligation, .expectedExpense, .installment:
            return store.appLanguage == .arabicEgyptian ? "فلوس خارجة" : "Money out"
        }
    }

    private var canManageSeries: Bool {
        event.repeatRule != .none || linkedInstallmentPlan != nil || linkedRecurringSeries != nil
    }

    private var seriesSourceText: String {
        if linkedInstallmentPlan != nil {
            return store.appLanguage == .arabicEgyptian ? "البند ده جاي من خطة تقسيط." : "This item comes from an installment plan."
        }

        return store.appLanguage == .arabicEgyptian ? "البند ده جاي من قاعدة متكررة." : "This item comes from a recurring rule."
    }

    private func openSeriesSource() {
        if let linkedInstallmentPlan {
            selectedInstallmentPlan = linkedInstallmentPlan
        } else if event.repeatRule != .none || linkedRecurringSeries != nil {
            isManagingRecurringSeries = true
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func accountDetailRow(_ title: String, _ accountName: String?) -> some View {
        HStack(alignment: .center) {
            Text(title)
            Spacer()

            if let account = store.accounts.first(where: { $0.name == accountName }) {
                AccountIdentityLabel(account: account, markSize: 24)
            } else {
                Text(accountName ?? notSetText)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount, maximumFractionDigits: 2)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if store.appLanguage == .arabicEgyptian {
            formatter.locale = Locale(identifier: "ar_EG")
        }
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter.string(from: date)
    }

    private var notSetText: String {
        store.appLanguage == .arabicEgyptian ? "غير محدد" : "Not set"
    }
}

struct MarkIncomeReceivedView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let event: FinancialEvent

    @State private var receivedDate: Date = Date()
    @State private var selectedAccountName: String = ""
    @State private var amountText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(store.appLanguage == .arabicEgyptian ? "الدخل المستلم" : "Received Income") {
                    detailRow(store.appLanguage == .arabicEgyptian ? "العنوان" : "Title", event.title)

                    TextField(store.appLanguage == .arabicEgyptian ? "المبلغ" : "Amount", text: $amountText)
                        .keyboardType(.decimalPad)

                    DatePicker(
                        store.appLanguage == .arabicEgyptian ? "تم الدفع في" : "Paid at",
                        selection: $receivedDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section(store.appLanguage == .arabicEgyptian ? "الحساب" : "Account") {
                    AccountMenuPickerField(
                        title: store.appLanguage == .arabicEgyptian ? "الحساب" : "Account",
                        selection: $selectedAccountName,
                        accounts: store.accounts.filter { $0.isActive },
                        placeholder: store.appLanguage == .arabicEgyptian ? "اختر حساب" : "Select account",
                        emptyTitle: store.appLanguage == .arabicEgyptian ? "اختر حساب" : "Select account"
                    )

                    if selectedAccountName.isEmpty {
                        Text(store.appLanguage == .arabicEgyptian ? "اختر الحساب الذي استلم الفلوس." : "Choose the account that received the money.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        markReceived()
                    } label: {
                        HStack {
                            Spacer()
                            Text(store.appLanguage == .arabicEgyptian ? "تسجيل كـ مستلم" : "Mark Received")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                } footer: {
                    Text(store.appLanguage == .arabicEgyptian ? "سيتم تحويل الدخل المتوقع لنفس السجل إلى دخل فعلي مرة واحدة فقط." : "This converts the expected income record into actual received income once.")
                }
            }
            .navigationTitle(store.appLanguage == .arabicEgyptian ? "تسجيل الدخل" : "Mark Income Received")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupInitialValues()
            }
        }
    }

    private var amount: Double {
        parseAmountText(amountText)
    }

    private var canSave: Bool {
        amount > 0 && !selectedAccountName.isEmpty
    }

    private func setupInitialValues() {
        receivedDate = Date()
        selectedAccountName = event.accountName ?? store.accounts.first { $0.isActive }?.name ?? ""
        amountText = cleanNumberText(event.amount)
    }

    private func markReceived() {
        if let sourceID = event.sourceRecurringEventID,
           let series = store.financialEvents.first(where: { $0.id == sourceID }) {
            let didMarkReceived = store.markRecurringOccurrencePaid(
                series: series,
                occurrenceDate: event.date,
                amount: amount,
                accountName: selectedAccountName,
                paymentDate: receivedDate,
                paymentMethodName: event.paymentMethodName,
                categoryName: event.categoryName,
                subCategoryName: event.subCategoryName,
                note: event.note
            )

            if didMarkReceived {
                dismiss()
            }
            return
        }

        var updatedEvent = event
        updatedEvent.status = .paid
        updatedEvent.date = receivedDate
        updatedEvent.amount = amount
        updatedEvent.accountName = selectedAccountName

        store.updateFinancialEvent(originalEvent: event, updatedEvent: updatedEvent)
        dismiss()
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func cleanNumberText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(value)
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
}

struct TransactionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionDetailView(event: SampleWalletData.financialEvents[0])
            .environmentObject(WalletStore())
    }
}
