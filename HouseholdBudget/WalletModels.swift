import Foundation

// MARK: - Account

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case cash = "Cash"
    case bank = "Bank"
    case wallet = "Wallet"

    var id: String { rawValue }
}

enum ProviderAppearanceColor: String, Codable, CaseIterable, Identifiable {
    case blue = "Blue"
    case indigo = "Indigo"
    case purple = "Purple"
    case green = "Green"
    case mint = "Mint"
    case teal = "Teal"
    case orange = "Orange"
    case red = "Red"
    case pink = "Pink"
    case gray = "Gray"

    var id: String { rawValue }
}

struct Account: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var balance: Double
    var type: AccountType
    var isActive: Bool = true
    var recognitionAliases: [String] = []
    var recognitionCardEndings: [String] = []
    var appearanceColor: ProviderAppearanceColor?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var deletedAt: Date? = nil

    init(
        id: UUID = UUID(),
        name: String,
        balance: Double,
        type: AccountType,
        isActive: Bool = true,
        recognitionAliases: [String] = [],
        recognitionCardEndings: [String] = [],
        appearanceColor: ProviderAppearanceColor? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.balance = balance
        self.type = type
        self.isActive = isActive
        self.recognitionAliases = recognitionAliases
        self.recognitionCardEndings = recognitionCardEndings
        self.appearanceColor = appearanceColor
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case balance
        case type
        case isActive
        case recognitionAliases
        case recognitionCardEndings
        case appearanceColor
        case createdAt
        case updatedAt
        case isDeleted
        case deletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        balance = try container.decode(Double.self, forKey: .balance)
        type = try container.decode(AccountType.self, forKey: .type)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        recognitionAliases = try container.decodeIfPresent([String].self, forKey: .recognitionAliases) ?? []
        recognitionCardEndings = try container.decodeIfPresent([String].self, forKey: .recognitionCardEndings) ?? []
        appearanceColor = try container.decodeIfPresent(ProviderAppearanceColor.self, forKey: .appearanceColor)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

// MARK: - Category

struct Category: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var subcategories: [String]
    var isActive: Bool = true
    var inactiveSubcategoryNames: [String] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var deletedAt: Date? = nil

    init(
        id: UUID = UUID(),
        name: String,
        subcategories: [String],
        isActive: Bool = true,
        inactiveSubcategoryNames: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.subcategories = subcategories
        self.isActive = isActive
        self.inactiveSubcategoryNames = inactiveSubcategoryNames
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case subcategories
        case isActive
        case inactiveSubcategoryNames
        case createdAt
        case updatedAt
        case isDeleted
        case deletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        subcategories = try container.decode([String].self, forKey: .subcategories)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        inactiveSubcategoryNames = try container.decodeIfPresent([String].self, forKey: .inactiveSubcategoryNames) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(subcategories, forKey: .subcategories)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(inactiveSubcategoryNames, forKey: .inactiveSubcategoryNames)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }
}

// MARK: - Wallet Event
// User-friendly event, such as Fuel, Talabat, Pharmacy, Supermarket.

struct WalletEvent: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String

    var categoryName: String
    var subCategoryName: String

    var defaultAccountName: String?
    var isFavorite: Bool = false
    var isActive: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var deletedAt: Date? = nil

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case categoryName
        case subCategoryName
        case defaultAccountName
        case isFavorite
        case isActive
        case createdAt
        case updatedAt
        case isDeleted
        case deletedAt
    }

}

extension WalletEvent {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        categoryName = try container.decode(String.self, forKey: .categoryName)
        subCategoryName = try container.decode(String.self, forKey: .subCategoryName)
        defaultAccountName = try container.decodeIfPresent(String.self, forKey: .defaultAccountName)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

struct MerchantMemory: Identifiable, Codable, Hashable {
    var id = UUID()
    var merchantName: String
    var aliases: [String] = []
    var defaultCategoryName: String
    var defaultSubCategoryName: String
    var defaultAccountName: String?
    var defaultType: FinancialEventType = .expense
    var lastUsedAt: Date? = nil
    var usageCount: Int = 0
    var isActive: Bool = true
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var deletedAt: Date? = nil

    private enum CodingKeys: String, CodingKey {
        case id
        case merchantName
        case aliases
        case defaultCategoryName
        case defaultSubCategoryName
        case defaultAccountName
        case defaultType
        case lastUsedAt
        case usageCount
        case isActive
        case createdAt
        case updatedAt
        case isDeleted
        case deletedAt
    }

}

extension MerchantMemory {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        merchantName = try container.decode(String.self, forKey: .merchantName)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        defaultCategoryName = try container.decode(String.self, forKey: .defaultCategoryName)
        defaultSubCategoryName = try container.decode(String.self, forKey: .defaultSubCategoryName)
        defaultAccountName = try container.decodeIfPresent(String.self, forKey: .defaultAccountName)
        defaultType = try container.decodeIfPresent(FinancialEventType.self, forKey: .defaultType) ?? .expense
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        usageCount = try container.decodeIfPresent(Int.self, forKey: .usageCount) ?? 0
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

// MARK: - Financial Event

enum FinancialEventType: String, Codable, CaseIterable, Identifiable {
    case expense = "Expense"
    case income = "Income"
    case obligation = "Obligation"
    case expectedExpense = "Expected Expense"
    case installment = "Installment"
    case transfer = "Transfer"

