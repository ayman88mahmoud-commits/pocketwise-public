import Foundation

// MARK: - Sample Wallet Data

struct SampleWalletData {

    // MARK: - Date Helper

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - Accounts

    static let accounts: [Account] = [
        Account(name: "Cash", balance: 15_000, type: .cash),
        Account(name: "NBE", balance: 120_000, type: .bank),
        Account(name: "CIB", balance: 85_000, type: .bank)
    ]

    // MARK: - Categories

    static let categories: [Category] = [
        Category(
            name: "Fixed Obligations",
            subcategories: [
                "Rent",
                "Taj City",
                "Valu",
                "Club Installments",
                "Insurance"
            ]
        ),

        Category(
            name: "Household",
            subcategories: [
                "Home Essentials",
                "Maid"
            ]
        ),

        Category(
            name: "Groceries",
            subcategories: [
                "Supermarket",
                "Instashop",
                "Mini Market",
                "Butcher"
            ]
        ),

        Category(
            name: "Dining & Delivery",
            subcategories: [
                "Talabat",
                "Restaurants",
                "Cafe"
            ]
        ),

        Category(
            name: "Kids",
            subcategories: [
                "Nursery",
                "Swimming",
                "Ballet",
                "Kick Boxing",
                "Toys",
                "Lessons"
            ]
        ),

        Category(
            name: "Health & Medical",
            subcategories: [
                "Pharmacy",
                "Dentist",
                "Lab Tests",
                "Doctors"
            ]
        ),

        Category(
            name: "Car & Transport",
            subcategories: [
                "Fuel",
                "Uber",
                "Maintenance"
            ]
        ),

        Category(
            name: "Digital & Subscriptions",
            subcategories: [
                "Apple",
                "Netflix",
                "Spotify",
                "ChatGPT",
                "Claude",
                "Prime",
                "OSN",
                "Disney",
                "Watchit",
                "WE",
                "Etisalat"
            ]
        ),

        Category(
            name: "Shopping",
            subcategories: [
                "Amazon",
                "Temu",
                "Clothes",
                "Gifts"
            ]
        ),

        Category(
            name: "Family Support",
            subcategories: [
                "Baba",
                "Mona",
                "Farah",
                "Ahmed",
                "M.Fell"
            ]
        ),

        Category(
            name: "Personal",
            subcategories: [
                "Wife Pocket Money",
                "Cigarettes",
                "Personal Spending"
            ]
        ),

        Category(
            name: "Banking & Fees",
            subcategories: [
                "InstaPay Fee",
                "Transfer Fee",
                "Card Fee"
            ]
        )
    ]

    // MARK: - Wallet Events
    // These are the daily user-facing buttons/events.

    static let walletEvents: [WalletEvent] = [
        WalletEvent(
            name: "Fuel",
            categoryName: "Car & Transport",
            subCategoryName: "Fuel",
            defaultAccountName: "CIB",
            isFavorite: true
        ),

        WalletEvent(
            name: "Uber",
            categoryName: "Car & Transport",
            subCategoryName: "Uber",
            defaultAccountName: "CIB",
            isFavorite: true
        ),

        WalletEvent(
            name: "Talabat",
            categoryName: "Dining & Delivery",
            subCategoryName: "Talabat",
            defaultAccountName: "CIB",
            isFavorite: true
        ),

        WalletEvent(
            name: "Supermarket",
            categoryName: "Groceries",
            subCategoryName: "Supermarket",
            defaultAccountName: "CIB",
            isFavorite: true
        ),

        WalletEvent(
            name: "Pharmacy",
            categoryName: "Health & Medical",
            subCategoryName: "Pharmacy",
            defaultAccountName: "Cash",
            isFavorite: true
        ),

        WalletEvent(
            name: "Amazon",
            categoryName: "Shopping",
            subCategoryName: "Amazon",
            defaultAccountName: "CIB",
            isFavorite: true
        ),

        WalletEvent(
            name: "Nursery",
            categoryName: "Kids",
            subCategoryName: "Nursery",
            defaultAccountName: "CIB",
            isFavorite: false
        ),

        WalletEvent(
            name: "Home Essentials",
            categoryName: "Household",
            subCategoryName: "Home Essentials",
            defaultAccountName: "CIB",
            isFavorite: true
        )
    ]

    // MARK: - Installment Plans

    static let installmentPlans: [InstallmentPlan] = [
        InstallmentPlan(
            purchaseName: "Laptop",
            totalAmount: 30_000,
            installmentCount: 12,
            firstDueDate: date(2026, 7, 1),
            accountName: "CIB",
            categoryName: "Shopping",
            subCategoryName: "Amazon",
            paymentMethodName: "Valu",
            note: "Sample Valu installment purchase"
        )
    ]

    // MARK: - Financial Events
    // One unified stream for expenses, income, obligations, installments, and expected expenses.

