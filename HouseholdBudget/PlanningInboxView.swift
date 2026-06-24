import SwiftUI

struct PlanningInboxView: View {

    @EnvironmentObject private var store: WalletStore
    @State private var rangeStartMonth = PlanningInboxView.startOfMonth(for: Date())
    @State private var rangeEndMonth = PlanningInboxView.startOfMonth(for: Date())

    init(rangeStartMonth: Date = Date(), rangeEndMonth: Date = Date()) {
        _rangeStartMonth = State(initialValue: Self.startOfMonth(for: rangeStartMonth))
        _rangeEndMonth = State(initialValue: Self.startOfMonth(for: rangeEndMonth))
    }

    private enum IssueSeverity: String, CaseIterable, Identifiable {
        case high
        case medium
        case low

        var id: String { rawValue }
    }

    private struct PlanningIssue: Identifiable {
        let id = UUID()
        let severity: IssueSeverity
        let title: String
        let detail: String
        let date: Date?
        let amount: Double?
        let destination: PlanningIssueDestination?
    }

    private enum PlanningIssueDestination {
        case transaction(FinancialEvent)
        case duplicateCandidates([FinancialEvent])
        case recurringSeries(FinancialEvent)
        case monthlyBudget(Date)
        case obligations
    }

    private var issues: [PlanningIssue] {
        var result: [PlanningIssue] = []
        result.append(contentsOf: missingAccountIssues)
        result.append(contentsOf: uncategorizedIssues)
        result.append(contentsOf: futureNotPlannedIssues)
        result.append(contentsOf: suspiciousAmountIssues)
        result.append(contentsOf: duplicateIssues)
        result.append(contentsOf: recurringReviewIssues)
        result.append(contentsOf: monthlyObservationIssues)
        return result
    }

    private var selectedRange: (start: Date, end: Date) {
        let start = Self.startOfMonth(for: rangeStartMonth)
        let end = Self.endOfMonth(for: rangeEndMonth)

        if start <= end {
            return (start, end)
        }

        return (Self.startOfMonth(for: rangeEndMonth), Self.endOfMonth(for: rangeStartMonth))
    }

    private var selectedMonths: [Date] {
        let range = selectedRange
        var months: [Date] = []
        var current = Self.startOfMonth(for: range.start)
        let last = Self.startOfMonth(for: range.end)

        while current <= last {
            months.append(current)
            guard let next = Calendar.current.date(byAdding: .month, value: 1, to: current) else {
                break
            }
            current = next
        }

        return months
    }

    private var scopedEvents: [FinancialEvent] {
        let range = selectedRange
        return store.activeFinancialEvents.filter { event in
            event.date >= range.start && event.date <= range.end
        }
    }

    private var missingAccountIssues: [PlanningIssue] {
        scopedEvents.compactMap { event in
            guard event.status != .cancelled,
                  event.status != .skipped,
                  event.type != .transfer,
                  event.accountName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false else {
                return nil
            }

            return PlanningIssue(
                severity: .high,
                title: store.appLanguage == .arabicEgyptian ? "حساب ناقص" : "Missing account",
                detail: event.title,
                date: event.date,
                amount: event.amount,
                destination: .transaction(event)
            )
        }
    }

    private var uncategorizedIssues: [PlanningIssue] {
        scopedEvents.compactMap { event in
            guard event.status != .cancelled,
                  event.status != .skipped,
                  isBudgetRelevant(event),
                  event.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false else {
                return nil
            }

            return PlanningIssue(
                severity: .high,
                title: store.appLanguage == .arabicEgyptian ? "مصروف من غير تصنيف" : "Uncategorized spending",
                detail: event.title,
                date: event.date,
                amount: event.amount,
                destination: .transaction(event)
            )
        }
    }

    private var futureNotPlannedIssues: [PlanningIssue] {
        scopedEvents.compactMap { event in
            guard event.status != .paid,
                  event.status != .cancelled,
                  event.status != .skipped,
                  isBudgetRelevant(event),
                  let categoryName = event.categoryName,
                  !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  plannedAmount(for: event) <= 0 else {
                return nil
            }

            return PlanningIssue(
                severity: .medium,
                title: store.appLanguage == .arabicEgyptian ? "مصروف جاي مش متخطط" : "Upcoming not planned",
                detail: "\(event.title) • \(categoryName)",
                date: event.date,
                amount: event.recurringAmount(for: event.date),
                destination: .transaction(event)
            )
        }
    }

