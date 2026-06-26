import Foundation

enum WalletSyncRecordEntity: String, CaseIterable, Codable, Hashable {
    case financialEvent = "FinancialEvent"
    case account = "Account"
    case category = "Category"
    case walletEvent = "WalletEvent"
    case merchantMemory = "MerchantMemory"
    case installmentPlan = "InstallmentPlan"
    case monthlyBudget = "MonthlyBudget"
    case personDebt = "PersonDebt"
    case personDebtEntry = "PersonDebtEntry"
    case creditCard = "CreditCard"
    case creditCardPurchase = "CreditCardPurchase"
    case creditCardPayment = "CreditCardPayment"
    case historicalMonthlySummary = "HistoricalMonthlySummary"
    case householdSettings = "HouseholdSettings"

    var recordNamePrefix: String {
        rawValue
    }

    func recordName(for id: UUID) -> String {
        "\(recordNamePrefix)_\(id.uuidString.lowercased())"
    }
}

struct WalletSyncRecordIdentity: Codable, Hashable {
    var entity: WalletSyncRecordEntity
    var id: UUID

    var recordName: String {
        entity.recordName(for: id)
    }

    init(entity: WalletSyncRecordEntity, id: UUID) {
        self.entity = entity
        self.id = id
    }
}
