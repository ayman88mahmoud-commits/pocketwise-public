import Foundation

enum BudgetDateHelper {
    static func startOfMonth(for date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }

    static func addMonths(_ value: Int, to date: Date) -> Date {
        let start = startOfMonth(for: date)
        return Calendar.current.date(byAdding: .month, value: value, to: start) ?? start
    }

    static func date(year: Int, month: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components)
    }

    static func monthKey(for date: Date) -> (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return (components.year ?? 2026, components.month ?? 1)
    }

    static func monthID(for date: Date) -> String {
        let key = monthKey(for: date)
        return "\(key.year)-\(key.month)"
    }

    static func months(from start: Date, through end: Date) -> [Date] {
        let normalizedStart = startOfMonth(for: start)
        let normalizedEnd = startOfMonth(for: end)
        if normalizedEnd < normalizedStart {
            return [normalizedStart]
        }

        var result: [Date] = []
        var current = normalizedStart
        while current <= normalizedEnd && result.count < 36 {
            result.append(current)
            current = addMonths(1, to: current)
        }
        return result
    }

    static func monthRange(year: Int, month: Int) -> (start: Date, end: Date)? {
        guard let start = date(year: year, month: month),
              let end = Calendar.current.date(byAdding: .month, value: 1, to: start) else {
            return nil
        }
        return (start, end)
    }

    static func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
