import SwiftUI

struct TodayView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.colorScheme) private var colorScheme
    @Binding private var isAddExpenseSheetActive: Bool
    private let pendingBankSMSImportCount: Int
    private let reviewPendingBankSMSImports: () -> Void

    @State private var addExpenseRoute: AddExpenseRoute?
    @State private var selectedFinancialEvent: FinancialEvent?
    @State private var isAddingFutureItem = false
    @State private var isAddingIncome = false
    @State private var isAddingExpectedIncome = false
    @State private var isAddingRecurringIncome = false
    @State private var isShowingManageIncome = false
    @State private var isAddingTransfer = false
    @State private var isAddingRecurringPayment = false
    @State private var isAddingInstallmentPlan = false
    @State private var isShowingRunwayDetails = false
    @State private var runwaySafeTargetText = ""
    @State private var runwaySafeTargetWasSaved = false
    @State private var runwaySafeTargetError: String?
    @State private var isUpdatingRunwaySafeTargetText = false
    @State private var selectedRecurringPayment: FinancialEvent?
    @State private var selectedInstallmentPlan: InstallmentPlan?
    @State private var selectedUpcomingPayment: FinancialEvent?
    @State private var selectedCreditCardPaymentRoute: CreditCardPaymentRoute?
    @State private var isShowingPeopleDebts = false
    @State private var isShowingGlobalSearch = false
    @State private var selectedRunwayBreakdown: RunwayBreakdownRoute?
    @State private var selectedRunwayInsight: RunwayInsightRoute?
    @State private var isShowingCurrentMonthActualBreakdown = false
    @State private var isShowingQuickAddManager = false
    @State private var isShowingRunwayChart = false
    @State private var isShowingSetupAssistant = false
    @State private var isShowingDataBackup = false
    @State private var isShowingQuickTour = false
    @State private var isPendingImportAttentionActive = false
    @State private var pendingImportAttentionPulse = false
    @FocusState private var isRunwaySafeTargetFocused: Bool
    @AppStorage("wallet_runway_check_target_timestamp") private var runwayTargetTimestamp: Double = 0

    init(
        isAddExpenseSheetActive: Binding<Bool> = .constant(false),
        pendingBankSMSImportCount: Int = 0,
        reviewPendingBankSMSImports: @escaping () -> Void = {}
    ) {
        _isAddExpenseSheetActive = isAddExpenseSheetActive
        self.pendingBankSMSImportCount = pendingBankSMSImportCount
        self.reviewPendingBankSMSImports = reviewPendingBankSMSImports
    }

    private var today: Date {
        Date()
    }

    private var runwayTargetDate: Date {
        if runwayTargetTimestamp > 0 {
            return Date(timeIntervalSince1970: runwayTargetTimestamp)
        }

        return Calendar.current.date(byAdding: .day, value: 90, to: today) ?? today
    }

    private var runwayTargetDateBinding: Binding<Date> {
        Binding(
            get: { runwayTargetDate },
            set: { newValue in
                runwayTargetTimestamp = newValue.timeIntervalSince1970
            }
        )
    }

    private var runwayCheck: RunwayCheckResult {
        store.runwayCheck(targetDate: runwayTargetDate, from: today)
    }

    private var recentEvents: [FinancialEvent] {
        Array(store.recentPaidEvents.prefix(4))
    }

    private var upcomingEvents: [FinancialEvent] {
        Array(store.upcomingEvents.prefix(4))
    }

    private var upcomingCreditCardDueItems: [CreditCardDueItem] {
        let remainingSlots = max(4 - upcomingEvents.count, 0)
        guard remainingSlots > 0 else {
            return []
        }

        return Array(store.creditCardDueItems(referenceDate: today, horizonMonths: store.forecastHorizonMonths).prefix(remainingSlots))
    }

    private var quickAddEvents: [WalletEvent] {
        store.activeWalletEvents.filter { $0.isFavorite && $0.isActive }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {

                    headerSection

                    if pendingBankSMSImportCount > 0 {
                        pendingBankSMSImportCard
                    }

                    if setupGuidanceState == .emptyWallet {
                        freshEmptyWalletCard
                    } else if setupGuidanceState == .incompleteSetup {
                        incompleteSetupCard
                    }

                    primaryActionZone

                    needsAttentionCard

                    quickAddSection

                    runwayCard

                    currentMonthBudgetCard

                    upcomingSection

                    recentActivitySection
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 8)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 28)
            }
            .accessibilityIdentifier("screen.today")
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                runwaySafeTargetText = cleanNumberText(store.runwaySafeBalanceTarget)
            }
            .sheet(item: $addExpenseRoute) { route in
                AddExpenseView(prefilledEvent: route.event)
                    .environmentObject(store)
                    .onAppear {
                        isAddExpenseSheetActive = true
                    }
                    .onDisappear {
                        isAddExpenseSheetActive = false
                    }
            }
            .sheet(isPresented: $isShowingQuickAddManager) {
                QuickAddManagerSheet()
                    .environmentObject(store)
            }
            .sheet(isPresented: $isShowingSetupAssistant) {
                OnboardingWelcomeView(presentationMode: .settings)
                    .environmentObject(store)
            }
            .sheet(isPresented: $isShowingDataBackup) {
                NavigationStack {
                    DataBackupView()
                        .environmentObject(store)
                }
            }
            .sheet(isPresented: $isShowingQuickTour) {
                NavigationStack {
                    QuickTourView()
                        .environmentObject(store)
                }
            }
            .sheet(item: $selectedFinancialEvent) { event in
                TransactionDetailView(event: event)
                    .environmentObject(store)
            }
            .sheet(item: $selectedRecurringPayment) { event in
                RecurringPaymentEditorView(event: event)
                    .environmentObject(store)
            }
            .sheet(item: $selectedInstallmentPlan) { plan in
                InstallmentPlanEditorView(plan: plan)
                    .environmentObject(store)
            }
            .sheet(item: $selectedUpcomingPayment) { event in
                UpcomingPaymentConfirmationSheet(event: event)
                    .environmentObject(store)
            }
            .sheet(item: $selectedCreditCardPaymentRoute) { route in
                CreditCardPaymentView(route: route)
                    .environmentObject(store)
            }
            .sheet(isPresented: $isShowingPeopleDebts) {
                PeopleDebtsView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $isShowingGlobalSearch) {
                GlobalSearchView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $isAddingFutureItem) {
                AddFutureItemView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $isAddingIncome) {
                AddFutureItemView(startsAsIncome: true, startsAsReceivedIncome: true)
                    .environmentObject(store)
            }
            .sheet(isPresented: $isAddingExpectedIncome) {
                AddFutureItemView(startsAsIncome: true, startsAsReceivedIncome: false)
                    .environmentObject(store)
            }
            .sheet(isPresented: $isAddingRecurringIncome) {
                AddFutureItemView(startsAsIncome: true, startsAsReceivedIncome: false, startsAsRecurringIncome: true)
                    .environmentObject(store)
            }
            .sheet(isPresented: $isShowingManageIncome) {
                ManageIncomeView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $isAddingTransfer) {
                AddTransferView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $isAddingRecurringPayment) {
                AddRecurringPaymentView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $isAddingInstallmentPlan) {
                AddInstallmentPlanView()
                    .environmentObject(store)
            }
            .sheet(item: $selectedRunwayBreakdown) { route in
                RunwayBreakdownSheet(
                    route: route,
                    result: runwayCheck,
                    accounts: store.activeAccounts
                )
                .environmentObject(store)
            }
            .sheet(item: $selectedRunwayInsight) { route in
                RunwayInsightSheet(
                    route: route,
                    result: runwayCheck,
                    nextMonthSafetyItems: nextMonthSafetyItems
                )
                .environmentObject(store)
            }
            .sheet(isPresented: $isShowingCurrentMonthActualBreakdown) {
                TodayActualSpendingBreakdownSheet(
                    monthDate: Date(),
                    displayedAmount: currentMonthActualTotal
                )
                .environmentObject(store)
            }
            .sheet(isPresented: $isShowingRunwayChart) {
                NavigationStack {
                    RunwayChartView()
                        .environmentObject(store)
                }
            }
        }
    }
}

// MARK: - Add Expense Route

private struct TodayAttentionItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color
    let route: TodayAttentionRoute?
}

private enum TodayAttentionRoute {
    case upcoming(FinancialEvent)
    case monthlySummary
    case runway
}

struct AddExpenseRoute: Identifiable {
    let id = UUID()
    let event: WalletEvent?
}

