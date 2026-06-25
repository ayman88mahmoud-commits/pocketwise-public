import SwiftUI

struct TransactionInitialFilter {
    var searchText: String = ""
    var categoryName: String?
    var monthDate: Date?
    var paidOnly: Bool = false
    var incomeOnly: Bool = false
}

private enum TransactionListItem: Identifiable {
    case financialEvent(FinancialEvent)
    case creditCardPurchase(CreditCardPurchase)
    case creditCardPayment(CreditCardPayment)

    var id: String {
        switch self {
        case .financialEvent(let event):
            return "event-\(event.id)"
        case .creditCardPurchase(let purchase):
            return "card-purchase-\(purchase.id)"
        case .creditCardPayment(let payment):
            return "card-payment-\(payment.id)"
        }
    }

    var date: Date {
        switch self {
        case .financialEvent(let event):
            return event.date
        case .creditCardPurchase(let purchase):
            return purchase.purchaseDate
        case .creditCardPayment(let payment):
            return payment.paymentDate
        }
    }

    var createdAt: Date {
        switch self {
        case .financialEvent(let event):
            return event.createdAt
        case .creditCardPurchase(let purchase):
            return purchase.createdAt
        case .creditCardPayment(let payment):
            return payment.createdAt
        }
    }

    var isInstaPayFee: Bool {
        switch self {
        case .financialEvent(let event):
            return event.title.caseInsensitiveCompare("InstaPay Fee") == .orderedSame ||
            event.subCategoryName?.caseInsensitiveCompare("InstaPay Fee") == .orderedSame
        case .creditCardPurchase, .creditCardPayment:
            return false
        }
    }
}

