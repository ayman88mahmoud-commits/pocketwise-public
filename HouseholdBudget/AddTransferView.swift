import SwiftUI

struct AddTransferView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var fromAccountName = ""
    @State private var toAccountName = ""
    @State private var amountText = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var includesATMFee = false
    @State private var atmFeeAmountText = ""
    @State private var atmFeeTitle = "ATM Withdrawal Fee"

    private var activeAccounts: [Account] {
        store.accounts
            .filter { $0.isActive }
            .sorted { $0.name < $1.name }
    }

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(isArabic ? "تحويل" : "Transfer") {
                    AccountMenuPickerField(
                        title: isArabic ? "من حساب" : "From Account",
                        selection: $fromAccountName,
                        accounts: activeAccounts,
                        emptyTitle: isArabic ? "اختار حساب" : "Select account"
                    )
                    .pocketWiseInputField(semanticColor: .accounts)

                    if let fromAccount {
                        accountSummary(account: fromAccount)
                    }

                    Button {
                        swapAccounts()
                    } label: {
                        HStack {
                            Spacer()

                            Image(systemName: "arrow.up.arrow.down")
                                .font(.headline)

                            Text(isArabic ? "تبديل" : "Swap")
                                .fontWeight(.semibold)

                            Spacer()
                        }
                    }
                    .disabled(fromAccountName.isEmpty && toAccountName.isEmpty)

                    AccountMenuPickerField(
                        title: isArabic ? "إلى حساب" : "To Account",
                        selection: $toAccountName,
                        accounts: activeAccounts,
                        emptyTitle: isArabic ? "اختار حساب" : "Select account"
                    )
                    .pocketWiseInputField(semanticColor: .accounts)

                    if let toAccount {
                        accountSummary(account: toAccount)
                    }

                    TextField(isArabic ? "المبلغ" : "Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .accounts, isProminent: true)

                    DatePicker(
                        isArabic ? "التاريخ والوقت" : "Date & Time",
                        selection: $date,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .pocketWiseInputField(semanticColor: .obligations)
                }

                Section(isArabic ? "رسوم ماكينة ATM" : "ATM Fee") {
                    Toggle(isArabic ? "إضافة رسوم سحب ATM" : "Add ATM withdrawal fee", isOn: $includesATMFee)

                    if includesATMFee {
                        TextField(isArabic ? "عنوان الرسوم" : "Fee title", text: $atmFeeTitle)
                            .pocketWiseInputField(semanticColor: .spending)

                        TextField(isArabic ? "مبلغ الرسوم" : "Fee amount", text: $atmFeeAmountText)
                            .keyboardType(.decimalPad)
                            .pocketWiseInputField(semanticColor: .spending)

                        Text(isArabic ? "الرسوم هتتحفظ كمصروف مدفوع منفصل تحت مصاريف بنكية / رسوم سحب ATM." : "The fee is saved as a separate paid expense under Banking & Fees / ATM Withdrawal Fee.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if shouldShowPreview {
                    Section(isArabic ? "معاينة" : "Preview") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(directionText)
                                        .font(.headline)

                                    Text(formatCurrency(amount))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "arrow.right")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }

                            Divider()

                            if let fromAccount {
                                balancePreviewRow(
                                    title: isArabic ? "\(fromAccount.name) بعد التحويل" : "\(fromAccount.name) after",
                                    amount: sourceBalanceAfterTransfer,
                                    isWarning: sourceBalanceAfterTransfer < 0
                                )
                            }

                            if let toAccount {
                                balancePreviewRow(
                                    title: isArabic ? "\(toAccount.name) بعد التحويل" : "\(toAccount.name) after",
                                    amount: destinationBalanceAfterTransfer,
                                    isWarning: false
                                )
                            }

                            if includesATMFee {
                                balancePreviewRow(
                                    title: isArabic ? "رسوم ATM" : "ATM Fee",
                                    amount: atmFeeAmount,
                                    isWarning: false
                                )
                            }
                        }
                    }
                }

                Section(isArabic ? "ملاحظات" : "Note") {
                    TextField(isArabic ? "ملاحظة اختيارية" : "Optional note", text: $note)
                        .pocketWiseInputField(semanticColor: .neutral)
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
                        saveTransfer()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isArabic ? "حفظ التحويل" : "Save Transfer")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(isArabic ? "تحويل" : "Transfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isArabic ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var amount: Double {
        RecurringMonthlyAmountsSection.parseAmountText(amountText)
    }

    private var atmFeeAmount: Double {
        RecurringMonthlyAmountsSection.parseAmountText(atmFeeAmountText)
    }

    private var fromAccount: Account? {
        activeAccounts.first { $0.name == fromAccountName }
    }

    private var toAccount: Account? {
        activeAccounts.first { $0.name == toAccountName }
    }

    private var sourceBalanceAfterTransfer: Double {
        guard let fromAccount else {
            return 0
        }

        return fromAccount.balance - amount - effectiveATMFee
    }

    private var destinationBalanceAfterTransfer: Double {
        guard let toAccount else {
            return 0
        }

        return toAccount.balance + amount
    }

    private var effectiveATMFee: Double {
        includesATMFee ? atmFeeAmount : 0
    }

    private var shouldShowPreview: Bool {
        fromAccount != nil ||
        toAccount != nil ||
        amount > 0 ||
        includesATMFee
    }

    private var directionText: String {
        let from = fromAccountName.isEmpty ? (isArabic ? "من حساب" : "From account") : fromAccountName
        let to = toAccountName.isEmpty ? (isArabic ? "إلى حساب" : "To account") : toAccountName
        return "\(from) → \(to)"
    }

    private var validationMessages: [String] {
        var messages: [String] = []

        if fromAccountName.isEmpty {
            messages.append(isArabic ? "اختار الحساب اللي هتحول منه." : "Select the account to transfer from.")
        }

        if toAccountName.isEmpty {
            messages.append(isArabic ? "اختار الحساب اللي هتحول له." : "Select the account to transfer to.")
        }

        if !fromAccountName.isEmpty && fromAccountName == toAccountName {
            messages.append(isArabic ? "حساب التحويل منه وإليه ما ينفعش يكونوا نفس الحساب." : "From and To accounts cannot be the same.")
        }

        if !fromAccountName.isEmpty &&
            !activeAccounts.contains(where: { $0.name == fromAccountName }) {
            messages.append(isArabic ? "اختار حساب مصدر نشط." : "Select an active source account.")
        }

        if !toAccountName.isEmpty &&
            !activeAccounts.contains(where: { $0.name == toAccountName }) {
            messages.append(isArabic ? "اختار حساب وجهة نشط." : "Select an active destination account.")
        }

        if amount <= 0 {
            messages.append(isArabic ? "دخل مبلغ أكبر من صفر." : "Enter an amount greater than zero.")
        }

        if includesATMFee {
            if atmFeeAmount <= 0 {
                messages.append(isArabic ? "دخل رسوم ATM أكبر من صفر." : "Enter an ATM fee greater than zero.")
            }

            if atmFeeTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages.append(isArabic ? "دخل عنوان الرسوم." : "Enter a fee title.")
            }
        } else if !atmFeeAmountText.isEmpty && atmFeeAmount < 0 {
            messages.append(isArabic ? "رسوم ATM لازم تكون صفر أو أكتر." : "ATM fee must be zero or greater.")
        }

        if fromAccount != nil,
           amount > 0,
           sourceBalanceAfterTransfer < 0 {
            messages.append(isArabic ? "الرصيد في حساب المصدر غير كافي." : "Insufficient balance in selected source account.")
        }

        return messages
    }

    private var canSave: Bool {
        validationMessages.isEmpty
    }

    private func saveTransfer() {
        guard canSave else {
            return
        }

        store.addTransfer(
            amount: amount,
            date: date,
            fromAccountName: fromAccountName,
            toAccountName: toAccountName,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
            atmFeeAmount: includesATMFee ? atmFeeAmount : 0,
            atmFeeTitle: atmFeeTitle
        )

        dismiss()
    }

    private func swapAccounts() {
        let oldFrom = fromAccountName
        fromAccountName = toAccountName
        toAccountName = oldFrom
    }

    private func accountSummary(account: Account) -> some View {
        HStack(spacing: 10) {
            AccountVisualMark(account: account, size: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(accountTypeLabel(account.type)) - \(isArabic ? "الرصيد" : "Balance"): \(formatCurrency(account.balance))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func balancePreviewRow(title: String, amount: Double, isWarning: Bool) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)

            Spacer()

            Text(formatCurrency(amount))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isWarning ? .red : .primary)
        }
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
    }

    private func accountTypeLabel(_ accountType: AccountType) -> String {
        guard isArabic else {
            return accountType.rawValue
        }

        switch accountType {
        case .cash:
            return "كاش"
        case .bank:
            return "بنك"
        case .wallet:
            return "محفظة"
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2

        let number = NSNumber(value: amount)
        let formatted = formatter.string(from: number) ?? "\(amount)"

        return "\(formatted) EGP"
    }
}

struct AddTransferView_Previews: PreviewProvider {
    static var previews: some View {
        AddTransferView()
            .environmentObject(WalletStore())
    }
}
