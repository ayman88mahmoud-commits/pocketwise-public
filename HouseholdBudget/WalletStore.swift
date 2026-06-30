import Foundation
import Combine

enum TransactionDuplicateSourceKind: Hashable {
    case financialEvent
    case creditCardPurchase
}

struct TransactionDuplicateCandidate: Identifiable, Hashable {
    let id: String
    let sourceKind: TransactionDuplicateSourceKind
    let title: String
    let amount: Double
    let date: Date
    let accountOrCardName: String
    let paymentMethodName: String?
    let categoryName: String?
    let subCategoryName: String?
}

struct TransactionDuplicateCheckRequest {
    var title: String
    var amount: Double
    var date: Date
    var accountName: String? = nil
    var paymentMethodName: String? = nil
    var cardID: UUID? = nil
    var cardName: String? = nil
    var categoryName: String? = nil
    var subCategoryName: String? = nil
    var importIdentity: String? = nil
    var rawImportNote: String? = nil
    var eventType: FinancialEventType = .expense
}

struct ActualSpendingSubcategoryTotal: Identifiable, Hashable {
    var id: String { "\(categoryName)-\(subCategoryName)" }
    let categoryName: String
    let subCategoryName: String
    let totalAmount: Double
    let transactionCount: Int
}

struct ActualSpendingBreakdownItem: Identifiable, Hashable {
    enum Source: Hashable {
        case financialEvent
        case creditCardPurchase
    }

    let id: String
    let title: String
    let amount: Double
    let date: Date
    let createdAt: Date
    let categoryName: String
    let subCategoryName: String
    let paymentMethodName: String?
    let accountName: String?
    let transactionType: String
    let source: Source

    var isInstaPayFee: Bool {
        title.caseInsensitiveCompare("InstaPay Fee") == .orderedSame ||
        subCategoryName.caseInsensitiveCompare("InstaPay Fee") == .orderedSame
    }
}

final class WalletStore: ObservableObject {

    // MARK: - Storage Keys

    private enum StorageKey {
        static let accounts = "wallet_accounts"
        static let categories = "wallet_categories"
        static let walletEvents = "wallet_events"
        static let merchantMemories = "wallet_merchant_memories"
        static let installmentPlans = "wallet_installment_plans"
        static let financialEvents = "wallet_financial_events"
        static let personDebts = "wallet_person_debts"
        static let personDebtEntries = "wallet_person_debt_entries"
        static let monthlyBudgets = "wallet_monthly_budgets"
        static let historicalMonthlySummaries = "wallet_historical_monthly_summaries"
        static let creditCards = "wallet_credit_cards"
        static let creditCardPurchases = "wallet_credit_card_purchases"
        static let creditCardPayments = "wallet_credit_card_payments"
        static let monthlyLivingBurn = "wallet_monthly_living_burn"
        static let runwaySafeBalanceTarget = "wallet_runway_safe_balance_target"
        static let instaPayFeePercent = "wallet_instapay_fee_percent"
        static let instaPayMinimumFee = "wallet_instapay_minimum_fee"
        static let instaPayMaximumFee = "wallet_instapay_maximum_fee"
        static let displayName = "wallet_display_name"
        static let appLanguage = "wallet_app_language"
        static let forecastHorizonMonths = "wallet_forecast_horizon_months"
        static let hideBalances = "wallet_hide_balances"
        static let incomeMode = "wallet_income_mode"
        static let salaryResumeDate = "wallet_salary_resume_date"
        static let localDataUpdatedAt = "wallet_local_data_updated_at"
        static let iCloudSyncEnabled = "wallet_icloud_sync_enabled"
        static let lastICloudUploadAt = "wallet_icloud_last_upload_at"
        static let lastICloudDownloadAt = "wallet_icloud_last_download_at"
        static let lastKnownRemoteUpdateAt = "wallet_icloud_last_remote_update_at"
        static let lastICloudSyncError = "wallet_icloud_last_sync_error"
        static let onboardingSkipped = "wallet_onboarding_skipped"
        static let onboardingCompleted = "wallet_onboarding_completed"
        static let onboardingLastStep = "wallet_onboarding_last_step"
    }

    // MARK: - Published Data

    @Published var accounts: [Account] {
        didSet { saveAccounts() }
    }

    @Published var categories: [Category] {
        didSet { saveCategories() }
    }

    @Published var walletEvents: [WalletEvent] {
        didSet { saveWalletEvents() }
    }

    @Published var merchantMemories: [MerchantMemory] {
        didSet { saveMerchantMemories() }
    }

    @Published var installmentPlans: [InstallmentPlan] {
        didSet { saveInstallmentPlans() }
    }

    @Published var financialEvents: [FinancialEvent] {
        didSet { saveFinancialEvents() }
    }

    @Published var personDebts: [PersonDebt] {
        didSet { savePersonDebts() }
    }

    @Published var personDebtEntries: [PersonDebtEntry] {
        didSet { savePersonDebtEntries() }
    }

    @Published var monthlyBudgets: [WalletMonthlyBudget] {
        didSet { saveMonthlyBudgets() }
    }

    @Published var historicalMonthlySummaries: [HistoricalMonthlySummaryEntry] {
        didSet { saveHistoricalMonthlySummaries() }
    }

    @Published var creditCards: [CreditCard] {
        didSet { saveCreditCards() }
    }

    @Published var creditCardPurchases: [CreditCardPurchase] {
        didSet { saveCreditCardPurchases() }
    }

    @Published var creditCardPayments: [CreditCardPayment] {
        didSet { saveCreditCardPayments() }
    }

    // MARK: - Active Records

    var activeAccounts: [Account] {
        accounts.filter { !$0.isDeleted }
    }

    var activeCategories: [Category] {
        categories.filter { !$0.isDeleted && !isDebugSyncValidationCategory($0) }
    }

    var activeWalletEvents: [WalletEvent] {
        walletEvents.filter { !$0.isDeleted }
    }

    private func isDebugSyncValidationCategory(_ category: Category) -> Bool {
#if DEBUG
        WalletSyncDebugSyntheticMasterDataChangeFactory.isDebugCategory(category)
#else
        false
#endif
    }

    var activeMerchantMemories: [MerchantMemory] {
        merchantMemories.filter { !$0.isDeleted }
    }

    var activeFinancialEvents: [FinancialEvent] {
        financialEvents.filter { !$0.isDeleted }
    }

    var activeInstallmentPlans: [InstallmentPlan] {
        installmentPlans.filter { !$0.isDeleted }
    }

    var activeMonthlyBudgets: [WalletMonthlyBudget] {
        monthlyBudgets.filter { !$0.isDeleted }
    }

    var activePersonDebts: [PersonDebt] {
        personDebts.filter { !$0.isDeleted }
    }

    var activePersonDebtEntries: [PersonDebtEntry] {
        personDebtEntries.filter { !$0.isDeleted }
    }

    var activeHistoricalMonthlySummaries: [HistoricalMonthlySummaryEntry] {
        historicalMonthlySummaries.filter { !$0.isDeleted }
    }

    var activeCreditCardPurchases: [CreditCardPurchase] {
        creditCardPurchases.filter { !$0.isDeleted }
    }

    var activeCreditCardPayments: [CreditCardPayment] {
        creditCardPayments.filter { !$0.isDeleted }
    }

    func activeEntries(for personDebtID: UUID) -> [PersonDebtEntry] {
        activePersonDebtEntries.filter { $0.debtID == personDebtID }
    }

    func activePurchases(for creditCardID: UUID) -> [CreditCardPurchase] {
        activeCreditCardPurchases.filter { $0.cardID == creditCardID }
    }

    func activePayments(for creditCardID: UUID) -> [CreditCardPayment] {
        activeCreditCardPayments.filter { $0.cardID == creditCardID }
    }

    func activeFinancialEvents(for accountName: String) -> [FinancialEvent] {
        activeFinancialEvents.filter {
            $0.accountName == accountName ||
            $0.destinationAccountName == accountName
        }
    }

    @Published var monthlyLivingBurn: Double {
        didSet { saveMonthlyLivingBurn() }
    }

    @Published var runwaySafeBalanceTarget: Double {
        didSet { saveRunwaySafeBalanceTarget() }
    }

    @Published var instaPayFeePercent: Double {
        didSet { saveInstaPayFeeSettings() }
    }

    @Published var instaPayMinimumFee: Double {
        didSet { saveInstaPayFeeSettings() }
    }

    @Published var instaPayMaximumFee: Double {
        didSet { saveInstaPayFeeSettings() }
    }

    @Published var displayName: String {
        didSet { saveAppPreferences() }
    }

    @Published var appLanguage: AppLanguage {
        didSet { saveAppPreferences() }
    }

    @Published var forecastHorizonMonths: Int {
        didSet { saveAppPreferences() }
    }

    @Published var hideBalances: Bool {
        didSet { saveAppPreferences() }
    }

    @Published var incomeMode: IncomeMode {
        didSet { saveAppPreferences() }
    }

    @Published var salaryResumeDate: Date? {
        didSet { saveAppPreferences() }
    }

    @Published var localDataUpdatedAt: Date {
        didSet { saveLocalDataUpdatedAt() }
    }

    @Published var iCloudSyncEnabled: Bool {
        didSet { saveICloudSyncSettings() }
    }

    @Published var lastICloudUploadAt: Date? {
        didSet { saveICloudSyncSettings() }
    }

    @Published var lastICloudDownloadAt: Date? {
        didSet { saveICloudSyncSettings() }
    }

    @Published var lastKnownRemoteUpdateAt: Date? {
        didSet { saveICloudSyncSettings() }
    }

    @Published var lastICloudSyncError: String? {
        didSet { saveICloudSyncSettings() }
    }

    @Published var onboardingSkipped: Bool {
        didSet { saveOnboardingState() }
    }

    @Published var onboardingCompleted: Bool {
        didSet { saveOnboardingState() }
    }

    @Published var onboardingLastStep: Int {
        didSet { saveOnboardingState() }
    }

    @Published var iCloudAvailability: WalletICloudAvailability = .unknown
    @Published var iCloudRemoteMetadata: WalletICloudRemoteMetadata?
    @Published var iCloudConflictState: WalletICloudConflictState = .none

    private let userDefaults: UserDefaults
    private lazy var iCloudSyncService = WalletICloudSyncService.shared

    // MARK: - Init

    @MainActor
    static func loadForStartup() async -> WalletStore {
        await Task.yield()
        return WalletStore()
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        self.accounts = Self.load(
            key: StorageKey.accounts,
            fallback: [],
            userDefaults: userDefaults
        )

        self.categories = Self.load(
            key: StorageKey.categories,
            fallback: [],
            userDefaults: userDefaults
        )

        self.walletEvents = Self.load(
            key: StorageKey.walletEvents,
            fallback: [],
            userDefaults: userDefaults
        )

        self.merchantMemories = Self.load(
            key: StorageKey.merchantMemories,
            fallback: [],
            userDefaults: userDefaults
        )

        self.installmentPlans = Self.load(
            key: StorageKey.installmentPlans,
            fallback: [],
            userDefaults: userDefaults
        )

        self.financialEvents = Self.load(
            key: StorageKey.financialEvents,
            fallback: [],
            userDefaults: userDefaults
        )

        self.personDebts = Self.load(
            key: StorageKey.personDebts,
            fallback: [],
            userDefaults: userDefaults
        )

        self.personDebtEntries = Self.load(
            key: StorageKey.personDebtEntries,
            fallback: [],
            userDefaults: userDefaults
        )

        self.monthlyBudgets = Self.load(
            key: StorageKey.monthlyBudgets,
            fallback: [],
            userDefaults: userDefaults
        )

        self.historicalMonthlySummaries = Self.load(
            key: StorageKey.historicalMonthlySummaries,
            fallback: [],
            userDefaults: userDefaults
        )

        self.creditCards = Self.load(
            key: StorageKey.creditCards,
            fallback: [],
            userDefaults: userDefaults
        )

        self.creditCardPurchases = Self.load(
            key: StorageKey.creditCardPurchases,
            fallback: [],
            userDefaults: userDefaults
        )

        self.creditCardPayments = Self.load(
            key: StorageKey.creditCardPayments,
            fallback: [],
            userDefaults: userDefaults
        )

        self.monthlyLivingBurn = Self.load(
            key: StorageKey.monthlyLivingBurn,
            fallback: 45_000,
            userDefaults: userDefaults
        )

        self.runwaySafeBalanceTarget = Self.load(
            key: StorageKey.runwaySafeBalanceTarget,
            fallback: 0,
            userDefaults: userDefaults
        )

        self.instaPayFeePercent = Self.load(
            key: StorageKey.instaPayFeePercent,
            fallback: 0.1,
            userDefaults: userDefaults
        )

        self.instaPayMinimumFee = Self.load(
            key: StorageKey.instaPayMinimumFee,
            fallback: 0.5,
            userDefaults: userDefaults
        )

        self.instaPayMaximumFee = Self.load(
            key: StorageKey.instaPayMaximumFee,
            fallback: 20,
            userDefaults: userDefaults
        )

        self.displayName = Self.load(
            key: StorageKey.displayName,
            fallback: "",
            userDefaults: userDefaults
        )

        self.appLanguage = Self.load(
            key: StorageKey.appLanguage,
            fallback: .english,
            userDefaults: userDefaults
        )

        self.forecastHorizonMonths = Self.load(
            key: StorageKey.forecastHorizonMonths,
            fallback: 12,
            userDefaults: userDefaults
        )

        self.hideBalances = Self.load(
            key: StorageKey.hideBalances,
            fallback: false,
            userDefaults: userDefaults
        )

        self.incomeMode = Self.load(
            key: StorageKey.incomeMode,
            fallback: .unknown,
            userDefaults: userDefaults
        )

        self.salaryResumeDate = Self.load(
            key: StorageKey.salaryResumeDate,
            fallback: Optional<Date>.none,
            userDefaults: userDefaults
        )

        self.localDataUpdatedAt = Self.load(
            key: StorageKey.localDataUpdatedAt,
            fallback: Date(),
            userDefaults: userDefaults
        )

        self.iCloudSyncEnabled = Self.load(
            key: StorageKey.iCloudSyncEnabled,
            fallback: false,
            userDefaults: userDefaults
        )

        self.lastICloudUploadAt = Self.load(
            key: StorageKey.lastICloudUploadAt,
            fallback: Optional<Date>.none,
            userDefaults: userDefaults
        )

        self.lastICloudDownloadAt = Self.load(
            key: StorageKey.lastICloudDownloadAt,
            fallback: Optional<Date>.none,
            userDefaults: userDefaults
        )

        self.lastKnownRemoteUpdateAt = Self.load(
            key: StorageKey.lastKnownRemoteUpdateAt,
            fallback: Optional<Date>.none,
            userDefaults: userDefaults
        )

        self.lastICloudSyncError = Self.load(
            key: StorageKey.lastICloudSyncError,
            fallback: Optional<String>.none,
            userDefaults: userDefaults
        )

        self.onboardingSkipped = Self.load(
            key: StorageKey.onboardingSkipped,
            fallback: false,
            userDefaults: userDefaults
        )

        self.onboardingCompleted = Self.load(
            key: StorageKey.onboardingCompleted,
            fallback: false,
            userDefaults: userDefaults
        )

        self.onboardingLastStep = Self.load(
            key: StorageKey.onboardingLastStep,
            fallback: 0,
            userDefaults: userDefaults
        )
    }

    // MARK: - Quick Access

    var shouldShowOnboardingOnLaunch: Bool {
        !onboardingSkipped &&
        !onboardingCompleted &&
        !Self.hasPersistedMeaningfulWalletData(userDefaults: userDefaults)
    }

    var availableCash: Double {
        ForecastEngine.calculateAvailableCash(accounts: activeAccounts)
    }

    var dailyLivingBurn: Double {
        max(monthlyLivingBurn, 0) / 30
    }

    var favoriteEvents: [WalletEvent] {
        walletEvents
            .filter { $0.isFavorite && $0.isActive }
            .sorted { $0.name < $1.name }
    }

    var recentPaidEvents: [FinancialEvent] {
        financialEvents
            .filter { $0.status == .paid }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var upcomingEvents: [FinancialEvent] {
        (
            financialEvents.filter { $0.repeatRule == .none } +
            recurringUpcomingExpenseOccurrences() +
            recurringUpcomingIncomeOccurrences() +
            expectedRepaymentEvents()
        )
            .filter {
                $0.status == .unpaid ||
                $0.status == .expected ||
                $0.status == .planned
            }
            .sorted { $0.date < $1.date }
    }

    private func recurringUpcomingExpenseOccurrences() -> [FinancialEvent] {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()

        return (0..<max(forecastHorizonMonths, 1))
            .compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
            .flatMap { monthDate -> [FinancialEvent] in
                let components = calendar.dateComponents([.year, .month], from: monthDate)
                guard let year = components.year, let month = components.month else {
                    return []
                }

                return upcomingKnownExpenseEvents(year: year, month: month)
                    .filter { $0.sourceRecurringEventID != nil }
            }
    }

    private func recurringUpcomingIncomeOccurrences() -> [FinancialEvent] {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()

        return (0..<max(forecastHorizonMonths, 1))
            .compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
            .flatMap { monthDate -> [FinancialEvent] in
                let components = calendar.dateComponents([.year, .month], from: monthDate)
                guard let year = components.year, let month = components.month else {
                    return []
                }

                return upcomingKnownIncomeEvents(year: year, month: month)
                    .filter { $0.sourceRecurringEventID != nil }
            }
    }

    // MARK: - Forecast

    func runway(from date: Date = Date()) -> FinancialRunwayResult {
        ForecastEngine.calculateRunway(
            accounts: activeAccounts,
            financialEvents: activeFinancialEvents,
            monthlyLivingBurn: monthlyLivingBurn,
            from: date
        )
    }

    /// Returns the credit card due items using the same horizon logic as runwayCheck,
    /// allowing an external call site to pass an identical financial picture.
    func creditCardDueItemsForRunway(from startDate: Date, to targetDate: Date) -> [CreditCardDueItem] {
        creditCardDueItems(
            referenceDate: startDate,
            horizonMonths: runwayHorizonMonths(from: startDate, to: targetDate)
        )
    }

    func runwayCheck(targetDate: Date, from date: Date = Date()) -> RunwayCheckResult {
        ForecastEngine.calculateRunwayCheck(
            accounts: activeAccounts,
            financialEvents: activeFinancialEvents + expectedRepaymentEvents(),
            monthlyBudgets: activeMonthlyBudgets,
            creditCardPurchases: activeCreditCardPurchases,
            creditCardDueItems: creditCardDueItems(
                referenceDate: date,
                horizonMonths: runwayHorizonMonths(from: date, to: targetDate)
            ),
            minimumSafeBalance: runwaySafeBalanceTarget,
            from: date,
            targetDate: targetDate
        )
    }

    func monthlyForecasts(
        numberOfMonths: Int = 6,
        from date: Date = Date()
    ) -> [MonthlyForecast] {
        ForecastEngine.buildMonthlyForecast(
            accounts: activeAccounts,
            financialEvents: activeFinancialEvents,
            monthlyLivingBurn: monthlyLivingBurn,
            numberOfMonths: numberOfMonths,
            from: date
        )
    }

    // MARK: - Account Management

    func updateAccountBalance(accountID: UUID, newBalance: Double) {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else {
            return
        }

        accounts[index].balance = newBalance
        accounts[index].updatedAt = Date()
    }

    func updateAccountBalance(accountName: String, newBalance: Double) {
        guard let index = accounts.firstIndex(where: { $0.name == accountName }) else {
            return
        }

        accounts[index].balance = newBalance
        accounts[index].updatedAt = Date()
    }

    func accountNameExists(_ name: String, excluding accountID: UUID? = nil) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return accounts.contains { account in
            account.id != accountID &&
            account.name.caseInsensitiveCompare(cleanName) == .orderedSame
        }
    }

