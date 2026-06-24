import SwiftUI

struct CreditCardPaymentRoute: Identifiable {
    enum Source {
        case general
        case due
    }

    let id = UUID()
    let card: CreditCard
    let prefilledAmount: Double?
    let maximumPaymentAmount: Double?
    let source: Source

    init(
        card: CreditCard,
        prefilledAmount: Double? = nil,
        maximumPaymentAmount: Double? = nil,
        source: Source = .general
    ) {
        self.card = card
        self.prefilledAmount = prefilledAmount
        self.maximumPaymentAmount = maximumPaymentAmount
        self.source = source
    }
}

struct CreditCardsView: View {

    @EnvironmentObject private var store: WalletStore

    @State private var isAddingCard = false
    @State private var selectedCard: CreditCard?
    @State private var paymentRoute: CreditCardPaymentRoute?
    @State private var ledgerCard: CreditCard?

    @State private var swipeHintOffset: CGFloat = 0
    @State private var swipeHintVisible = false
    @State private var swipeHintHasRun = false

    private var activeCards: [CreditCard] {
        store.activeCreditCards
    }

    private var inactiveCards: [CreditCard] {
        store.creditCards
            .filter { !$0.isActive && !$0.isDeleted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.appLanguage == .arabicEgyptian ? "الكروت هنا للإعداد والمتابعة." : "Cards here are for setup and tracking.")
                        .font(.headline)

                    Text(store.appLanguage == .arabicEgyptian ? "مشتريات الكارت تتسجل من إضافة مصروف. السداد يخصم من الحساب المختار ولا يتحسب كمصروف جديد." : "Card purchases are recorded from Add Expense. Payments deduct the selected account and are not counted as new expenses.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if !activeCards.isEmpty {
                Section {
                    Button {
                        if let card = activeCards.first {
                            paymentRoute = CreditCardPaymentRoute(card: card)
                        }
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "سداد كارت" : "Pay Card", systemImage: "creditcard.and.123")
                            .fontWeight(.semibold)
                    }
                }
            }

            cardSection(title: store.appLanguage == .arabicEgyptian ? "نشطة" : "Active Cards", cards: activeCards)

            if !inactiveCards.isEmpty {
                cardSection(title: store.appLanguage == .arabicEgyptian ? "غير نشطة" : "Inactive Cards", cards: inactiveCards)
            }
        }
        .accessibilityIdentifier("screen.creditCards")
        .onAppear {
            guard !swipeHintHasRun, !activeCards.isEmpty else { return }
            swipeHintHasRun = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.25)) {
                    swipeHintOffset = -20
                    swipeHintVisible = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        swipeHintOffset = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            swipeHintVisible = false
                        }
                    }
                }
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "كروت الائتمان" : "Credit Cards")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingCard = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(store.appLanguage == .arabicEgyptian ? "أضف كارت" : "Add Card")
            }
        }
        .sheet(isPresented: $isAddingCard) {
            CreditCardEditorView()
                .environmentObject(store)
        }
        .sheet(item: $selectedCard) { card in
            CreditCardEditorView(card: card)
                .environmentObject(store)
        }
        .sheet(item: $paymentRoute) { route in
            CreditCardPaymentView(route: route)
                .environmentObject(store)
        }
        .sheet(item: $ledgerCard) { card in
            CreditCardStatementLedgerView(card: card)
                .environmentObject(store)
        }
    }

    private func cardSection(title: String, cards: [CreditCard]) -> some View {
        Section(title) {
            if cards.isEmpty {
                Text(store.appLanguage == .arabicEgyptian ? "لسه مفيش كروت." : "No cards added yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(cards) { card in
                    let isHintRow = card.id == activeCards.first?.id
                    Button {
                        ledgerCard = card
                    } label: {
                        CreditCardRow(
                            card: card,
                            onPayDue: { dueItem in
                                paymentRoute = CreditCardPaymentRoute(
                                    card: card,
                                    prefilledAmount: dueItem.dueAmount,
                                    maximumPaymentAmount: dueItem.dueAmount,
                                    source: .due
                                )
                            }
                        )
                        .offset(x: isHintRow ? swipeHintOffset : 0)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottomTrailing) {
                        if isHintRow && swipeHintVisible {
                            Text(store.appLanguage == .arabicEgyptian ? "اسحب يسار" : "Swipe left for more")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.regularMaterial)
                                .clipShape(Capsule())
                                .padding(.bottom, 4)
                                .padding(.trailing, 4)
                                .allowsHitTesting(false)
                                .transition(.opacity)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if card.isActive {
                                Button {
                                    paymentRoute = CreditCardPaymentRoute(card: card)
                                } label: {
                                    Label(store.appLanguage == .arabicEgyptian ? "سداد" : "Pay", systemImage: "creditcard.and.123")
                                }
                                .tint(.blue)

                                Button(role: .destructive) {
                                    store.deactivateCreditCard(card)
                                } label: {
                                    Label(store.appLanguage == .arabicEgyptian ? "تعطيل" : "Deactivate", systemImage: "pause.circle")
                                }
                            }

                            Button {
                                ledgerCard = card
                            } label: {
                                Label(store.appLanguage == .arabicEgyptian ? "الكشوفات" : "Ledger", systemImage: "list.bullet.rectangle")
                            }
                            .tint(.purple)

                            Button {
                                selectedCard = card
                            } label: {
                                Label(store.appLanguage == .arabicEgyptian ? "تعديل" : "Edit", systemImage: "pencil")
                            }
                        }
                }
            }
        }
    }
}