private struct QuickAddManagerSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var newName = ""
    @State private var selectedCategoryName = ""
    @State private var selectedSubCategoryName = ""
    @State private var selectedAccountName = ""
    @State private var shouldShowValidation = false

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var quickAddEvents: [WalletEvent] {
        store.activeWalletEvents.filter { $0.isFavorite && $0.isActive }
    }

    private var trimmedNewName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var activeCategories: [Category] {
        store.activeCategories
    }

    private var availableSubcategories: [String] {
        store.activeSubcategories(for: selectedCategoryName)
    }

    private var activeAccounts: [Account] {
        store.activeAccounts
    }

    private var canAdd: Bool {
        !trimmedNewName.isEmpty &&
        activeCategories.contains { $0.name == selectedCategoryName } &&
        availableSubcategories.contains(selectedSubCategoryName) &&
        (selectedAccountName.isEmpty || activeAccounts.contains { $0.name == selectedAccountName }) &&
        !hasDuplicateName
    }

    private var categorySuggestion: CategorySubcategorySuggestion? {
        store.suggestedCategorySubcategory(
            for: CategorySuggestionRequest(
                title: trimmedNewName,
                accountName: selectedAccountName,
                allowedEventTypes: [.expense],
                includeCreditCardPurchases: true
            )
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if quickAddEvents.isEmpty {
                        Text(isArabic ? "لا توجد اختصارات مضافة لليوم." : "No Quick Add items on Today.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(quickAddEvents) { event in
                            HStack(spacing: 10) {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.tertiary)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(event.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(event.categoryName) • \(event.subCategoryName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    removeFromToday(event)
                                } label: {
                                    Text(isArabic ? "إزالة من اليوم" : "Remove from Today")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .onMove(perform: moveQuickAddItems)
                    }
                } header: {
                    Text(isArabic ? "اختصارات اليوم" : "Today Quick Add")
                }

                Section(isArabic ? "إضافة اختصار" : "Add Quick Add") {
                    TextField(isArabic ? "الاسم" : "Name", text: $newName)

                    if shouldShowValidation && trimmedNewName.isEmpty {
                        validationMessage(isArabic ? "اكتب اسم الاختصار" : "Enter a shortcut name.")
                    }

                    if shouldShowValidation && hasDuplicateName {
                        validationMessage(isArabic ? "في اختصار بنفس الاسم" : "Another shortcut already uses this name.")
                    }

                    CategorySubcategoryPickerView(
                        categoryName: $selectedCategoryName,
                        subCategoryName: $selectedSubCategoryName,
                        title: isArabic ? "البند" : "Category",
                        showsValidation: shouldShowValidation,
                        categoryValidationMessage: isArabic ? "اختر بند" : "Choose a category.",
                        subcategoryValidationMessage: isArabic ? "اختر بند فرعي" : "Choose a subcategory.",
                        suggestion: categorySuggestion
                    )
                    .environmentObject(store)

                    if shouldShowValidation && !availableSubcategories.contains(selectedSubCategoryName) {
                        validationMessage(isArabic ? "اختر بند فرعي" : "Choose a subcategory.")
                    }

                    AccountMenuPickerField(
                        title: isArabic ? "الحساب الافتراضي" : "Default Account",
                        selection: $selectedAccountName,
                        accounts: activeAccounts,
                        placeholder: isArabic ? "بدون حساب افتراضي" : "No default account",
                        emptyTitle: isArabic ? "بدون حساب افتراضي" : "No default account"
                    )

                    Button {
                        addQuickAddItem()
                    } label: {
                        Text(isArabic ? "إضافة اختصار" : "Add Quick Add")
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle(isArabic ? "إدارة الاختصارات" : "Manage Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isArabic ? "تمام" : "Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
            .onAppear {
                normalizeSelections()
            }
            .onChange(of: selectedCategoryName) { _, _ in
                normalizeSubcategory()
            }
        }
    }

    private var hasDuplicateName: Bool {
        store.walletEvents.contains {
            $0.name.caseInsensitiveCompare(trimmedNewName) == .orderedSame
        }
    }

    private func normalizeSelections() {
        if !activeCategories.contains(where: { $0.name == selectedCategoryName }) {
            selectedCategoryName = activeCategories.first?.name ?? ""
        }

        normalizeSubcategory()

        if !selectedAccountName.isEmpty,
           !activeAccounts.contains(where: { $0.name == selectedAccountName }) {
            selectedAccountName = ""
        }
    }

    private func normalizeSubcategory() {
        if !availableSubcategories.contains(selectedSubCategoryName) {
            selectedSubCategoryName = availableSubcategories.first ?? ""
        }
    }

    private func addQuickAddItem() {
        shouldShowValidation = true
        guard canAdd else {
            return
        }

        let event = WalletEvent(
            name: trimmedNewName,
            categoryName: selectedCategoryName,
            subCategoryName: selectedSubCategoryName,
            defaultAccountName: selectedAccountName.isEmpty ? nil : selectedAccountName,
            isFavorite: true,
            isActive: true
        )

        var events = store.walletEvents
        events.append(event)
        store.walletEvents = events
        newName = ""
        shouldShowValidation = false
    }

    private func removeFromToday(_ event: WalletEvent) {
        guard let index = store.walletEvents.firstIndex(where: { $0.id == event.id }) else {
            return
        }

        var events = store.walletEvents
        events[index].isFavorite = false
        store.walletEvents = events
    }

    private func moveQuickAddItems(from source: IndexSet, to destination: Int) {
        var favorites = quickAddEvents
        favorites.move(fromOffsets: source, toOffset: destination)

        let favoriteIDs = Set(favorites.map(\.id))
        let otherEvents = store.walletEvents.filter { !favoriteIDs.contains($0.id) }
        store.walletEvents = favorites + otherEvents
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
    }
}

private struct ManageIncomeView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var eventToMarkReceived: FinancialEvent?
    @State private var eventToEdit: FinancialEvent?
    @State private var recurringIncomeToEdit: FinancialEvent?
    @State private var receivedIncomeToReview: FinancialEvent?
    @State private var eventPendingDelete: FinancialEvent?

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var expectedIncome: [FinancialEvent] {
        store.upcomingKnownIncomeEvents()
    }

    private var recurringIncome: [FinancialEvent] {
        store.activeFinancialEvents
            .filter { $0.type == .income && $0.repeatRule != .none }
            .sorted { $0.date < $1.date }
    }

    private var receivedIncome: [FinancialEvent] {
        Array(
            store.activeFinancialEvents
                .filter { $0.type == .income && $0.status == .paid }
                .sorted { $0.date > $1.date }
                .prefix(12)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(isArabic
                         ? "الدخل المتوقع لا يغير رصيد الحساب حتى يتم تسجيله كمستلم."
                         : "Expected income does not change your account balance until it is marked received.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Color.clear
                        .frame(width: 0, height: 0)
                        .accessibilityIdentifier("section.expectedIncome")

                    Text(isArabic
                         ? "اضغط ··· لتسجيل الشهر كمستلم عند وصول الفلوس."
                         : "Tap ··· to mark a month as received when the money arrives.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if expectedIncome.isEmpty {
                        emptyIncomeRow(
                            icon: "calendar.badge.clock",
                            message: isArabic ? "لا يوجد دخل قادم حاليًا." : "No upcoming income right now."
                        )
                    } else {
                        ForEach(expectedIncome) { event in
                            incomeRow(event, icon: "calendar.badge.clock", semanticColor: .accounts) {
                                Button(isArabic ? "تسجيل كمستلم" : "Mark received") {
                                    eventToMarkReceived = event
                                }

                                Button(isArabic ? "تعديل هذا الشهر" : "Edit this month") {
                                    eventToEdit = event
                                }

                                Button(isArabic ? "تخطي / حذف" : "Skip / delete", role: .destructive) {
                                    eventPendingDelete = event
                                }
                            }
                        }
                    }
                } header: {
                    Text(isArabic ? "شهور الدخل المتوقعة" : "Expected income months")
                        .accessibilityIdentifier("section.expectedIncome")
                }

                Section {
                    Color.clear
                        .frame(width: 0, height: 0)
                        .accessibilityIdentifier("section.recurringIncome")

                    Text(isArabic
                         ? "كل قاعدة تنشئ شهور الدخل المتوقعة المعروضة بالأعلى."
                         : "Each rule generates the expected income months listed above.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if recurringIncome.isEmpty {
                        emptyIncomeRow(
                            icon: "repeat.circle.fill",
                            message: isArabic ? "لا توجد قواعد دخل متكرر حاليًا." : "No recurring income rules yet."
                        )
                    } else {
                        ForEach(recurringIncome) { event in
                            incomeRow(event, icon: "repeat.circle.fill", semanticColor: .income) {
                                Button(isArabic ? "تعديل القاعدة" : "Edit rule") {
                                    recurringIncomeToEdit = event
                                }

                                Button(isArabic ? "حذف القاعدة" : "Delete rule", role: .destructive) {
                                    eventPendingDelete = event
                                }
                            }
                        }
                    }
                } header: {
                    Text(isArabic ? "قواعد الدخل المتكرر" : "Recurring income rules")
                        .accessibilityIdentifier("section.recurringIncome")
                }

                Section {
                    Color.clear
                        .frame(width: 0, height: 0)
                        .accessibilityIdentifier("section.receivedIncome")

                    if receivedIncome.isEmpty {
                        emptyIncomeRow(
                            icon: "checkmark.circle.fill",
                            message: isArabic ? "لا يوجد دخل مستلم بعد." : "No received income yet."
                        )
                    } else {
                        ForEach(receivedIncome) { event in
                            Button {
                                receivedIncomeToReview = event
                            } label: {
                                incomeRowContent(event, icon: "checkmark.circle.fill", semanticColor: .success)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text(isArabic ? "دخل تم استلامه" : "Received income")
                        .accessibilityIdentifier("section.receivedIncome")
                }
            }
            .accessibilityIdentifier("sheet.manageIncome")
            .navigationTitle(isArabic ? "إدارة الدخل" : "Manage Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isArabic ? "إغلاق" : "Close") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $eventToMarkReceived) { event in
                MarkIncomeReceivedView(event: event)
                    .environmentObject(store)
            }
            .sheet(item: $eventToEdit) { event in
                EditFinancialEventView(event: event)
                    .environmentObject(store)
            }
            .sheet(item: $recurringIncomeToEdit) { event in
                RecurringPaymentEditorView(event: event)
                    .environmentObject(store)
            }
            .sheet(item: $receivedIncomeToReview) { event in
                TransactionDetailView(event: event)
                    .environmentObject(store)
            }
            .confirmationDialog(
                isArabic ? "حذف هذا الدخل؟" : "Delete this income?",
                isPresented: Binding(
                    get: { eventPendingDelete != nil },
                    set: { if !$0 { eventPendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let eventPendingDelete,
                   let sourceID = eventPendingDelete.sourceRecurringEventID,
                   let series = store.financialEvents.first(where: { $0.id == sourceID }) {
                    Button(isArabic ? "تخطي هذا الشهر" : "Skip this month", role: .destructive) {
                        _ = store.skipRecurringOccurrence(seriesID: sourceID, occurrenceDate: eventPendingDelete.date)
                        self.eventPendingDelete = nil
                    }

                    Button(isArabic ? "حذف الدخل المتكرر بالكامل" : "Delete entire recurring income", role: .destructive) {
                        store.deleteFinancialEvent(series)
                        self.eventPendingDelete = nil
                    }
                } else {
                    Button(isArabic ? "حذف" : "Delete", role: .destructive) {
                        if let eventPendingDelete {
                            store.deleteFinancialEvent(eventPendingDelete)
                        }
                        eventPendingDelete = nil
                    }
                }

                Button(isArabic ? "إلغاء" : "Cancel", role: .cancel) {
                    eventPendingDelete = nil
                }
            } message: {
                if let eventPendingDelete,
                   eventPendingDelete.sourceRecurringEventID != nil {
                    Text(isArabic
                         ? "هذا الدخل جزء من سلسلة متكررة. يمكنك تخطي هذا الشهر فقط أو حذف السلسلة بالكامل."
                         : "This income is part of a recurring series. You can skip this month only or delete the whole series.")
                } else {
                    Text(isArabic
                         ? "سيتم حذف الدخل من التخطيط أو السجل حسب حالته."
                         : "This removes the income from planning or history depending on its status.")
                }
            }
        }
    }

    @ViewBuilder
    private func incomeRow<MenuContent: View>(
        _ event: FinancialEvent,
        icon: String,
        semanticColor: PocketWiseSemanticColor,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) -> some View {
        HStack(spacing: 10) {
            incomeRowContent(event, icon: icon, semanticColor: semanticColor)

            Menu {
                menuContent()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func incomeRowContent(
        _ event: FinancialEvent,
        icon: String,
        semanticColor: PocketWiseSemanticColor
    ) -> some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(systemName: icon, semanticColor: semanticColor, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(incomeTitle(for: event))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(incomeSubtitle(for: event))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(store.displayCurrency(event.amount))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(incomeAmountColor(for: event))
        }
    }

    private func incomeAmountColor(for event: FinancialEvent) -> Color {
        event.status == .paid ? PocketWiseSemanticColor.income.tint : PocketWiseSemanticColor.accounts.tint
    }

    private func emptyIncomeRow(icon: String, message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func incomeSubtitle(for event: FinancialEvent) -> String {
        if event.repeatRule != .none && event.sourceRecurringEventID == nil {
            return incomePlanSubtitle(for: event)
        }

        let status = incomeOccurrenceStatusText(for: event)
        return [
            status,
            event.accountName,
            formatDate(event.date)
        ]
        .compactMap { $0 }
        .joined(separator: " • ")
    }

    private func incomeTitle(for event: FinancialEvent) -> String {
        if event.sourceRecurringEventID != nil {
            return "\(event.title) — \(formatMonth(event.date))"
        }

        return event.title
    }

    private func incomeOccurrenceStatusText(for event: FinancialEvent) -> String {
        if event.status == .paid {
            return isArabic ? "تم الاستلام" : "Received"
        }

        if event.sourceRecurringEventID != nil {
            return isArabic ? "شهر مخطط" : "Planned month"
        }

        return isArabic ? "متوقع" : "Expected"
    }

    private func incomePlanSubtitle(for event: FinancialEvent) -> String {
        [
            incomePlanKindText(for: event),
            event.accountName,
            incomePlanStartText(for: event),
            incomePlanEndText(for: event)
        ]
        .compactMap { $0 }
        .joined(separator: " • ")
    }

    private func incomePlanKindText(for event: FinancialEvent) -> String {
        switch event.effectiveRecurringAmountMode {
        case .fixedAmount:
            return isArabic ? "خطة شهرية ثابتة" : "Fixed monthly plan"
        case .variableEachMonth:
            return isArabic ? "خطة شهرية متغيرة" : "Variable monthly plan"
        case .estimatedUntilConfirmed:
            return isArabic ? "خطة تقديرية" : "Estimated plan"
        }
    }

    private func incomePlanStartText(for event: FinancialEvent) -> String {
        isArabic ? "بدأت \(formatMonth(event.date))" : "Started \(formatMonth(event.date))"
    }

    private func incomePlanEndText(for event: FinancialEvent) -> String? {
        switch event.effectiveRecurringEndKind {
        case .never:
            return nil
        case .afterNumberOfPayments:
            guard let count = event.recurringEndPaymentCount else {
                return nil
            }

            return isArabic ? "تنتهي بعد \(count) شهور" : "Ends after \(count) months"
        case .onDate:
            guard let date = event.recurringEndDate else {
                return nil
            }

            return isArabic ? "تنتهي \(formatMonth(date))" : "Ends \(formatMonth(date))"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = isArabic ? Locale(identifier: "ar_EG") : Locale(identifier: "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = isArabic ? Locale(identifier: "ar_EG") : Locale(identifier: "en_US")
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}

private enum RunwaySafeTargetParseError: Error {
    case invalid
}

// MARK: - Sections

private extension TodayView {

    var currentMonthComponents: (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        return (components.year ?? 2026, components.month ?? 1)
    }

    var currentMonthBudget: WalletMonthlyBudget? {
        store.monthlyBudget(year: currentMonthComponents.year, month: currentMonthComponents.month)
    }

    var currentMonthActualSpending: [String: Double] {
        store.actualSpendingByCategory(year: currentMonthComponents.year, month: currentMonthComponents.month)
    }

    var currentMonthPlannedTotal: Double {
        currentMonthBudget?.items.map { $0.plannedAmount }.reduce(0, +) ?? 0
    }

    var currentMonthActualTotal: Double {
        currentMonthActualSpending.values.reduce(0, +)
    }

    var currentMonthPercentUsed: Double {
        guard currentMonthPlannedTotal > 0 else {
            return 0
        }

        return currentMonthActualTotal / currentMonthPlannedTotal
    }

    var currentMonthOverBudgetCategoryCount: Int {
        (currentMonthBudget?.items ?? []).filter { item in
            (currentMonthActualSpending[item.categoryName] ?? 0) > item.plannedAmount
        }.count
    }

    var currentMonthBudgetStatus: TodayBudgetStatus {
        guard currentMonthPlannedTotal > 0 else {
            return .notPlanned
        }

        if currentMonthActualTotal > currentMonthPlannedTotal {
            return .overBudget
        }

        if currentMonthActualTotal > currentMonthPlannedTotal * 0.8 {
            return .watch
        }

        return .onTrack
    }

    private enum SetupGuidanceState: Equatable {
        case emptyWallet
        case incompleteSetup
        case none
    }

    var hasMeaningfulSetupData: Bool {
        !store.activeFinancialEvents.isEmpty ||
        !store.activeWalletEvents.isEmpty ||
        !store.activeCreditCardPurchases.isEmpty ||
        !store.activeCreditCardPayments.isEmpty ||
        !store.activeInstallmentPlans.isEmpty ||
        !store.activePersonDebts.isEmpty ||
        !store.activePersonDebtEntries.isEmpty ||
        store.activeMonthlyBudgets.contains { budget in
            budget.items.contains { $0.plannedAmount > 0 }
        }
    }

    private var setupGuidanceState: SetupGuidanceState {
        guard !hasMeaningfulSetupData else { return .none }
        if store.activeAccounts.isEmpty && store.activeCreditCards.isEmpty {
            return .emptyWallet
        }
        return .incompleteSetup
    }

    var attentionItems: [TodayAttentionItem] {
        var items: [TodayAttentionItem] = []
        let todayStart = Calendar.current.startOfDay(for: Date())
        let dueSoonEnd = Calendar.current.date(byAdding: .day, value: 7, to: todayStart) ?? Date()

        let dueSoon = store.upcomingEvents
            .filter { event in
                event.type != .income &&
                event.type != .transfer &&
                event.status != .paid &&
                event.status != .cancelled &&
                event.status != .skipped &&
                event.date < dueSoonEnd
            }
            .sorted { $0.date < $1.date }

        let isAr = store.appLanguage == .arabicEgyptian

        if let overdue = dueSoon.first(where: { $0.date < todayStart }) {
            items.append(
                TodayAttentionItem(
                    title: isAr ? "متأخر: \(overdue.title)" : "Overdue: \(overdue.title)",
                    subtitle: isAr ? "\(formatCurrency(overdue.amount)) كان مستحقًا \(formatDate(overdue.date))" : "\(formatCurrency(overdue.amount)) was due \(formatDate(overdue.date))",
                    systemImage: "exclamationmark.triangle.fill",
                    color: .red,
                    route: .upcoming(overdue)
                )
            )
        } else if let nextDue = dueSoon.first {
            items.append(
                TodayAttentionItem(
                    title: isAr ? "قريبًا: \(nextDue.title)" : "Due soon: \(nextDue.title)",
                    subtitle: isAr ? "\(formatCurrency(nextDue.amount)) مستحق \(formatDate(nextDue.date))" : "\(formatCurrency(nextDue.amount)) due \(formatDate(nextDue.date))",
                    systemImage: "calendar.badge.exclamationmark",
                    color: .orange,
                    route: .upcoming(nextDue)
                )
            )
        }

        if currentMonthBudgetStatus == .overBudget {
            items.append(
                TodayAttentionItem(
                    title: isAr ? "الشهر ده تجاوز الميزانية" : "This month is over budget",
                    subtitle: isAr ? "\(currentMonthOverBudgetCategoryCount) تصنيفات تجاوزت الخطة." : "\(currentMonthOverBudgetCategoryCount) categories are over plan.",
                    systemImage: "chart.line.downtrend.xyaxis",
                    color: .red,
                    route: .monthlySummary
                )
            )
        } else if currentMonthBudgetStatus == .watch {
            items.append(
                TodayAttentionItem(
                    title: isAr ? "الميزانية بدأت تضيق" : "Budget is getting tight",
                    subtitle: isAr ? "\(Int((currentMonthPercentUsed * 100).rounded()))٪ من خطة الشهر اتصرفت." : "\(Int((currentMonthPercentUsed * 100).rounded()))% of this month's plan is used.",
                    systemImage: "gauge.with.dots.needle.67percent",
                    color: .orange,
                    route: .monthlySummary
                )
            )
        }

        if runwayCheck.status != .safe {
            items.append(
                TodayAttentionItem(
                    title: store.appLanguage == .arabicEgyptian ? "اختبار الأمان محتاج مراجعة" : "Runway check needs review",
                    subtitle: runwayAttentionSubtitle,
                    systemImage: "wallet.pass",
                    color: .orange,
                    route: .runway
                )
            )
        }

        return Array(items.prefix(3))
    }

    var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AppText.greeting(language: store.appLanguage, displayName: store.displayName))
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(AppText.readySubtitle(store.appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                TodayCircleIconButton(
                    systemImage: "magnifyingglass",
                    accessibilityLabel: store.appLanguage == .arabicEgyptian ? "بحث" : "Search"
                ) {
                    isShowingGlobalSearch = true
                }

                NavigationLink {
                    AccountManagementView()
                        .environmentObject(store)
                } label: {
                    TodayHeaderBalanceSummary(
                        title: AppText.available(store.appLanguage),
                        value: formatCurrency(runwayCheck.availableCash),
                        actionText: AppText.manageAccounts(store.appLanguage)
                    )
                }
                .buttonStyle(.plain)

                TodayCircleIconButton(
                    systemImage: store.hideBalances ? "eye.slash.fill" : "eye.fill",
                    accessibilityLabel: store.hideBalances ? AppText.showBalances(store.appLanguage) : AppText.hideBalances(store.appLanguage)
                ) {
                    store.toggleHideBalances()
                }
            }
        }
        .pocketWiseCard(semanticColor: .accounts, padding: 14, cornerRadius: 18, showsBorder: true)
    }

    var freshEmptyWalletCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                PocketWiseIconBadge(
                    systemName: PocketWiseSemanticColor.setup.defaultIconName,
                    semanticColor: .setup,
                    size: 40,
                    cornerRadius: 12
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(store.appLanguage == .arabicEgyptian ? "أهلًا بك في WalletBoard" : "Welcome to WalletBoard")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(store.appLanguage == .arabicEgyptian ? "ابدأ بإعداد المحافظ، الدخل، الالتزامات، والميزانيات عشان تخطط فلوسك بوضوح." : "Set up your wallets, income, obligations, and budgets to start planning your money clearly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 10) {
                Button {
                    isShowingSetupAssistant = true
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "افتح مساعد الإعداد" : "Open Setup Assistant", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    isShowingDataBackup = true
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "استيراد نسخة احتياطية" : "Import Backup", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    isShowingQuickTour = true
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "ابدأ جولة سريعة" : "Start Quick Tour", systemImage: "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .pocketWiseCard(semanticColor: .setup, padding: 16, cornerRadius: 18, showsBorder: true, showsShadow: true)
    }

    var incompleteSetupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                PocketWiseIconBadge(
                    systemName: "arrow.forward.circle.fill",
                    semanticColor: .setup,
                    size: 40,
                    cornerRadius: 12
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(store.appLanguage == .arabicEgyptian ? "واصل إعداد WalletBoard" : "Continue setting up WalletBoard")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(store.appLanguage == .arabicEgyptian ? "أضف دخل، التزامات، مدفوعات متكررة، أو ميزانيات عشان WalletBoard يبدأ يخطط فلوسك بوضوح." : "Add income, obligations, recurring payments, or budgets so WalletBoard can start planning your money clearly.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(spacing: 10) {
                Button {
                    isShowingSetupAssistant = true
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "واصل الإعداد" : "Continue Setup", systemImage: "arrow.forward.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    isShowingDataBackup = true
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "استيراد نسخة احتياطية" : "Import Backup", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    isShowingQuickTour = true
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "ابدأ جولة سريعة" : "Start Quick Tour", systemImage: "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .pocketWiseCard(semanticColor: .setup, padding: 16, cornerRadius: 18, showsBorder: true, showsShadow: true)
    }

    var runwayCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            Button {
                selectedRunwayInsight = .overview
            } label: {
                HStack(spacing: 12) {
                    PocketWiseIconBadge(
                        systemName: "chart.line.downtrend.xyaxis",
                        semanticColor: runwayCheck.status == .safe ? .accounts : .warning,
                        size: 42,
                        cornerRadius: 12
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.appLanguage == .arabicEgyptian ? "خريطة الكاش" : "Cash runway")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(safeUntilMainText)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(runwayMainResultColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    statusBadge
                }
            }
            .buttonStyle(.plain)

            DatePicker(
                AppText.targetDate(store.appLanguage),
                selection: runwayTargetDateBinding,
                displayedComponents: .date
            )
            .font(.caption)
            .datePickerStyle(.compact)
            .pocketWiseInputField(semanticColor: .accounts)

            VStack(alignment: .leading, spacing: 6) {
                safeUntilSummaryLine(
                    title: AppText.availableNow(store.appLanguage),
                    value: formatCurrency(runwayCheck.availableCash),
                    breakdownRoute: .startingBalance
                )

                safeUntilSummaryLine(
                    title: AppText.keepAtLeast(store.appLanguage),
                    value: store.runwaySafeBalanceTarget > 0 ? formatCurrency(store.runwaySafeBalanceTarget) : noSafeTargetSetText
                )

                safeUntilSummaryLine(
                    title: store.appLanguage == .arabicEgyptian ? "الشهور الجاية" : "Next months",
                    value: nextMonthsSafetySummaryText,
                    insightRoute: .nextMonths
                )
            }
            .pocketWiseCard(semanticColor: .accounts, padding: 10, cornerRadius: 12, showsBorder: true)

            NavigationLink {
                AppPreferencesView()
                    .environmentObject(store)
            } label: {
                TodayChevronInfoRow(
                    title: AppText.incomeMode(store.appLanguage),
                    value: incomeModeSummaryText
                )
            }
            .buttonStyle(.plain)

            if let salaryWarningText {
                NavigationLink {
                    AppPreferencesView()
                        .environmentObject(store)
                } label: {
                Text(salaryWarningText)
                        .font(.caption)
                        .foregroundStyle(PocketWiseSemanticColor.warning.tint)
                }
                .buttonStyle(.plain)
            }

            runwaySafeBalanceTargetEditor

            HStack(spacing: 12) {
                TodaySmallMetricCard(
                    title: AppText.lowestCashReach(store.appLanguage),
                    value: formatCurrency(runwayCheck.lowestExpectedBalance)
                ) {
                    selectedRunwayInsight = .lowestBalance
                }

                if runwayCheck.shortfallToStaySafe > 0 {
                    TodaySmallMetricCard(
                        title: store.appLanguage == .arabicEgyptian ? "محتاج \(formatCurrency(runwayCheck.shortfallToStaySafe)) زيادة عشان تفضل آمن" : "You need \(formatCurrency(runwayCheck.shortfallToStaySafe)) more to stay safe",
                        value: formatCurrency(runwayCheck.shortfallToStaySafe)
                    ) {
                        selectedRunwayInsight = .shortfall
                    }
                }
            }

            if let nextCashInflow = runwayCheck.nextCashInflow {
                Button {
                    selectedRunwayBreakdown = .futureInflows
                } label: {
                    Text(nextCashInflowText(nextCashInflow))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            DisclosureGroup(
                isExpanded: $isShowingRunwayDetails,
                content: {
                    runwayDetailsSection
                },
                label: {
                    Text(AppText.whatsIncluded(store.appLanguage))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            )
            .font(.caption)

            Divider()

            Button {
                isShowingRunwayChart = true
            } label: {
                HStack {
                    Label(AppText.viewRunwayMap(store.appLanguage), systemImage: "chart.line.downtrend.xyaxis")
                        .font(.footnote)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .pocketWiseCard(semanticColor: .accounts, padding: 14, cornerRadius: 18, showsBorder: true, showsShadow: true)
    }

    var currentMonthBudgetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppText.thisMonth(store.appLanguage))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(formatMonth(Date()))
                            .font(.headline)
                            .fontWeight(.semibold)
                    }

                    Spacer()

                    TodayBudgetStatusPill(
                        text: currentMonthBudgetStatus.title,
                        color: currentMonthBudgetStatus.color
                    )
                }

                if currentMonthPlannedTotal <= 0 {
                    Text(store.appLanguage == .arabicEgyptian ? "لسه مفيش ميزانية للشهر ده." : "No budget planned for this month.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        MonthlyBudgetView()
                            .environmentObject(store)
                    } label: {
                        HStack(spacing: 6) {
                            Text(store.appLanguage == .arabicEgyptian ? "افتح ميزانية الشهر" : "Open Monthly Budget")
                                .font(.caption)
                                .fontWeight(.semibold)

                            Image(systemName: "chevron.forward")
                                .font(.caption2)
                        }
                        .foregroundStyle(PocketWiseSemanticColor.budgets.tint)
                    }
                    .buttonStyle(.plain)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int((currentMonthPercentUsed * 100).rounded()))% used")
                                .font(.title3)
                                .fontWeight(.bold)

                            Spacer()

                            Text("\(currentMonthOverBudgetCategoryCount) over")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ProgressView(value: min(currentMonthPercentUsed, 1))
                            .tint(currentMonthBudgetStatus.color)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            Button {
                                isShowingCurrentMonthActualBreakdown = true
                            } label: {
                                TodaySourceMetricButton(
                                    title: store.appLanguage == .arabicEgyptian ? "المدفوع" : "Actual",
                                    value: formatCurrency(currentMonthActualTotal),
                                    subtitle: store.appLanguage == .arabicEgyptian ? "معاملات الشهر الحالي" : "This month transactions",
                                    color: PocketWiseSemanticColor.spending.tint,
                                    semanticColor: .spending
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                MonthlyBudgetView()
                                    .environmentObject(store)
                            } label: {
                                TodaySourceMetricButton(
                                    title: store.appLanguage == .arabicEgyptian ? "المخطط" : "Planned",
                                    value: formatCurrency(currentMonthPlannedTotal),
                                    subtitle: store.appLanguage == .arabicEgyptian ? "ميزانية الشهر الحالي" : "Current month budget",
                                    color: PocketWiseSemanticColor.budgets.tint,
                                    semanticColor: .budgets
                                )
                            }
                            .buttonStyle(.plain)

                            let difference = currentMonthPlannedTotal - currentMonthActualTotal

                            NavigationLink {
                                MonthlySummaryView()
                                    .environmentObject(store)
                            } label: {
                                TodaySourceMetricButton(
                                    title: difference >= 0
                                        ? (store.appLanguage == .arabicEgyptian ? "المتبقي" : "Remaining")
                                        : (store.appLanguage == .arabicEgyptian ? "فوق الخطة" : "Over"),
                                    value: formatCurrency(abs(difference)),
                                    subtitle: store.appLanguage == .arabicEgyptian ? "ملخص الشهر" : "Monthly summary",
                                    color: difference >= 0 ? PocketWiseSemanticColor.success.tint : PocketWiseSemanticColor.danger.tint,
                                    semanticColor: difference >= 0 ? .success : .danger
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        NavigationLink {
                            MonthlySummaryView()
                                .environmentObject(store)
                        } label: {
                            HStack(spacing: 6) {
                                Text(store.appLanguage == .arabicEgyptian ? "شوف ملخص الشهر" : "View Monthly Summary")
                                .font(.caption)
                                .fontWeight(.semibold)

                                Image(systemName: "chevron.forward")
                                    .font(.caption2)
                            }
                            .foregroundStyle(PocketWiseSemanticColor.budgets.tint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .pocketWiseCard(semanticColor: .budgets, padding: 14, cornerRadius: 18, showsBorder: true, showsShadow: true)
    }

    var primaryActionZone: some View {
        VStack(spacing: 10) {
            TodayPrimaryActionButton(
                title: AppText.addExpense(store.appLanguage)
            ) {
                addExpenseRoute = AddExpenseRoute(event: nil)
            }

            HStack(spacing: 10) {
                TodaySecondaryActionButton(
                    title: AppText.addTransfer(store.appLanguage),
                    icon: "arrow.left.arrow.right.circle.fill",
                    semanticColor: .accounts
                ) {
                    isAddingTransfer = true
                }

                Menu {
                    Button {
                        isAddingIncome = true
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "سجّل دخل مستلم" : "Log received income", systemImage: "checkmark.circle.fill")
                    }

                    Button {
                        isAddingExpectedIncome = true
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "خطط دخل متوقع" : "Plan expected income", systemImage: "calendar.badge.clock")
                    }

                    Button {
                        isAddingRecurringIncome = true
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "اضبط مرتب متكرر" : "Set recurring salary", systemImage: "repeat.circle.fill")
                    }

                    Divider()

                    Button {
                        isShowingManageIncome = true
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "إدارة مصادر الدخل" : "Manage income sources", systemImage: "tray.full.fill")
                    }
                    .accessibilityIdentifier("button.manageIncome")
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(AppText.addIncome(store.appLanguage))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(PocketWiseSemanticColor.income.tint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(PocketWiseTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(PocketWiseSemanticColor.income.borderColor(for: colorScheme), lineWidth: 1)
                    )
                }

                Menu {
                    Button {
                        isAddingFutureItem = true
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "خطط دفعة قادمة" : "Plan upcoming payment", systemImage: "calendar.badge.plus")
                    }

                    Button {
                        isAddingRecurringPayment = true
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "أضف دفعة متكررة" : "Add recurring payment", systemImage: "calendar.badge.clock")
                    }

                    Button {
                        isAddingInstallmentPlan = true
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "أضف خطة تقسيط" : "Add installment plan", systemImage: "creditcard.and.123")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "ellipsis.circle.fill")
                        Text(AppText.more(store.appLanguage))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(PocketWiseSemanticColor.setup.tint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(PocketWiseTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(PocketWiseSemanticColor.setup.borderColor(for: colorScheme), lineWidth: 1)
                    )
                }
            }
        }
    }

    var needsAttentionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            TodaySectionTitle(title: AppText.needsAttention(store.appLanguage))

            if attentionItems.isEmpty {
                TodayIconMessageRow(
                    systemImage: "checkmark.circle.fill",
                    message: store.appLanguage == .arabicEgyptian ? "تمام، مفيش حاجة مستعجلة دلوقتي." : "All clear right now.",
                    color: .green
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(attentionItems) { item in
                        attentionItemRow(item)
                    }
                }
            }
        }
        .pocketWiseCard(semanticColor: .warning, padding: 14, cornerRadius: 18, showsBorder: true, showsShadow: true)
    }

    var pendingBankSMSImportCard: some View {
        Button {
            reviewPendingBankSMSImports()
        } label: {
            HStack(spacing: 12) {
                PocketWiseIconBadge(
                    systemName: "tray.and.arrow.down.fill",
                    semanticColor: .spending,
                    size: 38
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.appLanguage == .arabicEgyptian ? "واردات SMS معلقة" : "Pending SMS imports")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(pendingBankSMSImportCount == 1
                         ? (store.appLanguage == .arabicEgyptian ? "معاملة واحدة جاهزة للمراجعة." : "1 transaction is ready for review.")
                         : (store.appLanguage == .arabicEgyptian ? "\(pendingBankSMSImportCount) معاملات جاهزة للمراجعة." : "\(pendingBankSMSImportCount) transactions are ready for review."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(pendingBankSMSImportCount > 9 ? "9+" : "\(pendingBankSMSImportCount)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 26, minHeight: 26)
                    .background(PocketWiseSemanticColor.spending.tint)
                    .clipShape(Capsule())
                    .accessibilityLabel(
                        pendingBankSMSImportCount == 1
                        ? (store.appLanguage == .arabicEgyptian ? "معاملة معلقة واحدة" : "1 pending import")
                        : (store.appLanguage == .arabicEgyptian ? "\(pendingBankSMSImportCount) معاملات معلقة" : "\(pendingBankSMSImportCount) pending imports")
                    )

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pocketWiseCard(semanticColor: .spending, padding: 14, cornerRadius: 18, showsBorder: true, showsShadow: true)
        .scaleEffect(isPendingImportAttentionActive && pendingImportAttentionPulse ? 1.012 : 1)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    PocketWiseSemanticColor.spending.tint.opacity(
                        isPendingImportAttentionActive
                        ? (pendingImportAttentionPulse ? 0.75 : 0.30)
                        : 0.24
                    ),
                    lineWidth: isPendingImportAttentionActive ? 1.6 : 1
                )
        )
        .shadow(
            color: PocketWiseSemanticColor.spending.tint.opacity(
                isPendingImportAttentionActive
                ? (pendingImportAttentionPulse ? 0.24 : 0.10)
                : 0.08
            ),
            radius: isPendingImportAttentionActive ? (pendingImportAttentionPulse ? 18 : 10) : 8,
            x: 0,
            y: 8
        )
        .animation(.easeInOut(duration: 0.9), value: pendingImportAttentionPulse)
        .task(id: pendingBankSMSImportCount) {
            await runPendingImportAttentionAnimation()
        }
    }

    private func runPendingImportAttentionAnimation() async {
        guard pendingBankSMSImportCount > 0 else {
            isPendingImportAttentionActive = false
            pendingImportAttentionPulse = false
            return
        }

        isPendingImportAttentionActive = true
        pendingImportAttentionPulse = false

        withAnimation(.easeInOut(duration: 0.9).repeatCount(4, autoreverses: true)) {
            pendingImportAttentionPulse = true
        }

        try? await Task.sleep(nanoseconds: 4_200_000_000)

        guard !Task.isCancelled else {
            return
        }

        withAnimation(.easeOut(duration: 0.35)) {
            isPendingImportAttentionActive = false
            pendingImportAttentionPulse = false
        }
    }

    @ViewBuilder
    func attentionItemRow(_ item: TodayAttentionItem) -> some View {
        if let route = item.route, case .upcoming(let event) = route, isPayable(event) {
            HStack(spacing: 8) {
                NavigationLink {
                    upcomingSourceDestination(event)
                } label: {
                    TodayAttentionRow(
                        title: item.title,
                        subtitle: item.subtitle,
                        systemImage: item.systemImage,
                        color: item.color
                    )
                }
                .buttonStyle(.plain)

                Button {
                    selectedUpcomingPayment = event
                } label: {
                    Text(AppText.pay(store.appLanguage))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .pocketWiseChip(semanticColor: .success)
                }
                .buttonStyle(.plain)
            }
        } else if let route = item.route {
            NavigationLink {
                attentionDestination(for: route)
            } label: {
                TodayAttentionRow(
                    title: item.title,
                    subtitle: item.subtitle,
                    systemImage: item.systemImage,
                    color: item.color
                )
            }
            .buttonStyle(.plain)
        } else {
            TodayAttentionRow(
                title: item.title,
                subtitle: item.subtitle,
                systemImage: item.systemImage,
                color: item.color
            )
        }
    }

    var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(AppText.quickAdd(store.appLanguage))
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Button {
                    isShowingQuickAddManager = true
                } label: {
                    Text(store.appLanguage == .arabicEgyptian ? "إدارة" : "Manage")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
            }

            if quickAddEvents.isEmpty {
                Text(store.appLanguage == .arabicEgyptian ? "علّم مصاريفك المتكررة كمفضلة عشان تظهر هنا." : "Favorite common expenses to show them here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(quickAddEvents) { event in
                            TodayQuickAddTile(
                                name: event.name,
                                subcategoryName: event.subCategoryName,
                                iconName: iconName(for: event.name)
                            ) {
                                addExpenseRoute = AddExpenseRoute(event: event)
                            }
                        }
                    }
                }
            }
        }
    }

    var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TodaySectionTitle(title: AppText.upcoming(store.appLanguage))

            VStack(spacing: 10) {
                ForEach(upcomingEvents) { event in
                    upcomingEventRow(event)
                }

                ForEach(upcomingCreditCardDueItems) { dueItem in
                    creditCardDueRow(dueItem)
                }
            }
        }
    }

    var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TodaySectionTitle(title: AppText.recentActivity(store.appLanguage))

            VStack(spacing: 10) {
                ForEach(recentEvents) { event in
                    Button {
                        selectedFinancialEvent = event
                    } label: {
                        TodayRecentEventRow(
                            title: event.title,
                            classification: classificationText(for: event),
                            paymentLabel: paymentMethodLabel(for: event),
                            amountText: formatCurrency(event.amount),
                            dateText: formatDate(event.date),
                            iconName: iconName(for: event.title)
                        )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Components

private extension TodayView {

    var statusBadge: some View {
        TodayStatusBadge(
            text: runwayStatusText,
            color: runwayMainResultColor
        )
    }

    var runwayStatusText: String {
        switch runwayCheck.status {
        case .safe:
            return store.appLanguage == .arabicEgyptian ? "آمن" : "Safe"
        case .notSafe:
            return store.appLanguage == .arabicEgyptian ? "مش آمن" : "Not Safe"
        case .cashShortage:
            return store.appLanguage == .arabicEgyptian ? "عجز كاش" : "Cash Shortage"
        case .planIncomplete:
            return store.appLanguage == .arabicEgyptian ? "الخطة ناقصة" : "Incomplete"
        }
    }

    var safeUntilMainText: String {
        if let dangerDate = runwayCheck.dangerDate {
            let todayStart = Calendar.current.startOfDay(for: today)
            let dangerStart = Calendar.current.startOfDay(for: dangerDate)

            guard dangerStart > todayStart,
                  let safeDate = Calendar.current.date(byAdding: .day, value: -1, to: dangerStart) else {
                return store.appLanguage == .arabicEgyptian ? "مش آمن اليوم" : "Not safe today"
            }

            return formatDate(safeDate)
        }

        if runwayCheck.status == .planIncomplete,
           let incompleteDate = runwayCheck.planIncompleteAfter {
            return store.appLanguage == .arabicEgyptian ? "الخطة ناقصة بعد \(formatMonth(incompleteDate))" : "Plan incomplete after \(formatMonth(incompleteDate))"
        }

        return store.appLanguage == .arabicEgyptian
            ? "آمن لحد \(formatDate(runwayCheck.calculationEndDate))"
            : "Safe through \(formatDate(runwayCheck.calculationEndDate))"
    }

    var nextMonthsSafetySummaryText: String {
        nextMonthSafetyItems
            .map { item in
                "\(formatShortMonth(item.monthStart)) \(item.status.title(language: store.appLanguage))"
            }
            .joined(separator: " · ")
    }

    var nextMonthSafetyItems: [MonthSafetyItem] {
        let calendar = Calendar.current
        let currentMonthStart = startOfMonth(today)

        return (0..<3).compactMap { offset in
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: currentMonthStart),
                  let monthEnd = endOfMonth(monthStart) else {
                return nil
            }

            let result = store.runwayCheck(targetDate: monthEnd, from: today)
            return MonthSafetyItem(
                monthStart: monthStart,
                status: monthSafetyStatus(lowestProjectedBalance: result.lowestExpectedBalance)
            )
        }
    }

    func monthSafetyStatus(lowestProjectedBalance: Double) -> MonthSafetyStatus {
        let minimumSafeBalance = store.runwaySafeBalanceTarget
        let buffer = lowestProjectedBalance - minimumSafeBalance
        let tightThreshold = max(minimumSafeBalance * 0.10, 1_000)

        if buffer < 0 {
            return .risk
        }

        if buffer <= tightThreshold {
            return .tight
        }

        return .safe
    }

    var incomeModeSummaryText: String {
        switch store.incomeMode {
        case .noSalaryUntilDate:
            if let date = store.salaryResumeDate {
                return store.appLanguage == .arabicEgyptian ? "مفيش مرتب لحد \(formatMonth(date))" : "No salary until \(formatMonth(date))"
            }
            return store.incomeMode.title(language: store.appLanguage)
        case .vacationUnpaidPeriod:
            if let date = store.salaryResumeDate {
                return store.appLanguage == .arabicEgyptian ? "إجازة / بدون مرتب لحد \(formatMonth(date))" : "Vacation / unpaid until \(formatMonth(date))"
            }
            return store.incomeMode.title(language: store.appLanguage)
        case .regularSalaryActive, .irregularIncome, .unknown:
            return store.incomeMode.title(language: store.appLanguage)
        }
    }

    var noDatedRunwayItemsText: String? {
        guard runwayCheck.breakdown.futureCashInflowCount == 0,
              runwayCheck.breakdown.datedExpenseCount == 0,
              runwayCheck.breakdown.recurringInstallmentCount == 0 else {
            return nil
        }

        return store.appLanguage == .arabicEgyptian ? "لا توجد بنود مؤكدة بتاريخ قبل أو في هذا اليوم." : "No dated cash movements found before this date."
    }

    var noSafeTargetSetText: String {
        AppText.notSet(store.appLanguage)
    }

    var saveButtonText: String {
        AppText.save(store.appLanguage)
    }

    var savedButtonText: String {
        AppText.saved(store.appLanguage)
    }

    var runwaySafeTargetHasChanges: Bool {
        switch parsedRunwaySafeTargetAmount() {
        case .success(let amount):
            return abs(amount - store.runwaySafeBalanceTarget) > 0.005
        case .failure:
            return !runwaySafeTargetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func saveRunwaySafeBalanceTarget() {
        switch parsedRunwaySafeTargetAmount() {
        case .success(let amount):
            store.updateRunwaySafeBalanceTarget(amount)
            let normalizedText = cleanNumberText(store.runwaySafeBalanceTarget)
            if runwaySafeTargetText != normalizedText {
                isUpdatingRunwaySafeTargetText = true
                runwaySafeTargetText = normalizedText
            } else {
                isUpdatingRunwaySafeTargetText = false
            }
            runwaySafeTargetError = nil
            runwaySafeTargetWasSaved = true
            isRunwaySafeTargetFocused = false
        case .failure:
            runwaySafeTargetWasSaved = false
            runwaySafeTargetError = store.appLanguage == .arabicEgyptian ? "اكتب رقم صحيح لحد الأمان." : "Enter a valid safe balance target."
            isRunwaySafeTargetFocused = true
        }
    }

    func parsedRunwaySafeTargetAmount() -> Result<Double, RunwaySafeTargetParseError> {
        let trimmedText = runwaySafeTargetText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return .success(0)
        }

        let allowedCharacters = CharacterSet(charactersIn: "0123456789.,")
        guard trimmedText.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return .failure(.invalid)
        }

        let normalizedText = normalizedAmountText(trimmedText)
        guard let amount = Double(normalizedText), amount.isFinite else {
            return .failure(.invalid)
        }

        return .success(max(amount, 0))
    }

    func normalizedAmountText(_ text: String) -> String {
        let commaIndexes = text.indices.filter { text[$0] == "," }
        let dotIndexes = text.indices.filter { text[$0] == "." }

        if let lastComma = commaIndexes.last,
           let lastDot = dotIndexes.last {
            let decimalSeparator = lastComma > lastDot ? "," : "."
            let groupingSeparator = decimalSeparator == "," ? "." : ","
            return text
                .replacingOccurrences(of: groupingSeparator, with: "")
                .replacingOccurrences(of: decimalSeparator, with: ".")
        }

        if !commaIndexes.isEmpty {
            return normalizedSingleSeparatorAmountText(text, separator: ",")
        }

        if !dotIndexes.isEmpty {
            return normalizedSingleSeparatorAmountText(text, separator: ".")
        }

        return text
    }

    func normalizedSingleSeparatorAmountText(_ text: String, separator: String) -> String {
        let parts = text.split(separator: Character(separator), omittingEmptySubsequences: false)
        guard parts.count > 1 else {
            return text
        }

        let lastPartCount = parts.last?.count ?? 0
        if parts.count > 2 || lastPartCount == 3 {
            return parts.joined()
        }

        return parts.joined(separator: ".")
    }

    var runwayDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let noDatedRunwayItemsText {
                Text(noDatedRunwayItemsText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            detailMetricRow(
                title: store.appLanguage == .arabicEgyptian ? "الرصيد الحالي" : "Starting balance",
                value: formatCurrency(runwayCheck.availableCash),
                route: .startingBalance
            )
            detailMetricRow(
                title: store.appLanguage == .arabicEgyptian ? "دخول فلوس داخل الحساب" : "Future cash inflows included",
                value: "\(runwayCheck.breakdown.futureCashInflowCount) • \(formatCurrency(runwayCheck.breakdown.futureCashInflowTotal))",
                route: .futureInflows
            )
            detailMetricRow(
                title: store.appLanguage == .arabicEgyptian ? "مصاريف بتاريخ داخل الحساب" : "Dated obligations included",
                value: "\(runwayCheck.breakdown.datedExpenseCount) • \(formatCurrency(runwayCheck.breakdown.datedExpenseTotal))",
                route: .datedObligations
            )
            detailMetricRow(
                title: store.appLanguage == .arabicEgyptian ? "متكرر/أقساط داخل الحساب" : "Recurring/installments included",
                value: "\(runwayCheck.breakdown.recurringInstallmentCount) • \(formatCurrency(runwayCheck.breakdown.recurringInstallmentTotal))",
                route: .recurringInstallments
            )
            detailMetricRow(
                title: store.appLanguage == .arabicEgyptian ? "تقدير الميزانية الشهرية" : "Monthly budget included",
                value: formatCurrency(runwayCheck.breakdown.monthlyEstimateTotal),
                route: .monthlyBudget
            )
            detailMetricRow(
                title: AppText.keepAtLeast(store.appLanguage),
                value: formatCurrency(runwayCheck.minimumSafeBalance)
            )
            detailMetricRow(
                title: AppText.lowestCashReach(store.appLanguage),
                value: formatCurrency(runwayCheck.lowestExpectedBalance)
            )
            if runwayCheck.shortfallToStaySafe > 0 {
                detailMetricRow(
                    title: store.appLanguage == .arabicEgyptian ? "محتاج زيادة عشان تفضل آمن" : "More needed to stay safe",
                    value: formatCurrency(runwayCheck.shortfallToStaySafe)
                )
            }
        }
        .padding(.top, 6)
    }

    var runwaySafeBalanceTargetEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(AppText.keepAtLeast(store.appLanguage))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(store.runwaySafeBalanceTarget > 0 ? formatCurrency(store.runwaySafeBalanceTarget) : noSafeTargetSetText)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(store.runwaySafeBalanceTarget > 0 ? Color.primary : Color.orange)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                TextField("0", text: $runwaySafeTargetText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 92)
                    .pocketWiseInputField(semanticColor: .accounts, isProminent: true)
                    .focused($isRunwaySafeTargetFocused)
                    .onChange(of: runwaySafeTargetText) { _, _ in
                        if isUpdatingRunwaySafeTargetText {
                            isUpdatingRunwaySafeTargetText = false
                            return
                        }

                        runwaySafeTargetWasSaved = false
                        runwaySafeTargetError = nil
                    }
                    .onSubmit {
                        saveRunwaySafeBalanceTarget()
                    }

                Button(runwaySafeTargetWasSaved ? savedButtonText : saveButtonText) {
                    saveRunwaySafeBalanceTarget()
                }
                .font(.caption)
                .fontWeight(.semibold)
                .buttonStyle(.bordered)
                .disabled(runwaySafeTargetWasSaved || !runwaySafeTargetHasChanges)
            }

            if let runwaySafeTargetError {
                Text(runwaySafeTargetError)
                    .font(.caption2)
                    .foregroundStyle(PocketWiseSemanticColor.danger.tint)
            } else if runwaySafeTargetWasSaved {
                Text(store.appLanguage == .arabicEgyptian ? "تم حفظ حد الأمان." : "Safe balance target saved.")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(PocketWiseSemanticColor.success.tint)
            }
        }
        .pocketWiseCard(semanticColor: .accounts, padding: 10, cornerRadius: 12, showsBorder: true)
    }

    var salaryWarningText: String? {
        guard let resumeDate = store.salaryResumeDate,
              store.incomeMode == .noSalaryUntilDate || store.incomeMode == .vacationUnpaidPeriod else {
            return nil
        }

        let hasSalaryBeforeResume = store.activeFinancialEvents.contains { event in
            event.type == .income &&
            event.effectiveIncomeType == .salary &&
            event.date < resumeDate &&
            event.status != .cancelled &&
            event.status != .skipped
        }

        guard hasSalaryBeforeResume else {
            return store.appLanguage == .arabicEgyptian ? "لا يتم افتراض مرتب لحد \(formatMonth(resumeDate))." : "No salary assumed until \(formatMonth(resumeDate))."
        }

        return store.appLanguage == .arabicEgyptian ? "يوجد مرتب مسجل قبل تاريخ رجوع المرتب. راجع خطة الدخل." : "Salary entry exists before resume date. Review income plan."
    }

    var runwayMainResultText: String {
        switch runwayCheck.status {
        case .safe:
            return store.appLanguage == .arabicEgyptian ? "آمن لحد \(formatDate(runwayCheck.targetDate))" : "Safe through \(formatDate(runwayCheck.targetDate))"
        case .notSafe:
            let date = runwayCheck.dangerDate ?? runwayCheck.targetDate
            return store.appLanguage == .arabicEgyptian ? "مش آمن لحد \(formatDate(runwayCheck.targetDate)): \(formatDate(date))" : "Not safe through \(formatDate(runwayCheck.targetDate)): \(formatDate(date))"
        case .cashShortage:
            let date = runwayCheck.cashShortageDate ?? runwayCheck.targetDate
            return store.appLanguage == .arabicEgyptian ? "عجز قبل \(formatDate(runwayCheck.targetDate)): \(formatDate(date))" : "Cash shortage before \(formatDate(runwayCheck.targetDate)): \(formatDate(date))"
        case .planIncomplete:
            let date = runwayCheck.planIncompleteAfter ?? runwayCheck.targetDate
            return store.appLanguage == .arabicEgyptian ? "الخطة ناقصة بعد \(formatMonth(date))" : "Plan incomplete after \(formatMonth(date))"
        }
    }

    var runwayMainResultColor: Color {
        switch runwayCheck.status {
        case .safe:
            return .green
        case .notSafe, .planIncomplete:
            return .orange
        case .cashShortage:
            return .red
        }
    }

    var runwayAttentionSubtitle: String {
        switch runwayCheck.status {
        case .safe:
            return store.appLanguage == .arabicEgyptian ? "الخطة آمنة لحد تاريخ الهدف." : "The plan is safe through the target date."
        case .notSafe:
            return store.appLanguage == .arabicEgyptian ? "الرصيد ممكن ينزل تحت حد الأمان قبل تاريخ الهدف." : "Balance may fall below the safe minimum before the target date."
        case .cashShortage:
            return store.appLanguage == .arabicEgyptian ? "في عجز كاش متوقع قبل تاريخ الهدف." : "A cash shortage is expected before the target date."
        case .planIncomplete:
            return store.appLanguage == .arabicEgyptian ? "كمّل ميزانية الشهور عشان نعرف الأمان لحد تاريخ الهدف." : "Complete monthly plans to check safety through the target date."
        }
    }

    func nextCashInflowText(_ inflow: RunwayCashInflow) -> String {
        let typeLabel = cashInflowKindText(inflow.kind)
        if store.appLanguage == .arabicEgyptian {
            return "أقرب دخول فلوس: \(formatDate(inflow.date)) • \(typeLabel)"
        }

        return "Next cash inflow: \(formatDate(inflow.date)) • Type: \(typeLabel)"
    }

    func cashInflowKindText(_ kind: CashInflowKind) -> String {
        switch kind {
        case .salary:
            return store.appLanguage == .arabicEgyptian ? "مرتب" : "Salary"
        case .oneTimeCashInflow:
            return store.appLanguage == .arabicEgyptian ? "دخول مرة واحدة" : "One-time cash inflow"
        case .reimbursement:
            return store.appLanguage == .arabicEgyptian ? "استرداد / تعويض" : "Reimbursement"
        case .expectedRepayment:
            return store.appLanguage == .arabicEgyptian ? "سداد متوقع" : "Expected repayment"
        case .transfer:
            return store.appLanguage == .arabicEgyptian ? "تحويل" : "Transfer"
        case .loanOrDebt:
            return store.appLanguage == .arabicEgyptian ? "قرض/دين" : "Loan/Debt"
        case .unknown:
            return store.appLanguage == .arabicEgyptian ? "غير معروف" : "Unknown"
        }
    }

    func safeUntilSummaryLine(
        title: String,
        value: String,
        breakdownRoute: RunwayBreakdownRoute? = nil,
        insightRoute: RunwayInsightRoute? = nil
    ) -> some View {
        TodaySafeUntilSummaryLine(
            title: title,
            value: value,
            isEnabled: breakdownRoute != nil || insightRoute != nil
        ) {
            if let breakdownRoute {
                selectedRunwayBreakdown = breakdownRoute
            } else if let insightRoute {
                selectedRunwayInsight = insightRoute
            }
        }
    }

    @ViewBuilder
    func attentionDestination(for route: TodayAttentionRoute) -> some View {
        switch route {
        case .upcoming(let event):
            upcomingSourceDestination(event)
        case .monthlySummary:
            MonthlySummaryView()
                .environmentObject(store)
        case .runway:
            RunwayInsightSheet(
                route: .overview,
                result: runwayCheck,
                nextMonthSafetyItems: nextMonthSafetyItems
            )
            .environmentObject(store)
        }
    }

    @ViewBuilder
    func upcomingSourceDestination(_ event: FinancialEvent) -> some View {
        if event.paymentMethodName == "People/Debts" ||
            event.categoryName == "Money Lent / Receivables" {
            PeopleDebtsView()
                .environmentObject(store)
        } else if let planID = event.sourceInstallmentPlanID,
                  let plan = store.installmentPlans.first(where: { $0.id == planID }) {
            InstallmentPlanEditorView(plan: plan)
                .environmentObject(store)
        } else if let sourceID = event.sourceRecurringEventID,
                  let sourceEvent = store.financialEvents.first(where: { $0.id == sourceID }) {
            RecurringPaymentEditorView(event: sourceEvent)
                .environmentObject(store)
        } else if event.repeatRule != .none {
            RecurringPaymentEditorView(event: event)
                .environmentObject(store)
        } else {
            TransactionDetailView(event: event, isPresentedModally: false)
                .environmentObject(store)
        }
    }

    func detailMetricRow(title: String, value: String, route: RunwayBreakdownRoute? = nil) -> some View {
        TodayDetailMetricRow(
            title: title,
            value: value,
            showsDisclosure: route != nil
        ) {
            if let route {
                selectedRunwayBreakdown = route
            }
        }
    }

    func upcomingEventRow(_ event: FinancialEvent) -> some View {
        HStack(spacing: 12) {
            Button {
                openUpcomingSource(event)
            } label: {
                HStack(spacing: 12) {
                    NamedVisualMark(
                        name: event.title,
                        fallbackSystemImage: iconName(for: event.title),
                        size: 36
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(classificationText(for: event))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let progressText = store.installmentProgressText(for: event) {
                            Text(progressText)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }

                        if let accountName = event.accountName,
                           let account = store.activeAccounts.first(where: { $0.name == accountName }) {
                            AccountIdentityLabel(
                                account: account,
                                subtitle: "Account",
                                markSize: 22
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        } else if let accountName = event.accountName {
                            Text("Account: \(accountName)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(amountText(for: event))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(isPeopleDebtExpectedRepayment(event) ? dueStatusText(for: event.date) : formatDate(event.date))
                            .font(.caption)
                            .foregroundStyle(isPeopleDebtOverdue(event) ? .red : .secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isPayable(event) {
                Button {
                    selectedUpcomingPayment = event
                } label: {
                    Text(AppText.pay(store.appLanguage))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .pocketWiseChip(semanticColor: .success)
                }
                .buttonStyle(.plain)
            }
        }
        .pocketWiseCard(semanticColor: .obligations, padding: 14, cornerRadius: 18, showsBorder: true)
    }

    func creditCardDueRow(_ dueItem: CreditCardDueItem) -> some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(
                systemName: "creditcard.trianglebadge.exclamationmark",
                semanticColor: .warning,
                size: 36,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(AppText.creditCardDue(store.appLanguage))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(dueItem.cardName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(store.appLanguage == .arabicEgyptian ? "كشف الحساب يوم \(formatDate(dueItem.statementClosingDate))" : "Statement closes \(formatDate(dueItem.statementClosingDate))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(store.appLanguage == .arabicEgyptian ? "إجمالي المستحق على الكارت: \(formatCurrency(dueItem.outstandingAmount))" : "Card outstanding: \(formatCurrency(dueItem.outstandingAmount))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let defaultPaymentAccountName = dueItem.defaultPaymentAccountName {
                    Text(store.appLanguage == .arabicEgyptian ? "السداد من \(defaultPaymentAccountName)" : "Pay from \(defaultPaymentAccountName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    CreditCardsView()
                        .environmentObject(store)
                } label: {
                    Text(store.appLanguage == .arabicEgyptian ? "راجع تفاصيل الكارت" : "Review card details")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(PocketWiseSemanticColor.creditCards.tint)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(formatCurrency(dueItem.dueAmount))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(AppText.dueAmount(store.appLanguage))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(store.appLanguage == .arabicEgyptian ? "مستحق يوم \(formatDate(dueItem.dueDate))" : "Due on \(formatDate(dueItem.dueDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    openCreditCardPayment(dueItem)
                } label: {
                    Text(AppText.payDue(store.appLanguage))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .pocketWiseChip(semanticColor: .success)
                }
                .buttonStyle(.plain)
            }
        }
        .pocketWiseCard(semanticColor: .creditCards, padding: 14, cornerRadius: 18, showsBorder: true)
    }

    func openCreditCardPayment(_ dueItem: CreditCardDueItem) {
        guard dueItem.dueAmount > 0,
              let card = store.creditCards.first(where: { $0.id == dueItem.cardID }) else {
            return
        }

        selectedCreditCardPaymentRoute = CreditCardPaymentRoute(
            card: card,
            prefilledAmount: dueItem.dueAmount,
            maximumPaymentAmount: dueItem.dueAmount,
            source: .due
        )
    }

    func openUpcomingSource(_ event: FinancialEvent) {
        if event.paymentMethodName == "People/Debts" ||
            event.categoryName == "Money Lent / Receivables" {
            isShowingPeopleDebts = true
            return
        }

        if let planID = event.sourceInstallmentPlanID,
           let plan = store.installmentPlans.first(where: { $0.id == planID }) {
            selectedInstallmentPlan = plan
            return
        }

        if let sourceID = event.sourceRecurringEventID,
           let sourceEvent = store.financialEvents.first(where: { $0.id == sourceID }) {
            selectedRecurringPayment = sourceEvent
            return
        }

        if event.repeatRule != .none {
            selectedRecurringPayment = event
            return
        }

        selectedFinancialEvent = event
    }

    func paymentMethodLabel(for event: FinancialEvent) -> String? {
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

    func isPayable(_ event: FinancialEvent) -> Bool {
        guard event.status != .paid else {
            return false
        }

        switch event.type {
        case .expense, .obligation, .expectedExpense, .installment:
            return true

        case .income, .transfer:
            return false
        }
    }

    func classificationText(for event: FinancialEvent) -> String {
        if event.categoryName == "Money Lent / Receivables" {
            return store.appLanguage == .arabicEgyptian ? "سداد متوقع" : "Expected repayment"
        }

        if event.type == .transfer {
            let from = event.accountName ?? "Not set"
            let to = event.destinationAccountName ?? "Not set"
            return "\(from) -> \(to)"
        }

        if let categoryName = event.categoryName {
            return AppText.categoryDisplayName(categoryName, language: store.appLanguage)
        }

        return event.type.rawValue
    }

    func isPeopleDebtExpectedRepayment(_ event: FinancialEvent) -> Bool {
        event.paymentMethodName == "People/Debts" ||
        event.categoryName == "Money Lent / Receivables"
    }

    func isPeopleDebtOverdue(_ event: FinancialEvent) -> Bool {
        isPeopleDebtExpectedRepayment(event) &&
        Calendar.current.startOfDay(for: event.date) < Calendar.current.startOfDay(for: Date())
    }

    func dueStatusText(for date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())

        if day < today {
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

    func amountText(for event: FinancialEvent) -> String {
        if event.type == .transfer {
            return formatCurrency(event.amount)
        }

        return formatCurrency(event.amount)
    }
}

// MARK: - Formatting

private extension TodayView {

    func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount)
    }

    func cleanNumberText(_ amount: Double) -> String {
        guard amount > 0 else {
            return ""
        }

        if amount.rounded() == amount {
            return String(Int(amount))
        }

        return String(format: "%.2f", amount)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    func formatShortMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    func startOfMonth(_ date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }

    func endOfMonth(_ date: Date) -> Date? {
        let start = startOfMonth(date)
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: start) else {
            return nil
        }

        return Calendar.current.date(byAdding: .day, value: -1, to: nextMonth)
    }

    func iconName(for name: String) -> String {
        let lowercased = name.lowercased()

        if lowercased.contains("fuel") {
            return "fuelpump.fill"
        }

        if lowercased.contains("uber") || lowercased.contains("transport") {
            return "car.fill"
        }

        if lowercased.contains("talabat") || lowercased.contains("restaurant") {
            return "fork.knife"
        }

        if lowercased.contains("supermarket") || lowercased.contains("grocery") {
            return "cart.fill"
        }

        if lowercased.contains("pharmacy") || lowercased.contains("medical") {
            return "cross.case.fill"
        }

        if lowercased.contains("amazon") || lowercased.contains("shopping") {
            return "bag.fill"
        }

        if lowercased.contains("nursery") || lowercased.contains("kids") {
            return "figure.and.child.holdinghands"
        }

        if lowercased.contains("rent") || lowercased.contains("home") {
            return "house.fill"
        }

        if lowercased.contains("salary") || lowercased.contains("income") {
            return "arrow.down.circle.fill"
        }

        if lowercased.contains("transfer") {
            return "arrow.left.arrow.right.circle.fill"
        }

        return "creditcard.fill"
    }
}

// MARK: - Upcoming Payment Confirmation

enum UpcomingPaymentMethod: String, CaseIterable, Identifiable {
    case cash = "Cash"
    case bankTransfer = "Bank transfer"
    case instaPay = "InstaPay"
    case card = "Card"
    case other = "Other"

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .cash:
            return language == .arabicEgyptian ? "كاش" : "Cash"
        case .bankTransfer:
            return language == .arabicEgyptian ? "تحويل بنكي" : "Bank transfer"
        case .instaPay:
            return "InstaPay"
        case .card:
            return language == .arabicEgyptian ? "كارت" : "Card"
        case .other:
            return language == .arabicEgyptian ? "أخرى" : "Other"
        }
    }

    static func fromStoredValue(_ value: String?) -> UpcomingPaymentMethod {
        guard let value else {
            return .cash
        }

        if value.caseInsensitiveCompare("InstaPay") == .orderedSame {
            return .instaPay
        }

        if value.caseInsensitiveCompare("Transfer") == .orderedSame ||
            value.caseInsensitiveCompare("Bank transfer") == .orderedSame {
            return .bankTransfer
        }

        if value.caseInsensitiveCompare("Card") == .orderedSame {
            return .card
        }

        return .cash
    }
}

struct UpcomingPaymentConfirmationSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let event: FinancialEvent
    var occurrenceDate: Date? = nil

    @State private var amountText = ""
    @State private var selectedAccountName = ""
    @State private var selectedPaymentMethod: UpcomingPaymentMethod = .cash
    @State private var feeText = "0"
    @State private var paymentDate = Date()
    @State private var selectedCategoryName = ""
    @State private var selectedSubCategoryName = ""
    @State private var note = ""
    @State private var shouldShowValidationMessages = false
    @State private var paymentError: String?

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(isArabic ? "دفع مصروف قادم" : "Pay Upcoming Expense") {
                    HStack(spacing: 10) {
                        NamedVisualMark(
                            name: event.title,
                            fallbackSystemImage: "tag.fill",
                            size: 28
                        )

                        Text(event.title)
                            .font(.headline)
                    }

                    TextField(isArabic ? "المبلغ" : "Amount", text: $amountText)
                        .keyboardType(.decimalPad)

                    if shouldShowValidationMessages && amount <= 0 {
                        validationMessage(isArabic ? "أدخل مبلغ أكبر من صفر" : "Enter an amount greater than zero.")
                    }
                }

                Section(isArabic ? "مدفوع من" : "Paid from") {
                    AccountMenuPickerField(
                        title: isArabic ? "مدفوع من" : "Paid from",
                        selection: $selectedAccountName,
                        accounts: store.activeAccounts,
                        placeholder: isArabic ? "اختر حساب الدفع" : "Choose payment account",
                        emptyTitle: isArabic ? "اختر حساب الدفع" : "Choose payment account"
                    )

                    if shouldShowValidationMessages && selectedAccountName.isEmpty {
                        validationMessage(isArabic ? "اختر حساب الدفع" : "Choose payment account")
                    }
                }

                Section(isArabic ? "طريقة الدفع" : "Payment method") {
                    PaymentMethodMenuPickerField(
                        title: isArabic ? "طريقة الدفع" : "Payment method",
                        selection: $selectedPaymentMethod,
                        options: UpcomingPaymentMethod.allCases,
                        optionTitle: { $0.title(language: store.appLanguage) },
                        identityName: { $0.rawValue }
                    )

                    if selectedPaymentMethod == .instaPay {
                        HStack {
                            Text(isArabic ? "عمولة InstaPay" : "InstaPay fee")
                            Spacer()
                            TextField("0", text: $feeText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 120)
                        }

                        if shouldShowValidationMessages && feeAmount < 0 {
                            validationMessage(isArabic ? "العمولة لا يمكن أن تكون بالسالب" : "Fee cannot be negative.")
                        }
                    }

                    HStack {
                        Text(isArabic ? "إجمالي الخصم" : "Total deducted")
                        Spacer()
                        Text(store.displayCurrency(totalDeducted))
                            .fontWeight(.semibold)
                    }
                }

                Section(isArabic ? "تاريخ الدفع" : "Payment date") {
                    DatePicker(
                        isArabic ? "تم الدفع في" : "Paid at",
                        selection: $paymentDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section(isArabic ? "التصنيف" : "Category") {
                    CategorySubcategoryPickerView(
                        categoryName: $selectedCategoryName,
                        subCategoryName: $selectedSubCategoryName,
                        title: isArabic ? "التصنيف" : "Category",
                        showsValidation: shouldShowValidationMessages,
                        categoryValidationMessage: isArabic ? "اختر التصنيف" : "Choose a category.",
                        subcategoryValidationMessage: isArabic ? "اختر التصنيف الفرعي" : "Choose a subcategory."
                    )
                }

                Section(isArabic ? "ملاحظات" : "Notes") {
                    TextField(isArabic ? "ملاحظات اختيارية" : "Optional notes", text: $note)
                }

                Section {
                    if let paymentError {
                        validationMessage(paymentError)
                    }

                    Button {
                        markPaid()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isArabic ? "تسجيل كمدفوع" : "Mark Paid")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                } footer: {
                    Text(isArabic ? "الحساب الظاهر على البطاقة مجرد اقتراح. لن يتم الخصم إلا من الحساب المختار هنا." : "The account shown on the card is only a suggestion. The selected account here is the one that will be deducted.")
                }
            }
            .navigationTitle(isArabic ? "دفع مصروف قادم" : "Pay Upcoming Expense")
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
            .onChange(of: selectedPaymentMethod) { _, newValue in
                if newValue == .instaPay {
                    feeText = cleanNumberText(defaultInstaPayFee)
                } else {
                    feeText = "0"
                }
            }
            .onChange(of: amountText) { _, _ in
                if selectedPaymentMethod == .instaPay {
                    feeText = cleanNumberText(defaultInstaPayFee)
                }
            }
        }
    }

    private var amount: Double {
        parseAmountText(amountText)
    }

    private var feeAmount: Double {
        selectedPaymentMethod == .instaPay ? parseAmountText(feeText) : 0
    }

    private var totalDeducted: Double {
        amount + max(feeAmount, 0)
    }

    private var defaultInstaPayFee: Double {
        store.calculateInstaPayFee(for: amount)
    }

    private var activeAccounts: [Account] {
        store.activeAccounts
    }

    private var availableSubcategories: [String] {
        store.activeSubcategories(for: selectedCategoryName)
    }

    private var canSave: Bool {
        amount > 0 &&
        feeAmount >= 0 &&
        activeAccounts.contains(where: { $0.name == selectedAccountName }) &&
        !selectedCategoryName.isEmpty &&
        !selectedSubCategoryName.isEmpty &&
        !alreadyPaid
    }

    private var alreadyPaid: Bool {
        if let sourceID = recurringSourceID {
            let date = occurrenceDate ?? event.date
            let components = Calendar.current.dateComponents([.year, .month], from: date)
            guard let year = components.year,
                  let month = components.month else {
                return true
            }

            return store.paidRecurringOccurrence(sourceID: sourceID, year: year, month: month) != nil
        }

        return store.financialEvents.first { $0.id == event.id }?.status == .paid
    }

    private var recurringSourceID: UUID? {
        event.sourceRecurringEventID ?? (event.repeatRule != .none ? event.id : nil)
    }

    private func setupInitialValues() {
        amountText = cleanNumberText(event.recurringAmount(for: occurrenceDate ?? event.date))
        selectedAccountName = suggestedAccountName
        selectedPaymentMethod = UpcomingPaymentMethod.fromStoredValue(event.paymentMethodName)
        feeText = selectedPaymentMethod == .instaPay ? cleanNumberText(defaultInstaPayFee) : "0"
        paymentDate = Date()
        selectedCategoryName = event.categoryName ?? store.activeCategories.first?.name ?? ""
        selectedSubCategoryName = event.subCategoryName ?? availableSubcategories.first ?? ""
        ensureSubcategoryIsValid()
        note = event.note ?? ""
    }

    private var suggestedAccountName: String {
        if let accountName = event.accountName,
           activeAccounts.contains(where: { $0.name == accountName }) {
            return accountName
        }

        return activeAccounts.first?.name ?? ""
    }

    private func ensureSubcategoryIsValid() {
        let subcategories = availableSubcategories
        guard !subcategories.contains(selectedSubCategoryName) else {
            return
        }

        selectedSubCategoryName = subcategories.first ?? ""
    }

    private func markPaid() {
        shouldShowValidationMessages = true
        guard canSave else {
            return
        }

        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNote = cleanNote.isEmpty ? nil : cleanNote
        let methodName = selectedPaymentMethod.title(language: .english)
        paymentError = nil

        let mainPaymentSucceeded: Bool
        if let sourceID = recurringSourceID,
           let series = store.financialEvents.first(where: { $0.id == sourceID }) {
            mainPaymentSucceeded = store.markRecurringOccurrencePaid(
                series: series,
                occurrenceDate: occurrenceDate ?? event.date,
                amount: amount,
                accountName: selectedAccountName,
                paymentDate: paymentDate,
                paymentMethodName: methodName,
                categoryName: selectedCategoryName,
                subCategoryName: selectedSubCategoryName,
                note: finalNote
            )
        } else {
            mainPaymentSucceeded = store.markAsPaid(
                event,
                amount: amount,
                accountName: selectedAccountName,
                paymentMethodName: methodName,
                paymentDate: paymentDate,
                categoryName: selectedCategoryName,
                subCategoryName: selectedSubCategoryName,
                note: finalNote
            )
        }

        guard mainPaymentSucceeded else {
            paymentError = isArabic ? "تعذر تسجيل المصروف الأساسي. لم يتم تسجيل عمولة InstaPay." : "Could not save the main payment. No InstaPay fee was created."
            return
        }

        if selectedPaymentMethod == .instaPay && feeAmount > 0 {
            let feeSucceeded = store.addBankingFeeExpense(
                title: "InstaPay Fee",
                amount: feeAmount,
                date: paymentDate,
                accountName: selectedAccountName,
                paymentMethodName: "InstaPay",
                note: "InstaPay fee for \(event.title)"
            )

            guard feeSucceeded else {
                paymentError = isArabic ? "تم تسجيل المصروف الأساسي، لكن تعذر تسجيل عمولة InstaPay." : "Main payment was saved, but the InstaPay fee could not be saved."
                return
            }
        }

        dismiss()
    }

    private func validationMessage(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.red)
    }

    private func parseAmountText(_ text: String) -> Double {
        let cleaned = text
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Double(cleaned) ?? 0
    }

    private func cleanNumberText(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return String(format: "%.2f", amount)
    }
}

// MARK: - Global Search

private struct GlobalSearchView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var transactionResults: [FinancialEvent] {
        guard !trimmedQuery.isEmpty else { return [] }

        return store.activeFinancialEvents
            .filter { matchesFinancialEvent($0) }
            .sorted { first, second in
                if first.date == second.date {
                    return first.createdAt > second.createdAt
                }

                return first.date > second.date
            }
            .prefix(20)
            .map { $0 }
    }

    private var peopleDebtResults: [PersonDebt] {
        guard !trimmedQuery.isEmpty else { return [] }

        return store.activePersonDebts
            .filter { matchesPersonDebt($0) }
            .sorted { first, second in
                let firstRemaining = store.remainingAmount(for: first)
                let secondRemaining = store.remainingAmount(for: second)
                if firstRemaining == secondRemaining {
                    return first.updatedAt > second.updatedAt
                }

                return firstRemaining > secondRemaining
            }
            .prefix(12)
            .map { $0 }
    }

    private var accountResults: [Account] {
        guard !trimmedQuery.isEmpty else { return [] }

        return store.activeAccounts
            .filter { matchesAccount($0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .prefix(12)
            .map { $0 }
    }

    private var categoryResults: [CategorySearchResult] {
        guard !trimmedQuery.isEmpty else { return [] }

        return store.activeCategories
            .flatMap { category in
                categorySearchResults(for: category)
            }
            .prefix(16)
            .map { $0 }
    }

    private var obligationResults: [ObligationSearchResult] {
        guard !trimmedQuery.isEmpty else { return [] }

        return allObligationResults
            .filter { matchesObligation($0) }
            .prefix(20)
            .map { $0 }
    }

    private var hasAnyResults: Bool {
        !transactionResults.isEmpty ||
        !peopleDebtResults.isEmpty ||
        !accountResults.isEmpty ||
        !categoryResults.isEmpty ||
        !obligationResults.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    searchField
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                if trimmedQuery.isEmpty {
                    emptyPrompt
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else if !hasAnyResults {
                    noResultsPrompt
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    resultsSections
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isArabic ? "بحث" : "Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isArabic ? "تم" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(
                isArabic ? "ابحث في المعاملات، الأشخاص، الحسابات، التصنيفات، الالتزامات..." : "Search transactions, people, accounts, categories, obligations...",
                text: $query
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var emptyPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(isArabic ? "ابحث من مكان واحد" : "Search from one place")
                .font(.headline)
                .fontWeight(.semibold)

            Text(isArabic ? "ابحث في المعاملات، الأشخاص، الحسابات، التصنيفات، والالتزامات." : "Find transactions, people, accounts, categories, and obligations without digging through tabs.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var noResultsPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(isArabic ? "لا توجد نتائج" : "No results found")
                .font(.headline)
                .fontWeight(.semibold)

            Text(trimmedQuery)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    @ViewBuilder
    private var resultsSections: some View {
        if !transactionResults.isEmpty {
            Section(isArabic ? "المعاملات" : "Transactions") {
                ForEach(transactionResults) { event in
                    NavigationLink {
                        TransactionDetailView(event: event, isPresentedModally: false)
                            .environmentObject(store)
                    } label: {
                        GlobalSearchRow(
                            icon: transactionIcon(for: event),
                            title: event.title,
                            subtitle: transactionSubtitle(for: event),
                            detail: store.signedDisplayCurrency(event.amount, prefix: event.type == .income ? "+" : event.type == .transfer ? "" : "-"),
                            badge: event.type.rawValue,
                            dateText: shortDate(event.date)
                        )
                    }
                }
            }
        }

        if !peopleDebtResults.isEmpty {
            Section(isArabic ? "الأشخاص والديون" : "People & Debts") {
                ForEach(peopleDebtResults) { debt in
                    NavigationLink {
                        PeopleDebtsView()
                            .environmentObject(store)
                    } label: {
                        GlobalSearchRow(
                            icon: debt.kind == .owedToMe ? "person.crop.circle.badge.clock" : "person.crop.circle.badge.exclamationmark",
                            title: debt.personName,
                            subtitle: debtSubtitle(for: debt),
                            detail: store.displayCurrency(store.remainingAmount(for: debt)),
                            badge: isArabic ? "الأشخاص والديون" : "People & Debts",
                            dateText: debt.dueDate.map { shortDate($0) }
                        )
                    }
                }
            }
        }

        if !accountResults.isEmpty {
            Section(isArabic ? "الحسابات" : "Accounts") {
                ForEach(accountResults) { account in
                    NavigationLink {
                        AccountManagementView()
                            .environmentObject(store)
                    } label: {
                        GlobalSearchRow(
                            icon: accountIcon(for: account),
                            title: account.name,
                            subtitle: account.type.rawValue,
                            detail: store.displayCurrency(account.balance),
                            badge: isArabic ? "حساب" : "Account",
                            dateText: nil,
                            account: account
                        )
                    }
                }
            }
        }

        if !categoryResults.isEmpty {
            Section(isArabic ? "التصنيفات" : "Categories") {
                ForEach(categoryResults) { result in
                    NavigationLink {
                        TransactionsView(
                            initialFilter: TransactionInitialFilter(
                                searchText: result.subcategoryName ?? "",
                                categoryName: result.category.name,
                                paidOnly: true
                            )
                        )
                        .environmentObject(store)
                    } label: {
                        GlobalSearchRow(
                            icon: "tag.fill",
                            title: result.subcategoryName ?? result.category.name,
                            subtitle: result.subcategoryName == nil ? (isArabic ? "تصنيف" : "Category") : result.category.name,
                            detail: nil,
                            badge: isArabic ? "تصنيف" : "Category",
                            dateText: nil
                        )
                    }
                }
            }
        }

        if !obligationResults.isEmpty {
            Section(isArabic ? "الالتزامات" : "Obligations") {
                ForEach(obligationResults) { result in
                    NavigationLink {
                        obligationDestination(for: result)
                    } label: {
                        GlobalSearchRow(
                            icon: result.icon,
                            title: result.title,
                            subtitle: result.subtitle,
                            detail: store.displayCurrency(result.amount),
                            badge: result.badge,
                            dateText: result.date.map { shortDate($0) }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func obligationDestination(for result: ObligationSearchResult) -> some View {
        ObligationsCenterView()
            .environmentObject(store)
    }
}

private extension GlobalSearchView {

    var allObligationResults: [ObligationSearchResult] {
        let recurring = store.activeFinancialEvents
            .filter { $0.repeatRule != .none && $0.status != .cancelled }
            .map { event in
                let nextDate = nextRecurringDate(for: event) ?? event.date
                return ObligationSearchResult(
                    id: "recurring-\(event.id.uuidString)",
                    kind: .recurring(event),
                    title: event.title,
                    subtitle: "\(event.repeatRule.rawValue) • \(event.categoryName ?? event.type.rawValue)",
                    amount: event.recurringAmount(for: nextDate),
                    date: nextDate,
                    badge: isArabic ? "متكرر" : "Recurring",
                    icon: "repeat",
                    searchableText: [
                        event.title,
                        event.note,
                        event.categoryName,
                        event.subCategoryName,
                        event.accountName,
                        event.repeatRule.rawValue,
                        event.effectiveRecurringAmountMode.title(language: store.appLanguage),
                        amountSearchText(event.recurringAmount(for: nextDate)),
                        dateSearchText(nextDate)
                    ]
                    .compactMap { $0 }
                    .joined(separator: " ")
                )
            }

        let installments = store.activeInstallmentPlans.map { plan in
            let summary = store.installmentPlanSummary(for: plan)
            let nextDate = summary.nextDueDate ?? plan.firstDueDate
            return ObligationSearchResult(
                id: "installment-\(plan.id.uuidString)",
                kind: .installment(plan),
                title: "\(plan.paymentMethodName) - \(plan.purchaseName)",
                subtitle: "\(plan.categoryName) / \(plan.subCategoryName)",
                amount: plan.monthlyAmount,
                date: nextDate,
                badge: isArabic ? "أقساط" : "Installment",
                icon: "creditcard.and.123",
                searchableText: [
                    plan.purchaseName,
                    plan.paymentMethodName,
                    plan.note,
                    plan.categoryName,
                    plan.subCategoryName,
                    plan.accountName,
                    amountSearchText(plan.monthlyAmount),
                    amountSearchText(plan.totalAmount),
                    dateSearchText(nextDate)
                ]
                .compactMap { $0 }
                .joined(separator: " ")
            )
        }

        let futureEvents = store.activeFinancialEvents
            .filter { event in
                event.repeatRule == .none &&
                event.sourceInstallmentPlanID == nil &&
                event.status != .paid &&
                event.status != .cancelled
            }
            .map { event in
                ObligationSearchResult(
                    id: "future-\(event.id.uuidString)",
                    kind: .futureEvent(event),
                    title: event.title,
                    subtitle: transactionSubtitle(for: event),
                    amount: event.amount,
                    date: event.date,
                    badge: event.type == .income ? (isArabic ? "دخل متوقع" : "Expected Income") : (isArabic ? "بند مستقبلي" : "Future Item"),
                    icon: event.type == .income ? "arrow.down.circle.fill" : "calendar",
                    searchableText: searchableText(for: event)
                )
            }

        let debts = store.activePersonDebts
            .filter { !$0.isArchived && $0.dueDate != nil && store.remainingAmount(for: $0) > 0 }
            .map { debt in
                ObligationSearchResult(
                    id: "debt-\(debt.id.uuidString)",
                    kind: .personDebt(debt),
                    title: debt.personName,
                    subtitle: debtSubtitle(for: debt),
                    amount: store.remainingAmount(for: debt),
                    date: debt.dueDate,
                    badge: isArabic ? "الأشخاص والديون" : "People & Debts",
                    icon: "person.2.fill",
                    searchableText: personDebtSearchText(debt)
                )
            }

        return (recurring + installments + futureEvents + debts)
            .sorted { first, second in
                switch (first.date, second.date) {
                case let (firstDate?, secondDate?):
                    return firstDate < secondDate
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
                }
            }
    }

    func matchesFinancialEvent(_ event: FinancialEvent) -> Bool {
        matchesText(searchableText(for: event)) || matchesAmount(event.amount)
    }

    func matchesPersonDebt(_ debt: PersonDebt) -> Bool {
        matchesText(personDebtSearchText(debt)) ||
        matchesAmount(debt.originalAmount) ||
        matchesAmount(store.remainingAmount(for: debt))
    }

    func matchesAccount(_ account: Account) -> Bool {
        matchesText(
            [
                account.name,
                account.type.rawValue,
                account.recognitionAliases.joined(separator: " "),
                account.recognitionCardEndings.joined(separator: " ")
            ]
            .joined(separator: " ")
        ) || matchesAmount(account.balance)
    }

    func matchesObligation(_ result: ObligationSearchResult) -> Bool {
        matchesText(result.searchableText) || matchesAmount(result.amount)
    }

    func categorySearchResults(for category: Category) -> [CategorySearchResult] {
        var results: [CategorySearchResult] = []
        let categoryMatches = matchesText(category.name)

        if categoryMatches {
            results.append(CategorySearchResult(category: category, subcategoryName: nil))
        }

        for subcategory in category.subcategories where matchesText("\(category.name) \(subcategory)") {
            results.append(CategorySearchResult(category: category, subcategoryName: subcategory))
        }

        return results
    }

    func searchableText(for event: FinancialEvent) -> String {
        [
            event.title,
            event.note,
            event.categoryName,
            event.subCategoryName,
            event.reimbursementCategoryName,
            event.walletEventName,
            event.accountName,
            event.destinationAccountName,
            event.paymentMethodName,
            event.type.rawValue,
            event.status.rawValue,
            event.type == .income ? event.effectiveIncomeType.title(language: store.appLanguage) : nil,
            amountSearchText(event.amount),
            dateSearchText(event.date)
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    func personDebtSearchText(_ debt: PersonDebt) -> String {
        [
            debt.personName,
            debt.note,
            debt.kind.rawValue,
            store.status(for: debt).rawValue,
            amountSearchText(debt.originalAmount),
            amountSearchText(store.remainingAmount(for: debt)),
            debt.dueDate.map { dateSearchText($0) }
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }

    func matchesText(_ text: String) -> Bool {
        normalized(text).contains(normalized(trimmedQuery))
    }

    func matchesAmount(_ amount: Double) -> Bool {
        let queryDigits = trimmedQuery.filter(\.isNumber)
        guard !queryDigits.isEmpty else {
            return false
        }

        let amountDigits = "\(Int(amount.rounded()))"
        return amountDigits.contains(queryDigits)
    }

    func normalized(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: ",", with: "")
            .lowercased()
    }

    func amountSearchText(_ amount: Double) -> String {
        [
            "\(Int(amount.rounded()))",
            store.displayCurrency(amount)
        ]
        .joined(separator: " ")
    }

    func dateSearchText(_ date: Date) -> String {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d MMM yyyy"

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"

        let shortMonthFormatter = DateFormatter()
        shortMonthFormatter.dateFormat = "MMM yyyy"

        return [
            dayFormatter.string(from: date),
            monthFormatter.string(from: date),
            shortMonthFormatter.string(from: date),
            "\(Calendar.current.component(.year, from: date))"
        ]
        .joined(separator: " ")
    }

    func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    func transactionSubtitle(for event: FinancialEvent) -> String {
        if event.type == .transfer {
            return "\(event.accountName ?? "Not set") -> \(event.destinationAccountName ?? "Not set")"
        }

        if let categoryName = event.categoryName,
           let subCategoryName = event.subCategoryName {
            return AppText.categorySubcategoryDisplayText(
                categoryName: categoryName,
                subCategoryName: subCategoryName,
                language: store.appLanguage
            )
        }

        if let categoryName = event.categoryName {
            return AppText.categoryDisplayName(categoryName, language: store.appLanguage)
        }

        if let accountName = event.accountName {
            return accountName
        }

        return event.status.rawValue
    }

    func debtSubtitle(for debt: PersonDebt) -> String {
        let status = store.status(for: debt).rawValue
        let kind = debt.kind == .owedToMe
            ? (isArabic ? "فلوس مستحقة ليك" : "Owed to me")
            : (isArabic ? "عليك دين" : "I owe")

        return "\(kind) • \(status)"
    }

    func transactionIcon(for event: FinancialEvent) -> String {
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

    func accountIcon(for account: Account) -> String {
        switch account.type {
        case .cash:
            return "banknote.fill"
        case .bank:
            return "building.columns.fill"
        case .wallet:
            return "wallet.pass.fill"
        }
    }

    func nextRecurringDate(for event: FinancialEvent) -> Date? {
        guard event.repeatRule != .none else {
            return nil
        }

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let anchor = calendar.startOfDay(for: event.date)

        guard anchor < todayStart else {
            return anchor
        }

        for offset in 0...36 {
            guard let candidate = recurringDate(from: anchor, rule: event.repeatRule, offset: offset),
                  candidate >= todayStart else {
                continue
            }

            if !event.isRecurringOccurrenceSkipped(on: candidate) {
                return candidate
            }
        }

        return nil
    }

    func recurringDate(from start: Date, rule: RepeatRule, offset: Int) -> Date? {
        let calendar = Calendar.current

        switch rule {
        case .none:
            return start
        case .monthly:
            return calendar.date(byAdding: .month, value: offset, to: start)
        case .quarterly:
            return calendar.date(byAdding: .month, value: offset * 3, to: start)
        case .yearly:
            return calendar.date(byAdding: .year, value: offset, to: start)
        }
    }
}

private struct CategorySearchResult: Identifiable {
    let category: Category
    let subcategoryName: String?

    var id: String {
        "\(category.id.uuidString)-\(subcategoryName ?? "__category__")"
    }
}

private struct ObligationSearchResult: Identifiable {
    let id: String
    let kind: ObligationSearchKind
    let title: String
    let subtitle: String
    let amount: Double
    let date: Date?
    let badge: String
    let icon: String
    let searchableText: String
}

private enum ObligationSearchKind {
    case recurring(FinancialEvent)
    case installment(InstallmentPlan)
    case futureEvent(FinancialEvent)
    case personDebt(PersonDebt)
}

// MARK: - Budget Status

private enum TodayBudgetStatus {
    case notPlanned
    case onTrack
    case watch
    case overBudget

    var title: String {
        switch self {
        case .notPlanned:
            return "Not Planned"
        case .onTrack:
            return "On Track"
        case .watch:
            return "Watch"
        case .overBudget:
            return "Over Budget"
        }
    }

    var color: Color {
        switch self {
        case .notPlanned:
            return .secondary
        case .onTrack:
            return .green
        case .watch:
            return .orange
        case .overBudget:
            return .red
        }
    }
}

// MARK: - Preview

struct TodayView_Previews: PreviewProvider {
    static var previews: some View {
        TodayView()
            .environmentObject(WalletStore())
    }
}
