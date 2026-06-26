import Foundation

struct BudgetCellSelection: Identifiable {
    let id = UUID()
    let date: Date
    let year: Int
    let month: Int
    let categoryName: String
    let plannedAmount: Double
    let paidActualAmount: Double
    let knownUpcomingAmount: Double
    let effectiveProjectedAmount: Double

    var remainingAfterKnown: Double {
        plannedAmount - paidActualAmount - knownUpcomingAmount
    }
}

enum BudgetGridApplyRoute: Identifiable {
    case copyToFuture(selection: BudgetCellSelection, visibleMonths: [Date])
    case categoryAcrossMonths(categoryName: String, anchorMonth: Date, visibleMonths: [Date])

    var id: String {
        switch self {
        case let .copyToFuture(selection, _):
            return "copy-\(selection.id.uuidString)"
        case let .categoryAcrossMonths(categoryName, anchorMonth, _):
            return "category-\(categoryName)-\(anchorMonth.timeIntervalSinceReferenceDate)"
        }
    }
}

enum BudgetGridBulkActionType: String {
    case useCommittedAsBudget
    case applyToFutureMonths
    case applyToSelectedMonths
}

struct BudgetMonthSelection: Identifiable {
    let id = UUID()
    let date: Date
}

struct CategoryUpcomingSelection: Identifiable {
    let id = UUID()
    let monthDate: Date
    let year: Int
    let month: Int
    let categoryName: String
    let displayedAmount: Double
}

enum BudgetCategoryAction: Hashable, Identifiable {
    case planned(monthDate: Date, categoryName: String)
    case transactions(categoryName: String, monthDate: Date)

    var id: String {
        switch self {
        case let .planned(monthDate, categoryName):
            return "planned-\(categoryName)-\(monthDate.timeIntervalSinceReferenceDate)"
        case let .transactions(categoryName, monthDate):
            return "transactions-\(categoryName)-\(monthDate.timeIntervalSinceReferenceDate)"
        }
    }
}

struct BudgetCommittedMonthSelection: Identifiable {
    let id = UUID()
    let monthDate: Date
    let year: Int
    let month: Int
    let displayedAmount: Double
}