private struct CreditCardRow: View {

    @EnvironmentObject private var store: WalletStore

    let card: CreditCard
    let onPayDue: (CreditCardDueItem) -> Void
    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CreditCardVisualMark(card: card, size: 38)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(card.name)
                        .font(.headline)
                        .lineLimit(1)

                    if let lastFourDigits = card.lastFourDigits {
                        Text("•••• \(lastFourDigits)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(card.bankName.isEmpty ? card.cardNetwork.rawValue : "\(card.bankName) - \(card.cardNetwork.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 3) {
                    let openingOutstanding = card.openingOutstandingBalance
                    let purchaseTotal = store.creditCardPurchaseTotal(cardID: card.id)
                    let paymentTotal = store.creditCardPaymentTotal(cardID: card.id)
                    let dueItem = store.creditCardDueItems(referenceDate: Date(), horizonMonths: store.forecastHorizonMonths)
                        .first { $0.cardID == card.id }

                    detailLine(title: isAr ? "الحد الائتماني" : "Limit", value: store.displayCurrency(card.creditLimit))
                    detailLine(title: isAr ? "إجمالي المستحق الحالي" : "Current Outstanding", value: store.displayCurrency(store.creditCardOutstanding(cardID: card.id)))
                    if openingOutstanding > 0 {
                        detailLine(title: store.appLanguage == .arabicEgyptian ? "رصيد افتتاحي مستحق" : "Opening Owed", value: store.displayCurrency(openingOutstanding))
                    }
                    detailLine(title: isAr ? "مشتريات" : "Purchases", value: store.displayCurrency(purchaseTotal))
                    detailLine(title: isAr ? "مدفوعات" : "Payments", value: store.displayCurrency(paymentTotal))
                    detailLine(title: isAr ? "يوم كشف الحساب" : "Statement Closing", value: isAr ? "يوم \(card.statementClosingDay)" : "Day \(card.statementClosingDay)")
                    detailLine(title: isAr ? "يوم الاستحقاق" : "Due", value: isAr ? "يوم \(card.paymentDueDay)" : "Day \(card.paymentDueDay)")

                    if let dueItem {
                        detailLine(title: store.appLanguage == .arabicEgyptian ? "المستحق القادم" : "Next Due", value: "\(formatDate(dueItem.dueDate)) • \(store.displayCurrency(dueItem.dueAmount))")
                        detailLine(title: store.appLanguage == .arabicEgyptian ? "كشف الحساب" : "Statement closes", value: formatDate(dueItem.statementClosingDate))

                        Button {
                            onPayDue(dueItem)
                        } label: {
                            Label(store.appLanguage == .arabicEgyptian ? "سداد المستحق" : "Pay Due", systemImage: "creditcard.and.123")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderless)
                        .tint(PocketWiseSemanticColor.creditCards.tint)
                        .padding(.top, 2)
                    }

                    if let defaultPaymentAccountName = card.defaultPaymentAccountName {
                        detailLine(title: "Default account", value: defaultPaymentAccountName)
                    }
                }

                Text(card.isActive ? (isAr ? "نشط" : "Active") : (isAr ? "غير نشط" : "Inactive"))
                    .pocketWiseChip(
                        semanticColor: card.isActive ? .success : .neutral,
                        isSelected: card.isActive
                    )
            }

            Spacer()

            Image(systemName: "chevron.forward")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(.vertical, 5)
    }

