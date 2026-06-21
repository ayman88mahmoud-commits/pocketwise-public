import SwiftUI
import Charts

// MARK: - UI-only display structs (never persisted, never backed up)

struct AffordabilityResult {
    let verdict: RunwayCheckStatus
    let newLowestBalance: Double
    let newLowestBalanceDate: Date
    let bufferDaysChange: Int
    let affectsRunway: Bool
}

private struct RunwayEventItem: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let title: String
    let amount: Double
    let isInflow: Bool
    let sourceType: String
    let balanceAfter: Double?
}

private struct RunwayProjectionMatch {
    let itemDate: Date
    let matchedPoint: RunwayProjectionPoint
    let matchKind: String
    let previousPoint: RunwayProjectionPoint?
    let nextPoint: RunwayProjectionPoint?
}

private struct RunwayMapSnapshot {
    let startDate: Date
    let targetDate: Date
    let result: RunwayCheckResult
    let projectionPoints: [RunwayProjectionPoint]
    let chartPoints: [RunwayProjectionPoint]
    let eventItems: [RunwayEventItem]
    let chartYDomain: ClosedRange<Double>
}

// MARK: - Horizon options

private enum RunwayHorizonOption: Hashable {
    case days30
    case days60
    case days180
    case customDate(Date)

    func targetDate(from today: Date) -> Date {
        let cal = Calendar.current
        switch self {
        case .days30:          return cal.date(byAdding: .day, value: 30,  to: today) ?? today
        case .days60:          return cal.date(byAdding: .day, value: 60,  to: today) ?? today
        case .days180:         return cal.date(byAdding: .day, value: 180, to: today) ?? today
        case .customDate(let d): return d > today ? d : today
        }
    }
}

// MARK: - Main view

struct RunwayChartView: View {

    @EnvironmentObject private var store: WalletStore

    @State private var horizon: RunwayHorizonOption = .days180
    @State private var isShowingCustomDatePicker = false
    @State private var customDate: Date = Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date()
    @State private var snapshot: RunwayMapSnapshot?
    @State private var isLoadingSnapshot = false
    @State private var snapshotTask: Task<Void, Never>?
    @State private var selectedProjectionPoint: RunwayProjectionPoint?
#if DEBUG
    @State private var diagnosticItem: RunwayEventItem?
#endif

    // Affordability state — all ephemeral, never persisted
    @State private var affordabilityAmountText = ""
    @State private var affordabilityDate: Date = Date()
    @State private var cachedAffordabilityResult: AffordabilityResult? = nil
    @State private var cachedAffordabilityPoints: [RunwayProjectionPoint]? = nil
    @FocusState private var isAmountFocused: Bool

    private var today: Date { Date() }
    private var horizonDate: Date { horizon.targetDate(from: today) }
    private var horizonDateKey: Date { Calendar.current.startOfDay(for: horizonDate) }

    private var isCustomHorizonSelected: Bool {
        if case .customDate = horizon { return true }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                horizonPickerSection
                if let snapshot {
                    chartSection(snapshot)
                    eventsSection(snapshot)
                    affordabilitySection(snapshot)
                } else {
                    loadingSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(PocketWiseTheme.screenBackground)
        .navigationTitle(AppText.runwayMapTitle(store.appLanguage))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $isShowingCustomDatePicker) {
            customDatePickerSheet
        }
#if DEBUG
        .sheet(item: $diagnosticItem) { item in
            if let snapshot {
                diagnosticSheet(for: item, snapshot: snapshot)
            } else {
                Text("Runway snapshot is not available.")
            }
        }
#endif
        .task(id: horizonDateKey) {
            refreshSnapshot()
        }
        .onDisappear {
            snapshotTask?.cancel()
        }
        .onChange(of: affordabilityAmountText) { _, _ in updateAffordability() }
        .onChange(of: affordabilityDate) { _, _ in updateAffordability() }
    }

    // MARK: - Horizon Picker