struct TransactionsView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var searchText = ""
    @State private var mainFilter: TransactionMainFilter = .all
    @State private var selectedAccountName: String?
    @State private var selectedCategoryName: String?
    @State private var monthFilter: TransactionMonthFilter = .allTime
    @State private var selectedMonthDate: Date?
    @State private var isShowingMoreFilters = false

    init(initialFilter: TransactionInitialFilter? = nil) {
        _searchText = State(initialValue: initialFilter?.searchText ?? "")
        _mainFilter = State(initialValue: initialFilter?.incomeOnly == true ? .income : (initialFilter?.paidOnly == true ? .expenses : .all))
        _selectedCategoryName = State(initialValue: initialFilter?.categoryName)
        _monthFilter = State(initialValue: initialFilter?.monthDate == nil ? .allTime : .selectedMonth)
        _selectedMonthDate = State(initialValue: initialFilter?.monthDate)
    }

    private var sortedItems: [TransactionListItem] {
        let financialItems = store.activeFinancialEvents
            .filter { !($0.type == .income && $0.repeatRule != .none && $0.sourceRecurringEventID == nil) }
            .map(TransactionListItem.financialEvent)
        let recurringIncomeItems = store.upcomingKnownIncomeEvents()
            .filter { $0.sourceRecurringEventID != nil }
            .map(TransactionListItem.financialEvent)
        let cardPurchaseItems = store.activeCreditCardPurchases.map(TransactionListItem.creditCardPurchase)
        let cardPaymentItems = store.activeCreditCardPayments.map(TransactionListItem.creditCardPayment)

        return (financialItems + recurringIncomeItems + cardPurchaseItems + cardPaymentItems).sorted(by: sortTransactionItems)
    }

    private var filteredItems: [TransactionListItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return sortedItems.filter { item in
            matchesMainFilter(item) &&
            matchesAccountFilter(item) &&
            matchesCategoryFilter(item) &&
            matchesMonthFilter(item) &&
            matchesSearch(item, query: query)
        }
    }

    private var groupedItems: [(monthStart: Date, items: [TransactionListItem])] {
        let grouped = Dictionary(grouping: filteredItems) { item in
            startOfMonth(item.date)
        }

        return grouped
            .map { group in
                (
                    monthStart: group.key,
                    items: group.value.sorted(by: sortTransactionItemsForCurrentFilter)
                )
            }
            .sorted { first, second in
                if mainFilter == .futureUpcoming {
                    return first.monthStart < second.monthStart
                }

                return first.monthStart > second.monthStart
            }
    }

    private func sortTransactionItems(_ first: TransactionListItem, _ second: TransactionListItem) -> Bool {
        if first.date == second.date {
            if first.isInstaPayFee != second.isInstaPayFee {
                return !first.isInstaPayFee
            }

            return first.createdAt > second.createdAt
        }

        return first.date > second.date
    }

    private func sortTransactionItemsForCurrentFilter(_ first: TransactionListItem, _ second: TransactionListItem) -> Bool {
        if mainFilter == .futureUpcoming {
            if first.date == second.date {
                return first.createdAt > second.createdAt
            }

            return first.date < second.date
        }

        return sortTransactionItems(first, second)
    }

    private var availableAccountNames: [String] {
        var names = store.accounts
            .filter { $0.isActive }
            .map { $0.name }

        let usedNames = store.activeFinancialEvents.flatMap { event in
            [event.accountName, event.destinationAccountName].compactMap { $0 }
        }

        for name in usedNames where !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            names.append(name)
        }

        for name in store.activeCreditCardPayments.map(\.fromAccountName)
        where !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            names.append(name)
        }

        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var availableFilterAccounts: [Account] {
        availableAccountNames.map { name in
            account(for: name) ?? Account(name: name, balance: 0, type: .bank, isActive: false)
        }
    }

    private var availableCategoryNames: [String] {
        var names = store.categories
            .filter { $0.isActive }
            .map { $0.name }

        let usedNames = store.activeFinancialEvents.compactMap { $0.categoryName }

        for name in usedNames where !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            names.append(name)
        }

        for name in store.activeCreditCardPurchases.map(\.categoryName)
        where !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            names.append(name)
        }

        if let selectedCategoryName,
           !names.contains(where: { $0.caseInsensitiveCompare(selectedCategoryName) == .orderedSame }) {
            names.append(selectedCategoryName)
        }

        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var hasActiveFilters: Bool {
        mainFilter != .all ||
        selectedAccountName != nil ||
        selectedCategoryName != nil ||
        monthFilter != .allTime ||
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var activeFilterLabels: [String] {
        var labels: [String] = []

        if mainFilter != .all {
            labels.append(mainFilter.title(language: store.appLanguage))
        }

        if let selectedAccountName {
            labels.append(selectedAccountName)
        }

        if let selectedCategoryName {
            labels.append(selectedCategoryName)
        }

        if monthFilter != .allTime {
            if let selectedMonthDate {
                labels.append(formatMonth(selectedMonthDate))
            } else {
                labels.append(monthFilter.title(language: store.appLanguage))
            }
        }

        return labels
    }

    private var filterContextText: String? {
        guard selectedMonthDate != nil || selectedCategoryName != nil || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        if selectedMonthDate != nil && mainFilter == .expenses && selectedCategoryName == nil {
            return store.appLanguage == .arabicEgyptian ? "معاملات الشهر الحالي" : "This month transactions"
        }

        if let selectedCategoryName, let selectedMonthDate {
            return store.appLanguage == .arabicEgyptian
                ? "\(selectedCategoryName) - \(formatMonth(selectedMonthDate))"
                : "\(selectedCategoryName) - \(formatMonth(selectedMonthDate))"
        }

        return store.appLanguage == .arabicEgyptian ? "نتائج مفلترة" : "Filtered transactions"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    transactionsTitle
                    peopleDebtsShortcut
                    filterHeader
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if sortedItems.isEmpty {
                    emptyState(
                        title: store.appLanguage == .arabicEgyptian ? "لسه مفيش حركات" : "No transactions yet",
                        subtitle: store.appLanguage == .arabicEgyptian ? "المصاريف، مشتريات وسداد الكارت، الدخل، التحويلات، والالتزامات المدفوعة هتظهر هنا." : "Added expenses, card purchases, card payments, future items, income, fees, and paid obligations will appear here.",
                        showClearButton: false
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else if filteredItems.isEmpty {
                    emptyState(
                        title: store.appLanguage == .arabicEgyptian ? "مفيش حركات مناسبة للفلاتر دي." : "No transactions match these filters.",
                        subtitle: emptyTransactionsSubtitle,
                        showClearButton: hasActiveFilters
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(groupedItems, id: \.monthStart) { group in
                        Section(formatMonth(group.monthStart)) {
                            ForEach(group.items) { item in
                                switch item {
                                case .financialEvent(let event):
                                    NavigationLink {
                                        TransactionDetailView(
                                            event: event,
                                            isPresentedModally: false
                                        )
                                        .environmentObject(store)
                                    } label: {
                                        TransactionHistoryRow(event: event)
                                    }
                                    .buttonStyle(.plain)

                                case .creditCardPurchase(let purchase):
                                    NavigationLink {
                                        CreditCardPurchaseDetailView(purchase: purchase)
                                            .environmentObject(store)
                                    } label: {
                                        CreditCardPurchaseHistoryRow(purchase: purchase)
                                            .environmentObject(store)
                                    }
                                    .buttonStyle(.plain)

                                case .creditCardPayment(let payment):
                                    NavigationLink {
                                        CreditCardPaymentDetailView(payment: payment)
                                            .environmentObject(store)
                                    } label: {
                                        CreditCardPaymentHistoryRow(payment: payment)
                                            .environmentObject(store)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .accessibilityIdentifier("screen.transactions")
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingMoreFilters) {
                transactionFilterSheet
            }
        }
    }

    private var transactionsTitle: some View {
        Text(AppText.tabTransactions(store.appLanguage))
            .font(.largeTitle)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private var peopleDebtsShortcut: some View {
        NavigationLink {
            PeopleDebtsView()
                .environmentObject(store)
        } label: {
            HStack(spacing: 12) {
                PocketWiseIconBadge(
                    systemName: "person.2.fill",
                    semanticColor: .accounts,
                    size: 36,
                    cornerRadius: 10
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(store.appLanguage == .arabicEgyptian ? "الأشخاص والديون" : "People & Debts")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(store.appLanguage == .arabicEgyptian ? "تابع الفلوس اللي ليك أو عليك." : "Track money owed to you or by you.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .pocketWiseCard(semanticColor: .accounts, padding: 10, cornerRadius: 14, showsBorder: true)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 4)
        }
        .buttonStyle(.plain)
    }

    private var emptyTransactionsSubtitle: String {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isPeopleDebtContext =
            selectedCategoryName?.caseInsensitiveCompare("Money Lent / Receivables") == .orderedSame ||
            query.localizedCaseInsensitiveContains("money lent") ||
            query.localizedCaseInsensitiveContains("repayment") ||
            query.localizedCaseInsensitiveContains("people") ||
            query.localizedCaseInsensitiveContains("debt")

        if isPeopleDebtContext {
            return store.appLanguage == .arabicEgyptian
                ? "حركات الأشخاص والديون تتم إدارتها بشكل منفصل. افتح الأشخاص / الديون لمراجعتها."
                : "People/Debts cash movements are managed separately. Open People/Debts to review them."
        }

        return store.appLanguage == .arabicEgyptian
            ? "غيّر البحث أو الفلاتر عشان تشوف حركات أكتر."
            : "Adjust search or filters to review more transactions."
    }

    private var filterHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(store.appLanguage == .arabicEgyptian ? "دور في الحركات" : "Search transactions", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)

            if let filterContextText {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .foregroundStyle(PocketWiseSemanticColor.spending.tint)

                    Text(filterContextText)
                        .font(.caption)
                        .fontWeight(.semibold)

                    Spacer()

                    if hasActiveFilters {
                        Button(store.appLanguage == .arabicEgyptian ? "مسح" : "Clear") {
                            clearFilters()
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(PocketWiseSemanticColor.spending.softBackground(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TransactionMainFilter.allCases) { filter in
                        filterChip(
                            title: filter.title(language: store.appLanguage),
                            isSelected: mainFilter == filter
                        ) {
                            mainFilter = filter
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 24)
            }

            HStack(spacing: 8) {
                Button {
                    isShowingMoreFilters = true
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "فلاتر أكتر" : "More Filters", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .pocketWiseChip(semanticColor: .spending, isSelected: false)
                }
                .buttonStyle(.plain)

                if hasActiveFilters {
                    Button(store.appLanguage == .arabicEgyptian ? "امسح الفلاتر" : "Clear Filters") {
                        clearFilters()
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(PocketWiseSemanticColor.spending.tint)
                }

                Spacer()
            }
            .padding(.horizontal, 16)

            if !activeFilterLabels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(activeFilterLabels, id: \.self) { label in
                            Text(label)
                                .pocketWiseChip(semanticColor: .spending)
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 24)
                }
            }
        }
        .padding(.vertical, 10)
        .background(Color(.systemGroupedBackground))
    }

    private var transactionFilterSheet: some View {
        NavigationStack {
            Form {
                Section(store.appLanguage == .arabicEgyptian ? "الحساب" : "Account") {
                    AccountMenuPickerField(
                        title: store.appLanguage == .arabicEgyptian ? "الحساب" : "Account",
                        selection: accountSelectionBinding,
                        accounts: availableFilterAccounts,
                        placeholder: store.appLanguage == .arabicEgyptian ? "كل الحسابات" : "All Accounts",
                        emptyTitle: store.appLanguage == .arabicEgyptian ? "كل الحسابات" : "All Accounts",
                        emptySelectionValue: "__all__",
                        inactiveSubtitle: true
                    )
                    .pocketWiseInputField(semanticColor: .accounts)
                }

                Section(store.appLanguage == .arabicEgyptian ? "البند" : "Category") {
                    Picker(store.appLanguage == .arabicEgyptian ? "البند" : "Category", selection: categorySelectionBinding) {
                        Text(store.appLanguage == .arabicEgyptian ? "كل البنود" : "All Categories").tag("__all__")

                        ForEach(availableCategoryNames, id: \.self) { categoryName in
                            Text(categoryName).tag(categoryName)
                        }
                    }
                    .pocketWiseInputField(semanticColor: .categories)
                }

                Section(store.appLanguage == .arabicEgyptian ? "الشهر" : "Month") {
                    Picker(store.appLanguage == .arabicEgyptian ? "الفترة" : "Month Range", selection: $monthFilter) {
                        ForEach(TransactionMonthFilter.allCases) { filter in
                            Text(filter.title(language: store.appLanguage)).tag(filter)
                        }
                    }
                    .onChange(of: monthFilter) { _, newValue in
                        if newValue != .selectedMonth {
                            selectedMonthDate = nil
                        }
                    }
                    .pocketWiseInputField(semanticColor: .spending)

                    if monthFilter == .selectedMonth {
                        DatePicker(
                            store.appLanguage == .arabicEgyptian ? "اختار شهر" : "Select Month",
                            selection: Binding(
                                get: { selectedMonthDate ?? Date() },
                                set: { selectedMonthDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .pocketWiseInputField(semanticColor: .spending)
                    }
                }

                if hasActiveFilters {
                    Section {
                        Button(store.appLanguage == .arabicEgyptian ? "امسح الفلاتر" : "Clear Filters") {
                            clearFilters()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(store.appLanguage == .arabicEgyptian ? "فلاتر أكتر" : "More Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.appLanguage == .arabicEgyptian ? "تم" : "Done") {
                        isShowingMoreFilters = false
                    }
                }
            }
        }
    }

    private var accountSelectionBinding: Binding<String> {
        Binding(
            get: { selectedAccountName ?? "__all__" },
            set: { selectedAccountName = $0 == "__all__" ? nil : $0 }
        )
    }

    private var categorySelectionBinding: Binding<String> {
        Binding(
            get: { selectedCategoryName ?? "__all__" },
            set: { selectedCategoryName = $0 == "__all__" ? nil : $0 }
        )
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 1)
                .pocketWiseChip(semanticColor: transactionFilterSemanticColor(for: title), isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func transactionFilterSemanticColor(for title: String) -> PocketWiseSemanticColor {
        let normalized = title.lowercased()
        if normalized.contains("income") || normalized.contains("دخل") {
            return .income
        }
        if normalized.contains("transfer") || normalized.contains("تحويل") {
            return .accounts
        }
        if normalized.contains("paid") || normalized.contains("مدفوع") {
            return .success
        }
        return .spending
    }

    private func emptyState(title: String, subtitle: String, showClearButton: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if showClearButton {
                Button(store.appLanguage == .arabicEgyptian ? "امسح الفلاتر" : "Clear Filters") {
                    clearFilters()
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func matchesMainFilter(_ item: TransactionListItem) -> Bool {
        switch item {
        case .financialEvent(let event):
            switch mainFilter {
            case .all:
                return true

            case .expenses:
                return isExpenseLike(event.type) && event.status == .paid && event.date <= Date()

            case .income:
                return event.type == .income

            case .transfers:
                return event.type == .transfer

            case .futureUpcoming:
                return event.date > Date()

            case .unpaidExpected:
                return (event.status == .unpaid ||
                        event.status == .expected ||
                        event.status == .planned) &&
                event.date <= Date()
            }

        case .creditCardPurchase(let purchase):
            switch mainFilter {
            case .all:
                return true
            case .expenses:
                return purchase.purchaseDate <= Date()
            case .futureUpcoming:
                return purchase.purchaseDate > Date()
            case .income, .transfers, .unpaidExpected:
                return false
            }

        case .creditCardPayment(let payment):
            switch mainFilter {
            case .all, .transfers:
                return true
            case .futureUpcoming:
                return payment.paymentDate > Date()
            case .expenses, .income, .unpaidExpected:
                return false
            }
        }
    }

    private func matchesAccountFilter(_ item: TransactionListItem) -> Bool {
        guard let selectedAccountName else {
            return true
        }

        switch item {
        case .financialEvent(let event):
            return event.accountName?.caseInsensitiveCompare(selectedAccountName) == .orderedSame ||
            event.destinationAccountName?.caseInsensitiveCompare(selectedAccountName) == .orderedSame

        case .creditCardPurchase:
            return false

        case .creditCardPayment(let payment):
            return payment.fromAccountName.caseInsensitiveCompare(selectedAccountName) == .orderedSame
        }
    }

    private func matchesCategoryFilter(_ item: TransactionListItem) -> Bool {
        guard let selectedCategoryName else {
            return true
        }

        switch item {
        case .financialEvent(let event):
            return event.categoryName?.caseInsensitiveCompare(selectedCategoryName) == .orderedSame

        case .creditCardPurchase(let purchase):
            return purchase.categoryName.caseInsensitiveCompare(selectedCategoryName) == .orderedSame

        case .creditCardPayment:
            return false
        }
    }

    private func matchesMonthFilter(_ item: TransactionListItem) -> Bool {
        if let selectedMonthDate,
           let range = monthRange(for: selectedMonthDate) {
            return item.date >= range.start && item.date < range.end
        }

        guard let range = monthFilter.dateRange() else {
            return true
        }

        return item.date >= range.start && item.date < range.end
    }

    private func matchesSearch(_ item: TransactionListItem, query: String) -> Bool {
        guard !query.isEmpty else {
            return true
        }

        return searchableText(for: item)
            .localizedCaseInsensitiveContains(query)
    }

    private func isExpenseLike(_ type: FinancialEventType) -> Bool {
        switch type {
        case .expense, .obligation, .expectedExpense, .installment:
            return true

        case .income, .transfer:
            return false
        }
    }

    private func clearFilters() {
        searchText = ""
        mainFilter = .all
        selectedAccountName = nil
        selectedCategoryName = nil
        monthFilter = .allTime
        selectedMonthDate = nil
    }

    private func searchableText(for item: TransactionListItem) -> String {
        switch item {
        case .financialEvent(let event):
            return [
                event.title,
                event.note,
                event.categoryName,
                event.subCategoryName,
                event.reimbursementCategoryName,
                event.type == .income ? event.effectiveIncomeType.title(language: store.appLanguage) : nil,
                event.accountName,
                event.destinationAccountName,
                event.paymentMethodName,
                event.type.rawValue,
                event.status.rawValue,
                cleanNumberText(event.amount),
                "\(Int(event.amount))"
            ]
            .compactMap { $0 }
            .joined(separator: " ")

        case .creditCardPurchase(let purchase):
            let card = store.creditCards.first { $0.id == purchase.cardID }
            return [
                purchase.title,
                purchase.note,
                purchase.categoryName,
                purchase.subCategoryName,
                card?.name,
                card?.bankName,
                "Credit Card",
                "Card Purchase",
                cleanNumberText(purchase.amount),
                "\(Int(purchase.amount))"
            ]
            .compactMap { $0 }
            .joined(separator: " ")

        case .creditCardPayment(let payment):
            let card = store.creditCards.first { $0.id == payment.cardID }
            return [
                "Payment to \(card?.name ?? "Credit Card")",
                payment.note,
                payment.fromAccountName,
                card?.name,
                card?.bankName,
                "Credit Card",
                "Card Payment",
                "Settlement",
                cleanNumberText(payment.amount),
                "\(Int(payment.amount))"
            ]
            .compactMap { $0 }
            .joined(separator: " ")
        }
    }

    private func startOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func account(for name: String) -> Account? {
        store.accounts.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func monthRange(for date: Date) -> (start: Date, end: Date)? {
        let start = startOfMonth(date)
        guard let end = Calendar.current.date(byAdding: .month, value: 1, to: start) else {
            return nil
        }

        return (start, end)
    }

    private func cleanNumberText(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return "\(amount)"
    }
}

private enum TransactionMainFilter: String, CaseIterable, Identifiable {
    case all
    case expenses
    case income
    case transfers
    case futureUpcoming
    case unpaidExpected

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .all:
            return language == .arabicEgyptian ? "الكل" : "All"
        case .expenses:
            return language == .arabicEgyptian ? "المصاريف" : "Expenses"
        case .income:
            return language == .arabicEgyptian ? "الدخل" : "Income"
        case .transfers:
            return language == .arabicEgyptian ? "التحويلات" : "Transfers"
        case .futureUpcoming:
            return language == .arabicEgyptian ? "الجاي" : "Future"
        case .unpaidExpected:
            return language == .arabicEgyptian ? "لسه" : "Unpaid"
        }
    }
}

private enum TransactionMonthFilter: String, CaseIterable, Identifiable {
    case currentMonth
    case previousMonth
    case lastThreeMonths
    case thisYear
    case selectedMonth
    case allTime

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .currentMonth:
            return language == .arabicEgyptian ? "الشهر الحالي" : "Current Month"
        case .previousMonth:
            return language == .arabicEgyptian ? "الشهر اللي فات" : "Previous Month"
        case .lastThreeMonths:
            return language == .arabicEgyptian ? "آخر ٣ شهور" : "Last 3 Months"
        case .thisYear:
            return language == .arabicEgyptian ? "السنة دي" : "This Year"
        case .selectedMonth:
            return language == .arabicEgyptian ? "الشهر المختار" : "Selected Month"
        case .allTime:
            return language == .arabicEgyptian ? "كل الوقت" : "All Time"
        }
    }

    func dateRange(from date: Date = Date()) -> (start: Date, end: Date)? {
        let calendar = Calendar.current

        switch self {
        case .currentMonth:
            let start = startOfMonth(for: date, calendar: calendar)
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? date
            return (start, end)

        case .previousMonth:
            let currentStart = startOfMonth(for: date, calendar: calendar)
            let start = calendar.date(byAdding: .month, value: -1, to: currentStart) ?? currentStart
            return (start, currentStart)

        case .lastThreeMonths:
            let currentStart = startOfMonth(for: date, calendar: calendar)
            let start = calendar.date(byAdding: .month, value: -2, to: currentStart) ?? currentStart
            let end = calendar.date(byAdding: .month, value: 1, to: currentStart) ?? date
            return (start, end)

        case .thisYear:
            let components = calendar.dateComponents([.year], from: date)
            let start = calendar.date(from: components) ?? date
            let end = calendar.date(byAdding: .year, value: 1, to: start) ?? date
            return (start, end)

        case .selectedMonth:
            return nil

        case .allTime:
            return nil
        }
    }

    private func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}

struct TransactionHistoryRow: View {

    @EnvironmentObject private var store: WalletStore

    let event: FinancialEvent

    var body: some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(
                systemName: iconName,
                semanticColor: semanticColor,
                size: 36,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(classificationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    ForEach(chipLabels, id: \.self) { label in
                        chip(label)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(signedAmountText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(amountColor)
                    .lineLimit(1)

                Text(formatDate(event.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var semanticColor: PocketWiseSemanticColor {
        switch event.type {
        case .income:
            return event.status == .paid ? .income : .accounts
        case .transfer:
            return .accounts
        case .obligation, .expectedExpense, .installment:
            return .obligations
        case .expense:
            return .spending
        }
    }

    private var amountColor: Color {
        switch event.type {
        case .income:
            return event.status == .paid ? PocketWiseSemanticColor.income.tint : PocketWiseSemanticColor.accounts.tint
        case .transfer:
            return PocketWiseSemanticColor.accounts.tint
        case .expense, .obligation, .expectedExpense, .installment:
            return PocketWiseSemanticColor.spending.tint
        }
    }

    private var classificationText: String {
        if event.type == .transfer {
            let notSet = store.appLanguage == .arabicEgyptian ? "غير محدد" : "Not set"
            let from = event.accountName ?? notSet
            let to = event.destinationAccountName ?? notSet
            return "\(from) → \(to)"
        }

        var parts: [String] = []

        if let categoryName = event.categoryName,
           let subCategoryName = event.subCategoryName {
            parts.append(AppText.categorySubcategoryDisplayText(
                categoryName: categoryName,
                subCategoryName: subCategoryName,
                language: store.appLanguage
            ))
        } else if let categoryName = event.categoryName {
            parts.append(AppText.categoryDisplayName(categoryName, language: store.appLanguage))
        } else if let subCategoryName = event.subCategoryName {
            parts.append(AppText.subcategoryDisplayName(subCategoryName, language: store.appLanguage))
        } else if event.type == .income {
            parts.append(event.effectiveIncomeType.title(language: store.appLanguage))
        }

        if let paymentLabel {
            parts.append(paymentLabel)
        }

        return parts.isEmpty ? AppText.eventTypeLabel(event.type, language: store.appLanguage) : parts.joined(separator: " • ")
    }

    private var paymentLabel: String? {
        if event.type == .transfer {
            return store.appLanguage == .arabicEgyptian ? "تحويل" : "Transfer"
        }

        if let paymentMethodName = event.paymentMethodName,
           !paymentMethodName.isEmpty {
            return paymentMethodName
        }

        if let accountName = event.accountName,
           !accountName.isEmpty {
            return accountName
        }

        return nil
    }

    private var chipLabels: [String] {
        var labels: [String] = []

        if event.type == .income {
            labels.append(event.status == .paid ? localizedChip("Received") : localizedChip("Expected income"))
        } else if event.status != .paid {
            labels.append(statusLabel)
        }

        switch event.type {
        case .income:
            break
        case .transfer:
            labels.append(localizedChip("Transfer"))
        case .expense:
            if event.status != .paid {
                labels.append(localizedChip("Expense"))
            }
        case .obligation, .expectedExpense, .installment:
            labels.append(localizedChip("Future"))
        }

        return labels
    }

    private var statusLabel: String {
        switch event.status {
        case .expected:
            return AppText.statusLabel(.expected, language: store.appLanguage)
        case .planned:
            return AppText.statusLabel(.planned, language: store.appLanguage)
        case .unpaid:
            return AppText.statusLabel(.unpaid, language: store.appLanguage)
        case .paid:
            return AppText.statusLabel(.paid, language: store.appLanguage)
        case .skipped:
            return AppText.statusLabel(.skipped, language: store.appLanguage)
        case .cancelled:
            return AppText.statusLabel(.cancelled, language: store.appLanguage)
        }
    }

    private func localizedChip(_ key: String) -> String {
        AppText.transactionChip(key, language: store.appLanguage)
    }

    private var signedAmountText: String {
        if event.type == .transfer {
            return formatCurrency(event.amount)
        }

        let prefix = event.type == .income ? "+" : "-"
        return store.signedDisplayCurrency(event.amount, prefix: prefix)
    }

    private var iconName: String {
        switch event.type {
        case .income:
            return "arrow.down.circle.fill"
        case .obligation:
            return "calendar.circle.fill"
        case .expectedExpense:
            return "clock.fill"
        case .installment:
            return "creditcard.and.123"
        case .expense:
            return "creditcard.fill"
        case .transfer:
            return "arrow.left.arrow.right.circle.fill"
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .pocketWiseChip(semanticColor: chipSemanticColor(for: text))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func chipSemanticColor(for text: String) -> PocketWiseSemanticColor {
        let normalized = text.lowercased()
        if normalized.contains("expected") ||
            normalized.contains("planned") ||
            normalized.contains("future") ||
            normalized.contains("unpaid") ||
            normalized.contains("متوقع") ||
            normalized.contains("مخطط") ||
            normalized.contains("قادم") ||
            normalized.contains("غير مدفوع") {
            return .warning
        }
        if normalized.contains("received") || normalized.contains("income") || normalized.contains("دخل") || normalized.contains("الاستلام") {
            return .income
        }
        if normalized.contains("transfer") || normalized.contains("تحويل") {
            return .accounts
        }
        if normalized.contains("paid") || normalized.contains("مدفوع") {
            return .success
        }
        if normalized.contains("obligation") || normalized.contains("installment") || normalized.contains("due") {
            return .obligations
        }
        return semanticColor
    }

    private func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
    }
}

private struct CreditCardPurchaseHistoryRow: View {

    @EnvironmentObject private var store: WalletStore

    let purchase: CreditCardPurchase

    private var card: CreditCard? {
        store.creditCards.first { $0.id == purchase.cardID }
    }

    var body: some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(
                systemName: "creditcard.fill",
                semanticColor: .creditCards,
                size: 36,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(purchase.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(creditCardPurchaseSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    chip(AppText.transactionChip("Card", language: store.appLanguage))
                    chip(AppText.transactionChip("Purchase", language: store.appLanguage))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(store.signedDisplayCurrency(purchase.amount, prefix: "-"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(PocketWiseSemanticColor.spending.tint)
                    .lineLimit(1)

                Text(formatDate(purchase.purchaseDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .pocketWiseChip(semanticColor: .creditCards)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var creditCardPurchaseSubtitle: String {
        let categoryText = "\(purchase.categoryName) / \(purchase.subCategoryName)"
        guard let cardName = card?.name else {
            return categoryText
        }

        return "\(categoryText) • \(cardName)"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
    }
}

private struct CreditCardPurchaseDetailView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let purchase: CreditCardPurchase

    @State private var isEditing = false
    @State private var showDeleteConfirmation = false

    private var card: CreditCard? {
        store.creditCards.first { $0.id == purchase.cardID }
    }

    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    var body: some View {
        List {
            Section(isAr ? "شراء بالكارت" : "Card Purchase") {
                detailRow(isAr ? "الوصف" : "Title", purchase.title)
                detailRow(isAr ? "المبلغ" : "Amount", store.displayCurrency(purchase.amount, maximumFractionDigits: 2))
                detailRow(isAr ? "التاريخ" : "Date", formatDate(purchase.purchaseDate))
                detailRow(isAr ? "البند" : "Category",
                    AppText.categoryDisplayName(purchase.categoryName, language: store.appLanguage))
                detailRow(isAr ? "البند الفرعي" : "Subcategory",
                    AppText.subcategoryDisplayName(purchase.subCategoryName, language: store.appLanguage))
            }

            Section(isAr ? "كارت الائتمان" : "Credit Card") {
                if let card {
                    HStack(spacing: 10) {
                        CreditCardVisualMark(card: card, size: 30)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(card.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(cardSubtitle(card))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    detailRow(isAr ? "المستحق على الكارت" : "Outstanding",
                        store.displayCurrency(store.creditCardOutstanding(cardID: card.id), maximumFractionDigits: 2))
                } else {
                    detailRow(isAr ? "الكارت" : "Card", isAr ? "غير موجود" : "Not found")
                }

                Text(isAr ? "العملية دي لم تخصم من أي حساب بنك أو كاش وقت التسجيل." : "This purchase did not deduct any bank, cash, or wallet account at entry time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let note = purchase.note,
               !note.isEmpty {
                Section(isAr ? "ملاحظة" : "Note") {
                    Text(note)
                }
            }

            Section {
                Button {
                    isEditing = true
                } label: {
                    HStack {
                        Spacer()
                        Text(isAr ? "تعديل" : "Edit")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text(isAr ? "احذف شراء الكارت" : "Delete Card Purchase")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(isAr ? "شراء بالكارت" : "Card Purchase")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditing) {
            EditCreditCardPurchaseView(purchase: purchase)
                .environmentObject(store)
        }
        .confirmationDialog(
            isAr ? "احذف شراء الكارت؟" : "Delete card purchase?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(isAr ? "احذف" : "Delete", role: .destructive) {
                store.deleteCreditCardPurchase(purchase)
                dismiss()
            }

            Button(isAr ? "إلغاء" : "Cancel", role: .cancel) { }
        } message: {
            Text(isAr ? "الحذف يقلل مصروفات التصنيف ورصيد الكارت المستحق فقط، ولا يغير رصيد البنك." : "Deleting reduces category spending and card outstanding only. It does not change bank cash.")
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

    private func cardSubtitle(_ card: CreditCard) -> String {
        if let lastFourDigits = card.lastFourDigits {
            return "\(card.bankName) •••• \(lastFourDigits)"
        }

        return card.bankName.isEmpty ? card.cardNetwork.rawValue : card.bankName
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter.string(from: date)
    }
}

private struct EditCreditCardPurchaseView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let purchase: CreditCardPurchase

    @State private var title: String = ""
    @State private var amountText: String = ""
    @State private var date: Date = Date()
    @State private var selectedCardID: UUID?
    @State private var selectedCategoryName: String = ""
    @State private var selectedSubCategoryName: String = ""
    @State private var note: String = ""

    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    var body: some View {
        NavigationStack {
            Form {
                Section(isAr ? "شراء بالكارت" : "Card Purchase") {
                    TextField(isAr ? "الوصف" : "Title", text: $title)

                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        validationMessage(isAr ? "اكتب وصف أو عنوان." : "Enter a title or description.")
                    }

                    TextField(isAr ? "المبلغ" : "Amount", text: $amountText)
                        .keyboardType(.decimalPad)

                    if amount <= 0 {
                        validationMessage(isAr ? "أدخل مبلغ أكبر من صفر." : "Enter an amount greater than zero.")
                    }

                    DatePicker(
                        isAr ? "التاريخ والوقت" : "Date & Time",
                        selection: $date,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section(isAr ? "كارت الائتمان" : "Credit Card") {
                    Picker(isAr ? "اختر الكارت" : "Select Credit Card", selection: $selectedCardID) {
                        Text(isAr ? "اختر الكارت" : "Select Credit Card")
                            .tag(UUID?.none)

                        ForEach(cardsForEditing) { card in
                            Text(creditCardPickerTitle(card))
                                .tag(Optional(card.id))
                        }
                    }

                    if selectedCardID == nil {
                        validationMessage(isAr ? "اختر الكارت." : "Select a credit card.")
                    }

                    Text(isAr ? "تعديل شراء الكارت لا يخصم من رصيد البنك وقت الحفظ." : "Editing a card purchase does not deduct bank cash when saved.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(isAr ? "البند" : "Category") {
                    CategorySubcategoryPickerView(
                        categoryName: $selectedCategoryName,
                        subCategoryName: $selectedSubCategoryName,
                        showsValidation: true,
                        includesInactiveSelection: true,
                        suggestion: categorySuggestion
                    )
                }

                Section(isAr ? "ملاحظة" : "Note") {
                    TextField(isAr ? "ملاحظة اختيارية" : "Optional note", text: $note)
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
                            Text(isAr ? "حفظ التعديلات" : "Save Changes")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(isAr ? "تعديل شراء الكارت" : "Edit Card Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isAr ? "إلغاء" : "Cancel") {
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
        }
    }

    private var amount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var cardsForEditing: [CreditCard] {
        var cards = store.activeCreditCards

        if let inactiveCard = store.creditCards.first(where: { $0.id == selectedCardID && !$0.isActive }),
           !cards.contains(where: { $0.id == inactiveCard.id }) {
            cards.append(inactiveCard)
        }

        return cards.sorted { $0.name < $1.name }
    }

    private var categoriesForEditing: [Category] {
        var categories = store.categories.filter { $0.isActive }

        if let inactiveCategory = store.categories.first(where: { $0.name == selectedCategoryName && !$0.isActive }),
           !categories.contains(where: { $0.id == inactiveCategory.id }) {
            categories.append(inactiveCategory)
        }

        return categories.sorted { $0.name < $1.name }
    }

    private var availableSubcategories: [String] {
        store.subcategoriesForEditing(
            categoryName: selectedCategoryName,
            selectedSubcategoryName: selectedSubCategoryName
        )
    }

    private var validationMessages: [String] {
        var messages: [String] = []

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append(isAr ? "اكتب وصف أو عنوان." : "Enter a title or description.")
        }

        if amount <= 0 {
            messages.append(isAr ? "أدخل مبلغ أكبر من صفر." : "Enter an amount greater than zero.")
        }

        if selectedCardID == nil {
            messages.append(isAr ? "اختر الكارت." : "Select a credit card.")
        }

        if selectedCategoryName.isEmpty {
            messages.append(isAr ? "اختر البند." : "Select a category.")
        }

        if selectedSubCategoryName.isEmpty {
            messages.append(isAr ? "اختر البند الفرعي." : "Select a subcategory.")
        }

        return messages
    }

    private var canSave: Bool {
        validationMessages.isEmpty
    }

    private var categorySuggestion: CategorySubcategorySuggestion? {
        guard purchase.categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                purchase.subCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return store.suggestedCategorySubcategory(
            for: CategorySuggestionRequest(
                title: title,
                note: note,
                paymentMethodName: "Credit Card",
                allowedEventTypes: [.expense],
                includeCreditCardPurchases: true,
                excludingCreditCardPurchaseID: purchase.id
            )
        )
    }

    private func setupInitialValues() {
        title = purchase.title
        amountText = cleanNumberText(purchase.amount)
        date = purchase.purchaseDate
        selectedCardID = purchase.cardID
        selectedCategoryName = purchase.categoryName
        selectedSubCategoryName = purchase.subCategoryName
        note = purchase.note ?? ""

        if selectedSubCategoryName.isEmpty {
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

    private func saveChanges() {
        guard let selectedCardID else {
            return
        }

        var updatedPurchase = purchase
        updatedPurchase.cardID = selectedCardID
        updatedPurchase.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedPurchase.amount = amount
        updatedPurchase.purchaseDate = date
        updatedPurchase.categoryName = selectedCategoryName
        updatedPurchase.subCategoryName = selectedSubCategoryName
        updatedPurchase.note = note.isEmpty ? nil : note

        store.updateCreditCardPurchase(updatedPurchase)
        dismiss()
    }

    private func creditCardPickerTitle(_ card: CreditCard) -> String {
        if let lastFourDigits = card.lastFourDigits {
            return "\(card.name) •••• \(lastFourDigits)"
        }

        return card.name
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

private struct CreditCardPaymentHistoryRow: View {

    @EnvironmentObject private var store: WalletStore

    let payment: CreditCardPayment

    private var card: CreditCard? {
        store.creditCards.first { $0.id == payment.cardID }
    }

    var body: some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(
                systemName: "creditcard.and.123",
                semanticColor: .creditCards,
                size: 36,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text("\(payment.fromAccountName) -> \(card?.name ?? "Credit Card")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    chip(AppText.transactionChip("Payment", language: store.appLanguage))
                    chip(AppText.transactionChip("Settlement", language: store.appLanguage))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(store.signedDisplayCurrency(payment.amount, prefix: "-"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(PocketWiseSemanticColor.accounts.tint)
                    .lineLimit(1)

                Text(formatDate(payment.paymentDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var title: String {
        store.appLanguage == .arabicEgyptian ? "سداد \(card?.name ?? "كارت ائتمان")" : "Payment to \(card?.name ?? "Credit Card")"
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .pocketWiseChip(semanticColor: .creditCards)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
    }
}

private struct CreditCardPaymentDetailView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let payment: CreditCardPayment

    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?

    private var card: CreditCard? {
        store.creditCards.first { $0.id == payment.cardID }
    }

    var body: some View {
        List {
            Section(store.appLanguage == .arabicEgyptian ? "سداد كارت" : "Card Payment") {
                detailRow("Title", store.appLanguage == .arabicEgyptian ? "سداد \(card?.name ?? "كارت ائتمان")" : "Payment to \(card?.name ?? "Credit Card")")
                detailRow("Amount", store.displayCurrency(payment.amount, maximumFractionDigits: 2))
                detailRow("Date", formatDate(payment.paymentDate))
                detailRow("From Account", payment.fromAccountName)
                detailRow("Card", card?.name ?? "Not found")
            }

            Section(store.appLanguage == .arabicEgyptian ? "التأثير" : "Impact") {
                Text(store.appLanguage == .arabicEgyptian ? "السداد خصم من الحساب المختار وقلل المستحق على الكارت. لا يتحسب كمصروف جديد." : "This payment deducted the selected account and reduced card outstanding. It is not counted as a new expense.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let card {
                    detailRow("Current Outstanding", store.displayCurrency(store.creditCardOutstanding(cardID: card.id), maximumFractionDigits: 2))
                }
            }

            if let note = payment.note,
               !note.isEmpty {
                Section("Note") {
                    Text(note)
                }
            }

            Section {
                if let deleteError {
                    Text(deleteError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "احذف سداد الكارت" : "Delete Card Payment")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "سداد كارت" : "Card Payment")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            store.appLanguage == .arabicEgyptian ? "احذف سداد الكارت؟" : "Delete card payment?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(store.appLanguage == .arabicEgyptian ? "احذف" : "Delete", role: .destructive) {
                if store.deleteCreditCardPayment(payment) {
                    dismiss()
                } else {
                    deleteError = store.appLanguage == .arabicEgyptian ? "تعذر حذف السداد." : "Could not delete payment."
                }
            }

            Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel", role: .cancel) { }
        } message: {
            Text(store.appLanguage == .arabicEgyptian ? "الحذف يرجع المبلغ للحساب ويزود المستحق على الكارت مرة أخرى. لا يغير المصروفات." : "Deleting restores the source account and increases card outstanding again. It does not change spending.")
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter.string(from: date)
    }
}

struct TransactionsView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionsView()
            .environmentObject(WalletStore())
    }
}
