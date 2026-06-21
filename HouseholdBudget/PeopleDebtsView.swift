import SwiftUI

struct PeopleDebtsView: View {

    @EnvironmentObject private var store: WalletStore

    @State private var addDebtKind: PersonDebtKind?

    private var isAr: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var visibleDebts: [PersonDebt] {
        store.personDebts
            .filter { !$0.isArchived }
            .sorted {
                if store.remainingAmount(for: $0) == store.remainingAmount(for: $1) {
                    return $0.updatedAt > $1.updatedAt
                }

                return store.remainingAmount(for: $0) > store.remainingAmount(for: $1)
            }
    }

    var body: some View {
        List {
            Section {
                debtSummaryCards
            }

            Section {
                Label {
                    Text(isAr ? "الأشخاص والديون منفصلين عن الميزانية الشهرية والتقارير. السلف والاقتراض والسداد ممكن يحرّكوا أرصدة الحسابات، بس مش بيتحسبوا كمصاريف شهرية." : "People / Debts is separate from monthly budget and transaction reports. Lending, borrowing, and repayments can move account balances, but they are not counted as monthly spending.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "info.circle")
                }
            }

            Section {
                Button {
                    addDebtKind = .owedToMe
                } label: {
                    actionRow(title: isAr ? "أنا سلّفت فلوس" : "I Lent Money", subtitle: isAr ? "حد عليه فلوس ليا" : "Someone owes me", icon: "arrow.up.forward.circle.fill")
                }
                .buttonStyle(.plain)

                Button {
                    addDebtKind = .iOwe
                } label: {
                    actionRow(title: isAr ? "أنا استلفت فلوس" : "I Borrowed Money", subtitle: isAr ? "عليا فلوس لحد" : "I owe someone", icon: "arrow.down.forward.circle.fill")
                }
                .buttonStyle(.plain)
            }

            Section(isAr ? "الأشخاص" : "People") {
                if visibleDebts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isAr ? "لسه مفيش ديون أشخاص" : "No people debts yet")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text(isAr ? "تابع السلف والاقتراض والسداد هنا من غير ما يتحسبوا كمصاريف أو دخل." : "Track lending, borrowing, and repayments here without counting them as expenses or income.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(visibleDebts) { debt in
                        NavigationLink {
                            PersonDebtDetailView(debt: debt)
                        } label: {
                            PersonDebtRow(debt: debt)
                                .environmentObject(store)
                        }
                    }
                }
            }
        }
        .navigationTitle(isAr ? "الأشخاص والديون" : "People / Debts")
        .sheet(item: $addDebtKind) { kind in
            AddPersonDebtView(kind: kind)
                .environmentObject(store)
        }
    }

    private var debtSummaryCards: some View {
        VStack(spacing: 12) {
            summaryRow(title: isAr ? "ليا عند الناس" : "Owed to Me", value: store.totalOwedToMe, color: .green)
            summaryRow(title: isAr ? "عليا للناس" : "I Owe", value: store.totalIOwe, color: .orange)

            Divider()

            summaryRow(
                title: isAr ? "الصافي" : "Net Position",
                value: abs(store.netPeopleDebtPosition),
                color: store.netPeopleDebtPosition >= 0 ? .green : .red,
                prefix: store.netPeopleDebtPosition >= 0 ? "+" : "-"
            )
        }
        .padding(.vertical, 4)
    }

    private func summaryRow(title: String, value: Double, color: Color, prefix: String = "") -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(store.signedDisplayCurrency(value, prefix: prefix))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }

    private func actionRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 38, height: 38)
                .foregroundStyle(.blue)
                .background(Color.blue.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount)
    }
}

struct PersonDebtRow: View {

    @EnvironmentObject private var store: WalletStore

    let debt: PersonDebt

    private var remainingAmount: Double {
        store.remainingAmount(for: debt)
    }