    func accountHasTransactions(_ account: Account) -> Bool {
        financialEvents.contains {
            $0.accountName == account.name ||
            $0.destinationAccountName == account.name
        } ||
        personDebtEntries.contains { $0.accountName == account.name }
    }

    func addAccount(
        name: String,
        type: AccountType,
        balance: Double,
        recognitionAliases: [String] = [],
        recognitionCardEndings: [String] = [],
        appearanceColor: ProviderAppearanceColor? = nil
    ) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty,
              !accountNameExists(cleanName) else {
            return
        }

        accounts.append(
            Account(
                name: cleanName,
                balance: max(balance, 0),
                type: type,
                isActive: true,
                recognitionAliases: cleanRecognitionValues(recognitionAliases),
                recognitionCardEndings: cleanCardEndings(recognitionCardEndings),
                appearanceColor: appearanceColor
            )
        )
    }

    func updateAccount(
        accountID: UUID,
        name: String,
        type: AccountType,
        balance: Double,
        isActive: Bool,
        recognitionAliases: [String]? = nil,
        recognitionCardEndings: [String]? = nil,
        appearanceColor: ProviderAppearanceColor? = nil
    ) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty,
              !accountNameExists(cleanName, excluding: accountID),
              let index = accounts.firstIndex(where: { $0.id == accountID }) else {
            return
        }

        let oldName = accounts[index].name

        accounts[index].name = cleanName
        accounts[index].type = type
        accounts[index].balance = max(balance, 0)
        accounts[index].isActive = isActive
        accounts[index].recognitionAliases = cleanRecognitionValues(recognitionAliases ?? accounts[index].recognitionAliases)
        accounts[index].recognitionCardEndings = cleanCardEndings(recognitionCardEndings ?? accounts[index].recognitionCardEndings)
        accounts[index].appearanceColor = appearanceColor ?? accounts[index].appearanceColor
        accounts[index].updatedAt = Date()

        if oldName != cleanName {
            renameAccountReferences(from: oldName, to: cleanName)
        }
    }

    private func cleanRecognitionValues(_ values: [String]) -> [String] {
        Array(
            Set(
                values
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
    }

    private func cleanCardEndings(_ values: [String]) -> [String] {
        cleanRecognitionValues(
            values.map { value in
                String(value.filter(\.isNumber).suffix(4))
            }
            .filter { $0.count == 4 }
        )
    }

    func deactivateAccount(_ account: Account) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else {
            return
        }

        accounts[index].isActive = false
    }

    func activateAccount(_ account: Account) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else {
            return
        }

        accounts[index].isActive = true
    }

    func deleteAccountIfUnused(_ account: Account) {
        guard !accountHasTransactions(account) else {
            return
        }

        markSyncRecordDeletedLocally(entity: .account, id: account.id)
        accounts.removeAll { $0.id == account.id }

        for index in walletEvents.indices where walletEvents[index].defaultAccountName == account.name {
            walletEvents[index].defaultAccountName = nil
        }

        for index in installmentPlans.indices where installmentPlans[index].accountName == account.name {
            installmentPlans[index].accountName = nil
        }
    }

    private func renameAccountReferences(from oldName: String, to newName: String) {
        for index in financialEvents.indices where financialEvents[index].accountName == oldName {
            financialEvents[index].accountName = newName
        }

        for index in financialEvents.indices where financialEvents[index].destinationAccountName == oldName {
            financialEvents[index].destinationAccountName = newName
        }

        for index in walletEvents.indices where walletEvents[index].defaultAccountName == oldName {
            walletEvents[index].defaultAccountName = newName
        }

        for index in installmentPlans.indices where installmentPlans[index].accountName == oldName {
            installmentPlans[index].accountName = newName
        }

        for index in personDebtEntries.indices where personDebtEntries[index].accountName == oldName {
            personDebtEntries[index].accountName = newName
        }
    }

    func updateMonthlyLivingBurn(_ newValue: Double) {
        monthlyLivingBurn = max(newValue, 0)
    }

    func updateRunwaySafeBalanceTarget(_ newValue: Double) {
        runwaySafeBalanceTarget = max(newValue, 0)
    }

    func updateInstaPayFeeSettings(percent: Double, minimumFee: Double, maximumFee: Double) {
        instaPayFeePercent = max(percent, 0)
        instaPayMinimumFee = max(minimumFee, 0)
        instaPayMaximumFee = max(maximumFee, instaPayMinimumFee)
    }

    func updateAppPreferences(displayName: String, appLanguage: AppLanguage, forecastHorizonMonths: Int, hideBalances: Bool) {
        self.displayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.appLanguage = appLanguage
        self.forecastHorizonMonths = [6, 12, 18, 24].contains(forecastHorizonMonths) ? forecastHorizonMonths : 12
        self.hideBalances = hideBalances
    }

    func updateIncomeSettings(incomeMode: IncomeMode, salaryResumeDate: Date?) {
        self.incomeMode = incomeMode

        switch incomeMode {
        case .noSalaryUntilDate, .vacationUnpaidPeriod:
            self.salaryResumeDate = salaryResumeDate
        case .regularSalaryActive, .irregularIncome, .unknown:
            self.salaryResumeDate = nil
        }
    }

    func skipOnboarding() {
        onboardingSkipped = true
    }

    func completeOnboarding(lastStep: Int = 0) {
        onboardingLastStep = max(lastStep, 0)
        onboardingCompleted = true
    }

    func updateOnboardingLastStep(_ step: Int) {
        onboardingLastStep = max(step, 0)
    }

    func setHideBalances(_ isHidden: Bool) {
        hideBalances = isHidden
    }

    func toggleHideBalances() {
        hideBalances.toggle()
    }

    func displayCurrency(_ amount: Double, maximumFractionDigits: Int = 0) -> String {
        guard !hideBalances else {
            return "••••"
        }

        return formattedCurrency(amount, maximumFractionDigits: maximumFractionDigits)
    }

    func signedDisplayCurrency(_ amount: Double, prefix: String = "", maximumFractionDigits: Int = 0) -> String {
        guard !hideBalances else {
            return "••••"
        }

        return "\(prefix)\(formattedCurrency(amount, maximumFractionDigits: maximumFractionDigits))"
    }

    private func formattedCurrency(_ amount: Double, maximumFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maximumFractionDigits

        let number = NSNumber(value: amount)
        let formatted = formatter.string(from: number) ?? "\(Int(amount))"

        return "\(formatted) EGP"
    }

    func calculateInstaPayFee(for amount: Double) -> Double {
        guard amount > 0 else {
            return 0
        }

        let percentageFee = amount * max(instaPayFeePercent, 0) / 100
        let minimumAppliedFee = max(instaPayMinimumFee, percentageFee)
        return min(instaPayMaximumFee, minimumAppliedFee)
    }

    // MARK: - Category Management

    func activeSubcategories(for categoryName: String) -> [String] {
        guard let category = categories.first(where: { $0.name == categoryName }) else {
            return []
        }

        return category.subcategories.filter { subcategory in
            !category.inactiveSubcategoryNames.contains { inactiveName in
                inactiveName.caseInsensitiveCompare(subcategory) == .orderedSame
            }
        }
    }

    func subcategoriesForEditing(categoryName: String, selectedSubcategoryName: String?) -> [String] {
        var subcategories = activeSubcategories(for: categoryName)

        if let selectedSubcategoryName,
           !selectedSubcategoryName.isEmpty,
           !subcategories.contains(where: { $0.caseInsensitiveCompare(selectedSubcategoryName) == .orderedSame }),
           categories.first(where: { $0.name == categoryName })?.subcategories.contains(where: { $0.caseInsensitiveCompare(selectedSubcategoryName) == .orderedSame }) == true {
            subcategories.append(selectedSubcategoryName)
        }

        return subcategories.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func categoryNameExists(_ name: String, excluding categoryID: UUID? = nil) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return categories.contains { category in
            category.id != categoryID &&
            category.name.caseInsensitiveCompare(cleanName) == .orderedSame
        }
    }

    func subcategoryNameExists(_ name: String, in categoryID: UUID, excluding oldName: String? = nil) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let category = categories.first(where: { $0.id == categoryID }) else {
            return false
        }

        return category.subcategories.contains { subcategory in
            if let oldName,
               subcategory.caseInsensitiveCompare(oldName) == .orderedSame {
                return false
            }

            return subcategory.caseInsensitiveCompare(cleanName) == .orderedSame
        }
    }

    func isSubcategoryActive(_ subcategoryName: String, in categoryName: String) -> Bool {
        guard let category = categories.first(where: { $0.name == categoryName }) else {
            return false
        }

        return !category.inactiveSubcategoryNames.contains { inactiveName in
            inactiveName.caseInsensitiveCompare(subcategoryName) == .orderedSame
        }
    }

    func categoryHasReferences(_ category: Category) -> Bool {
        financialEvents.contains { $0.categoryName == category.name } ||
        walletEvents.contains { $0.categoryName == category.name } ||
        installmentPlans.contains { $0.categoryName == category.name } ||
        monthlyBudgets.contains { budget in
            budget.items.contains { $0.categoryName == category.name }
        } ||
        historicalMonthlySummaries.contains {
            $0.categoryName == category.name
        }
    }

    func subcategoryHasReferences(_ subcategoryName: String, in category: Category) -> Bool {
        financialEvents.contains {
            $0.categoryName == category.name &&
            $0.subCategoryName == subcategoryName
        } ||
        walletEvents.contains {
            $0.categoryName == category.name &&
            $0.subCategoryName == subcategoryName
        } ||
        installmentPlans.contains {
            $0.categoryName == category.name &&
            $0.subCategoryName == subcategoryName
        } ||
        historicalMonthlySummaries.contains {
            $0.categoryName == category.name &&
            $0.subCategoryName == subcategoryName
        }
    }

    func addCategory(name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty,
              !categoryNameExists(cleanName) else {
            return
        }

        categories.append(
            Category(
                name: cleanName,
                subcategories: [],
                isActive: true
            )
        )
    }

    func updateCategory(categoryID: UUID, name: String, isActive: Bool) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty,
              !categoryNameExists(cleanName, excluding: categoryID),
              let index = categories.firstIndex(where: { $0.id == categoryID }) else {
            return
        }

        let oldName = categories[index].name
        categories[index].name = cleanName
        categories[index].isActive = isActive

        if oldName != cleanName {
            renameCategoryReferences(from: oldName, to: cleanName)
        }
    }

    func deactivateCategory(_ category: Category) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
            return
        }

        categories[index].isActive = false
    }

    func activateCategory(_ category: Category) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else {
            return
        }

        categories[index].isActive = true
    }

    func deleteCategoryIfUnused(_ category: Category) {
        guard !categoryHasReferences(category) else {
            return
        }

        markSyncRecordDeletedLocally(entity: .category, id: category.id)
        categories.removeAll { $0.id == category.id }
    }

    func addSubcategory(_ subcategoryName: String, to categoryName: String) {
        let cleanSubcategory = subcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanSubcategory.isEmpty,
              let index = categories.firstIndex(where: { $0.name == categoryName }) else {
            return
        }

        if categories[index].subcategories.contains(where: { $0.caseInsensitiveCompare(cleanSubcategory) == .orderedSame }) {
            categories[index].inactiveSubcategoryNames.removeAll {
                $0.caseInsensitiveCompare(cleanSubcategory) == .orderedSame
            }
            return
        }

        categories[index].subcategories.append(cleanSubcategory)
    }

    func updateSubcategory(
        in categoryID: UUID,
        oldName: String,
        newName: String,
        isActive: Bool
    ) {
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty,
              !subcategoryNameExists(cleanName, in: categoryID, excluding: oldName),
              let categoryIndex = categories.firstIndex(where: { $0.id == categoryID }),
              let subcategoryIndex = categories[categoryIndex].subcategories.firstIndex(where: { $0.caseInsensitiveCompare(oldName) == .orderedSame }) else {
            return
        }

        let categoryName = categories[categoryIndex].name
        categories[categoryIndex].subcategories[subcategoryIndex] = cleanName
        categories[categoryIndex].inactiveSubcategoryNames.removeAll {
            $0.caseInsensitiveCompare(oldName) == .orderedSame ||
            $0.caseInsensitiveCompare(cleanName) == .orderedSame
        }

        if !isActive {
            categories[categoryIndex].inactiveSubcategoryNames.append(cleanName)
        }

        if oldName != cleanName {
            renameSubcategoryReferences(in: categoryName, from: oldName, to: cleanName)
        }
    }

    func deactivateSubcategory(_ subcategoryName: String, in category: Category) {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == category.id }),
              categories[categoryIndex].subcategories.contains(where: { $0.caseInsensitiveCompare(subcategoryName) == .orderedSame }) else {
            return
        }

        if !categories[categoryIndex].inactiveSubcategoryNames.contains(where: { $0.caseInsensitiveCompare(subcategoryName) == .orderedSame }) {
            categories[categoryIndex].inactiveSubcategoryNames.append(subcategoryName)
        }
    }

    func activateSubcategory(_ subcategoryName: String, in category: Category) {
        guard let categoryIndex = categories.firstIndex(where: { $0.id == category.id }) else {
            return
        }

        categories[categoryIndex].inactiveSubcategoryNames.removeAll {
            $0.caseInsensitiveCompare(subcategoryName) == .orderedSame
        }
    }

    func deleteSubcategoryIfUnused(_ subcategoryName: String, in category: Category) {
        guard !subcategoryHasReferences(subcategoryName, in: category),
              let categoryIndex = categories.firstIndex(where: { $0.id == category.id }) else {
            return
        }

        categories[categoryIndex].subcategories.removeAll {
            $0.caseInsensitiveCompare(subcategoryName) == .orderedSame
        }
        categories[categoryIndex].inactiveSubcategoryNames.removeAll {
            $0.caseInsensitiveCompare(subcategoryName) == .orderedSame
        }
    }

    private func renameCategoryReferences(from oldName: String, to newName: String) {
        for index in financialEvents.indices where financialEvents[index].categoryName == oldName {
            financialEvents[index].categoryName = newName
        }

        for index in walletEvents.indices where walletEvents[index].categoryName == oldName {
            walletEvents[index].categoryName = newName
        }

        for index in installmentPlans.indices where installmentPlans[index].categoryName == oldName {
            installmentPlans[index].categoryName = newName
        }

        for budgetIndex in monthlyBudgets.indices {
            for itemIndex in monthlyBudgets[budgetIndex].items.indices
            where monthlyBudgets[budgetIndex].items[itemIndex].categoryName == oldName {
                monthlyBudgets[budgetIndex].items[itemIndex].categoryName = newName
            }
        }

        for index in historicalMonthlySummaries.indices where historicalMonthlySummaries[index].categoryName == oldName {
            historicalMonthlySummaries[index].categoryName = newName
            historicalMonthlySummaries[index].updatedAt = Date()
        }
    }

    private func renameSubcategoryReferences(in categoryName: String, from oldName: String, to newName: String) {
        for index in financialEvents.indices
        where financialEvents[index].categoryName == categoryName &&
        financialEvents[index].subCategoryName == oldName {
            financialEvents[index].subCategoryName = newName
        }

        for index in walletEvents.indices
        where walletEvents[index].categoryName == categoryName &&
        walletEvents[index].subCategoryName == oldName {
            walletEvents[index].subCategoryName = newName
        }

        for index in installmentPlans.indices
        where installmentPlans[index].categoryName == categoryName &&
        installmentPlans[index].subCategoryName == oldName {
            installmentPlans[index].subCategoryName = newName
        }

        for index in historicalMonthlySummaries.indices
        where historicalMonthlySummaries[index].categoryName == categoryName &&
        historicalMonthlySummaries[index].subCategoryName == oldName {
            historicalMonthlySummaries[index].subCategoryName = newName
            historicalMonthlySummaries[index].updatedAt = Date()
        }
    }

    // MARK: - Monthly Budget Planning

    func monthlyBudget(year: Int, month: Int) -> WalletMonthlyBudget? {
        monthlyBudgets.first { $0.year == year && $0.month == month }
    }

    func saveMonthlyBudget(year: Int, month: Int, plannedAmountsByCategory: [String: Double]) {
        if let index = monthlyBudgets.firstIndex(where: { $0.year == year && $0.month == month }) {
            let cleanItems = mergedMonthlyBudgetItems(
                existingItems: monthlyBudgets[index].items,
                plannedAmountsByCategory: plannedAmountsByCategory
            )
            let replacementItemIDs = Set(cleanItems.map(\.id))
            let removedItems = monthlyBudgets[index].items.filter { !replacementItemIDs.contains($0.id) }
            for item in removedItems {
                markHighRiskRecordDeletedLocally(entity: .monthlyBudgetItem, id: item.id, deletedAt: Date())
            }
            monthlyBudgets[index].items = cleanItems
            monthlyBudgets[index].updatedAt = Date()
            return
        }

        let cleanItems = newMonthlyBudgetItems(plannedAmountsByCategory: plannedAmountsByCategory)
        monthlyBudgets.append(
            WalletMonthlyBudget(
                year: year,
                month: month,
                items: cleanItems,
                createdAt: Date(),
                updatedAt: Date()
            )
        )
    }

    private func mergedMonthlyBudgetItems(
        existingItems: [WalletMonthlyBudgetItem],
        plannedAmountsByCategory: [String: Double]
    ) -> [WalletMonthlyBudgetItem] {
        var reusableItemsByKey = Dictionary(grouping: existingItems) { monthlyBudgetItemLogicalKey(for: $0.categoryName) }

        return sanitizedMonthlyBudgetInputs(plannedAmountsByCategory)
            .map { categoryName, plannedAmount in
                let key = monthlyBudgetItemLogicalKey(for: categoryName)
                guard var existingItem = reusableItemsByKey[key]?.first else {
                    return WalletMonthlyBudgetItem(
                        categoryName: categoryName,
                        plannedAmount: plannedAmount
                    )
                }

                reusableItemsByKey[key]?.removeFirst()
                if reusableItemsByKey[key]?.isEmpty == true {
                    reusableItemsByKey[key] = nil
                }

                if existingItem.categoryName != categoryName || existingItem.plannedAmount != plannedAmount {
                    existingItem.categoryName = categoryName
                    existingItem.plannedAmount = plannedAmount
                    existingItem.updatedAt = Date()
                }

                return existingItem
            }
            .sorted { $0.categoryName.localizedCaseInsensitiveCompare($1.categoryName) == .orderedAscending }
    }

    private func newMonthlyBudgetItems(plannedAmountsByCategory: [String: Double]) -> [WalletMonthlyBudgetItem] {
        sanitizedMonthlyBudgetInputs(plannedAmountsByCategory)
            .map { categoryName, plannedAmount in
                WalletMonthlyBudgetItem(
                    categoryName: categoryName,
                    plannedAmount: plannedAmount
                )
            }
            .sorted { $0.categoryName.localizedCaseInsensitiveCompare($1.categoryName) == .orderedAscending }
    }

    private func sanitizedMonthlyBudgetInputs(_ plannedAmountsByCategory: [String: Double]) -> [(categoryName: String, plannedAmount: Double)] {
        plannedAmountsByCategory
            .map { key, value in
                (
                    categoryName: key.trimmingCharacters(in: .whitespacesAndNewlines),
                    plannedAmount: max(value, 0)
                )
            }
            .filter { !$0.categoryName.isEmpty }
    }

    private func monthlyBudgetItemLogicalKey(for categoryName: String) -> String {
        categoryName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func copyMonthlyBudget(from sourceYear: Int, sourceMonth: Int, to targetYear: Int, targetMonth: Int) {
        guard let sourceBudget = monthlyBudget(year: sourceYear, month: sourceMonth) else {
            return
        }

        let plannedAmounts = Dictionary(uniqueKeysWithValues: sourceBudget.items.map { item in
            (item.categoryName, item.plannedAmount)
        })

        saveMonthlyBudget(
            year: targetYear,
            month: targetMonth,
            plannedAmountsByCategory: plannedAmounts
        )
    }

    func actualSpendingByCategory(year: Int, month: Int) -> [String: Double] {
        Dictionary(grouping: actualSpendingBreakdownItems(year: year, month: month)) { item in
            item.categoryName
        }
        .mapValues { items in
            items.map(\.amount).reduce(0, +)
        }
    }

    func actualSpendingBreakdownItems(year: Int, month: Int, categoryName: String? = nil) -> [ActualSpendingBreakdownItem] {
        guard let monthRange = monthRange(year: year, month: month) else {
            return []
        }

        let financialItems = activeFinancialEvents.compactMap { event -> ActualSpendingBreakdownItem? in
            guard event.status == .paid,
                  event.date >= monthRange.start,
                  event.date < monthRange.end,
                  isActualSpendingType(event.type) else {
                return nil
            }

            let resolvedCategoryName = event.categoryName ?? "Uncategorized"
            if let categoryName,
               resolvedCategoryName != categoryName {
                return nil
            }

            return ActualSpendingBreakdownItem(
                id: "event-\(event.id)",
                title: event.title,
                amount: event.amount,
                date: event.date,
                createdAt: event.createdAt,
                categoryName: resolvedCategoryName,
                subCategoryName: event.subCategoryName ?? "Uncategorized",
                paymentMethodName: event.paymentMethodName,
                accountName: event.accountName,
                transactionType: event.type.rawValue,
                source: .financialEvent
            )
        }

        let creditCardItems = activeCreditCardPurchases.compactMap { purchase -> ActualSpendingBreakdownItem? in
            guard purchase.purchaseDate >= monthRange.start,
                  purchase.purchaseDate < monthRange.end else {
                return nil
            }

            if let categoryName,
               purchase.categoryName != categoryName {
                return nil
            }

            let cardName = activeCreditCards.first { $0.id == purchase.cardID }?.name
            return ActualSpendingBreakdownItem(
                id: "card-purchase-\(purchase.id)",
                title: purchase.title,
                amount: purchase.amount,
                date: purchase.purchaseDate,
                createdAt: purchase.createdAt,
                categoryName: purchase.categoryName,
                subCategoryName: purchase.subCategoryName,
                paymentMethodName: "Credit Card",
                accountName: cardName,
                transactionType: "Credit Card Purchase",
                source: .creditCardPurchase
            )
        }

        return (financialItems + creditCardItems).sorted { first, second in
            if first.date == second.date {
                if first.isInstaPayFee != second.isInstaPayFee {
                    return !first.isInstaPayFee
                }

                return first.createdAt > second.createdAt
            }

            return first.date > second.date
        }
    }

    func actualSpendingBySubcategory(year: Int, month: Int) -> [ActualSpendingSubcategoryTotal] {
        guard let monthRange = monthRange(year: year, month: month) else {
            return []
        }

        var totals: [String: (categoryName: String, subCategoryName: String, totalAmount: Double, transactionCount: Int)] = [:]

        for event in activeFinancialEvents
        where event.status == .paid &&
        event.date >= monthRange.start &&
        event.date < monthRange.end &&
        isActualSpendingType(event.type) {
            let categoryName = event.categoryName ?? "Uncategorized"
            let subCategoryName = event.subCategoryName ?? "Uncategorized"
            let key = "\(categoryName)\u{1F}\(subCategoryName)"
            let existing = totals[key] ?? (categoryName, subCategoryName, 0, 0)
            totals[key] = (
                categoryName: categoryName,
                subCategoryName: subCategoryName,
                totalAmount: existing.totalAmount + event.amount,
                transactionCount: existing.transactionCount + 1
            )
        }

        for purchase in activeCreditCardPurchases
        where purchase.purchaseDate >= monthRange.start &&
        purchase.purchaseDate < monthRange.end {
            let key = "\(purchase.categoryName)\u{1F}\(purchase.subCategoryName)"
            let existing = totals[key] ?? (purchase.categoryName, purchase.subCategoryName, 0, 0)
            totals[key] = (
                categoryName: purchase.categoryName,
                subCategoryName: purchase.subCategoryName,
                totalAmount: existing.totalAmount + purchase.amount,
                transactionCount: existing.transactionCount + 1
            )
        }

        return totals.values
            .map { value in
                ActualSpendingSubcategoryTotal(
                    categoryName: value.categoryName,
                    subCategoryName: value.subCategoryName,
                    totalAmount: value.totalAmount,
                    transactionCount: value.transactionCount
                )
            }
            .sorted { $0.totalAmount > $1.totalAmount }
    }

    func upcomingKnownExpenseEvents(year: Int, month: Int) -> [FinancialEvent] {
        guard let monthRange = monthRange(year: year, month: month) else {
            return []
        }

        let oneOffEvents = activeFinancialEvents
            .filter { event in
                event.repeatRule == .none &&
                event.status != .paid &&
                event.status != .cancelled &&
                event.status != .skipped &&
                event.date >= monthRange.start &&
                event.date < monthRange.end &&
                isActualSpendingType(event.type)
            }

        let recurringOccurrences = activeFinancialEvents
            .filter { event in
                event.repeatRule != .none &&
                event.status != .paid &&
                event.status != .cancelled &&
                event.status != .skipped &&
                isActualSpendingType(event.type)
            }
            .compactMap { recurringOccurrenceEvent(for: $0, year: year, month: month) }

        return (oneOffEvents + recurringOccurrences)
            .sorted {
                if $0.date == $1.date {
                    return $0.createdAt < $1.createdAt
                }

                return $0.date < $1.date
            }
    }

    func upcomingKnownExpensesByCategory(year: Int, month: Int) -> [String: Double] {
        Dictionary(grouping: upcomingKnownExpenseEvents(year: year, month: month)) { event in
            event.categoryName ?? "Uncategorized"
        }
        .mapValues { events in
            events.map { $0.recurringAmount(for: $0.date) }.reduce(0, +)
        }
    }

    func upcomingKnownIncomeEvents(year: Int, month: Int) -> [FinancialEvent] {
        guard let monthRange = monthRange(year: year, month: month) else {
            return []
        }

        let oneOffEvents = activeFinancialEvents
            .filter { event in
                event.type == .income &&
                event.repeatRule == .none &&
                event.sourceRecurringEventID == nil &&
                event.status != .paid &&
                event.status != .cancelled &&
                event.status != .skipped &&
                event.date >= monthRange.start &&
                event.date < monthRange.end
            }

        let recurringOccurrences = activeFinancialEvents
            .filter { event in
                event.type == .income &&
                event.repeatRule != .none &&
                event.status != .paid &&
                event.status != .cancelled &&
                event.status != .skipped
            }
            .compactMap { recurringOccurrenceEvent(for: $0, year: year, month: month) }

        return (oneOffEvents + recurringOccurrences)
            .sorted {
                if $0.date == $1.date {
                    return $0.createdAt < $1.createdAt
                }

                return $0.date < $1.date
            }
    }

    func upcomingKnownIncomeEvents(numberOfMonths: Int? = nil, from date: Date = Date()) -> [FinancialEvent] {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let months = max(numberOfMonths ?? forecastHorizonMonths, 1)

        return (0..<months)
            .compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
            .flatMap { monthDate -> [FinancialEvent] in
                let components = calendar.dateComponents([.year, .month], from: monthDate)
                guard let year = components.year, let month = components.month else {
                    return []
                }

                return upcomingKnownIncomeEvents(year: year, month: month)
            }
            .sorted {
                if $0.date == $1.date {
                    return $0.createdAt < $1.createdAt
                }

                return $0.date < $1.date
            }
    }

    func paidRecurringOccurrence(sourceID: UUID, year: Int, month: Int) -> FinancialEvent? {
        activeFinancialEvents.first { event in
            event.status == .paid &&
            event.sourceRecurringEventID == sourceID &&
            event.recurringOccurrenceYear == year &&
            event.recurringOccurrenceMonth == month
        }
    }

    // Total income for a given month: synthesized expected recurring + one-time expected + already-received.
    // Use this instead of directly filtering financialEvents for income, which misses synthesized recurring occurrences.
    func monthlyBudgetIncome(year: Int, month: Int) -> Double {
        let expectedTotal = upcomingKnownIncomeEvents(year: year, month: month)
            .map(\.amount).reduce(0, +)

        guard let range = monthRange(year: year, month: month) else {
            return expectedTotal
        }

        let paidOneOff = activeFinancialEvents
            .filter { event in
                event.type == .income &&
                event.status == .paid &&
                event.repeatRule == .none &&
                event.sourceRecurringEventID == nil &&
                event.date >= range.start &&
                event.date < range.end
            }
            .map(\.amount).reduce(0, +)

        let paidRecurring = activeFinancialEvents
            .filter { event in
                event.type == .income &&
                event.status == .paid &&
                event.sourceRecurringEventID != nil &&
                event.recurringOccurrenceYear == year &&
                event.recurringOccurrenceMonth == month
            }
            .map(\.amount).reduce(0, +)

        return expectedTotal + paidOneOff + paidRecurring
    }

    @discardableResult
    func markRecurringOccurrencePaid(
        series: FinancialEvent,
        occurrenceDate: Date,
        amount: Double,
        accountName: String,
        paymentDate: Date,
        paymentMethodName: String? = nil,
        categoryName: String? = nil,
        subCategoryName: String? = nil,
        note: String?
    ) -> Bool {
        let components = Calendar.current.dateComponents([.year, .month], from: occurrenceDate)
        guard let year = components.year,
              let month = components.month,
              amount > 0,
              accounts.contains(where: { $0.name == accountName }) else {
            return false
        }

        guard paidRecurringOccurrence(sourceID: series.id, year: year, month: month) == nil else {
            return false
        }

        let paidEvent = FinancialEvent(
            type: series.type,
            status: .paid,
            title: series.title,
            amount: amount,
            date: paymentDate,
            accountName: accountName,
            paymentMethodName: paymentMethodName ?? series.paymentMethodName,
            walletEventName: series.walletEventName,
            categoryName: categoryName ?? series.categoryName,
            subCategoryName: subCategoryName ?? series.subCategoryName,
            incomeType: series.incomeType,
            reimbursementCategoryName: series.reimbursementCategoryName,
            repeatRule: .none,
            confidence: .high,
            sourceRecurringEventID: series.id,
            recurringOccurrenceYear: year,
            recurringOccurrenceMonth: month,
            note: note,
            createdAt: Date()
        )

        addFinancialEvent(paidEvent)
        return paidRecurringOccurrence(sourceID: series.id, year: year, month: month) != nil
    }

    @discardableResult
    func skipRecurringOccurrence(seriesID: UUID, occurrenceDate: Date) -> Bool {
        guard let index = financialEvents.firstIndex(where: { $0.id == seriesID }) else {
            return false
        }

        let components = Calendar.current.dateComponents([.year, .month], from: occurrenceDate)
        guard let year = components.year,
              let month = components.month else {
            return false
        }

        var overrides = financialEvents[index].recurringScheduleOverrides ?? []
        let existingAmount = financialEvents[index].recurringAmount(for: occurrenceDate)

        if let overrideIndex = overrides.firstIndex(where: { $0.year == year && $0.month == month }) {
            overrides[overrideIndex].amount = existingAmount
            overrides[overrideIndex].isSkipped = true
            overrides[overrideIndex].updatedAt = Date()
        } else {
            overrides.append(
                RecurringScheduleOverride(
                    year: year,
                    month: month,
                    amount: existingAmount,
                    isSkipped: true,
                    updatedAt: Date()
                )
            )
        }

        financialEvents[index].recurringScheduleOverrides = overrides
        return true
    }

    func historicalSummaries(year: Int, month: Int) -> [HistoricalMonthlySummaryEntry] {
        historicalMonthlySummaries
            .filter { $0.year == year && $0.month == month }
            .sorted {
                if $0.categoryName == $1.categoryName {
                    return $0.subCategoryName.localizedCaseInsensitiveCompare($1.subCategoryName) == .orderedAscending
                }

                return $0.categoryName.localizedCaseInsensitiveCompare($1.categoryName) == .orderedAscending
            }
    }

    func historicalSummarySpendingByCategory(year: Int, month: Int) -> [String: Double] {
        Dictionary(grouping: historicalSummaries(year: year, month: month)) { entry in
            entry.categoryName
        }
        .mapValues { entries in
            entries.map { $0.amount }.reduce(0, +)
        }
    }

    func historicalSummaryTotal(year: Int, month: Int) -> Double {
        historicalSummaries(year: year, month: month)
            .map { $0.amount }
            .reduce(0, +)
    }

    func addHistoricalMonthlySummary(
        year: Int,
        month: Int,
        categoryName: String,
        subCategoryName: String,
        amount: Double,
        note: String?
    ) {
        let cleanCategoryName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSubCategoryName = subCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard year >= 1900,
              month >= 1,
              month <= 12,
              amount > 0,
              categories.contains(where: { $0.name == cleanCategoryName }),
              categorySubcategoryExists(categoryName: cleanCategoryName, subCategoryName: cleanSubCategoryName) else {
            return
        }

        historicalMonthlySummaries.append(
            HistoricalMonthlySummaryEntry(
                year: year,
                month: month,
                categoryName: cleanCategoryName,
                subCategoryName: cleanSubCategoryName,
                amount: amount,
                note: cleanNote?.isEmpty == true ? nil : cleanNote
            )
        )
    }

    func updateHistoricalMonthlySummary(
        entryID: UUID,
        categoryName: String,
        subCategoryName: String,
        amount: Double,
        note: String?
    ) {
        let cleanCategoryName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSubCategoryName = subCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let index = historicalMonthlySummaries.firstIndex(where: { $0.id == entryID }),
              amount > 0,
              categories.contains(where: { $0.name == cleanCategoryName }),
              categorySubcategoryExists(categoryName: cleanCategoryName, subCategoryName: cleanSubCategoryName) else {
            return
        }

        historicalMonthlySummaries[index].categoryName = cleanCategoryName
        historicalMonthlySummaries[index].subCategoryName = cleanSubCategoryName
        historicalMonthlySummaries[index].amount = amount
        historicalMonthlySummaries[index].note = cleanNote?.isEmpty == true ? nil : cleanNote
        historicalMonthlySummaries[index].updatedAt = Date()
    }

    func deleteHistoricalMonthlySummary(_ entry: HistoricalMonthlySummaryEntry) {
        markSyncRecordDeletedLocally(entity: .historicalMonthlySummary, id: entry.id)
        historicalMonthlySummaries.removeAll { $0.id == entry.id }
    }

    // MARK: - Credit Cards

    var activeCreditCards: [CreditCard] {
        creditCards
            .filter { $0.isActive && !$0.isDeleted }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func addCreditCard(
        name: String,
        bankName: String,
        lastFourDigits: String?,
        cardNetwork: CreditCardNetwork,
        appearanceColor: ProviderAppearanceColor? = nil,
        creditLimit: Double,
        openingOutstandingBalance: Double = 0,
        openingOutstandingDate: Date? = nil,
        statementClosingDay: Int,
        paymentDueDay: Int,
        defaultPaymentAccountName: String?,
        note: String?
    ) {
        let card = CreditCard(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            bankName: bankName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastFourDigits: cleanCreditCardLastFourDigits(lastFourDigits),
            cardNetwork: cardNetwork,
            appearanceColor: appearanceColor,
            creditLimit: creditLimit,
            openingOutstandingBalance: max(openingOutstandingBalance, 0),
            openingOutstandingDate: openingOutstandingBalance > 0 ? openingOutstandingDate : nil,
            statementClosingDay: statementClosingDay,
            paymentDueDay: paymentDueDay,
            defaultPaymentAccountName: cleanOptionalText(defaultPaymentAccountName),
            isActive: true,
            note: cleanOptionalText(note)
        )

        guard isValidCreditCard(card) else {
            return
        }

        creditCards.append(card)
    }

    func updateCreditCard(_ card: CreditCard) {
        guard let index = creditCards.firstIndex(where: { $0.id == card.id }) else {
            return
        }

        var updatedCard = card
        updatedCard.name = updatedCard.name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedCard.bankName = updatedCard.bankName.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedCard.lastFourDigits = cleanCreditCardLastFourDigits(updatedCard.lastFourDigits)
        updatedCard.openingOutstandingBalance = max(updatedCard.openingOutstandingBalance, 0)
        if updatedCard.openingOutstandingBalance <= 0 {
            updatedCard.openingOutstandingDate = nil
        }
        updatedCard.defaultPaymentAccountName = cleanOptionalText(updatedCard.defaultPaymentAccountName)
        updatedCard.note = cleanOptionalText(updatedCard.note)
        updatedCard.updatedAt = Date()

        guard isValidCreditCard(updatedCard) else {
            return
        }

        creditCards[index] = updatedCard
    }

    func deactivateCreditCard(_ card: CreditCard) {
        guard let index = creditCards.firstIndex(where: { $0.id == card.id }) else {
            return
        }

        creditCards[index].isActive = false
        creditCards[index].updatedAt = Date()
    }

    func creditCardOutstanding(cardID: UUID) -> Double {
        let openingOutstanding = activeCreditCards.first(where: { $0.id == cardID })?.openingOutstandingBalance ?? 0

        let totalPurchases = activeCreditCardPurchases
            .filter { $0.cardID == cardID }
            .map(\.amount)
            .reduce(0, +)

        let totalPayments = activeCreditCardPayments
            .filter { $0.cardID == cardID }
            .map(\.amount)
            .reduce(0, +)

        return max(openingOutstanding + totalPurchases - totalPayments, 0)
    }

    func creditCardPurchaseTotal(cardID: UUID) -> Double {
        activeCreditCardPurchases
            .filter { $0.cardID == cardID }
            .map(\.amount)
            .reduce(0, +)
    }

    func creditCardPaymentTotal(cardID: UUID) -> Double {
        activeCreditCardPayments
            .filter { $0.cardID == cardID }
            .map(\.amount)
            .reduce(0, +)
    }

    func creditCardDueItems(referenceDate: Date = Date(), horizonMonths: Int? = nil) -> [CreditCardDueItem] {
        activeCreditCards.compactMap { card in
            let ledger = creditCardStatementLedger(
                cardID: card.id,
                referenceDate: referenceDate,
                horizonMonths: horizonMonths ?? forecastHorizonMonths
            )

            guard let statement = ledger.first(where: { $0.remainingDue > 0 }) else {
                return nil
            }

            return CreditCardDueItem(
                cardID: statement.cardID,
                cardName: statement.cardName,
                dueAmount: statement.remainingDue,
                outstandingAmount: creditCardOutstanding(cardID: statement.cardID),
                statementClosingDate: statement.statementClosingDate,
                dueDate: statement.paymentDueDate,
                defaultPaymentAccountName: card.defaultPaymentAccountName,
                statusLabel: "Credit Card Due"
            )
        }
        .sorted {
            if $0.dueDate == $1.dueDate {
                return $0.cardName.localizedCaseInsensitiveCompare($1.cardName) == .orderedAscending
            }

            return $0.dueDate < $1.dueDate
        }
    }

    func creditCardStatementLedger(
        cardID: UUID,
        referenceDate: Date = Date(),
        horizonMonths: Int? = nil
    ) -> [CreditCardStatementLedgerEntry] {
        guard let card = activeCreditCards.first(where: { $0.id == cardID }) else {
            return []
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: referenceDate)
        let horizonEnd = calendar.date(
            byAdding: .month,
            value: max(horizonMonths ?? forecastHorizonMonths, 1),
            to: start
        )
        let statementDates = creditCardStatementClosingDates(
            card: card,
            referenceDate: start,
            horizonEnd: horizonEnd
        )
        let openingStatementDate = statementDates.first { statementDate in
            guard let dueDate = creditCardDueDate(
                statementClosingDate: statementDate,
                paymentDueDay: card.paymentDueDay
            ) else {
                return false
            }

            return dueDate >= start
        }
        let cardPurchases = activeCreditCardPurchases
            .filter { $0.cardID == card.id }
            .sorted {
                if $0.purchaseDate == $1.purchaseDate {
                    return $0.createdAt < $1.createdAt
                }

                return $0.purchaseDate < $1.purchaseDate
            }
        var remainingPaymentAllocations = activeCreditCardPayments
            .filter { $0.cardID == card.id }
            .sorted {
                if $0.paymentDate == $1.paymentDate {
                    return $0.createdAt < $1.createdAt
                }

                return $0.paymentDate < $1.paymentDate
            }
            .map { payment in
                CreditCardPaymentAllocationState(payment: payment, remainingAmount: payment.amount)
            }
        let totalPayments = remainingPaymentAllocations
            .map(\.remainingAmount)
            .reduce(0, +)
        var cumulativeStatementCharges = 0.0
        var ledger: [CreditCardStatementLedgerEntry] = []

        for statementClosingDate in statementDates {
            guard let paymentDueDate = creditCardDueDate(
                statementClosingDate: statementClosingDate,
                paymentDueDay: card.paymentDueDay
            ) else {
                continue
            }

            if let horizonEnd,
               paymentDueDate >= horizonEnd {
                continue
            }

            let purchasesInStatement = cardPurchases.filter { purchase in
                creditCardStatementClosingDate(
                    forPurchaseDate: purchase.purchaseDate,
                    statementClosingDay: card.statementClosingDay
                ) == statementClosingDate
            }
            let statementPurchaseTotal = purchasesInStatement.map(\.amount).reduce(0, +)
            let openingOwedIncluded = statementClosingDate == openingStatementDate ? card.openingOutstandingBalance : 0
            let statementChargeTotal = openingOwedIncluded + statementPurchaseTotal

            guard statementChargeTotal > 0 else {
                continue
            }

            var remainingDue = statementChargeTotal
            var paymentsApplied: [CreditCardStatementPaymentAllocation] = []

            for index in remainingPaymentAllocations.indices where remainingDue > 0 {
                let availablePayment = remainingPaymentAllocations[index].remainingAmount
                guard availablePayment > 0 else {
                    continue
                }

                let appliedAmount = min(remainingDue, availablePayment)
                remainingDue -= appliedAmount
                remainingPaymentAllocations[index].remainingAmount -= appliedAmount

                let payment = remainingPaymentAllocations[index].payment
                paymentsApplied.append(
                    CreditCardStatementPaymentAllocation(
                        id: "\(payment.id.uuidString)-\(statementClosingDate.timeIntervalSince1970)",
                        paymentID: payment.id,
                        fromAccountName: payment.fromAccountName,
                        paymentDate: payment.paymentDate,
                        amount: appliedAmount,
                        note: payment.note
                    )
                )
            }

            let paymentsAppliedTotal = paymentsApplied.map(\.amount).reduce(0, +)
            cumulativeStatementCharges += statementChargeTotal
            let totalOutstandingAfterStatement = max(cumulativeStatementCharges - totalPayments, 0)
            let statusLabel = creditCardStatementStatusLabel(
                dueDate: paymentDueDate,
                remainingDue: remainingDue,
                paymentsAppliedTotal: paymentsAppliedTotal,
                statementChargeTotal: statementChargeTotal,
                referenceDate: start
            )

            ledger.append(
                CreditCardStatementLedgerEntry(
                    cardID: card.id,
                    cardName: card.name,
                    statementClosingDate: statementClosingDate,
                    paymentDueDate: paymentDueDate,
                    openingOwedIncluded: openingOwedIncluded,
                    purchases: purchasesInStatement,
                    paymentsApplied: paymentsApplied,
                    statementPurchaseTotal: statementPurchaseTotal,
                    paymentsAppliedTotal: paymentsAppliedTotal,
                    remainingDue: max(remainingDue, 0),
                    totalOutstandingAfterStatement: totalOutstandingAfterStatement,
                    statusLabel: statusLabel
                )
            )
        }

        return ledger
    }

    private struct CreditCardPaymentAllocationState {
        var payment: CreditCardPayment
        var remainingAmount: Double
    }

    private func creditCardStatementStatusLabel(
        dueDate: Date,
        remainingDue: Double,
        paymentsAppliedTotal: Double,
        statementChargeTotal: Double,
        referenceDate: Date
    ) -> String {
        if remainingDue <= 0 {
            return "Paid"
        }

        if dueDate < referenceDate {
            return "Overdue"
        }

        if paymentsAppliedTotal > 0 && paymentsAppliedTotal < statementChargeTotal {
            return "Partially Paid"
        }

        if dueDate == referenceDate {
            return "Due"
        }

        return "Upcoming"
    }

    func addCreditCardPurchase(
        cardID: UUID,
        title: String,
        amount: Double,
        purchaseDate: Date,
        categoryName: String,
        subCategoryName: String,
        note: String?
    ) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCategoryName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSubCategoryName = subCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard amount > 0,
              !cleanTitle.isEmpty,
              creditCards.contains(where: { $0.id == cardID && $0.isActive }),
              categories.contains(where: { $0.name == cleanCategoryName }),
              categorySubcategoryExists(categoryName: cleanCategoryName, subCategoryName: cleanSubCategoryName) else {
            return
        }

        creditCardPurchases.append(
            CreditCardPurchase(
                id: UUID(),
                cardID: cardID,
                title: cleanTitle,
                amount: amount,
                purchaseDate: purchaseDate,
                categoryName: cleanCategoryName,
                subCategoryName: cleanSubCategoryName,
                note: cleanNote?.isEmpty == true ? nil : cleanNote,
                createdAt: Date(),
                updatedAt: Date()
            )
        )
    }

    func deleteCreditCardPurchase(_ purchase: CreditCardPurchase) {
        markHighRiskRecordDeletedLocally(entity: .creditCardPurchase, id: purchase.id, deletedAt: Date())
        creditCardPurchases.removeAll { $0.id == purchase.id }
    }

    func updateCreditCardPurchase(_ purchase: CreditCardPurchase) {
        let cleanTitle = purchase.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCategoryName = purchase.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSubCategoryName = purchase.subCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = purchase.note?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let index = creditCardPurchases.firstIndex(where: { $0.id == purchase.id }),
              purchase.amount > 0,
              !cleanTitle.isEmpty,
              creditCards.contains(where: { $0.id == purchase.cardID }),
              categories.contains(where: { $0.name == cleanCategoryName }),
              categorySubcategoryExists(categoryName: cleanCategoryName, subCategoryName: cleanSubCategoryName) else {
            return
        }

        var updatedPurchase = purchase
        updatedPurchase.title = cleanTitle
        updatedPurchase.categoryName = cleanCategoryName
        updatedPurchase.subCategoryName = cleanSubCategoryName
        updatedPurchase.note = cleanNote?.isEmpty == true ? nil : cleanNote
        updatedPurchase.createdAt = creditCardPurchases[index].createdAt
        updatedPurchase.updatedAt = Date()

        creditCardPurchases[index] = updatedPurchase
    }

    func addCreditCardPayment(
        cardID: UUID,
        fromAccountName: String,
        amount: Double,
        paymentDate: Date,
        note: String?
    ) -> Bool {
        let cleanAccountName = fromAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let outstanding = creditCardOutstanding(cardID: cardID)

        guard creditCards.contains(where: { $0.id == cardID }),
              let accountIndex = accounts.firstIndex(where: { $0.name == cleanAccountName }),
              amount > 0,
              amount <= outstanding,
              accounts[accountIndex].balance >= amount else {
            return false
        }

        accounts[accountIndex].balance -= amount
        accounts[accountIndex].updatedAt = Date()
        creditCardPayments.append(
            CreditCardPayment(
                id: UUID(),
                cardID: cardID,
                fromAccountName: cleanAccountName,
                amount: amount,
                paymentDate: paymentDate,
                note: cleanNote?.isEmpty == true ? nil : cleanNote,
                createdAt: Date(),
                updatedAt: Date()
            )
        )

        return true
    }

    func deleteCreditCardPayment(_ payment: CreditCardPayment) -> Bool {
        guard let paymentIndex = creditCardPayments.firstIndex(where: { $0.id == payment.id }),
              let accountIndex = accounts.firstIndex(where: { $0.name == payment.fromAccountName }) else {
            return false
        }

        accounts[accountIndex].balance += payment.amount
        accounts[accountIndex].updatedAt = Date()
        markHighRiskRecordDeletedLocally(entity: .creditCardPayment, id: payment.id, deletedAt: Date())
        creditCardPayments.remove(at: paymentIndex)
        return true
    }

    private func categorySubcategoryExists(categoryName: String, subCategoryName: String) -> Bool {
        guard let category = categories.first(where: { $0.name == categoryName }) else {
            return false
        }

        return category.subcategories.contains { $0.caseInsensitiveCompare(subCategoryName) == .orderedSame }
    }

    private func cleanCreditCardLastFourDigits(_ value: String?) -> String? {
        let digits = value?.filter(\.isNumber)

        guard let digits,
              !digits.isEmpty else {
            return nil
        }

        return String(digits)
    }

    private func cleanOptionalText(_ value: String?) -> String? {
        let cleanValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanValue?.isEmpty == false ? cleanValue : nil
    }

    private func creditCardStatementEligibleBalance(card: CreditCard, statementClosingDate: Date) -> Double {
        let openingOutstanding = card.openingOutstandingBalance
        let eligiblePurchases = activeCreditCardPurchases
            .filter { purchase in
                purchase.cardID == card.id &&
                creditCardStatementClosingDate(
                    forPurchaseDate: purchase.purchaseDate,
                    statementClosingDay: card.statementClosingDay
                ).map { $0 <= statementClosingDate } == true
            }
            .map(\.amount)
            .reduce(0, +)

        return openingOutstanding + eligiblePurchases
    }

    private func creditCardStatementClosingDates(card: CreditCard, referenceDate: Date, horizonEnd: Date?) -> [Date] {
        let calendar = Calendar.current
        let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)) ?? referenceDate
        let monthCount: Int

        if let horizonEnd {
            let horizonMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: horizonEnd)) ?? horizonEnd
            monthCount = max((calendar.dateComponents([.month], from: startMonth, to: horizonMonth).month ?? 0) + 2, 3)
        } else {
            monthCount = 18
        }

        return (-1..<monthCount).compactMap { monthOffset in
            guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: startMonth) else {
                return nil
            }

            let components = calendar.dateComponents([.year, .month], from: monthDate)
            guard let year = components.year,
                  let month = components.month else {
                return nil
            }

            return creditCardStatementClosingDate(year: year, month: month, statementClosingDay: card.statementClosingDay)
        }
        .sorted()
    }

    private func creditCardStatementClosingDate(forPurchaseDate purchaseDate: Date, statementClosingDay: Int) -> Date? {
        let calendar = Calendar.current
        let purchaseStart = calendar.startOfDay(for: purchaseDate)
        let components = calendar.dateComponents([.year, .month], from: purchaseStart)

        guard let year = components.year,
              let month = components.month,
              let thisMonthClosingDate = creditCardStatementClosingDate(
                year: year,
                month: month,
                statementClosingDay: statementClosingDay
              ) else {
            return nil
        }

        if purchaseStart <= thisMonthClosingDate {
            return thisMonthClosingDate
        }

        guard let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: thisMonthClosingDate) else {
            return nil
        }

        let nextComponents = calendar.dateComponents([.year, .month], from: nextMonthDate)
        guard let nextYear = nextComponents.year,
              let nextMonth = nextComponents.month else {
            return nil
        }

        return creditCardStatementClosingDate(
            year: nextYear,
            month: nextMonth,
            statementClosingDay: statementClosingDay
        )
    }

    private func creditCardStatementClosingDate(year: Int, month: Int, statementClosingDay: Int) -> Date? {
        guard (1...31).contains(statementClosingDay) else {
            return nil
        }

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let firstDay = calendar.date(from: components),
              let dayRange = calendar.range(of: .day, in: .month, for: firstDay) else {
            return nil
        }

        components.day = min(statementClosingDay, dayRange.count)
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    private func creditCardDueDate(statementClosingDate: Date, paymentDueDay: Int) -> Date? {
        guard (1...31).contains(paymentDueDay) else {
            return nil
        }

        let calendar = Calendar.current
        let closingComponents = calendar.dateComponents([.year, .month, .day], from: statementClosingDate)

        guard let closingYear = closingComponents.year,
              let closingMonth = closingComponents.month,
              let closingDay = closingComponents.day else {
            return nil
        }

        if paymentDueDay > closingDay {
            return creditCardDueDate(year: closingYear, month: closingMonth, paymentDueDay: paymentDueDay)
        }

        guard let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: statementClosingDate) else {
            return nil
        }

        let nextComponents = calendar.dateComponents([.year, .month], from: nextMonthDate)
        guard let nextYear = nextComponents.year,
              let nextMonth = nextComponents.month else {
            return nil
        }

        return creditCardDueDate(year: nextYear, month: nextMonth, paymentDueDay: paymentDueDay)
    }

    private func nextCreditCardDueDate(paymentDueDay: Int, referenceDate: Date) -> Date? {
        guard (1...31).contains(paymentDueDay) else {
            return nil
        }

        let calendar = Calendar.current
        let referenceStart = calendar.startOfDay(for: referenceDate)
        let referenceComponents = calendar.dateComponents([.year, .month], from: referenceStart)

        guard let year = referenceComponents.year,
              let month = referenceComponents.month,
              let thisMonthDueDate = creditCardDueDate(year: year, month: month, paymentDueDay: paymentDueDay) else {
            return nil
        }

        if thisMonthDueDate >= referenceStart {
            return thisMonthDueDate
        }

        guard let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: thisMonthDueDate) else {
            return nil
        }

        let nextComponents = calendar.dateComponents([.year, .month], from: nextMonthDate)
        guard let nextYear = nextComponents.year,
              let nextMonth = nextComponents.month else {
            return nil
        }

        return creditCardDueDate(year: nextYear, month: nextMonth, paymentDueDay: paymentDueDay)
    }

    private func creditCardDueDate(year: Int, month: Int, paymentDueDay: Int) -> Date? {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let firstDay = calendar.date(from: components),
              let dayRange = calendar.range(of: .day, in: .month, for: firstDay) else {
            return nil
        }

        components.day = min(paymentDueDay, dayRange.count)
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    private func runwayHorizonMonths(from startDate: Date, to targetDate: Date) -> Int {
        let calendar = Calendar.current
        let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: startDate)) ?? startDate
        let targetMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: targetDate)) ?? targetDate
        let monthCount = calendar.dateComponents([.month], from: startMonth, to: targetMonth).month ?? 0
        return max(monthCount + 2, 1)
    }

    private func isValidCreditCard(_ card: CreditCard) -> Bool {
        let lastFourDigits = card.lastFourDigits ?? ""

        return !card.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        card.creditLimit >= 0 &&
        card.openingOutstandingBalance >= 0 &&
        (1...31).contains(card.statementClosingDay) &&
        (1...31).contains(card.paymentDueDay) &&
        lastFourDigits.count <= 4 &&
        lastFourDigits.allSatisfy(\.isNumber)
    }

    func budgetCategoryNames(for budget: WalletMonthlyBudget?) -> [String] {
        let activeNames = categories
            .filter { $0.isActive }
            .map { $0.name }

        let savedNames = budget?.items.map { $0.categoryName } ?? []
        let allNames = activeNames + savedNames
        var uniqueNames: [String] = []

        for name in allNames where !uniqueNames.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            uniqueNames.append(name)
        }

        return uniqueNames.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func isActualSpendingType(_ type: FinancialEventType) -> Bool {
        switch type {
        case .expense, .obligation, .expectedExpense, .installment:
            return true

        case .income, .transfer:
            return false
        }
    }

    private func monthRange(year: Int, month: Int) -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let start = calendar.date(from: components),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            return nil
        }

        return (start, end)
    }

    private func recurringOccurrenceEvent(for event: FinancialEvent, year: Int, month: Int) -> FinancialEvent? {
        guard let monthRange = monthRange(year: year, month: month),
              let occurrenceDate = recurringOccurrenceDate(for: event, in: monthRange),
              !event.isRecurringOccurrenceSkipped(on: occurrenceDate) else {
            return nil
        }

        let occurrenceComponents = Calendar.current.dateComponents([.year, .month], from: occurrenceDate)
        guard let occurrenceYear = occurrenceComponents.year,
              let occurrenceMonth = occurrenceComponents.month,
              paidRecurringOccurrence(sourceID: event.id, year: occurrenceYear, month: occurrenceMonth) == nil else {
            return nil
        }

        var occurrence = event
        occurrence.id = UUID()
        occurrence.date = occurrenceDate
        let occurrenceAmount = event.recurringAmount(for: occurrenceDate)
        guard occurrenceAmount > 0 else {
            return nil
        }

        occurrence.amount = occurrenceAmount
        occurrence.status = .unpaid
        occurrence.repeatRule = .none
        occurrence.sourceRecurringEventID = event.id
        occurrence.recurringOccurrenceYear = occurrenceYear
        occurrence.recurringOccurrenceMonth = occurrenceMonth
        return occurrence
    }

    private func recurringOccurrenceDate(for event: FinancialEvent, in monthRange: (start: Date, end: Date)) -> Date? {
        guard event.repeatRule != .none else {
            return nil
        }

        let calendar = Calendar.current
        var currentDate = event.date
        var occurrenceNumber = 1

        if currentDate >= monthRange.start && currentDate < monthRange.end {
            return event.allowsRecurringOccurrence(on: currentDate, occurrenceNumber: occurrenceNumber) ? currentDate : nil
        }

        while currentDate < monthRange.end && occurrenceNumber < 240 {
            guard let nextDate = nextRecurringDate(after: currentDate, rule: event.repeatRule, originalDay: calendar.component(.day, from: event.date)) else {
                return nil
            }

            currentDate = nextDate
            occurrenceNumber += 1

            if currentDate >= monthRange.start && currentDate < monthRange.end {
                return event.allowsRecurringOccurrence(on: currentDate, occurrenceNumber: occurrenceNumber) ? currentDate : nil
            }
        }

        return nil
    }

    private func nextRecurringDate(after date: Date, rule: RepeatRule, originalDay: Int) -> Date? {
        let calendar = Calendar.current
        let monthOffset: Int

        switch rule {
        case .none:
            return nil
        case .monthly:
            monthOffset = 1
        case .quarterly:
            monthOffset = 3
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        }

        guard let roughDate = calendar.date(byAdding: .month, value: monthOffset, to: date) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month], from: roughDate)
        let daysInTargetMonth = calendar.range(of: .day, in: .month, for: roughDate)?.count ?? originalDay
        components.day = min(originalDay, daysInTargetMonth)
        return calendar.date(from: components)
    }

    // MARK: - People / Debts

    var totalOwedToMe: Double {
        activePersonDebts
            .filter { $0.kind == .owedToMe && !$0.isArchived }
            .map { remainingAmount(for: $0) }
            .reduce(0, +)
    }

    var totalIOwe: Double {
        activePersonDebts
            .filter { $0.kind == .iOwe && !$0.isArchived }
            .map { remainingAmount(for: $0) }
            .reduce(0, +)
    }

    var netPeopleDebtPosition: Double {
        totalOwedToMe - totalIOwe
    }

    func entries(for debt: PersonDebt) -> [PersonDebtEntry] {
        activePersonDebtEntries
            .filter { $0.debtID == debt.id }
            .sorted {
                if $0.date == $1.date {
                    return $0.createdAt < $1.createdAt
                }

                return $0.date < $1.date
            }
    }

    func repaidAmount(for debt: PersonDebt) -> Double {
        entries(for: debt)
            .filter { entry in
                entry.entryType == .repaymentReceived ||
                entry.entryType == .repaymentPaid
            }
            .map { $0.amount }
            .reduce(0, +)
    }

    func remainingAmount(for debt: PersonDebt) -> Double {
        max(debt.originalAmount - repaidAmount(for: debt), 0)
    }

    func expectedRepaymentEvents() -> [FinancialEvent] {
        activePersonDebts.compactMap { debt in
            guard debt.kind == .owedToMe,
                  !debt.isArchived,
                  let dueDate = debt.dueDate else {
                return nil
            }

            let remaining = remainingAmount(for: debt)
            guard remaining > 0 else {
                return nil
            }

            return FinancialEvent(
                id: debt.id,
                type: .income,
                status: .expected,
                title: "Expected repayment from \(debt.personName)",
                amount: remaining,
                date: dueDate,
                accountName: nil,
                paymentMethodName: "People/Debts",
                walletEventName: nil,
                categoryName: "Money Lent / Receivables",
                subCategoryName: "Expected Repayment",
                incomeType: .loanOrDebt,
                repeatRule: .none,
                confidence: .medium,
                note: debt.note,
                createdAt: debt.updatedAt
            )
        }
    }

    func repaymentsReceivedByCategory(year: Int, month: Int) -> [String: Double] {
        guard let monthRange = monthRange(year: year, month: month) else {
            return [:]
        }

        let total = activePersonDebtEntries
            .filter { entry in
                entry.entryType == .repaymentReceived &&
                entry.date >= monthRange.start &&
                entry.date < monthRange.end
            }
            .map(\.amount)
            .reduce(0, +)

        return total > 0 ? ["Repayments Received": total] : [:]
    }

    func status(for debt: PersonDebt) -> PersonDebtStatus {
        let repaidAmount = repaidAmount(for: debt)
        let remainingAmount = remainingAmount(for: debt)

        if remainingAmount <= 0 {
            return .settled
        }

        if repaidAmount > 0 {
            return .partiallyPaid
        }

        return .open
    }

    func addPersonDebt(
        kind: PersonDebtKind,
        personName: String,
        amount: Double,
        accountName: String,
        date: Date,
        dueDate: Date?,
        note: String?
    ) -> Bool {
        let cleanName = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAccountName = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty,
              amount > 0,
              accounts.contains(where: { $0.name == cleanAccountName }) else {
            return false
        }

        let entryType: PersonDebtEntryType = kind == .owedToMe ? .initialLending : .initialBorrowing
        let entry = PersonDebtEntry(
            debtID: UUID(),
            entryType: entryType,
            amount: amount,
            accountName: cleanAccountName,
            date: date,
            note: cleanNote?.isEmpty == true ? nil : cleanNote,
            createdAt: Date()
        )

        guard canApplyPersonDebtEntry(entry) else {
            return false
        }

        let debt = PersonDebt(
            id: entry.debtID,
            personName: cleanName,
            kind: kind,
            originalAmount: amount,
            note: cleanNote?.isEmpty == true ? nil : cleanNote,
            createdAt: Date(),
            updatedAt: Date(),
            dueDate: dueDate,
            isArchived: false
        )

        personDebts.append(debt)
        personDebtEntries.append(entry)
        applyPersonDebtEntryImpact(entry, multiplier: 1)
        return true
    }

    func recordDebtRepayment(
        for debt: PersonDebt,
        amount: Double,
        accountName: String,
        date: Date,
        note: String?
    ) -> Bool {
        guard let index = personDebts.firstIndex(where: { $0.id == debt.id }),
              amount > 0,
              amount <= remainingAmount(for: personDebts[index]) else {
            return false
        }

        let cleanAccountName = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entryType: PersonDebtEntryType = personDebts[index].kind == .owedToMe ? .repaymentReceived : .repaymentPaid
        let entry = PersonDebtEntry(
            debtID: personDebts[index].id,
            entryType: entryType,
            amount: amount,
            accountName: cleanAccountName,
            date: date,
            note: cleanNote?.isEmpty == true ? nil : cleanNote,
            createdAt: Date()
        )

        guard canApplyPersonDebtEntry(entry) else {
            return false
        }

        personDebtEntries.append(entry)
        personDebts[index].updatedAt = Date()
        applyPersonDebtEntryImpact(entry, multiplier: 1)
        return true
    }

    func deletePersonDebt(_ debt: PersonDebt) -> Bool {
        guard let index = personDebts.firstIndex(where: { $0.id == debt.id }) else {
            return false
        }

        let linkedEntries = entries(for: personDebts[index])
        for entry in linkedEntries {
            applyPersonDebtEntryImpact(entry, multiplier: -1)
        }

        for entry in linkedEntries {
            markHighRiskRecordDeletedLocally(entity: .personDebtEntry, id: entry.id, deletedAt: Date())
        }
        markHighRiskRecordDeletedLocally(entity: .personDebt, id: personDebts[index].id, deletedAt: Date())
        personDebtEntries.removeAll { $0.debtID == personDebts[index].id }
        personDebts.remove(at: index)
        return true
    }

    private func canApplyPersonDebtEntry(_ entry: PersonDebtEntry) -> Bool {
        guard entry.amount > 0,
              let account = accounts.first(where: { $0.name == entry.accountName }) else {
            return false
        }

        switch entry.entryType {
        case .initialLending, .repaymentPaid:
            return account.balance >= entry.amount

        case .initialBorrowing, .repaymentReceived:
            return true
        }
    }

    private func applyPersonDebtEntryImpact(_ entry: PersonDebtEntry, multiplier: Double) {
        guard let index = accounts.firstIndex(where: { $0.name == entry.accountName }) else {
            return
        }

        switch entry.entryType {
        case .initialLending, .repaymentPaid:
            accounts[index].balance -= entry.amount * multiplier

        case .initialBorrowing, .repaymentReceived:
            accounts[index].balance += entry.amount * multiplier
        }

        accounts[index].updatedAt = Date()
    }

    // MARK: - Backup

    func makeBackupSnapshot() -> WalletDataSnapshot {
        let exportedAt = Date()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let latestTransactionDate = (
            financialEvents.map(\.date) +
            creditCardPurchases.map(\.purchaseDate) +
            creditCardPayments.map(\.paymentDate)
        ).max()
        let backupMetadata = WalletBackupMetadata(
            backupCreatedAt: exportedAt,
            appName: "WalletBoard",
            appVersion: appVersion,
            backupSchemaVersion: WalletDataSnapshot.currentSchemaVersion,
            deviceName: nil,
            totalAccounts: accounts.count,
            totalTransactions: financialEvents.count,
            totalFutureItems: financialEvents.filter { $0.status != .paid && $0.repeatRule == .none }.count,
            totalRecurringItems: financialEvents.filter { $0.repeatRule != .none }.count,
            totalInstallments: installmentPlans.count,
            totalCreditCards: creditCards.count,
            totalCreditCardPurchases: creditCardPurchases.count,
            totalCreditCardPayments: creditCardPayments.count,
            totalPeopleDebts: personDebts.count,
            latestTransactionDate: latestTransactionDate
        )

        return WalletDataSnapshot(
            schemaVersion: WalletDataSnapshot.currentSchemaVersion,
            exportedAt: exportedAt,
            appBuildInfo: appVersion,
            backupMetadata: backupMetadata,
            accounts: accounts,
            categories: categories,
            walletEvents: walletEvents,
            merchantMemories: merchantMemories,
            installmentPlans: installmentPlans,
            financialEvents: financialEvents,
            personDebts: personDebts,
            personDebtEntries: personDebtEntries,
            monthlyBudgets: monthlyBudgets,
            historicalMonthlySummaries: historicalMonthlySummaries,
            creditCards: creditCards,
            creditCardPurchases: creditCardPurchases,
            creditCardPayments: creditCardPayments,
            monthlyLivingBurn: monthlyLivingBurn,
            runwaySafeBalanceTarget: runwaySafeBalanceTarget,
            instaPayFeePercent: instaPayFeePercent,
            instaPayMinimumFee: instaPayMinimumFee,
            instaPayMaximumFee: instaPayMaximumFee,
            displayName: displayName,
            appLanguage: appLanguage,
            forecastHorizonMonths: forecastHorizonMonths,
            hideBalances: hideBalances,
            incomeMode: incomeMode,
            salaryResumeDate: salaryResumeDate
        )
    }

    func encodeBackupSnapshotToJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(makeBackupSnapshot())
    }

    func importBackupSnapshotFromJSON(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let snapshot = try decoder.decode(WalletDataSnapshot.self, from: data)
            try restoreFromBackupSnapshot(snapshot)
        } catch let error as WalletBackupError {
            throw error
        } catch {
            throw WalletBackupError.decodeFailed
        }
    }

    func restoreFromBackupSnapshot(_ snapshot: WalletDataSnapshot) throws {
        try validateBackupSnapshot(snapshot)

        accounts = snapshot.accounts
        categories = snapshot.categories
        walletEvents = snapshot.walletEvents
        merchantMemories = snapshot.merchantMemories
        installmentPlans = snapshot.installmentPlans
        financialEvents = snapshot.financialEvents
        personDebts = snapshot.personDebts
        personDebtEntries = snapshot.personDebtEntries
        monthlyBudgets = snapshot.monthlyBudgets
        historicalMonthlySummaries = snapshot.historicalMonthlySummaries
        creditCards = snapshot.creditCards
        creditCardPurchases = snapshot.creditCardPurchases
        creditCardPayments = snapshot.creditCardPayments
        monthlyLivingBurn = max(snapshot.monthlyLivingBurn, 0)
        runwaySafeBalanceTarget = max(snapshot.runwaySafeBalanceTarget, 0)
        instaPayFeePercent = max(snapshot.instaPayFeePercent, 0)
        instaPayMinimumFee = max(snapshot.instaPayMinimumFee, 0)
        instaPayMaximumFee = max(snapshot.instaPayMaximumFee, instaPayMinimumFee)
        displayName = snapshot.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        appLanguage = snapshot.appLanguage
        forecastHorizonMonths = [6, 12, 18, 24].contains(snapshot.forecastHorizonMonths) ? snapshot.forecastHorizonMonths : 12
        hideBalances = snapshot.hideBalances
        incomeMode = snapshot.incomeMode
        salaryResumeDate = snapshot.salaryResumeDate
        localDataUpdatedAt = snapshot.exportedAt
    }

    func makeBackupValidationReport(for snapshot: WalletDataSnapshot) -> BackupValidationReport {
        var issues: [BackupValidationIssue] = []
        let accountNames = Set(snapshot.accounts.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) })
        let creditCardIDs = Set(snapshot.creditCards.map(\.id))
        let installmentPlanIDs = Set(snapshot.installmentPlans.map(\.id))
        let today = Calendar.current.startOfDay(for: Date())

        appendDuplicateIDIssues(
            ids: snapshot.financialEvents.map(\.id),
            label: "financial event",
            issues: &issues
        )
        appendDuplicateMonthlyBudgetItemIDIssues(
            monthlyBudgets: snapshot.monthlyBudgets,
            issues: &issues
        )

        for event in snapshot.financialEvents {
            if event.amount <= 0 {
                issues.append(
                    BackupValidationIssue(
                        severity: .warning,
                        title: "Invalid financial event amount",
                        detail: "\(event.title) has an amount that should not be zero or negative.",
                        recordID: event.id
                    )
                )
            }

            if event.status == .paid && event.type != .transfer {
                let accountName = event.accountName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if accountName.isEmpty || !accountNames.contains(accountName) {
                    issues.append(
                        BackupValidationIssue(
                            severity: .warning,
                            title: "Paid event missing account",
                            detail: "\(event.title) is marked paid but does not reference a restored account.",
                            recordID: event.id
                        )
                    )
                }
            }

            if event.type == .transfer {
                let source = event.accountName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let destination = event.destinationAccountName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if source.isEmpty || !accountNames.contains(source) {
                    issues.append(
                        BackupValidationIssue(
                            severity: .warning,
                            title: "Transfer missing source account",
                            detail: "\(event.title) references a source account that is not in the backup.",
                            recordID: event.id
                        )
                    )
                }

                if destination.isEmpty || !accountNames.contains(destination) {
                    issues.append(
                        BackupValidationIssue(
                            severity: .warning,
                            title: "Transfer missing destination account",
                            detail: "\(event.title) references a destination account that is not in the backup.",
                            recordID: event.id
                        )
                    )
                }
            }

            if event.status == .paid && Calendar.current.startOfDay(for: event.date) > today {
                issues.append(
                    BackupValidationIssue(
                        severity: .info,
                        title: "Future dated paid event",
                        detail: "\(event.title) is marked paid with a future date. Review after restore if this was intentional.",
                        recordID: event.id
                    )
                )
            }

            if let planID = event.sourceInstallmentPlanID,
               !installmentPlanIDs.contains(planID) {
                issues.append(
                    BackupValidationIssue(
                        severity: .warning,
                        title: "Installment event missing plan",
                        detail: "\(event.title) references an installment plan that is not in the backup.",
                        recordID: event.id
                    )
                )
            }
        }

        for purchase in snapshot.creditCardPurchases {
            if purchase.amount <= 0 {
                issues.append(
                    BackupValidationIssue(
                        severity: .warning,
                        title: "Invalid credit card purchase amount",
                        detail: "\(purchase.title) has an amount that should not be zero or negative.",
                        recordID: purchase.id
                    )
                )
            }

            if !creditCardIDs.contains(purchase.cardID) {
                issues.append(
                    BackupValidationIssue(
                        severity: .warning,
                        title: "Credit card purchase missing card",
                        detail: "\(purchase.title) references a credit card that is not in the backup.",
                        recordID: purchase.id
                    )
                )
            }
        }

        for payment in snapshot.creditCardPayments {
            if payment.amount <= 0 {
                issues.append(
                    BackupValidationIssue(
                        severity: .warning,
                        title: "Invalid credit card payment amount",
                        detail: "A credit card payment has an amount that should not be zero or negative.",
                        recordID: payment.id
                    )
                )
            }

            if !creditCardIDs.contains(payment.cardID) {
                issues.append(
                    BackupValidationIssue(
                        severity: .warning,
                        title: "Credit card payment missing card",
                        detail: "A credit card payment references a credit card that is not in the backup.",
                        recordID: payment.id
                    )
                )
            }

            let accountName = payment.fromAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
            if accountName.isEmpty || !accountNames.contains(accountName) {
                issues.append(
                    BackupValidationIssue(
                        severity: .warning,
                        title: "Credit card payment missing account",
                        detail: "A credit card payment references a source account that is not in the backup.",
                        recordID: payment.id
                    )
                )
            }
        }

        for plan in snapshot.installmentPlans {
            if plan.totalAmount <= 0 || plan.installmentCount <= 0 {
                issues.append(
                    BackupValidationIssue(
                        severity: .warning,
                        title: "Invalid installment plan values",
                        detail: "\(plan.purchaseName) has an impossible total amount or installment count.",
                        recordID: plan.id
                    )
                )
            }

            if let accountName = plan.accountName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !accountName.isEmpty,
               !accountNames.contains(accountName) {
                issues.append(
                    BackupValidationIssue(
                        severity: .warning,
                        title: "Installment plan missing account",
                        detail: "\(plan.purchaseName) references an account that is not in the backup.",
                        recordID: plan.id
                    )
                )
            }

            if let linkedCreditCardID = plan.linkedCreditCardID,
               !creditCardIDs.contains(linkedCreditCardID) {
                issues.append(
                    BackupValidationIssue(
                        severity: .warning,
                        title: "Installment plan missing linked card",
                        detail: "\(plan.purchaseName) is linked to a credit card that is not in the backup.",
                        recordID: plan.id
                    )
                )
            }

            let paidCount = snapshot.financialEvents.filter { event in
                event.sourceInstallmentPlanID == plan.id &&
                event.type == .installment &&
                event.status == .paid
            }.count

            if paidCount > plan.installmentCount {
                issues.append(
                    BackupValidationIssue(
                        severity: .warning,
                        title: "Installment paid count exceeds total",
                        detail: "\(plan.purchaseName) has more paid installment events than its installment count.",
                        recordID: plan.id
                    )
                )
            }
        }

        for card in snapshot.creditCards {
            if let accountName = card.defaultPaymentAccountName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !accountName.isEmpty,
               !accountNames.contains(accountName) {
                issues.append(
                    BackupValidationIssue(
                        severity: .warning,
                        title: "Credit card default payment account missing",
                        detail: "\(card.name) references a default payment account that is not in the backup.",
                        recordID: card.id
                    )
                )
            }
        }

        for entry in snapshot.personDebtEntries {
            if entry.amount <= 0 {
                issues.append(
                    BackupValidationIssue(
                        severity: .warning,
                        title: "Invalid debt entry amount",
                        detail: "A people/debts entry has an amount that should not be zero or negative.",
                        recordID: entry.id
                    )
                )
            }

            let accountName = entry.accountName.trimmingCharacters(in: .whitespacesAndNewlines)
            if accountName.isEmpty || !accountNames.contains(accountName) {
                issues.append(
                    BackupValidationIssue(
                        severity: .warning,
                        title: "Debt entry missing account",
                        detail: "A people/debts entry references an account that is not in the backup.",
                        recordID: entry.id
                    )
                )
            }
        }

        return BackupValidationReport(issues: issues)
    }

    private func appendDuplicateIDIssues(
        ids: [UUID],
        label: String,
        issues: inout [BackupValidationIssue]
    ) {
        var seen: Set<UUID> = []
        var reported: Set<UUID> = []

        for id in ids {
            if seen.contains(id), !reported.contains(id) {
                issues.append(
                    BackupValidationIssue(
                        severity: .warning,
                        title: "Duplicate \(label) ID",
                        detail: "The backup contains more than one \(label) with the same ID.",
                        recordID: id
                    )
                )
                reported.insert(id)
            }

            seen.insert(id)
        }
    }

    private func appendDuplicateMonthlyBudgetItemIDIssues(
        monthlyBudgets: [WalletMonthlyBudget],
        issues: inout [BackupValidationIssue]
    ) {
        var firstBudgetContextByID: [UUID: String] = [:]
        var reported: Set<UUID> = []

        for budget in monthlyBudgets {
            let budgetContext = monthlyBudgetValidationContext(for: budget)

            for item in budget.items {
                if let firstBudgetContext = firstBudgetContextByID[item.id],
                   !reported.contains(item.id) {
                    issues.append(
                        BackupValidationIssue(
                            severity: .warning,
                            title: "Duplicate monthly budget item ID",
                            detail: "The backup contains more than one monthly budget item with ID \(item.id). Duplicate found in \(budgetContext); first seen in \(firstBudgetContext).",
                            recordID: item.id
                        )
                    )
                    reported.insert(item.id)
                } else if firstBudgetContextByID[item.id] == nil {
                    firstBudgetContextByID[item.id] = budgetContext
                }
            }
        }
    }

    private func monthlyBudgetValidationContext(for budget: WalletMonthlyBudget) -> String {
        "monthly budget \(budget.year)-\(String(format: "%02d", budget.month))"
    }

    private func validateBackupSnapshot(_ snapshot: WalletDataSnapshot) throws {
        guard snapshot.schemaVersion > 0,
              snapshot.schemaVersion <= WalletDataSnapshot.currentSchemaVersion else {
            throw WalletBackupError.unsupportedSchemaVersion(snapshot.schemaVersion)
        }

        try validateUniqueIDs(snapshot.accounts.map { $0.id }, label: "accounts")
        try validateUniqueIDs(snapshot.categories.map { $0.id }, label: "categories")
        try validateUniqueIDs(snapshot.walletEvents.map { $0.id }, label: "quick events")
        try validateUniqueIDs(snapshot.merchantMemories.map { $0.id }, label: "merchant memories")
        try validateUniqueIDs(snapshot.installmentPlans.map { $0.id }, label: "installment plans")
        try validateUniqueIDs(snapshot.financialEvents.map { $0.id }, label: "financial events")
        try validateUniqueIDs(snapshot.personDebts.map { $0.id }, label: "people debts")
        try validateUniqueIDs(snapshot.personDebtEntries.map { $0.id }, label: "people debt entries")
        try validateUniqueIDs(snapshot.monthlyBudgets.map { $0.id }, label: "monthly budgets")
        try validateUniqueMonthlyBudgetItemIDs(snapshot.monthlyBudgets)
        try validateUniqueIDs(snapshot.historicalMonthlySummaries.map { $0.id }, label: "historical summaries")
        try validateUniqueIDs(snapshot.creditCards.map { $0.id }, label: "credit cards")
        try validateUniqueIDs(snapshot.creditCardPurchases.map { $0.id }, label: "credit card purchases")
        try validateUniqueIDs(snapshot.creditCardPayments.map { $0.id }, label: "credit card payments")

        let accountNames = snapshot.accounts.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !accountNames.contains(where: { $0.isEmpty }) else {
            throw WalletBackupError.invalidData("Backup contains an account without a name.")
        }

        guard Set(accountNames.map { $0.lowercased() }).count == accountNames.count else {
            throw WalletBackupError.invalidData("Backup contains duplicate account names.")
        }

        let categoryNames = snapshot.categories.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !categoryNames.contains(where: { $0.isEmpty }) else {
            throw WalletBackupError.invalidData("Backup contains a category without a name.")
        }

        guard Set(categoryNames.map { $0.lowercased() }).count == categoryNames.count else {
            throw WalletBackupError.invalidData("Backup contains duplicate category names.")
        }

        let validCategories = Set(categoryNames)
        let validSubcategoriesByCategory = Dictionary(uniqueKeysWithValues: snapshot.categories.map { category in
            (category.name, Set(category.subcategories))
        })

        for merchant in snapshot.merchantMemories {
            guard !merchant.merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  validCategories.contains(merchant.defaultCategoryName),
                  validSubcategoriesByCategory[merchant.defaultCategoryName]?.contains(merchant.defaultSubCategoryName) == true else {
                throw WalletBackupError.invalidData("Backup contains invalid merchant memory data.")
            }
        }

        for event in snapshot.financialEvents {
            guard event.amount > 0 else {
                throw WalletBackupError.invalidData("Backup contains a financial event with an invalid amount.")
            }

            if event.type == .transfer {
                guard let source = event.accountName?.trimmingCharacters(in: .whitespacesAndNewlines),
                      let destination = event.destinationAccountName?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !source.isEmpty,
                      !destination.isEmpty,
                      source != destination else {
                    throw WalletBackupError.invalidData("Backup contains an invalid transfer event.")
                }
            }
        }

        for budget in snapshot.monthlyBudgets {
            guard budget.year >= 1900,
                  budget.month >= 1,
                  budget.month <= 12 else {
                throw WalletBackupError.invalidData("Backup contains a monthly budget with an invalid month or year.")
            }

            guard budget.items.allSatisfy({ !$0.categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.plannedAmount >= 0 }) else {
                throw WalletBackupError.invalidData("Backup contains invalid monthly budget items.")
            }
        }

        for entry in snapshot.historicalMonthlySummaries {
            guard entry.year >= 1900,
                  entry.month >= 1,
                  entry.month <= 12,
                  entry.amount > 0,
                  validCategories.contains(entry.categoryName),
                  validSubcategoriesByCategory[entry.categoryName]?.contains(entry.subCategoryName) == true else {
                throw WalletBackupError.invalidData("Backup contains invalid historical summary data.")
            }
        }

        let creditCardIDs = Set(snapshot.creditCards.map { $0.id })

        for card in snapshot.creditCards {
            guard isValidCreditCard(card) else {
                throw WalletBackupError.invalidData("Backup contains invalid credit card data.")
            }
        }

        for purchase in snapshot.creditCardPurchases {
            guard creditCardIDs.contains(purchase.cardID),
                  purchase.amount > 0,
                  !purchase.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  validCategories.contains(purchase.categoryName),
                  validSubcategoriesByCategory[purchase.categoryName]?.contains(purchase.subCategoryName) == true else {
                throw WalletBackupError.invalidData("Backup contains invalid credit card purchase data.")
            }
        }

        for payment in snapshot.creditCardPayments {
            guard creditCardIDs.contains(payment.cardID),
                  payment.amount > 0,
                  !payment.fromAccountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WalletBackupError.invalidData("Backup contains invalid credit card payment data.")
            }
        }

        let debtIDs = Set(snapshot.personDebts.map { $0.id })
        for debt in snapshot.personDebts {
            guard !debt.personName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  debt.originalAmount > 0 else {
                throw WalletBackupError.invalidData("Backup contains invalid people debt data.")
            }
        }

        for entry in snapshot.personDebtEntries {
            guard debtIDs.contains(entry.debtID),
                  entry.amount > 0,
                  !entry.accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WalletBackupError.invalidData("Backup contains invalid people debt entry data.")
            }
        }

        guard snapshot.monthlyLivingBurn >= 0,
              snapshot.runwaySafeBalanceTarget >= 0,
              snapshot.instaPayFeePercent >= 0,
              snapshot.instaPayMinimumFee >= 0,
              snapshot.instaPayMaximumFee >= snapshot.instaPayMinimumFee else {
            throw WalletBackupError.invalidData("Backup contains invalid settings.")
        }
    }

    private func validateUniqueIDs(_ ids: [UUID], label: String) throws {
        guard Set(ids).count == ids.count else {
            throw WalletBackupError.invalidData("Backup contains duplicate \(label).")
        }
    }

    private func validateUniqueMonthlyBudgetItemIDs(_ monthlyBudgets: [WalletMonthlyBudget]) throws {
        var firstBudgetContextByID: [UUID: String] = [:]

        for budget in monthlyBudgets {
            let budgetContext = monthlyBudgetValidationContext(for: budget)

            for item in budget.items {
                if let firstBudgetContext = firstBudgetContextByID[item.id] {
                    throw WalletBackupError.invalidData(
                        "Backup contains duplicate monthly budget item ID \(item.id) in \(budgetContext); first seen in \(firstBudgetContext)."
                    )
                }

                firstBudgetContextByID[item.id] = budgetContext
            }
        }
    }

    // MARK: - iCloud Sync

    func enableICloudSync(_ enabled: Bool) {
        iCloudSyncEnabled = enabled
    }

    @MainActor
    func checkICloudAvailability() async {
        iCloudAvailability = await iCloudSyncService.checkAvailability()
        if iCloudAvailability == .available {
            lastICloudSyncError = nil
        }
    }

    @MainActor
    func fetchICloudStatus() async {
        await checkICloudAvailability()
        guard iCloudAvailability == .available else {
            iCloudRemoteMetadata = nil
            iCloudConflictState = .none
            if iCloudAvailability == .capabilityNotEnabled {
                lastICloudSyncError = "iCloud capability is not enabled for this app target."
            }
            return
        }

        do {
            let metadata = try await iCloudSyncService.fetchRemoteMetadata()
            iCloudRemoteMetadata = metadata
            lastKnownRemoteUpdateAt = metadata?.remoteUpdatedAt
            iCloudConflictState = conflictState(remoteUpdatedAt: metadata?.remoteUpdatedAt)
            lastICloudSyncError = nil
        } catch {
            iCloudRemoteMetadata = nil
            iCloudConflictState = .none
            lastICloudSyncError = error.localizedDescription
        }
    }

    @MainActor
    func uploadBackupToICloud(force: Bool = false) async -> Bool {
        await fetchICloudStatus()
        guard iCloudAvailability == .available else {
            return false
        }

        if iCloudConflictState == .conflict && !force {
            lastICloudSyncError = "Conflict detected. Choose how to resolve it before uploading."
            return false
        }

        do {
            var snapshot = makeBackupSnapshot()
            snapshot.exportedAt = Date()
            let metadata = try await iCloudSyncService.upload(snapshot: snapshot)
            lastICloudUploadAt = Date()
            lastKnownRemoteUpdateAt = metadata.remoteUpdatedAt ?? snapshot.exportedAt
            iCloudRemoteMetadata = metadata
            iCloudConflictState = .none
            lastICloudSyncError = nil
            return true
        } catch {
            lastICloudSyncError = error.localizedDescription
            return false
        }
    }

    @MainActor
    func downloadBackupFromICloud(force: Bool = false) async -> Bool {
        await fetchICloudStatus()
        guard iCloudAvailability == .available else {
            return false
        }

        if iCloudConflictState == .conflict && !force {
            lastICloudSyncError = "Conflict detected. Choose how to resolve it before downloading."
            return false
        }

        do {
            let snapshot = try await iCloudSyncService.downloadSnapshot()
            _ = try createLocalSafetyBackupBeforeICloudReplace()
            try restoreFromBackupSnapshot(snapshot)
            lastICloudDownloadAt = Date()
            lastKnownRemoteUpdateAt = snapshot.exportedAt
            iCloudConflictState = .none
            lastICloudSyncError = nil
            return true
        } catch {
            lastICloudSyncError = error.localizedDescription
            return false
        }
    }

    func downloadICloudSnapshotForReview() async throws -> WalletDataSnapshot {
        await fetchICloudStatus()
        guard iCloudAvailability == .available else {
            throw WalletICloudSyncError.notAvailable("iCloud is not available. Check iCloud account and network.")
        }

        let snapshot = try await iCloudSyncService.downloadSnapshot()
        try validateBackupSnapshot(snapshot)
        return snapshot
    }

    func createLocalSafetyBackupBeforeICloudReplace() throws -> URL {
        let data = try encodeBackupSnapshotToJSON()
        let fileManager = FileManager.default
        guard let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw WalletBackupError.invalidData("Could not find Application Support folder for safety backup.")
        }

        let folderURL = applicationSupportURL.appendingPathComponent("ICloudSafetyBackups", isDirectory: true)
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let fileName = "WalletSafetyBackup-before-iCloud-\(formatter.string(from: Date())).json"
        let fileURL = folderURL.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func conflictState(remoteUpdatedAt: Date?) -> WalletICloudConflictState {
        guard let remoteUpdatedAt else {
            return localDataUpdatedAt > (lastICloudUploadAt ?? .distantPast) ? .localNewer : .none
        }

        let lastSyncDate = max(lastICloudUploadAt ?? .distantPast, lastICloudDownloadAt ?? .distantPast)
        let localChangedSinceSync = localDataUpdatedAt > lastSyncDate.addingTimeInterval(1)
        let remoteChangedSinceSync = remoteUpdatedAt > lastSyncDate.addingTimeInterval(1)

        if localChangedSinceSync && remoteChangedSinceSync {
            return .conflict
        }

        if remoteUpdatedAt > localDataUpdatedAt.addingTimeInterval(1) {
            return .remoteNewer
        }

        if localDataUpdatedAt > remoteUpdatedAt.addingTimeInterval(1) {
            return .localNewer
        }

        return .none
    }

    // MARK: - Financial Event Management

    func addFinancialEvent(_ event: FinancialEvent) {
        guard canApplyFinancialEvent(event) else {
            return
        }

        financialEvents.append(event)
        applyAccountImpactIfNeeded(event)
    }

    func updateFinancialEvent(_ updatedEvent: FinancialEvent) {
        guard let originalEvent = financialEvents.first(where: { $0.id == updatedEvent.id }) else {
            return
        }

        updateFinancialEvent(originalEvent: originalEvent, updatedEvent: updatedEvent)
    }

    func updateFinancialEvent(originalEvent: FinancialEvent, updatedEvent: FinancialEvent) {
        guard let index = financialEvents.firstIndex(where: { $0.id == originalEvent.id }) else {
            return
        }

        guard canApplyFinancialEvent(updatedEvent) else {
            return
        }

        applyAccountImpact(financialEvents[index], multiplier: -1, markAccountsUpdatedForSync: true)
        financialEvents[index] = updatedEvent
        applyAccountImpactIfNeeded(updatedEvent)
    }

    func deleteFinancialEvent(_ event: FinancialEvent) {
        guard let index = financialEvents.firstIndex(where: { $0.id == event.id }) else {
            return
        }

        markFinancialEventDeletedLocally(id: financialEvents[index].id, deletedAt: Date())
        reverseAccountImpactIfNeeded(financialEvents[index])
        financialEvents.remove(at: index)
    }

    func possibleDuplicateTransaction(for request: TransactionDuplicateCheckRequest) -> TransactionDuplicateCandidate? {
        guard request.amount > 0,
              !normalizedDuplicateText(request.title).isEmpty,
              !isStandaloneInstaPayFee(
                title: request.title,
                categoryName: request.categoryName,
                subCategoryName: request.subCategoryName
              ) else {
            return nil
        }

        if let cardID = request.cardID {
            return duplicateCreditCardPurchase(for: request, cardID: cardID)
        }

        return duplicateFinancialEvent(for: request)
    }

    private func duplicateFinancialEvent(for request: TransactionDuplicateCheckRequest) -> TransactionDuplicateCandidate? {
        let cleanAccountName = request.accountName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleanPaymentMethodName = request.paymentMethodName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleanImportNote = request.rawImportNote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return financialEvents
            .filter { candidate in
                candidate.status == .paid &&
                candidate.type == request.eventType &&
                duplicateAmountMatches(candidate.amount, request.amount) &&
                duplicateDateMatches(candidate.date, request.date) &&
                !isStandaloneInstaPayFee(
                    title: candidate.title,
                    categoryName: candidate.categoryName,
                    subCategoryName: candidate.subCategoryName
                )
            }
            .first { candidate in
                if importEvidenceLooksDuplicate(
                    request: request,
                    candidateTitle: candidate.title,
                    candidateNote: candidate.note,
                    candidateAccountName: candidate.accountName,
                    candidatePaymentMethodName: candidate.paymentMethodName,
                    rawImportNote: cleanImportNote
                ) {
                    return true
                }

                guard duplicateTitleMatches(candidate.title, request.title) else {
                    return false
                }

                if !cleanAccountName.isEmpty,
                   candidate.accountName?.caseInsensitiveCompare(cleanAccountName) != .orderedSame {
                    return false
                }

                if !cleanPaymentMethodName.isEmpty,
                   candidate.paymentMethodName?.caseInsensitiveCompare(cleanPaymentMethodName) != .orderedSame {
                    return false
                }

                return true
            }
            .map { candidate in
                TransactionDuplicateCandidate(
                    id: "financialEvent-\(candidate.id.uuidString)",
                    sourceKind: .financialEvent,
                    title: candidate.title,
                    amount: candidate.amount,
                    date: candidate.date,
                    accountOrCardName: candidate.accountName ?? "No account",
                    paymentMethodName: candidate.paymentMethodName,
                    categoryName: candidate.categoryName,
                    subCategoryName: candidate.subCategoryName
                )
            }
    }

    private func duplicateCreditCardPurchase(
        for request: TransactionDuplicateCheckRequest,
        cardID: UUID
    ) -> TransactionDuplicateCandidate? {
        creditCardPurchases
            .first { candidate in
                candidate.cardID == cardID &&
                duplicateAmountMatches(candidate.amount, request.amount) &&
                duplicateDateMatches(candidate.purchaseDate, request.date) &&
                (
                    duplicateTitleMatches(candidate.title, request.title) ||
                    importEvidenceLooksDuplicate(
                        request: request,
                        candidateTitle: candidate.title,
                        candidateNote: candidate.note,
                        candidateAccountName: request.cardName,
                        candidatePaymentMethodName: "Credit Card",
                        rawImportNote: request.rawImportNote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    )
                )
            }
            .map { candidate in
                let cardName = creditCards.first { $0.id == candidate.cardID }?.name ?? request.cardName ?? "Credit Card"
                return TransactionDuplicateCandidate(
                    id: "creditCardPurchase-\(candidate.id.uuidString)",
                    sourceKind: .creditCardPurchase,
                    title: candidate.title,
                    amount: candidate.amount,
                    date: candidate.purchaseDate,
                    accountOrCardName: cardName,
                    paymentMethodName: "Credit Card",
                    categoryName: candidate.categoryName,
                    subCategoryName: candidate.subCategoryName
                )
            }
    }

    private func importEvidenceLooksDuplicate(
        request: TransactionDuplicateCheckRequest,
        candidateTitle: String,
        candidateNote: String?,
        candidateAccountName: String?,
        candidatePaymentMethodName: String?,
        rawImportNote: String
    ) -> Bool {
        guard request.importIdentity?.isEmpty == false else {
            return false
        }

        let cleanAccountName = request.accountName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cleanAccountName.isEmpty,
           candidateAccountName?.caseInsensitiveCompare(cleanAccountName) != .orderedSame {
            return false
        }

        let cleanPaymentMethodName = request.paymentMethodName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cleanPaymentMethodName.isEmpty,
           candidatePaymentMethodName?.caseInsensitiveCompare(cleanPaymentMethodName) != .orderedSame {
            return false
        }

        if duplicateTitleMatches(candidateTitle, request.title) {
            return true
        }

        guard !rawImportNote.isEmpty,
              let candidateNote,
              !candidateNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        let normalizedCandidateNote = normalizedDuplicateText(candidateNote)
        let normalizedRawImportNote = normalizedDuplicateText(rawImportNote)
        if normalizedCandidateNote.contains(normalizedRawImportNote) ||
            normalizedRawImportNote.contains(normalizedCandidateNote) {
            return true
        }

        return duplicateImportTokenOverlap(normalizedCandidateNote, normalizedRawImportNote) >= 3
    }

    private func duplicateAmountMatches(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.005
    }

    private func duplicateDateMatches(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.isDate(lhs, inSameDayAs: rhs) ||
        abs(lhs.timeIntervalSince(rhs)) <= 15 * 60
    }

    private func duplicateTitleMatches(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalizedDuplicateText(lhs)
        let right = normalizedDuplicateText(rhs)
        guard left.count >= 4,
              right.count >= 4 else {
            return left == right && !left.isEmpty
        }

        return left == right || left.contains(right) || right.contains(left)
    }

    private func duplicateImportTokenOverlap(_ lhs: String, _ rhs: String) -> Int {
        let separators = CharacterSet.letters.union(.decimalDigits).inverted
        let leftTokens = Set(
            lhs.components(separatedBy: separators)
                .filter { $0.count >= 4 && !duplicateGenericTokens.contains($0) }
        )
        let rightTokens = Set(
            rhs.components(separatedBy: separators)
                .filter { $0.count >= 4 && !duplicateGenericTokens.contains($0) }
        )

        return leftTokens.intersection(rightTokens).count
    }

    private func isStandaloneInstaPayFee(
        title: String,
        categoryName: String?,
        subCategoryName: String?
    ) -> Bool {
        title.caseInsensitiveCompare("InstaPay Fee") == .orderedSame ||
        subCategoryName?.caseInsensitiveCompare("InstaPay Fee") == .orderedSame ||
        (categoryName?.caseInsensitiveCompare("Banking & Fees") == .orderedSame &&
         title.localizedCaseInsensitiveContains("fee"))
    }

    private func normalizedDuplicateText(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var duplicateGenericTokens: Set<String> {
        [
            "account",
            "amount",
            "bank",
            "card",
            "credit",
            "debit",
            "detected",
            "egp",
            "ending",
            "from",
            "payment",
            "source",
            "transaction"
        ]
    }

    // MARK: - Add Data

    func addExpense(
        title: String,
        amount: Double,
        date: Date,
        accountName: String,
        walletEvent: WalletEvent?,
        note: String? = nil
    ) {
        addManualExpense(
            title: title,
            amount: amount,
            date: date,
            accountName: accountName,
            paymentMethodName: "Direct",
            walletEventName: walletEvent?.name,
            categoryName: walletEvent?.categoryName,
            subCategoryName: walletEvent?.subCategoryName,
            note: note
        )
    }

    func addManualExpense(
        title: String,
        amount: Double,
        date: Date,
        accountName: String,
        paymentMethodName: String,
        walletEventName: String? = nil,
        categoryName: String?,
        subCategoryName: String?,
        note: String? = nil
    ) {
        let event = FinancialEvent(
            type: .expense,
            status: .paid,
            title: title,
            amount: amount,
            date: date,
            accountName: accountName,
            paymentMethodName: paymentMethodName,
            walletEventName: walletEventName,
            categoryName: categoryName,
            subCategoryName: subCategoryName,
            note: note,
            createdAt: Date()
        )

        addFinancialEvent(event)
    }

    func addInstaPayExpense(
        title: String,
        amount: Double,
        date: Date,
        sourceAccountName: String,
        walletEventName: String? = nil,
        categoryName: String?,
        subCategoryName: String?,
        note: String? = nil
    ) {
        ensureBankingFeesCategory()

        addManualExpense(
            title: title,
            amount: amount,
            date: date,
            accountName: sourceAccountName,
            paymentMethodName: "InstaPay",
            walletEventName: walletEventName,
            categoryName: categoryName,
            subCategoryName: subCategoryName,
            note: note
        )

        let fee = calculateInstaPayFee(for: amount)
        guard fee > 0 else {
            return
        }

        addManualExpense(
            title: "InstaPay Fee",
            amount: fee,
            date: date,
            accountName: sourceAccountName,
            paymentMethodName: "InstaPay",
            walletEventName: nil,
            categoryName: "Banking & Fees",
            subCategoryName: "InstaPay Fee",
            note: "Fee for \(title)"
        )
    }

    @discardableResult
    func addBankingFeeExpense(
        title: String,
        amount: Double,
        date: Date,
        accountName: String,
        paymentMethodName: String,
        note: String? = nil
    ) -> Bool {
        guard amount > 0,
              accounts.contains(where: { $0.name == accountName }) else {
            return false
        }

        ensureBankingFeesCategory()

        let feeEvent = FinancialEvent(
            type: .expense,
            status: .paid,
            title: title,
            amount: amount,
            date: date,
            accountName: accountName,
            paymentMethodName: paymentMethodName,
            walletEventName: nil,
            categoryName: "Banking & Fees",
            subCategoryName: "InstaPay Fee",
            confidence: .high,
            note: note,
            createdAt: Date()
        )

        addFinancialEvent(feeEvent)
        return financialEvents.contains { $0.id == feeEvent.id && $0.status == .paid }
    }

    func addTransfer(
        amount: Double,
        date: Date,
        fromAccountName: String,
        toAccountName: String,
        note: String? = nil,
        atmFeeAmount: Double = 0,
        atmFeeTitle: String = "ATM Withdrawal Fee"
    ) {
        let cleanFromAccountName = fromAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanToAccountName = toAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFeeTitle = atmFeeTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard amount > 0,
              !cleanFromAccountName.isEmpty,
              !cleanToAccountName.isEmpty,
              cleanFromAccountName != cleanToAccountName,
              accounts.contains(where: { $0.name == cleanFromAccountName }),
              accounts.contains(where: { $0.name == cleanToAccountName }) else {
            return
        }

        let transferEvent = FinancialEvent(
            type: .transfer,
            status: .paid,
            title: "Transfer",
            amount: amount,
            date: date,
            accountName: cleanFromAccountName,
            destinationAccountName: cleanToAccountName,
            paymentMethodName: "Transfer",
            note: note,
            createdAt: Date()
        )

        addFinancialEvent(transferEvent)

        guard atmFeeAmount > 0 else {
            return
        }

        ensureATMFeeCategory()

        addManualExpense(
            title: cleanFeeTitle.isEmpty ? "ATM Withdrawal Fee" : cleanFeeTitle,
            amount: atmFeeAmount,
            date: date,
            accountName: cleanFromAccountName,
            paymentMethodName: "ATM Fee",
            walletEventName: nil,
            categoryName: "Banking & Fees",
            subCategoryName: "ATM Withdrawal Fee",
            note: "Fee for transfer from \(cleanFromAccountName) to \(cleanToAccountName)"
        )
    }

    func addQuickEvent(
        name: String,
        categoryName: String,
        subCategoryName: String,
        defaultAccountName: String?,
        isFavorite: Bool
    ) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            return
        }

        if walletEvents.contains(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) {
            return
        }

        let event = WalletEvent(
            name: cleanName,
            categoryName: categoryName,
            subCategoryName: subCategoryName,
            defaultAccountName: defaultAccountName,
            isFavorite: isFavorite
        )

        walletEvents.append(event)
    }

    func addMerchantMemory(
        merchantName: String,
        aliases: [String],
        defaultCategoryName: String,
        defaultSubCategoryName: String,
        defaultAccountName: String?,
        defaultType: FinancialEventType
    ) {
        let cleanName = merchantName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty,
              categories.contains(where: { $0.name == defaultCategoryName }),
              activeSubcategories(for: defaultCategoryName).contains(defaultSubCategoryName) else {
            return
        }

        merchantMemories.append(
            MerchantMemory(
                merchantName: cleanName,
                aliases: cleanTextList(aliases),
                defaultCategoryName: defaultCategoryName,
                defaultSubCategoryName: defaultSubCategoryName,
                defaultAccountName: defaultAccountName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? defaultAccountName : nil,
                defaultType: defaultType,
                updatedAt: Date()
            )
        )
    }

    func updateMerchantMemory(_ memory: MerchantMemory) {
        guard let index = merchantMemories.firstIndex(where: { $0.id == memory.id }) else {
            return
        }

        var updatedMemory = memory
        updatedMemory.merchantName = memory.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedMemory.aliases = cleanTextList(memory.aliases)
        updatedMemory.updatedAt = Date()

        guard !updatedMemory.merchantName.isEmpty,
              categories.contains(where: { $0.name == updatedMemory.defaultCategoryName }),
              activeSubcategories(for: updatedMemory.defaultCategoryName).contains(updatedMemory.defaultSubCategoryName) else {
            return
        }

        merchantMemories[index] = updatedMemory
    }

    func deleteMerchantMemory(_ memory: MerchantMemory) {
        markSyncRecordDeletedLocally(entity: .merchantMemory, id: memory.id)
        merchantMemories.removeAll { $0.id == memory.id }
    }

    private func cleanTextList(_ values: [String]) -> [String] {
        var cleanedValues: [String] = []

        for value in values {
            let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleanValue.isEmpty &&
                !cleanedValues.contains(where: { $0.caseInsensitiveCompare(cleanValue) == .orderedSame }) {
                cleanedValues.append(cleanValue)
            }
        }

        return cleanedValues
    }

    private func ensureBankingFeesCategory() {
        if let index = categories.firstIndex(where: { $0.name == "Banking & Fees" }) {
            if !categories[index].subcategories.contains("InstaPay Fee") {
                categories[index].subcategories.append("InstaPay Fee")
            }
            return
        }

        categories.append(
            Category(
                name: "Banking & Fees",
                subcategories: ["InstaPay Fee"]
            )
        )
    }

    private func ensureATMFeeCategory() {
        if let index = categories.firstIndex(where: { $0.name == "Banking & Fees" }) {
            if !categories[index].subcategories.contains("ATM Withdrawal Fee") {
                categories[index].subcategories.append("ATM Withdrawal Fee")
            }
            categories[index].inactiveSubcategoryNames.removeAll {
                $0.caseInsensitiveCompare("ATM Withdrawal Fee") == .orderedSame
            }
            categories[index].isActive = true
            return
        }

        categories.append(
            Category(
                name: "Banking & Fees",
                subcategories: ["ATM Withdrawal Fee"]
            )
        )
    }

    func addIncome(
        title: String,
        amount: Double,
        date: Date,
        accountName: String,
        incomeType: IncomeType = .oneTimeCashInflow,
        reimbursementCategoryName: String? = nil,
        note: String? = nil
    ) {
        let event = FinancialEvent(
            type: .income,
            status: .paid,
            title: title,
            amount: amount,
            date: date,
            accountName: accountName,
            incomeType: incomeType,
            reimbursementCategoryName: incomeType == .reimbursement ? reimbursementCategoryName : nil,
            note: note,
            createdAt: Date()
        )

        addFinancialEvent(event)
    }

    func reimbursementIncomeByCategory(year: Int, month: Int) -> [String: Double] {
        guard let monthRange = monthRange(year: year, month: month) else {
            return [:]
        }

        let reimbursementEvents = financialEvents.filter { event in
            event.status == .paid &&
            event.type == .income &&
            event.effectiveIncomeType == .reimbursement &&
            event.date >= monthRange.start &&
            event.date < monthRange.end &&
            event.reimbursementCategoryName != nil
        }

        return Dictionary(grouping: reimbursementEvents) { event in
            event.reimbursementCategoryName ?? "Uncategorized"
        }
        .mapValues { events in
            events.map { $0.amount }.reduce(0, +)
        }
    }

    // MARK: - Installment Plans

    func addInstallmentPlanAndGenerateEvents(_ plan: InstallmentPlan) {
        installmentPlans.append(plan)
        financialEvents.append(contentsOf: generateInstallmentEvents(for: plan))
    }

    func updateInstallmentPlanAndRegenerateFutureEvents(_ updatedPlan: InstallmentPlan) {
        guard let index = installmentPlans.firstIndex(where: { $0.id == updatedPlan.id }) else {
            return
        }

        installmentPlans[index] = updatedPlan

        let paidGeneratedEvents = financialEvents
            .filter { event in
                event.sourceInstallmentPlanID == updatedPlan.id &&
                event.type == .installment &&
                event.status == .paid
            }
            .sorted { $0.date < $1.date }

        financialEvents.removeAll { event in
            event.sourceInstallmentPlanID == updatedPlan.id &&
            event.type == .installment &&
            event.status != .paid
        }

        let regeneratedEvents = Array(
            generateInstallmentEvents(for: updatedPlan)
                .dropFirst(paidGeneratedEvents.count)
        )

        financialEvents.append(contentsOf: regeneratedEvents)
    }

    func deleteInstallmentPlanAndFutureEvents(_ plan: InstallmentPlan) {
        markInstallmentPlanDeletedLocally(id: plan.id, deletedAt: Date())
        installmentPlans.removeAll { $0.id == plan.id }

        let futureEvents = financialEvents.filter { event in
            event.sourceInstallmentPlanID == plan.id &&
            event.type == .installment &&
            event.status != .paid
        }
        for event in futureEvents {
            markFinancialEventDeletedLocally(id: event.id, deletedAt: Date())
        }
        financialEvents.removeAll { event in
            futureEvents.contains { $0.id == event.id }
        }
    }

    func installmentProgressText(for event: FinancialEvent) -> String? {
        guard event.type == .installment,
              let planID = event.sourceInstallmentPlanID,
              installmentPlans.contains(where: { $0.id == planID }) else {
            return nil
        }

        let linkedEvents = financialEvents
            .filter { linkedEvent in
                linkedEvent.sourceInstallmentPlanID == planID &&
                linkedEvent.type == .installment
            }
            .sorted {
                if $0.date == $1.date {
                    return $0.createdAt < $1.createdAt
                }

                return $0.date < $1.date
            }

        guard let index = linkedEvents.firstIndex(where: { $0.id == event.id }) else {
            return nil
        }

        return "Installment \(index + 1) of \(linkedEvents.count)"
    }

    func installmentPlanSummary(for plan: InstallmentPlan) -> (paidCount: Int, totalCount: Int, remainingUnpaidAmount: Double, nextDueDate: Date?) {
        let linkedEvents = financialEvents
            .filter { event in
            event.sourceInstallmentPlanID == plan.id &&
            event.type == .installment
            }
            .sorted { $0.date < $1.date }

        let paidCount = linkedEvents.filter { $0.status == .paid }.count
        let unpaidEvents = linkedEvents.filter { $0.status != .paid }
        let remainingUnpaidAmount = unpaidEvents
            .map { $0.amount }
            .reduce(0, +)

        return (
            paidCount: paidCount,
            totalCount: linkedEvents.isEmpty ? plan.installmentCount : linkedEvents.count,
            remainingUnpaidAmount: remainingUnpaidAmount,
            nextDueDate: unpaidEvents.first?.date
        )
    }

    func generateInstallmentEvents(for plan: InstallmentPlan) -> [FinancialEvent] {
        guard plan.installmentCount > 0 else {
            return []
        }

        let cleanPurchaseName = plan.purchaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPaymentMethodName = plan.paymentMethodName.trimmingCharacters(in: .whitespacesAndNewlines)
        let paymentMethodName = cleanPaymentMethodName.isEmpty ? "Valu" : cleanPaymentMethodName
        let title = "\(paymentMethodName) - \(cleanPurchaseName)"
        let accountName = plan.accountName ?? accounts.first { $0.isActive }?.name

        return (0..<plan.installmentCount).compactMap { monthOffset in
            guard let dueDate = installmentDueDate(
                firstDueDate: plan.firstDueDate,
                monthOffset: monthOffset
            ) else {
                return nil
            }

            return FinancialEvent(
                type: .installment,
                status: .unpaid,
                title: title,
                amount: plan.monthlyAmount,
                date: dueDate,
                accountName: accountName,
                walletEventName: nil,
                categoryName: plan.categoryName,
                subCategoryName: plan.subCategoryName,
                repeatRule: .none,
                confidence: .high,
                sourceInstallmentPlanID: plan.id,
                note: plan.note,
                createdAt: Date()
            )
        }
    }

    private func installmentDueDate(firstDueDate: Date, monthOffset: Int) -> Date? {
        let calendar = Calendar.current
        let preferredDay = calendar.component(.day, from: firstDueDate)

        guard let roughDate = calendar.date(
            byAdding: .month,
            value: monthOffset,
            to: firstDueDate
        ) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month], from: roughDate)
        let daysInTargetMonth = calendar.range(
            of: .day,
            in: .month,
            for: roughDate
        )?.count ?? preferredDay

        components.day = min(preferredDay, daysInTargetMonth)
        return calendar.date(from: components)
    }

    // MARK: - Update Status

    func markAsPaid(_ event: FinancialEvent) {
        guard let index = financialEvents.firstIndex(where: { $0.id == event.id }) else {
            return
        }

        let wasAlreadyPaid = financialEvents[index].status == .paid
        var paidEvent = financialEvents[index]
        paidEvent.status = .paid

        guard canApplyFinancialEvent(paidEvent) else {
            return
        }

        financialEvents[index].status = .paid
        financialEvents[index].createdAt = Date()

        if !wasAlreadyPaid {
            applyAccountImpactIfNeeded(financialEvents[index])
        }
    }

    @discardableResult
    func markAsPaid(
        _ event: FinancialEvent,
        amount: Double,
        accountName: String,
        paymentMethodName: String,
        paymentDate: Date,
        categoryName: String?,
        subCategoryName: String?,
        note: String?
    ) -> Bool {
        guard let index = financialEvents.firstIndex(where: { $0.id == event.id }),
              financialEvents[index].status != .paid,
              amount > 0,
              accounts.contains(where: { $0.name == accountName }) else {
            return false
        }

        financialEvents[index].amount = amount
        financialEvents[index].accountName = accountName
        financialEvents[index].paymentMethodName = paymentMethodName
        financialEvents[index].date = paymentDate
        financialEvents[index].categoryName = categoryName
        financialEvents[index].subCategoryName = subCategoryName
        financialEvents[index].note = note
        financialEvents[index].status = .paid
        financialEvents[index].createdAt = Date()

        applyAccountImpactIfNeeded(financialEvents[index])
        return true
    }

    func cancelEvent(_ event: FinancialEvent) {
        guard let index = financialEvents.firstIndex(where: { $0.id == event.id }) else {
            return
        }

        financialEvents[index].status = .cancelled
    }

    // MARK: - Reset

    func resetToSampleData() {
        accounts = SampleWalletData.accounts
        categories = SampleWalletData.categories
        walletEvents = SampleWalletData.walletEvents
        merchantMemories = []
        installmentPlans = SampleWalletData.installmentPlans
        financialEvents = SampleWalletData.financialEvents
        personDebts = []
        personDebtEntries = []
        monthlyBudgets = []
        historicalMonthlySummaries = []
        creditCards = []
        creditCardPurchases = []
        creditCardPayments = []
        monthlyLivingBurn = 45_000
        runwaySafeBalanceTarget = 0
        instaPayFeePercent = 0.1
        instaPayMinimumFee = 0.5
        instaPayMaximumFee = 20
        displayName = ""
        appLanguage = .english
        forecastHorizonMonths = 12
        hideBalances = false
    }

    // MARK: - Account Impact

    private func applyAccountImpactIfNeeded(_ event: FinancialEvent) {
        applyAccountImpact(event, multiplier: 1, markAccountsUpdatedForSync: true)
    }

    private func reverseAccountImpactIfNeeded(_ event: FinancialEvent) {
        applyAccountImpact(event, multiplier: -1, markAccountsUpdatedForSync: true)
    }

    private func applyAccountImpact(
        _ event: FinancialEvent,
        multiplier: Double,
        markAccountsUpdatedForSync: Bool
    ) {
        guard event.status == .paid else {
            return
        }

        guard let accountName = event.accountName else {
            return
        }

        guard let index = accounts.firstIndex(where: { $0.name == accountName }) else {
            return
        }

        switch event.type {
        case .expense, .obligation, .expectedExpense, .installment:
            accounts[index].balance -= event.amount * multiplier
            markAccountUpdatedForSyncIfNeeded(at: index, enabled: markAccountsUpdatedForSync)

        case .income:
            accounts[index].balance += event.amount * multiplier
            markAccountUpdatedForSyncIfNeeded(at: index, enabled: markAccountsUpdatedForSync)

        case .transfer:
            guard let destinationAccountName = event.destinationAccountName,
                  let destinationIndex = accounts.firstIndex(where: { $0.name == destinationAccountName }) else {
                return
            }

            accounts[index].balance -= event.amount * multiplier
            accounts[destinationIndex].balance += event.amount * multiplier
            markAccountUpdatedForSyncIfNeeded(at: index, enabled: markAccountsUpdatedForSync)
            markAccountUpdatedForSyncIfNeeded(at: destinationIndex, enabled: markAccountsUpdatedForSync)
        }
    }

    private func markAccountUpdatedForSyncIfNeeded(at index: Int, enabled: Bool) {
        guard enabled else { return }
        accounts[index].updatedAt = Date()
    }

    private func canApplyFinancialEvent(_ event: FinancialEvent) -> Bool {
        guard event.amount > 0 else {
            return false
        }

        if event.status == .paid && event.type != .transfer {
            guard let accountName = event.accountName,
                  !accountName.isEmpty,
                  accounts.contains(where: { $0.name == accountName }) else {
                return false
            }
        }

        guard event.type == .transfer else {
            return true
        }

        guard let sourceAccountName = event.accountName,
              let destinationAccountName = event.destinationAccountName,
              !sourceAccountName.isEmpty,
              !destinationAccountName.isEmpty,
              sourceAccountName != destinationAccountName,
              accounts.contains(where: { $0.name == sourceAccountName }),
              accounts.contains(where: { $0.name == destinationAccountName }) else {
            return false
        }

        return true
    }

    // MARK: - Save

    private func saveAccounts() {
        markLocalDataChanged()
        save(accounts, key: StorageKey.accounts)
    }

    private func saveCategories() {
        markLocalDataChanged()
        save(categories, key: StorageKey.categories)
    }

    private func saveWalletEvents() {
        markLocalDataChanged()
        save(walletEvents, key: StorageKey.walletEvents)
    }

    private func saveMerchantMemories() {
        markLocalDataChanged()
        save(merchantMemories, key: StorageKey.merchantMemories)
    }

    private func saveInstallmentPlans() {
        markLocalDataChanged()
        save(installmentPlans, key: StorageKey.installmentPlans)
    }

    private func saveFinancialEvents() {
        markLocalDataChanged()
        save(financialEvents, key: StorageKey.financialEvents)
    }

    private func savePersonDebts() {
        markLocalDataChanged()
        save(personDebts, key: StorageKey.personDebts)
    }

    private func savePersonDebtEntries() {
        markLocalDataChanged()
        save(personDebtEntries, key: StorageKey.personDebtEntries)
    }

    private func saveMonthlyBudgets() {
        markLocalDataChanged()
        save(monthlyBudgets, key: StorageKey.monthlyBudgets)
    }

    private func saveHistoricalMonthlySummaries() {
        markLocalDataChanged()
        save(historicalMonthlySummaries, key: StorageKey.historicalMonthlySummaries)
    }

    private func saveCreditCards() {
        markLocalDataChanged()
        save(creditCards, key: StorageKey.creditCards)
    }

    private func saveCreditCardPurchases() {
        markLocalDataChanged()
        save(creditCardPurchases, key: StorageKey.creditCardPurchases)
    }

    private func saveCreditCardPayments() {
        markLocalDataChanged()
        save(creditCardPayments, key: StorageKey.creditCardPayments)
    }

    private func saveMonthlyLivingBurn() {
        markLocalDataChanged()
        save(monthlyLivingBurn, key: StorageKey.monthlyLivingBurn)
    }

    private func saveRunwaySafeBalanceTarget() {
        markLocalDataChanged()
        save(runwaySafeBalanceTarget, key: StorageKey.runwaySafeBalanceTarget)
    }

    private func saveInstaPayFeeSettings() {
        markLocalDataChanged()
        save(instaPayFeePercent, key: StorageKey.instaPayFeePercent)
        save(instaPayMinimumFee, key: StorageKey.instaPayMinimumFee)
        save(instaPayMaximumFee, key: StorageKey.instaPayMaximumFee)
    }

    private func saveAppPreferences() {
        markLocalDataChanged()
        save(displayName, key: StorageKey.displayName)
        save(appLanguage, key: StorageKey.appLanguage)
        save(forecastHorizonMonths, key: StorageKey.forecastHorizonMonths)
        save(hideBalances, key: StorageKey.hideBalances)
        save(incomeMode, key: StorageKey.incomeMode)
        save(salaryResumeDate, key: StorageKey.salaryResumeDate)
    }

    private func markLocalDataChanged() {
        localDataUpdatedAt = Date()
    }

    private func markSyncRecordDeletedLocally(entity: WalletSyncRecordEntity, id: UUID) {
        WalletSyncStateStore(keyValueStore: userDefaults).markRecordDeletedLocally(entity: entity, id: id)
    }

    private func markInstallmentPlanDeletedLocally(id: UUID, deletedAt: Date) {
        WalletSyncStateStore(keyValueStore: userDefaults).markInstallmentPlanDeletedLocally(id: id, deletedAt: deletedAt)
    }

    private func markHighRiskRecordDeletedLocally(entity: WalletSyncRecordEntity, id: UUID, deletedAt: Date) {
        WalletSyncStateStore(keyValueStore: userDefaults).markHighRiskRecordDeletedLocally(
            entity: entity,
            id: id,
            deletedAt: deletedAt
        )
    }

    private func markFinancialEventDeletedLocally(id: UUID, deletedAt: Date) {
        WalletSyncStateStore(keyValueStore: userDefaults).markFinancialEventDeletedLocally(id: id, deletedAt: deletedAt)
    }

    private func saveLocalDataUpdatedAt() {
        save(localDataUpdatedAt, key: StorageKey.localDataUpdatedAt)
    }

    private func saveICloudSyncSettings() {
        save(iCloudSyncEnabled, key: StorageKey.iCloudSyncEnabled)
        save(lastICloudUploadAt, key: StorageKey.lastICloudUploadAt)
        save(lastICloudDownloadAt, key: StorageKey.lastICloudDownloadAt)
        save(lastKnownRemoteUpdateAt, key: StorageKey.lastKnownRemoteUpdateAt)
        save(lastICloudSyncError, key: StorageKey.lastICloudSyncError)
    }

    private func saveOnboardingState() {
        save(onboardingSkipped, key: StorageKey.onboardingSkipped)
        save(onboardingCompleted, key: StorageKey.onboardingCompleted)
        save(onboardingLastStep, key: StorageKey.onboardingLastStep)
    }

    private func save<T: Codable>(_ value: T, key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            userDefaults.set(data, forKey: key)
        } catch {
            print("Failed to save \(key): \(error.localizedDescription)")
        }
    }

    private static func load<T: Codable>(key: String, fallback: T, userDefaults: UserDefaults) -> T {
        guard let data = userDefaults.data(forKey: key) else {
            return fallback
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Failed to load \(key): \(error.localizedDescription)")
            return fallback
        }
    }

    private static func hasPersistedMeaningfulWalletData(userDefaults: UserDefaults) -> Bool {
        [
            StorageKey.accounts,
            StorageKey.financialEvents,
            StorageKey.installmentPlans,
            StorageKey.monthlyBudgets,
            StorageKey.creditCards,
            StorageKey.creditCardPurchases,
            StorageKey.creditCardPayments,
            StorageKey.personDebts,
            StorageKey.personDebtEntries
        ].contains { userDefaults.data(forKey: $0) != nil }
    }
}

