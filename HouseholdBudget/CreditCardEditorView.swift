import SwiftUI

struct CreditCardEditorView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let card: CreditCard?

    @State private var name = ""
    @State private var bankName = ""
    @State private var lastFourDigits = ""
    @State private var cardNetwork: CreditCardNetwork = .other
    @State private var appearanceColor: ProviderAppearanceColor?
    @State private var creditLimitText = ""
    @State private var openingOutstandingText = ""
    @State private var openingOutstandingDate = Date()
    @State private var statementClosingDayText = "1"
    @State private var paymentDueDayText = "1"
    @State private var defaultPaymentAccountName = ""
    @State private var isActive = true
    @State private var note = ""

    init(card: CreditCard? = nil) {
        self.card = card
    }

    private var isEditing: Bool {
        card != nil
    }

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var creditLimit: Double? {
        parseAmount(creditLimitText)
    }

    private var openingOutstandingBalance: Double? {
        let trimmedText = openingOutstandingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return 0
        }

        return parseAmount(trimmedText)
    }

    private var statementClosingDay: Int? {
        Int(statementClosingDayText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var paymentDueDay: Int? {
        Int(paymentDueDayText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var accountsForPayment: [Account] {
        var accounts = store.activeAccounts.filter { $0.isActive }

        if let inactiveAccount = store.accounts.first(where: { $0.name == defaultPaymentAccountName && !$0.isActive }),
           !accounts.contains(where: { $0.id == inactiveAccount.id }) {
            accounts.append(inactiveAccount)
        }

        return accounts.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var validationMessages: [String] {
        var messages: [String] = []

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append(isArabic ? "الاسم مطلوب." : "Name is required.")
        }

        if creditLimit == nil {
            messages.append(isArabic ? "دخل حد ائتماني صحيح." : "Enter a valid credit limit.")
        } else if (creditLimit ?? 0) < 0 {
            messages.append(isArabic ? "الحد الائتماني لازم يكون صفر أو أكتر." : "Credit limit must be zero or positive.")
        }

        if openingOutstandingBalance == nil {
            messages.append(isArabic ? "دخل رصيد مستحق حالي صحيح." : "Enter a valid current outstanding balance.")
        } else if (openingOutstandingBalance ?? 0) < 0 {
            messages.append(isArabic ? "الرصيد المستحق الحالي لازم يكون صفر أو أكتر." : "Current outstanding balance must be zero or positive.")
        }

        if let statementClosingDay {
            if !(1...31).contains(statementClosingDay) {
                messages.append(isArabic ? "يوم قفل كشف الحساب لازم يكون من ١ إلى ٣١." : "Statement closing day must be from 1 to 31.")
            }
        } else {
            messages.append(isArabic ? "دخل يوم قفل كشف حساب صحيح." : "Enter a valid statement closing day.")
        }

        if let paymentDueDay {
            if !(1...31).contains(paymentDueDay) {
                messages.append(isArabic ? "يوم استحقاق السداد لازم يكون من ١ إلى ٣١." : "Payment due day must be from 1 to 31.")
            }
        } else {
            messages.append(isArabic ? "دخل يوم استحقاق سداد صحيح." : "Enter a valid payment due day.")
        }

        let cleanLastFour = lastFourDigits.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanLastFour.isEmpty &&
            (cleanLastFour.count != 4 || !cleanLastFour.allSatisfy(\.isNumber)) {
            messages.append(isArabic ? "آخر ٤ أرقام لازم تكون ٤ أرقام بالضبط أو فاضية." : "Last 4 digits must be exactly 4 digits or empty.")
        }

        return messages
    }

    private var canSave: Bool {
        validationMessages.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(isArabic ? "الكارت" : "Card") {
                    TextField(isArabic ? "اسم الكارت" : "Card name", text: $name)
                        .pocketWiseInputField(semanticColor: .creditCards)

                    TextField(isArabic ? "البنك / المزود" : "Bank / provider", text: $bankName)
                        .pocketWiseInputField(semanticColor: .creditCards)

                    TextField(isArabic ? "آخر ٤ أرقام" : "Last 4 digits", text: $lastFourDigits)
                        .keyboardType(.numberPad)
                        .pocketWiseInputField(semanticColor: .creditCards)
                        .onChange(of: lastFourDigits) { _, newValue in
                            lastFourDigits = String(newValue.filter(\.isNumber).prefix(4))
                        }

                    Text(isArabic ? "بيستخدم لمطابقة إشعارات البنك. ما تدخلش رقم الحساب أو الكارت كامل." : "Used to match bank notification messages. Do not enter full account/card number.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Picker(isArabic ? "الشبكة" : "Network", selection: $cardNetwork) {
                        ForEach(CreditCardNetwork.allCases) { network in
                            Text(network.rawValue)
                                .tag(network)
                        }
                    }
                    .pocketWiseInputField(semanticColor: .creditCards)

                    Text(isArabic ? "الشبكة محفوظة كنص فقط. WalletBoard بيستخدم أيقونة كارت عامة بدل شعارات الشبكات الرسمية." : "Network is stored as text only. WalletBoard uses a generic card icon instead of official card-network logos.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(isArabic ? "الشكل" : "Appearance") {
                    HStack(spacing: 12) {
                        CreditCardVisualMark(
                            card: CreditCard(
                                name: name.isEmpty ? (isArabic ? "كارت ائتمان" : "Credit Card") : name,
                                bankName: bankName,
                                cardNetwork: cardNetwork,
                                appearanceColor: appearanceColor ?? .purple,
                                creditLimit: 0,
                                statementClosingDay: 1,
                                paymentDueDay: 1
                            ),
                            size: 38
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(isArabic ? "علامة كارت عامة" : "Generic card badge")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(isArabic ? "بيستخدم أيقونة ولون آمنين بدل شعارات المزودين الرسمية." : "Uses a safe icon and color instead of official provider logos.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ProviderAppearanceColorPicker(
                        title: isArabic ? "اللون" : "Color",
                        selection: $appearanceColor,
                        defaultColor: .purple
                    )
                }

                Section(isArabic ? "الشروط" : "Terms") {
                    TextField(isArabic ? "الحد الائتماني" : "Credit limit", text: $creditLimitText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .creditCards, isProminent: true)

                    TextField(isArabic ? "الرصيد المستحق الحالي" : "Current outstanding balance", text: $openingOutstandingText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .creditCards, isProminent: true)

                    if (openingOutstandingBalance ?? 0) > 0 {
                        DatePicker(
                            isArabic ? "المستحق حتى" : "Outstanding as of",
                            selection: $openingOutstandingDate,
                            displayedComponents: .date
                        )
                        .pocketWiseInputField(semanticColor: .obligations)
                    }

                    Text(store.appLanguage == .arabicEgyptian ? "استخدمه فقط للمبلغ المستحق على الكارت قبل ما تبدأ تسجيله هنا. ده يؤثر على السيولة، وليس على تقارير المصروفات." : "Use this only for the amount already owed on this card before you started tracking it here. It affects card due planning, not spending reports.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextField(isArabic ? "يوم قفل كشف الحساب" : "Statement closing day", text: $statementClosingDayText)
                        .keyboardType(.numberPad)
                        .pocketWiseInputField(semanticColor: .obligations)
                        .onChange(of: statementClosingDayText) { _, newValue in
                            statementClosingDayText = String(newValue.filter(\.isNumber).prefix(2))
                        }

                    TextField(isArabic ? "يوم استحقاق السداد" : "Payment due day", text: $paymentDueDayText)
                        .keyboardType(.numberPad)
                        .pocketWiseInputField(semanticColor: .obligations)
                        .onChange(of: paymentDueDayText) { _, newValue in
                            paymentDueDayText = String(newValue.filter(\.isNumber).prefix(2))
                        }
                }

                Section(isArabic ? "حساب السداد الافتراضي" : "Default Payment Account") {
                    AccountMenuPickerField(
                        title: isArabic ? "الحساب" : "Account",
                        selection: $defaultPaymentAccountName,
                        accounts: accountsForPayment,
                        placeholder: isArabic ? "مفيش حساب افتراضي" : "No default account",
                        emptyTitle: isArabic ? "مفيش حساب افتراضي" : "No default account",
                        inactiveSubtitle: true
                    )
                    .pocketWiseInputField(semanticColor: .accounts)

                    Text(isArabic ? "السداد بيتسجل من شاشة كروت الائتمان. الاختيار ده بيحدد حساب السداد مسبقًا فقط." : "Payments are recorded from the Credit Cards screen. This default only preselects the payment account.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if isEditing {
                    Section(isArabic ? "الحالة" : "Status") {
                        Toggle(isArabic ? "نشط" : "Active", isOn: $isActive)
                    }
                }

                Section(isArabic ? "ملاحظات" : "Note") {
                    TextField(isArabic ? "ملاحظة اختيارية" : "Optional note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .pocketWiseInputField(semanticColor: .neutral)
                }

                Section {
                    if !validationMessages.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(validationMessages, id: \.self) { message in
                                Text(message)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    Button {
                        saveCard()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isEditing ? (isArabic ? "حفظ التعديلات" : "Save Changes") : (isArabic ? "أضف كارت" : "Add Card"))
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(isEditing ? (isArabic ? "تعديل كارت" : "Edit Card") : (isArabic ? "أضف كارت" : "Add Card"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isArabic ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupInitialValues()
            }
        }
    }

    private func setupInitialValues() {
        guard let card else {
            return
        }

        name = card.name
        bankName = card.bankName
        lastFourDigits = card.lastFourDigits ?? ""
        cardNetwork = card.cardNetwork
        appearanceColor = card.appearanceColor
        creditLimitText = cleanNumberText(card.creditLimit)
        openingOutstandingText = card.openingOutstandingBalance > 0 ? cleanNumberText(card.openingOutstandingBalance) : ""
        openingOutstandingDate = card.openingOutstandingDate ?? card.createdAt
        statementClosingDayText = "\(card.statementClosingDay)"
        paymentDueDayText = "\(card.paymentDueDay)"
        defaultPaymentAccountName = card.defaultPaymentAccountName ?? ""
        isActive = card.isActive
        note = card.note ?? ""
    }

    private func saveCard() {
        guard let creditLimit,
              let openingOutstandingBalance,
              let statementClosingDay,
              let paymentDueDay else {
            return
        }

        if var card {
            card.name = name
            card.bankName = bankName
            card.lastFourDigits = lastFourDigits.isEmpty ? nil : lastFourDigits
            card.cardNetwork = cardNetwork
            card.appearanceColor = appearanceColor ?? .purple
            card.creditLimit = creditLimit
            card.openingOutstandingBalance = openingOutstandingBalance
            card.openingOutstandingDate = openingOutstandingBalance > 0 ? openingOutstandingDate : nil
            card.statementClosingDay = statementClosingDay
            card.paymentDueDay = paymentDueDay
            card.defaultPaymentAccountName = defaultPaymentAccountName.isEmpty ? nil : defaultPaymentAccountName
            card.isActive = isActive
            card.note = note.isEmpty ? nil : note
            store.updateCreditCard(card)
        } else {
            store.addCreditCard(
                name: name,
                bankName: bankName,
                lastFourDigits: lastFourDigits.isEmpty ? nil : lastFourDigits,
                cardNetwork: cardNetwork,
                appearanceColor: appearanceColor ?? .purple,
                creditLimit: creditLimit,
                openingOutstandingBalance: openingOutstandingBalance,
                openingOutstandingDate: openingOutstandingBalance > 0 ? openingOutstandingDate : nil,
                statementClosingDay: statementClosingDay,
                paymentDueDay: paymentDueDay,
                defaultPaymentAccountName: defaultPaymentAccountName.isEmpty ? nil : defaultPaymentAccountName,
                note: note.isEmpty ? nil : note
            )
        }

        dismiss()
    }

    private func parseAmount(_ value: String) -> Double? {
        let cleanValue = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !cleanValue.isEmpty else {
            return nil
        }

        return Double(cleanValue)
    }

    private func cleanNumberText(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return "\(amount)"
    }
}