    private var status: PersonDebtStatus {
        store.status(for: debt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(debt.personName)
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(kindLabel(debt.kind))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(statusLabel(status))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }

            HStack {
                Text("\(store.appLanguage == .arabicEgyptian ? "الأصل" : "Original"): \(formatCurrency(debt.originalAmount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(store.appLanguage == .arabicEgyptian ? "المتبقي" : "Remaining"): \(formatCurrency(remainingAmount))")
                    .font(.caption)
                    .fontWeight(.semibold)
            }

            if let dueDate = debt.dueDate {
                Text(dueStatusText(for: dueDate))
                    .font(.caption2)
                    .foregroundStyle(isOverdue(dueDate) && remainingAmount > 0 ? .red : .secondary)
            }

            if let note = debt.note,
               !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch status {
        case .open:
            return .orange
        case .partiallyPaid:
            return .blue
        case .settled:
            return .green
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if store.appLanguage == .arabicEgyptian {
            formatter.locale = Locale(identifier: "ar_EG")
        }
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private func dueStatusText(for date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())

        if remainingAmount > 0 && day < today {
            return store.appLanguage == .arabicEgyptian ? "متأخر" : "Overdue"
        }

        if day == today {
            return store.appLanguage == .arabicEgyptian ? "مستحق اليوم" : "Due today"
        }

        if store.appLanguage == .arabicEgyptian {
            return "مستحق في \(formatDate(date))"
        }

        return "Due on \(formatDate(date))"
    }

    private func kindLabel(_ kind: PersonDebtKind) -> String {
        guard store.appLanguage == .arabicEgyptian else {
            return kind.rawValue
        }

        switch kind {
        case .owedToMe:
            return "ليا عنده"
        case .iOwe:
            return "عليا ليه"
        }
    }

    private func statusLabel(_ status: PersonDebtStatus) -> String {
        guard store.appLanguage == .arabicEgyptian else {
            return status.rawValue
        }

        switch status {
        case .open:
            return "مفتوح"
        case .partiallyPaid:
            return "مدفوع جزئيًا"
        case .settled:
            return "متسدد"
        }
    }

    private func isOverdue(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }
}

struct AddPersonDebtView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let kind: PersonDebtKind

    @State private var personName = ""
    @State private var amountText = ""
    @State private var selectedAccountName = ""
    @State private var date = Date()
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var note = ""
    @State private var didAttemptSave = false

    private var activeAccounts: [Account] {
        store.accounts
            .filter { $0.isActive }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var amount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var selectedAccount: Account? {
        store.accounts.first { $0.name == selectedAccountName }
    }

    private var isAr: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var validationMessages: [String] {
        var messages: [String] = []

        if personName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append(isAr ? "دخل اسم الشخص." : "Enter a person name.")
        }

        if amount <= 0 {
            messages.append(isAr ? "دخل مبلغ أكبر من صفر." : "Enter an amount greater than zero.")
        }

        if selectedAccountName.isEmpty || selectedAccount == nil {
            messages.append(isAr ? "اختار الحساب المستخدم." : "Select the account to use.")
        }

        if kind == .owedToMe,
           let selectedAccount,
           amount > selectedAccount.balance {
            messages.append(isAr ? "الرصيد في الحساب المختار غير كافي." : "Insufficient balance in selected account.")
        }

        return messages
    }