    var id: String { rawValue }
}

enum FinancialEventStatus: String, Codable, CaseIterable, Identifiable {
    case planned = "Planned"
    case expected = "Expected"
    case paid = "Paid"
    case unpaid = "Unpaid"
    case skipped = "Skipped"
    case cancelled = "Cancelled"

    var id: String { rawValue }
}

enum IncomeType: String, Codable, CaseIterable, Identifiable {
    case salary
    case oneTimeCashInflow
    case reimbursement
    case transfer
    case loanOrDebt
    case unknown

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .salary:
            return language == .arabicEgyptian ? "مرتب" : "Salary"
        case .oneTimeCashInflow:
            return language == .arabicEgyptian ? "دخول مرة واحدة" : "One-time cash inflow"
        case .reimbursement:
            return language == .arabicEgyptian ? "استرداد / تعويض" : "Reimbursement"
        case .transfer:
            return language == .arabicEgyptian ? "تحويل" : "Transfer"
        case .loanOrDebt:
            return language == .arabicEgyptian ? "سلفة / دين" : "Loan / Debt"
        case .unknown:
            return language == .arabicEgyptian ? "غير محدد" : "Unknown"
        }
    }
}

enum IncomeMode: String, Codable, CaseIterable, Identifiable {
    case regularSalaryActive
    case noSalaryUntilDate
    case irregularIncome
    case vacationUnpaidPeriod
    case unknown

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .regularSalaryActive:
            return language == .arabicEgyptian ? "المرتب شغال عادي" : "Regular salary active"
        case .noSalaryUntilDate:
            return language == .arabicEgyptian ? "مفيش مرتب لحد تاريخ" : "No salary until date"
        case .irregularIncome:
            return language == .arabicEgyptian ? "دخل غير منتظم" : "Irregular income"
        case .vacationUnpaidPeriod:
            return language == .arabicEgyptian ? "إجازة / فترة بدون مرتب" : "Vacation / unpaid period"
        case .unknown:
            return language == .arabicEgyptian ? "غير محدد" : "Unknown"
        }
    }
}

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"

    var id: String { rawValue }
}

enum RecurringEndKind: String, Codable, CaseIterable, Identifiable {
    case never
    case onDate
    case afterNumberOfPayments

    var id: String { rawValue }
}

enum RecurringAmountMode: String, Codable, CaseIterable, Identifiable {
    case fixedAmount
    case variableEachMonth
    case estimatedUntilConfirmed

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .fixedAmount:
            return language == .arabicEgyptian ? "مبلغ ثابت" : "Fixed Amount"
        case .variableEachMonth:
            return language == .arabicEgyptian ? "مبلغ متغير كل شهر" : "Variable Each Month"
        case .estimatedUntilConfirmed:
            return language == .arabicEgyptian ? "تقديري لحين التأكيد" : "Estimated Until Confirmed"
        }
    }
}

struct RecurringScheduleOverride: Identifiable, Codable, Hashable {
    var id = UUID()
    var year: Int
    var month: Int
    var amount: Double
    var isSkipped: Bool = false
    var note: String? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    private enum CodingKeys: String, CodingKey {
        case id
        case year
        case month
        case amount
        case isSkipped
        case note
        case createdAt
        case updatedAt
    }

}

extension RecurringScheduleOverride {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        year = try container.decode(Int.self, forKey: .year)
        month = try container.decode(Int.self, forKey: .month)
        amount = try container.decode(Double.self, forKey: .amount)
        isSkipped = try container.decodeIfPresent(Bool.self, forKey: .isSkipped) ?? false
        note = try container.decodeIfPresent(String.self, forKey: .note)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

enum ConfidenceLevel: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english
    case arabicEgyptian

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .arabicEgyptian:
            return "عربي مصري"
        }
    }
}

struct RecurringPaidOccurrenceIdentity: Codable, Hashable {
    var sourceRecurringEventID: UUID
    var year: Int
    var month: Int
}

struct FinancialEvent: Identifiable, Codable, Hashable {
    var id = UUID()

    var type: FinancialEventType
    var status: FinancialEventStatus

    var title: String
    var amount: Double
    var date: Date

    var accountName: String?
    var destinationAccountName: String?
    var paymentMethodName: String?

    var walletEventName: String?
    var categoryName: String?
    var subCategoryName: String?
    var incomeType: IncomeType? = nil
    var reimbursementCategoryName: String? = nil

    var repeatRule: RepeatRule = .none
    var recurringEndKind: RecurringEndKind? = nil
    var recurringEndDate: Date? = nil
    var recurringEndPaymentCount: Int? = nil
    var recurringScheduleOverrides: [RecurringScheduleOverride]? = nil
    var recurringAmountMode: RecurringAmountMode? = nil
    var recurringEstimatedAmount: Double? = nil
    var confidence: ConfidenceLevel? = nil

