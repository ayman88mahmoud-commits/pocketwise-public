import SwiftUI

struct CashTimelineView: View {

    private enum HorizonOption: Equatable, Identifiable {
        case days30
        case days60
        case days90
        case customDate(Date)

        var id: String {
            switch self {
            case .days30: return "days30"
            case .days60: return "days60"
            case .days90: return "days90"
            case .customDate: return "customDate"
            }
        }

        func label(_ language: AppLanguage) -> String {
            switch self {
            case .days30: return AppText.timelineHorizon30(language)
            case .days60: return AppText.timelineHorizon60(language)
            case .days90: return AppText.timelineHorizon90(language)
            case .customDate: return AppText.timelineHorizonPickDate(language)
            }
        }
    }

    fileprivate struct TimelineDetailRow: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    fileprivate struct TimelineSourceItem: Identifiable {
        let id: String
        let title: String
        let amount: Double
        let date: Date
        let isInflow: Bool
        let sourceType: String
        let status: FinancialEventStatus?
        let categoryName: String?
        let subCategoryName: String?
        let detailRows: [TimelineDetailRow]
    }

    private struct BalancedItem: Identifiable {
        let item: TimelineSourceItem
        let balanceAfter: Double
        var id: String { item.id }
    }

    private struct MonthGroup: Identifiable {
        let monthDate: Date
        let items: [BalancedItem]
        var id: Date { monthDate }
    }

    private struct TimelineSnapshot {
        let result: RunwayCheckResult
        let horizonDate: Date
        let balancedItems: [BalancedItem]
        let pinchPoint: BalancedItem?
        let itemsByMonth: [MonthGroup]
        let overdueItems: [TimelineSourceItem]
    }

    @EnvironmentObject private var store: WalletStore
    @State private var selectedHorizon: HorizonOption = .customDate(Self.defaultCustomDate())
    @State private var customPickerDate: Date = Self.defaultCustomDate()
    @State private var hasChosenCustomDate = false
    @State private var isCustomDatePickerPresented = false
    @State private var selectedItem: TimelineSourceItem?

    private var language: AppLanguage { store.appLanguage }
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private static func defaultCustomDate() -> Date {
        Date().addingTimeInterval(60 * 60 * 24 * 30)
    }