    private var suspiciousAmountIssues: [PlanningIssue] {
        scopedEvents.compactMap { event in
            guard event.amount <= 0 else {
                return nil
            }

            return PlanningIssue(
                severity: .high,
                title: store.appLanguage == .arabicEgyptian ? "مبلغ محتاج مراجعة" : "Suspicious amount",
                detail: event.title,
                date: event.date,
                amount: event.amount,
                destination: .transaction(event)
            )
        }
    }

    private var duplicateIssues: [PlanningIssue] {
        let activeEvents = scopedEvents.filter {
            $0.status != .cancelled && $0.status != .skipped
        }

        let groupedEvents = Dictionary(grouping: activeEvents) { event in
            duplicateKey(for: event)
        }

        return groupedEvents.values.compactMap { events in
            let sortedEvents = events.sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date < rhs.date
                }

                return lhs.createdAt < rhs.createdAt
            }

            let reportableEvents = reportableDuplicateCandidates(from: sortedEvents)

            guard reportableEvents.count > 1,
                  let first = reportableEvents.first else {
                return nil
            }

            return PlanningIssue(
                severity: .medium,
                title: store.appLanguage == .arabicEgyptian ? "احتمال تكرار" : "Possible duplicate",
                detail: "\(first.title) • \(reportableEvents.count)x",
                date: first.date,
                amount: first.amount,
                destination: .duplicateCandidates(reportableEvents)
            )
        }
    }

    private var recurringReviewIssues: [PlanningIssue] {
        scopedEvents.compactMap { event in
            guard event.repeatRule != .none,
                  event.status != .cancelled,
                  event.status != .skipped,
                  event.effectiveRecurringEndKind == .never else {
                return nil
            }

            return PlanningIssue(
                severity: .low,
                title: store.appLanguage == .arabicEgyptian ? "دفع متكرر من غير نهاية" : "Recurring with no end",
                detail: event.title,
                date: event.date,
                amount: event.amount,
                destination: .recurringSeries(event)
            )
        }
    }

    private var monthlyObservationIssues: [PlanningIssue] {
        selectedMonths.flatMap { monthDate in
            [
                missingIncomeIssue(for: monthDate),
                budgetObservationIssue(for: monthDate)
            ].compactMap { $0 }
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.appLanguage == .arabicEgyptian ? "قائمة مراجعة بتساعدك تلم أي حاجة ممكن تلخبط التخطيط." : "A read-only review list for items that may weaken planning accuracy.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(store.appLanguage == .arabicEgyptian ? "مفيش تصليح تلقائي هنا، ومفيش تغيير في الأرصدة." : "Nothing is auto-fixed here, and balances do not change.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section(store.appLanguage == .arabicEgyptian ? "نطاق الشهور" : "Month range") {
                monthRangeSelector
            }

            ForEach(IssueSeverity.allCases) { severity in
                issueSection(severity)
            }
        }
        .navigationTitle(AppText.planCheck(store.appLanguage))
    }

    private var monthRangeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            monthStepper(
                title: store.appLanguage == .arabicEgyptian ? "من" : "From",
                month: rangeStartMonth,
                movePrevious: { moveRangeStart(by: -1) },
                moveNext: { moveRangeStart(by: 1) }
            )

            monthStepper(
                title: store.appLanguage == .arabicEgyptian ? "إلى" : "To",
                month: rangeEndMonth,
                movePrevious: { moveRangeEnd(by: -1) },
                moveNext: { moveRangeEnd(by: 1) }
            )

            Button {
                let currentMonth = Self.startOfMonth(for: Date())
                rangeStartMonth = currentMonth
                rangeEndMonth = currentMonth
            } label: {
                Text(AppText.thisMonth(store.appLanguage))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text(rangeSummaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func monthStepper(
        title: String,
        month: Date,
        movePrevious: @escaping () -> Void,
        moveNext: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    movePrevious()
                } label: {
                    Text(store.appLanguage == .arabicEgyptian ? "السابق" : "Previous")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Text(formatMonth(month))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(minWidth: 120)

                Button {
                    moveNext()
                } label: {
                    Text(store.appLanguage == .arabicEgyptian ? "التالي" : "Next")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func issueSection(_ severity: IssueSeverity) -> some View {
        let sectionIssues = issues.filter { $0.severity == severity }

        return Section(severityTitle(severity)) {
            if sectionIssues.isEmpty {
                Text(emptyText(for: severity))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sectionIssues) { issue in
                    issueRow(issue)
                }
            }
        }
    }

    @ViewBuilder
    private func issueRow(_ issue: PlanningIssue) -> some View {
        if let destination = issue.destination {
            NavigationLink {
                issueDestination(destination)
            } label: {
                issueRowContent(issue)
            }
        } else {
            issueRowContent(issue)
        }
    }

    @ViewBuilder
    private func issueDestination(_ destination: PlanningIssueDestination) -> some View {
        switch destination {
        case .transaction(let event):
            TransactionDetailView(event: event, isPresentedModally: false)
        case .duplicateCandidates(let events):
            DuplicateCandidatesView(events: events)
        case .recurringSeries(let event):
            RecurringPaymentEditorView(event: event)
        case .monthlyBudget(let monthDate):
            MonthlyBudgetView(initialMonthDate: monthDate)
        case .obligations:
            ObligationsCenterView()
        }
    }

    private func issueRowContent(_ issue: PlanningIssue) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName(for: issue.severity))
                .foregroundStyle(color(for: issue.severity))
                .frame(width: 28, height: 28)
                .background(color(for: issue.severity).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text(issue.title)
                    .font(.headline)

                Text(issue.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    if let date = issue.date {
                        Text(formatDate(date))
                    }

                    if let amount = issue.amount {
                        Text(store.displayCurrency(amount))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func isBudgetRelevant(_ event: FinancialEvent) -> Bool {
        switch event.type {
        case .expense, .obligation, .expectedExpense, .installment:
            return true
        case .income, .transfer:
            return false
        }
    }

    private func plannedAmount(for event: FinancialEvent) -> Double {
        guard let categoryName = event.categoryName else {
            return 0
        }

        let components = Calendar.current.dateComponents([.year, .month], from: event.date)

        guard let year = components.year,
              let month = components.month,
              let budget = store.monthlyBudget(year: year, month: month) else {
            return 0
        }

        return budget.items.first {
            $0.categoryName.caseInsensitiveCompare(categoryName) == .orderedSame
        }?.plannedAmount ?? 0
    }

    private func missingIncomeIssue(for monthDate: Date) -> PlanningIssue? {
        let monthKey = monthComponents(for: monthDate)
        let hasIncome = store.activeFinancialEvents.contains { event in
            guard event.type == .income,
                  event.status != .cancelled,
                  event.status != .skipped else {
                return false
            }

            let eventKey = monthComponents(for: event.date)
            return eventKey.year == monthKey.year && eventKey.month == monthKey.month
        }

        guard !hasIncome else {
            return nil
        }

        return PlanningIssue(
            severity: .medium,
            title: store.appLanguage == .arabicEgyptian ? "مفيش دخل متسجل" : "No income entered",
            detail: store.appLanguage == .arabicEgyptian ? "مفيش دخل متسجل في \(formatMonth(monthDate))." : "No income entered for \(formatMonth(monthDate)).",
            date: monthDate,
            amount: nil,
            destination: .obligations
        )
    }

    private func budgetObservationIssue(for monthDate: Date) -> PlanningIssue? {
        let monthKey = monthComponents(for: monthDate)

        guard let budget = store.monthlyBudget(year: monthKey.year, month: monthKey.month) else {
            return PlanningIssue(
                severity: .medium,
                title: store.appLanguage == .arabicEgyptian ? "مفيش ميزانية متسجلة" : "No budget entered",
                detail: store.appLanguage == .arabicEgyptian ? "مفيش ميزانية متسجلة في \(formatMonth(monthDate))." : "No budget entered for \(formatMonth(monthDate)).",
                date: monthDate,
                amount: nil,
                destination: .monthlyBudget(monthDate)
            )
        }

        let plannedByCategory = Dictionary(uniqueKeysWithValues: budget.items.map { item in
            (item.categoryName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), item.plannedAmount)
        })

        let mainBudgetCategories = store.activeCategories
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let missingCategoryCount = mainBudgetCategories.filter { categoryName in
            let key = categoryName.lowercased()
            return (plannedByCategory[key] ?? 0) <= 0
        }.count

        if budget.items.isEmpty || budget.items.allSatisfy({ $0.plannedAmount <= 0 }) {
            return PlanningIssue(
                severity: .medium,
                title: store.appLanguage == .arabicEgyptian ? "مفيش ميزانية متسجلة" : "No budget entered",
                detail: store.appLanguage == .arabicEgyptian ? "مفيش مبالغ مخططة في \(formatMonth(monthDate))." : "No planned amounts entered for \(formatMonth(monthDate)).",
                date: monthDate,
                amount: nil,
                destination: .monthlyBudget(monthDate)
            )
        }

        guard missingCategoryCount > 0 else {
            return nil
        }

        return PlanningIssue(
            severity: .low,
            title: store.appLanguage == .arabicEgyptian ? "تصنيفات من غير ميزانية" : "Some categories have no planned budget",
            detail: store.appLanguage == .arabicEgyptian ? "\(missingCategoryCount) تصنيفات أساسية من غير مبلغ مخطط في \(formatMonth(monthDate))." : "\(missingCategoryCount) main categories have no planned budget in \(formatMonth(monthDate)).",
            date: monthDate,
            amount: nil,
            destination: .monthlyBudget(monthDate)
        )
    }

    private func monthComponents(for date: Date) -> (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return (components.year ?? 0, components.month ?? 0)
    }

    private var rangeSummaryText: String {
        let months = selectedMonths.count
        if months == 1 {
            return store.appLanguage == .arabicEgyptian ? "المراجعة للشهر المختار فقط." : "Reviewing the selected month only."
        }

        return store.appLanguage == .arabicEgyptian ? "المراجعة على \(months) شهور." : "Reviewing \(months) months."
    }

    private func moveRangeStart(by value: Int) {
        rangeStartMonth = Self.addMonths(value, to: rangeStartMonth)
    }

    private func moveRangeEnd(by value: Int) {
        rangeEndMonth = Self.addMonths(value, to: rangeEndMonth)
    }

    private func duplicateKey(for event: FinancialEvent) -> String {
        let day = Calendar.current.startOfDay(for: event.date).timeIntervalSince1970
        let normalizedTitle = event.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(event.type.rawValue)-\(event.amount)-\(day)-\(normalizedTitle)"
    }

    private func reportableDuplicateCandidates(from events: [FinancialEvent]) -> [FinancialEvent] {
        let linkedPaidOccurrenceSourceIDs = Set(
            events.compactMap { event -> UUID? in
                guard event.status == .paid else {
                    return nil
                }

                return event.sourceRecurringEventID
            }
        )

        return events.filter { event in
            let isRecurringTemplateWithLinkedPaidOccurrence =
                event.repeatRule != .none &&
                linkedPaidOccurrenceSourceIDs.contains(event.id)

            return !isRecurringTemplateWithLinkedPaidOccurrence
        }
    }

    private func severityTitle(_ severity: IssueSeverity) -> String {
        switch severity {
        case .high:
            return store.appLanguage == .arabicEgyptian ? "عالي" : "High"
        case .medium:
            return store.appLanguage == .arabicEgyptian ? "متوسط" : "Medium"
        case .low:
            return store.appLanguage == .arabicEgyptian ? "بسيط" : "Low"
        }
    }

    private func emptyText(for severity: IssueSeverity) -> String {
        switch severity {
        case .high:
            return store.appLanguage == .arabicEgyptian ? "مفيش مشاكل عالية." : "No high-priority issues."
        case .medium:
            return store.appLanguage == .arabicEgyptian ? "مفيش حاجات متوسطة." : "No medium-priority issues."
        case .low:
            return store.appLanguage == .arabicEgyptian ? "مفيش ملاحظات بسيطة." : "No low-priority notes."
        }
    }

    private func iconName(for severity: IssueSeverity) -> String {
        switch severity {
        case .high:
            return "exclamationmark.triangle.fill"
        case .medium:
            return "exclamationmark.circle.fill"
        case .low:
            return "info.circle.fill"
        }
    }

    private func color(for severity: IssueSeverity) -> Color {
        switch severity {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .blue
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private static func startOfMonth(for date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }

    private static func endOfMonth(for date: Date) -> Date {
        let start = startOfMonth(for: date)
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start
        return Calendar.current.date(byAdding: .second, value: -1, to: nextMonth) ?? start
    }

    private static func addMonths(_ value: Int, to date: Date) -> Date {
        let start = startOfMonth(for: date)
        let newDate = Calendar.current.date(byAdding: .month, value: value, to: start) ?? start
        return startOfMonth(for: newDate)
    }
}

private struct DuplicateCandidatesView: View {
    @EnvironmentObject private var store: WalletStore
    let events: [FinancialEvent]

    private var sortedEvents: [FinancialEvent] {
        events.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date < rhs.date
            }

            return lhs.createdAt < rhs.createdAt
        }
    }

    private var firstEvent: FinancialEvent? {
        sortedEvents.first
    }

    var body: some View {
        List {
            Section {
                Text(store.appLanguage == .arabicEgyptian ? "دي قائمة قراءة فقط للعمليات اللي شكلها متكرر. افتح أي عملية للتفاصيل، ومفيش دمج أو حذف تلقائي هنا." : "This is a read-only list of transactions that look duplicated. Open any transaction for details; nothing is merged or deleted here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let firstEvent {
                Section(store.appLanguage == .arabicEgyptian ? "تفاصيل مشتركة" : "Shared details") {
                    detailRow(
                        title: store.appLanguage == .arabicEgyptian ? "الاسم" : "Name",
                        value: firstEvent.title
                    )
                    detailRow(
                        title: store.appLanguage == .arabicEgyptian ? "النوع" : "Type",
                        value: firstEvent.type.rawValue
                    )
                    detailRow(
                        title: store.appLanguage == .arabicEgyptian ? "التاريخ" : "Date",
                        value: formatDate(firstEvent.date)
                    )
                    detailRow(
                        title: store.appLanguage == .arabicEgyptian ? "المبلغ" : "Amount",
                        value: store.displayCurrency(firstEvent.amount)
                    )

                    if let categoryName = firstEvent.categoryName,
                       !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        detailRow(
                            title: store.appLanguage == .arabicEgyptian ? "التصنيف" : "Category",
                            value: categoryName
                        )
                    }
                }
            }

            Section(store.appLanguage == .arabicEgyptian ? "العمليات المتطابقة" : "Matching transactions") {
                ForEach(sortedEvents) { event in
                    NavigationLink {
                        TransactionDetailView(event: event, isPresentedModally: false)
                    } label: {
                        candidateRow(event)
                    }
                }
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "احتمال تكرار" : "Possible duplicate")
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 16)

            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func candidateRow(_ event: FinancialEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.title)
                .font(.headline)

            HStack(spacing: 8) {
                Text(formatDate(event.date))
                Text(store.displayCurrency(event.amount))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(statusText(for: event))
                Text(sourceText(for: event))

                if let accountName = event.accountName,
                   !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(accountName)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private func statusText(for event: FinancialEvent) -> String {
        if store.appLanguage == .arabicEgyptian {
            switch event.status {
            case .paid:
                return "الحالة: مدفوع"
            case .unpaid:
                return "الحالة: غير مدفوع"
            case .planned:
                return "الحالة: مخطط"
            case .expected:
                return "الحالة: متوقع"
            case .skipped:
                return "الحالة: متخطي"
            case .cancelled:
                return "الحالة: ملغي"
            }
        }

        return "Status: \(event.status.rawValue)"
    }

    private func sourceText(for event: FinancialEvent) -> String {
        if event.repeatRule != .none && event.sourceRecurringEventID == nil {
            return store.appLanguage == .arabicEgyptian ? "المصدر: قالب متكرر" : "Source: recurring template"
        }

        if event.status == .paid && event.sourceRecurringEventID != nil {
            return store.appLanguage == .arabicEgyptian ? "المصدر: دفعة متكررة مدفوعة" : "Source: paid occurrence"
        }

        return store.appLanguage == .arabicEgyptian ? "المصدر: بند منفرد" : "Source: one-off item"
    }
}

enum PlanCheckState {
    case insufficientData
    case needsReview
    case complete
}

struct PlanCheckSummary {
    let state: PlanCheckState
    let issueCount: Int
    let rangeText: String
    let endMonthText: String
}

enum PlanCheckSummaryBuilder {
    static func summary(store: WalletStore, startMonth: Date, endMonth: Date) -> PlanCheckSummary {
        let start = startOfMonth(for: startMonth)
        let end = endOfMonth(for: endMonth)
        let normalizedRange = start <= end ? (start: start, end: end) : (start: startOfMonth(for: endMonth), end: endOfMonth(for: startMonth))
        let months = selectedMonths(from: normalizedRange.start, through: normalizedRange.end)
        let scopedEvents = store.activeFinancialEvents.filter { event in
            event.date >= normalizedRange.start && event.date <= normalizedRange.end
        }

        let issueCount =
            missingAccountCount(in: scopedEvents) +
            uncategorizedCount(in: scopedEvents) +
            futureNotPlannedCount(in: scopedEvents, store: store) +
            suspiciousAmountCount(in: scopedEvents) +
            duplicateCount(in: scopedEvents) +
            recurringReviewCount(in: scopedEvents) +
            monthlyObservationCount(months: months, store: store)

        let state: PlanCheckState
        if hasInsufficientData(months: months, scopedEvents: scopedEvents, store: store) {
            state = .insufficientData
        } else if issueCount > 0 {
            state = .needsReview
        } else {
            state = .complete
        }

        return PlanCheckSummary(
            state: state,
            issueCount: issueCount,
            rangeText: rangeText(from: normalizedRange.start, through: normalizedRange.end),
            endMonthText: monthText(normalizedRange.end)
        )
    }

    private static func missingAccountCount(in events: [FinancialEvent]) -> Int {
        events.filter { event in
            event.status != .cancelled &&
            event.status != .skipped &&
            event.type != .transfer &&
            event.accountName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
        }.count
    }

    private static func uncategorizedCount(in events: [FinancialEvent]) -> Int {
        events.filter { event in
            event.status != .cancelled &&
            event.status != .skipped &&
            isBudgetRelevant(event) &&
            event.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false
        }.count
    }

    private static func futureNotPlannedCount(in events: [FinancialEvent], store: WalletStore) -> Int {
        events.filter { event in
            guard event.status != .paid,
                  event.status != .cancelled,
                  event.status != .skipped,
                  isBudgetRelevant(event),
                  let categoryName = event.categoryName,
                  !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }

            return plannedAmount(for: event, categoryName: categoryName, store: store) <= 0
        }.count
    }

    private static func suspiciousAmountCount(in events: [FinancialEvent]) -> Int {
        events.filter { $0.amount <= 0 }.count
    }

    private static func duplicateCount(in events: [FinancialEvent]) -> Int {
        let activeEvents = events.filter {
            $0.status != .cancelled && $0.status != .skipped
        }

        let groupedEvents = Dictionary(grouping: activeEvents) { event in
            duplicateKey(for: event)
        }

        return groupedEvents.values.filter { events in
            reportableDuplicateCandidates(from: sortedEvents(events)).count > 1
        }.count
    }

    private static func recurringReviewCount(in events: [FinancialEvent]) -> Int {
        events.filter { event in
            event.repeatRule != .none &&
            event.status != .cancelled &&
            event.status != .skipped &&
            event.effectiveRecurringEndKind == .never
        }.count
    }

    private static func monthlyObservationCount(months: [Date], store: WalletStore) -> Int {
        months.reduce(0) { total, monthDate in
            total + (hasIncome(in: monthDate, store: store) ? 0 : 1) + (hasBudgetObservationIssue(in: monthDate, store: store) ? 1 : 0)
        }
    }

    private static func hasInsufficientData(months: [Date], scopedEvents: [FinancialEvent], store: WalletStore) -> Bool {
        let hasIncome = scopedEvents.contains { event in
            event.type == .income &&
            event.status != .cancelled &&
            event.status != .skipped
        }

        let hasPlannedBudget = months.contains { monthDate in
            let key = monthComponents(for: monthDate)
            return store.monthlyBudget(year: key.year, month: key.month)?.items.contains { $0.plannedAmount > 0 } == true
        }

        return !hasIncome && !hasPlannedBudget
    }

    private static func hasIncome(in monthDate: Date, store: WalletStore) -> Bool {
        let monthKey = monthComponents(for: monthDate)
        return store.activeFinancialEvents.contains { event in
            guard event.type == .income,
                  event.status != .cancelled,
                  event.status != .skipped else {
                return false
            }

            let eventKey = monthComponents(for: event.date)
            return eventKey.year == monthKey.year && eventKey.month == monthKey.month
        }
    }

    private static func hasBudgetObservationIssue(in monthDate: Date, store: WalletStore) -> Bool {
        let monthKey = monthComponents(for: monthDate)

        guard let budget = store.monthlyBudget(year: monthKey.year, month: monthKey.month) else {
            return true
        }

        if budget.items.isEmpty || budget.items.allSatisfy({ $0.plannedAmount <= 0 }) {
            return true
        }

        let plannedByCategory = Dictionary(uniqueKeysWithValues: budget.items.map { item in
            (item.categoryName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), item.plannedAmount)
        })

        let mainBudgetCategories = store.activeCategories
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return mainBudgetCategories.contains { categoryName in
            let key = categoryName.lowercased()
            return (plannedByCategory[key] ?? 0) <= 0
        }
    }

    private static func isBudgetRelevant(_ event: FinancialEvent) -> Bool {
        switch event.type {
        case .expense, .obligation, .expectedExpense, .installment:
            return true
        case .income, .transfer:
            return false
        }
    }

    private static func plannedAmount(for event: FinancialEvent, categoryName: String, store: WalletStore) -> Double {
        let components = Calendar.current.dateComponents([.year, .month], from: event.date)

        guard let year = components.year,
              let month = components.month,
              let budget = store.monthlyBudget(year: year, month: month) else {
            return 0
        }

        return budget.items.first {
            $0.categoryName.caseInsensitiveCompare(categoryName) == .orderedSame
        }?.plannedAmount ?? 0
    }

    private static func duplicateKey(for event: FinancialEvent) -> String {
        let day = Calendar.current.startOfDay(for: event.date).timeIntervalSince1970
        let normalizedTitle = event.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(event.type.rawValue)-\(event.amount)-\(day)-\(normalizedTitle)"
    }

    private static func reportableDuplicateCandidates(from events: [FinancialEvent]) -> [FinancialEvent] {
        let linkedPaidOccurrenceSourceIDs = Set(
            events.compactMap { event -> UUID? in
                guard event.status == .paid else {
                    return nil
                }

                return event.sourceRecurringEventID
            }
        )

        return events.filter { event in
            let isRecurringTemplateWithLinkedPaidOccurrence =
                event.repeatRule != .none &&
                linkedPaidOccurrenceSourceIDs.contains(event.id)

            return !isRecurringTemplateWithLinkedPaidOccurrence
        }
    }

    private static func sortedEvents(_ events: [FinancialEvent]) -> [FinancialEvent] {
        events.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date < rhs.date
            }

            return lhs.createdAt < rhs.createdAt
        }
    }

    private static func selectedMonths(from start: Date, through end: Date) -> [Date] {
        var months: [Date] = []
        var current = startOfMonth(for: start)
        let last = startOfMonth(for: end)

        while current <= last {
            months.append(current)
            guard let next = Calendar.current.date(byAdding: .month, value: 1, to: current) else {
                break
            }
            current = next
        }

        return months
    }

    private static func monthComponents(for date: Date) -> (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return (components.year ?? 0, components.month ?? 0)
    }

    private static func rangeText(from start: Date, through end: Date) -> String {
        if Calendar.current.isDate(start, equalTo: end, toGranularity: .month) {
            return monthText(start)
        }

        return "\(monthText(start)) - \(monthText(end))"
    }

    private static func monthText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    private static func startOfMonth(for date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }

    private static func endOfMonth(for date: Date) -> Date {
        let start = startOfMonth(for: date)
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start
        return Calendar.current.date(byAdding: .second, value: -1, to: nextMonth) ?? start
    }
}