    var sourceInstallmentPlanID: UUID? = nil
    var sourceRecurringEventID: UUID? = nil
    var recurringOccurrenceYear: Int? = nil
    var recurringOccurrenceMonth: Int? = nil

    var note: String? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var deletedAt: Date? = nil

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case status
        case title
        case amount
        case date
        case accountName
        case destinationAccountName
        case paymentMethodName
        case walletEventName
        case categoryName
        case subCategoryName
        case incomeType
        case reimbursementCategoryName
        case repeatRule
        case recurringEndKind
        case recurringEndDate
        case recurringEndPaymentCount
        case recurringScheduleOverrides
        case recurringAmountMode
        case recurringEstimatedAmount
        case confidence
        case sourceInstallmentPlanID
        case sourceRecurringEventID
        case recurringOccurrenceYear
        case recurringOccurrenceMonth
        case note
        case createdAt
        case updatedAt
        case isDeleted
        case deletedAt
    }

}

extension FinancialEvent {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        type = try container.decode(FinancialEventType.self, forKey: .type)
        status = try container.decode(FinancialEventStatus.self, forKey: .status)
        title = try container.decode(String.self, forKey: .title)
        amount = try container.decode(Double.self, forKey: .amount)
        date = try container.decode(Date.self, forKey: .date)
        accountName = try container.decodeIfPresent(String.self, forKey: .accountName)
        destinationAccountName = try container.decodeIfPresent(String.self, forKey: .destinationAccountName)
        paymentMethodName = try container.decodeIfPresent(String.self, forKey: .paymentMethodName)
        walletEventName = try container.decodeIfPresent(String.self, forKey: .walletEventName)
        categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        subCategoryName = try container.decodeIfPresent(String.self, forKey: .subCategoryName)
        incomeType = try container.decodeIfPresent(IncomeType.self, forKey: .incomeType)
        reimbursementCategoryName = try container.decodeIfPresent(String.self, forKey: .reimbursementCategoryName)
        repeatRule = try container.decodeIfPresent(RepeatRule.self, forKey: .repeatRule) ?? .none
        recurringEndKind = try container.decodeIfPresent(RecurringEndKind.self, forKey: .recurringEndKind)
        recurringEndDate = try container.decodeIfPresent(Date.self, forKey: .recurringEndDate)
        recurringEndPaymentCount = try container.decodeIfPresent(Int.self, forKey: .recurringEndPaymentCount)
        recurringScheduleOverrides = try container.decodeIfPresent([RecurringScheduleOverride].self, forKey: .recurringScheduleOverrides)
        recurringAmountMode = try container.decodeIfPresent(RecurringAmountMode.self, forKey: .recurringAmountMode)
        recurringEstimatedAmount = try container.decodeIfPresent(Double.self, forKey: .recurringEstimatedAmount)
        confidence = try container.decodeIfPresent(ConfidenceLevel.self, forKey: .confidence)
        sourceInstallmentPlanID = try container.decodeIfPresent(UUID.self, forKey: .sourceInstallmentPlanID)
        sourceRecurringEventID = try container.decodeIfPresent(UUID.self, forKey: .sourceRecurringEventID)
        recurringOccurrenceYear = try container.decodeIfPresent(Int.self, forKey: .recurringOccurrenceYear)
        recurringOccurrenceMonth = try container.decodeIfPresent(Int.self, forKey: .recurringOccurrenceMonth)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

extension FinancialEvent {
    var recurringPaidOccurrenceIdentity: RecurringPaidOccurrenceIdentity? {
        guard status == .paid,
              let sourceRecurringEventID,
              let recurringOccurrenceYear,
              let recurringOccurrenceMonth else {
            return nil
        }

        return RecurringPaidOccurrenceIdentity(
            sourceRecurringEventID: sourceRecurringEventID,
            year: recurringOccurrenceYear,
            month: recurringOccurrenceMonth
        )
    }

    var effectiveIncomeType: IncomeType {
        incomeType ?? .unknown
    }

    var effectiveRecurringEndKind: RecurringEndKind {
        recurringEndKind ?? .never
    }

    var effectiveRecurringAmountMode: RecurringAmountMode {
        recurringAmountMode ?? .fixedAmount
    }

    var effectiveRecurringEstimatedAmount: Double {
        switch effectiveRecurringAmountMode {
        case .fixedAmount:
            return max(recurringEstimatedAmount ?? amount, 0)
        case .variableEachMonth, .estimatedUntilConfirmed:
            return max(recurringEstimatedAmount ?? 0, 0)
        }
    }

    func allowsRecurringOccurrence(on occurrenceDate: Date, occurrenceNumber: Int) -> Bool {
        switch effectiveRecurringEndKind {
        case .never:
            return true
        case .onDate:
            guard let recurringEndDate else {
                return true
            }

            let calendar = Calendar.current
            return calendar.startOfDay(for: occurrenceDate) <= calendar.startOfDay(for: recurringEndDate)
        case .afterNumberOfPayments:
            guard let recurringEndPaymentCount else {
                return true
            }

            return occurrenceNumber <= max(recurringEndPaymentCount, 0)
        }
    }

