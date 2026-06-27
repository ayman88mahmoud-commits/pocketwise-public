import SwiftUI

struct WalletRootView: View {

    @EnvironmentObject private var store: WalletStore
    @Binding private var pendingBankSMSImportDrafts: [BankSMSImportDraft]
    @State private var activeBankSMSImportDraft: BankSMSImportDraft?
    @State private var isAddExpenseSheetActive = false
    @State private var pausedBankSMSImportIdentities: Set<String> = []

    init(pendingBankSMSImportDrafts: Binding<[BankSMSImportDraft]> = .constant([])) {
        _pendingBankSMSImportDrafts = pendingBankSMSImportDrafts
    }

    var body: some View {
        TabView {
            if store.appLanguage == .arabicEgyptian {
                SettingsView()
                    .environment(\.layoutDirection, layoutDirection)
                    .accessibilityIdentifier("screen.settings")
                    .tabItem {
                        Label(AppText.tabSettings(store.appLanguage), systemImage: "gearshape.fill")
                            .accessibilityIdentifier("tab.settings")
                    }

                AnalysisView()
                    .environment(\.layoutDirection, layoutDirection)
                    .tabItem {
                        Label(AppText.tabAnalysis(store.appLanguage), systemImage: "chart.pie.fill")
                            .accessibilityIdentifier("tab.analysis")
                    }

                BudgetRootView()
                    .environment(\.layoutDirection, layoutDirection)
                    .tabItem {
                        Label(AppText.tabPlan(store.appLanguage), systemImage: "tablecells")
                            .accessibilityIdentifier("tab.budget")
                    }

                TransactionsView()
                    .environment(\.layoutDirection, layoutDirection)
                    .tabItem {
                        Label(AppText.tabTransactions(store.appLanguage), systemImage: "list.bullet.rectangle")
                            .accessibilityIdentifier("tab.transactions")
                    }

                todayTab
            } else {
                todayTab

                TransactionsView()
                    .environment(\.layoutDirection, layoutDirection)
                    .tabItem {
                        Label(AppText.tabTransactions(store.appLanguage), systemImage: "list.bullet.rectangle")
                            .accessibilityIdentifier("tab.transactions")
                    }

                BudgetRootView()
                    .environment(\.layoutDirection, layoutDirection)
                    .tabItem {
                        Label(AppText.tabPlan(store.appLanguage), systemImage: "tablecells")
                            .accessibilityIdentifier("tab.budget")
                    }

                AnalysisView()
                    .environment(\.layoutDirection, layoutDirection)
                    .tabItem {
                        Label(AppText.tabAnalysis(store.appLanguage), systemImage: "chart.pie.fill")
                            .accessibilityIdentifier("tab.analysis")
                    }

                SettingsView()
                    .environment(\.layoutDirection, layoutDirection)
                    .accessibilityIdentifier("screen.settings")
                    .tabItem {
                        Label(AppText.tabSettings(store.appLanguage), systemImage: "gearshape.fill")
                            .accessibilityIdentifier("tab.settings")
                    }
            }
        }
        .onAppear {
            refreshPendingBankSMSImports()
        }
        .sheet(item: $activeBankSMSImportDraft, onDismiss: {
            closeActiveBankSMSImportDraftForLater()
        }) { draft in
            if draft.transactionType == "income" {
                AddFutureItemView(
                    startsAsIncome: true,
                    bankSMSDraft: draft,
                    onBankSMSImportSaved: removePendingBankSMSImport,
                    onBankSMSImportDiscarded: removePendingBankSMSImport
                )
                    .environmentObject(store)
                    .onAppear {
                        isAddExpenseSheetActive = true
                    }
                    .onDisappear {
                        isAddExpenseSheetActive = false
                    }
            } else {
                AddExpenseView(
                    bankSMSDraft: draft,
                    onBankSMSImportSaved: removePendingBankSMSImport,
                    onBankSMSImportDiscarded: removePendingBankSMSImport
                )
                    .environmentObject(store)
                    .onAppear {
                        isAddExpenseSheetActive = true
                    }
                    .onDisappear {
                        isAddExpenseSheetActive = false
                    }
            }
        }
    }

    private var layoutDirection: LayoutDirection {
        AppText.layoutDirection(store.appLanguage)
    }

    private var todayTab: some View {
        TodayView(
            isAddExpenseSheetActive: $isAddExpenseSheetActive,
            pendingBankSMSImportCount: pendingBankSMSImportDrafts.count,
            reviewPendingBankSMSImports: {
                presentNextPendingBankSMSImportIfPossible(includingPaused: true)
            }
        )
        .environment(\.layoutDirection, layoutDirection)
        .accessibilityIdentifier("screen.today")
        .tabItem {
            Label(AppText.tabToday(store.appLanguage), systemImage: "house.fill")
                .accessibilityIdentifier("tab.today")
        }
    }

    private func refreshPendingBankSMSImports() {
        pendingBankSMSImportDrafts = PendingBankSMSImportStore.load()
    }

    private func presentNextPendingBankSMSImportIfPossible(includingPaused: Bool = false) {
        guard activeBankSMSImportDraft == nil,
              !isAddExpenseSheetActive else {
            return
        }

        let nextDraft = pendingBankSMSImportDrafts.first { draft in
            includingPaused || !pausedBankSMSImportIdentities.contains(draft.importIdentity)
        }

        guard let nextDraft else {
            return
        }

        if includingPaused {
            pausedBankSMSImportIdentities.remove(nextDraft.importIdentity)
        }
        activeBankSMSImportDraft = nextDraft
    }