    var body: some View {
        let snapshot = makeSnapshot()

        List {
            verdictSection(snapshot: snapshot)
            horizonSection
            scopeNoteSection
            todayAnchorSection(snapshot: snapshot)
            overdueSection(snapshot: snapshot)
            futureSection(snapshot: snapshot)
        }
        .listStyle(.plain)
        .navigationTitle(AppText.timelineTitle(language))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedItem) { item in
            TimelineItemDetailSheet(item: item)
                .environmentObject(store)
        }
        .sheet(isPresented: $isCustomDatePickerPresented) {
            customDatePickerSheet
        }
    }

    // MARK: - Snapshot

    private func makeSnapshot() -> TimelineSnapshot {
        let targetDate = engineTargetDate()
        let result = store.runwayCheck(targetDate: targetDate)
        let allItems = timelineItems(from: result)
        let horizonDate = resolvedHorizonDate(from: allItems)
        let visibleItems = allItems.filter { $0.date >= today && $0.date <= horizonDate }

        var balance = result.availableCash
        let balancedItems = visibleItems.map { item in
            balance += item.isInflow ? item.amount : -item.amount
            return BalancedItem(item: item, balanceAfter: balance)
        }

        let target = store.runwaySafeBalanceTarget
        let pinchPoint = balancedItems
            .filter { $0.balanceAfter < target }
            .min { $0.balanceAfter < $1.balanceAfter }

        let itemsByMonth = monthGroups(from: balancedItems)
        let overdueItems = overdueObligationItems()

        return TimelineSnapshot(
            result: result,
            horizonDate: horizonDate,
            balancedItems: balancedItems,
            pinchPoint: pinchPoint,
            itemsByMonth: itemsByMonth,
            overdueItems: overdueItems
        )
    }

    private func engineTargetDate() -> Date {
        let days: Int
        switch selectedHorizon {
        case .days30:
            days = 30
        case .days60:
            days = 60
        case .days90:
            days = 90
        case .customDate(let date):
            days = (Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 90) + 1
        }

        return Calendar.current.date(byAdding: .day, value: max(days, 1), to: today) ?? today
    }

    private func timelineItems(from result: RunwayCheckResult) -> [TimelineSourceItem] {
        let inflows = result.breakdown.futureCashInflowItems.map {
            sourceItem(from: $0, isInflow: true)
        }
        let obligations = result.breakdown.datedObligationItems.map {
            sourceItem(from: $0, isInflow: false)
        }
        let installments = result.breakdown.recurringInstallmentItems.map {
            sourceItem(from: $0, isInflow: false)
        }

        return (inflows + obligations + installments)
            .sorted {
                if $0.date == $1.date {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.date < $1.date
            }
    }

    private func sourceItem(from item: RunwayBreakdownItem, isInflow: Bool) -> TimelineSourceItem {
        TimelineSourceItem(
            id: "runway-\(item.id.uuidString)",
            title: item.title,
            amount: item.amount,
            date: item.date,
            isInflow: isInflow,
            sourceType: item.sourceType,
            status: item.status,
            categoryName: item.categoryName,
            subCategoryName: item.subCategoryName,
            detailRows: []
        )
    }

    private func resolvedHorizonDate(from items: [TimelineSourceItem]) -> Date {
        switch selectedHorizon {
        case .days30:
            return Calendar.current.date(byAdding: .day, value: 30, to: today) ?? today
        case .days60:
            return Calendar.current.date(byAdding: .day, value: 60, to: today) ?? today
        case .days90:
            return Calendar.current.date(byAdding: .day, value: 90, to: today) ?? today
        case .customDate(let date):
            return Calendar.current.startOfDay(for: date)
        }
    }

    private func monthGroups(from balancedItems: [BalancedItem]) -> [MonthGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: balancedItems) { balanced -> Date in
            calendar.date(from: calendar.dateComponents([.year, .month], from: balanced.item.date)) ?? balanced.item.date
        }
        return grouped
            .sorted { $0.key < $1.key }
            .map { MonthGroup(monthDate: $0.key, items: $0.value) }
    }

    private func overdueObligationItems() -> [TimelineSourceItem] {
        store.financialEvents
            .filter { event in
                ForecastEngine.isCashImpactEvent(event.type) &&
                ForecastEngine.isOutflow(event.type) &&
                event.status == .unpaid &&
                Calendar.current.startOfDay(for: event.date) < today
            }
            .compactMap { event in
                if event.repeatRule != .none && overdueOccurrenceAlreadyPaid(event) {
                    return nil
                }
                return overdueSourceItem(from: event)
            }
            .sorted { $0.date < $1.date }
    }

    private func overdueOccurrenceAlreadyPaid(_ template: FinancialEvent) -> Bool {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: template.date)
        let month = calendar.component(.month, from: template.date)
        return store.financialEvents.contains { event in
            event.sourceRecurringEventID == template.id &&
            event.status == .paid &&
            event.recurringOccurrenceYear == year &&
            event.recurringOccurrenceMonth == month
        }
    }

    private func overdueSourceItem(from event: FinancialEvent) -> TimelineSourceItem {
        TimelineSourceItem(
            id: "overdue-\(event.id.uuidString)",
            title: event.title,
            amount: event.amount,
            date: event.date,
            isInflow: false,
            sourceType: event.type.rawValue,
            status: event.status,
            categoryName: event.categoryName,
            subCategoryName: event.subCategoryName,
            detailRows: []
        )
    }

    // MARK: - Verdict Section

    private func verdictSection(snapshot: TimelineSnapshot) -> some View {
        Section {
            if let pinch = snapshot.pinchPoint {
                HStack(alignment: .top, spacing: 12) {
                    PocketWiseIconBadge(
                        systemName: "exclamationmark.triangle.fill",
                        semanticColor: .warning,
                        size: 38,
                        cornerRadius: 11
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppText.timelineTight(language, dateString: CashTimelineFormatters.shortDate(pinch.item.date, language: language)))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PocketWiseSemanticColor.warning.tint)
                        Text(AppText.timelinePinchDetail(
                            language,
                            amount: store.displayCurrency(pinch.balanceAfter),
                            dateString: CashTimelineFormatters.shortDate(pinch.item.date, language: language)
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .pocketWiseCard(semanticColor: .warning, padding: 12, cornerRadius: 14, showsBorder: true)
            } else if snapshot.balancedItems.isEmpty {
                Text(AppText.timelineEmpty(language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                Label(AppText.timelineAllClear(language, dateString: CashTimelineFormatters.shortDate(snapshot.horizonDate, language: language)), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(PocketWiseSemanticColor.success.tint)
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 4)
            }
        }
        .listRowSeparator(.hidden)
    }

    // MARK: - Horizon Section

    private var horizonSection: some View {
        Section {
            HStack(spacing: 4) {
                horizonButton(.days30)
                horizonButton(.days60)
                horizonButton(.days90)
                customDateButton
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
        .listRowSeparator(.hidden)
    }

    private func horizonButton(_ option: HorizonOption) -> some View {
        Button {
            selectedHorizon = option
        } label: {
            Text(option.label(language))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .pocketWiseChip(semanticColor: .accounts, isSelected: selectedHorizon == option)
        }
        .buttonStyle(.plain)
    }

    private var customDateButton: some View {
        Button {
            if case .customDate(let date) = selectedHorizon {
                customPickerDate = clampedCustomDate(date)
            }
            isCustomDatePickerPresented = true
        } label: {
            Label {
                Text(customDateLabel)
            } icon: {
                if !hasChosenCustomDate {
                    Image(systemName: "calendar")
                }
            }
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .pocketWiseChip(semanticColor: .accounts, isSelected: isCustomDateSelected)
        }
        .buttonStyle(.plain)
    }

    private var customDateLabel: String {
        guard hasChosenCustomDate else {
            return AppText.timelineHorizonPickDate(language)
        }
        return CashTimelineFormatters.shortDate(customPickerDate, language: language)
    }

    private var isCustomDateSelected: Bool {
        if case .customDate = selectedHorizon { return true }
        return false
    }

    private var customDatePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "",
                selection: $customPickerDate,
                in: customDateRange,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding()
            .navigationTitle(AppText.timelineHorizonPickDate(language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.done(language)) {
                        let selectedDate = clampedCustomDate(customPickerDate)
                        customPickerDate = selectedDate
                        selectedHorizon = .customDate(selectedDate)
                        hasChosenCustomDate = true
                        isCustomDatePickerPresented = false
                    }
                }
            }
        }
        .onAppear {
            if case .customDate(let date) = selectedHorizon {
                customPickerDate = clampedCustomDate(date)
            }
        }
    }

    private var customDateRange: ClosedRange<Date> {
        customMinimumDate...customMaximumDate
    }

    private var customMinimumDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
    }

    private var customMaximumDate: Date {
        Calendar.current.date(byAdding: .year, value: 2, to: today) ?? today
    }

    private func clampedCustomDate(_ date: Date) -> Date {
        min(max(Calendar.current.startOfDay(for: date), customMinimumDate), customMaximumDate)
    }

    private var scopeNoteSection: some View {
        Section {
            Text(CashTimelineLabels.knownCommitmentsOnlyNote(language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 2)
        }
        .listRowSeparator(.hidden)
    }

    // MARK: - Today Anchor Section

    private func todayAnchorSection(snapshot: TimelineSnapshot) -> some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppText.timelineToday(language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(AppText.availableNow(language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(store.displayCurrency(snapshot.result.availableCash))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(snapshot.result.availableCash >= store.runwaySafeBalanceTarget ? PocketWiseSemanticColor.accounts.tint : PocketWiseSemanticColor.danger.tint)
            }
            .pocketWiseCard(semanticColor: .accounts, padding: 12, cornerRadius: 14, showsBorder: true)
        }
        .listRowSeparator(.hidden)
    }

    // MARK: - Overdue Section

    @ViewBuilder private func overdueSection(snapshot: TimelineSnapshot) -> some View {
        if !snapshot.overdueItems.isEmpty {
            Section {
                ForEach(snapshot.overdueItems) { item in
                    TimelineEventRow(
                        item: item,
                        balanceAfter: nil,
                        isOverdue: true,
                        language: language
                    )
                    .onTapGesture { selectedItem = item }
                    .listRowSeparator(.hidden)
                }
            } header: {
                Text(AppText.timelineOverdueHeader(language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PocketWiseSemanticColor.danger.tint)
                    .textCase(nil)
            }
        }
    }

    // MARK: - Future Section

    @ViewBuilder private func futureSection(snapshot: TimelineSnapshot) -> some View {
        if snapshot.balancedItems.isEmpty {
            Section {
                Text(AppText.timelineEmpty(language))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            }
            .listRowSeparator(.hidden)
        } else {
            ForEach(snapshot.itemsByMonth) { group in
                Section {
                    ForEach(group.items) { balanced in
                        TimelineEventRow(
                            item: balanced.item,
                            balanceAfter: balanced.balanceAfter,
                            isOverdue: false,
                            language: language
                        )
                        .onTapGesture { selectedItem = balanced.item }
                        .listRowSeparator(Visibility.hidden)
                    }
                } header: {
                    Text(CashTimelineFormatters.month(group.monthDate, language: language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
    }
}

// MARK: - Timeline Event Row

private struct TimelineEventRow: View {

    let item: CashTimelineView.TimelineSourceItem
    let balanceAfter: Double?
    let isOverdue: Bool
    let language: AppLanguage

    @EnvironmentObject private var store: WalletStore

    private var isPinchPoint: Bool {
        guard !isOverdue else { return false }
        guard let balance = balanceAfter else { return false }
        return balance < store.runwaySafeBalanceTarget
    }

    private var amountColor: Color {
        if isOverdue { return PocketWiseSemanticColor.danger.tint }
        if isPinchPoint { return PocketWiseSemanticColor.warning.tint }
        if item.isInflow { return PocketWiseSemanticColor.accounts.tint }
        return Color.primary
    }

    private var semanticColor: PocketWiseSemanticColor {
        if isOverdue { return .danger }
        if isPinchPoint { return .warning }
        if item.isInflow { return .accounts }
        return .obligations
    }

    private var dateString: String {
        CashTimelineFormatters.shortDate(item.date, language: language)
    }

    private var dateTypeLabel: String {
        if isOverdue {
            return "\(dateString) · \(AppText.timelineOverdueNote(language))"
        }
        return "\(dateString) · \(CashTimelineLabels.sourceType(item.sourceType, language: language))"
    }

    private func numberOnly(_ amount: Double) -> String {
        let full = store.displayCurrency(amount)
        guard !store.hideBalances else { return full }
        return full.replacingOccurrences(of: " EGP", with: "")
    }

    private func afterText(_ balance: Double) -> String {
        "\(CashTimelineLabels.afterCompact(language)): \(numberOnly(balance))"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 1.5)
                dotView
                    .frame(width: 9, height: 9)
            }
            .frame(width: 20)

            contentColumn
                .padding(.vertical, 10)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .contentShape(Rectangle())
    }

    @ViewBuilder private var dotView: some View {
        if isOverdue || isPinchPoint {
            Circle().fill(semanticColor.tint)
        } else if item.isInflow {
            Circle().stroke(semanticColor.tint, lineWidth: 1.5)
        } else {
            Circle().fill(PocketWiseSemanticColor.obligations.tint.opacity(0.7))
        }
    }

    @ViewBuilder private var contentColumn: some View {
        if isPinchPoint {
            innerContent
                .padding(8)
                .pocketWiseCard(semanticColor: .warning, padding: 8, cornerRadius: 10, showsBorder: true)
        } else {
            innerContent
        }
    }

    private var innerContent: some View {
        HStack(alignment: .top, spacing: 0) {
            leftColumn
                .layoutPriority(1)
            Spacer(minLength: 8)
            rightColumn
                .frame(minWidth: 84, maxWidth: 128, alignment: .trailing)
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                if item.isInflow {
                    Text(AppText.timelineExpectedBadge(language))
                        .pocketWiseChip(semanticColor: .accounts)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            Text(dateTypeLabel)
                .font(.system(size: 12))
                .foregroundStyle(Color.secondary)

            if item.isInflow {
                Text(AppText.timelineNotReceivedYet(language))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondary)
            }

            if isPinchPoint, let balance = balanceAfter {
                Text(AppText.timelinePinchDetail(
                    language,
                    amount: numberOnly(balance),
                    dateString: dateString
                ))
                .font(.system(size: 12))
                .foregroundStyle(PocketWiseSemanticColor.warning.tint)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var rightColumn: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text((item.isInflow ? "+" : "−") + numberOnly(item.amount))
                .font(.body.weight(.medium))
                .foregroundStyle(amountColor)

            if let balance = balanceAfter {
                Text(afterText(balance))
                    .font(.system(size: 12))
                    .foregroundStyle(balance < store.runwaySafeBalanceTarget ? PocketWiseSemanticColor.warning.tint : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }
}

// MARK: - Timeline Item Detail Sheet

private struct TimelineItemDetailSheet: View {

    @EnvironmentObject private var store: WalletStore
    let item: CashTimelineView.TimelineSourceItem

    private var language: AppLanguage { store.appLanguage }
    private var isArabic: Bool { language == .arabicEgyptian }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    detailRow(label: CashTimelineLabels.amount(language), value: store.displayCurrency(item.amount))
                    detailRow(label: CashTimelineLabels.date(language), value: CashTimelineFormatters.longDate(item.date, language: language))
                    detailRow(label: CashTimelineLabels.type(language), value: CashTimelineLabels.sourceType(item.sourceType, language: language))
                    if let status = item.status {
                        detailRow(label: CashTimelineLabels.status(language), value: CashTimelineLabels.status(status, language: language))
                    }
                    if let category = item.categoryName {
                        detailRow(label: isArabic ? "البند" : "Category", value: category)
                    }
                    if let subCategory = item.subCategoryName {
                        detailRow(label: isArabic ? "البند الفرعي" : "Subcategory", value: subCategory)
                    }
                }

                if !item.detailRows.isEmpty {
                    Section {
                        ForEach(item.detailRows) { row in
                            detailRow(label: row.label, value: row.value)
                        }
                    }
                }
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Labels and Formatters

private enum CashTimelineLabels {
    static func monthlyBudgetEstimate(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "تقدير الميزانية الشهرية" : "Monthly budget estimate"
    }

    static func knownCommitmentsOnlyNote(_ language: AppLanguage) -> String {
        language == .arabicEgyptian
            ? "الالتزامات المعروفة فقط. تقدير الميزانية الشهرية غير محسوب هنا."
            : "Known commitments only. Monthly budget estimate is not included here."
    }

    static func afterCompact(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "بعدها" : "After"
    }

    static func amount(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "المبلغ" : "Amount"
    }

    static func date(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "التاريخ" : "Date"
    }

    static func type(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "النوع" : "Type"
    }

    static func status(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الحالة" : "Status"
    }

    static func period(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الفترة" : "Period"
    }

    static func planned(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "المخطط" : "Planned"
    }

    static func paidSoFar(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "مدفوع لحد دلوقتي" : "Paid so far"
    }

    static func committedElsewhere(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "ملتزم به في مكان تاني" : "Committed elsewhere"
    }

    static func remainingEstimate(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "التقدير المتبقي" : "Remaining estimate"
    }

    static func sourceType(_ rawValue: String, language: AppLanguage) -> String {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "monthly budget estimate":
            return monthlyBudgetEstimate(language)
        case "expected income", "future inflow", "income":
            return language == .arabicEgyptian ? "دخل متوقع" : "Expected income"
        case "credit card due", "credit card payment due":
            return language == .arabicEgyptian ? "مستحق كارت ائتمان" : "Credit card due"
        case "installment":
            return language == .arabicEgyptian ? "قسط" : "Installment"
        case "recurring", "recurring payment":
            return language == .arabicEgyptian ? "متكرر" : "Recurring"
        case "obligation":
            return language == .arabicEgyptian ? "التزام" : "Obligation"
        case "expected expense", "future expense":
            return language == .arabicEgyptian ? "مصروف متوقع" : "Expected expense"
        case "debt repayment":
            return language == .arabicEgyptian ? "سداد دين" : "Debt repayment"
        case "reimbursement":
            return language == .arabicEgyptian ? "تعويض" : "Reimbursement"
        case "transfer":
            return language == .arabicEgyptian ? "تحويل" : "Transfer"
        default:
            if rawValue.isEmpty {
                return language == .arabicEgyptian ? "بند" : "Item"
            }
            return language == .arabicEgyptian ? "بند" : rawValue
        }
    }

    static func status(_ status: FinancialEventStatus, language: AppLanguage) -> String {
        switch status {
        case .planned:
            return language == .arabicEgyptian ? "مخطط" : "Planned"
        case .expected:
            return language == .arabicEgyptian ? "متوقع" : "Expected"
        case .paid:
            return language == .arabicEgyptian ? "مدفوع" : "Paid"
        case .unpaid:
            return language == .arabicEgyptian ? "غير مدفوع" : "Unpaid"
        case .skipped:
            return language == .arabicEgyptian ? "متخطي" : "Skipped"
        case .cancelled:
            return language == .arabicEgyptian ? "ملغي" : "Cancelled"
        }
    }
}

private enum CashTimelineFormatters {
    private static let shortEnglish: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    private static let shortArabic: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "ar_EG")
        return formatter
    }()

    private static let monthEnglish: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    private static let monthArabic: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "ar_EG")
        return formatter
    }()

    private static let longEnglish: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    private static let longArabic: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "ar_EG")
        return formatter
    }()

    static func shortDate(_ date: Date, language: AppLanguage) -> String {
        (language == .arabicEgyptian ? shortArabic : shortEnglish).string(from: date)
    }

    static func month(_ date: Date, language: AppLanguage) -> String {
        (language == .arabicEgyptian ? monthArabic : monthEnglish).string(from: date)
    }

    static func longDate(_ date: Date, language: AppLanguage) -> String {
        (language == .arabicEgyptian ? longArabic : longEnglish).string(from: date)
    }
}