    private var horizonPickerSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                horizonChip(.days30,  label: AppText.timelineHorizon30(store.appLanguage))
                horizonChip(.days60,  label: AppText.timelineHorizon60(store.appLanguage))
                horizonChip(.days180, label: AppText.runwayMapHorizon180(store.appLanguage))
                customHorizonChip
            }
            .padding(.horizontal, 2)
        }
    }

    private func horizonChip(_ option: RunwayHorizonOption, label: String) -> some View {
        let selected = horizon == option
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { horizon = option }
        } label: {
            Text(label)
                .font(.subheadline)
                .fontWeight(selected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var customHorizonChip: some View {
        Button {
            isShowingCustomDatePicker = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.subheadline)
                if case .customDate(let d) = horizon {
                    Text(shortDateLabel(d))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } else {
                    Text(AppText.timelineHorizonPickDate(store.appLanguage))
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isCustomHorizonSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isCustomHorizonSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var customDatePickerSheet: some View {
        NavigationStack {
            DatePicker(
                AppText.timelineHorizonPickDate(store.appLanguage),
                selection: $customDate,
                in: (Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today)...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .navigationTitle(AppText.timelineHorizonPickDate(store.appLanguage))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.done(store.appLanguage)) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            horizon = .customDate(customDate)
                        }
                        isShowingCustomDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(store.appLanguage == .arabicEgyptian ? "جاري حساب خريطة السيولة..." : "Calculating runway map...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .pocketWiseCard(semanticColor: .accounts, padding: 24, cornerRadius: 16, showsBorder: true)
    }

    // MARK: - Chart Section

    private func chartYDomain(for snapshot: RunwayMapSnapshot) -> ClosedRange<Double> {
        var values = [
            snapshot.chartYDomain.lowerBound,
            snapshot.chartYDomain.upperBound
        ]
        if let testPoints = cachedAffordabilityPoints {
            values.append(contentsOf: testPoints.map(\.balance))
        }
        return Self.chartDomain(for: values)
    }

    private func xAxisMarkDates(for snapshot: RunwayMapSnapshot) -> [Date] {
        let calendar = Calendar.current
        let dayCount = calendar.dateComponents([.day], from: snapshot.startDate, to: snapshot.targetDate).day ?? 0

        if dayCount <= 45 {
            return strideDates(every: 7, startDate: snapshot.startDate, targetDate: snapshot.targetDate)
        }

        return monthLabelDates(startDate: snapshot.startDate, targetDate: snapshot.targetDate)
    }

    private func chartSection(_ snapshot: RunwayMapSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {

            // Status headline row
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle()
                    .fill(statusColor(for: snapshot.result.status))
                    .frame(width: 9, height: 9)
                Text(statusHeadline(for: snapshot.result))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(statusColor(for: snapshot.result.status))
            }

            // Key metrics
            HStack(alignment: .top, spacing: 20) {
                metricPill(
                    label: AppText.lowestCashReach(store.appLanguage),
                    value: formatCurrency(snapshot.result.lowestExpectedBalance),
                    date: snapshot.result.lowestBalanceDate
                )
                if let inflow = snapshot.result.nextCashInflow {
                    metricPill(
                        label: AppText.runwayNextIncome(store.appLanguage),
                        value: formatCurrency(inflow.amount),
                        date: inflow.date
                    )
                }
            }

            // Line chart — clean line only, no area fill
            Chart {
                // Baseline trajectory line
                ForEach(snapshot.chartPoints) { pt in
                    LineMark(
                        x: .value("Date", pt.date),
                        y: .value("Balance", pt.balance)
                    )
                    .foregroundStyle(statusColor(for: snapshot.result.status))
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.monotone)
                }

                // Safe balance floor — dashed rule with label above the line
                if store.runwaySafeBalanceTarget > 0 {
                    RuleMark(y: .value("Safe floor", store.runwaySafeBalanceTarget))
                        .foregroundStyle(PocketWiseSemanticColor.warning.tint.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text(AppText.runwaySafeFloor(store.appLanguage))
                                .font(.caption2)
                                .foregroundStyle(PocketWiseSemanticColor.warning.tint)
                                .padding(.leading, 4)
                                .padding(.bottom, 2)
                        }
                }

                // Lowest balance marker
                if let lowest = snapshot.projectionPoints.min(by: { $0.balance < $1.balance }) {
                    PointMark(
                        x: .value("Date", lowest.date),
                        y: .value("Balance", lowest.balance)
                    )
                    .foregroundStyle(PocketWiseSemanticColor.warning.tint)
                    .symbolSize(60)
                }

                // Next cash inflow marker
                if let inflow = snapshot.result.nextCashInflow {
                    PointMark(
                        x: .value("Date", inflow.date),
                        y: .value("Balance", balanceAt(date: inflow.date, in: snapshot.projectionPoints, fallback: snapshot.result.availableCash))
                    )
                    .foregroundStyle(PocketWiseSemanticColor.income.tint)
                    .symbolSize(60)
                }

                // Affordability overlay — dashed what-if trajectory
                if let testPoints = cachedAffordabilityPoints {
                    ForEach(testPoints) { pt in
                        LineMark(
                            x: .value("Date", pt.date),
                            y: .value("Balance", pt.balance)
                        )
                        .foregroundStyle(PocketWiseSemanticColor.budgets.tint.opacity(0.75))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .interpolationMethod(.monotone)
                    }
                }

                if let selectedProjectionPoint {
                    RuleMark(x: .value("Selected date", selectedProjectionPoint.date))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    PointMark(
                        x: .value("Selected date", selectedProjectionPoint.date),
                        y: .value("Selected balance", selectedProjectionPoint.balance)
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(80)
                }
            }
            .frame(height: 220)
            .chartXScale(domain: snapshot.startDate...snapshot.targetDate)
            .chartXAxis {
                AxisMarks(values: xAxisMarkDates(for: snapshot)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.secondary.opacity(0.16))
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(xAxisLabel(for: date, in: snapshot))
                                .font(.caption2)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
            }
            .chartYScale(domain: chartYDomain(for: snapshot))
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    selectProjectionPoint(at: value.location, proxy: proxy, geometry: geometry, snapshot: snapshot)
                                }
                        )
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(compactCurrency(v))
                                .font(.caption2)
                        }
                    }
                }
            }
            if let selectedProjectionPoint {
                selectedPointCard(selectedProjectionPoint, snapshot: snapshot)
            }
            Text(store.appLanguage == .arabicEgyptian
                 ? "الرسم يشمل تقديرات الميزانية والعناصر النقدية المتوقعة. رصيد نهاية اليوم يعكس التوقع الكامل لذلك التاريخ."
                 : "Chart includes planned budget estimates and projected cash-impact items. Day-end balance reflects the full runway projection for that date.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .pocketWiseCard(semanticColor: statusSemanticColor(for: snapshot.result.status), padding: 16, cornerRadius: 16, showsBorder: true, showsShadow: true)
    }

    // MARK: - Events Section

    private func eventsSection(_ snapshot: RunwayMapSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppText.runwayUpcomingItems(store.appLanguage))
                .font(.headline)
                .fontWeight(.semibold)

            if snapshot.eventItems.isEmpty {
                Text(AppText.timelineEmpty(store.appLanguage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(snapshot.eventItems.enumerated()), id: \.element.id) { index, item in
                        eventRow(item, snapshot: snapshot)
                        if index < snapshot.eventItems.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .pocketWiseCard(semanticColor: .accounts, padding: 0, cornerRadius: 12, showsBorder: true)
            }
        }
    }

    private func eventRow(_ item: RunwayEventItem, snapshot: RunwayMapSnapshot) -> some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(
                systemName: item.isInflow ? "arrow.down.circle.fill" : "calendar.badge.clock",
                semanticColor: item.isInflow ? .income : .obligations,
                size: 34,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(item.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let balanceAfter = item.balanceAfter {
                    Text(balanceAfterLabel(balanceAfter))
                        .font(.caption2)
                        .foregroundStyle(balanceAfter < 0 ? Color.red : Color.secondary)
                }
            }

            Spacer()

            Text((item.isInflow ? "+" : "−") + formatCurrency(item.amount))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(item.isInflow ? PocketWiseSemanticColor.income.tint : PocketWiseSemanticColor.obligations.tint)

#if DEBUG
            Button {
                let report = diagnosticReport(for: item, snapshot: snapshot)
                print(report)
                diagnosticItem = item
            } label: {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Runway balance diagnostic")
#endif
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
#if DEBUG
        .onLongPressGesture {
            let report = diagnosticReport(for: item, snapshot: snapshot)
            print(report)
            diagnosticItem = item
        }
#endif
    }

    private func selectedPointCard(_ point: RunwayProjectionPoint, snapshot: RunwayMapSnapshot) -> some View {
        let safeFloor = snapshot.result.minimumSafeBalance
        let delta = point.balance - safeFloor
        let nearbyEvents = nearbyEvents(for: point.date, in: snapshot.eventItems)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(point.date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(selectedPointStatus(balance: point.balance, safeFloor: safeFloor))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedPointStatusColor(balance: point.balance, safeFloor: safeFloor))
            }

            HStack {
                Text(store.appLanguage == .arabicEgyptian ? "الرصيد المتوقع" : "Projected balance")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatCurrency(point.balance))
                    .fontWeight(.semibold)
            }
            .font(.caption)

            HStack {
                Text(delta < 0
                     ? (store.appLanguage == .arabicEgyptian ? "أقل من الحد الآمن" : "Below safe floor by")
                     : (store.appLanguage == .arabicEgyptian ? "فوق الحد الآمن" : "Above safe floor by"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatCurrency(abs(delta)))
                    .foregroundStyle(delta < 0 ? Color.red : Color.secondary)
            }
            .font(.caption)

            if !nearbyEvents.isEmpty {
                Text((store.appLanguage == .arabicEgyptian ? "أحداث قريبة: " : "Nearby events: ") + nearbyEvents.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .pocketWiseCard(semanticColor: delta < 0 ? .warning : .success, padding: 12, cornerRadius: 12, showsBorder: true)
    }

#if DEBUG
    private func diagnosticSheet(for item: RunwayEventItem, snapshot: RunwayMapSnapshot) -> some View {
        let report = diagnosticReport(for: item, snapshot: snapshot)

        return NavigationStack {
            ScrollView {
                Text(report)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(16)
            }
            .navigationTitle("Runway balance diagnostic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppText.done(store.appLanguage)) {
                        diagnosticItem = nil
                    }
                }
            }
        }
    }