    private func detailLine(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(title):")
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.caption)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

struct CreditCardPaymentView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let route: CreditCardPaymentRoute

    @State private var selectedCardID: UUID?
    @State private var selectedAccountName = ""
    @State private var amountText = ""
    @State private var paymentDate = Date()
    @State private var note = ""
    @State private var saveError: String?

    private var activeCards: [CreditCard] {
        store.activeCreditCards
    }

    private var selectedCard: CreditCard? {
        guard let selectedCardID else {
            return nil
        }

        return store.creditCards.first { $0.id == selectedCardID && !$0.isDeleted }
    }

    private var activeAccounts: [Account] {
        store.accounts
            .filter { $0.isActive }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var selectedAccount: Account? {
        activeAccounts.first { $0.name == selectedAccountName }
    }

    private var amount: Double {
        RecurringMonthlyAmountsSection.parseAmountText(amountText)
    }

    private var outstanding: Double {
        guard let selectedCardID else {
            return 0
        }

        return store.creditCardOutstanding(cardID: selectedCardID)
    }

    private var remainingOutstandingAfterPayment: Double {
        max(outstanding - amount, 0)
    }

    private var sourceBalanceAfterPayment: Double? {
        guard let selectedAccount else {
            return nil
        }

        return selectedAccount.balance - amount
    }

    private var validationMessages: [String] {
        var messages: [String] = []

        if selectedCardID == nil {
            messages.append(store.appLanguage == .arabicEgyptian ? "اختار الكارت." : "Select a card.")
        }

        if selectedAccountName.isEmpty {
            messages.append(store.appLanguage == .arabicEgyptian ? "اختار حساب السداد." : "Select the payment account.")
        }

        if amount <= 0 {
            messages.append(store.appLanguage == .arabicEgyptian ? "دخل مبلغ أكبر من صفر." : "Enter an amount greater than zero.")
        }

        if amount > outstanding {
            messages.append(store.appLanguage == .arabicEgyptian ? "المبلغ أكبر من المستحق على الكارت." : "Payment cannot exceed current outstanding.")
        }

        if let maximumPaymentAmount = route.maximumPaymentAmount,
           amount > maximumPaymentAmount {
            messages.append(store.appLanguage == .arabicEgyptian ? "المبلغ أكبر من المتبقي للسداد في الكشف." : "Payment cannot exceed the remaining statement due.")
        }

        if let selectedAccount,
           amount > selectedAccount.balance {
            messages.append(store.appLanguage == .arabicEgyptian ? "رصيد الحساب غير كافي." : "Insufficient balance in selected account.")
        }

        if outstanding <= 0 {
            messages.append(store.appLanguage == .arabicEgyptian ? "مفيش مستحق حالي على الكارت." : "This card has no current outstanding balance.")
        }

        return messages
    }

    private var canSave: Bool {
        validationMessages.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(store.appLanguage == .arabicEgyptian ? "الكارت" : "Card") {
                    Picker(store.appLanguage == .arabicEgyptian ? "الكارت" : "Card", selection: cardSelectionBinding) {
                        Text(store.appLanguage == .arabicEgyptian ? "اختار الكارت" : "Select Card")
                            .tag(UUID?.none)

                        ForEach(activeCards) { card in
                            Text(cardTitle(card))
                                .tag(Optional(card.id))
                        }
                    }
                    .disabled(route.source == .due)
                    .pocketWiseInputField(semanticColor: .creditCards)

                    HStack {
                        Text(store.appLanguage == .arabicEgyptian ? "المستحق الحالي" : "Current outstanding")
                        Spacer()
                        Text(store.displayCurrency(outstanding, maximumFractionDigits: 2))
                            .fontWeight(.semibold)
                    }

                    if route.source == .due,
                       let maximumPaymentAmount = route.maximumPaymentAmount {
                        HStack {
                            Text(store.appLanguage == .arabicEgyptian ? "المبلغ المستحق" : "Amount Due")
                            Spacer()
                            Text(store.displayCurrency(maximumPaymentAmount, maximumFractionDigits: 2))
                                .fontWeight(.semibold)
                        }

                        Text(store.appLanguage == .arabicEgyptian ? "السداد ده هيقلل رصيد الكارت، ومش هيتحسب كمصروف جديد." : "This payment will reduce your card balance. It will not count as a new expense.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(route.source == .due ? (store.appLanguage == .arabicEgyptian ? "السداد من" : "Payment from") : (store.appLanguage == .arabicEgyptian ? "حساب السداد" : "Payment Account")) {
                    AccountMenuPickerField(
                        title: store.appLanguage == .arabicEgyptian ? "من حساب" : "From Account",
                        selection: $selectedAccountName,
                        accounts: activeAccounts,
                        emptyTitle: store.appLanguage == .arabicEgyptian ? "اختار حساب" : "Select account"
                    )
                    .pocketWiseInputField(semanticColor: .accounts)

                    if let selectedAccount {
                        HStack {
                            Text(store.appLanguage == .arabicEgyptian ? "الرصيد الحالي" : "Current balance")
                            Spacer()
                            Text(store.displayCurrency(selectedAccount.balance, maximumFractionDigits: 2))
                                .fontWeight(.semibold)
                        }
                    }
                }

                Section(store.appLanguage == .arabicEgyptian ? "السداد" : "Payment") {
                    TextField(store.appLanguage == .arabicEgyptian ? "المبلغ" : "Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .creditCards, isProminent: true)

                    DatePicker(
                        store.appLanguage == .arabicEgyptian ? "تم الدفع في" : "Paid at",
                        selection: $paymentDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .pocketWiseInputField(semanticColor: .obligations)
                }

                if amount > 0 || selectedAccount != nil {
                    Section(store.appLanguage == .arabicEgyptian ? "بعد السداد" : "After Payment") {
                        HStack {
                            Text(store.appLanguage == .arabicEgyptian ? "المتبقي على الكارت" : "Remaining outstanding")
                            Spacer()
                            Text(store.displayCurrency(remainingOutstandingAfterPayment, maximumFractionDigits: 2))
                                .fontWeight(.semibold)
                        }

                        if let sourceBalanceAfterPayment {
                            HStack {
                                Text(store.appLanguage == .arabicEgyptian ? "رصيد الحساب بعد السداد" : "Source balance after")
                                Spacer()
                                Text(store.displayCurrency(sourceBalanceAfterPayment, maximumFractionDigits: 2))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(sourceBalanceAfterPayment < 0 ? .red : .primary)
                            }
                        }
                    }
                }

                Section(store.appLanguage == .arabicEgyptian ? "ملاحظة" : "Note") {
                    TextField(store.appLanguage == .arabicEgyptian ? "ملاحظة اختيارية" : "Optional note", text: $note, axis: .vertical)
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

                    if let saveError {
                        Text(saveError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    Button {
                        savePayment()
                    } label: {
                        HStack {
                            Spacer()
                            Text(store.appLanguage == .arabicEgyptian ? "سجل السداد" : "Save Card Payment")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(route.source == .due ? (store.appLanguage == .arabicEgyptian ? "سداد المستحق" : "Pay Due") : (store.appLanguage == .arabicEgyptian ? "سداد كارت" : "Pay Card"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupInitialValues()
            }
            .onChange(of: selectedCardID) { _, newValue in
                applyDefaultAccount(for: newValue)
            }
        }
    }

    private var cardSelectionBinding: Binding<UUID?> {
        Binding(
            get: { selectedCardID },
            set: { selectedCardID = $0 }
        )
    }

    private func setupInitialValues() {
        selectedCardID = route.card.id
        amountText = cleanNumberText(route.prefilledAmount ?? store.creditCardOutstanding(cardID: route.card.id))
        applyDefaultAccount(for: route.card.id)
    }

    private func applyDefaultAccount(for cardID: UUID?) {
        guard let cardID,
              let card = store.activeCreditCards.first(where: { $0.id == cardID }) else {
            selectedAccountName = activeAccounts.first?.name ?? ""
            return
        }

        if let defaultPaymentAccountName = card.defaultPaymentAccountName,
           activeAccounts.contains(where: { $0.name == defaultPaymentAccountName }) {
            selectedAccountName = defaultPaymentAccountName
            return
        }

        if route.source == .due {
            selectedAccountName = ""
            return
        }

        if !activeAccounts.contains(where: { $0.name == selectedAccountName }) {
            selectedAccountName = activeAccounts.first?.name ?? ""
        }
    }

    private func savePayment() {
        guard let selectedCardID else {
            return
        }

        let didSave = store.addCreditCardPayment(
            cardID: selectedCardID,
            fromAccountName: selectedAccountName,
            amount: amount,
            paymentDate: paymentDate,
            note: note.isEmpty ? nil : note
        )

        if didSave {
            dismiss()
        } else {
            saveError = store.appLanguage == .arabicEgyptian ? "تعذر تسجيل السداد. راجع البيانات." : "Could not save payment. Check the details."
        }
    }

    private func cardTitle(_ card: CreditCard) -> String {
        if let lastFourDigits = card.lastFourDigits {
            return "\(card.name) •••• \(lastFourDigits)"
        }

        return card.name
    }

    private func cleanNumberText(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return "\(amount)"
    }
}

private struct CreditCardStatementLedgerView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let card: CreditCard

    @State private var paymentRoute: CreditCardPaymentRoute?

    private var ledgerEntries: [CreditCardStatementLedgerEntry] {
        store.creditCardStatementLedger(
            cardID: card.id,
            referenceDate: Date(),
            horizonMonths: store.forecastHorizonMonths
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.name)
                            .font(.headline)

                        metricLine(
                            title: store.appLanguage == .arabicEgyptian ? "إجمالي المستحق الحالي" : "Current Outstanding",
                            value: formatCurrency(store.creditCardOutstanding(cardID: card.id))
                        )

                        if let dueItem = store.creditCardDueItems(referenceDate: Date(), horizonMonths: store.forecastHorizonMonths).first(where: { $0.cardID == card.id }) {
                            metricLine(
                                title: store.appLanguage == .arabicEgyptian ? "المستحق القادم" : "Next Due",
                                value: "\(formatCurrency(dueItem.dueAmount)) • \(formatDate(dueItem.dueDate))"
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(store.appLanguage == .arabicEgyptian ? "سجل كشوفات الكارت" : "Statement Ledger") {
                    if ledgerEntries.isEmpty {
                        Text(store.appLanguage == .arabicEgyptian ? "لا توجد كشوفات محسوبة لهذا الكارت." : "No generated statement rows for this card.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(ledgerEntries) { entry in
                            statementDisclosure(entry)
                        }
                    }
                }
            }
            .navigationTitle(store.appLanguage == .arabicEgyptian ? "سجل كشوفات الكارت" : "Statement Ledger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.appLanguage == .arabicEgyptian ? "تمام" : "Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $paymentRoute) { route in
                CreditCardPaymentView(route: route)
                    .environmentObject(store)
            }
        }
    }

    private func statementDisclosure(_ entry: CreditCardStatementLedgerEntry) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                if entry.openingOwedIncluded > 0 {
                    metricLine(
                        title: store.appLanguage == .arabicEgyptian ? "رصيد افتتاحي مستحق" : "Opening Owed",
                        value: formatCurrency(entry.openingOwedIncluded)
                    )
                }

                metricLine(
                    title: store.appLanguage == .arabicEgyptian ? "مشتريات الكشف" : "Statement Purchases",
                    value: formatCurrency(entry.statementPurchaseTotal)
                )

                if entry.purchases.isEmpty {
                    Text(store.appLanguage == .arabicEgyptian ? "لا توجد مشتريات في هذا الكشف." : "No purchases in this statement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entry.purchases) { purchase in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(purchase.title)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(formatCurrency(purchase.amount))
                                    .font(.caption)
                            }

                            Text("\(formatDate(purchase.purchaseDate)) • \(purchase.categoryName) / \(purchase.subCategoryName)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                metricLine(
                    title: store.appLanguage == .arabicEgyptian ? "مدفوعات مخصومة" : "Payments Applied",
                    value: formatCurrency(entry.paymentsAppliedTotal)
                )

                if entry.paymentsApplied.isEmpty {
                    Text(store.appLanguage == .arabicEgyptian ? "لا توجد مدفوعات مخصومة من هذا الكشف." : "No payments applied to this statement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entry.paymentsApplied) { payment in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(payment.fromAccountName)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(formatCurrency(payment.amount))
                                    .font(.caption)
                            }

                            Text(formatDate(payment.paymentDate))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()

                metricLine(
                    title: store.appLanguage == .arabicEgyptian ? "المتبقي للسداد" : "Remaining Due",
                    value: formatCurrency(entry.remainingDue)
                )

                metricLine(
                    title: store.appLanguage == .arabicEgyptian ? "إجمالي المستحق بعد الكشف" : "Outstanding After Statement",
                    value: formatCurrency(entry.totalOutstandingAfterStatement)
                )

                if entry.remainingDue > 0 {
                    Button {
                        paymentRoute = CreditCardPaymentRoute(
                            card: card,
                            prefilledAmount: entry.remainingDue,
                            maximumPaymentAmount: entry.remainingDue,
                            source: .due
                        )
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "سداد الكشف" : "Pay Statement", systemImage: "creditcard.and.123")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                }
            }
            .padding(.top, 8)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(store.appLanguage == .arabicEgyptian ? "تاريخ كشف الحساب" : "Statement Closing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatDate(entry.statementClosingDate))
                        .font(.caption)
                }

                HStack {
                    Text(store.appLanguage == .arabicEgyptian ? "تاريخ السداد" : "Payment Due")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatDate(entry.paymentDueDate))
                        .font(.caption)
                }

                HStack {
                    Text(statusText(entry.statusLabel))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(statusColor(entry.statusLabel).opacity(0.12))
                        .foregroundStyle(statusColor(entry.statusLabel))
                        .clipShape(Capsule())

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatCurrency(entry.remainingDue))
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text(store.appLanguage == .arabicEgyptian ? "المتبقي للسداد" : "Remaining Due")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func metricLine(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }

    private func statusText(_ status: String) -> String {
        guard store.appLanguage == .arabicEgyptian else {
            return status
        }

        switch status {
        case "Paid":
            return "مسدد"
        case "Partially Paid":
            return "مسدد جزئيًا"
        case "Overdue":
            return "متأخر"
        case "Due":
            return "مستحق"
        case "Upcoming":
            return "قادم"
        default:
            return status
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "Paid":
            return .green
        case "Partially Paid":
            return .orange
        case "Overdue":
            return .red
        case "Due":
            return .blue
        default:
            return .secondary
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount, maximumFractionDigits: 2)
    }
}

struct CreditCardVisualMark: View {

    let card: CreditCard
    var size: CGFloat = 32

    var body: some View {
        ProviderAppearanceBadge(
            systemName: "creditcard.fill",
            color: (card.appearanceColor ?? .purple).swiftUIColor,
            size: size
        )
    }
}
