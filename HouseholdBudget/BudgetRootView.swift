import SwiftUI

struct BudgetRootView: View {

    private enum BudgetSection: String, CaseIterable, Identifiable {
        case grid
        case currentMonth
        case obligations
        case setup

        var id: String { rawValue }

        func title(_ language: AppLanguage) -> String {
            switch self {
            case .grid:
                return AppText.budgetGrid(language)
            case .currentMonth:
                return AppText.currentMonth(language)
            case .obligations:
                return AppText.obligations(language)
            case .setup:
                return AppText.setup(language)
            }
        }
    }

    @EnvironmentObject private var store: WalletStore
    @State private var selectedSection: BudgetSection = .grid

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedSection) {
                    ForEach(BudgetSection.allCases) { section in
                        Text(section.title(store.appLanguage)).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)

                Divider()

                Group {
                    switch selectedSection {
                    case .grid:
                        BudgetGridView()
                    case .currentMonth:
                        CurrentMonthBudgetView()
                    case .obligations:
                        ObligationsCenterView()
                    case .setup:
                        BudgetSetupView()
                    }
                }
                .environmentObject(store)
            }
            .accessibilityIdentifier("screen.budget")
            .navigationTitle(AppText.tabPlan(store.appLanguage))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct BudgetGridView: View {

    private enum RangeMode: String, CaseIterable, Identifiable {
        case annual
        case custom

        var id: String { rawValue }

        func title(_ language: AppLanguage) -> String {
            switch self {
            case .annual:
                return language == .arabicEgyptian ? "سنوي" : "Annual"
            case .custom:
                return language == .arabicEgyptian ? "مخصص" : "Custom"
            }
        }
    }

    @EnvironmentObject private var store: WalletStore
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("budgetGridRangeMode") private var rangeModeRaw = RangeMode.custom.rawValue
    @AppStorage("budgetGridCustomStartMonth") private var customStartMonthValue = BudgetGridView.defaultCustomStartMonth.timeIntervalSinceReferenceDate
    @AppStorage("budgetGridCustomEndMonth") private var customEndMonthValue = BudgetGridView.defaultCustomEndMonth.timeIntervalSinceReferenceDate
    @AppStorage("budgetGridSelectedYear") private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var isSelectingCustomEnd = false
    @State private var selectedCell: BudgetCellSelection?
    @State private var selectedMonthForBudget: BudgetMonthSelection?
    @State private var applyRoute: BudgetGridApplyRoute?
    @State private var latestUndoAction: BudgetGridUndoAction?
    @State private var showObligationsSheet = false
    @State private var selectedIncomeMonth: BudgetMonthSelection?
    @State private var selectedProjectedExpenseMonth: BudgetMonthProjection?
    @State private var selectedCommittedMonth: BudgetCommittedMonthSelection?
    @State private var deferredGridSnapshot: BudgetGridSnapshot?
    @State private var deferredGridSnapshotSignature: BudgetGridSnapshotSignature?

    private let rowHeaderWidth: CGFloat = 92
    private let cellWidth: CGFloat = 112

    private static var defaultCustomStartMonth: Date {
        BudgetDateHelper.startOfMonth(for: Date())
    }

    private static var defaultCustomEndMonth: Date {
        let year = Calendar.current.component(.year, from: Date())
        return BudgetDateHelper.date(year: year, month: 12) ?? defaultCustomStartMonth
    }

    private var rangeMode: RangeMode {
        RangeMode(rawValue: rangeModeRaw) ?? .custom
    }

    private var customStartMonthDate: Date {
        BudgetDateHelper.startOfMonth(for: Date(timeIntervalSinceReferenceDate: customStartMonthValue))
    }

    private var customEndMonthDate: Date {
        BudgetDateHelper.startOfMonth(for: Date(timeIntervalSinceReferenceDate: customEndMonthValue))
    }

    private var monthDates: [Date] {
        switch rangeMode {
        case .annual:
            return (1...12).compactMap { month in
                BudgetDateHelper.date(year: selectedYear, month: month)
            }
        case .custom:
            return BudgetDateHelper.months(from: customStartMonthDate, through: customEndMonthDate)
        }
    }

    private var gridSnapshot: BudgetGridSnapshot {
        BudgetGridSnapshot(
            monthDates: monthDates,
            initialOpeningBalance: store.availableCash,
            safeThreshold: max(store.runwaySafeBalanceTarget, 0),
            store: store
        )
    }

    private var gridSnapshotSignature: BudgetGridSnapshotSignature {
        BudgetGridSnapshotSignature(
            monthDates: monthDates,
            availableCash: store.availableCash,
            safeThreshold: max(store.runwaySafeBalanceTarget, 0),
            financialDataVersion: store.localDataUpdatedAt
        )
    }

    private var categories: [String] {
        gridSnapshot.categories
    }

    private func projectionRows(from snapshot: BudgetGridSnapshot) -> [BudgetMonthProjection] {
        snapshot.projectionRows
    }

    private var projectionRows: [BudgetMonthProjection] {
        gridSnapshot.projectionRows
    }

    private func planCheckSummary(for snapshot: BudgetGridSnapshot) -> PlanCheckSummary {
        PlanCheckSummaryBuilder.summary(
            store: store,
            startMonth: snapshot.monthDates.first ?? Date(),
            endMonth: snapshot.monthDates.last ?? Date()
        )
    }

    private var planCheckSummary: PlanCheckSummary {
        planCheckSummary(for: gridSnapshot)
    }

    private func makeGridSnapshot() -> BudgetGridSnapshot {
        gridSnapshot
    }

    var body: some View {
        let snapshotSignature = gridSnapshotSignature
        let snapshot: BudgetGridSnapshot? = deferredGridSnapshotSignature == snapshotSignature ? deferredGridSnapshot : nil
        let categories = snapshot?.categories ?? []
        let projectionRows = snapshot?.projectionRows ?? []

        List {
            if let snapshot {
                let planCheckSummary = planCheckSummary(for: snapshot)
                Section {
                    planStatusCard(summary: planCheckSummary)
                }
            }

            Section {
                rangeControls
            }

            Section {
                Text(store.appLanguage == .arabicEgyptian ? "عدّل المخطط من الجدول. المدفوع والأرصدة الفعلية مش بتتغير من هنا." : "Edit planned budget values from the grid. Paid spending and real balances do not change here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let latestUndoAction {
                Section {
                    HStack(spacing: 8) {
                        Text(store.appLanguage == .arabicEgyptian ? "تم تحديث \(latestUndoAction.monthCount) شهر •" : "Updated \(latestUndoAction.monthCount) months •")
                            .font(.footnote)
                            .fontWeight(.semibold)

                        Spacer()

                        Button(store.appLanguage == .arabicEgyptian ? "تراجع" : "Undo") {
                            undoLatestBudgetGridAction()
                        }
                        .font(.footnote)
                        .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 6)
                    .listRowBackground(Color.blue)
                }
            }

            Section {
                if let snapshot {
                    if categories.isEmpty {
                        ContentUnavailableView(
                            AppText.noCategoriesYet(store.appLanguage),
                            systemImage: "tablecells",
                            description: Text(store.appLanguage == .arabicEgyptian ? "أضف بنود من الإعدادات عشان تبدأ التخطيط." : "Add categories in Setup to start planning.")
                        )
                    } else {
                        gridTable(snapshot: snapshot, projectionRows: projectionRows)
                            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    }
                } else {
                    ContentUnavailableView(
                        store.appLanguage == .arabicEgyptian ? "جاري تجهيز المخطط" : "Preparing budget plan",
                        systemImage: "tablecells",
                        description: Text(store.appLanguage == .arabicEgyptian ? "هنعرض الجدول بعد تجهيز أرقام الفترة." : "The grid will appear after the visible range is prepared.")
                    )
                }
            } footer: {
                Text(store.appLanguage == .arabicEgyptian ? "ملتزم به جاي من مصاريف لسه ما اتدفعتش. مش محسوب كمدفوع، ومش بيغيّر المخطط إلا لو عدّلته بنفسك." : "Committed comes from future/unpaid items. It is not counted as paid, and it does not overwrite planned budget unless you edit it.")
            }
        }
        .listStyle(.insetGrouped)
        .task(id: snapshotSignature) {
            await rebuildDeferredGridSnapshot(for: snapshotSignature)
        }
        .sheet(item: $selectedCell) { selection in
            BudgetCellEditSheet(
                selection: selection,
                visibleMonths: monthDates,
                onUseCommittedAsBudget: { updatedSelection in
                    applySingleCellBudget(
                        selection: updatedSelection,
                        amount: updatedSelection.knownUpcomingAmount,
                        actionType: .useCommittedAsBudget
                    )
                },
                onCopyToFuture: { updatedSelection in
                    presentApplyRoute(.copyToFuture(selection: updatedSelection, visibleMonths: monthDates))
                },
                onApplyAcrossMonths: { updatedSelection in
                    presentApplyRoute(
                        .categoryAcrossMonths(
                            categoryName: updatedSelection.categoryName,
                            anchorMonth: updatedSelection.date,
                            visibleMonths: monthDates
                        )
                    )
                }
            )
            .environmentObject(store)
        }
        .sheet(item: $selectedMonthForBudget) { selection in
            MonthlyBudgetView(initialMonthDate: selection.date)
                .environmentObject(store)
        }
        .sheet(item: $applyRoute) { route in
            switch route {
            case let .copyToFuture(selection, visibleMonths):
                CopyBudgetCellForwardSheet(
                    selection: selection,
                    visibleMonths: visibleMonths,
                    onApplied: { undoAction in
                        latestUndoAction = undoAction
                    }
                )
                    .environmentObject(store)
            case let .categoryAcrossMonths(categoryName, anchorMonth, visibleMonths):
                CategoryAcrossMonthsSheet(
                    categoryName: categoryName,
                    anchorMonth: anchorMonth,
                    visibleMonths: visibleMonths,
                    onApplied: { undoAction in
                        latestUndoAction = undoAction
                    }
                )
                .environmentObject(store)
            }
        }
        .sheet(isPresented: $showObligationsSheet) {
            NavigationStack {
                ObligationsCenterView()
                    .environmentObject(store)
            }
        }
        .sheet(item: $selectedIncomeMonth) { selection in
            TransactionsView(
                initialFilter: TransactionInitialFilter(
                    monthDate: selection.date,
                    incomeOnly: true
                )
            )
            .environmentObject(store)
        }
        .sheet(item: $selectedProjectedExpenseMonth) { projection in
            ProjectedExpenseBreakdownSheet(
                projection: projection,
                categoryNames: deferredGridSnapshot?.categories ?? []
            )
            .environmentObject(store)
        }
        .sheet(item: $selectedCommittedMonth) { selection in
            MonthCommittedBreakdownSheet(selection: selection)
                .environmentObject(store)
        }
    }

    @MainActor
    private func rebuildDeferredGridSnapshot(for signature: BudgetGridSnapshotSignature) async {
        guard deferredGridSnapshotSignature != signature else {
            return
        }

        deferredGridSnapshot = nil
        deferredGridSnapshotSignature = nil
        await Task.yield()

        guard !Task.isCancelled else {
            return
        }

        let snapshot = makeGridSnapshot()
        guard gridSnapshotSignature == signature else {
            return
        }

        deferredGridSnapshot = snapshot
        deferredGridSnapshotSignature = signature
    }

    private func planStatusCard(summary: PlanCheckSummary) -> some View {
        NavigationLink {
            PlanningInboxView(
                rangeStartMonth: monthDates.first ?? Date(),
                rangeEndMonth: monthDates.last ?? Date()
            )
            .environmentObject(store)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(planStatusText(summary: summary))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(AppText.openPlanCheck(store.appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }

    private var planStatusCard: some View {
        planStatusCard(summary: planCheckSummary)
    }

    private var planStatusText: String {
        planStatusText(summary: planCheckSummary)
    }

    private func planStatusText(summary: PlanCheckSummary) -> String {
        switch summary.state {
        case .insufficientData:
            return AppText.addBudgetOrIncomeToCheckPeriod(store.appLanguage)
        case .needsReview:
            return AppText.planStatusIssues(
                store.appLanguage,
                count: summary.issueCount,
                range: summary.rangeText
            )
        case .complete:
            return AppText.planLooksCompleteThrough(
                store.appLanguage,
                month: summary.endMonthText
            )
        }
    }

    private func presentApplyRoute(_ route: BudgetGridApplyRoute) {
        selectedCell = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            applyRoute = route
        }
    }

    private func applySingleCellBudget(selection: BudgetCellSelection, amount: Double, actionType: BudgetGridBulkActionType) {
        let undoAction = BudgetGridUndoAction.capture(
            categoryName: selection.categoryName,
            dates: [selection.date],
            newAmount: amount,
            actionType: actionType,
            store: store
        )

        BudgetPlanningWriter.setPlannedAmount(
            amount,
            categoryName: selection.categoryName,
            year: selection.year,
            month: selection.month,
            store: store
        )
        latestUndoAction = undoAction
    }

    private func undoLatestBudgetGridAction() {
        guard let latestUndoAction else { return }
        latestUndoAction.restore(in: store)
        self.latestUndoAction = nil
    }

    private var rangeControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: rangeModeBinding) {
                ForEach(RangeMode.allCases) { mode in
                    Text(mode.title(store.appLanguage)).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch rangeMode {
            case .annual:
                Stepper(value: $selectedYear, in: 2000...2100) {
                    LabelValueRow(
                        title: store.appLanguage == .arabicEgyptian ? "السنة" : "Year",
                        value: "\(selectedYear)"
                    )
                }
            case .custom:
                customMonthPillSelector
            }
        }
    }

    private var rangeModeBinding: Binding<RangeMode> {
        Binding(
            get: { rangeMode },
            set: { newValue in
                rangeModeRaw = newValue.rawValue
                isSelectingCustomEnd = false
            }
        )
    }

    private var customMonthPillSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.appLanguage == .arabicEgyptian ? "اختار بداية ونهاية الفترة" : "Choose start and end months")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(customSelectableMonths, id: \.self) { month in
                        Button {
                            handleCustomMonthTap(month)
                        } label: {
                            Text(shortMonthTitle(month))
                                .font(.caption)
                                .fontWeight(isMonthInCustomRange(month) ? .semibold : .regular)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(customMonthPillBackground(month))
                                .foregroundStyle(isMonthInCustomRange(month) ? Color.white : Color.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 16)
            }

            Text(customRangeHelperText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var customSelectableMonths: [Date] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let startYear = min(
            currentYear,
            calendar.component(.year, from: customStartMonthDate),
            calendar.component(.year, from: customEndMonthDate)
        )
        let endYear = max(
            currentYear + 1,
            calendar.component(.year, from: customStartMonthDate),
            calendar.component(.year, from: customEndMonthDate)
        )

        guard let start = BudgetDateHelper.date(year: startYear, month: 1),
              let end = BudgetDateHelper.date(year: endYear, month: 12) else {
            return []
        }

        return BudgetDateHelper.months(from: start, through: end)
    }

    private var customRangeHelperText: String {
        if isSelectingCustomEnd {
            return store.appLanguage == .arabicEgyptian ? "اختار شهر النهاية. لو اخترت شهر قبل البداية، هنرتب الفترة تلقائيًا." : "Choose the end month. If it is before the start, the range will be swapped."
        }

        return store.appLanguage == .arabicEgyptian ? "اضغط شهر للبداية، ثم اضغط شهر النهاية." : "Tap a start month, then tap an end month."
    }

    private func handleCustomMonthTap(_ month: Date) {
        let tappedMonth = BudgetDateHelper.startOfMonth(for: month)

        if isSelectingCustomEnd {
            if Calendar.current.isDate(tappedMonth, equalTo: customStartMonthDate, toGranularity: .month) {
                resetCustomRangeToDefault()
                return
            }

            if tappedMonth < customStartMonthDate {
                setCustomEndMonthDate(customStartMonthDate)
                setCustomStartMonthDate(tappedMonth)
            } else {
                setCustomEndMonthDate(tappedMonth)
            }
            isSelectingCustomEnd = false
            return
        }

        setCustomStartMonthDate(tappedMonth)
        setCustomEndMonthDate(tappedMonth)
        isSelectingCustomEnd = true
    }

    private func resetCustomRangeToDefault() {
        setCustomStartMonthDate(BudgetGridView.defaultCustomStartMonth)
        setCustomEndMonthDate(BudgetGridView.defaultCustomEndMonth)
        isSelectingCustomEnd = false
    }

    private func setCustomStartMonthDate(_ date: Date) {
        customStartMonthValue = BudgetDateHelper.startOfMonth(for: date).timeIntervalSinceReferenceDate
    }

    private func setCustomEndMonthDate(_ date: Date) {
        customEndMonthValue = BudgetDateHelper.startOfMonth(for: date).timeIntervalSinceReferenceDate
    }

    private func isMonthInCustomRange(_ month: Date) -> Bool {
        let start = min(customStartMonthDate, customEndMonthDate)
        let end = max(customStartMonthDate, customEndMonthDate)
        let value = BudgetDateHelper.startOfMonth(for: month)
        return value >= start && value <= end
    }

    private func customMonthPillBackground(_ month: Date) -> Color {
        let value = BudgetDateHelper.startOfMonth(for: month)
        if Calendar.current.isDate(value, equalTo: customStartMonthDate, toGranularity: .month) ||
            Calendar.current.isDate(value, equalTo: customEndMonthDate, toGranularity: .month) {
            return .blue
        }

        if isMonthInCustomRange(value) {
            return Color.blue.opacity(0.70)
        }

        return Color(.secondarySystemGroupedBackground)
    }

    private func gridTable(snapshot: BudgetGridSnapshot, projectionRows: [BudgetMonthProjection]) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                headerScrollableRow(categories: snapshot.categories)
                Divider()

                ForEach(projectionRows) { row in
                    budgetMonthScrollableRow(row, snapshot: snapshot)
                    Divider()
                }

                Divider()
                    .padding(.top, 6)
                totalsScrollableRow(snapshot: snapshot, projectionRows: projectionRows)
            }
            .font(.caption)
        }
        .font(.caption)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .leftToRight)
        .overlay(alignment: .trailing) {
            LinearGradient(
                colors: [
                    Color(.systemBackground).opacity(0),
                    Color(.systemBackground).opacity(0.85)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 24)
            .allowsHitTesting(false)
        }
    }

    private var gridTable: some View {
        let snapshot = makeGridSnapshot()
        return gridTable(snapshot: snapshot, projectionRows: snapshot.projectionRows)
    }

    private func headerScrollableRow(categories: [String]) -> some View {
        HStack(spacing: 0) {
            gridHeaderCell(store.appLanguage == .arabicEgyptian ? "الشهر" : "Month", width: rowHeaderWidth)

            ForEach(categories, id: \.self) { category in
                Button {
                    applyRoute = .categoryAcrossMonths(
                        categoryName: category,
                        anchorMonth: customStartMonthDate,
                        visibleMonths: monthDates
                    )
                } label: {
                    gridHeaderCell(category, width: cellWidth)
                }
                .buttonStyle(.plain)
            }

            gridHeaderCell(AppText.income(store.appLanguage), width: cellWidth)
            gridHeaderCell(AppText.budget(store.appLanguage), width: cellWidth)
            gridHeaderCell(AppText.committed(store.appLanguage), width: cellWidth)
            gridHeaderCell(AppText.totalExpected(store.appLanguage), width: cellWidth)
            gridHeaderCell(AppText.endBalance(store.appLanguage), width: cellWidth)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var headerScrollableRow: some View {
        headerScrollableRow(categories: categories)
    }

    private func budgetMonthScrollableRow(_ row: BudgetMonthProjection, snapshot: BudgetGridSnapshot) -> some View {
        let isCurrent = Calendar.current.isDate(row.date, equalTo: Date(), toGranularity: .month)
        return HStack(spacing: 0) {
            Button {
                selectedMonthForBudget = BudgetMonthSelection(date: row.date)
            } label: {
                gridMonthCell(row.date)
            }
            .buttonStyle(.plain)

            ForEach(snapshot.categories, id: \.self) { category in
                let cell = snapshot.cellData(category: category, year: row.year, month: row.month)
                Button {
                    selectedCell = BudgetCellSelection(
                        date: row.date,
                        year: row.year,
                        month: row.month,
                        categoryName: category,
                        plannedAmount: cell.plannedAmount,
                        paidActualAmount: cell.paidActualAmount,
                        knownUpcomingAmount: cell.knownUpcomingAmount,
                        effectiveProjectedAmount: cell.effectiveProjectedAmount
                    )
                } label: {
                    gridBudgetCell(cell)
                }
                .buttonStyle(.plain)
            }

            Button {
                selectedIncomeMonth = BudgetMonthSelection(date: row.date)
            } label: {
                gridAmountCell(row.plannedIncome, width: cellWidth, color: .green)
            }
            .buttonStyle(.plain)

            Button {
                selectedMonthForBudget = BudgetMonthSelection(date: row.date)
            } label: {
                gridAmountCell(row.plannedExpenses, width: cellWidth, color: .primary)
            }
            .buttonStyle(.plain)

            Button {
                selectedCommittedMonth = BudgetCommittedMonthSelection(
                    monthDate: row.date,
                    year: row.year,
                    month: row.month,
                    displayedAmount: row.knownUpcoming
                )
            } label: {
                gridAmountCell(row.knownUpcoming, width: cellWidth, color: .orange)
            }
            .buttonStyle(.plain)

            Button {
                selectedProjectedExpenseMonth = row
            } label: {
                gridAmountCell(row.projectedExpenses, width: cellWidth, color: .blue)
            }
            .buttonStyle(.plain)

            endBalanceCell(row.projectedClosingBalance, width: cellWidth, color: row.endBalanceColor)
        }
        .background(isCurrent ? PocketWiseSemanticColor.budgets.softBackground(for: colorScheme).opacity(0.35) : .clear)
    }

    private func budgetMonthScrollableRow(_ row: BudgetMonthProjection) -> some View {
        budgetMonthScrollableRow(row, snapshot: gridSnapshot)
    }

    private func totalsScrollableRow(snapshot: BudgetGridSnapshot, projectionRows: [BudgetMonthProjection]) -> some View {
        HStack(spacing: 0) {
            gridHeaderCell(store.appLanguage == .arabicEgyptian ? "إجمالي الفترة" : "Period Total", width: rowHeaderWidth)

            ForEach(snapshot.categories, id: \.self) { category in
                let total = snapshot.categoryProjectedTotal(category: category)
                gridAmountCell(total, width: cellWidth, color: .primary)
            }

            gridAmountCell(projectionRows.map(\.plannedIncome).reduce(0, +), width: cellWidth, color: .green)
            gridAmountCell(projectionRows.map(\.plannedExpenses).reduce(0, +), width: cellWidth, color: .primary)
            gridAmountCell(projectionRows.map(\.knownUpcoming).reduce(0, +), width: cellWidth, color: .orange)
            gridAmountCell(projectionRows.map(\.projectedExpenses).reduce(0, +), width: cellWidth, color: .blue)
            gridHeaderCell("-", width: cellWidth)
        }
        .background(Color(.secondarySystemGroupedBackground).opacity(0.7))
        .fontWeight(.bold)
    }

    private var totalsScrollableRow: some View {
        let snapshot = makeGridSnapshot()
        return totalsScrollableRow(snapshot: snapshot, projectionRows: snapshot.projectionRows)
    }

    private func gridHeaderCell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 4)
            .frame(width: width, alignment: .center)
            .frame(minHeight: 42)
    }

    private func gridMonthCell(_ date: Date) -> some View {
        let isCurrent = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
        return HStack(spacing: 0) {
            Rectangle()
                .fill(isCurrent ? PocketWiseSemanticColor.budgets.tint : Color.clear)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(shortMonthTitle(date))
                    .font(.caption)
                    .fontWeight(isCurrent ? .bold : .semibold)
                    .foregroundStyle(isCurrent ? PocketWiseSemanticColor.budgets.tint : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if isCurrent {
                    Text(store.appLanguage == .arabicEgyptian ? "الحالي" : "Current")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(PocketWiseSemanticColor.budgets.tint)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(PocketWiseSemanticColor.budgets.tint.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: rowHeaderWidth, alignment: .leading)
        .frame(minHeight: 46)
        .background(isCurrent ? PocketWiseSemanticColor.budgets.softBackground(for: colorScheme) : .clear)
    }

    private func gridAmountCell(_ amount: Double, width: CGFloat, color: Color) -> some View {
        Text(store.displayCurrency(amount))
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .padding(.horizontal, 4)
            .frame(width: width, alignment: .center)
            .frame(minHeight: 46)
    }

    private func endBalanceCell(_ amount: Double, width: CGFloat, color: Color) -> some View {
        Text(store.displayCurrency(amount))
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .padding(.horizontal, 4)
            .frame(width: width, alignment: .center)
            .frame(minHeight: 46)
    }

    private func gridBudgetCell(_ cell: BudgetGridCellData) -> some View {
        VStack(spacing: 2) {
            Text(store.displayCurrency(cell.mainDisplayAmount))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(cell.mainColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            if cell.knownUpcomingAmount > 0 || cell.paidActualAmount > 0 {
                Text(cell.secondaryLabel(language: store.appLanguage, store: store))
                    .font(.caption2)
                    .foregroundStyle(cell.statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .padding(.horizontal, 4)
        .frame(width: cellWidth, alignment: .center)
        .frame(minHeight: 46)
        .background(cell.backgroundColor)
    }

    private func shortMonthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}

private struct CurrentMonthBudgetView: View {

    @EnvironmentObject private var store: WalletStore
    @State private var selectedMonthDate = BudgetDateHelper.startOfMonth(for: Date())
    @State private var showCopyCurrentForward = false
    @State private var showPlannedIncomeSheet = false
    @State private var showPlannedExpensesSheet = false
    @State private var showActualSpentSheet = false
    @State private var showRemainingSheet = false
    @State private var showObligationsSheet = false
    @State private var showAfterCommittedSheet = false
    @State private var showOpeningBalanceSheet = false
    @State private var showProjectedMonthBalanceSheet = false
    @State private var selectedUpcomingCategory: CategoryUpcomingSelection?
    @State private var selectedCommittedMonth: BudgetCommittedMonthSelection?
    @State private var selectedCategoryAction: BudgetCategoryAction?

    private var monthKey: (year: Int, month: Int) {
        BudgetDateHelper.monthKey(for: selectedMonthDate)
    }

    private var currentMonthSnapshot: CurrentMonthBudgetSnapshot {
        CurrentMonthBudgetSnapshot(
            monthDate: selectedMonthDate,
            availableCash: store.availableCash,
            store: store
        )
    }

    private var plannedByCategory: [String: Double] {
        Dictionary(uniqueKeysWithValues: (store.monthlyBudget(year: monthKey.year, month: monthKey.month)?.items ?? []).map { ($0.categoryName, $0.plannedAmount) })
    }

    private var paidByCategory: [String: Double] {
        store.actualSpendingByCategory(year: monthKey.year, month: monthKey.month)
    }

    private var upcomingByCategory: [String: Double] {
        store.upcomingKnownExpensesByCategory(year: monthKey.year, month: monthKey.month)
    }

    private var categoryNames: [String] {
        var names: [String] = []
        for name in Array(plannedByCategory.keys) + Array(paidByCategory.keys) + Array(upcomingByCategory.keys) {
            if !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                names.append(name)
            }
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var plannedExpenses: Double {
        categoryNames.map { plannedByCategory[$0] ?? 0 }.reduce(0, +)
    }

    private var actualSpent: Double {
        categoryNames.map { paidByCategory[$0] ?? 0 }.reduce(0, +)
    }

    private var knownUpcoming: Double {
        categoryNames.map { upcomingByCategory[$0] ?? 0 }.reduce(0, +)
    }

    private var projectedExpenseExposure: Double {
        categoryNames
            .map { category in
                max(plannedByCategory[category] ?? 0, (paidByCategory[category] ?? 0) + (upcomingByCategory[category] ?? 0))
            }
            .reduce(0, +)
    }

    private var isSelectedCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonthDate, equalTo: Date(), toGranularity: .month)
    }

    private var estimatedOpeningCash: Double {
        if isSelectedCurrentMonth {
            return store.availableCash + actualSpent
        }

        return store.availableCash
    }

    private var plannedIncome: Double {
        store.monthlyBudgetIncome(year: monthKey.year, month: monthKey.month)
    }

    private var projectedClosingBalance: Double {
        estimatedOpeningCash + plannedIncome - projectedExpenseExposure
    }

    private var remaining: Double {
        plannedExpenses - actualSpent
    }

    private var remainingAfterKnown: Double {
        plannedExpenses - actualSpent - knownUpcoming
    }

    var body: some View {
        let snapshot = currentMonthSnapshot

        List {
            Section {
                MonthStepperCard(
                    title: store.appLanguage == .arabicEgyptian ? "الشهر" : "Month",
                    monthDate: $selectedMonthDate,
                    language: store.appLanguage
                )
            }

            Section {
                dashboardSummary(snapshot: snapshot)
            }

            Section(store.appLanguage == .arabicEgyptian ? "تفاصيل البنود" : "Category Breakdown") {
                if snapshot.categoryNames.isEmpty {
                    Text(store.appLanguage == .arabicEgyptian ? "لسه مفيش خطة أو مصاريف للشهر ده." : "No plan or spending for this month yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.categoryNames, id: \.self) { category in
                        currentMonthCategoryRow(category, snapshot: snapshot)
                    }
                }
            }

            Section(store.appLanguage == .arabicEgyptian ? "إجراءات سريعة" : "Quick Actions") {
                NavigationLink {
                    MonthlyBudgetView()
                        .environmentObject(store)
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "تعديل ميزانية الشهر" : "Edit Month Budget", systemImage: "pencil")
                }

                Button {
                    copyPreviousMonth()
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "انسخ من الشهر اللي فات" : "Copy from Previous Month", systemImage: "doc.on.doc")
                }

                Button {
                    showCopyCurrentForward = true
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "انسخ لشهور جاية" : "Copy to Future Months", systemImage: "arrowshape.turn.up.forward")
                }

                NavigationLink {
                    MonthCloseoutView()
                        .environmentObject(store)
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "مراجعة وقفل الشهر" : "Review & Close Month", systemImage: "checkmark.circle")
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showCopyCurrentForward) {
            CopyWholeMonthForwardSheet(sourceMonth: selectedMonthDate)
                .environmentObject(store)
        }
        .sheet(isPresented: $showPlannedIncomeSheet) {
            NavigationStack {
                TransactionsView(
                    initialFilter: TransactionInitialFilter(
                        monthDate: selectedMonthDate,
                        incomeOnly: true
                    )
                )
                .environmentObject(store)
            }
        }
        .sheet(isPresented: $showPlannedExpensesSheet) {
            NavigationStack {
                MonthlyBudgetView(initialMonthDate: selectedMonthDate)
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $showActualSpentSheet) {
            ActualSpentBreakdownSheet(
                monthDate: selectedMonthDate,
                displayedAmount: currentMonthSnapshot.actualSpent
            )
            .environmentObject(store)
        }
        .sheet(isPresented: $showRemainingSheet) {
            NavigationStack {
                MonthlySummaryView(initialMonthDate: selectedMonthDate)
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $showObligationsSheet) {
            NavigationStack {
                ObligationsCenterView()
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $showAfterCommittedSheet) {
            AfterCommittedBreakdownSheet(monthDate: selectedMonthDate)
                .environmentObject(store)
        }
        .sheet(isPresented: $showOpeningBalanceSheet) {
            EstimatedOpeningCashBreakdownSheet(monthDate: selectedMonthDate)
                .environmentObject(store)
        }
        .sheet(isPresented: $showProjectedMonthBalanceSheet) {
            ProjectedMonthBalanceBreakdownSheet(monthDate: selectedMonthDate)
                .environmentObject(store)
        }
        .sheet(item: $selectedCommittedMonth) { selection in
            MonthCommittedBreakdownSheet(selection: selection)
                .environmentObject(store)
        }
        .sheet(item: $selectedUpcomingCategory) { selection in
            CategoryUpcomingBreakdownSheet(selection: selection)
                .environmentObject(store)
        }
        .navigationDestination(item: $selectedCategoryAction) { action in
            switch action {
            case let .planned(monthDate, _):
                MonthlyBudgetView(initialMonthDate: monthDate)
                    .environmentObject(store)
            case let .transactions(categoryName, monthDate):
                TransactionsView(
                    initialFilter: TransactionInitialFilter(
                        categoryName: categoryName,
                        monthDate: monthDate,
                        paidOnly: true
                    )
                )
                .environmentObject(store)
            }
        }
    }

    private func dashboardSummary(snapshot: CurrentMonthBudgetSnapshot) -> some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                Button {
                    showPlannedIncomeSheet = true
                } label: {
                    BudgetMetricCard(
                        title: store.appLanguage == .arabicEgyptian ? "الدخل المخطط" : "Planned Income",
                        value: snapshot.plannedIncome,
                        color: .green,
                        showsDisclosure: true
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showPlannedExpensesSheet = true
                } label: {
                    BudgetMetricCard(
                        title: store.appLanguage == .arabicEgyptian ? "المصاريف المخططة" : "Planned Expenses",
                        value: snapshot.plannedExpenses,
                        showsDisclosure: true
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showActualSpentSheet = true
                } label: {
                    BudgetMetricCard(
                        title: store.appLanguage == .arabicEgyptian ? "المصروف الفعلي" : "Actual Spent",
                        value: snapshot.actualSpent,
                        color: .red,
                        showsDisclosure: true
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showRemainingSheet = true
                } label: {
                    BudgetMetricCard(
                        title: AppText.remaining(store.appLanguage),
                        value: abs(snapshot.remaining),
                        color: snapshot.remaining >= 0 ? .green : .red,
                        showsDisclosure: true
                    )
                }
                .buttonStyle(.plain)

                Button {
                    selectedCommittedMonth = BudgetCommittedMonthSelection(
                        monthDate: snapshot.monthDate,
                        year: snapshot.year,
                        month: snapshot.month,
                        displayedAmount: snapshot.knownUpcoming
                    )
                } label: {
                    BudgetMetricCard(
                        title: AppText.committed(store.appLanguage),
                        value: snapshot.knownUpcoming,
                        color: .orange,
                        showsDisclosure: true
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showAfterCommittedSheet = true
                } label: {
                    BudgetMetricCard(
                        title: store.appLanguage == .arabicEgyptian ? "بعد الملتزم به" : "After Committed",
                        value: abs(snapshot.remainingAfterKnown),
                        color: snapshot.remainingAfterKnown >= 0 ? .green : .red,
                        showsDisclosure: true
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button {
                    showOpeningBalanceSheet = true
                } label: {
                    BudgetMetricCard(
                        title: store.appLanguage == .arabicEgyptian ? "كاش افتتاحي تقديري" : "Estimated Opening Cash",
                        value: snapshot.estimatedOpeningCash,
                        showsDisclosure: true
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showProjectedMonthBalanceSheet = true
                } label: {
                    BudgetMetricCard(
                        title: store.appLanguage == .arabicEgyptian ? "رصيد الشهر المتوقع" : "Projected Month Balance",
                        value: snapshot.projectedClosingBalance,
                        color: snapshot.projectedClosingBalance >= 0 ? .green : .red,
                        showsDisclosure: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func currentMonthCategoryRow(_ category: String, snapshot: CurrentMonthBudgetSnapshot) -> some View {
        let planned = snapshot.plannedByCategory[category] ?? 0
        let paid = snapshot.paidByCategory[category] ?? 0
        let upcoming = snapshot.upcomingByCategory[category] ?? 0
        let afterUpcoming = planned - paid - upcoming

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    PocketWiseIconBadge(
                        systemName: "chart.pie.fill",
                        semanticColor: .budgets,
                        size: 30,
                        cornerRadius: 9
                    )

                    Text(category)
                        .font(.headline)
                }

                Spacer()

                Text(statusText(planned: planned, paid: paid, upcoming: upcoming))
                    .pocketWiseChip(semanticColor: semanticColorForBudgetStatus(planned: planned, paid: paid, upcoming: upcoming))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                Button {
                    selectedCategoryAction = .planned(monthDate: selectedMonthDate, categoryName: category)
                } label: {
                    BudgetMetricCard(title: AppText.planned(store.appLanguage), value: planned)
                }
                .buttonStyle(.plain)

                Button {
                    selectedCategoryAction = .transactions(categoryName: category, monthDate: selectedMonthDate)
                } label: {
                    BudgetMetricCard(title: store.appLanguage == .arabicEgyptian ? "المدفوع" : "Paid", value: paid)
                }
                .buttonStyle(.plain)

                Button {
                    selectedUpcomingCategory = CategoryUpcomingSelection(
                        monthDate: selectedMonthDate,
                        year: monthKey.year,
                        month: monthKey.month,
                        categoryName: category,
                        displayedAmount: upcoming
                    )
                } label: {
                    BudgetMetricCard(
                        title: AppText.upcoming(store.appLanguage),
                        value: upcoming,
                        showsDisclosure: true
                    )
                }
                .buttonStyle(.plain)

                BudgetMetricCard(title: store.appLanguage == .arabicEgyptian ? "بعد الجاي" : "After Upcoming", value: abs(afterUpcoming), color: afterUpcoming >= 0 ? .green : .red)
            }
        }
        .pocketWiseCard(
            semanticColor: .budgets,
            padding: 12,
            cornerRadius: 14,
            showsBorder: true
        )
    }

    private func semanticColorForBudgetStatus(planned: Double, paid: Double, upcoming: Double) -> PocketWiseSemanticColor {
        let afterUpcoming = planned - paid - upcoming

        if planned <= 0 && paid <= 0 && upcoming <= 0 {
            return .neutral
        }

        return afterUpcoming >= 0 ? .success : .warning
    }

    private func copyPreviousMonth() {
        let previous = BudgetDateHelper.addMonths(-1, to: selectedMonthDate)
        let previousKey = BudgetDateHelper.monthKey(for: previous)
        store.copyMonthlyBudget(from: previousKey.year, sourceMonth: previousKey.month, to: monthKey.year, targetMonth: monthKey.month)
    }

    private func statusText(planned: Double, paid: Double, upcoming: Double) -> String {
        if planned <= 0 && upcoming > 0 { return store.appLanguage == .arabicEgyptian ? "جاي مش متخطط" : "Unplanned upcoming" }
        if planned > 0 && paid > planned { return store.appLanguage == .arabicEgyptian ? "فوق الخطة" : "Over plan" }
        if planned > 0 && paid + upcoming > planned { return store.appLanguage == .arabicEgyptian ? "محتاج متابعة" : "Watch" }
        return store.appLanguage == .arabicEgyptian ? "ماشي كويس" : "On track"
    }

    private func statusColor(planned: Double, paid: Double, upcoming: Double) -> Color {
        if planned <= 0 && upcoming > 0 { return .orange }
        if planned > 0 && paid > planned { return .red }
        if planned > 0 && paid + upcoming > planned { return .orange }
        return .green
    }
}

private struct BudgetSetupView: View {

    @EnvironmentObject private var store: WalletStore
    @State private var isAddingRecurringPayment = false
    @State private var isAddingInstallmentPlan = false
    @State private var isEditingFallbackSpending = false

    var body: some View {
        List {
            Section(store.appLanguage == .arabicEgyptian ? "أدوات الإعداد" : "Setup Tools") {
                NavigationLink {
                    MultiMonthPlannerView()
                        .environmentObject(store)
                } label: {
                    setupRow(
                        title: store.appLanguage == .arabicEgyptian ? "انسخ شهر لشهور جاية" : "Copy Month to Future Months",
                        subtitle: store.appLanguage == .arabicEgyptian ? "انسخ ميزانية شهر واحد لشهور بعده" : "Copy one month budget to multiple future months",
                        icon: "doc.on.doc"
                    )
                }

                NavigationLink {
                    HistoricalSummaryView()
                        .environmentObject(store)
                } label: {
                    setupRow(
                        title: store.appLanguage == .arabicEgyptian ? "تسجيل شهور قديمة بسرعة" : "Fast Log Past Month Totals",
                        subtitle: store.appLanguage == .arabicEgyptian ? "إجماليات قديمة من غير ما تغيّر الأرصدة" : "Enter old month totals quickly without transactions",
                        icon: "clock.arrow.circlepath"
                    )
                }

                NavigationLink {
                    CategoryManagementView()
                        .environmentObject(store)
                } label: {
                    setupRow(
                        title: store.appLanguage == .arabicEgyptian ? "البنود والتصنيفات" : "Categories",
                        subtitle: store.appLanguage == .arabicEgyptian ? "إدارة بنود الميزانية والتصنيفات" : "Manage budget categories and groups",
                        icon: "list.bullet"
                    )
                }

                NavigationLink {
                    AccountManagementView()
                        .environmentObject(store)
                } label: {
                    setupRow(
                        title: store.appLanguage == .arabicEgyptian ? "الحسابات / الأرصدة الافتتاحية" : "Accounts / Opening Balances",
                        subtitle: store.appLanguage == .arabicEgyptian ? "راجع أرصدة الحسابات اللي بتبدأ منها الخطة" : "Review account balances used to start planning",
                        icon: "banknote"
                    )
                }

                NavigationLink {
                    AppPreferencesView()
                        .environmentObject(store)
                } label: {
                    setupRow(
                        title: store.appLanguage == .arabicEgyptian ? "مدة التوقع وإعدادات الدخل" : "Forecast Horizon & Income Settings",
                        subtitle: store.appLanguage == .arabicEgyptian ? "اضبط مدة التوقع وافتراضات الدخل" : "Set planning horizon and income assumptions",
                        icon: "gauge.with.dots.needle.bottom.50percent"
                    )
                }

                Button {
                    isEditingFallbackSpending = true
                } label: {
                    setupRow(
                        title: store.appLanguage == .arabicEgyptian ? "تقدير شهري احتياطي عند عدم وجود ميزانية" : "Default monthly spending fallback",
                        subtitle: store.appLanguage == .arabicEgyptian ? "يستخدم فقط إذا لم يتم إدخال ميزانية للشهر المختار" : "Used only when no monthly budget is set for the selected month",
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
                .buttonStyle(.plain)
            }

            Section(store.appLanguage == .arabicEgyptian ? "اختصارات التخطيط" : "Planning Shortcuts") {
                Button {
                    isAddingRecurringPayment = true
                } label: {
                    setupRow(
                        title: store.appLanguage == .arabicEgyptian ? "أضف دفع متكرر" : "Add Recurring Payment",
                        subtitle: store.appLanguage == .arabicEgyptian ? "اختصار إضافة فقط. إدارة المتكرر من مركز التخطيط." : "Add shortcut only. Manage recurring items in Planning Center.",
                        icon: "calendar.badge.plus"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    isAddingInstallmentPlan = true
                } label: {
                    setupRow(
                        title: store.appLanguage == .arabicEgyptian ? "أضف تقسيط" : "Add Installment Plan",
                        subtitle: store.appLanguage == .arabicEgyptian ? "اختصار إضافة فقط. إدارة الأقساط من مركز التخطيط." : "Add shortcut only. Manage installment plans in Planning Center.",
                        icon: "creditcard.and.123"
                    )
                }
                .buttonStyle(.plain)
            }

        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $isAddingRecurringPayment) {
            AddRecurringPaymentView()
                .environmentObject(store)
        }
        .sheet(isPresented: $isAddingInstallmentPlan) {
            AddInstallmentPlanView()
                .environmentObject(store)
        }
        .sheet(isPresented: $isEditingFallbackSpending) {
            FlexibleSpendingEditorView()
                .environmentObject(store)
        }
    }

    private func setupRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(
                systemName: icon,
                semanticColor: .budgets,
                size: 34,
                cornerRadius: 10
            )

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
        }
        .padding(.vertical, 4)
    }
}

struct ObligationsCenterView: View {

    @EnvironmentObject private var store: WalletStore

    private var recurringPayments: [RecurringObligationPreview] {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()

        return (0..<12)
            .compactMap { calendar.date(byAdding: .month, value: $0, to: start) }
            .flatMap { monthDate -> [RecurringObligationPreview] in
                let components = calendar.dateComponents([.year, .month], from: monthDate)
                guard let year = components.year, let month = components.month else {
                    return []
                }

                return store.upcomingKnownExpenseEvents(year: year, month: month)
                    .compactMap { occurrence in
                        guard let sourceID = occurrence.sourceRecurringEventID,
                              let source = store.activeFinancialEvents.first(where: { $0.id == sourceID }) else {
                            return nil
                        }

                        return RecurringObligationPreview(source: source, occurrence: occurrence)
                    }
            }
            .sorted { $0.occurrence.date < $1.occurrence.date }
    }

    private var installmentPlans: [InstallmentPlan] {
        store.activeInstallmentPlans.sorted {
            let first = store.installmentPlanSummary(for: $0).nextDueDate ?? $0.firstDueDate
            let second = store.installmentPlanSummary(for: $1).nextDueDate ?? $1.firstDueDate
            return first < second
        }
    }

    private var creditCardDueItems: [CreditCardDueItem] {
        store.creditCardDueItems(referenceDate: Date(), horizonMonths: store.forecastHorizonMonths)
    }

    private var futureExpenseItems: [FinancialEvent] {
        store.activeFinancialEvents
            .filter { event in
                event.repeatRule == .none &&
                event.sourceInstallmentPlanID == nil &&
                event.status != .paid &&
                event.status != .cancelled &&
                event.type != .income &&
                event.type != .transfer
            }
            .sorted { $0.date < $1.date }
    }

    private var expectedIncomeItems: [FinancialEvent] {
        store.activeFinancialEvents
            .filter { event in
                event.repeatRule == .none &&
                event.status != .paid &&
                event.status != .cancelled &&
                event.type == .income
            }
            .sorted { $0.date < $1.date }
    }

    private var expectedRepayments: [FinancialEvent] {
        store.expectedRepaymentEvents().sorted { $0.date < $1.date }
    }

    private var recurringUpcomingTotal: Double {
        recurringPayments.map(\.occurrence.amount).reduce(0, +)
    }

    private var installmentRemainingTotal: Double {
        installmentPlans
            .map { store.installmentPlanSummary(for: $0).remainingUnpaidAmount }
            .reduce(0, +)
    }

    private var creditCardDueTotal: Double {
        creditCardDueItems.map(\.dueAmount).reduce(0, +)
    }

    private var futureExpenseTotal: Double {
        futureExpenseItems.map(\.amount).reduce(0, +)
    }

    private var expectedIncomeTotal: Double {
        expectedIncomeItems.map(\.amount).reduce(0, +)
    }

    private var expectedRepaymentTotal: Double {
        expectedRepayments.map(\.amount).reduce(0, +)
    }

    var body: some View {
        List {
            Section {
                Text(store.appLanguage == .arabicEgyptian ? "التزامات قادمة، فلوس داخلة متوقعة، وسداد." : "Upcoming commitments, expected money in, and repayments.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                if recurringPayments.isEmpty {
                    emptyText(store.appLanguage == .arabicEgyptian ? "مفيش التزامات متكررة." : "No recurring obligations.")
                } else {
                    ForEach(recurringPayments) { preview in
                        NavigationLink {
                            RecurringSeriesDetailView(eventID: preview.source.id)
                                .environmentObject(store)
                        } label: {
                            obligationRow(
                                icon: "repeat",
                                title: preview.occurrence.title,
                                amount: preview.occurrence.amount,
                                date: preview.occurrence.date,
                                subtitle: "\(preview.source.repeatRule.rawValue) • \(preview.occurrence.subCategoryName ?? preview.occurrence.categoryName ?? preview.occurrence.type.rawValue)",
                                status: recurringStatus(for: preview.occurrence)
                            )
                        }
                    }
                }
            } header: {
                recurringSummaryHeader
            }

            Section(
                summaryHeader(
                    title: AppText.installments(store.appLanguage),
                    count: installmentPlans.count,
                    amount: installmentRemainingTotal,
                    qualifier: AppText.remainingUnpaid(store.appLanguage)
                )
            ) {
                if installmentPlans.isEmpty {
                    emptyText(store.appLanguage == .arabicEgyptian ? "مفيش خطط تقسيط." : "No installment plans.")
                } else {
                    ForEach(installmentPlans) { plan in
                        NavigationLink {
                            InstallmentPlanEditorView(plan: plan)
                                .environmentObject(store)
                        } label: {
                            let summary = store.installmentPlanSummary(for: plan)
                            obligationRow(
                                icon: "creditcard.and.123",
                                title: "\(plan.paymentMethodName) - \(plan.purchaseName)",
                                amount: plan.monthlyAmount,
                                date: summary.nextDueDate ?? plan.firstDueDate,
                                subtitle: "\(summary.paidCount) paid of \(summary.totalCount) • \(plan.subCategoryName)",
                                status: summary.remainingUnpaidAmount > 0 ? activeText : endedText
                            )
                        }
                    }
                }
            }

            Section(
                summaryHeader(
                    title: store.appLanguage == .arabicEgyptian ? "مستحقات كروت الائتمان" : "Credit Card Dues",
                    count: creditCardDueItems.count,
                    amount: creditCardDueTotal,
                    qualifier: store.appLanguage == .arabicEgyptian ? "مستحق" : "due"
                )
            ) {
                if creditCardDueItems.isEmpty {
                    emptyText(store.appLanguage == .arabicEgyptian ? "مفيش مستحقات كروت ائتمان غير مدفوعة." : "No unpaid credit card dues.")
                } else {
                    ForEach(creditCardDueItems) { item in
                        obligationRow(
                            icon: "creditcard.trianglebadge.exclamationmark",
                            title: item.cardName,
                            amount: item.dueAmount,
                            date: item.dueDate,
                            subtitle: store.appLanguage == .arabicEgyptian
                            ? "التزام كاش لسداد الكارت - مش مصروف جديد"
                            : "Cash obligation to pay the card - not new spending",
                            status: creditCardDueStatus(for: item.dueDate)
                        )
                    }
                }
            }

            Section(
                summaryHeader(
                    title: store.appLanguage == .arabicEgyptian ? "بنود مخططة / غير مدفوعة" : "Planned / Unpaid Items",
                    count: futureExpenseItems.count,
                    amount: futureExpenseTotal,
                    qualifier: AppText.planned(store.appLanguage).lowercased()
                )
            ) {
                if futureExpenseItems.isEmpty {
                    emptyText(store.appLanguage == .arabicEgyptian ? "مفيش بنود مخططة أو غير مدفوعة." : "No planned or unpaid items.")
                } else {
                    ForEach(futureExpenseItems) { event in
                        NavigationLink {
                            TransactionDetailView(event: event, isPresentedModally: false)
                                .environmentObject(store)
                        } label: {
                            obligationRow(
                                icon: "calendar",
                                title: event.title,
                                amount: event.amount,
                                date: event.date,
                                subtitle: event.subCategoryName ?? event.categoryName ?? event.type.rawValue,
                                status: event.status.rawValue
                            )
                        }
                    }
                }
            }

            Section(
                summaryHeader(
                    title: AppText.expectedIncome(store.appLanguage),
                    count: expectedIncomeItems.count,
                    amount: expectedIncomeTotal,
                    qualifier: AppText.total(store.appLanguage)
                )
            ) {
                if expectedIncomeItems.isEmpty {
                    emptyText(store.appLanguage == .arabicEgyptian ? "مفيش دخل متوقع." : "No expected income.")
                } else {
                    ForEach(expectedIncomeItems) { event in
                        NavigationLink {
                            TransactionDetailView(event: event, isPresentedModally: false)
                                .environmentObject(store)
                        } label: {
                            obligationRow(
                                icon: "arrow.down.circle",
                                title: event.title,
                                amount: event.amount,
                                date: event.date,
                                subtitle: event.effectiveIncomeType.title(language: store.appLanguage),
                                status: event.status.rawValue
                            )
                        }
                    }
                }
            }

            Section(
                summaryHeader(
                    title: AppText.peopleDebts(store.appLanguage),
                    count: expectedRepayments.count,
                    amount: expectedRepaymentTotal,
                    qualifier: AppText.total(store.appLanguage)
                )
            ) {
                if !expectedRepayments.isEmpty {
                    ForEach(expectedRepayments) { event in
                        NavigationLink {
                            PeopleDebtsView()
                                .environmentObject(store)
                        } label: {
                            obligationRow(
                                icon: "person.2",
                                title: event.title,
                                amount: event.amount,
                                date: event.date,
                                subtitle: store.appLanguage == .arabicEgyptian ? "سداد متوقع" : "Expected repayment",
                                status: peopleDebtDueStatus(for: event.date)
                            )
                        }
                    }
                }

                NavigationLink {
                    PeopleDebtsView()
                        .environmentObject(store)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2")
                            .font(.headline)
                            .frame(width: 34, height: 34)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.appLanguage == .arabicEgyptian ? "افتح الأشخاص والديون" : "Open People & Debts")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            Text(store.appLanguage == .arabicEgyptian ? "إدارة السلف، الديون، والسداد" : "Manage money lent, borrowed, and repayments")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "مركز التخطيط" : "Planning Center")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summaryHeader(title: String, count: Int, amount: Double, qualifier: String) -> String {
        "\(title) • \(count) • \(store.displayCurrency(amount)) \(qualifier)"
    }

    private var recurringSummaryHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(store.appLanguage == .arabicEgyptian ? "دفعات متكررة قادمة" : "Upcoming recurring payments") • \(recurringPayments.count)")
            Text("\(store.appLanguage == .arabicEgyptian ? "الـ ١٢ شهر الجايين" : "Next 12 months") • \(store.displayCurrency(recurringUpcomingTotal))")
            Text(store.appLanguage == .arabicEgyptian ? "مولدة من قواعد الدفع المتكرر. المدفوع والمتخطي غير محسوب هنا." : "Generated from recurring rules. Paid and skipped occurrences are not included here.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
    }

    private var activeText: String {
        store.appLanguage == .arabicEgyptian ? "نشط" : "Active"
    }

    private var upcomingPaymentText: String {
        store.appLanguage == .arabicEgyptian ? "دفعة قادمة" : "Upcoming payment"
    }

    private var endedText: String {
        store.appLanguage == .arabicEgyptian ? "منتهي" : "Ended"
    }

    private var overdueText: String {
        store.appLanguage == .arabicEgyptian ? "متأخر" : "Overdue"
    }

    private func peopleDebtDueStatus(for date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())

        if day < today {
            return overdueText
        }

        if day == today {
            return store.appLanguage == .arabicEgyptian ? "مستحق اليوم" : "Due today"
        }

        return upcomingPaymentText
    }

    private func creditCardDueStatus(for date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())
        let dueSoonEnd = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today

        if day < today {
            return overdueText
        }

        if day == today {
            return store.appLanguage == .arabicEgyptian ? "مستحق اليوم" : "Due today"
        }

        if day < dueSoonEnd {
            return store.appLanguage == .arabicEgyptian ? "قريب" : "Due soon"
        }

        return store.appLanguage == .arabicEgyptian ? "غير مدفوع" : "Unpaid"
    }

    private func obligationRow(icon: String, title: String, amount: Double, date: Date, subtitle: String, status: String) -> some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(
                systemName: icon,
                semanticColor: .obligations,
                size: 34,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(store.displayCurrency(amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(PocketWiseSemanticColor.obligations.tint)

                Text(formatDate(date))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(status)
                    .pocketWiseChip(semanticColor: .obligations)
            }
        }
        .padding(.vertical, 4)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }

    private func recurringStatus(for event: FinancialEvent) -> String {
        if event.isRecurringOccurrenceSkipped(on: event.date) {
            return store.appLanguage == .arabicEgyptian ? "متخطي" : "Skipped"
        }

        if event.effectiveRecurringAmountMode != .fixedAmount {
            return store.appLanguage == .arabicEgyptian ? "يحتاج تأكيد" : "Needs confirmation"
        }

        return upcomingPaymentText
    }

    private func nextDate(for event: FinancialEvent) -> Date? {
        RecurringSeriesDateHelper.nextOccurrence(for: event, from: Date())
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

private struct RecurringObligationPreview: Identifiable {
    let source: FinancialEvent
    let occurrence: FinancialEvent

    var id: String {
        "\(source.id.uuidString)-\(occurrence.recurringOccurrenceYear ?? 0)-\(occurrence.recurringOccurrenceMonth ?? 0)"
    }
}

private struct RecurringSeriesDetailView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let eventID: UUID

    @State private var isEditingSeries = false
    @State private var confirmation: SeriesConfirmation?
    @State private var occurrenceToSkip: Date?
    @State private var amountSelection: RecurringOccurrenceSelection?
    @State private var paidSelection: RecurringOccurrenceSelection?

    private var event: FinancialEvent? {
        store.activeFinancialEvents.first { $0.id == eventID }
    }

    var body: some View {
        List {
            if let event {
                Section(store.appLanguage == .arabicEgyptian ? "السلسلة" : "Series") {
                    detailRow(store.appLanguage == .arabicEgyptian ? "الاسم" : "Name", event.title)
                    detailRow(store.appLanguage == .arabicEgyptian ? "المبلغ" : "Amount", store.displayCurrency(event.amount))
                    detailRow(store.appLanguage == .arabicEgyptian ? "التصنيف" : "Category", event.subCategoryName ?? event.categoryName ?? "Not set")
                    detailRow(store.appLanguage == .arabicEgyptian ? "الحساب" : "Account", event.accountName ?? "Not set")
                    detailRow(store.appLanguage == .arabicEgyptian ? "التكرار" : "Frequency", event.repeatRule.rawValue)
                    detailRow(store.appLanguage == .arabicEgyptian ? "نوع المبلغ" : "Amount Mode", event.effectiveRecurringAmountMode.title(language: store.appLanguage))
                    if event.effectiveRecurringAmountMode != .fixedAmount {
                        detailRow(store.appLanguage == .arabicEgyptian ? "المبلغ التقديري" : "Estimated amount", store.displayCurrency(event.effectiveRecurringEstimatedAmount))
                    }
                    detailRow(store.appLanguage == .arabicEgyptian ? "تاريخ البداية" : "Start date", formatDate(event.date))
                    detailRow(store.appLanguage == .arabicEgyptian ? "ينتهي" : "End condition", endConditionText(for: event))

                    if let nextDate = RecurringSeriesDateHelper.nextOccurrence(for: event, from: Date()) {
                        detailRow(store.appLanguage == .arabicEgyptian ? "أقرب استحقاق" : "Next due date", formatDate(nextDate))
                    }
                }

                Section(store.appLanguage == .arabicEgyptian ? "الشهور الجاية" : "Upcoming Preview") {
                    let dates = RecurringSeriesDateHelper.upcomingOccurrences(for: event, from: Date(), limit: 6)
                    if dates.isEmpty {
                        Text(store.appLanguage == .arabicEgyptian ? "مفيش شهور جاية حسب إعدادات السلسلة." : "No upcoming months based on this series setup.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(dates, id: \.self) { date in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(formatMonth(date))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)

                                        Text(occurrenceStatusText(for: event, date: date))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(occurrenceAmountText(for: event, date: date))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }

                                if store.paidRecurringOccurrence(sourceID: event.id, year: occurrenceYearMonth(date).year, month: occurrenceYearMonth(date).month) == nil {
                                    HStack {
                                        if event.effectiveRecurringAmountMode != .fixedAmount {
                                            Button(store.appLanguage == .arabicEgyptian ? "تأكيد المبلغ" : "Confirm amount") {
                                                amountSelection = RecurringOccurrenceSelection(eventID: event.id, date: date)
                                            }
                                            .buttonStyle(.borderless)
                                        }

                                        Button(store.appLanguage == .arabicEgyptian ? "تسجيل كمدفوع" : "Mark Paid") {
                                            paidSelection = RecurringOccurrenceSelection(eventID: event.id, date: date)
                                        }
                                        .buttonStyle(.borderless)

                                        Button(role: .destructive) {
                                            occurrenceToSkip = date
                                            confirmation = .skipThisMonth
                                        } label: {
                                            Text(store.appLanguage == .arabicEgyptian ? "تخطي" : "Skip")
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    .font(.caption)
                                }
                            }
                        }
                    }
                }

                Section(store.appLanguage == .arabicEgyptian ? "إجراءات" : "Actions") {
                    Button {
                        isEditingSeries = true
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "تعديل السلسلة" : "Edit series", systemImage: "pencil")
                    }

                    Button {
                        occurrenceToSkip = Date()
                        confirmation = .skipThisMonth
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "حذف هذا الشهر فقط" : "Delete this occurrence only", systemImage: "calendar.badge.minus")
                    }

                    Button {
                        confirmation = .endAfterThisMonth
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "إنهاء بعد هذا الشهر" : "End after this month", systemImage: "calendar.badge.exclamationmark")
                    }

                    Button(role: .destructive) {
                        confirmation = .deleteSeries
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "حذف السلسلة بالكامل" : "Delete entire series", systemImage: "trash")
                    }
                    .disabled(event.status == .paid)
                }

                if event.status == .paid {
                    Section {
                        Text(store.appLanguage == .arabicEgyptian ? "السلسلة دي ظاهرة كمدفوعة. لا يتم حذف معاملات مدفوعة من هنا؛ افتح تفاصيل المعاملة للحذف العادي." : "This series appears paid. Paid transactions are not deleted here; open transaction detail for normal deletion.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(store.appLanguage == .arabicEgyptian ? "السلسلة غير موجودة." : "Series not found.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "إدارة السلسلة" : "Manage Series")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditingSeries) {
            if let event {
                RecurringPaymentEditorView(event: event)
                    .environmentObject(store)
            }
        }
        .sheet(item: $amountSelection) { selection in
            if let event {
                RecurringOccurrenceAmountSheet(event: event, occurrenceDate: selection.date)
                    .environmentObject(store)
            }
        }
        .sheet(item: $paidSelection) { selection in
            if let event {
                UpcomingPaymentConfirmationSheet(event: event, occurrenceDate: selection.date)
                    .environmentObject(store)
            }
        }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { confirmation != nil },
                set: { if !$0 { confirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let confirmation {
                Button(confirmation.confirmButtonTitle(language: store.appLanguage), role: confirmation.role) {
                    perform(confirmation)
                    self.confirmation = nil
                }
            }

            Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel", role: .cancel) {
                confirmation = nil
            }
        } message: {
            Text(confirmation?.message(language: store.appLanguage) ?? "")
        }
    }

    private var confirmationTitle: String {
        confirmation?.title(language: store.appLanguage) ?? ""
    }

    private func perform(_ confirmation: SeriesConfirmation) {
        guard var event else {
            return
        }

        switch confirmation {
        case .skipThisMonth:
            let components = Calendar.current.dateComponents([.year, .month], from: occurrenceToSkip ?? Date())
            guard let year = components.year, let month = components.month else { return }
            var overrides = event.recurringScheduleOverrides ?? []
            let override = RecurringScheduleOverride(
                year: year,
                month: month,
                amount: 0,
                isSkipped: true,
                note: store.appLanguage == .arabicEgyptian ? "تم الحذف من مركز التخطيط" : "Deleted from Planning Center",
                updatedAt: Date()
            )

            if let index = overrides.firstIndex(where: { $0.year == year && $0.month == month }) {
                overrides[index] = override
            } else {
                overrides.append(override)
            }

            event.recurringScheduleOverrides = overrides
            store.updateFinancialEvent(event)
            occurrenceToSkip = nil

        case .endAfterThisMonth:
            event.recurringEndKind = .onDate
            event.recurringEndDate = endOfCurrentMonth()
            event.recurringEndPaymentCount = nil
            store.updateFinancialEvent(event)

        case .deleteSeries:
            guard event.status != .paid else { return }
            store.deleteFinancialEvent(event)
            dismiss()
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func endConditionText(for event: FinancialEvent) -> String {
        switch event.effectiveRecurringEndKind {
        case .never:
            return store.appLanguage == .arabicEgyptian ? "بدون نهاية" : "Never"
        case .onDate:
            return event.recurringEndDate.map(formatDate) ?? (store.appLanguage == .arabicEgyptian ? "تاريخ غير محدد" : "Date not set")
        case .afterNumberOfPayments:
            let count = event.recurringEndPaymentCount ?? 0
            return store.appLanguage == .arabicEgyptian ? "بعد \(count) دفعات" : "After \(count) payments"
        }
    }

    private func endOfCurrentMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        let start = calendar.date(from: components) ?? Date()
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? start
    }

    private func occurrenceStatusText(for event: FinancialEvent, date: Date) -> String {
        let key = occurrenceYearMonth(date)
        if store.paidRecurringOccurrence(sourceID: event.id, year: key.year, month: key.month) != nil {
            return store.appLanguage == .arabicEgyptian ? "مدفوع" : "Paid"
        }

        if event.isRecurringOccurrenceSkipped(on: date) {
            return store.appLanguage == .arabicEgyptian ? "متخطي" : "Skipped"
        }

        if event.recurringOverride(for: date) != nil {
            return store.appLanguage == .arabicEgyptian ? "مؤكد" : "Confirmed"
        }

        if event.effectiveRecurringAmountMode == .fixedAmount {
            return store.appLanguage == .arabicEgyptian ? "ثابت" : "Fixed"
        }

        return store.appLanguage == .arabicEgyptian ? "تقديري" : "Estimated"
    }

    private func occurrenceAmountText(for event: FinancialEvent, date: Date) -> String {
        let key = occurrenceYearMonth(date)
        if let paid = store.paidRecurringOccurrence(sourceID: event.id, year: key.year, month: key.month) {
            return store.displayCurrency(paid.amount)
        }

        if event.isRecurringOccurrenceSkipped(on: date) {
            return "-"
        }

        return store.displayCurrency(event.recurringAmount(for: date))
    }

    private func occurrenceYearMonth(_ date: Date) -> (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return (components.year ?? 0, components.month ?? 0)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    private enum SeriesConfirmation: Identifiable {
        case skipThisMonth
        case endAfterThisMonth
        case deleteSeries

        var id: String {
            switch self {
            case .skipThisMonth: return "skipThisMonth"
            case .endAfterThisMonth: return "endAfterThisMonth"
            case .deleteSeries: return "deleteSeries"
            }
        }

        var role: ButtonRole? {
            self == .deleteSeries ? .destructive : nil
        }

        func title(language: AppLanguage) -> String {
            switch self {
            case .skipThisMonth:
                return language == .arabicEgyptian ? "حذف هذا الشهر فقط؟" : "Delete this occurrence only?"
            case .endAfterThisMonth:
                return language == .arabicEgyptian ? "إنهاء بعد هذا الشهر؟" : "End after this month?"
            case .deleteSeries:
                return language == .arabicEgyptian ? "حذف السلسلة بالكامل؟" : "Delete entire series?"
            }
        }

        func confirmButtonTitle(language: AppLanguage) -> String {
            switch self {
            case .skipThisMonth:
                return language == .arabicEgyptian ? "حذف هذا الشهر فقط" : "Delete this occurrence only"
            case .endAfterThisMonth:
                return language == .arabicEgyptian ? "إنهاء بعد هذا الشهر" : "End after this month"
            case .deleteSeries:
                return language == .arabicEgyptian ? "حذف السلسلة بالكامل" : "Delete entire series"
            }
        }

        func message(language: AppLanguage) -> String {
            switch self {
            case .skipThisMonth:
                return language == .arabicEgyptian ? "سيتم حذف هذا الشهر فقط، وستستمر الشهور القادمة." : "This removes only this unpaid occurrence. Future months will continue."
            case .endAfterThisMonth:
                return language == .arabicEgyptian ? "سيتم الاحتفاظ بالسجلات السابقة وإيقاف الشهور القادمة بعد هذا الشهر." : "This keeps past records and stops future months after this month."
            case .deleteSeries:
                return language == .arabicEgyptian ? "سيتم حذف قاعدة التكرار والبنود المستقبلية غير المدفوعة فقط. المعاملات المدفوعة لن يتم حذفها." : "This removes the recurring rule and unpaid future occurrences. Paid transactions will not be deleted."
            }
        }
    }
}

private struct RecurringOccurrenceSelection: Identifiable {
    let eventID: UUID
    let date: Date

    var id: String {
        "\(eventID.uuidString)-\(date.timeIntervalSince1970)"
    }
}

private struct RecurringOccurrenceAmountSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let event: FinancialEvent
    let occurrenceDate: Date

    @State private var amountText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(store.appLanguage == .arabicEgyptian ? "تأكيد المبلغ" : "Confirm Amount") {
                    Text(event.title)
                        .font(.headline)

                    Text(formatMonth(occurrenceDate))
                        .foregroundStyle(.secondary)

                    TextField(store.appLanguage == .arabicEgyptian ? "مبلغ هذا الشهر" : "This month amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .obligations, isProminent: true)
                }

                Section {
                    Button {
                        saveAmount()
                    } label: {
                        HStack {
                            Spacer()
                            Text(store.appLanguage == .arabicEgyptian ? "احفظ المبلغ" : "Save Amount")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(amount <= 0)
                } footer: {
                    Text(store.appLanguage == .arabicEgyptian ? "تأكيد المبلغ لا يغيّر الرصيد. الرصيد يتغير فقط عند التسجيل كمدفوع." : "Confirming amount does not change balance. Balance changes only when marked paid.")
                }
            }
            .navigationTitle(store.appLanguage == .arabicEgyptian ? "تأكيد الشهر" : "Confirm Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                amountText = cleanNumberText(event.recurringAmount(for: occurrenceDate))
            }
        }
    }

    private var amount: Double {
        parseAmountText(amountText)
    }

    private func saveAmount() {
        var updatedEvent = event
        let components = Calendar.current.dateComponents([.year, .month], from: occurrenceDate)
        guard let year = components.year,
              let month = components.month else {
            return
        }

        let override = RecurringScheduleOverride(
            year: year,
            month: month,
            amount: amount,
            isSkipped: false,
            note: store.appLanguage == .arabicEgyptian ? "مبلغ مؤكد" : "Confirmed amount",
            updatedAt: Date()
        )

        var overrides = updatedEvent.recurringScheduleOverrides ?? []
        if let index = overrides.firstIndex(where: { $0.year == year && $0.month == month }) {
            overrides[index] = override
        } else {
            overrides.append(override)
        }

        updatedEvent.recurringScheduleOverrides = overrides
        store.updateFinancialEvent(updatedEvent)
        dismiss()
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func cleanNumberText(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(value)
    }
}

private func parseAmountText(_ text: String) -> Double {
    let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return 0 }

    if cleaned.contains(",") && cleaned.contains(".") {
        return Double(cleaned.replacingOccurrences(of: ",", with: "")) ?? 0
    }

    if cleaned.contains(",") {
        let parts = cleaned.split(separator: ",")
        if let last = parts.last, last.count == 3 {
            return Double(cleaned.replacingOccurrences(of: ",", with: "")) ?? 0
        }

        return Double(cleaned.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    return Double(cleaned) ?? 0
}

private enum RecurringSeriesDateHelper {
    static func nextOccurrence(for event: FinancialEvent, from date: Date) -> Date? {
        upcomingOccurrences(for: event, from: date, limit: 1).first
    }

    static func upcomingOccurrences(for event: FinancialEvent, from date: Date, limit: Int) -> [Date] {
        guard event.repeatRule != .none, limit > 0 else {
            return []
        }

        var dates: [Date] = []
        var occurrenceDate = event.date
        var occurrenceNumber = 1
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: date)

        while occurrenceDate < startOfToday {
            guard let nextDate = nextDate(after: occurrenceDate, rule: event.repeatRule) else {
                return dates
            }
            occurrenceDate = nextDate
            occurrenceNumber += 1
        }

        var safetyCounter = 0
        while dates.count < limit && safetyCounter < 120 {
            guard event.allowsRecurringOccurrence(on: occurrenceDate, occurrenceNumber: occurrenceNumber) else {
                break
            }

            dates.append(occurrenceDate)

            guard let nextDate = nextDate(after: occurrenceDate, rule: event.repeatRule) else {
                break
            }
            occurrenceDate = nextDate
            occurrenceNumber += 1
            safetyCounter += 1
        }

        return dates
    }

    private static func nextDate(after date: Date, rule: RepeatRule) -> Date? {
        let calendar = Calendar.current
        switch rule {
        case .none:
            return nil
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
}

private struct BudgetCellEditSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let selection: BudgetCellSelection
    let visibleMonths: [Date]
    let onUseCommittedAsBudget: (BudgetCellSelection) -> Void
    let onCopyToFuture: (BudgetCellSelection) -> Void
    let onApplyAcrossMonths: (BudgetCellSelection) -> Void

    @State private var amountText: String
    @State private var isShowingCommittedBreakdown = false
    @State private var isShowingPaidBreakdown = false

    init(
        selection: BudgetCellSelection,
        visibleMonths: [Date],
        onUseCommittedAsBudget: @escaping (BudgetCellSelection) -> Void,
        onCopyToFuture: @escaping (BudgetCellSelection) -> Void,
        onApplyAcrossMonths: @escaping (BudgetCellSelection) -> Void
    ) {
        self.selection = selection
        self.visibleMonths = visibleMonths
        self.onUseCommittedAsBudget = onUseCommittedAsBudget
        self.onCopyToFuture = onCopyToFuture
        self.onApplyAcrossMonths = onApplyAcrossMonths
        _amountText = State(initialValue: selection.plannedAmount > 0 ? String(format: "%.0f", selection.plannedAmount) : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabelValueRow(title: store.appLanguage == .arabicEgyptian ? "الشهر" : "Month", value: BudgetDateHelper.monthTitle(selection.date))
                    LabelValueRow(title: store.appLanguage == .arabicEgyptian ? "البند" : "Category", value: selection.categoryName)
                    LabelValueRow(title: store.appLanguage == .arabicEgyptian ? "المخطط يدويًا" : "Manual Planned", value: store.displayCurrency(selection.plannedAmount))
                    Button {
                        isShowingPaidBreakdown = true
                    } label: {
                        HStack {
                            Text(store.appLanguage == .arabicEgyptian ? "المدفوع حتى الآن" : "Paid So Far")
                                .foregroundStyle(.primary)

                            Spacer(minLength: 12)

                            Text(store.displayCurrency(selection.paidActualAmount))
                                .fontWeight(.semibold)
                                .multilineTextAlignment(.trailing)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    if selection.knownUpcomingAmount > 0 {
                        Button {
                            isShowingCommittedBreakdown = true
                        } label: {
                            HStack {
                                Text(store.appLanguage == .arabicEgyptian ? "ملتزم به" : "Committed")
                                    .foregroundStyle(.primary)

                                Spacer(minLength: 12)

                                Text(store.displayCurrency(selection.knownUpcomingAmount))
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.trailing)

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        LabelValueRow(title: store.appLanguage == .arabicEgyptian ? "ملتزم به" : "Committed", value: store.displayCurrency(selection.knownUpcomingAmount))
                    }
                    LabelValueRow(title: store.appLanguage == .arabicEgyptian ? "المتوقع إجمالًا" : "Total Expected", value: store.displayCurrency(selection.effectiveProjectedAmount))
                    LabelValueRow(title: store.appLanguage == .arabicEgyptian ? "المتبقي من الميزانية" : "Budget Left", value: store.displayCurrency(selection.remainingAfterKnown))
                } footer: {
                    Text(store.appLanguage == .arabicEgyptian ? "المبالغ الملتزم بها مجدولة لكنها لم تُدفع بعد. لا تؤثر على رصيدك الفعلي." : "Committed amounts are scheduled but not yet paid. They don't affect your actual balance.")
                }

                Section(store.appLanguage == .arabicEgyptian ? "تحديد الميزانية" : "Set Budget") {
                    TextField(store.appLanguage == .arabicEgyptian ? "المبلغ" : "Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .budgets, isProminent: true)
                }

                Section {
                    Button {
                        saveAmount()
                        dismiss()
                    } label: {
                        Text(store.appLanguage == .arabicEgyptian ? "حفظ" : "Save")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .disabled(parsedAmount == nil)

                    Button(role: .destructive) {
                        saveAmount(0)
                        dismiss()
                    } label: {
                        Text(store.appLanguage == .arabicEgyptian ? "إزالة" : "Remove")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }

                    if selection.knownUpcomingAmount > 0 {
                        Button {
                            onUseCommittedAsBudget(selection)
                            dismiss()
                        } label: {
                            Text(store.appLanguage == .arabicEgyptian ? "استخدم الملتزم به كميزانية" : "Use Committed as Budget")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                    }

                    Button {
                        onCopyToFuture(selection)
                    } label: {
                        Text(store.appLanguage == .arabicEgyptian ? "تطبيق على الشهور القادمة" : "Apply to Future Months")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }

                    Button {
                        onApplyAcrossMonths(selection)
                    } label: {
                        Text(store.appLanguage == .arabicEgyptian ? "تطبيق على الشهور المحددة" : "Apply to Selected Months")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                }
            }
            .navigationTitle(store.appLanguage == .arabicEgyptian ? "تعديل خانة" : "Edit Cell")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingCommittedBreakdown) {
                BudgetCommittedBreakdownSheet(selection: selection)
                    .environmentObject(store)
            }
            .sheet(isPresented: $isShowingPaidBreakdown) {
                BudgetPaidBreakdownSheet(selection: selection)
                    .environmentObject(store)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: ".")).map { max($0, 0) }
    }

    private func saveAmount(_ overrideAmount: Double? = nil) {
        let amount = overrideAmount ?? parsedAmount ?? 0
        BudgetPlanningWriter.setPlannedAmount(
            amount,
            categoryName: selection.categoryName,
            year: selection.year,
            month: selection.month,
            store: store
        )
    }
}

private struct CategoryUpcomingBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let selection: CategoryUpcomingSelection

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var items: [FinancialEvent] {
        store.upcomingKnownExpenseEvents(year: selection.year, month: selection.month)
            .filter { ($0.categoryName ?? "Uncategorized") == selection.categoryName }
            .sorted {
                if $0.date == $1.date {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }

                return $0.date < $1.date
            }
    }

    private var breakdownTotal: Double {
        items.map { $0.recurringAmount(for: $0.date) }.reduce(0, +)
    }

    private var totalMatches: Bool {
        abs(breakdownTotal - selection.displayedAmount) < 0.01
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    detailRow(title: isArabic ? "الشهر" : "Month", value: BudgetDateHelper.monthTitle(selection.monthDate))
                    detailRow(title: isArabic ? "البند" : "Category", value: selection.categoryName)
                    detailRow(title: AppText.upcoming(store.appLanguage), value: store.displayCurrency(selection.displayedAmount))
                }

                Section {
                    if items.isEmpty {
                        Text(isArabic ? "لا توجد بنود قادمة لهذا البند في الشهر المختار." : "No upcoming source items found for this category in the selected month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            if canNavigate(item) {
                                NavigationLink {
                                    destination(for: item)
                                } label: {
                                    upcomingRow(item)
                                }
                            } else {
                                upcomingRow(item)
                            }
                        }
                    }
                } header: {
                    Text(isArabic ? "مصادر القادم" : "Upcoming Sources")
                } footer: {
                    Text(isArabic ? "عرض فقط. لا يتم تسجيل دفع أو تعديل أي التزام من هنا." : "Read-only. This does not mark anything paid or change any commitment.")
                }

                Section {
                    detailRow(title: isArabic ? "إجمالي التفاصيل" : "Source Total", value: store.displayCurrency(breakdownTotal))

                    if !totalMatches {
                        Text(isArabic ? "إجمالي التفاصيل لا يطابق رقم القادم. برجاء مراجعة مصدر الحساب." : "Breakdown total does not match the Upcoming value. Please review the source logic.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(isArabic ? "تفاصيل القادم" : "Upcoming Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isArabic ? "تم" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func upcomingRow(_ item: FinancialEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NamedVisualMark(
                name: item.title,
                fallbackSystemImage: sourceIcon(for: item),
                size: 32
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(sourceType(for: item))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(statusText(for: item))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(store.displayCurrency(item.recurringAmount(for: item.date)))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(formatDate(item.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func destination(for item: FinancialEvent) -> some View {
        if let sourceID = item.sourceRecurringEventID,
           store.activeFinancialEvents.contains(where: { $0.id == sourceID }) {
            RecurringSeriesDetailView(eventID: sourceID)
                .environmentObject(store)
        } else if let planID = item.sourceInstallmentPlanID,
                  let plan = store.activeInstallmentPlans.first(where: { $0.id == planID }) {
            InstallmentPlanEditorView(plan: plan)
                .environmentObject(store)
        } else if item.repeatRule != .none {
            RecurringPaymentEditorView(event: item)
                .environmentObject(store)
        } else if item.sourceInstallmentPlanID == nil &&
                    item.sourceRecurringEventID == nil &&
                    item.repeatRule == .none {
            TransactionDetailView(event: item, isPresentedModally: false)
                .environmentObject(store)
        }
    }

    private func canNavigate(_ item: FinancialEvent) -> Bool {
        if let sourceID = item.sourceRecurringEventID,
           store.activeFinancialEvents.contains(where: { $0.id == sourceID }) {
            return true
        }

        if let planID = item.sourceInstallmentPlanID,
           store.activeInstallmentPlans.contains(where: { $0.id == planID }) {
            return true
        }

        if item.repeatRule != .none {
            return true
        }

        return item.sourceInstallmentPlanID == nil &&
        item.sourceRecurringEventID == nil &&
        item.repeatRule == .none
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }

    private func sourceType(for item: FinancialEvent) -> String {
        if item.sourceInstallmentPlanID != nil {
            return isArabic ? "قسط" : "Installment"
        }

        if item.sourceRecurringEventID != nil || item.repeatRule != .none {
            return isArabic ? "دفع متكرر" : "Recurring"
        }

        if item.type == .expectedExpense {
            return isArabic ? "مصروف مستقبلي" : "Future item"
        }

        if item.type == .obligation {
            return isArabic ? "التزام مرة واحدة" : "One-off obligation"
        }

        return isArabic ? "بند قادم" : "Upcoming item"
    }

    private func statusText(for item: FinancialEvent) -> String {
        if item.sourceRecurringEventID != nil {
            if item.recurringScheduleOverrides?.contains(where: { override in
                override.year == item.recurringOccurrenceYear && override.month == item.recurringOccurrenceMonth
            }) == true {
                return isArabic ? "مؤكد" : "confirmed"
            }

            if item.effectiveRecurringAmountMode != .fixedAmount {
                return isArabic ? "تقديري" : "estimated"
            }
        }

        switch item.status {
        case .paid:
            return isArabic ? "مدفوع" : "paid"
        case .unpaid:
            return isArabic ? "غير مدفوع" : "unpaid"
        case .expected:
            return isArabic ? "متوقع" : "expected"
        case .planned:
            return isArabic ? "مخطط" : "planned"
        case .cancelled:
            return isArabic ? "ملغي" : "cancelled"
        case .skipped:
            return isArabic ? "متخطي" : "skipped"
        }
    }

    private func sourceIcon(for item: FinancialEvent) -> String {
        if item.sourceInstallmentPlanID != nil {
            return "creditcard.fill"
        }

        if item.sourceRecurringEventID != nil || item.repeatRule != .none {
            return "repeat"
        }

        return "calendar.badge.clock"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

private struct BudgetCommittedBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let selection: BudgetCellSelection

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var items: [FinancialEvent] {
        store.upcomingKnownExpenseEvents(year: selection.year, month: selection.month)
            .filter { ($0.categoryName ?? "Uncategorized") == selection.categoryName }
            .sorted {
                if $0.date == $1.date {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }

                return $0.date < $1.date
            }
    }

    private var breakdownTotal: Double {
        items.map(\.amount).reduce(0, +)
    }

    private var totalMatches: Bool {
        abs(breakdownTotal - selection.knownUpcomingAmount) < 0.01
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if items.isEmpty {
                        Text(isArabic ? "لا توجد تفاصيل لهذا الرقم." : "No committed source items found for this amount.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            breakdownRow(item)
                        }
                    }
                } header: {
                    Text(selection.categoryName)
                } footer: {
                    Text(isArabic ? "عرض فقط. لا يتم تسجيل دفع أو تعديل أي التزام من هنا." : "Read-only. This does not mark anything paid or change any commitment.")
                }

                Section {
                    HStack {
                        Text(isArabic ? "إجمالي الالتزامات" : "Total committed")
                        Spacer()
                        Text(store.displayCurrency(breakdownTotal))
                            .fontWeight(.semibold)
                    }

                    if !totalMatches {
                        Text(isArabic ? "إجمالي التفاصيل لا يطابق رقم الالتزامات. برجاء مراجعة مصدر الحساب." : "Breakdown total does not match committed total. Please review committed source logic.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(isArabic ? "تفاصيل الالتزامات" : "Committed Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isArabic ? "تم" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func breakdownRow(_ item: FinancialEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NamedVisualMark(
                name: item.title,
                fallbackSystemImage: sourceIcon(for: item),
                size: 32
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(sourceType(for: item))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(statusText(for: item))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(store.displayCurrency(item.amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(formatDate(item.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func sourceType(for item: FinancialEvent) -> String {
        if item.sourceInstallmentPlanID != nil {
            return isArabic ? "قسط" : "Installment"
        }

        if item.sourceRecurringEventID != nil || item.repeatRule != .none {
            return isArabic ? "دفع متكرر" : "Recurring Payment"
        }

        if item.type == .expectedExpense {
            return isArabic ? "مصروف مستقبلي" : "Future Expense"
        }

        return isArabic ? "مصدر ملتزم" : "Other committed source"
    }

    private func statusText(for item: FinancialEvent) -> String {
        if item.recurringOccurrenceYear != nil {
            if item.recurringScheduleOverrides?.contains(where: { override in
                override.year == item.recurringOccurrenceYear && override.month == item.recurringOccurrenceMonth
            }) == true {
                return isArabic ? "مؤكد" : "confirmed"
            }

            if item.effectiveRecurringAmountMode != .fixedAmount {
                return isArabic ? "تقديري" : "estimated"
            }
        }

        return isArabic ? "مجدول / غير مدفوع" : "scheduled / unpaid"
    }

    private func sourceIcon(for item: FinancialEvent) -> String {
        if item.sourceInstallmentPlanID != nil {
            return "creditcard.fill"
        }

        if item.sourceRecurringEventID != nil || item.repeatRule != .none {
            return "repeat"
        }

        return "calendar.badge.clock"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

private struct BudgetPaidBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let selection: BudgetCellSelection

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var items: [ActualSpendingBreakdownItem] {
        store.actualSpendingBreakdownItems(
            year: selection.year,
            month: selection.month,
            categoryName: selection.categoryName
        )
    }

    private var breakdownTotal: Double {
        items.map(\.amount).reduce(0, +)
    }

    private var totalMatches: Bool {
        abs(breakdownTotal - selection.paidActualAmount) < 0.01
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    detailRow(title: isArabic ? "الشهر" : "Month", value: BudgetDateHelper.monthTitle(selection.date))
                    detailRow(title: isArabic ? "البند" : "Category", value: selection.categoryName)
                    detailRow(title: isArabic ? "إجمالي المدفوع" : "Total Paid", value: store.displayCurrency(selection.paidActualAmount))
                }

                Section {
                    if items.isEmpty {
                        Text(isArabic ? "مفيش معاملات مدفوعة في البند ده خلال الشهر ده." : "No paid transactions found for this category in this month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            paidBreakdownRow(item)
                        }
                    }
                } header: {
                    Text(isArabic ? "المعاملات المدفوعة" : "Paid Transactions")
                } footer: {
                    Text(isArabic ? "عرض فقط. لا يتم تعديل أو حذف معاملات من هنا." : "Read-only. This does not edit or delete transactions.")
                }

                Section {
                    HStack {
                        Text(isArabic ? "إجمالي المدفوع" : "Total Paid")
                        Spacer()
                        Text(store.displayCurrency(breakdownTotal))
                            .fontWeight(.semibold)
                    }

                    if !totalMatches {
                        Text(isArabic ? "إجمالي التفاصيل لا يطابق رقم المدفوع. برجاء مراجعة مصدر الحساب." : "Breakdown total does not match Paid So Far. Please review the source logic.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(isArabic ? "تفاصيل المدفوع" : "Paid Breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isArabic ? "تم" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func paidBreakdownRow(_ item: ActualSpendingBreakdownItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NamedVisualMark(
                name: item.title,
                fallbackSystemImage: iconName(for: item),
                size: 32
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(item.categoryName) / \(item.subCategoryName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(metaText(for: item))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(store.displayCurrency(item.amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(formatDateTime(item.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }

    private func metaText(for item: ActualSpendingBreakdownItem) -> String {
        [
            item.transactionType,
            item.paymentMethodName,
            item.accountName
        ]
        .compactMap { value in
            guard let value,
                  !value.isEmpty else {
                return nil
            }

            return value
        }
        .joined(separator: " • ")
    }

    private func iconName(for item: ActualSpendingBreakdownItem) -> String {
        switch item.source {
        case .creditCardPurchase:
            return "creditcard.fill"
        case .financialEvent:
            if item.transactionType == FinancialEventType.obligation.rawValue {
                return "calendar.circle.fill"
            }
            if item.transactionType == FinancialEventType.installment.rawValue {
                return "creditcard.and.123"
            }
            return "creditcard.fill"
        }
    }

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
    }
}

private struct CopyBudgetCellForwardSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let selection: BudgetCellSelection
    let visibleMonths: [Date]
    let onApplied: (BudgetGridUndoAction) -> Void

    @State private var selectedMonthKeys: Set<String> = []
    @State private var pendingApplyDates: [Date] = []
    @State private var showingApplyConfirmation = false

    private var futureMonths: [Date] {
        visibleMonths.filter { $0 > selection.date }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabelValueRow(title: store.appLanguage == .arabicEgyptian ? "من شهر" : "From Month", value: BudgetDateHelper.monthTitle(selection.date))
                    LabelValueRow(title: store.appLanguage == .arabicEgyptian ? "البند" : "Category", value: selection.categoryName)
                    LabelValueRow(title: store.appLanguage == .arabicEgyptian ? "المخطط" : "Planned", value: store.displayCurrency(selection.plannedAmount))
                }

                Section(store.appLanguage == .arabicEgyptian ? "اختار الشهور" : "Select Months") {
                    if futureMonths.isEmpty {
                        Text(store.appLanguage == .arabicEgyptian ? "مفيش شهور قدام في النطاق الحالي." : "No future months in the current range.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(futureMonths, id: \.self) { date in
                            let key = BudgetDateHelper.monthID(for: date)
                            Toggle(BudgetDateHelper.monthTitle(date), isOn: Binding(
                                get: { selectedMonthKeys.contains(key) },
                                set: { isOn in
                                    if isOn {
                                        selectedMonthKeys.insert(key)
                                    } else {
                                        selectedMonthKeys.remove(key)
                                    }
                                }
                            ))
                        }
                    }
                }

                Section {
                    Button {
                        requestApplyCopy()
                    } label: {
                        Text(store.appLanguage == .arabicEgyptian ? "انسخ دلوقتي" : "Copy Now")
                    }
                    .disabled(selectedMonthKeys.isEmpty)
                }
            }
            .navigationTitle(store.appLanguage == .arabicEgyptian ? "انسخ لشهور جاية" : "Copy to Future Months")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(
                store.appLanguage == .arabicEgyptian ? "تأكيد التطبيق" : "Confirm Apply",
                isPresented: $showingApplyConfirmation
            ) {
                Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel", role: .cancel) {
                    pendingApplyDates = []
                }
                Button(store.appLanguage == .arabicEgyptian ? "تطبيق" : "Apply") {
                    applyCopy(to: pendingApplyDates)
                    pendingApplyDates = []
                    dismiss()
                }
            } message: {
                Text(confirmMessage(monthCount: pendingApplyDates.count))
            }
        }
    }

    private func requestApplyCopy() {
        let dates = futureMonths.filter { selectedMonthKeys.contains(BudgetDateHelper.monthID(for: $0)) }
        guard !dates.isEmpty else { return }

        if dates.count > 1 {
            pendingApplyDates = dates
            showingApplyConfirmation = true
        } else {
            applyCopy(to: dates)
            dismiss()
        }
    }

    private func applyCopy(to dates: [Date]) {
        let undoAction = BudgetGridUndoAction.capture(
            categoryName: selection.categoryName,
            dates: dates,
            newAmount: selection.plannedAmount,
            actionType: .applyToFutureMonths,
            store: store
        )

        for date in dates {
            let key = BudgetDateHelper.monthKey(for: date)
            BudgetPlanningWriter.setPlannedAmount(
                selection.plannedAmount,
                categoryName: selection.categoryName,
                year: key.year,
                month: key.month,
                store: store
            )
        }
        onApplied(undoAction)
    }

    private func confirmMessage(monthCount: Int) -> String {
        if store.appLanguage == .arabicEgyptian {
            return "سيتم تحديث \(selection.categoryName) لعدد \(monthCount) شهر. يمكنك التراجع مباشرة بعد التطبيق."
        }

        return "This will update \(selection.categoryName) for \(monthCount) months. You can undo this immediately after applying."
    }
}

private struct CategoryAcrossMonthsSheet: View {

    private enum ApplyScope: String, CaseIterable, Identifiable {
        case allVisible
        case fromSelectedForward

        var id: String { rawValue }

        func title(_ language: AppLanguage) -> String {
            switch self {
            case .allVisible:
                return language == .arabicEgyptian ? "كل الشهور الظاهرة" : "All Visible Months"
            case .fromSelectedForward:
                return language == .arabicEgyptian ? "من الشهر المختار لقدام" : "From Selected Month Forward"
            }
        }
    }

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let categoryName: String
    let anchorMonth: Date
    let visibleMonths: [Date]
    let onApplied: (BudgetGridUndoAction) -> Void

    @State private var amountText = ""
    @State private var applyScope: ApplyScope = .allVisible
    @State private var pendingApplyDates: [Date] = []
    @State private var pendingApplyAmount: Double = 0
    @State private var showingApplyConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabelValueRow(title: store.appLanguage == .arabicEgyptian ? "البند" : "Category", value: categoryName)
                    TextField(store.appLanguage == .arabicEgyptian ? "المبلغ" : "Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .budgets, isProminent: true)
                }

                Section(store.appLanguage == .arabicEgyptian ? "طبّق على" : "Apply To") {
                    Picker("", selection: $applyScope) {
                        ForEach(ApplyScope.allCases) { scope in
                            Text(scope.title(store.appLanguage)).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button {
                        requestApply()
                    } label: {
                        Text(store.appLanguage == .arabicEgyptian ? "طبّق" : "Apply")
                    }
                    .disabled(parsedAmount == nil)
                }
            }
            .navigationTitle(store.appLanguage == .arabicEgyptian ? "بند عبر الشهور" : "Category Across Months")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(
                store.appLanguage == .arabicEgyptian ? "تأكيد التطبيق" : "Confirm Apply",
                isPresented: $showingApplyConfirmation
            ) {
                Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel", role: .cancel) {
                    pendingApplyDates = []
                    pendingApplyAmount = 0
                }
                Button(store.appLanguage == .arabicEgyptian ? "تطبيق" : "Apply") {
                    apply(amount: pendingApplyAmount, to: pendingApplyDates)
                    pendingApplyDates = []
                    pendingApplyAmount = 0
                    dismiss()
                }
            } message: {
                Text(confirmMessage(monthCount: pendingApplyDates.count))
            }
        }
    }

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: ".")).map { max($0, 0) }
    }

    private func requestApply() {
        guard let amount = parsedAmount else { return }
        let dates = selectedDates()

        if dates.count > 1 {
            pendingApplyDates = dates
            pendingApplyAmount = amount
            showingApplyConfirmation = true
        } else {
            apply(amount: amount, to: dates)
            dismiss()
        }
    }

    private func selectedDates() -> [Date] {
        let dates: [Date]
        switch applyScope {
        case .allVisible:
            dates = visibleMonths
        case .fromSelectedForward:
            dates = visibleMonths.filter { $0 >= anchorMonth }
        }
        return dates
    }

    private func apply(amount: Double, to dates: [Date]) {
        guard !dates.isEmpty else { return }

        let undoAction = BudgetGridUndoAction.capture(
            categoryName: categoryName,
            dates: dates,
            newAmount: amount,
            actionType: .applyToSelectedMonths,
            store: store
        )

        for date in dates {
            let key = BudgetDateHelper.monthKey(for: date)
            BudgetPlanningWriter.setPlannedAmount(
                amount,
                categoryName: categoryName,
                year: key.year,
                month: key.month,
                store: store
            )
        }
        onApplied(undoAction)
    }

    private func confirmMessage(monthCount: Int) -> String {
        if store.appLanguage == .arabicEgyptian {
            return "سيتم تحديث \(categoryName) لعدد \(monthCount) شهر. يمكنك التراجع مباشرة بعد التطبيق."
        }

        return "This will update \(categoryName) for \(monthCount) months. You can undo this immediately after applying."
    }
}

private struct CopyWholeMonthForwardSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let sourceMonth: Date
    @State private var selectedCount = 3

    private let countOptions = [1, 3, 6]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabelValueRow(title: store.appLanguage == .arabicEgyptian ? "من شهر" : "From Month", value: BudgetDateHelper.monthTitle(sourceMonth))
                    Picker(store.appLanguage == .arabicEgyptian ? "عدد الشهور" : "Months", selection: $selectedCount) {
                        ForEach(countOptions, id: \.self) { value in
                            Text(store.appLanguage == .arabicEgyptian ? "\(value) شهور" : "\(value) Months").tag(value)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        copyForward()
                        dismiss()
                    } label: {
                        Text(store.appLanguage == .arabicEgyptian ? "انسخ الميزانية" : "Copy Budget")
                    }
                } footer: {
                    Text(store.appLanguage == .arabicEgyptian ? "ده بينسخ المخطط بس. المدفوع والأرصدة مش هتتغير." : "This copies planned values only. Paid spending and balances will not change.")
                }
            }
            .navigationTitle(store.appLanguage == .arabicEgyptian ? "انسخ لشهور جاية" : "Copy to Future Months")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func copyForward() {
        let sourceKey = BudgetDateHelper.monthKey(for: sourceMonth)
        for offset in 1...selectedCount {
            let target = BudgetDateHelper.addMonths(offset, to: sourceMonth)
            let targetKey = BudgetDateHelper.monthKey(for: target)
            store.copyMonthlyBudget(
                from: sourceKey.year,
                sourceMonth: sourceKey.month,
                to: targetKey.year,
                targetMonth: targetKey.month
            )
        }
    }
}

private struct MonthStepperCard: View {

    @Environment(\.colorScheme) private var colorScheme

    let title: String
    @Binding var monthDate: Date
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                PocketWiseIconBadge(
                    systemName: "calendar",
                    semanticColor: .budgets,
                    size: 34,
                    cornerRadius: 10
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Text(BudgetDateHelper.monthTitle(monthDate))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        if isCurrentMonth {
                            Text(language == .arabicEgyptian ? "الشهر الحالي" : "Current month")
                                .pocketWiseChip(semanticColor: .budgets)
                        }
                    }
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    monthDate = BudgetDateHelper.addMonths(-1, to: monthDate)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 38, height: 34)
                }
                .buttonStyle(.bordered)

                Button {
                    monthDate = BudgetDateHelper.startOfMonth(for: Date())
                } label: {
                    Text(monthSubtitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(isCurrentMonth ? PocketWiseSemanticColor.budgets.tint : .secondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Button {
                    monthDate = BudgetDateHelper.addMonths(1, to: monthDate)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 38, height: 34)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
        .pocketWiseCard(
            semanticColor: isCurrentMonth ? .budgets : .neutral,
            padding: 14,
            cornerRadius: 14,
            showsBorder: true
        )
        .background {
            if isCurrentMonth {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PocketWiseSemanticColor.budgets.softBackground(for: colorScheme))
                    .blur(radius: 8)
                    .opacity(0.35)
            }
        }
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(monthDate, equalTo: Date(), toGranularity: .month)
    }

    private var monthSubtitle: String {
        let selected = BudgetDateHelper.startOfMonth(for: monthDate)
        let current = BudgetDateHelper.startOfMonth(for: Date())

        if Calendar.current.isDate(selected, equalTo: current, toGranularity: .month) {
            return language == .arabicEgyptian ? "الشهر ده" : "This Month"
        }

        if selected > current {
            let next = BudgetDateHelper.addMonths(1, to: current)
            if Calendar.current.isDate(selected, equalTo: next, toGranularity: .month) {
                return language == .arabicEgyptian ? "الشهر الجاي" : "Next Month"
            }

            return language == .arabicEgyptian ? "شهر مستقبلي" : "Future Month"
        }

        return language == .arabicEgyptian ? "شهر سابق" : "Past Month"
    }
}

private struct BudgetMetricCard: View {

    @EnvironmentObject private var store: WalletStore

    let title: String
    let value: Double
    var color: Color = .primary
    var showsDisclosure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                if showsDisclosure {
                    Image(systemName: "chevron.forward")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(store.displayCurrency(value))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pocketWiseCard(
            semanticColor: .budgets,
            padding: 10,
            cornerRadius: 10,
            showsBorder: true
        )
    }
}

private struct ActualSpentBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let monthDate: Date
    let displayedAmount: Double

    private var monthKey: (year: Int, month: Int) {
        BudgetDateHelper.monthKey(for: monthDate)
    }

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var items: [ActualSpendingBreakdownItem] {
        store.actualSpendingBreakdownItems(year: monthKey.year, month: monthKey.month, categoryName: nil)
    }

    private var sourceTotal: Double {
        items.map(\.amount).reduce(0, +)
    }

    private var totalMatches: Bool {
        abs(sourceTotal - displayedAmount) < 0.01
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabelValueRow(
                        title: isArabic ? "الشهر" : "Month",
                        value: BudgetDateHelper.monthTitle(monthDate)
                    )
                    LabelValueRow(
                        title: isArabic ? "المصروف الفعلي" : "Actual Spent",
                        value: store.displayCurrency(displayedAmount)
                    )
                    LabelValueRow(
                        title: isArabic ? "إجمالي المصادر" : "Source Total",
                        value: store.displayCurrency(sourceTotal)
                    )

                    if !totalMatches {
                        Text(isArabic ? "إجمالي المصادر لا يطابق رقم المصروف الفعلي." : "Source total does not match the Actual Spent card value.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    if items.isEmpty {
                        Text(isArabic ? "مفيش مصروف فعلي مسجل للشهر ده." : "No actual spending source rows for this month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            if let event = financialEvent(for: item) {
                                NavigationLink {
                                    TransactionDetailView(event: event, isPresentedModally: false)
                                        .environmentObject(store)
                                } label: {
                                    actualSpentRow(item)
                                }
                            } else {
                                actualSpentRow(item)
                            }
                        }
                    }
                } header: {
                    Text(isArabic ? "مصادر المصروف الفعلي" : "Actual Spending Sources")
                } footer: {
                    Text(isArabic ? "نفس مصادر رقم المصروف الفعلي. مدفوعات كروت الائتمان كتسوية مش بتظهر هنا إلا لو مصدر الحساب نفسه ضافها." : "Uses the same source as the Actual Spent value. Credit card settlement payments do not appear unless the actual-spending helper includes them.")
                }
            }
            .navigationTitle(isArabic ? "المصروف الفعلي" : "Actual Spent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isArabic ? "تم" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func actualSpentRow(_ item: ActualSpendingBreakdownItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NamedVisualMark(
                name: item.title,
                fallbackSystemImage: sourceIcon(for: item),
                size: 32
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(item.categoryName) / \(item.subCategoryName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(sourceText(for: item))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(store.displayCurrency(item.amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(formatDate(item.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func financialEvent(for item: ActualSpendingBreakdownItem) -> FinancialEvent? {
        guard item.source == .financialEvent,
              item.id.hasPrefix("event-") else {
            return nil
        }

        let uuidString = String(item.id.dropFirst("event-".count))
        guard let eventID = UUID(uuidString: uuidString) else {
            return nil
        }

        return store.activeFinancialEvents.first { $0.id == eventID }
    }

    private func sourceText(for item: ActualSpendingBreakdownItem) -> String {
        switch item.source {
        case .creditCardPurchase:
            return isArabic ? "مشتريات كارت ائتمان" : "Credit card purchase"
        case .financialEvent:
            var parts = [item.transactionType]
            if let paymentMethodName = item.paymentMethodName,
               !paymentMethodName.isEmpty {
                parts.append(paymentMethodName)
            }
            if let accountName = item.accountName,
               !accountName.isEmpty {
                parts.append(accountName)
            }
            return parts.joined(separator: " • ")
        }
    }

    private func sourceIcon(for item: ActualSpendingBreakdownItem) -> String {
        switch item.source {
        case .creditCardPurchase:
            return "creditcard"
        case .financialEvent:
            if item.transactionType.caseInsensitiveCompare("Installment") == .orderedSame {
                return "creditcard.and.123"
            }

            return "banknote"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

private enum CreditCardDueCashCommitmentHelper {
    static func dueItems(store: WalletStore, year: Int, month: Int) -> [CreditCardDueItem] {
        guard let range = BudgetDateHelper.monthRange(year: year, month: month) else {
            return []
        }

        return store.creditCardDueItems(referenceDate: Date(), horizonMonths: store.forecastHorizonMonths)
            .filter { item in
                item.dueAmount > 0 &&
                item.dueDate >= range.start &&
                item.dueDate < range.end
            }
            .sorted {
                if $0.dueDate == $1.dueDate {
                    return $0.cardName.localizedCaseInsensitiveCompare($1.cardName) == .orderedAscending
                }

                return $0.dueDate < $1.dueDate
            }
    }

    static func dueTotal(store: WalletStore, year: Int, month: Int) -> Double {
        dueItems(store: store, year: year, month: month)
            .map(\.dueAmount)
            .reduce(0, +)
    }
}

private struct AfterCommittedBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore
    let monthDate: Date

    private var monthKey: (year: Int, month: Int) {
        BudgetDateHelper.monthKey(for: monthDate)
    }

    private var plannedByCategory: [String: Double] {
        Dictionary(uniqueKeysWithValues: (store.monthlyBudget(year: monthKey.year, month: monthKey.month)?.items ?? []).map { ($0.categoryName, $0.plannedAmount) })
    }

    private var paidByCategory: [String: Double] {
        store.actualSpendingByCategory(year: monthKey.year, month: monthKey.month)
    }

    private var upcomingByCategory: [String: Double] {
        store.upcomingKnownExpensesByCategory(year: monthKey.year, month: monthKey.month)
    }

    private var allCategoryNames: [String] {
        var names: [String] = []
        for name in Array(plannedByCategory.keys) + Array(paidByCategory.keys) + Array(upcomingByCategory.keys) {
            if !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                names.append(name)
            }
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var plannedCategoryNames: [String] {
        allCategoryNames.filter { (plannedByCategory[$0] ?? 0) > 0 }
    }

    private var paidCategoryNames: [String] {
        allCategoryNames.filter { (paidByCategory[$0] ?? 0) > 0 }
    }

    private var upcomingCategoryNames: [String] {
        allCategoryNames.filter { (upcomingByCategory[$0] ?? 0) > 0 }
    }

    private var creditCardDueItems: [CreditCardDueItem] {
        CreditCardDueCashCommitmentHelper.dueItems(store: store, year: monthKey.year, month: monthKey.month)
    }

    private var creditCardDueTotal: Double {
        creditCardDueItems.map(\.dueAmount).reduce(0, +)
    }

    private var totalPlanned: Double {
        allCategoryNames.map { plannedByCategory[$0] ?? 0 }.reduce(0, +)
    }

    private var totalPaid: Double {
        allCategoryNames.map { paidByCategory[$0] ?? 0 }.reduce(0, +)
    }

    private var totalUpcoming: Double {
        allCategoryNames.map { upcomingByCategory[$0] ?? 0 }.reduce(0, +) + creditCardDueTotal
    }

    private var afterCommitted: Double {
        totalPlanned - totalPaid - totalUpcoming
    }

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabelValueRow(
                        title: isArabic ? "الشهر" : "Month",
                        value: BudgetDateHelper.monthTitle(monthDate)
                    )
                    LabelValueRow(
                        title: isArabic ? "المعادلة" : "Formula",
                        value: isArabic ? "مخطط − مدفوع − ملتزم به" : "Planned − Paid − Committed"
                    )
                }

                Section {
                    if plannedCategoryNames.isEmpty {
                        Text(isArabic ? "مفيش ميزانية محددة للشهر ده." : "No budget plan for this month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(plannedCategoryNames, id: \.self) { category in
                            LabelValueRow(title: category, value: store.displayCurrency(plannedByCategory[category] ?? 0))
                        }
                    }
                    LabelValueRow(title: isArabic ? "الإجمالي" : "Total", value: store.displayCurrency(totalPlanned))
                } header: {
                    Text(isArabic ? "المصاريف المخططة" : "Planned Expenses")
                } footer: {
                    Text(isArabic ? "من ميزانية الشهر المخططة." : "From the monthly budget plan.")
                }

                Section {
                    if paidCategoryNames.isEmpty {
                        Text(isArabic ? "مفيش مصاريف مسجلة للشهر ده." : "Nothing paid yet this month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(paidCategoryNames, id: \.self) { category in
                            LabelValueRow(title: category, value: store.displayCurrency(paidByCategory[category] ?? 0))
                        }
                    }
                    LabelValueRow(title: isArabic ? "الإجمالي" : "Total", value: store.displayCurrency(totalPaid))
                } header: {
                    Text(isArabic ? "− المصروف الفعلي" : "− Actual Spent")
                } footer: {
                    Text(isArabic ? "مصاريف مدفوعة ومشتريات بالبطاقة. للتفاصيل، ارجع للشاشة الرئيسية واضغط 'المصروف الفعلي'." : "Posted transactions and credit card purchases. For individual rows, tap Actual Spent on the main screen.")
                }

                Section {
                    if upcomingCategoryNames.isEmpty {
                        Text(isArabic ? "مفيش التزامات قادمة للشهر ده." : "No upcoming commitments this month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(upcomingCategoryNames, id: \.self) { category in
                            LabelValueRow(title: category, value: store.displayCurrency(upcomingByCategory[category] ?? 0))
                        }
                    }
                    if !creditCardDueItems.isEmpty {
                        ForEach(creditCardDueItems) { item in
                            LabelValueRow(
                                title: "\(item.cardName) \(isArabic ? "مستحق كارت" : "Card due")",
                                value: store.displayCurrency(item.dueAmount)
                            )
                        }
                    }
                    LabelValueRow(title: isArabic ? "الإجمالي" : "Total", value: store.displayCurrency(totalUpcoming))
                } header: {
                    Text(isArabic ? "− الملتزم به" : "− Committed")
                } footer: {
                    Text(isArabic ? "مصاريف مجدولة غير مدفوعة ومستحقات كروت ائتمان كالتزام كاش. مستحق الكارت مش مصروف جديد." : "Scheduled unpaid commitments plus credit card dues as cash obligations. Card dues are not new spending.")
                }

                Section {
                    HStack {
                        Text(isArabic ? "= بعد الملتزم به" : "= After Committed")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(store.displayCurrency(abs(afterCommitted)))
                            .fontWeight(.bold)
                            .foregroundStyle(afterCommitted >= 0 ? Color.green : Color.red)
                    }
                } footer: {
                    Text(isArabic
                         ? (afterCommitted >= 0 ? "هامش متبقي في الميزانية بعد المدفوع والملتزم به." : "تجاوزت الميزانية بعد حساب المدفوع والملتزم به.")
                         : (afterCommitted >= 0 ? "Budget headroom remaining after paid and committed expenses." : "Over budget after accounting for paid and committed expenses."))
                }
            }
            .navigationTitle(isArabic ? "بعد الملتزم به" : "After Committed")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ProjectedExpenseBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore

    let projection: BudgetMonthProjection
    let categoryNames: [String]

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var rows: [ProjectedExpenseBreakdownRow] {
        let plannedByCategory = Dictionary(
            uniqueKeysWithValues: (store.monthlyBudget(year: projection.year, month: projection.month)?.items ?? []).map {
                ($0.categoryName, $0.plannedAmount)
            }
        )
        let paidByCategory = store.actualSpendingByCategory(year: projection.year, month: projection.month)
        let upcomingByCategory = store.upcomingKnownExpensesByCategory(year: projection.year, month: projection.month)

        var names = categoryNames
        for name in Array(plannedByCategory.keys) + Array(paidByCategory.keys) + Array(upcomingByCategory.keys) {
            if !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                names.append(name)
            }
        }

        return names
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { category in
                ProjectedExpenseBreakdownRow(
                    categoryName: category,
                    plannedAmount: plannedByCategory[category] ?? 0,
                    paidAmount: paidByCategory[category] ?? 0,
                    upcomingAmount: upcomingByCategory[category] ?? 0
                )
            }
            .filter { $0.expectedAmount > 0 }
    }

    private var breakdownTotal: Double {
        rows.map(\.expectedAmount).reduce(0, +)
    }

    private var totalMatchesGrid: Bool {
        abs(breakdownTotal - projection.projectedExpenses) < 0.01
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabelValueRow(
                        title: isArabic ? "الشهر" : "Month",
                        value: BudgetDateHelper.monthTitle(projection.date)
                    )
                    LabelValueRow(
                        title: isArabic ? "رقم الجدول" : "Grid Value",
                        value: store.displayCurrency(projection.projectedExpenses)
                    )
                } footer: {
                    Text(isArabic
                         ? "شرح قراءة فقط لرقم إجمالي المتوقع الموجود في جدول الميزانية. ده مش توقع جديد ومش بيغير الميزانية أو المصاريف أو الأرصدة."
                         : "Read-only explanation of the existing Budget Grid Total Expected number. This is not a new forecast and does not change plans, transactions, or balances.")
                }

                Section {
                    if rows.isEmpty {
                        Text(isArabic ? "لا توجد بنود تدخل في إجمالي المتوقع لهذا الشهر." : "No category rows contribute to Total Expected for this month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(rows) { row in
                            projectedExpenseRow(row)
                        }
                    }
                } header: {
                    Text(isArabic ? "حسب البند" : "By Category")
                } footer: {
                    Text(isArabic
                         ? "لكل بند: إجمالي المتوقع = الأكبر بين المخطط، أو المدفوع + القادم."
                         : "For each category: Total Expected uses the larger of planned, or paid + upcoming.")
                }

                Section {
                    LabelValueRow(
                        title: AppText.totalExpected(store.appLanguage),
                        value: store.displayCurrency(breakdownTotal)
                    )

                    if !totalMatchesGrid {
                        Text(isArabic
                             ? "إجمالي التفاصيل لا يطابق رقم الجدول. راجع مصدر الحساب قبل الاعتماد عليه."
                             : "Breakdown total does not match the grid value. Review the source calculation before relying on it.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(AppText.totalExpected(store.appLanguage))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func projectedExpenseRow(_ row: ProjectedExpenseBreakdownRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.categoryName)
                    .font(.headline)

                Spacer()

                Text(store.displayCurrency(row.expectedAmount))
                    .font(.headline)
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 6) {
                compactAmountRow(title: AppText.planned(store.appLanguage), amount: row.plannedAmount)
                compactAmountRow(title: isArabic ? "المدفوع" : "Paid", amount: row.paidAmount)
                compactAmountRow(title: AppText.upcoming(store.appLanguage), amount: row.upcomingAmount)
                compactAmountRow(title: isArabic ? "المدفوع + القادم" : "Paid + Upcoming", amount: row.paidPlusUpcoming)
            }

            Text(row.reasonText(language: store.appLanguage))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func compactAmountRow(title: String, amount: Double) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(store.displayCurrency(amount))
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

private struct ProjectedExpenseBreakdownRow: Identifiable {
    var id: String { categoryName.lowercased() }
    let categoryName: String
    let plannedAmount: Double
    let paidAmount: Double
    let upcomingAmount: Double

    var paidPlusUpcoming: Double {
        paidAmount + upcomingAmount
    }

    var expectedAmount: Double {
        max(plannedAmount, paidPlusUpcoming)
    }

    func reasonText(language: AppLanguage) -> String {
        if plannedAmount >= paidPlusUpcoming {
            return language == .arabicEgyptian ? "باستخدام المخطط" : "Using plan"
        }

        return language == .arabicEgyptian ? "باستخدام المدفوع + القادم" : "Using paid + upcoming"
    }
}

private struct CurrentMonthBudgetSnapshot {
    let monthDate: Date
    let year: Int
    let month: Int
    let availableCash: Double
    let isCurrentMonth: Bool
    let isFutureMonth: Bool
    let previousMonthProjectedBalance: Double?
    let plannedByCategory: [String: Double]
    let paidByCategory: [String: Double]
    let upcomingByCategory: [String: Double]
    let categoryNames: [String]
    let plannedExpenses: Double
    let actualSpent: Double
    let knownUpcoming: Double
    let projectedExpenseExposure: Double
    let plannedIncome: Double
    let estimatedOpeningCash: Double
    let projectedClosingBalance: Double
    let remaining: Double
    let remainingAfterKnown: Double

    init(monthDate: Date, availableCash: Double, store: WalletStore) {
        let selectedMonthDate = BudgetDateHelper.startOfMonth(for: monthDate)
        let currentMonthDate = BudgetDateHelper.startOfMonth(for: Date())
        let isCurrentMonth = Calendar.current.isDate(selectedMonthDate, equalTo: currentMonthDate, toGranularity: .month)
        let isFutureMonth = selectedMonthDate > currentMonthDate

        var selectedOpeningCash = availableCash
        var previousProjectedBalance: Double?

        if isCurrentMonth {
            let currentData = Self.monthData(for: selectedMonthDate, store: store)
            selectedOpeningCash = availableCash + currentData.actualSpent
        } else if isFutureMonth {
            let currentData = Self.monthData(for: currentMonthDate, store: store)
            let currentOpeningCash = availableCash + currentData.actualSpent
            var rollingProjectedBalance = currentOpeningCash + currentData.plannedIncome - currentData.projectedExpenseExposure
            var cursor = BudgetDateHelper.addMonths(1, to: currentMonthDate)

            while cursor < selectedMonthDate {
                let cursorData = Self.monthData(for: cursor, store: store)
                rollingProjectedBalance = rollingProjectedBalance + cursorData.plannedIncome - cursorData.projectedExpenseExposure
                cursor = BudgetDateHelper.addMonths(1, to: cursor)
            }

            selectedOpeningCash = rollingProjectedBalance
            previousProjectedBalance = rollingProjectedBalance
        }

        self.monthDate = selectedMonthDate
        let monthKey = BudgetDateHelper.monthKey(for: selectedMonthDate)
        self.year = monthKey.year
        self.month = monthKey.month
        self.availableCash = availableCash
        self.isCurrentMonth = isCurrentMonth
        self.isFutureMonth = isFutureMonth
        self.previousMonthProjectedBalance = previousProjectedBalance

        let selectedData = Self.monthData(for: selectedMonthDate, store: store)
        let plannedByCategory = selectedData.plannedByCategory
        let paidByCategory = selectedData.paidByCategory
        let upcomingByCategory = selectedData.upcomingByCategory

        self.plannedByCategory = plannedByCategory
        self.paidByCategory = paidByCategory
        self.upcomingByCategory = upcomingByCategory

        self.categoryNames = selectedData.categoryNames
        self.plannedExpenses = selectedData.plannedExpenses
        self.actualSpent = selectedData.actualSpent
        self.knownUpcoming = selectedData.knownUpcoming
        self.projectedExpenseExposure = selectedData.projectedExpenseExposure
        self.plannedIncome = selectedData.plannedIncome
        self.estimatedOpeningCash = selectedOpeningCash
        self.projectedClosingBalance = selectedOpeningCash + selectedData.plannedIncome - selectedData.projectedExpenseExposure
        self.remaining = selectedData.plannedExpenses - selectedData.actualSpent
        self.remainingAfterKnown = selectedData.plannedExpenses - selectedData.actualSpent - selectedData.knownUpcoming
    }

    private static func monthData(for monthDate: Date, store: WalletStore) -> CurrentMonthBudgetMonthData {
        let monthKey = BudgetDateHelper.monthKey(for: monthDate)
        let plannedByCategory = Dictionary(uniqueKeysWithValues: (store.monthlyBudget(year: monthKey.year, month: monthKey.month)?.items ?? []).map {
            ($0.categoryName, $0.plannedAmount)
        })
        let paidByCategory = store.actualSpendingByCategory(year: monthKey.year, month: monthKey.month)
        let upcomingByCategory = store.upcomingKnownExpensesByCategory(year: monthKey.year, month: monthKey.month)

        var names: [String] = []
        for name in Array(plannedByCategory.keys) + Array(paidByCategory.keys) + Array(upcomingByCategory.keys) {
            if !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                names.append(name)
            }
        }
        let categoryNames = names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        let plannedExpenses = categoryNames.map { plannedByCategory[$0] ?? 0 }.reduce(0, +)
        let actualSpent = categoryNames.map { paidByCategory[$0] ?? 0 }.reduce(0, +)
        let knownUpcoming = categoryNames.map { upcomingByCategory[$0] ?? 0 }.reduce(0, +) +
            CreditCardDueCashCommitmentHelper.dueTotal(store: store, year: monthKey.year, month: monthKey.month)
        let projectedExpenseExposure = categoryNames
            .map { category in
                max(plannedByCategory[category] ?? 0, (paidByCategory[category] ?? 0) + (upcomingByCategory[category] ?? 0))
            }
            .reduce(0, +)

        let plannedIncome = store.monthlyBudgetIncome(year: monthKey.year, month: monthKey.month)

        return CurrentMonthBudgetMonthData(
            plannedByCategory: plannedByCategory,
            paidByCategory: paidByCategory,
            upcomingByCategory: upcomingByCategory,
            categoryNames: categoryNames,
            plannedExpenses: plannedExpenses,
            actualSpent: actualSpent,
            knownUpcoming: knownUpcoming,
            projectedExpenseExposure: projectedExpenseExposure,
            plannedIncome: plannedIncome
        )
    }
}

private struct CurrentMonthBudgetMonthData {
    let plannedByCategory: [String: Double]
    let paidByCategory: [String: Double]
    let upcomingByCategory: [String: Double]
    let categoryNames: [String]
    let plannedExpenses: Double
    let actualSpent: Double
    let knownUpcoming: Double
    let projectedExpenseExposure: Double
    let plannedIncome: Double
}

private struct ProjectedMonthBalanceBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore

    let monthDate: Date

    private var monthKey: (year: Int, month: Int) {
        BudgetDateHelper.monthKey(for: monthDate)
    }

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var snapshot: CurrentMonthBudgetSnapshot {
        CurrentMonthBudgetSnapshot(
            monthDate: monthDate,
            availableCash: store.availableCash,
            store: store
        )
    }

    private var plannedByCategory: [String: Double] {
        snapshot.plannedByCategory
    }

    private var paidByCategory: [String: Double] {
        snapshot.paidByCategory
    }

    private var upcomingByCategory: [String: Double] {
        snapshot.upcomingByCategory
    }

    private var categoryRows: [ProjectedExpenseBreakdownRow] {
        var names: [String] = []
        for name in Array(plannedByCategory.keys) + Array(paidByCategory.keys) + Array(upcomingByCategory.keys) {
            if !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                names.append(name)
            }
        }

        return names
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { category in
                ProjectedExpenseBreakdownRow(
                    categoryName: category,
                    plannedAmount: plannedByCategory[category] ?? 0,
                    paidAmount: paidByCategory[category] ?? 0,
                    upcomingAmount: upcomingByCategory[category] ?? 0
                )
            }
            .filter { $0.expectedAmount > 0 }
    }

    private var plannedIncome: Double {
        snapshot.plannedIncome
    }

    private var projectedExpenseExposure: Double {
        categoryRows.map(\.expectedAmount).reduce(0, +)
    }

    private var actualSpentSoFar: Double {
        snapshot.actualSpent
    }

    private var isSelectedCurrentMonth: Bool {
        snapshot.isCurrentMonth
    }

    private var isSelectedFutureMonth: Bool {
        snapshot.isFutureMonth
    }

    private var estimatedOpeningCash: Double {
        snapshot.estimatedOpeningCash
    }

    private var projectedMonthBalance: Double {
        snapshot.projectedClosingBalance
    }

    private var openingCashFooterEnglish: String {
        if isSelectedCurrentMonth {
            return "Current-month estimate: available cash now + actual spent so far. This is not an exact historical opening balance."
        }

        if isSelectedFutureMonth {
            return "Future-month estimate: the previous month projected balance becomes this month’s estimated opening cash."
        }

        return "Past months do not have historical opening cash snapshots yet; this remains a conservative fallback."
    }

    private var openingCashFooterArabic: String {
        if isSelectedCurrentMonth {
            return "تقدير للشهر الحالي: الكاش المتاح الآن + المصروف الفعلي حتى الآن. ده مش رصيد تاريخي دقيق."
        }

        if isSelectedFutureMonth {
            return "تقدير للشهر المستقبلي: رصيد الشهر السابق المتوقع يصبح الكاش الافتتاحي التقديري لهذا الشهر."
        }

        return "الشهور السابقة لا يوجد لها رصيد افتتاحي تاريخي مخزن حاليًا؛ لذلك يظل هذا تقديرًا محافظًا."
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabelValueRow(
                        title: isArabic ? "الشهر" : "Month",
                        value: BudgetDateHelper.monthTitle(monthDate)
                    )
                    LabelValueRow(
                        title: isArabic ? "المعادلة" : "Formula",
                        value: isArabic ? "كاش افتتاحي تقديري + الدخل - التعرض المتوقع للمصاريف" : "Estimated Opening Cash + Income - Projected Expense Exposure"
                    )
                } footer: {
                    Text(isArabic
                         ? "شرح قراءة فقط لقيمة رصيد الشهر المتوقع الحالية. ده مش حساب جديد ومش بيغير الميزانية أو المعاملات أو الأرصدة."
                         : "Read-only explanation of the existing Projected Month Balance value. This is not a new calculation and does not change plans, transactions, or balances.")
                }

                Section {
                    if isSelectedFutureMonth {
                        LabelValueRow(
                            title: isArabic ? "رصيد الشهر السابق المتوقع" : "Previous Month Projected Balance",
                            value: store.displayCurrency(snapshot.previousMonthProjectedBalance ?? estimatedOpeningCash)
                        )
                    } else {
                        LabelValueRow(
                            title: isArabic ? "الكاش المتاح الآن" : "Available Cash Now",
                            value: store.displayCurrency(store.availableCash)
                        )
                        LabelValueRow(
                            title: isArabic ? "المصروف الفعلي حتى الآن" : "Actual Spent So Far",
                            value: store.displayCurrency(actualSpentSoFar)
                        )
                    }
                    LabelValueRow(
                        title: isArabic ? "كاش افتتاحي تقديري" : "Estimated Opening Cash",
                        value: store.displayCurrency(estimatedOpeningCash)
                    )
                } footer: {
                    Text(isArabic
                         ? openingCashFooterArabic
                         : openingCashFooterEnglish)
                }

                Section {
                    LabelValueRow(
                        title: isArabic ? "الدخل المخطط / المتوقع" : "Planned / Expected Income",
                        value: store.displayCurrency(plannedIncome)
                    )
                } footer: {
                    Text(isArabic ? "بنود الدخل في الشهر المختار، ما عدا الملغي أو المتخطي." : "Income events in the selected month, excluding cancelled or skipped items.")
                }

                Section {
                    if categoryRows.isEmpty {
                        Text(isArabic ? "لا توجد بنود تدخل في التعرض المتوقع للمصاريف لهذا الشهر." : "No category rows contribute to projected expense exposure this month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(categoryRows) { row in
                            projectedExpenseRow(row)
                        }
                    }

                    LabelValueRow(
                        title: isArabic ? "التعرض المتوقع للمصاريف" : "Projected Expense Exposure",
                        value: store.displayCurrency(projectedExpenseExposure)
                    )
                } header: {
                    Text(isArabic ? "التعرض المتوقع للمصاريف" : "Projected Expense Exposure")
                } footer: {
                    Text(isArabic
                         ? "لكل بند: نستخدم الأكبر بين المخطط، أو المدفوع + القادم. الإجمالي هو مجموع البنود."
                         : "For each category, this uses the larger of planned, or paid + upcoming. The total is the sum of those category values.")
                }

                Section {
                    LabelValueRow(
                        title: isArabic ? "رصيد الشهر المتوقع" : "Projected Month Balance",
                        value: store.displayCurrency(projectedMonthBalance)
                    )
                } footer: {
                    Text(isArabic
                         ? "كاش افتتاحي تقديري + الدخل المخطط / المتوقع - التعرض المتوقع للمصاريف."
                         : "Estimated Opening Cash + Planned / Expected Income - Projected Expense Exposure.")
                }
            }
            .navigationTitle(isArabic ? "رصيد الشهر المتوقع" : "Projected Month Balance")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func projectedExpenseRow(_ row: ProjectedExpenseBreakdownRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.categoryName)
                    .font(.headline)

                Spacer()

                Text(store.displayCurrency(row.expectedAmount))
                    .font(.headline)
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 6) {
                compactAmountRow(title: AppText.planned(store.appLanguage), amount: row.plannedAmount)
                compactAmountRow(title: isArabic ? "المدفوع" : "Paid", amount: row.paidAmount)
                compactAmountRow(title: AppText.upcoming(store.appLanguage), amount: row.upcomingAmount)
                compactAmountRow(title: isArabic ? "المدفوع + القادم" : "Paid + Upcoming", amount: row.paidPlusUpcoming)
            }

            Text(row.reasonText(language: store.appLanguage))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func compactAmountRow(title: String, amount: Double) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(store.displayCurrency(amount))
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

private struct EstimatedOpeningCashBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore

    let monthDate: Date

    private var monthKey: (year: Int, month: Int) {
        BudgetDateHelper.monthKey(for: monthDate)
    }

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var snapshot: CurrentMonthBudgetSnapshot {
        CurrentMonthBudgetSnapshot(
            monthDate: monthDate,
            availableCash: store.availableCash,
            store: store
        )
    }

    private var actualSpentSoFar: Double {
        snapshot.actualSpent
    }

    private var isSelectedCurrentMonth: Bool {
        snapshot.isCurrentMonth
    }

    private var isSelectedFutureMonth: Bool {
        snapshot.isFutureMonth
    }

    private var estimatedOpeningCash: Double {
        snapshot.estimatedOpeningCash
    }

    private var openingCashFooterEnglish: String {
        if isSelectedCurrentMonth {
            return "Current-month estimate: available cash now + actual spent so far. This is not an exact historical opening balance."
        }

        if isSelectedFutureMonth {
            return "Future-month estimate: the previous month projected balance becomes this month’s estimated opening cash."
        }

        return "Past months do not have historical opening cash snapshots yet; this remains a conservative fallback."
    }

    private var openingCashFooterArabic: String {
        if isSelectedCurrentMonth {
            return "تقدير للشهر الحالي: الكاش المتاح الآن + المصروف الفعلي حتى الآن. ده مش رصيد افتتاحي تاريخي دقيق."
        }

        if isSelectedFutureMonth {
            return "تقدير للشهر المستقبلي: رصيد الشهر السابق المتوقع يصبح الكاش الافتتاحي التقديري لهذا الشهر."
        }

        return "الشهور السابقة لا يوجد لها رصيد افتتاحي تاريخي مخزن حاليًا؛ لذلك يظل هذا تقديرًا محافظًا."
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabelValueRow(
                        title: isArabic ? "الشهر" : "Month",
                        value: BudgetDateHelper.monthTitle(monthDate)
                    )
                    if isSelectedFutureMonth {
                        LabelValueRow(
                            title: isArabic ? "رصيد الشهر السابق المتوقع" : "Previous Month Projected Balance",
                            value: store.displayCurrency(snapshot.previousMonthProjectedBalance ?? estimatedOpeningCash)
                        )
                    } else {
                        LabelValueRow(
                            title: isArabic ? "الكاش المتاح الآن" : "Available Cash Now",
                            value: store.displayCurrency(store.availableCash)
                        )
                        LabelValueRow(
                            title: isArabic ? "المصروف الفعلي حتى الآن" : "Actual Spent So Far",
                            value: store.displayCurrency(actualSpentSoFar)
                        )
                    }
                    LabelValueRow(
                        title: isArabic ? "كاش افتتاحي تقديري" : "Estimated Opening Cash",
                        value: store.displayCurrency(estimatedOpeningCash)
                    )
                } footer: {
                    Text(isArabic
                         ? openingCashFooterArabic
                         : openingCashFooterEnglish)
                }
            }
            .navigationTitle(isArabic ? "كاش افتتاحي تقديري" : "Estimated Opening Cash")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct MonthCommittedBreakdownSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let selection: BudgetCommittedMonthSelection

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var items: [FinancialEvent] {
        store.upcomingKnownExpenseEvents(year: selection.year, month: selection.month)
            .sorted {
                if $0.date == $1.date {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }

                return $0.date < $1.date
            }
    }

    private var creditCardDueItems: [CreditCardDueItem] {
        CreditCardDueCashCommitmentHelper.dueItems(store: store, year: selection.year, month: selection.month)
    }

    private var knownCommitmentsTotal: Double {
        items.map { $0.recurringAmount(for: $0.date) }.reduce(0, +)
    }

    private var creditCardDueTotal: Double {
        creditCardDueItems.map(\.dueAmount).reduce(0, +)
    }

    private var breakdownTotal: Double {
        knownCommitmentsTotal + creditCardDueTotal
    }

    private var totalMatches: Bool {
        abs(breakdownTotal - selection.displayedAmount) < 0.01
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    detailRow(
                        title: isArabic ? "الشهر" : "Month",
                        value: BudgetDateHelper.monthTitle(selection.monthDate)
                    )
                    detailRow(
                        title: AppText.committed(store.appLanguage),
                        value: store.displayCurrency(selection.displayedAmount)
                    )
                }

                Section {
                    if items.isEmpty {
                        Text(isArabic ? "لا توجد التزامات قادمة في هذا الشهر." : "No committed source items found for this month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(items) { item in
                            if canNavigate(item) {
                                NavigationLink {
                                    destination(for: item)
                                } label: {
                                    committedRow(item)
                                }
                            } else {
                                committedRow(item)
                            }
                        }
                    }
                } header: {
                    Text(isArabic ? "التزامات معروفة" : "Known Commitments")
                } footer: {
                    Text(isArabic ? "عرض فقط. لا يتم تسجيل دفع أو تعديل أي التزام من هنا." : "Read-only. This does not mark anything paid or change any commitment.")
                }

                Section {
                    if creditCardDueItems.isEmpty {
                        Text(isArabic ? "مفيش مستحقات كروت ائتمان في الشهر ده." : "No credit card dues found for this month.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(creditCardDueItems) { item in
                            creditCardDueRow(item)
                        }
                    }
                } header: {
                    Text(isArabic ? "مستحقات كروت الائتمان" : "Credit Card Dues")
                } footer: {
                    Text(isArabic ? "التزام كاش لسداد الكارت. مش مصروف جديد ومش مضاف لمصاريف التصنيفات." : "Cash obligation to pay the card. Not new spending and not added to category actuals.")
                }

                Section {
                    detailRow(
                        title: isArabic ? "إجمالي التفاصيل" : "Source Total",
                        value: store.displayCurrency(breakdownTotal)
                    )

                    if !totalMatches {
                        Text(isArabic ? "إجمالي التفاصيل لا يطابق رقم الالتزامات في الجدول. برجاء مراجعة مصدر الحساب." : "Breakdown total does not match the grid committed value. Please review committed source logic.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle(isArabic ? "الالتزامات - \(BudgetDateHelper.monthTitle(selection.monthDate))" : "Committed - \(BudgetDateHelper.monthTitle(selection.monthDate))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isArabic ? "تم" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func committedRow(_ item: FinancialEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NamedVisualMark(
                name: item.title,
                fallbackSystemImage: sourceIcon(for: item),
                size: 32
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(item.categoryName ?? (isArabic ? "بدون بند" : "Uncategorized"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(sourceType(for: item))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(statusText(for: item))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(store.displayCurrency(item.recurringAmount(for: item.date)))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(formatDate(item.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func creditCardDueRow(_ item: CreditCardDueItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NamedVisualMark(
                name: item.cardName,
                fallbackSystemImage: "creditcard.trianglebadge.exclamationmark",
                size: 32
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.cardName)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(isArabic ? "مستحق كارت ائتمان" : "Credit Card Due")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(isArabic ? "التزام كاش - مش مصروف جديد" : "Cash obligation - not new spending")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(creditCardDueStatusText(for: item.dueDate))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(store.displayCurrency(item.dueAmount))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(formatDate(item.dueDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func destination(for item: FinancialEvent) -> some View {
        if let sourceID = item.sourceRecurringEventID,
           store.activeFinancialEvents.contains(where: { $0.id == sourceID }) {
            RecurringSeriesDetailView(eventID: sourceID)
                .environmentObject(store)
        } else if let planID = item.sourceInstallmentPlanID,
                  let plan = store.activeInstallmentPlans.first(where: { $0.id == planID }) {
            InstallmentPlanEditorView(plan: plan)
                .environmentObject(store)
        } else if item.repeatRule != .none {
            RecurringPaymentEditorView(event: item)
                .environmentObject(store)
        } else if item.sourceInstallmentPlanID == nil &&
                    item.sourceRecurringEventID == nil &&
                    item.repeatRule == .none {
            TransactionDetailView(event: item, isPresentedModally: false)
                .environmentObject(store)
        }
    }

    private func canNavigate(_ item: FinancialEvent) -> Bool {
        if let sourceID = item.sourceRecurringEventID,
           store.activeFinancialEvents.contains(where: { $0.id == sourceID }) {
            return true
        }

        if let planID = item.sourceInstallmentPlanID,
           store.activeInstallmentPlans.contains(where: { $0.id == planID }) {
            return true
        }

        if item.repeatRule != .none {
            return true
        }

        return item.sourceInstallmentPlanID == nil &&
        item.sourceRecurringEventID == nil &&
        item.repeatRule == .none
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }

    private func sourceType(for item: FinancialEvent) -> String {
        if item.sourceInstallmentPlanID != nil {
            return isArabic ? "قسط" : "Installment"
        }

        if item.sourceRecurringEventID != nil || item.repeatRule != .none {
            return isArabic ? "دفع متكرر" : "Recurring"
        }

        if item.type == .expectedExpense {
            return isArabic ? "مصروف مستقبلي" : "Future item"
        }

        if item.type == .obligation {
            return isArabic ? "التزام مرة واحدة" : "One-off obligation"
        }

        return isArabic ? "بند قادم" : "Upcoming item"
    }

    private func statusText(for item: FinancialEvent) -> String {
        if item.sourceRecurringEventID != nil {
            if item.recurringScheduleOverrides?.contains(where: { override in
                override.year == item.recurringOccurrenceYear && override.month == item.recurringOccurrenceMonth
            }) == true {
                return isArabic ? "مؤكد" : "confirmed"
            }

            if item.effectiveRecurringAmountMode != .fixedAmount {
                return isArabic ? "تقديري" : "estimated"
            }
        }

        switch item.status {
        case .paid:
            return isArabic ? "مدفوع" : "paid"
        case .unpaid:
            return isArabic ? "غير مدفوع" : "unpaid"
        case .expected:
            return isArabic ? "متوقع" : "expected"
        case .planned:
            return isArabic ? "مخطط" : "planned"
        case .cancelled:
            return isArabic ? "ملغي" : "cancelled"
        case .skipped:
            return isArabic ? "متخطي" : "skipped"
        }
    }

    private func creditCardDueStatusText(for dueDate: Date) -> String {
        let today = Calendar.current.startOfDay(for: Date())
        let dueDay = Calendar.current.startOfDay(for: dueDate)

        if dueDay < today {
            return isArabic ? "متأخر" : "overdue"
        }

        if Calendar.current.isDateInToday(dueDay) {
            return isArabic ? "مستحق النهارده" : "due today"
        }

        let days = Calendar.current.dateComponents([.day], from: today, to: dueDay).day ?? 0
        if days <= 7 {
            return isArabic ? "قريب" : "due soon"
        }

        return isArabic ? "غير مدفوع" : "unpaid"
    }

    private func sourceIcon(for item: FinancialEvent) -> String {
        if item.sourceInstallmentPlanID != nil {
            return "creditcard.fill"
        }

        if item.sourceRecurringEventID != nil || item.repeatRule != .none {
            return "repeat"
        }

        return "calendar.badge.clock"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

private struct LabelValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct BudgetCellSelection: Identifiable {
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

private enum BudgetGridApplyRoute: Identifiable {
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

private enum BudgetGridBulkActionType: String {
    case useCommittedAsBudget
    case applyToFutureMonths
    case applyToSelectedMonths
}

private struct BudgetGridPreviousBudgetValue {
    let categoryName: String
    let date: Date
    let year: Int
    let month: Int
    let existed: Bool
    let amount: Double
}

private struct BudgetGridUndoAction: Identifiable {
    let id = UUID()
    let categoryName: String
    let previousValues: [BudgetGridPreviousBudgetValue]
    let newAmount: Double
    let actionType: BudgetGridBulkActionType
    let timestamp: Date

    var monthCount: Int {
        previousValues.count
    }

    static func capture(
        categoryName: String,
        dates: [Date],
        newAmount: Double,
        actionType: BudgetGridBulkActionType,
        store: WalletStore
    ) -> BudgetGridUndoAction {
        BudgetGridUndoAction(
            categoryName: categoryName,
            previousValues: dates.map { date in
                let key = BudgetDateHelper.monthKey(for: date)
                return BudgetPlanningWriter.plannedValue(
                    categoryName: categoryName,
                    date: date,
                    year: key.year,
                    month: key.month,
                    store: store
                )
            },
            newAmount: newAmount,
            actionType: actionType,
            timestamp: Date()
        )
    }

    func restore(in store: WalletStore) {
        for previousValue in previousValues {
            BudgetPlanningWriter.restorePlannedValue(previousValue, store: store)
        }
    }
}

private struct BudgetMonthSelection: Identifiable {
    let id = UUID()
    let date: Date
}

private struct CategoryUpcomingSelection: Identifiable {
    let id = UUID()
    let monthDate: Date
    let year: Int
    let month: Int
    let categoryName: String
    let displayedAmount: Double
}

private enum BudgetCategoryAction: Hashable, Identifiable {
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

private struct BudgetCommittedMonthSelection: Identifiable {
    let id = UUID()
    let monthDate: Date
    let year: Int
    let month: Int
    let displayedAmount: Double
}

private struct BudgetMonthProjection: Identifiable {
    var id: String { "\(year)-\(month)" }
    let date: Date
    let year: Int
    let month: Int
    let openingBalance: Double
    let plannedIncome: Double
    let plannedExpenses: Double
    let paidActual: Double
    let knownUpcoming: Double
    let projectedExpenses: Double
    let projectedClosingBalance: Double
    let safeThreshold: Double

    var endBalanceColor: Color {
        if projectedClosingBalance < 0 {
            return .red
        }

        guard safeThreshold > 0 else {
            return .green
        }

        if projectedClosingBalance < safeThreshold {
            return .red
        }

        if projectedClosingBalance <= safeThreshold * 1.20 {
            return .yellow
        }

        return .green
    }
}

private struct BudgetGridMonthKey: Hashable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(date: Date) {
        let key = BudgetDateHelper.monthKey(for: date)
        self.year = key.year
        self.month = key.month
    }
}

private struct BudgetGridMonthData {
    let date: Date
    let year: Int
    let month: Int
    let plannedByCategory: [String: Double]
    let paidByCategory: [String: Double]
    let upcomingByCategory: [String: Double]
    let creditCardDueTotal: Double
    let plannedIncome: Double

    var plannedExpensesTotal: Double {
        plannedByCategory.values.reduce(0, +)
    }

    var paidActualTotal: Double {
        paidByCategory.values.reduce(0, +)
    }

    var upcomingKnownTotal: Double {
        upcomingByCategory.values.reduce(0, +) + creditCardDueTotal
    }
}

private struct BudgetGridSnapshotSignature: Hashable {
    let monthDates: [Date]
    let availableCash: Double
    let safeThreshold: Double
    let financialDataVersion: Date
}

private struct BudgetGridSnapshot {
    let monthDates: [Date]
    let categories: [String]
    let projectionRows: [BudgetMonthProjection]

    private let monthDataByKey: [BudgetGridMonthKey: BudgetGridMonthData]

    init(
        monthDates: [Date],
        initialOpeningBalance: Double,
        safeThreshold: Double,
        store: WalletStore
    ) {
        self.monthDates = monthDates

        var categoryNames = store.activeCategories.map { $0.name }
        var dataByKey: [BudgetGridMonthKey: BudgetGridMonthData] = [:]

        for date in monthDates {
            let monthKey = BudgetGridMonthKey(date: date)
            let budget = store.monthlyBudget(year: monthKey.year, month: monthKey.month)
            let plannedByCategory = Dictionary(
                uniqueKeysWithValues: (budget?.items ?? []).map { item in
                    (item.categoryName, item.plannedAmount)
                }
            )
            let paidByCategory = store.actualSpendingByCategory(year: monthKey.year, month: monthKey.month)
            let upcomingByCategory = store.upcomingKnownExpensesByCategory(year: monthKey.year, month: monthKey.month)
            let creditCardDueTotal = CreditCardDueCashCommitmentHelper.dueTotal(
                store: store,
                year: monthKey.year,
                month: monthKey.month
            )
            let plannedIncome = Self.plannedIncomeTotal(
                store: store,
                year: monthKey.year,
                month: monthKey.month
            )

            Self.appendMissingNames(Array(plannedByCategory.keys), to: &categoryNames)
            Self.appendMissingNames(Array(paidByCategory.keys), to: &categoryNames)
            Self.appendMissingNames(Array(upcomingByCategory.keys), to: &categoryNames)

            dataByKey[monthKey] = BudgetGridMonthData(
                date: date,
                year: monthKey.year,
                month: monthKey.month,
                plannedByCategory: plannedByCategory,
                paidByCategory: paidByCategory,
                upcomingByCategory: upcomingByCategory,
                creditCardDueTotal: creditCardDueTotal,
                plannedIncome: plannedIncome
            )
        }

        let sortedCategories = categoryNames.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        self.categories = sortedCategories
        self.monthDataByKey = dataByKey

        var opening = initialOpeningBalance
        self.projectionRows = monthDates.map { date in
            let monthKey = BudgetGridMonthKey(date: date)
            let monthData = dataByKey[monthKey]
            let plannedExpenses = monthData?.plannedExpensesTotal ?? 0
            let paidActual = monthData?.paidActualTotal ?? 0
            let knownUpcoming = monthData?.upcomingKnownTotal ?? 0
            let projectedExpenses = Self.projectedExpenseExposureTotal(
                categories: sortedCategories,
                monthData: monthData
            )
            let income = monthData?.plannedIncome ?? 0
            let closing = opening + income - plannedExpenses
            defer { opening = closing }
            return BudgetMonthProjection(
                date: date,
                year: monthKey.year,
                month: monthKey.month,
                openingBalance: opening,
                plannedIncome: income,
                plannedExpenses: plannedExpenses,
                paidActual: paidActual,
                knownUpcoming: knownUpcoming,
                projectedExpenses: projectedExpenses,
                projectedClosingBalance: closing,
                safeThreshold: safeThreshold
            )
        }
    }

    func cellData(category: String, year: Int, month: Int) -> BudgetGridCellData {
        let key = BudgetGridMonthKey(year: year, month: month)
        let monthData = monthDataByKey[key]
        return BudgetGridCellData(
            date: monthData?.date ?? BudgetDateHelper.date(year: year, month: month) ?? Date(),
            year: year,
            month: month,
            categoryName: category,
            plannedAmount: monthData?.plannedByCategory[category] ?? 0,
            paidActualAmount: monthData?.paidByCategory[category] ?? 0,
            knownUpcomingAmount: monthData?.upcomingByCategory[category] ?? 0
        )
    }

    func categoryProjectedTotal(category: String) -> Double {
        projectionRows
            .map { row in
                cellData(category: category, year: row.year, month: row.month).effectiveProjectedAmount
            }
            .reduce(0, +)
    }

    private static func appendMissingNames(_ names: [String], to categoryNames: inout [String]) {
        for name in names where !categoryNames.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            categoryNames.append(name)
        }
    }

    private static func projectedExpenseExposureTotal(
        categories: [String],
        monthData: BudgetGridMonthData?
    ) -> Double {
        categories
            .map { category in
                let planned = monthData?.plannedByCategory[category] ?? 0
                let paid = monthData?.paidByCategory[category] ?? 0
                let upcoming = monthData?.upcomingByCategory[category] ?? 0
                return max(planned, paid + upcoming)
            }
            .reduce(0, +)
    }

    private static func plannedIncomeTotal(store: WalletStore, year: Int, month: Int) -> Double {
        store.monthlyBudgetIncome(year: year, month: month)
    }
}

private struct BudgetGridCellData {
    let date: Date
    let year: Int
    let month: Int
    let categoryName: String
    let plannedAmount: Double
    let paidActualAmount: Double
    let knownUpcomingAmount: Double

    var effectiveProjectedAmount: Double {
        max(plannedAmount, paidActualAmount + knownUpcomingAmount)
    }

    var remainingAfterKnown: Double {
        plannedAmount - paidActualAmount - knownUpcomingAmount
    }

    var mainDisplayAmount: Double {
        if plannedAmount > 0 {
            return plannedAmount
        }

        if knownUpcomingAmount > 0 {
            return knownUpcomingAmount
        }

        return paidActualAmount
    }

    var mainColor: Color {
        if plannedAmount <= 0 && knownUpcomingAmount > 0 {
            return .orange
        }

        if plannedAmount > 0 && paidActualAmount + knownUpcomingAmount > plannedAmount {
            return .red
        }

        return .primary
    }

    var statusColor: Color {
        if plannedAmount <= 0 && knownUpcomingAmount > 0 {
            return .orange
        }

        if plannedAmount > 0 && paidActualAmount + knownUpcomingAmount > plannedAmount {
            return .red
        }

        return .secondary
    }

    var backgroundColor: Color {
        if plannedAmount <= 0 && knownUpcomingAmount > 0 {
            return Color.orange.opacity(0.10)
        }

        if plannedAmount > 0 && paidActualAmount + knownUpcomingAmount > plannedAmount {
            return Color.red.opacity(0.08)
        }

        return Color.clear
    }

    func secondaryLabel(language: AppLanguage, store: WalletStore) -> String {
        if plannedAmount <= 0 && knownUpcomingAmount > 0 {
            return language == .arabicEgyptian ? "ملتزم \(store.displayCurrency(knownUpcomingAmount))" : "Committed \(store.displayCurrency(knownUpcomingAmount))"
        }

        if plannedAmount > 0 && knownUpcomingAmount > 0 {
            return language == .arabicEgyptian ? "ملتزم \(store.displayCurrency(knownUpcomingAmount))" : "Committed \(store.displayCurrency(knownUpcomingAmount))"
        }

        if paidActualAmount > 0 {
            return language == .arabicEgyptian ? "مدفوع \(store.displayCurrency(paidActualAmount))" : "Paid \(store.displayCurrency(paidActualAmount))"
        }

        return ""
    }
}

private enum BudgetPlanningWriter {
    static func plannedValue(
        categoryName: String,
        date: Date,
        year: Int,
        month: Int,
        store: WalletStore
    ) -> BudgetGridPreviousBudgetValue {
        let item = store.monthlyBudget(year: year, month: month)?
            .items
            .first { $0.categoryName.caseInsensitiveCompare(categoryName) == .orderedSame }

        return BudgetGridPreviousBudgetValue(
            categoryName: categoryName,
            date: date,
            year: year,
            month: month,
            existed: item != nil,
            amount: item?.plannedAmount ?? 0
        )
    }

    static func setPlannedAmount(
        _ amount: Double,
        categoryName: String,
        year: Int,
        month: Int,
        store: WalletStore
    ) {
        var plannedAmounts = Dictionary(uniqueKeysWithValues: (store.monthlyBudget(year: year, month: month)?.items ?? []).map { item in
            (item.categoryName, item.plannedAmount)
        })
        plannedAmounts[categoryName] = max(amount, 0)
        store.saveMonthlyBudget(year: year, month: month, plannedAmountsByCategory: plannedAmounts)
    }

    static func restorePlannedValue(_ previousValue: BudgetGridPreviousBudgetValue, store: WalletStore) {
        var plannedAmounts = Dictionary(uniqueKeysWithValues: (store.monthlyBudget(year: previousValue.year, month: previousValue.month)?.items ?? []).map { item in
            (item.categoryName, item.plannedAmount)
        })

        if previousValue.existed {
            plannedAmounts[previousValue.categoryName] = max(previousValue.amount, 0)
        } else {
            plannedAmounts = plannedAmounts.filter { key, _ in
                key.caseInsensitiveCompare(previousValue.categoryName) != .orderedSame
            }
        }

        store.saveMonthlyBudget(
            year: previousValue.year,
            month: previousValue.month,
            plannedAmountsByCategory: plannedAmounts
        )
    }
}

private enum BudgetDateHelper {
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