#endif

    // MARK: - Can I Afford This Section

    private func affordabilitySection(_ snapshot: RunwayMapSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppText.affordabilityTitle(store.appLanguage))
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                // Amount row
                HStack {
                    Text(AppText.affordabilityAmount(store.appLanguage))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("0", text: $affordabilityAmountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 130)
                        .focused($isAmountFocused)
                        .font(.subheadline)
                        .pocketWiseInputField(semanticColor: .spending, isProminent: true)
                }

                Divider()

                // Date row
                DatePicker(
                    AppText.affordabilityDate(store.appLanguage),
                    selection: $affordabilityDate,
                    in: today...,
                    displayedComponents: .date
                )
                .font(.subheadline)
                .pocketWiseInputField(semanticColor: .obligations)
            }
            .pocketWiseCard(semanticColor: .spending, padding: 14, cornerRadius: 12, showsBorder: true)

            // Reset button — only visible when amount is entered
            if !affordabilityAmountText.isEmpty {
                Button(AppText.affordabilityReset(store.appLanguage)) {
                    affordabilityAmountText = ""
                    affordabilityDate = today
                    cachedAffordabilityResult = nil
                    cachedAffordabilityPoints = nil
                    isAmountFocused = false
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            // Result card — only visible when amount is valid
            if let ar = cachedAffordabilityResult {
                affordabilityResultCard(ar)
            }
        }
        .pocketWiseCard(semanticColor: .spending, padding: 16, cornerRadius: 16, showsBorder: true)
    }

    private func affordabilityResultCard(_ ar: AffordabilityResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            // Verdict
            HStack(spacing: 6) {
                Circle()
                    .fill(verdictColor(ar.verdict))
                    .frame(width: 9, height: 9)
                Text(verdictLabel(ar.verdict))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(verdictColor(ar.verdict))
                Spacer()
            }

            // New lowest balance
            HStack {
                Text(AppText.runwayNewLowestBalance(store.appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(formatCurrency(ar.newLowestBalance))
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(ar.newLowestBalanceDate, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Buffer impact
            if ar.bufferDaysChange < 0 {
                Text(AppText.runwayReducesBuffer(store.appLanguage, days: abs(ar.bufferDaysChange)))
                    .font(.caption)
                    .foregroundStyle(PocketWiseSemanticColor.warning.tint)
            } else if !ar.affectsRunway {
                Text(AppText.runwayNoEffect(store.appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Computation Helpers

    private func refreshSnapshot() {
        snapshotTask?.cancel()
        isLoadingSnapshot = true
        selectedProjectionPoint = nil
        cachedAffordabilityResult = nil
        cachedAffordabilityPoints = nil

        let startDate = Date()
        let targetDate = horizon.targetDate(from: startDate)
        let accounts = store.accounts
        let financialEvents = store.financialEvents + store.expectedRepaymentEvents()
        let monthlyBudgets = store.monthlyBudgets
        let creditCardPurchases = store.creditCardPurchases
        let creditCardDueItems = store.creditCardDueItemsForRunway(from: startDate, to: targetDate)
        let minimumSafeBalance = store.runwaySafeBalanceTarget

        snapshotTask = Task {
            await Task.yield()

            let newSnapshot = Self.makeSnapshot(
                accounts: accounts,
                financialEvents: financialEvents,
                monthlyBudgets: monthlyBudgets,
                creditCardPurchases: creditCardPurchases,
                creditCardDueItems: creditCardDueItems,
                minimumSafeBalance: minimumSafeBalance,
                startDate: startDate,
                targetDate: targetDate
            )

            guard !Task.isCancelled else { return }
            snapshot = newSnapshot
            selectedProjectionPoint = nil
            isLoadingSnapshot = false
        }
    }

    private static func makeSnapshot(
        accounts: [Account],
        financialEvents: [FinancialEvent],
        monthlyBudgets: [WalletMonthlyBudget],
        creditCardPurchases: [CreditCardPurchase],
        creditCardDueItems: [CreditCardDueItem],
        minimumSafeBalance: Double,
        startDate: Date,
        targetDate: Date
    ) -> RunwayMapSnapshot {
        let result = ForecastEngine.calculateRunwayCheck(
            accounts: accounts,
            financialEvents: financialEvents,
            monthlyBudgets: monthlyBudgets,
            creditCardPurchases: creditCardPurchases,
            creditCardDueItems: creditCardDueItems,
            minimumSafeBalance: minimumSafeBalance,
            from: startDate,
            targetDate: targetDate
        )

        let projectionPoints = ForecastEngine.calculateRunwayProjectionPoints(
            accounts: accounts,
            financialEvents: financialEvents,
            monthlyBudgets: monthlyBudgets,
            creditCardPurchases: creditCardPurchases,
            creditCardDueItems: creditCardDueItems,
            from: startDate,
            targetDate: targetDate
        )

        let eventItems = makeEventItems(from: result, projectionPoints: projectionPoints)
        var values = projectionPoints.map(\.balance)
        if minimumSafeBalance > 0 {
            values.append(minimumSafeBalance)
        }
        let domain = chartDomain(for: values)

        return RunwayMapSnapshot(
            startDate: Calendar.current.startOfDay(for: startDate),
            targetDate: Calendar.current.startOfDay(for: targetDate),
            result: result,
            projectionPoints: projectionPoints,
            chartPoints: downsampledChartPoints(projectionPoints),
            eventItems: eventItems,
            chartYDomain: domain
        )
    }

    private static func makeEventItems(
        from result: RunwayCheckResult,
        projectionPoints: [RunwayProjectionPoint]
    ) -> [RunwayEventItem] {
        let bd = result.breakdown
        let inflows = bd.futureCashInflowItems.map {
            RunwayEventItem(
                date: $0.date,
                title: $0.title,
                amount: $0.amount,
                isInflow: true,
                sourceType: $0.sourceType,
                balanceAfter: projectionMatch(for: $0.date, in: projectionPoints)?.matchedPoint.balance
            )
        }
        let obligations = bd.datedObligationItems.map {
            RunwayEventItem(
                date: $0.date,
                title: $0.title,
                amount: $0.amount,
                isInflow: false,
                sourceType: $0.sourceType,
                balanceAfter: projectionMatch(for: $0.date, in: projectionPoints)?.matchedPoint.balance
            )
        }
        let recurring = bd.recurringInstallmentItems.map {
            RunwayEventItem(
                date: $0.date,
                title: $0.title,
                amount: $0.amount,
                isInflow: false,
                sourceType: $0.sourceType,
                balanceAfter: projectionMatch(for: $0.date, in: projectionPoints)?.matchedPoint.balance
            )
        }
        return (inflows + obligations + recurring).sorted { $0.date < $1.date }
    }

    private static func projectedBalance(after date: Date, in points: [RunwayProjectionPoint]) -> Double? {
        projectionMatch(for: date, in: points)?.matchedPoint.balance
    }

    private static func projectionMatch(for date: Date, in points: [RunwayProjectionPoint]) -> RunwayProjectionMatch? {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        guard !points.isEmpty else { return nil }

        let previous = points.last(where: { calendar.startOfDay(for: $0.date) < day })
        let exact = points.first(where: { calendar.isDate($0.date, inSameDayAs: day) })
        let after = points.first(where: { calendar.startOfDay(for: $0.date) > day })

        if let exact {
            return RunwayProjectionMatch(
                itemDate: day,
                matchedPoint: exact,
                matchKind: "exact same date",
                previousPoint: previous,
                nextPoint: after
            )
        }

        if let after {
            return RunwayProjectionMatch(
                itemDate: day,
                matchedPoint: after,
                matchKind: "nearest after",
                previousPoint: previous,
                nextPoint: points.first(where: { calendar.startOfDay(for: $0.date) > calendar.startOfDay(for: after.date) })
            )
        }

        guard let before = points.last(where: { calendar.startOfDay(for: $0.date) < day }) else {
            return nil
        }

        return RunwayProjectionMatch(
            itemDate: day,
            matchedPoint: before,
            matchKind: "nearest before",
            previousPoint: points.last(where: { calendar.startOfDay(for: $0.date) < calendar.startOfDay(for: before.date) }),
            nextPoint: nil
        )
    }

    private static func downsampledChartPoints(_ points: [RunwayProjectionPoint], maxCount: Int = 240) -> [RunwayProjectionPoint] {
        guard points.count > maxCount, maxCount > 2 else { return points }

        let step = max(1, Int(ceil(Double(points.count) / Double(maxCount))))
        var selected = points.enumerated().compactMap { index, point in
            index % step == 0 ? point : nil
        }

        if let lowest = points.min(by: { $0.balance < $1.balance }) {
            selected.append(lowest)
        }
        if let last = points.last {
            selected.append(last)
        }

        let grouped = Dictionary(grouping: selected) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.compactMap { date, points in
            points.min(by: { abs($0.balance) < abs($1.balance) }) ?? RunwayProjectionPoint(date: date, balance: 0)
        }
        .sorted { $0.date < $1.date }
    }

    private static func chartDomain(for values: [Double]) -> ClosedRange<Double> {
        guard let minVal = values.min(), let maxVal = values.max() else { return 0...1 }
        let range = max(maxVal - minVal, 1_000)
        let pad = range * 0.15
        return (minVal - pad)...(maxVal + pad)
    }

    private func updateAffordability() {
        guard let snapshot else {
            cachedAffordabilityResult = nil
            cachedAffordabilityPoints = nil
            return
        }

        guard let amount = Double(affordabilityAmountText), amount > 0 else {
            cachedAffordabilityResult = nil
            cachedAffordabilityPoints = nil
            return
        }
        let (result, points) = computeAffordability(amount: amount, on: affordabilityDate, snapshot: snapshot)
        cachedAffordabilityResult = result
        cachedAffordabilityPoints = points
    }

    private func computeAffordability(
        amount: Double,
        on date: Date,
        snapshot: RunwayMapSnapshot
    ) -> (AffordabilityResult, [RunwayProjectionPoint]) {
        // Build ephemeral events array — the test event is NEVER saved or posted
        var testEvents = store.financialEvents + store.expectedRepaymentEvents()
        testEvents.append(FinancialEvent(
            type: .obligation,
            status: .unpaid,
            title: "What-if",
            amount: amount,
            date: date,
            accountName: nil,
            destinationAccountName: nil,
            paymentMethodName: nil,
            walletEventName: nil,
            categoryName: nil,
            subCategoryName: nil
        ))

        let testResult = ForecastEngine.calculateRunwayCheck(
            accounts: store.accounts,
            financialEvents: testEvents,
            monthlyBudgets: store.monthlyBudgets,
            creditCardPurchases: store.creditCardPurchases,
            creditCardDueItems: store.creditCardDueItemsForRunway(from: snapshot.startDate, to: snapshot.targetDate),
            minimumSafeBalance: store.runwaySafeBalanceTarget,
            from: snapshot.startDate,
            targetDate: snapshot.targetDate
        )

        let baselineDays = bufferDays(snapshot.result, from: snapshot.startDate)
        let testDays = bufferDays(testResult)

        let ar = AffordabilityResult(
            verdict: testResult.status,
            newLowestBalance: testResult.lowestExpectedBalance,
            newLowestBalanceDate: testResult.lowestBalanceDate,
            bufferDaysChange: testDays - baselineDays,
            affectsRunway: statusSeverity(testResult.status) > statusSeverity(snapshot.result.status) || testDays < baselineDays
        )
        let points = ForecastEngine.calculateRunwayProjectionPoints(
            accounts: store.accounts,
            financialEvents: testEvents,
            monthlyBudgets: store.monthlyBudgets,
            creditCardPurchases: store.creditCardPurchases,
            creditCardDueItems: store.creditCardDueItemsForRunway(from: snapshot.startDate, to: snapshot.targetDate),
            from: snapshot.startDate,
            targetDate: snapshot.targetDate
        )

        return (ar, points)
    }

    private func balanceAt(date: Date, in points: [RunwayProjectionPoint], fallback: Double) -> Double {
        points.last(where: { $0.date <= date })?.balance ?? fallback
    }

    private func projectedBalance(after date: Date, in points: [RunwayProjectionPoint]) -> Double? {
        let day = Calendar.current.startOfDay(for: date)

        if let point = points.first(where: { Calendar.current.startOfDay(for: $0.date) >= day }) {
            return point.balance
        }

        return points.last(where: { Calendar.current.startOfDay(for: $0.date) <= day })?.balance
    }

    private func selectProjectionPoint(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        snapshot: RunwayMapSnapshot
    ) {
        guard let plotFrameAnchor = proxy.plotFrame else {
            return
        }
        let plotFrame = geometry[plotFrameAnchor]
        let xPosition = location.x - plotFrame.origin.x
        guard let date: Date = proxy.value(atX: xPosition),
              let nearest = nearestProjectionPoint(to: date, in: snapshot.projectionPoints) else {
            return
        }

        selectedProjectionPoint = nearest
    }

    private func nearestProjectionPoint(to date: Date, in points: [RunwayProjectionPoint]) -> RunwayProjectionPoint? {
        points.min { first, second in
            abs(first.date.timeIntervalSince(date)) < abs(second.date.timeIntervalSince(date))
        }
    }

    private func nearbyEvents(for date: Date, in items: [RunwayEventItem]) -> [String] {
        let calendar = Calendar.current
        return items
            .filter { item in
                let days = abs(calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: item.date)).day ?? 0)
                return days <= 1
            }
            .prefix(3)
            .map(\.title)
    }

    private func selectedPointStatus(balance: Double, safeFloor: Double) -> String {
        if balance < 0 {
            return store.appLanguage == .arabicEgyptian ? "عجز نقدي" : "Cash shortage"
        }
        if safeFloor > 0 && balance < safeFloor {
            return store.appLanguage == .arabicEgyptian ? "تحت الحد الآمن" : "Below safe floor"
        }
        if safeFloor > 0 && balance < safeFloor * 1.1 {
            return store.appLanguage == .arabicEgyptian ? "ضغط" : "Tight"
        }
        return store.appLanguage == .arabicEgyptian ? "آمن" : "Safe"
    }

    private func selectedPointStatusColor(balance: Double, safeFloor: Double) -> Color {
        if balance < 0 {
            return .red
        }
        if safeFloor > 0 && balance < safeFloor {
            return .orange
        }
        if safeFloor > 0 && balance < safeFloor * 1.1 {
            return .yellow
        }
        return .green
    }

#if DEBUG
    private func diagnosticReport(for item: RunwayEventItem, snapshot: RunwayMapSnapshot) -> String {
        let match = Self.projectionMatch(for: item.date, in: snapshot.projectionPoints)
        let sameDayEvents = sameDayVisibleEvents(for: item.date, in: snapshot.eventItems)
        let hiddenEffects = hiddenRunwayEffects(for: item.date, in: snapshot)

        var lines: [String] = []
        lines.append("RUNWAY BALANCE DIAGNOSTIC")
        lines.append("==========================")
        lines.append("")
        lines.append("1. Item details")
        lines.append("Title: \(item.title)")
        lines.append("Date: \(diagnosticDate(item.date))")
        lines.append("Amount: \(signedCurrency(item.amount, isInflow: item.isInflow))")
        lines.append("Direction: \(item.isInflow ? "inflow" : "outflow")")
        lines.append("Source type: \(item.sourceType)")
        lines.append("")
        lines.append("2. Displayed balance line")
        lines.append("Label: Day-end balance")
        lines.append("Displayed balance: \(item.balanceAfter.map(formatCurrency) ?? "not shown")")
        lines.append("")
        lines.append("3. Projection point matching")
        lines.append("Item date: \(diagnosticDate(item.date))")
        if let match {
            lines.append("Match type: \(match.matchKind)")
            lines.append("Selected projection point date: \(diagnosticDate(match.matchedPoint.date))")
            lines.append("Selected projection point balance: \(formatCurrency(match.matchedPoint.balance))")
        } else {
            lines.append("Match type: no projection point available")
        }
        lines.append("")
        lines.append("4. Day-level breakdown")
        lines.append("Visible upcoming events on \(diagnosticDate(item.date)):")
        if sameDayEvents.isEmpty {
            lines.append("- none")
        } else {
            for event in sameDayEvents {
                lines.append("- \(event.title) | \(signedCurrency(event.amount, isInflow: event.isInflow)) | \(event.sourceType)")
            }
        }
        lines.append("")
        lines.append("Non-visible runway effects available to this diagnostic:")
        if hiddenEffects.isEmpty {
            lines.append("- none exposed in RunwayCheckResult.breakdown for this date")
        } else {
            for effect in hiddenEffects {
                lines.append("- \(effect)")
            }
        }
        lines.append("")
        lines.append("5. Previous/current/next projection points")
        if let match {
            lines.append("Previous: \(projectionPointLine(match.previousPoint))")
            lines.append("Matched: \(projectionPointLine(match.matchedPoint))")
            lines.append("Next: \(projectionPointLine(match.nextPoint))")
        } else {
            lines.append("Previous: n/a")
            lines.append("Matched: n/a")
            lines.append("Next: n/a")
        }
        lines.append("")
        lines.append("6. Explanation")
        lines.append("Day-end balance is the projected daily runway balance for \(match.map { diagnosticDate($0.matchedPoint.date) } ?? diagnosticDate(item.date)) from the same projection series used by the chart. It is not calculated as the balance immediately after this individual item in an event-by-event order.")
        if !hiddenEffects.isEmpty {
            lines.append("That daily balance may include hidden runway effects such as planned budget daily estimates that are not listed as individual Upcoming Items.")
        }

        return lines.joined(separator: "\n")
    }

    private func sameDayVisibleEvents(for date: Date, in items: [RunwayEventItem]) -> [RunwayEventItem] {
        items.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private func hiddenRunwayEffects(for date: Date, in snapshot: RunwayMapSnapshot) -> [String] {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)

        let budgetLines = snapshot.result.breakdown.monthlyBudgetItems.compactMap { item -> String? in
            let start = calendar.startOfDay(for: item.coveredStart)
            let end = calendar.startOfDay(for: item.coveredEnd)
            guard day >= start && day <= end else { return nil }

            let activeDays = max((calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1, 1)
            let dailyAmount = item.includedAmount / Double(activeDays)
            guard dailyAmount > 0 else { return nil }

            return "planned budget daily estimate: \(item.categoryName) \(formatCurrency(-dailyAmount))"
        }

        return budgetLines
    }

    private func projectionPointLine(_ point: RunwayProjectionPoint?) -> String {
        guard let point else { return "n/a" }
        return "\(diagnosticDate(point.date)) | \(formatCurrency(point.balance))"
    }

    private func projectionPointLine(_ point: RunwayProjectionPoint) -> String {
        "\(diagnosticDate(point.date)) | \(formatCurrency(point.balance))"
    }

    private func diagnosticDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private func signedCurrency(_ amount: Double, isInflow: Bool) -> String {
        (isInflow ? "+" : "-") + formatCurrency(amount)
    }
#endif

    private func strideDates(every dayInterval: Int, startDate: Date, targetDate: Date) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        var offset = 0

        while let date = calendar.date(byAdding: .day, value: offset, to: startDate),
              date <= targetDate {
            dates.append(date)
            offset += dayInterval
        }

        return dates
    }

    private func monthLabelDates(startDate: Date, targetDate: Date) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        var cursor = calendar.dateInterval(of: .month, for: startDate)?.start ?? startDate

        while cursor <= targetDate {
            let midpoint = calendar.date(byAdding: .day, value: 14, to: cursor) ?? cursor
            let labelDate = midpoint < startDate ? startDate : midpoint
            if labelDate <= targetDate {
                dates.append(labelDate)
            }

            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: cursor) else {
                break
            }
            cursor = nextMonth
        }

        return Array(Set(dates)).sorted()
    }

    private func xAxisLabel(for date: Date, in snapshot: RunwayMapSnapshot) -> String {
        let dayCount = Calendar.current.dateComponents([.day], from: snapshot.startDate, to: snapshot.targetDate).day ?? 0
        let formatter = DateFormatter()
        formatter.locale = store.appLanguage == .arabicEgyptian ? Locale(identifier: "ar_EG") : Locale(identifier: "en_US")

        let calendar = Calendar.current

        if dayCount <= 45 || calendar.isDate(date, inSameDayAs: snapshot.startDate) {
            formatter.setLocalizedDateFormatFromTemplate("d MMM")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("MMM")
        }

        return formatter.string(from: date)
    }

    private func shortDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = store.appLanguage == .arabicEgyptian ? Locale(identifier: "ar_EG") : Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        return formatter.string(from: date)
    }

    private func bufferDays(_ r: RunwayCheckResult, from startDate: Date? = nil) -> Int {
        let end = r.dangerDate ?? r.cashShortageDate ?? r.calculationEndDate
        return Calendar.current.dateComponents([.day], from: startDate ?? today, to: end).day ?? 0
    }

    private func statusSeverity(_ s: RunwayCheckStatus) -> Int {
        switch s {
        case .safe:           return 0
        case .planIncomplete: return 1
        case .notSafe:        return 2
        case .cashShortage:   return 3
        }
    }

    // MARK: - Presentation Helpers

    private func statusColor(for status: RunwayCheckStatus) -> Color {
        statusSemanticColor(for: status).tint
    }

    private func statusSemanticColor(for status: RunwayCheckStatus) -> PocketWiseSemanticColor {
        switch status {
        case .safe:           return .success
        case .planIncomplete: return .accounts
        case .notSafe:        return .warning
        case .cashShortage:   return .danger
        }
    }

    private func statusHeadline(for result: RunwayCheckResult) -> String {
        let lang = store.appLanguage
        switch result.status {
        case .safe:
            if let d = result.dangerDate {
                return lang == .arabicEgyptian
                    ? "آمن · لحد \(formatDate(d))"
                    : "Safe · through \(formatDate(d))"
            }
            return lang == .arabicEgyptian ? "آمن" : "Safe"
        case .notSafe:
            if let d = result.dangerDate {
                return lang == .arabicEgyptian
                    ? "ضغط مالي · في \(formatDate(d))"
                    : "Tight · pressure on \(formatDate(d))"
            }
            return lang == .arabicEgyptian ? "ضغط مالي" : "Tight"
        case .cashShortage:
            if let d = result.cashShortageDate {
                return lang == .arabicEgyptian
                    ? "في خطر · أول عجز في \(formatDate(d))"
                    : "At Risk · first shortage on \(formatDate(d))"
            }
            return lang == .arabicEgyptian ? "في خطر · نقص فلوس" : "At Risk · Cash Shortage"
        case .planIncomplete:
            if let d = result.planIncompleteAfter {
                return lang == .arabicEgyptian
                    ? "الخطة ناقصة · بعد \(formatDate(d))"
                    : "Plan Incomplete · after \(formatDate(d))"
            }
            return lang == .arabicEgyptian ? "الخطة ناقصة" : "Plan Incomplete"
        }
    }

    private func verdictColor(_ s: RunwayCheckStatus) -> Color {
        statusColor(for: s)
    }

    private func verdictLabel(_ s: RunwayCheckStatus) -> String {
        switch s {
        case .safe:           return AppText.affordabilitySafe(store.appLanguage)
        case .planIncomplete: return store.appLanguage == .arabicEgyptian ? "الخطة ناقصة" : "Plan Incomplete"
        case .notSafe:        return AppText.affordabilityTight(store.appLanguage)
        case .cashShortage:   return AppText.affordabilityAtRisk(store.appLanguage)
        }
    }

    private func metricPill(label: String, value: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(date, style: .date)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func formatCurrency(_ amount: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.maximumFractionDigits = 0
        let n = fmt.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
        return store.appLanguage == .arabicEgyptian ? "\(n) ج.م" : "EGP \(n)"
    }

    private func balanceAfterLabel(_ amount: Double) -> String {
        store.appLanguage == .arabicEgyptian
            ? "رصيد نهاية اليوم: \(formatCurrency(amount))"
            : "Day-end balance: \(formatCurrency(amount))"
    }

    private func compactCurrency(_ amount: Double) -> String {
        if abs(amount) >= 1_000_000 { return String(format: "%.1fM", amount / 1_000_000) }
        if abs(amount) >= 1_000     { return String(format: "%.0fK", amount / 1_000) }
        return String(format: "%.0f", amount)
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