extension WalletStore: WalletSyncInitialCloudAdoptionSeedPruning {
    @discardableResult
    func removeSeedDataBeforeInitialCloudAdoptionIfSafe() -> Bool {
        guard containsOnlySampleSeedDataForCloudAdoption else {
            return false
        }

        accounts = []
        categories = []
        walletEvents = []
        merchantMemories = []
        installmentPlans = []
        financialEvents = []
        personDebts = []
        personDebtEntries = []
        monthlyBudgets = []
        historicalMonthlySummaries = []
        creditCards = []
        creditCardPurchases = []
        creditCardPayments = []
        return true
    }

    private var containsOnlySampleSeedDataForCloudAdoption: Bool {
        Set(accounts.map(Self.accountSeedKey)) == Set(SampleWalletData.accounts.map(Self.accountSeedKey)) &&
        Set(categories.map(Self.categorySeedKey)) == Set(SampleWalletData.categories.map(Self.categorySeedKey)) &&
        Set(walletEvents.map(Self.walletEventSeedKey)) == Set(SampleWalletData.walletEvents.map(Self.walletEventSeedKey)) &&
        Set(installmentPlans.map(Self.installmentPlanSeedKey)) == Set(SampleWalletData.installmentPlans.map(Self.installmentPlanSeedKey)) &&
        Set(financialEvents.map(Self.financialEventSeedKey)) == Set(SampleWalletData.financialEvents.map(Self.financialEventSeedKey)) &&
        merchantMemories.isEmpty &&
        personDebts.isEmpty &&
        personDebtEntries.isEmpty &&
        monthlyBudgets.isEmpty &&
        historicalMonthlySummaries.isEmpty &&
        creditCards.isEmpty &&
        creditCardPurchases.isEmpty &&
        creditCardPayments.isEmpty
    }