    static let financialEvents: [FinancialEvent] = [

        // MARK: Paid Daily Expenses

        FinancialEvent(
            type: .expense,
            status: .paid,
            title: "Fuel",
            amount: 1_200,
            date: date(2026, 6, 3),
            accountName: "CIB",
            walletEventName: "Fuel",
            categoryName: "Car & Transport",
            subCategoryName: "Fuel",
            note: "SRT fuel"
        ),

        FinancialEvent(
            type: .expense,
            status: .paid,
            title: "Talabat",
            amount: 650,
            date: date(2026, 6, 4),
            accountName: "CIB",
            walletEventName: "Talabat",
            categoryName: "Dining & Delivery",
            subCategoryName: "Talabat"
        ),

        FinancialEvent(
            type: .expense,
            status: .paid,
            title: "Pharmacy",
            amount: 420,
            date: date(2026, 6, 5),
            accountName: "Cash",
            walletEventName: "Pharmacy",
            categoryName: "Health & Medical",
            subCategoryName: "Pharmacy"
        ),

        FinancialEvent(
            type: .expense,
            status: .paid,
            title: "Supermarket",
            amount: 1_850,
            date: date(2026, 6, 6),
            accountName: "CIB",
            walletEventName: "Supermarket",
            categoryName: "Groceries",
            subCategoryName: "Supermarket"
        ),

        // MARK: Known Obligations

        FinancialEvent(
            type: .obligation,
            status: .unpaid,
            title: "Nursery",
            amount: 4_500,
            date: date(2026, 6, 10),
            accountName: "CIB",
            walletEventName: "Nursery",
            categoryName: "Kids",
            subCategoryName: "Nursery",
            repeatRule: .monthly
        ),

        FinancialEvent(
            type: .obligation,
            status: .unpaid,
            title: "Rent",
            amount: 10_000,
            date: date(2026, 6, 15),
            accountName: "NBE",
            categoryName: "Fixed Obligations",
            subCategoryName: "Rent",
            repeatRule: .monthly
        ),

        FinancialEvent(
            type: .obligation,
            status: .unpaid,
            title: "Club Installment",
            amount: 2_000,
            date: date(2026, 6, 20),
            accountName: "CIB",
            categoryName: "Fixed Obligations",
            subCategoryName: "Club Installments",
            repeatRule: .monthly
        ),

        // MARK: Installment Generated Events

        FinancialEvent(
            type: .installment,
            status: .unpaid,
            title: "Valu - Laptop",
            amount: 2_500,
            date: date(2026, 7, 1),
            accountName: "CIB",
            categoryName: "Fixed Obligations",
            subCategoryName: "Valu",
            repeatRule: .none,
            note: "Generated from sample installment plan"
        ),

        FinancialEvent(
            type: .installment,
            status: .unpaid,
            title: "Valu - Laptop",
            amount: 2_500,
            date: date(2026, 8, 1),
            accountName: "CIB",
            categoryName: "Fixed Obligations",
            subCategoryName: "Valu",
            repeatRule: .none,
            note: "Generated from sample installment plan"
        ),

        // MARK: Expected Expenses

        FinancialEvent(
            type: .expectedExpense,
            status: .expected,
            title: "Vacation Spending",
            amount: 25_000,
            date: date(2026, 8, 15),
            accountName: nil,
            categoryName: "Personal",
            subCategoryName: "Personal Spending",
            confidence: .medium,
            note: "Estimated vacation spending"
        ),

        FinancialEvent(
            type: .expectedExpense,
            status: .expected,
            title: "Insurance Renewal",
            amount: 22_500,
            date: date(2026, 9, 1),
            accountName: nil,
            categoryName: "Fixed Obligations",
            subCategoryName: "Insurance",
            confidence: .high,
            note: "Expected annual insurance renewal"
        ),

        // MARK: Income

        FinancialEvent(
            type: .income,
            status: .expected,
            title: "Expected Salary",
            amount: 85_000,
            date: date(2026, 10, 15),
            accountName: "CIB",
            categoryName: nil,
            subCategoryName: nil,
            confidence: .high,
            note: "First expected income after vacation"
        )
    ]

    // MARK: - Quick Access

    static var favoriteEvents: [WalletEvent] {
        walletEvents.filter { $0.isFavorite && $0.isActive }
    }

    static var availableCash: Double {
        accounts
            .filter { $0.isActive }
            .map { $0.balance }
            .reduce(0, +)
    }

    static var recentEvents: [FinancialEvent] {
        financialEvents
            .filter { $0.status == .paid }
            .sorted { $0.date > $1.date }
    }

    static var upcomingEvents: [FinancialEvent] {
        financialEvents
            .filter {
                $0.status == .unpaid ||
                $0.status == .expected ||
                $0.status == .planned
            }
            .sorted { $0.date < $1.date }
    }
}