    private var canSave: Bool {
        validationMessages.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(kind == .owedToMe ? (isAr ? "أنا سلّفت فلوس" : "I Lent Money") : (isAr ? "أنا استلفت فلوس" : "I Borrowed Money")) {
                    TextField(isAr ? "اسم الشخص" : "Person name", text: $personName)
                    TextField(isAr ? "المبلغ" : "Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                    DatePicker(isAr ? "التاريخ" : "Date", selection: $date, displayedComponents: .date)

                    Toggle(isAr ? "إضافة تاريخ استحقاق" : "Add Due Date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker(isAr ? "تاريخ الاستحقاق" : "Due Date", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section(isAr ? "الحساب" : "Account") {
                    AccountMenuPickerField(
                        title: isAr ? "الحساب" : "Account",
                        selection: $selectedAccountName,
                        accounts: activeAccounts,
                        emptyTitle: isAr ? "اختار الحساب" : "Select Account"
                    )
                }

                Section(isAr ? "ملاحظات" : "Note") {
                    TextField(isAr ? "ملاحظة اختيارية" : "Optional note", text: $note, axis: .vertical)
                }

                if didAttemptSave && !validationMessages.isEmpty {
                    Section {
                        ForEach(validationMessages, id: \.self) { message in
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(kind == .owedToMe ? (isAr ? "أنا سلّفت فلوس" : "I Lent Money") : (isAr ? "أنا استلفت فلوس" : "I Borrowed Money"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isAr ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isAr ? "حفظ" : "Save") {
                        save()
                    }
                    .disabled(!canSave && didAttemptSave)
                }
            }
            .onAppear {
                if selectedAccountName.isEmpty {
                    selectedAccountName = activeAccounts.first?.name ?? ""
                }
            }
        }
    }

    private func save() {
        didAttemptSave = true
        guard canSave else {
            return
        }

        let saved = store.addPersonDebt(
            kind: kind,
            personName: personName,
            amount: amount,
            accountName: selectedAccountName,
            date: date,
            dueDate: hasDueDate ? dueDate : nil,
            note: note
        )

        if saved {
            dismiss()
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount)
    }
}

struct PersonDebtDetailView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let debt: PersonDebt

    @State private var isAddingRepayment = false
    @State private var isConfirmingDelete = false

    private var currentDebt: PersonDebt {
        store.personDebts.first { $0.id == debt.id } ?? debt
    }

    private var entries: [PersonDebtEntry] {
        store.entries(for: currentDebt)
    }

    private var remainingAmount: Double {
        store.remainingAmount(for: currentDebt)
    }

    private var repaidAmount: Double {
        store.repaidAmount(for: currentDebt)
    }

    private var status: PersonDebtStatus {
        store.status(for: currentDebt)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentDebt.personName)
                                .font(.title3)
                                .fontWeight(.bold)

                            Text(kindLabel(currentDebt.kind))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(statusLabel(status))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(statusColor.opacity(0.12))
                            .foregroundStyle(statusColor)
                            .clipShape(Capsule())
                    }

                    summaryRow(store.appLanguage == .arabicEgyptian ? "الأصل" : "Original", currentDebt.originalAmount)
                    summaryRow(store.appLanguage == .arabicEgyptian ? "المسدّد" : "Repaid", repaidAmount)
                    summaryRow(store.appLanguage == .arabicEgyptian ? "المتبقي" : "Remaining", remainingAmount)

                    if let dueDate = currentDebt.dueDate {
                        Text(dueStatusText(for: dueDate))
                            .font(.caption)
                            .foregroundStyle(isOverdue(dueDate) && remainingAmount > 0 ? .red : .secondary)
                    }

                    if let note = currentDebt.note,
                       !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if remainingAmount > 0 {
                Section {
                    Button(currentDebt.kind == .owedToMe ? (store.appLanguage == .arabicEgyptian ? "تسجيل سداد مستلم" : "Record Repayment Received") : (store.appLanguage == .arabicEgyptian ? "تسجيل سداد مدفوع" : "Record Repayment Paid")) {
                        isAddingRepayment = true
                    }
                }
            }

            Section(store.appLanguage == .arabicEgyptian ? "سجل الحركات" : "Movement History") {
                ForEach(entries) { entry in
                    DebtEntryRow(entry: entry)
                }
            }

            Section {
                Button(store.appLanguage == .arabicEgyptian ? "حذف الدين" : "Delete Debt", role: .destructive) {
                    isConfirmingDelete = true
                }
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "تفاصيل الدين" : "Debt Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddingRepayment) {
            AddDebtRepaymentView(debt: currentDebt)
                .environmentObject(store)
        }
        .confirmationDialog(
            store.appLanguage == .arabicEgyptian ? "تحذف الدين ده؟" : "Delete this debt?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(store.appLanguage == .arabicEgyptian ? "حذف الدين" : "Delete Debt", role: .destructive) {
                if store.deletePersonDebt(currentDebt) {
                    dismiss()
                }
            }

            Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel", role: .cancel) { }
        } message: {
            Text(store.appLanguage == .arabicEgyptian ? "حذف هذا الدين سيعكس الحركات المرتبطة بالحساب وقد يغير الأرصدة السابقة. الأرشفة أكثر أمانًا." : "Deleting this debt will reverse its linked account movements and may change historical balances. Archiving is safer.")
        }
    }

    private var statusColor: Color {
        switch status {
        case .open:
            return .orange
        case .partiallyPaid:
            return .blue
        case .settled:
            return .green
        }
    }

    private func summaryRow(_ title: String, _ amount: Double) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(formatCurrency(amount))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
        return "\(formatted) EGP"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if store.appLanguage == .arabicEgyptian {
            formatter.locale = Locale(identifier: "ar_EG")
        }
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private func dueStatusText(for date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())

        if remainingAmount > 0 && day < today {
            return store.appLanguage == .arabicEgyptian ? "متأخر" : "Overdue"
        }

        if day == today {
            return store.appLanguage == .arabicEgyptian ? "مستحق اليوم" : "Due today"
        }

        if store.appLanguage == .arabicEgyptian {
            return "مستحق في \(formatDate(date))"
        }

        return "Due on \(formatDate(date))"
    }

    private func kindLabel(_ kind: PersonDebtKind) -> String {
        guard store.appLanguage == .arabicEgyptian else {
            return kind.rawValue
        }

        switch kind {
        case .owedToMe:
            return "ليا عنده"
        case .iOwe:
            return "عليا ليه"
        }
    }

    private func statusLabel(_ status: PersonDebtStatus) -> String {
        guard store.appLanguage == .arabicEgyptian else {
            return status.rawValue
        }

        switch status {
        case .open:
            return "مفتوح"
        case .partiallyPaid:
            return "مدفوع جزئيًا"
        case .settled:
            return "متسدد"
        }
    }

    private func isOverdue(_ date: Date) -> Bool {
        Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
    }
}