    nonisolated private static func accountSeedKey(_ account: Account) -> String {
        "\(account.name)|\(account.type.rawValue)|\(account.balance)"
    }

    nonisolated private static func categorySeedKey(_ category: Category) -> String {
        "\(category.name)|\(category.subcategories.joined(separator: "\u{1F}"))"
    }

    nonisolated private static func walletEventSeedKey(_ event: WalletEvent) -> String {
        [
            event.name,
            event.categoryName,
            event.subCategoryName,
            event.defaultAccountName ?? "",
            String(event.isFavorite)
        ].joined(separator: "|")
    }

    nonisolated private static func installmentPlanSeedKey(_ plan: InstallmentPlan) -> String {
        [
            plan.purchaseName,
            "\(plan.totalAmount)",
            "\(plan.installmentCount)",
            "\(plan.firstDueDate.timeIntervalSince1970)",
            plan.categoryName,
            plan.subCategoryName,
            plan.paymentMethodName
        ].joined(separator: "|")
    }

    nonisolated private static func financialEventSeedKey(_ event: FinancialEvent) -> String {
        [
            event.type.rawValue,
            event.status.rawValue,
            event.title,
            "\(event.amount)",
            "\(event.date.timeIntervalSince1970)",
            event.accountName ?? "",
            event.destinationAccountName ?? "",
            event.categoryName ?? "",
            event.subCategoryName ?? ""
        ].joined(separator: "|")
    }
}