    func recurringOverride(for occurrenceDate: Date) -> RecurringScheduleOverride? {
        let components = Calendar.current.dateComponents([.year, .month], from: occurrenceDate)

        guard let year = components.year,
              let month = components.month else {
            return nil
        }

        return recurringScheduleOverrides?.first {
            $0.year == year && $0.month == month
        }
    }

    func isRecurringOccurrenceSkipped(on occurrenceDate: Date) -> Bool {
        recurringOverride(for: occurrenceDate)?.isSkipped == true
    }

    func recurringAmount(for occurrenceDate: Date) -> Double {
        if let override = recurringOverride(for: occurrenceDate) {
            guard !override.isSkipped else {
                return 0
            }

            return max(override.amount, 0)
        }

        switch effectiveRecurringAmountMode {
        case .fixedAmount:
            return amount
        case .variableEachMonth, .estimatedUntilConfirmed:
            return effectiveRecurringEstimatedAmount
        }
    }
}

// MARK: - Installment Plan

struct InstallmentPlan: Identifiable, Codable, Hashable {
    var id = UUID()

    var purchaseName: String
    var totalAmount: Double
    var installmentCount: Int
    var firstDueDate: Date
    var accountName: String?

    var categoryName: String
    var subCategoryName: String

    var paymentMethodName: String = "Valu"
    var linkedCreditCardID: UUID? = nil
    var note: String? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var deletedAt: Date? = nil

    var monthlyAmount: Double {
        guard installmentCount > 0 else { return 0 }
        return totalAmount / Double(installmentCount)
    }