    private func closeActiveBankSMSImportDraftForLater() {
        if let activeBankSMSImportDraft {
            pausedBankSMSImportIdentities.insert(activeBankSMSImportDraft.importIdentity)
        }

        activeBankSMSImportDraft = nil
        isAddExpenseSheetActive = false
    }

    private func removePendingBankSMSImport(_ draft: BankSMSImportDraft) {
        pausedBankSMSImportIdentities.remove(draft.importIdentity)
        pendingBankSMSImportDrafts = PendingBankSMSImportStore.remove(
            importIdentity: draft.importIdentity
        )
        activeBankSMSImportDraft = nil
        isAddExpenseSheetActive = false
    }
}

// MARK: - Timeline

struct TimelineView: View {

    @EnvironmentObject private var store: WalletStore

    private var today: Date {
        Date()
    }

    private var forecasts: [MonthlyForecast] {
        store.monthlyForecasts(
            numberOfMonths: store.forecastHorizonMonths,
            from: today
        )
    }

    private var breakdownsByMonth: [Date: MonthlyForecastBreakdown] {
        let breakdowns = ForecastEngine.buildMonthlyForecastBreakdowns(
            financialEvents: store.financialEvents,
            monthlyLivingBurn: store.monthlyLivingBurn,
            numberOfMonths: store.forecastHorizonMonths,
            from: today
        )

        return Dictionary(uniqueKeysWithValues: breakdowns.map { breakdown in
            (breakdown.monthStartDate, breakdown)
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(store.appLanguage == .arabicEgyptian ? "الخط الزمني" : "Timeline")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(store.appLanguage == .arabicEgyptian ? "توقع الكاش بناءً على المدفوعات المتكررة، المصاريف المتوقعة، الدخل، والصرف المرن." : "Future cash position based on recurring payments, expected expenses, income, and flexible spending.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(forecasts) { forecast in
                        TimelineMonthCard(
                            forecast: forecast,
                            breakdown: breakdownsByMonth[forecast.monthStartDate]
                        )
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct TimelineMonthCard: View {

    @EnvironmentObject private var store: WalletStore

    let forecast: MonthlyForecast
    let breakdown: MonthlyForecastBreakdown?

    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(formatMonth(forecast.monthStartDate))
                .font(.headline)
                .fontWeight(.bold)

            HStack {
                metric(isAr ? "رصيد البداية" : "Starting", forecast.startingCash)
                metric(isAr ? "الدخل" : "Income", forecast.expectedIncome)
            }

            HStack {
                metric(isAr ? "ثابت / متكرر" : "Fixed / Recurring", forecast.confirmedOutflow)
                metric(isAr ? "متوقع + مرن" : "Expected + Flexible", forecast.expectedOutflow)
            }

            if let breakdown {
                breakdownSection(breakdown)
            }

            Divider()

            HStack {
                Text(isAr ? "رصيد النهاية" : "Ending Cash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatCurrency(forecast.endingCash))
                    .font(.headline)
                    .fontWeight(.bold)
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    func breakdownSection(_ breakdown: MonthlyForecastBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isAr ? "العوامل" : "Drivers")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ForEach(Array(breakdown.topItems.prefix(5))) { item in
                breakdownRow(item)
            }

            if breakdown.flexibleSpendingAmount > 0 {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isAr ? "الصرف المرن" : "Flexible spending")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text(isAr ? "تقدير شهري" : "Monthly estimate")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(store.signedDisplayCurrency(breakdown.flexibleSpendingAmount, prefix: "-"))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    func breakdownRow(_ item: ForecastBreakdownItem) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(formatDate(item.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(AppText.eventTypeLabel(item.type, language: store.appLanguage))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if item.repeatRule != .none {
                        Text(AppText.repeatRuleLabel(item.repeatRule, language: store.appLanguage))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemBackground))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Text(signedAmountText(for: item))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(item.type == .income ? .green : .primary)
                .lineLimit(1)
        }
    }

    func metric(_ title: String, _ amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formatCurrency(amount))
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func signedAmountText(for item: ForecastBreakdownItem) -> String {
        let prefix = item.type == .income ? "+" : "-"
        return store.signedDisplayCurrency(item.amount, prefix: prefix)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount)
    }

    func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Analysis

struct AnalysisView: View {

    @EnvironmentObject private var store: WalletStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(AppText.tabAnalysis(store.appLanguage))
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(store.appLanguage == .arabicEgyptian ? "افهم الصرف، فروق الخطة، وتوقعات الكاش." : "Understand spending, plan gaps, and cash outlook.")
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        MonthlySummaryView()
                    } label: {
                        AnalysisCard(
                            title: store.appLanguage == .arabicEgyptian ? "ملخص الشهر" : "Monthly Summary",
                            subtitle: store.appLanguage == .arabicEgyptian ? "المخطط مقابل المصروف، معدل الصرف، وحالة الشهر." : "See planned vs spent, burn rate, and month status.",
                            icon: "gauge.with.dots.needle.bottom.50percent"
                        )
                    }
                    .buttonStyle(.plain)

                    Text(store.appLanguage == .arabicEgyptian ? "التقارير" : "Reports")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.top, 8)

                    NavigationLink {
                        WhereMoneyWentReportView()
                    } label: {
                        AnalysisCard(
                            title: store.appLanguage == .arabicEgyptian ? "فلوسي راحت فين؟" : "Where did my money go?",
                            subtitle: store.appLanguage == .arabicEgyptian ? "تقسيم المصاريف حسب البنود للشهر المختار." : "Category breakdown for the selected month.",
                            icon: "chart.pie.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        BiggestDrainsReportView()
                    } label: {
                        AnalysisCard(
                            title: store.appLanguage == .arabicEgyptian ? "أعلى بنود الصرف" : "Top spending areas",
                            subtitle: store.appLanguage == .arabicEgyptian ? "أعلى تصنيفات الصرف هذا الشهر." : "Your highest spending categories this month.",
                            icon: "drop.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        WhatChangedReportView()
                    } label: {
                        AnalysisCard(
                            title: store.appLanguage == .arabicEgyptian ? "إيه اللي اتغير؟" : "What changed?",
                            subtitle: store.appLanguage == .arabicEgyptian ? "مقارنة البنود من شهر لشهر." : "Month-to-month category changes.",
                            icon: "arrow.triangle.2.circlepath"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        SubcategoryBreakdownReportView()
                    } label: {
                        AnalysisCard(
                            title: store.appLanguage == .arabicEgyptian ? "التصنيفات الفرعية" : "Subcategory breakdown",
                            subtitle: store.appLanguage == .arabicEgyptian ? "عدد الحركات، المتوسط، ومقارنة بالشهر اللي فات." : "Counts, averages, and previous-month movement.",
                            icon: "list.bullet.indent"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        MonthlyDriverAnalysisReportView()
                    } label: {
                        AnalysisCard(
                            title: store.appLanguage == .arabicEgyptian ? "فروق الخطة والفعلي" : "Plan vs Actual Gaps",
                            subtitle: store.appLanguage == .arabicEgyptian ? "شوف أكبر اختلافات بين الصرف والخطة." : "See where spending differs most from your plan.",
                            icon: "point.topleft.down.curvedto.point.bottomright.up"
                        )
                    }
                    .buttonStyle(.plain)

                    Text(AppText.cashOutlookSection(store.appLanguage))
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.top, 8)

                    NavigationLink {
                        RunwayChartView()
                            .environmentObject(store)
                    } label: {
                        AnalysisCard(
                            title: AppText.runwayMapTitle(store.appLanguage),
                            subtitle: AppText.runwayMapSubtitle(store.appLanguage),
                            icon: "chart.line.downtrend.xyaxis"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        CashTimelineView()
                            .environmentObject(store)
                    } label: {
                        AnalysisCard(
                            title: store.appLanguage == .arabicEgyptian ? "خط زمني للسيولة" : "Cash Timeline",
                            subtitle: store.appLanguage == .arabicEgyptian ? "حركات قادمة مع أرصدة كاش متتابعة." : "Upcoming events with running cash balances.",
                            icon: "calendar.badge.clock"
                        )
                    }
                    .buttonStyle(.plain)

                    Text(store.appLanguage == .arabicEgyptian ? "ملخصات الشهور السابقة" : "Past month summaries")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.top, 8)

                    NavigationLink {
                        HistoricalSummaryView()
                    } label: {
                        AnalysisCard(
                            title: store.appLanguage == .arabicEgyptian ? "ملخصات الشهور السابقة" : "Past Month Summaries",
                            subtitle: store.appLanguage == .arabicEgyptian ? "ملخصات صرف قديمة لا تؤثر على أرصدة الحسابات." : "Past spending summaries that do not affect account balances.",
                            icon: "doc.text.magnifyingglass"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 8)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 28)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct AnalysisCard: View {

    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.forward")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Settings

struct SettingsView: View {

    @EnvironmentObject private var store: WalletStore

    @State private var isEditingInstaPayFees = false
    @State private var isConfirmingReset = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(store.appLanguage == .arabicEgyptian ? "لغة التطبيق" : "App Language")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Picker(
                            store.appLanguage == .arabicEgyptian ? "لغة التطبيق" : "App Language",
                            selection: Binding(
                                get: { store.appLanguage },
                                set: { store.appLanguage = $0 }
                            )
                        ) {
                            Text("English")
                                .tag(AppLanguage.english)
                            Text("عربي")
                                .tag(AppLanguage.arabicEgyptian)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                }

                Section(store.appLanguage == .arabicEgyptian ? "الإعداد والإدارة" : "Setup and management") {
                    NavigationLink {
                        OnboardingWelcomeView(presentationMode: .settings)
                            .environmentObject(store)
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "مساعد الإعداد" : "Setup Assistant",
                            subtitle: store.appLanguage == .arabicEgyptian ? "راجع أساسيات المحفظة بدون تسجيل معاملات" : "Review wallet basics without recording transactions.",
                            icon: "sparkles",
                            semanticColor: .setup
                        )
                    }

                    NavigationLink {
                        QuickTourView()
                            .environmentObject(store)
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "جولة سريعة" : "Quick Tour",
                            subtitle: store.appLanguage == .arabicEgyptian ? "تعرّف على الشاشات الأساسية بسرعة" : "A quick walkthrough of the main screens.",
                            icon: "play.circle.fill",
                            semanticColor: .setup
                        )
                    }

                    NavigationLink {
                        AppPreferencesView()
                            .environmentObject(store)
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "الملف والتفضيلات" : "Profile & Preferences",
                            subtitle: store.appLanguage == .arabicEgyptian ? "الاسم، اللغة، ومدة النظرة المستقبلية" : "Display name, language, and forecast horizon.",
                            icon: "person.crop.circle",
                            semanticColor: .accounts
                        )
                    }

                    NavigationLink {
                        AccountManagementView()
                            .environmentObject(store)
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "إدارة الحسابات" : "Manage Accounts",
                            subtitle: store.appLanguage == .arabicEgyptian ? "أضف وعدّل الحسابات والأرصدة" : "Add, edit, deactivate, and update balances.",
                            icon: "wallet.pass.fill",
                            semanticColor: .accounts
                        )
                    }

                    NavigationLink {
                        CreditCardsView()
                            .environmentObject(store)
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "كروت الائتمان" : "Credit Cards",
                            subtitle: store.appLanguage == .arabicEgyptian ? "إعداد الكروت بدون تغيير أرصدة الكاش" : "Set up cards without changing cash balances.",
                            icon: "creditcard.fill",
                            semanticColor: .creditCards
                        )
                    }
                    .accessibilityIdentifier("button.settingsCreditCards")

                    NavigationLink {
                        CategoryManagementView()
                            .environmentObject(store)
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "إدارة البنود" : "Manage Categories",
                            subtitle: store.appLanguage == .arabicEgyptian ? "أضف وعدّل ورتّب البنود الفرعية" : "Add, edit, deactivate, and organize subcategories.",
                            icon: "tag.fill",
                            semanticColor: .categories
                        )
                    }

                    NavigationLink {
                        MerchantMemoryView()
                            .environmentObject(store)
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "التجار والاختصارات" : "Merchant Memory",
                            subtitle: store.appLanguage == .arabicEgyptian ? "احفظ التجار والاختصارات والتصنيفات الافتراضية" : "Save merchants, aliases, and default categories.",
                            icon: "storefront",
                            semanticColor: .spending
                        )
                    }

                    HStack {
                        Text(store.appLanguage == .arabicEgyptian ? "الكاش المتاح الحالي" : "Current available cash")
                        Spacer()
                        Text(formatCurrency(store.availableCash))
                            .fontWeight(.bold)
                    }
                }

                Section(AppText.privacy(store.appLanguage)) {
                    Toggle(AppText.hideBalances(store.appLanguage), isOn: Binding(
                        get: { store.hideBalances },
                        set: { store.setHideBalances($0) }
                    ))

                    Text(store.appLanguage == .arabicEgyptian ? "بيخفي الأرقام المعروضة فقط، من غير ما يغيّر أي بيانات محفوظة." : "Hides displayed amounts only. Saved data and balances do not change.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(store.appLanguage == .arabicEgyptian ? "إعدادات الدفع" : "Payment settings") {
                    Button {
                        isEditingInstaPayFees = true
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "قواعد رسوم InstaPay" : "InstaPay fee rules",
                            subtitle: store.appLanguage == .arabicEgyptian
                                ? "\(cleanNumberText(store.instaPayFeePercent))%، أدنى \(formatCurrency(store.instaPayMinimumFee))، أقصى \(formatCurrency(store.instaPayMaximumFee))"
                                : "\(cleanNumberText(store.instaPayFeePercent))%, min \(formatCurrency(store.instaPayMinimumFee)), max \(formatCurrency(store.instaPayMaximumFee))",
                            icon: "percent",
                            semanticColor: .accounts
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section(store.appLanguage == .arabicEgyptian ? "البيانات والنسخ والاستعادة" : "Data, backup & restore") {
                    NavigationLink {
                        StartRealUseChecklistView()
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "قائمة بداية الشهر" : "Month Start Checklist",
                            subtitle: store.appLanguage == .arabicEgyptian ? "راجع الخطوات قبل تسجيل شهر جديد" : "Review the steps before tracking a new month.",
                            icon: "checklist",
                            semanticColor: .setup
                        )
                    }

                    NavigationLink {
                        DataBackupView()
                            .environmentObject(store)
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "نسخة احتياطية يدوية" : "Manual Backup",
                            subtitle: store.appLanguage == .arabicEgyptian ? "صدّر ملف نسخة احتياطية أو استرجع منه يدويًا" : "Export a backup file or restore one manually.",
                            icon: "externaldrive",
                            semanticColor: .backupPrivacy
                        )
                    }
                    .accessibilityIdentifier("button.settingsDataBackup")

                    NavigationLink {
                        ICloudSnapshotSyncView()
                            .environmentObject(store)
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "نسخة iCloud الاحتياطية" : "iCloud backup",
                            subtitle: store.appLanguage == .arabicEgyptian ? "نسخة يدوية خاصة على iCloud، وليست مزامنة تلقائية" : "Manual private iCloud backup copy, not automatic device sync.",
                            icon: "icloud",
                            semanticColor: .backupPrivacy
                        )
                    }
                }

                #if DEBUG
                Section(store.appLanguage == .arabicEgyptian ? "منطقة التطوير" : "Development") {
                    Button(role: .destructive) {
                        isConfirmingReset = true
                    } label: {
                        Text(store.appLanguage == .arabicEgyptian ? "استبدل المحفظة ببيانات تجريبية" : "Replace Wallet with Sample Data")
                    }
                }
                #endif
            }
            .accessibilityIdentifier("screen.settings")
            .navigationTitle(AppText.tabSettings(store.appLanguage))
            .sheet(isPresented: $isEditingInstaPayFees) {
                InstaPayFeeSettingsView()
                    .environmentObject(store)
            }
            #if DEBUG
            .confirmationDialog(
                store.appLanguage == .arabicEgyptian ? "استبدال المحفظة ببيانات تجريبية؟" : "Replace wallet with sample data?",
                isPresented: $isConfirmingReset,
                titleVisibility: .visible
            ) {
                Button(store.appLanguage == .arabicEgyptian ? "استبدال المحفظة" : "Replace Wallet", role: .destructive) {
                    store.resetToSampleData()
                }

                Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel", role: .cancel) { }
            } message: {
                Text(store.appLanguage == .arabicEgyptian ? "ده هيستبدل بيانات المحفظة الحالية ببيانات تجريبية. صدّر نسخة احتياطية الأول لو محتاج تحتفظ ببياناتك الحالية." : "This replaces your current wallet data with sample data. Export a backup first if you need to keep your current data.")
            }
            #endif
        }
    }

    func settingsRow(
        title: String,
        subtitle: String,
        icon: String,
        semanticColor: PocketWiseSemanticColor = .neutral
    ) -> some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(
                systemName: icon,
                semanticColor: semanticColor,
                size: 36,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount, maximumFractionDigits: 2)
    }

    func cleanNumberText(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return "\(amount)"
    }
}