struct DebtEntryRow: View {

    @EnvironmentObject private var store: WalletStore

    let entry: PersonDebtEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.headline)
                .frame(width: 34, height: 34)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(entryTypeLabel(entry.entryType))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(entry.accountName) - \(formatDate(entry.date))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let note = entry.note,
                   !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(formatCurrency(entry.amount))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch entry.entryType {
        case .initialLending, .repaymentPaid:
            return "arrow.up.circle.fill"
        case .initialBorrowing, .repaymentReceived:
            return "arrow.down.circle.fill"
        }
    }

    private func entryTypeLabel(_ type: PersonDebtEntryType) -> String {
        guard store.appLanguage == .arabicEgyptian else {
            return type.rawValue
        }

        switch type {
        case .initialLending:
            return "سلفة مبدئية"
        case .initialBorrowing:
            return "اقتراض مبدئي"
        case .repaymentReceived:
            return "سداد مستلم"
        case .repaymentPaid:
            return "سداد مدفوع"
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if store.appLanguage == .arabicEgyptian {
            formatter.locale = Locale(identifier: "ar_EG")
        }
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

struct AddDebtRepaymentView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let debt: PersonDebt

    @State private var amountText = ""
    @State private var selectedAccountName = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var didAttemptSave = false

    private var currentDebt: PersonDebt {
        store.personDebts.first { $0.id == debt.id } ?? debt
    }

    private var activeAccounts: [Account] {
        store.accounts
            .filter { $0.isActive }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var amount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var selectedAccount: Account? {
        store.accounts.first { $0.name == selectedAccountName }
    }

    private var remainingAmount: Double {
        store.remainingAmount(for: currentDebt)
    }

    private var isAr: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var validationMessages: [String] {
        var messages: [String] = []

        if amount <= 0 {
            messages.append(isAr ? "دخل مبلغ أكبر من صفر." : "Enter an amount greater than zero.")
        }

        if amount > remainingAmount {
            messages.append(isAr ? "السداد ما ينفعش يزيد عن المتبقي." : "Repayment cannot exceed the remaining balance.")
        }

        if selectedAccountName.isEmpty || selectedAccount == nil {
            messages.append(isAr ? "اختار الحساب المستخدم." : "Select the account to use.")
        }

        if currentDebt.kind == .iOwe,
           let selectedAccount,
           amount > selectedAccount.balance {
            messages.append(isAr ? "الرصيد في الحساب المختار غير كافي." : "Insufficient balance in selected account.")
        }

        return messages
    }

    private var canSave: Bool {
        validationMessages.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(currentDebt.kind == .owedToMe ? (isAr ? "سداد مستلم" : "Repayment Received") : (isAr ? "سداد مدفوع" : "Repayment Paid")) {
                    Text("\(isAr ? "المتبقي" : "Remaining"): \(formatCurrency(remainingAmount))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField(isAr ? "المبلغ" : "Amount", text: $amountText)
                        .keyboardType(.decimalPad)

                    DatePicker(isAr ? "التاريخ" : "Date", selection: $date, displayedComponents: .date)
                }

                Section(isAr ? "الحساب" : "Account") {
                    AccountMenuPickerField(
                        title: isAr ? "الحساب" : "Account",
                        selection: $selectedAccountName,
                        accounts: activeAccounts,
                        emptyTitle: isAr ? "اختار الحساب" : "Select Account"
                    )
                }

                Section(isAr ? "ملاحظات" : "Note") {
                    TextField(isAr ? "ملاحظة اختيارية" : "Optional note", text: $note, axis: .vertical)
                }

                if didAttemptSave && !validationMessages.isEmpty {
                    Section {
                        ForEach(validationMessages, id: \.self) { message in
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(currentDebt.kind == .owedToMe ? (isAr ? "سداد مستلم" : "Repayment Received") : (isAr ? "سداد مدفوع" : "Repayment Paid"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isAr ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isAr ? "حفظ" : "Save") {
                        save()
                    }
                    .disabled(!canSave && didAttemptSave)
                }
            }
            .onAppear {
                if selectedAccountName.isEmpty {
                    selectedAccountName = activeAccounts.first?.name ?? ""
                }
            }
        }
    }

    private func save() {
        didAttemptSave = true
        guard canSave else {
            return
        }

        let saved = store.recordDebtRepayment(
            for: currentDebt,
            amount: amount,
            accountName: selectedAccountName,
            date: date,
            note: note
        )

        if saved {
            dismiss()
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
        return "\(formatted) EGP"
    }
}

struct PeopleDebtsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PeopleDebtsView()
                .environmentObject(WalletStore())
        }
    }
}