    init(
        id: UUID = UUID(),
        purchaseName: String,
        totalAmount: Double,
        installmentCount: Int,
        firstDueDate: Date,
        accountName: String? = nil,
        categoryName: String,
        subCategoryName: String,
        paymentMethodName: String = "Valu",
        linkedCreditCardID: UUID? = nil,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.purchaseName = purchaseName
        self.totalAmount = totalAmount
        self.installmentCount = installmentCount
        self.firstDueDate = firstDueDate
        self.accountName = accountName
        self.categoryName = categoryName
        self.subCategoryName = subCategoryName
        self.paymentMethodName = paymentMethodName
        self.linkedCreditCardID = linkedCreditCardID
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case purchaseName
        case totalAmount
        case installmentCount
        case firstDueDate
        case accountName
        case categoryName
        case subCategoryName
        case paymentMethodName
        case linkedCreditCardID
        case note
        case createdAt
        case updatedAt
        case isDeleted
        case deletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        purchaseName = try container.decode(String.self, forKey: .purchaseName)
        totalAmount = try container.decode(Double.self, forKey: .totalAmount)
        installmentCount = try container.decode(Int.self, forKey: .installmentCount)
        firstDueDate = try container.decode(Date.self, forKey: .firstDueDate)
        accountName = try container.decodeIfPresent(String.self, forKey: .accountName)
        categoryName = try container.decode(String.self, forKey: .categoryName)
        subCategoryName = try container.decode(String.self, forKey: .subCategoryName)
        paymentMethodName = try container.decodeIfPresent(String.self, forKey: .paymentMethodName) ?? "Valu"
        linkedCreditCardID = try container.decodeIfPresent(UUID.self, forKey: .linkedCreditCardID)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

// MARK: - Forecast

struct MonthlyForecast: Identifiable, Codable, Hashable {
    var id = UUID()

    var monthStartDate: Date

    var startingCash: Double
    var confirmedOutflow: Double
    var expectedOutflow: Double
    var expectedIncome: Double

    var endingCash: Double {
        startingCash + expectedIncome - confirmedOutflow - expectedOutflow
    }
}

struct FinancialRunwayResult: Codable, Hashable {
    var availableCash: Double
    var requiredUntilNextIncome: Double
    var safetyBuffer: Double

    var safeUntilDate: Date?
    var nextIncomeDate: Date?

    var isSafe: Bool
}

// MARK: - Monthly Budget

struct WalletMonthlyBudget: Identifiable, Codable, Hashable {
    var id = UUID()
    var year: Int
    var month: Int
    var items: [WalletMonthlyBudgetItem]
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var deletedAt: Date? = nil

    private enum CodingKeys: String, CodingKey {
        case id
        case year
        case month
        case items
        case createdAt
        case updatedAt
        case isDeleted
        case deletedAt
    }

}

extension WalletMonthlyBudget {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        year = try container.decode(Int.self, forKey: .year)
        month = try container.decode(Int.self, forKey: .month)
        items = try container.decode([WalletMonthlyBudgetItem].self, forKey: .items)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

struct WalletMonthlyBudgetItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var categoryName: String
    var plannedAmount: Double
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var deletedAt: Date? = nil

    private enum CodingKeys: String, CodingKey {
        case id
        case categoryName
        case plannedAmount
        case createdAt
        case updatedAt
        case isDeleted
        case deletedAt
    }
}

extension WalletMonthlyBudgetItem {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        categoryName = try container.decode(String.self, forKey: .categoryName)
        plannedAmount = try container.decode(Double.self, forKey: .plannedAmount)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

// MARK: - People / Debts

enum PersonDebtKind: String, Codable, CaseIterable, Identifiable {
    case owedToMe = "Owed to Me"
    case iOwe = "I Owe"

    var id: String { rawValue }
}

enum PersonDebtEntryType: String, Codable, CaseIterable, Identifiable {
    case initialLending = "Initial Lending"
    case initialBorrowing = "Initial Borrowing"
    case repaymentReceived = "Repayment Received"
    case repaymentPaid = "Repayment Paid"

    var id: String { rawValue }
}

enum PersonDebtStatus: String, Codable, CaseIterable, Identifiable {
    case open = "Open"
    case partiallyPaid = "Partially Paid"
    case settled = "Settled"

    var id: String { rawValue }
}

struct PersonDebt: Identifiable, Codable, Hashable {
    var id = UUID()
    var personName: String
    var kind: PersonDebtKind
    var originalAmount: Double
    var note: String? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var dueDate: Date? = nil
    var isArchived: Bool = false
    var isDeleted: Bool = false
    var deletedAt: Date? = nil

    private enum CodingKeys: String, CodingKey {
        case id
        case personName
        case kind
        case originalAmount
        case note
        case createdAt
        case updatedAt
        case dueDate
        case isArchived
        case isDeleted
        case deletedAt
    }

}

extension PersonDebt {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        personName = try container.decode(String.self, forKey: .personName)
        kind = try container.decode(PersonDebtKind.self, forKey: .kind)
        originalAmount = try container.decode(Double.self, forKey: .originalAmount)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

struct PersonDebtEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var debtID: UUID
    var entryType: PersonDebtEntryType
    var amount: Double
    var accountName: String
    var date: Date
    var note: String? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isDeleted: Bool = false
    var deletedAt: Date? = nil

    private enum CodingKeys: String, CodingKey {
        case id
        case debtID
        case entryType
        case amount
        case accountName
        case date
        case note
        case createdAt
        case updatedAt
        case isDeleted
        case deletedAt
    }

}

extension PersonDebtEntry {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        debtID = try container.decode(UUID.self, forKey: .debtID)
        entryType = try container.decode(PersonDebtEntryType.self, forKey: .entryType)
        amount = try container.decode(Double.self, forKey: .amount)
        accountName = try container.decode(String.self, forKey: .accountName)
        date = try container.decode(Date.self, forKey: .date)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

// MARK: - Historical Summary-Only Data

struct HistoricalMonthlySummaryEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var year: Int
    var month: Int
    var categoryName: String
    var subCategoryName: String
    var amount: Double
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool = false
    var deletedAt: Date? = nil

    init(
        id: UUID = UUID(),
        year: Int,
        month: Int,
        categoryName: String,
        subCategoryName: String,
        amount: Double,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.year = year
        self.month = month
        self.categoryName = categoryName
        self.subCategoryName = subCategoryName
        self.amount = amount
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case year
        case month
        case categoryName
        case subCategoryName
        case amount
        case note
        case createdAt
        case updatedAt
        case isDeleted
        case deletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        year = try container.decode(Int.self, forKey: .year)
        month = try container.decode(Int.self, forKey: .month)
        categoryName = try container.decode(String.self, forKey: .categoryName)
        subCategoryName = try container.decode(String.self, forKey: .subCategoryName)
        amount = try container.decode(Double.self, forKey: .amount)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

// MARK: - Credit Cards

enum CreditCardNetwork: String, Codable, CaseIterable, Identifiable {
    case visa = "Visa"
    case mastercard = "Mastercard"
    case other = "Other"

    var id: String { rawValue }
}

struct CreditCard: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var bankName: String
    var lastFourDigits: String?
    var cardNetwork: CreditCardNetwork
    var appearanceColor: ProviderAppearanceColor?
    var creditLimit: Double
    var openingOutstandingBalance: Double
    var openingOutstandingDate: Date?
    var statementClosingDay: Int
    var paymentDueDay: Int
    var defaultPaymentAccountName: String?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var note: String?
    var isDeleted: Bool = false
    var deletedAt: Date? = nil

    init(
        id: UUID = UUID(),
        name: String,
        bankName: String,
        lastFourDigits: String? = nil,
        cardNetwork: CreditCardNetwork = .other,
        appearanceColor: ProviderAppearanceColor? = nil,
        creditLimit: Double,
        openingOutstandingBalance: Double = 0,
        openingOutstandingDate: Date? = nil,
        statementClosingDay: Int,
        paymentDueDay: Int,
        defaultPaymentAccountName: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        note: String? = nil,
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.bankName = bankName
        self.lastFourDigits = lastFourDigits
        self.cardNetwork = cardNetwork
        self.appearanceColor = appearanceColor
        self.creditLimit = creditLimit
        self.openingOutstandingBalance = max(openingOutstandingBalance, 0)
        self.openingOutstandingDate = openingOutstandingDate
        self.statementClosingDay = statementClosingDay
        self.paymentDueDay = paymentDueDay
        self.defaultPaymentAccountName = defaultPaymentAccountName
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.note = note
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case bankName
        case lastFourDigits
        case cardNetwork
        case appearanceColor
        case creditLimit
        case openingOutstandingBalance
        case openingOutstandingDate
        case statementClosingDay
        case paymentDueDay
        case defaultPaymentAccountName
        case isActive
        case createdAt
        case updatedAt
        case note
        case isDeleted
        case deletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        bankName = try container.decodeIfPresent(String.self, forKey: .bankName) ?? ""
        lastFourDigits = try container.decodeIfPresent(String.self, forKey: .lastFourDigits)
        cardNetwork = try container.decodeIfPresent(CreditCardNetwork.self, forKey: .cardNetwork) ?? .other
        appearanceColor = try container.decodeIfPresent(ProviderAppearanceColor.self, forKey: .appearanceColor)
        creditLimit = try container.decodeIfPresent(Double.self, forKey: .creditLimit) ?? 0
        openingOutstandingBalance = max(try container.decodeIfPresent(Double.self, forKey: .openingOutstandingBalance) ?? 0, 0)
        openingOutstandingDate = try container.decodeIfPresent(Date.self, forKey: .openingOutstandingDate)
        statementClosingDay = try container.decodeIfPresent(Int.self, forKey: .statementClosingDay) ?? 1
        paymentDueDay = try container.decodeIfPresent(Int.self, forKey: .paymentDueDay) ?? 1
        defaultPaymentAccountName = try container.decodeIfPresent(String.self, forKey: .defaultPaymentAccountName)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        note = try container.decodeIfPresent(String.self, forKey: .note)
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

struct CreditCardPurchase: Identifiable, Codable, Hashable {
    var id: UUID
    var cardID: UUID
    var title: String
    var amount: Double
    var purchaseDate: Date
    var categoryName: String
    var subCategoryName: String
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool = false
    var deletedAt: Date? = nil

    private enum CodingKeys: String, CodingKey {
        case id
        case cardID
        case title
        case amount
        case purchaseDate
        case categoryName
        case subCategoryName
        case note
        case createdAt
        case updatedAt
        case isDeleted
        case deletedAt
    }

}

extension CreditCardPurchase {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        cardID = try container.decode(UUID.self, forKey: .cardID)
        title = try container.decode(String.self, forKey: .title)
        amount = try container.decode(Double.self, forKey: .amount)
        purchaseDate = try container.decode(Date.self, forKey: .purchaseDate)
        categoryName = try container.decode(String.self, forKey: .categoryName)
        subCategoryName = try container.decode(String.self, forKey: .subCategoryName)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

struct CreditCardPayment: Identifiable, Codable, Hashable {
    var id: UUID
    var cardID: UUID
    var fromAccountName: String
    var amount: Double
    var paymentDate: Date
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool = false
    var deletedAt: Date? = nil

    private enum CodingKeys: String, CodingKey {
        case id
        case cardID
        case fromAccountName
        case amount
        case paymentDate
        case note
        case createdAt
        case updatedAt
        case isDeleted
        case deletedAt
    }

}

extension CreditCardPayment {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        cardID = try container.decode(UUID.self, forKey: .cardID)
        fromAccountName = try container.decode(String.self, forKey: .fromAccountName)
        amount = try container.decode(Double.self, forKey: .amount)
        paymentDate = try container.decode(Date.self, forKey: .paymentDate)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

struct CreditCardDueItem: Identifiable, Hashable {
    var cardID: UUID
    var cardName: String
    var dueAmount: Double
    var outstandingAmount: Double
    var statementClosingDate: Date
    var dueDate: Date
    var defaultPaymentAccountName: String?
    var statusLabel: String

    var id: String {
        let components = Calendar.current.dateComponents([.year, .month], from: dueDate)
        return "\(cardID.uuidString)-\(components.year ?? 0)-\(components.month ?? 0)"
    }
}

struct CreditCardStatementPaymentAllocation: Identifiable, Hashable {
    var id: String
    var paymentID: UUID
    var fromAccountName: String
    var paymentDate: Date
    var amount: Double
    var note: String?
}

struct CreditCardStatementLedgerEntry: Identifiable, Hashable {
    var cardID: UUID
    var cardName: String
    var statementClosingDate: Date
    var paymentDueDate: Date
    var openingOwedIncluded: Double
    var purchases: [CreditCardPurchase]
    var paymentsApplied: [CreditCardStatementPaymentAllocation]
    var statementPurchaseTotal: Double
    var paymentsAppliedTotal: Double
    var remainingDue: Double
    var totalOutstandingAfterStatement: Double
    var statusLabel: String

    var id: String {
        let components = Calendar.current.dateComponents([.year, .month], from: statementClosingDate)
        return "\(cardID.uuidString)-statement-\(components.year ?? 0)-\(components.month ?? 0)"
    }
}

// MARK: - Backup

struct WalletBackupMetadata: Codable, Hashable {
    var backupCreatedAt: Date
    var appName: String
    var appVersion: String?
    var backupSchemaVersion: Int
    var deviceName: String?
    var totalAccounts: Int
    var totalTransactions: Int
    var totalFutureItems: Int
    var totalRecurringItems: Int
    var totalInstallments: Int
    var totalCreditCards: Int
    var totalCreditCardPurchases: Int
    var totalCreditCardPayments: Int
    var totalPeopleDebts: Int
    var latestTransactionDate: Date?
}

enum BackupValidationSeverity: String, Codable, Hashable {
    case error
    case warning
    case info
}

struct BackupValidationIssue: Identifiable, Codable, Hashable {
    var id = UUID()
    var severity: BackupValidationSeverity
    var title: String
    var detail: String
    var recordID: UUID?
}

struct BackupValidationReport: Codable, Hashable {
    var issues: [BackupValidationIssue] = []

    var hasIssues: Bool {
        !issues.isEmpty
    }

    var errorCount: Int {
        issues.filter { $0.severity == .error }.count
    }

    var hasErrors: Bool {
        errorCount > 0
    }

    var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }

    var infoCount: Int {
        issues.filter { $0.severity == .info }.count
    }

    var summaryText: String {
        guard hasIssues else {
            return "No backup compatibility issues found."
        }

        if errorCount > 0 {
            if errorCount == 1 {
                return "1 blocking backup error found."
            }
            return "\(errorCount) blocking backup errors found."
        }

        if warningCount == 0 {
            if infoCount == 1 {
                return "1 backup review item found."
            }

            return "\(infoCount) backup review items found."
        }

        if warningCount == 1 {
            return "1 backup compatibility warning found."
        }

        return "\(warningCount) backup compatibility warnings found."
    }
}

struct WalletDataSnapshot: Codable, Hashable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int = WalletDataSnapshot.currentSchemaVersion
    var exportedAt: Date = Date()
    var appBuildInfo: String? = nil
    var backupMetadata: WalletBackupMetadata? = nil

    var accounts: [Account]
    var categories: [Category]
    var walletEvents: [WalletEvent]
    var merchantMemories: [MerchantMemory]
    var installmentPlans: [InstallmentPlan]
    var financialEvents: [FinancialEvent]
    var personDebts: [PersonDebt]
    var personDebtEntries: [PersonDebtEntry]
    var monthlyBudgets: [WalletMonthlyBudget]
    var historicalMonthlySummaries: [HistoricalMonthlySummaryEntry]
    var creditCards: [CreditCard]
    var creditCardPurchases: [CreditCardPurchase]
    var creditCardPayments: [CreditCardPayment]

    var monthlyLivingBurn: Double
    var runwaySafeBalanceTarget: Double
    var instaPayFeePercent: Double
    var instaPayMinimumFee: Double
    var instaPayMaximumFee: Double
    var displayName: String
    var appLanguage: AppLanguage
    var forecastHorizonMonths: Int
    var hideBalances: Bool
    var incomeMode: IncomeMode
    var salaryResumeDate: Date?

    init(
        schemaVersion: Int = WalletDataSnapshot.currentSchemaVersion,
        exportedAt: Date = Date(),
        appBuildInfo: String? = nil,
        backupMetadata: WalletBackupMetadata? = nil,
        accounts: [Account],
        categories: [Category],
        walletEvents: [WalletEvent],
        merchantMemories: [MerchantMemory] = [],
        installmentPlans: [InstallmentPlan],
        financialEvents: [FinancialEvent],
        personDebts: [PersonDebt],
        personDebtEntries: [PersonDebtEntry],
        monthlyBudgets: [WalletMonthlyBudget],
        historicalMonthlySummaries: [HistoricalMonthlySummaryEntry] = [],
        creditCards: [CreditCard] = [],
        creditCardPurchases: [CreditCardPurchase] = [],
        creditCardPayments: [CreditCardPayment] = [],
        monthlyLivingBurn: Double,
        runwaySafeBalanceTarget: Double = 0,
        instaPayFeePercent: Double,
        instaPayMinimumFee: Double,
        instaPayMaximumFee: Double,
        displayName: String = "",
        appLanguage: AppLanguage = .english,
        forecastHorizonMonths: Int = 12,
        hideBalances: Bool = false,
        incomeMode: IncomeMode = .unknown,
        salaryResumeDate: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.appBuildInfo = appBuildInfo
        self.backupMetadata = backupMetadata
        self.accounts = accounts
        self.categories = categories
        self.walletEvents = walletEvents
        self.merchantMemories = merchantMemories
        self.installmentPlans = installmentPlans
        self.financialEvents = financialEvents
        self.personDebts = personDebts
        self.personDebtEntries = personDebtEntries
        self.monthlyBudgets = monthlyBudgets
        self.historicalMonthlySummaries = historicalMonthlySummaries
        self.creditCards = creditCards
        self.creditCardPurchases = creditCardPurchases
        self.creditCardPayments = creditCardPayments
        self.monthlyLivingBurn = monthlyLivingBurn
        self.runwaySafeBalanceTarget = runwaySafeBalanceTarget
        self.instaPayFeePercent = instaPayFeePercent
        self.instaPayMinimumFee = instaPayMinimumFee
        self.instaPayMaximumFee = instaPayMaximumFee
        self.displayName = displayName
        self.appLanguage = appLanguage
        self.forecastHorizonMonths = forecastHorizonMonths
        self.hideBalances = hideBalances
        self.incomeMode = incomeMode
        self.salaryResumeDate = salaryResumeDate
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case exportedAt
        case appBuildInfo
        case backupMetadata
        case accounts
        case categories
        case walletEvents
        case merchantMemories
        case installmentPlans
        case financialEvents
        case personDebts
        case personDebtEntries
        case monthlyBudgets
        case historicalMonthlySummaries
        case creditCards
        case creditCardPurchases
        case creditCardPayments
        case monthlyLivingBurn
        case runwaySafeBalanceTarget
        case instaPayFeePercent
        case instaPayMinimumFee
        case instaPayMaximumFee
        case displayName
        case appLanguage
        case forecastHorizonMonths
        case hideBalances
        case incomeMode
        case salaryResumeDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? WalletDataSnapshot.currentSchemaVersion
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        appBuildInfo = try container.decodeIfPresent(String.self, forKey: .appBuildInfo)
        backupMetadata = try container.decodeIfPresent(WalletBackupMetadata.self, forKey: .backupMetadata)
        accounts = try container.decode([Account].self, forKey: .accounts)
        categories = try container.decode([Category].self, forKey: .categories)
        walletEvents = try container.decode([WalletEvent].self, forKey: .walletEvents)
        merchantMemories = try container.decodeIfPresent([MerchantMemory].self, forKey: .merchantMemories) ?? []
        installmentPlans = try container.decode([InstallmentPlan].self, forKey: .installmentPlans)
        financialEvents = try container.decode([FinancialEvent].self, forKey: .financialEvents)
        personDebts = try container.decodeIfPresent([PersonDebt].self, forKey: .personDebts) ?? []
        personDebtEntries = try container.decodeIfPresent([PersonDebtEntry].self, forKey: .personDebtEntries) ?? []
        monthlyBudgets = try container.decodeIfPresent([WalletMonthlyBudget].self, forKey: .monthlyBudgets) ?? []
        historicalMonthlySummaries = try container.decodeIfPresent([HistoricalMonthlySummaryEntry].self, forKey: .historicalMonthlySummaries) ?? []
        creditCards = try container.decodeIfPresent([CreditCard].self, forKey: .creditCards) ?? []
        creditCardPurchases = try container.decodeIfPresent([CreditCardPurchase].self, forKey: .creditCardPurchases) ?? []
        creditCardPayments = try container.decodeIfPresent([CreditCardPayment].self, forKey: .creditCardPayments) ?? []
        monthlyLivingBurn = try container.decode(Double.self, forKey: .monthlyLivingBurn)
        runwaySafeBalanceTarget = try container.decodeIfPresent(Double.self, forKey: .runwaySafeBalanceTarget) ?? 0
        instaPayFeePercent = try container.decodeIfPresent(Double.self, forKey: .instaPayFeePercent) ?? 0.1
        instaPayMinimumFee = try container.decodeIfPresent(Double.self, forKey: .instaPayMinimumFee) ?? 0.5
        instaPayMaximumFee = try container.decodeIfPresent(Double.self, forKey: .instaPayMaximumFee) ?? 20
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        appLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .appLanguage) ?? .english
        forecastHorizonMonths = try container.decodeIfPresent(Int.self, forKey: .forecastHorizonMonths) ?? 12
        hideBalances = try container.decodeIfPresent(Bool.self, forKey: .hideBalances) ?? false
        incomeMode = try container.decodeIfPresent(IncomeMode.self, forKey: .incomeMode) ?? .unknown
        salaryResumeDate = try container.decodeIfPresent(Date.self, forKey: .salaryResumeDate)
    }
}

enum WalletBackupError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case invalidData(String)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "Unsupported backup schema version: \(version)."
        case .invalidData(let message):
            return message
        case .decodeFailed:
            return "The selected file is not a valid wallet backup."
        }
    }
}

// MARK: - iCloud Sync

enum WalletICloudAvailability: String, Codable, CaseIterable, Identifiable {
    case unknown = "Unknown"
    case available = "Available"
    case noAccount = "Not Signed In"
    case restricted = "Restricted"
    case couldNotDetermine = "Could Not Determine"
    case capabilityNotEnabled = "Capability Not Enabled"
    case error = "Error"

    var id: String { rawValue }
}

struct WalletICloudRemoteMetadata: Codable, Hashable {
    var remoteUpdatedAt: Date?
    var schemaVersion: Int?
    var deviceName: String?
    var appBuildInfo: String?
}

enum WalletICloudConflictState: String, Codable, CaseIterable, Identifiable {
    case none = "No Conflict"
    case remoteNewer = "Remote Newer"
    case localNewer = "Local Newer"
    case conflict = "Conflict"

    var id: String { rawValue }
}

enum WalletICloudSyncError: LocalizedError {
    case notAvailable(String)
    case remoteSnapshotMissing
    case missingSnapshotData
    case invalidRemoteSnapshot(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable(let message):
            return message
        case .remoteSnapshotMissing:
            return "No wallet snapshot was found in iCloud."
        case .missingSnapshotData:
            return "The iCloud wallet snapshot is missing backup data."
        case .invalidRemoteSnapshot(let message):
            return message
        }
    }
}