struct ICloudSnapshotSyncView: View {

    @EnvironmentObject private var store: WalletStore

    @State private var cloudSnapshot: WalletDataSnapshot?
    @State private var noBackupFound = false
    @State private var actionMessage: String?
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var isConfirmingBackup = false
    @State private var isConfirmingRestore = false

    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    var body: some View {
        List {
            Section(isAr ? "الحالة" : "Status") {
                statusRow(
                    title: isAr ? "حالة iCloud" : "iCloud backup status",
                    value: availabilityText(store.iCloudAvailability),
                    isError: isUnavailable(store.iCloudAvailability)
                )

                statusRow(
                    title: isAr ? "آخر نسخة احتياطية" : "Last backup saved",
                    value: formattedOptionalDate(
                        store.iCloudRemoteMetadata?.remoteUpdatedAt ?? store.lastKnownRemoteUpdateAt,
                        fallback: isAr ? "لا توجد نسخة بعد" : "No backup yet"
                    )
                )

                statusRow(
                    title: isAr ? "بيانات هذا الجهاز" : "This device data",
                    value: formattedOptionalDate(store.localDataUpdatedAt, fallback: isAr ? "غير محدد" : "Unknown")
                )

                if let deviceName = store.iCloudRemoteMetadata?.deviceName, !deviceName.isEmpty {
                    statusRow(title: isAr ? "آخر جهاز حفظ النسخة" : "Last backed up from", value: deviceName)
                }

                if let lastError = store.lastICloudSyncError, !lastError.isEmpty {
                    Text(localizedICloudError(lastError))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isAr
                        ? "يمكن لـ WalletBoard حفظ نسخة احتياطية يدوية خاصة في iCloud الخاص بك. استعادة البيانات من iCloud تتطلب دائمًا تأكيدًا منك."
                        : "WalletBoard can save a private manual backup copy to your iCloud. Restoring from iCloud always requires confirmation.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text(isAr
                        ? "هذه نسخة احتياطية يدوية، وليست مزامنة تلقائية بين الأجهزة."
                        : "This is a manual iCloud backup copy, not automatic device sync.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section(isAr ? "الإجراءات" : "Actions") {
                Button {
                    isConfirmingBackup = true
                } label: {
                    Label(isAr ? "نسخ احتياطي الآن" : "Back Up Now", systemImage: "icloud.and.arrow.up")
                }
                .disabled(isWorking)

                Button {
                    Task { await viewICloudBackup() }
                } label: {
                    Label(
                        isWorking ? (isAr ? "جاري التحميل..." : "Loading...") : (isAr ? "مراجعة نسخة iCloud" : "Review iCloud Backup"),
                        systemImage: "eye"
                    )
                }
                .disabled(isWorking)
            }

            if noBackupFound {
                Section {
                    Label(
                        isAr ? "لا توجد نسخة احتياطية على iCloud" : "No iCloud backup found",
                        systemImage: "icloud.slash"
                    )
                    .foregroundStyle(.secondary)

                    Text(isAr
                        ? "اضغط «نسخ احتياطي الآن» لإنشاء أول نسخة احتياطية يدوية على iCloud."
                        : "Tap \"Back Up Now\" to create your first manual iCloud backup copy.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            if let cloudSnapshot {
                let backupDevice = store.iCloudRemoteMetadata?.deviceName
                    ?? cloudSnapshot.backupMetadata?.deviceName
                    ?? ""

                Section(isAr ? "نسخة iCloud الاحتياطية" : "iCloud backup") {
                    statusRow(
                        title: isAr ? "تاريخ النسخة" : "Backup Date",
                        value: formattedOptionalDate(cloudSnapshot.exportedAt, fallback: "-")
                    )

                    if !backupDevice.isEmpty {
                        statusRow(title: isAr ? "نُسخت من جهاز" : "Backed up from", value: backupDevice)
                    }

                    if let appVersion = cloudSnapshot.backupMetadata?.appVersion, !appVersion.isEmpty {
                        statusRow(title: isAr ? "إصدار التطبيق" : "App Version", value: appVersion)
                    }

                    statusRow(
                        title: isAr ? "المعاملات / البنود" : "Transactions / Items",
                        value: "\(cloudSnapshot.financialEvents.count)"
                    )
                    statusRow(
                        title: isAr ? "متكررة" : "Recurring",
                        value: "\(recurringCount(in: cloudSnapshot))"
                    )
                    statusRow(
                        title: isAr ? "الحسابات" : "Accounts",
                        value: "\(cloudSnapshot.accounts.count)"
                    )
                    statusRow(
                        title: isAr ? "الميزانيات" : "Budgets",
                        value: "\(cloudSnapshot.monthlyBudgets.count)"
                    )
                    statusRow(
                        title: isAr ? "الأشخاص والديون" : "People & Debts",
                        value: "\(cloudSnapshot.personDebts.count)"
                    )

                    if cloudSnapshot.creditCards.count > 0 {
                        statusRow(
                            title: isAr ? "كروت الائتمان" : "Credit Cards",
                            value: "\(cloudSnapshot.creditCards.count)"
                        )
                    }

                    Text(backupComparisonNote(for: cloudSnapshot))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }

                Section {
                    Button(role: .destructive) {
                        isConfirmingRestore = true
                    } label: {
                        Label(isAr ? "استعادة من نسخة iCloud" : "Restore from iCloud backup", systemImage: "icloud.and.arrow.down")
                    }
                    .disabled(isWorking)

                    Button {
                        self.cloudSnapshot = nil
                        noBackupFound = false
                    } label: {
                        Label(isAr ? "إلغاء العرض" : "Dismiss", systemImage: "xmark.circle")
                    }
                    .foregroundStyle(.secondary)

                    Text(isAr
                        ? "الاستعادة تستبدل بيانات هذا الجهاز. لن يتغير شيء بدون تأكيدك."
                        : "Restore replaces the data on this device. Nothing changes without your confirmation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } header: {
                    Text(isAr ? "الاستعادة" : "Restore")
                }
            }

            if let msg = actionMessage {
                Section {
                    Text(msg)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let err = errorMessage {
                Section {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            #if DEBUG
            Section("Debug — iCloud Status Check") {
                Text("Developer only. Not included in release builds. No data is uploaded or synced.")
                    .font(.footnote)
                    .foregroundStyle(.orange)

                Button {
                    Task { @MainActor in
                        do {
                            let checker = WalletSyncAccountAvailabilityChecker.liveDefault()
                            let result = try await checker.checkAvailability()
                            switch result {
                            case .available:
                                actionMessage = "[Debug] iCloud: Available — boundary is reachable."
                            case .noAccount:
                                actionMessage = "[Debug] iCloud: No Account — no Apple ID signed in."
                            case .restricted:
                                actionMessage = "[Debug] iCloud: Restricted — iCloud restricted on this device."
                            case .couldNotDetermine:
                                actionMessage = "[Debug] iCloud: Could Not Determine."
                            case .temporarilyUnavailable:
                                actionMessage = "[Debug] iCloud: Temporarily Unavailable."
                            case .unknown:
                                actionMessage = "[Debug] iCloud: Unknown status."
                            }
                            errorMessage = nil
                        } catch {
                            errorMessage = "[Debug] iCloud check failed: \(error.localizedDescription)"
                            actionMessage = nil
                        }
                    }
                } label: {
                    Label("Check iCloud Account Status", systemImage: "icloud.and.arrow.up")
                }
                .tint(.orange)
            }
            #endif
        }
        .navigationTitle(isAr ? "نسخة iCloud الاحتياطية" : "iCloud backup")
        .confirmationDialog(
            isAr ? "نسخ احتياطي إلى iCloud؟" : "Back up to iCloud?",
            isPresented: $isConfirmingBackup,
            titleVisibility: .visible
        ) {
            Button(isAr ? "نسخ احتياطي الآن" : "Back Up Now") {
                Task { await performBackup() }
            }

            Button(isAr ? "إلغاء" : "Cancel", role: .cancel) { }
        } message: {
            Text(isAr
                ? "سيتم رفع نسخة احتياطية من بيانات هذا الجهاز إلى iCloud. النسخة الموجودة في iCloud ستُستبدل ببياناتك الحالية."
                : "A backup copy of this device data will be uploaded to iCloud. This overwrites the existing iCloud backup.")
        }
        .confirmationDialog(
            isAr ? "استعادة البيانات من نسخة iCloud؟" : "Restore from iCloud backup?",
            isPresented: $isConfirmingRestore,
            titleVisibility: .visible
        ) {
            Button(isAr ? "استعادة من نسخة iCloud" : "Restore from iCloud backup", role: .destructive) {
                Task { await performRestore() }
            }

            Button(isAr ? "إلغاء" : "Cancel", role: .cancel) { }
        } message: {
            Text(restoreConfirmationMessage)
        }
        .task {
            await store.fetchICloudStatus()
        }
    }

    private func statusRow(title: String, value: String, isError: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            Group {
                if isError {
                    Text(value).foregroundStyle(.red)
                } else {
                    Text(value).foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.trailing)
        }
    }

    private var restoreConfirmationMessage: String {
        guard let snapshot = cloudSnapshot else {
            return isAr
                ? "سيتم استبدال بيانات هذا الجهاز بنسخة iCloud الاحتياطية. سيتم إنشاء نسخة أمان محلية أولًا إن أمكن."
                : "This will replace your device data with the iCloud backup. A local safety backup will be created first where possible."
        }

        let dateStr = formattedOptionalDate(snapshot.exportedAt, fallback: isAr ? "تاريخ غير محدد" : "unknown date")
        let device = store.iCloudRemoteMetadata?.deviceName
            ?? snapshot.backupMetadata?.deviceName
            ?? (isAr ? "جهاز غير معروف" : "unknown device")

        return isAr
            ? "سيتم استبدال بيانات هذا الجهاز بنسخة iCloud المحفوظة في \(dateStr) من جهاز: \(device). سيتم إنشاء نسخة أمان أولًا إن أمكن."
            : "This replaces your device data with the iCloud backup from \(dateStr), saved from \(device). A local safety backup will be created first where possible."
    }

    private func performBackup() async {
        await runICloudAction {
            if await store.uploadBackupToICloud(force: true) {
                cloudSnapshot = nil
                noBackupFound = false
                actionMessage = isAr ? "تم حفظ نسخة احتياطية يدوية على iCloud بنجاح." : "Manual iCloud backup copy saved successfully."
                errorMessage = nil
            } else {
                errorMessage = localizedICloudError(store.lastICloudSyncError ?? "")
                actionMessage = nil
            }
        }
    }

    private func viewICloudBackup() async {
        isWorking = true
        defer { isWorking = false }
        cloudSnapshot = nil
        noBackupFound = false
        errorMessage = nil
        actionMessage = nil

        do {
            let snapshot = try await store.downloadICloudSnapshotForReview()
            cloudSnapshot = snapshot
        } catch WalletICloudSyncError.remoteSnapshotMissing {
            noBackupFound = true
        } catch {
            errorMessage = localizedICloudError(error.localizedDescription)
        }
    }

    private func performRestore() async {
        await runICloudAction {
            let snapshot: WalletDataSnapshot
            if let existing = cloudSnapshot {
                snapshot = existing
            } else {
                snapshot = try await store.downloadICloudSnapshotForReview()
            }
            let safetyBackupURL = try store.createLocalSafetyBackupBeforeICloudReplace()
            try store.restoreFromBackupSnapshot(snapshot)
            store.lastICloudDownloadAt = Date()
            store.lastKnownRemoteUpdateAt = snapshot.exportedAt
            store.iCloudConflictState = .none
            store.lastICloudSyncError = nil
            cloudSnapshot = nil
            noBackupFound = false
            actionMessage = isAr
                ? "تمت الاستعادة من iCloud. نسخة الأمان: \(safetyBackupURL.lastPathComponent)"
                : "Restored from iCloud. Safety backup: \(safetyBackupURL.lastPathComponent)"
            errorMessage = nil
        }
    }

    private func runICloudAction(_ action: @escaping () async throws -> Void) async {
        isWorking = true
        defer { isWorking = false }

        do {
            try await action()
        } catch {
            errorMessage = localizedICloudError(error.localizedDescription)
            actionMessage = nil
        }
    }

    private func recurringCount(in snapshot: WalletDataSnapshot) -> Int {
        snapshot.financialEvents.filter { $0.repeatRule != .none }.count
    }

    private func backupComparisonNote(for snapshot: WalletDataSnapshot) -> String {
        let localDate = store.localDataUpdatedAt
        let cloudDate = snapshot.exportedAt

        if cloudDate > localDate.addingTimeInterval(1) {
            return isAr
                ? "نسخة iCloud أحدث من هذا الجهاز."
                : "iCloud backup is newer than this device."
        }

        if localDate > cloudDate.addingTimeInterval(1) {
            return isAr
                ? "هذا الجهاز أحدث من نسخة iCloud."
                : "This device is newer than the iCloud backup."
        }

        return isAr
            ? "نسخة iCloud وهذا الجهاز متقاربان في التاريخ."
            : "This device and iCloud backup are close in date."
    }

    private func isUnavailable(_ availability: WalletICloudAvailability) -> Bool {
        switch availability {
        case .available, .unknown:
            return false
        default:
            return true
        }
    }

    private func formattedOptionalDate(_ date: Date?, fallback: String = "") -> String {
        guard let date else {
            return fallback.isEmpty ? (isAr ? "غير موجود" : "None") : fallback
        }

        let formatter = DateFormatter()
        formatter.locale = isAr ? Locale(identifier: "ar_EG") : Locale(identifier: "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func availabilityText(_ availability: WalletICloudAvailability) -> String {
        switch availability {
        case .unknown:
            return isAr ? "جاري الفحص..." : "Checking..."
        case .available:
            return isAr ? "متاح" : "Available"
        case .noAccount:
            return isAr ? "تسجيل الدخول مطلوب" : "Sign In Required"
        case .restricted:
            return isAr ? "مقيد" : "Restricted"
        case .couldNotDetermine:
            return isAr ? "تعذر التحديد" : "Could Not Determine"
        case .capabilityNotEnabled:
            return isAr ? "غير مفعّل" : "Not Enabled"
        case .error:
            return isAr ? "خطأ" : "Error"
        }
    }

    private func localizedICloudError(_ message: String) -> String {
        guard isAr else {
            return message.isEmpty ? "iCloud is not available. Check your iCloud account and network connection." : message
        }

        return "iCloud غير متاح. راجع حساب iCloud والإنترنت."
    }
}

struct InstaPayFeeSettingsView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var percentText: String = ""
    @State private var minimumFeeText: String = ""
    @State private var maximumFeeText: String = ""

    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    var body: some View {
        NavigationStack {
            Form {
                Section(isAr ? "قواعد الرسوم" : "Fee rules") {
                    TextField(isAr ? "نسبة الرسوم" : "Fee percent", text: $percentText)
                        .keyboardType(.decimalPad)

                    TextField(isAr ? "أدنى رسوم" : "Minimum fee", text: $minimumFeeText)
                        .keyboardType(.decimalPad)

                    TextField(isAr ? "أقصى رسوم" : "Maximum fee", text: $maximumFeeText)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Text(isAr
                        ? "تُستخدم فقط عند اختيار InstaPay طريقة دفع. وقتها يحفظ التطبيق رسوم البنك كمصروف منفصل."
                        : "Used only when the payment method is InstaPay. The app then saves the bank fee as a separate expense.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(isAr ? "مثال" : "Example") {
                    HStack {
                        Text(isAr ? "تحويل 10,000 جنيه" : "10,000 EGP transfer")
                        Spacer()
                        Text(formatCurrency(sampleFee))
                            .fontWeight(.semibold)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isAr ? "حفظ" : "Save")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(isAr ? "قواعد رسوم InstaPay" : "InstaPay fee rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isAr ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                percentText = cleanNumberText(store.instaPayFeePercent)
                minimumFeeText = cleanNumberText(store.instaPayMinimumFee)
                maximumFeeText = cleanNumberText(store.instaPayMaximumFee)
            }
        }
    }

    private var percentValue: Double {
        Double(percentText.replacingOccurrences(of: ",", with: ".")) ?? -1
    }

    private var minimumFeeValue: Double {
        Double(minimumFeeText.replacingOccurrences(of: ",", with: ".")) ?? -1
    }

    private var maximumFeeValue: Double {
        Double(maximumFeeText.replacingOccurrences(of: ",", with: ".")) ?? -1
    }

    private var canSave: Bool {
        percentValue >= 0 &&
        minimumFeeValue >= 0 &&
        maximumFeeValue >= minimumFeeValue
    }

    private var sampleFee: Double {
        guard canSave else {
            return 0
        }

        let percentageFee = 10_000 * percentValue / 100
        let minimumAppliedFee = max(minimumFeeValue, percentageFee)
        return min(maximumFeeValue, minimumAppliedFee)
    }

    private func save() {
        store.updateInstaPayFeeSettings(
            percent: percentValue,
            minimumFee: minimumFeeValue,
            maximumFee: maximumFeeValue
        )

        dismiss()
    }

    private func cleanNumberText(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return "\(amount)"
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

struct FlexibleSpendingEditorView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var monthlySpendingText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(store.appLanguage == .arabicEgyptian ? "تقدير شهري احتياطي عند عدم وجود ميزانية" : "Default monthly spending fallback") {
                    TextField("0", text: $monthlySpendingText)
                        .keyboardType(.decimalPad)
                        .font(.title2)

                    Text(store.appLanguage == .arabicEgyptian ? "يستخدم فقط إذا لم يتم إدخال ميزانية للشهر المختار. لا تضف الإيجار أو الأقساط أو الاشتراكات هنا." : "Used only when no monthly budget is set for the selected month. Do not include rent, installments, subscriptions, or other fixed obligations here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    HStack {
                        Text(store.appLanguage == .arabicEgyptian ? "التقدير اليومي الاحتياطي" : "Fallback daily estimate")
                        Spacer()
                        Text(formatCurrency(monthlySpendingValue / 30))
                            .fontWeight(.semibold)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()
                            Text(store.appLanguage == .arabicEgyptian ? "حفظ التقدير الاحتياطي" : "Save fallback estimate")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(store.appLanguage == .arabicEgyptian ? "تقدير احتياطي" : "Fallback Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                monthlySpendingText = cleanNumberText(store.monthlyLivingBurn)
            }
        }
    }

    private var monthlySpendingValue: Double {
        Double(monthlySpendingText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var canSave: Bool {
        !monthlySpendingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        monthlySpendingValue >= 0
    }

    private func save() {
        store.updateMonthlyLivingBurn(monthlySpendingValue)
        dismiss()
    }

    private func cleanNumberText(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return "\(amount)"
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let number = NSNumber(value: amount)
        let formatted = formatter.string(from: number) ?? "\(Int(amount))"

        return "\(formatted) EGP"
    }
}

// MARK: - Preview

struct WalletRootView_Previews: PreviewProvider {
    static var previews: some View {
        WalletRootView()
            .environmentObject(WalletStore())
    }
}
