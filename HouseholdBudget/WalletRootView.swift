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

                    Text(store.appLanguage == .arabicEgyptian ? "افهم فلوسك بتروح فين." : "Understand where your money is going.")
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        MonthlySummaryView()
                    } label: {
                        AnalysisCard(
                            title: store.appLanguage == .arabicEgyptian ? "ملخص الشهر" : "Monthly Summary",
                            subtitle: store.appLanguage == .arabicEgyptian ? "المخطط مقابل الفعلي، معدل الصرف، وحالة الشهر." : "See planned vs actual, burn rate, and month status.",
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
                            title: store.appLanguage == .arabicEgyptian ? "أكتر حاجات سحبت فلوس" : "Biggest drains",
                            subtitle: store.appLanguage == .arabicEgyptian ? "أكبر بنود صرف في الشهر المختار." : "Top spending areas for the selected month.",
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
                            title: store.appLanguage == .arabicEgyptian ? "سبب الزيادة" : "Monthly driver analysis",
                            subtitle: store.appLanguage == .arabicEgyptian ? "أكبر الفروق بين الخطة والصرف." : "Biggest gaps between plan and spending.",
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
                            subtitle: store.appLanguage == .arabicEgyptian ? "حركات قادمة واضحة وأرصدة تشغيلية بعد كل حركة." : "Visible upcoming events and running balances.",
                            icon: "calendar.badge.clock"
                        )
                    }
                    .buttonStyle(.plain)

                    Text(store.appLanguage == .arabicEgyptian ? "أدوات تانية" : "Other Tools")
                        .font(.headline)
                        .fontWeight(.bold)
                        .padding(.top, 8)

                    NavigationLink {
                        HistoricalSummaryView()
                    } label: {
                        AnalysisCard(
                            title: store.appLanguage == .arabicEgyptian ? "ملخص الشهور القديمة" : "Historical Summary Data",
                            subtitle: store.appLanguage == .arabicEgyptian ? "إجماليات قديمة بس، من غير تأثير على الأرصدة." : "Summary-only past spending that does not affect balances.",
                            icon: "doc.text.magnifyingglass"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
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
                .frame(width: 36, height: 36)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
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
        .padding(12)
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
                Section(store.appLanguage == .arabicEgyptian ? "تجهيز المحفظة" : "Wallet Setup") {
                    NavigationLink {
                        OnboardingWelcomeView(presentationMode: .settings)
                            .environmentObject(store)
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "مساعد الإعداد" : "Setup Assistant",
                            subtitle: store.appLanguage == .arabicEgyptian ? "واجهة إعداد آمنة بدون تسجيل معاملات" : "Safe setup shell without recording transactions",
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
                            subtitle: store.appLanguage == .arabicEgyptian ? "تعرّف على مزايا التطبيق بسرعة" : "A quick overview of PocketWise features",
                            icon: "play.circle.fill",
                            semanticColor: .setup
                        )
                    }

                    NavigationLink {
                        AppPreferencesView()
                            .environmentObject(store)
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "الملف واللغة" : "Profile & App Preferences",
                            subtitle: store.appLanguage == .arabicEgyptian ? "الاسم، اللغة، ومدة التوقع" : "Display name, language, and forecast horizon",
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
                            subtitle: store.appLanguage == .arabicEgyptian ? "أضف وعدّل الحسابات والأرصدة" : "Add, edit, deactivate, and update balances",
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
                            subtitle: store.appLanguage == .arabicEgyptian ? "إعداد الكروت بدون تغيير الأرصدة" : "Set up cards without changing cash balances",
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
                            subtitle: store.appLanguage == .arabicEgyptian ? "رتّب البنود والبنود الفرعية" : "Add, edit, deactivate, and organize subcategories",
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
                            subtitle: store.appLanguage == .arabicEgyptian ? "احفظ التجار وتصنيفاتهم الافتراضية" : "Save merchants, aliases, and default categories",
                            icon: "storefront",
                            semanticColor: .spending
                        )
                    }

                    HStack {
                        Text(store.appLanguage == .arabicEgyptian ? "الكاش المتاح" : "Available Cash")
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

                    Text(store.appLanguage == .arabicEgyptian ? "بيخفي الأرقام في الشاشات اللي بتعرض البيانات بس." : "Masks read-only amounts across the app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(store.appLanguage == .arabicEgyptian ? "قواعد الدفع" : "Payment Rules") {
                    Button {
                        isEditingInstaPayFees = true
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "رسوم InstaPay" : "InstaPay Fees",
                            subtitle: store.appLanguage == .arabicEgyptian
                                ? "\(cleanNumberText(store.instaPayFeePercent))%، أدنى \(formatCurrency(store.instaPayMinimumFee))، أقصى \(formatCurrency(store.instaPayMaximumFee))"
                                : "\(cleanNumberText(store.instaPayFeePercent))%, min \(formatCurrency(store.instaPayMinimumFee)), max \(formatCurrency(store.instaPayMaximumFee))",
                            icon: "percent",
                            semanticColor: .accounts
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section(store.appLanguage == .arabicEgyptian ? "البيانات والنسخ" : "Data Management") {
                    NavigationLink {
                        StartRealUseChecklistView()
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "قائمة بداية الاستخدام الحقيقي" : "Start Real Use Checklist",
                            subtitle: store.appLanguage == .arabicEgyptian ? "خطوات بداية الشهر قبل الاستخدام اليومي" : "Month-start setup steps before daily tracking",
                            icon: "checklist",
                            semanticColor: .setup
                        )
                    }

                    NavigationLink {
                        DataBackupView()
                            .environmentObject(store)
                    } label: {
                        settingsRow(
                            title: store.appLanguage == .arabicEgyptian ? "نسخة احتياطية" : "Data Backup",
                            subtitle: store.appLanguage == .arabicEgyptian ? "تصدير واستيراد البيانات" : "Manual export and import",
                            icon: "externaldrive",
                            semanticColor: .backupPrivacy
                        )
                    }
                    .accessibilityIdentifier("button.settingsDataBackup")

                    settingsRow(
                        title: store.appLanguage == .arabicEgyptian ? "مزامنة iCloud غير متاحة" : "iCloud Sync unavailable",
                        subtitle: store.appLanguage == .arabicEgyptian ? "استخدم النسخ الاحتياطي اليدوي في هذا الإصدار" : "Use manual backup export/import in this build",
                        icon: "icloud.slash",
                        semanticColor: .backupPrivacy
                    )
                    .foregroundStyle(.secondary)
                }

                #if DEBUG
                Section(store.appLanguage == .arabicEgyptian ? "منطقة التطوير" : "Development") {
                    Button(role: .destructive) {
                        isConfirmingReset = true
                    } label: {
                        Text(store.appLanguage == .arabicEgyptian ? "رجّع المحفظة لبيانات تجريبية" : "Reset Wallet to Sample Data")
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
                store.appLanguage == .arabicEgyptian ? "ترجع المحفظة لبيانات تجريبية؟" : "Reset wallet to sample data?",
                isPresented: $isConfirmingReset,
                titleVisibility: .visible
            ) {
                Button(store.appLanguage == .arabicEgyptian ? "إعادة ضبط المحفظة" : "Reset Wallet", role: .destructive) {
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
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isWorking = false
    @State private var isConfirmingUpload = false
    @State private var isConfirmingReplace = false

    private var localSnapshot: WalletDataSnapshot {
        store.makeBackupSnapshot()
    }

    private var language: AppLanguage {
        store.appLanguage
    }

    private var isArabic: Bool {
        language == .arabicEgyptian
    }

    var body: some View {
        List {
            Section(isArabic ? "الحالة" : "Status") {
                statusRow(
                    title: isArabic ? "توفر iCloud" : "iCloud availability",
                    value: availabilityText(store.iCloudAvailability)
                )

                statusRow(
                    title: isArabic ? "آخر حفظ محلي" : "Last local save",
                    value: formattedOptionalDate(store.localDataUpdatedAt)
                )

                statusRow(
                    title: isArabic ? "آخر نسخة على iCloud" : "Last iCloud backup",
                    value: formattedOptionalDate(store.iCloudRemoteMetadata?.remoteUpdatedAt ?? store.lastKnownRemoteUpdateAt)
                )

                if let metadata = store.iCloudRemoteMetadata {
                    if let deviceName = metadata.deviceName, !deviceName.isEmpty {
                        statusRow(title: isArabic ? "الجهاز" : "Device", value: deviceName)
                    }

                    if let schemaVersion = metadata.schemaVersion {
                        statusRow(title: isArabic ? "نسخة المخطط" : "Schema", value: "\(schemaVersion)")
                    }
                }

                if let lastICloudSyncError = store.lastICloudSyncError,
                   !lastICloudSyncError.isEmpty {
                    Text(localizedICloudError(lastICloudSyncError))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            snapshotSection(
                title: isArabic ? "النسخة المحلية" : "Local Snapshot",
                snapshot: localSnapshot
            )

            if let cloudSnapshot {
                snapshotSection(
                    title: isArabic ? "نسخة iCloud" : "iCloud Snapshot",
                    snapshot: cloudSnapshot
                )
            } else {
                Section(isArabic ? "نسخة iCloud" : "iCloud Snapshot") {
                    Text(isArabic ? "استخدم المقارنة لتحميل ملخص نسخة iCloud بدون تغيير بياناتك." : "Use Compare to load the iCloud snapshot summary without changing your data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section(isArabic ? "الإجراءات" : "Actions") {
                Button {
                    Task { await refreshStatus() }
                } label: {
                    Label(isWorking ? (isArabic ? "جاري الفحص..." : "Checking...") : (isArabic ? "فحص حالة iCloud" : "Check iCloud Status"), systemImage: "icloud")
                }
                .disabled(isWorking)

                Button {
                    isConfirmingUpload = true
                } label: {
                    Label(isArabic ? "رفع نسخة إلى iCloud" : "Upload Backup to iCloud", systemImage: "icloud.and.arrow.up")
                }
                .disabled(isWorking)

                Button {
                    Task { await compareWithICloud() }
                } label: {
                    Label(isWorking ? (isArabic ? "جاري المقارنة..." : "Comparing...") : (isArabic ? "مقارنة المحلي مع iCloud" : "Compare Local vs iCloud"), systemImage: "arrow.left.arrow.right")
                }
                .disabled(isWorking)

                Button(role: .destructive) {
                    Task { await prepareReplaceWithICloud() }
                } label: {
                    Label(isArabic ? "تنزيل من iCloud" : "Download from iCloud", systemImage: "icloud.and.arrow.down")
                }
                .disabled(isWorking)

                Text(isArabic ? "لا يوجد دمج تلقائي أو استبدال صامت. التطبيق يفضل العمل المحلي، وكل استبدال يحتاج تأكيد." : "No automatic merge or silent overwrite. The app remains offline-first, and every replace requires confirmation.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if cloudSnapshot != nil {
                Section(isArabic ? "بعد المقارنة" : "After Compare") {
                    Button(isArabic ? "الاحتفاظ بالمحلي" : "Keep Local") {
                        statusMessage = isArabic ? "تم الاحتفاظ بالبيانات المحلية. لم يتم تغيير أي شيء." : "Kept local data. Nothing was changed."
                        errorMessage = nil
                    }

                    Button(isArabic ? "رفع المحلي إلى iCloud" : "Upload Local to iCloud") {
                        isConfirmingUpload = true
                    }

                    Button(isArabic ? "استبدال المحلي بنسخة iCloud" : "Replace Local with iCloud", role: .destructive) {
                        isConfirmingReplace = true
                    }
                }
            }

            Section(isArabic ? "النتيجة" : "Result") {
                if let statusMessage {
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(isArabic ? "لم يتم تنفيذ أي عملية iCloud في هذه الجلسة." : "No iCloud action has run in this session.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(isArabic ? "مزامنة iCloud" : "iCloud Sync")
        .confirmationDialog(
            isArabic ? "رفع النسخة المحلية إلى iCloud؟" : "Upload local backup to iCloud?",
            isPresented: $isConfirmingUpload,
            titleVisibility: .visible
        ) {
            Button(isArabic ? "رفع المحلي إلى iCloud" : "Upload Local to iCloud") {
                Task { await uploadToICloud() }
            }

            Button(isArabic ? "إلغاء" : "Cancel", role: .cancel) { }
        } message: {
            Text(isArabic ? "سيتم استبدال النسخة الموجودة في iCloud بنسخة من بياناتك المحلية الحالية." : "This overwrites the current snapshot stored in your private iCloud database with your current local data.")
        }
        .confirmationDialog(
            isArabic ? "استبدال المحلي بنسخة iCloud؟" : "Replace local data with iCloud backup?",
            isPresented: $isConfirmingReplace,
            titleVisibility: .visible
        ) {
            Button(isArabic ? "استبدال المحلي بنسخة iCloud" : "Replace Local with iCloud", role: .destructive) {
                Task { await replaceLocalWithICloud() }
            }

            Button(isArabic ? "إلغاء" : "Cancel", role: .cancel) { }
        } message: {
            Text(isArabic ? "سيتم استبدال بيانات التطبيق المحلية بنسخة iCloud. سيتم إنشاء نسخة أمان محلية أولًا إن أمكن." : "This will replace your local wallet data with the iCloud backup. A local safety backup will be created first where possible.")
        }
        .task {
            await refreshStatus()
        }
    }

    private func snapshotSection(title: String, snapshot: WalletDataSnapshot) -> some View {
        Section(title) {
            statusRow(title: isArabic ? "تاريخ النسخة" : "Created", value: formattedOptionalDate(snapshot.exportedAt))
            statusRow(title: isArabic ? "الحسابات" : "Accounts", value: "\(snapshot.accounts.count)")
            statusRow(title: isArabic ? "المعاملات / البنود" : "Transactions / Items", value: "\(snapshot.financialEvents.count)")
            statusRow(title: isArabic ? "الميزانيات" : "Budgets", value: "\(snapshot.monthlyBudgets.count)")
            statusRow(title: isArabic ? "البنود المستقبلية" : "Future items", value: "\(futureItemCount(in: snapshot))")
            statusRow(title: isArabic ? "المتكرر" : "Recurring", value: "\(recurringCount(in: snapshot))")
            statusRow(title: isArabic ? "الأشخاص / الديون" : "People / Debts", value: "\(snapshot.personDebts.count)")
        }
    }

    private func statusRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func refreshStatus() async {
        await runICloudAction {
            await store.fetchICloudStatus()
            statusMessage = isArabic ? "تم تحديث حالة iCloud." : "iCloud status refreshed."
        }
    }

    private func uploadToICloud() async {
        await runICloudAction {
            if await store.uploadBackupToICloud(force: true) {
                cloudSnapshot = nil
                statusMessage = isArabic ? "تم رفع النسخة المحلية إلى iCloud." : "Uploaded local backup to iCloud."
                errorMessage = nil
            } else {
                errorMessage = localizedICloudError(store.lastICloudSyncError ?? "")
                statusMessage = nil
            }
        }
    }

    private func compareWithICloud() async {
        await runICloudAction {
            let snapshot = try await store.downloadICloudSnapshotForReview()
            cloudSnapshot = snapshot
            statusMessage = comparisonMessage(for: snapshot)
            errorMessage = nil
        }
    }

    private func prepareReplaceWithICloud() async {
        await runICloudAction {
            cloudSnapshot = try await store.downloadICloudSnapshotForReview()
            statusMessage = isArabic ? "تم تحميل ملخص نسخة iCloud. أكد الاستبدال لو عايز تكمل." : "Loaded iCloud snapshot summary. Confirm replace if you want to continue."
            errorMessage = nil
            isConfirmingReplace = true
        }
    }

    private func replaceLocalWithICloud() async {
        await runICloudAction {
            let snapshot: WalletDataSnapshot
            if let cloudSnapshot {
                snapshot = cloudSnapshot
            } else {
                snapshot = try await store.downloadICloudSnapshotForReview()
            }
            let safetyBackupURL = try store.createLocalSafetyBackupBeforeICloudReplace()
            try store.restoreFromBackupSnapshot(snapshot)
            store.lastICloudDownloadAt = Date()
            store.lastKnownRemoteUpdateAt = snapshot.exportedAt
            store.iCloudConflictState = .none
            store.lastICloudSyncError = nil
            statusMessage = isArabic ? "تم استبدال البيانات المحلية بنسخة iCloud. نسخة الأمان: \(safetyBackupURL.lastPathComponent)" : "Replaced local data with iCloud backup. Safety backup: \(safetyBackupURL.lastPathComponent)"
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
            statusMessage = nil
        }
    }

    private func comparisonMessage(for snapshot: WalletDataSnapshot) -> String {
        let localDate = store.localDataUpdatedAt
        let cloudDate = snapshot.exportedAt

        if cloudDate > localDate.addingTimeInterval(1) {
            return isArabic ? "نسخة iCloud أحدث من المحلي. لا يوجد تغيير بدون اختيارك." : "iCloud appears newer than local. Nothing changes unless you choose."
        }

        if localDate > cloudDate.addingTimeInterval(1) {
            return isArabic ? "النسخة المحلية أحدث من iCloud. لا يوجد تغيير بدون اختيارك." : "Local appears newer than iCloud. Nothing changes unless you choose."
        }

        return isArabic ? "المحلي و iCloud قريبين في التاريخ. لا يوجد تغيير بدون اختيارك." : "Local and iCloud are close in date. Nothing changes unless you choose."
    }

    private func futureItemCount(in snapshot: WalletDataSnapshot) -> Int {
        snapshot.financialEvents.filter { event in
            event.status == .expected ||
            event.status == .planned ||
            event.status == .unpaid
        }.count
    }

    private func recurringCount(in snapshot: WalletDataSnapshot) -> Int {
        snapshot.financialEvents.filter { $0.repeatRule != .none }.count
    }

    private func formattedOptionalDate(_ date: Date?) -> String {
        guard let date else {
            return isArabic ? "غير موجود" : "None"
        }

        let formatter = DateFormatter()
        formatter.locale = isArabic ? Locale(identifier: "ar_EG") : Locale(identifier: "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func availabilityText(_ availability: WalletICloudAvailability) -> String {
        switch availability {
        case .unknown:
            return isArabic ? "غير معروف" : "Unknown"
        case .available:
            return isArabic ? "متاح" : "Available"
        case .noAccount:
            return isArabic ? "لا يوجد حساب iCloud" : "No iCloud account"
        case .restricted:
            return isArabic ? "مقيد" : "Restricted"
        case .couldNotDetermine:
            return isArabic ? "تعذر التحديد" : "Could not determine"
        case .capabilityNotEnabled:
            return isArabic ? "CloudKit غير مفعّل" : "CloudKit not enabled"
        case .error:
            return isArabic ? "خطأ" : "Error"
        }
    }

    private func localizedICloudError(_ message: String) -> String {
        guard isArabic else {
            return message.isEmpty ? "iCloud is not available. Check iCloud account and network." : message
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
                Section(isAr ? "افتراضات الرسوم" : "Fee Assumptions") {
                    TextField(isAr ? "نسبة الرسوم" : "Fee Percent", text: $percentText)
                        .keyboardType(.decimalPad)

                    TextField(isAr ? "أدنى رسوم" : "Minimum Fee", text: $minimumFeeText)
                        .keyboardType(.decimalPad)

                    TextField(isAr ? "أقصى رسوم" : "Maximum Fee", text: $maximumFeeText)
                        .keyboardType(.decimalPad)
                }

                Section {
                    Text(isAr
                        ? "تُستخدم عند اختيار InstaPay طريقة دفع. يحفظ التطبيق رسوم البنك كمصروف منفصل."
                        : "Used when payment method is InstaPay. The app saves the bank fee as a separate expense.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(isAr ? "مثال" : "Sample") {
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
            .navigationTitle(isAr ? "رسوم InstaPay" : "InstaPay Fees")
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
