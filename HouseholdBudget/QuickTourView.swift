import SwiftUI

struct QuickTourView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentPage = 0
    @State private var isShowingSetupAssistant = false
    @State private var isShowingDataBackup = false
    @State private var animationToken = UUID()

    private enum TourVisualType {
        case tabMap, setup, today, transactions, budget, analysis, backup
    }

    private struct TourPage {
        let tint: Color
        let titleEn: String
        let bodyEn: String
        let titleAr: String
        let bodyAr: String
        let visual: TourVisualType
    }

    private let pages: [TourPage] = [
        TourPage(
            tint: .blue,
            titleEn: "Plan before you spend",
            bodyEn: "WalletBoard helps you plan household money ahead, then track what actually happens.",
            titleAr: "خطط قبل ما تصرف",
            bodyAr: "WalletBoard بيساعدك تخطط لفلوس البيت مسبقًا وتتابع اللي بيحصل فعلًا.",
            visual: .tabMap
        ),
        TourPage(
            tint: .green,
            titleEn: "Start with your basics",
            bodyEn: "Add your accounts, categories, and plan once — the app organizes your month from there.",
            titleAr: "ابدأ بأساسياتك",
            bodyAr: "أضف حساباتك وتصنيفاتك وخطتك لمرة واحدة، والتطبيق هينظم شهرك من هناك.",
            visual: .setup
        ),
        TourPage(
            tint: .blue,
            titleEn: "Today is your command center",
            bodyEn: "Today keeps your cash runway, upcoming items, and attention points in one place.",
            titleAr: "النهارده هو مركز تحكمك",
            bodyAr: "شاشة النهارده بتجمع مدى الكاش والبنود القادمة والتنبيهات في مكان واحد.",
            visual: .today
        ),
        TourPage(
            tint: .red,
            titleEn: "Track what really happens",
            bodyEn: "Track actual spending, income, and transfers while keeping planned items separate until they happen.",
            titleAr: "تابع اللي بيحصل فعلًا",
            bodyAr: "سجّل المصروفات والدخل والتحويلات، واحتفظ بالبنود المخططة منفصلة لحين حدوثها.",
            visual: .transactions
        ),
        TourPage(
            tint: .indigo,
            titleEn: "Plan by month",
            bodyEn: "Plan each month by category, then compare your plan with actual spending.",
            titleAr: "خطط شهريًا",
            bodyAr: "خطط كل شهر ببند، وقارن خطتك بالإنفاق الفعلي.",
            visual: .budget
        ),
        TourPage(
            tint: .purple,
            titleEn: "Review what changed",
            bodyEn: "Use analysis to understand where money goes and what changed month by month.",
            titleAr: "راجع اللي اتغير",
            bodyAr: "استخدم التحليل لتفهم فين بتروح الفلوس وإيه اللي اتغير شهر بشهر.",
            visual: .analysis
        ),
        TourPage(
            tint: .teal,
            titleEn: "Your data, your control",
            bodyEn: "Manage your structure in Settings and keep your data safe with manual backups.",
            titleAr: "بياناتك تحت إيدك",
            bodyAr: "إدّر هيكلك من الإعدادات واحتفظ ببياناتك بنسخ احتياطية يدوية.",
            visual: .backup
        )
    ]

    private var isLastPage: Bool {
        currentPage == pages.count - 1
    }

    private var isAr: Bool {
        store.appLanguage == .arabicEgyptian
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    TourPageScaffold(
                        pageNumber: index + 1,
                        pageCount: pages.count,
                        title: isAr ? pages[index].titleAr : pages[index].titleEn,
                        bodyText: isAr ? pages[index].bodyAr : pages[index].bodyEn,
                        tint: pages[index].tint,
                        isActive: currentPage == index,
                        animationToken: animationToken
                    ) {
                        visualComponent(for: pages[index], isActive: currentPage == index)
                    }
                    .tag(index)
                    .transition(pageTransition)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? .easeInOut(duration: 0.16) : .snappy(duration: 0.28), value: currentPage)

            bottomBar
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(isAr ? "جولة سريعة" : "Quick Tour")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isAr ? "تخطي" : "Skip") {
                    dismiss()
                }
                .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $isShowingSetupAssistant) {
            OnboardingWelcomeView(presentationMode: .settings)
                .environmentObject(store)
        }
        .sheet(isPresented: $isShowingDataBackup) {
            NavigationStack {
                DataBackupView()
                    .environmentObject(store)
            }
        }
        .onChange(of: currentPage) { _, _ in
            animationToken = UUID()
        }
    }

    @ViewBuilder
    private func visualComponent(for page: TourPage, isActive: Bool) -> some View {
        switch page.visual {
        case .tabMap:
            TourTabBarMockup(color: page.tint, isActive: isActive, animationToken: animationToken)
        case .setup:
            TourFlowMockup(color: page.tint, isActive: isActive, animationToken: animationToken)
        case .today:
            TourDashboardMockup(color: page.tint, isActive: isActive, animationToken: animationToken)
        case .transactions:
            TourTransactionsMockup(color: page.tint, isActive: isActive, animationToken: animationToken)
        case .budget:
            TourBudgetMockup(color: page.tint, isActive: isActive, animationToken: animationToken)
        case .analysis:
            TourAnalysisMockup(color: page.tint, isActive: isActive, animationToken: animationToken)
        case .backup:
            TourBackupMockup(color: page.tint, isActive: isActive, animationToken: animationToken)
        }
    }

    private var pageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            )
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            pageDots

            if isLastPage {
                finalPageActions
            } else {
                nextButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(.regularMaterial)
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? pages[currentPage].tint : Color.secondary.opacity(0.25))
                    .frame(width: index == currentPage ? 22 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.18), value: currentPage)
            }
        }
        .accessibilityHidden(true)
    }

    private var nextButton: some View {
        Button {
            withAnimation {
                currentPage = min(currentPage + 1, pages.count - 1)
            }
        } label: {
            Text(isAr ? "التالي" : "Next")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var finalPageActions: some View {
        VStack(spacing: 9) {
            Button {
                isShowingSetupAssistant = true
            } label: {
                Label(isAr ? "افتح مساعد الإعداد" : "Open Setup Assistant", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack(spacing: 10) {
                Button {
                    isShowingDataBackup = true
                } label: {
                    Label(isAr ? "استيراد نسخة" : "Import Backup", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    dismiss()
                } label: {
                    Text(isAr ? "إنهاء" : "Finish")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
    }
}

// MARK: - Reusable Layout

private struct TourPageScaffold<Visual: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let pageNumber: Int
    let pageCount: Int
    let title: String
    let bodyText: String
    let tint: Color
    let isActive: Bool
    let animationToken: UUID
    let visual: () -> Visual

    @State private var revealStage = 0

    init(
        pageNumber: Int,
        pageCount: Int,
        title: String,
        bodyText: String,
        tint: Color,
        isActive: Bool,
        animationToken: UUID,
        @ViewBuilder visual: @escaping () -> Visual
    ) {
        self.pageNumber = pageNumber
        self.pageCount = pageCount
        self.title = title
        self.bodyText = bodyText
        self.tint = tint
        self.isActive = isActive
        self.animationToken = animationToken
        self.visual = visual
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("WalletBoard", systemImage: "wallet.pass.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)

                Spacer()

                Text("\(pageNumber)/\(pageCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
            }

            visual()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .tourReveal(isVisible: revealStage >= 1, reduceMotion: reduceMotion, yOffset: 16, scale: 0.985)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .tourReveal(isVisible: revealStage >= 2, reduceMotion: reduceMotion, yOffset: 10, scale: 1)

                Text(bodyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .tourReveal(isVisible: revealStage >= 3, reduceMotion: reduceMotion, yOffset: 8, scale: 1)
            }
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .onAppear {
            runEntrance()
        }
        .onChange(of: animationToken) { _, _ in
            runEntrance()
        }
        .onChange(of: isActive) { _, active in
            if active {
                runEntrance()
            }
        }
    }

    private func runEntrance() {
        guard isActive else { return }

        revealStage = 0

        Task { @MainActor in
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.14)) {
                    revealStage = 3
                }
                return
            }

            withAnimation(.easeOut(duration: 0.22)) {
                revealStage = 1
            }
            try? await Task.sleep(nanoseconds: 90_000_000)
            withAnimation(.easeOut(duration: 0.20)) {
                revealStage = 2
            }
            try? await Task.sleep(nanoseconds: 80_000_000)
            withAnimation(.easeOut(duration: 0.20)) {
                revealStage = 3
            }
        }
    }
}

private extension View {
    func tourReveal(
        isVisible: Bool,
        reduceMotion: Bool,
        yOffset: CGFloat = 10,
        scale: CGFloat = 0.98
    ) -> some View {
        opacity(isVisible ? 1 : 0)
            .offset(y: reduceMotion || isVisible ? 0 : yOffset)
            .scaleEffect(reduceMotion || isVisible ? 1 : scale)
    }
}

private struct TourRevealSequence {
    let isActive: Bool
    let animationToken: UUID
    let reduceMotion: Bool
    let maxStep: Int
    let setStep: (Int) -> Void

    func run() {
        guard isActive else { return }

        setStep(0)

        Task { @MainActor in
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.14)) {
                    setStep(maxStep)
                }
                return
            }

            for step in 1...maxStep {
                try? await Task.sleep(nanoseconds: UInt64(55_000_000 * step))
                withAnimation(.easeOut(duration: 0.22)) {
                    setStep(step)
                }
            }
        }
    }
}

// MARK: - Shared Primitives

private struct TourPhoneMockup<Content: View>: View {
    let color: Color
    let content: () -> Content

    init(color: Color, @ViewBuilder content: @escaping () -> Content) {
        self.color = color
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.22))
                .frame(width: 54, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 10)

            content()
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: color.opacity(0.20), radius: 18, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 8)
    }
}

private struct TourSectionHeader: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.headline.weight(.bold))

            Spacer()
        }
    }
}

private struct TourInfoCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct TourBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let label: String
    let ratio: Double
    let color: Color
    var isActive: Bool = true
    var animationToken = UUID()

    @State private var animatedRatio = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption.weight(.semibold))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.16))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: proxy.size.width * animatedRatio)
                }
            }
            .frame(height: 10)
        }
        .onAppear { runFill() }
        .onChange(of: animationToken) { _, _ in runFill() }
        .onChange(of: isActive) { _, active in
            if active { runFill() }
        }
    }

    private func runFill() {
        guard isActive else { return }
        animatedRatio = reduceMotion ? ratio : 0

        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.55)) {
            animatedRatio = ratio
        }
    }
}

// MARK: - Page 1: Tab Map

private struct TourTabBarMockup: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: WalletStore

    let color: Color
    let isActive: Bool
    let animationToken: UUID

    @State private var revealStep = 0

    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    private var tabs: [(String, String, Color)] {
        [
            ("house.fill", isAr ? "النهارده" : "Today", .blue),
            ("list.bullet.rectangle", isAr ? "الحركات" : "Transactions", .red),
            ("tablecells", isAr ? "الميزانية" : "Budget", .indigo),
            ("chart.pie.fill", isAr ? "التحليل" : "Analysis", .purple),
            ("gearshape.fill", isAr ? "الإعدادات" : "Settings", .gray)
        ]
    }

    var body: some View {
        TourPhoneMockup(color: color) {
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "wallet.pass.fill")
                        .foregroundStyle(color)
                    Text("WalletBoard")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                }

                VStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.element.1) { index, tab in
                        HStack(spacing: 10) {
                            Image(systemName: tab.0)
                                .font(.subheadline)
                                .foregroundStyle(tab.2)
                                .frame(width: 30, height: 30)
                                .background(tab.2.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            Text(tab.1)
                                .font(.subheadline.weight(.semibold))

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .tourReveal(isVisible: revealStep >= index + 1, reduceMotion: reduceMotion, yOffset: 8, scale: 0.98)

                        if index < tabs.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack {
                    ForEach(Array(tabs.enumerated()), id: \.element.1) { index, tab in
                        VStack(spacing: 3) {
                            Image(systemName: tab.0)
                                .font(.system(size: 16))
                                .foregroundStyle(tab.2)
                            Text(tab.1)
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(tab.2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity)
                        .tourReveal(isVisible: revealStep >= index + 2, reduceMotion: reduceMotion, yOffset: 4, scale: 0.92)
                    }
                }
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .onAppear { runReveal() }
        .onChange(of: animationToken) { _, _ in runReveal() }
        .onChange(of: isActive) { _, active in
            if active { runReveal() }
        }
    }

    private func runReveal() {
        TourRevealSequence(
            isActive: isActive,
            animationToken: animationToken,
            reduceMotion: reduceMotion,
            maxStep: 6,
            setStep: { revealStep = $0 }
        ).run()
    }
}

// MARK: - Page 2: Setup Flow

private struct TourFlowMockup: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: WalletStore

    let color: Color
    let isActive: Bool
    let animationToken: UUID

    @State private var revealStep = 0

    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    private var steps: [(String, Color)] {
        [
            (isAr ? "المحافظ والحسابات" : "Wallets & Accounts", .blue),
            (isAr ? "التصنيفات" : "Categories", .purple),
            (isAr ? "الكروت الائتمانية" : "Credit Cards", .pink),
            (isAr ? "الدخل" : "Income", .green),
            (isAr ? "الالتزامات" : "Obligations", .orange),
            (isAr ? "الميزانيات" : "Budgets", .indigo)
        ]
    }

    var body: some View {
        TourPhoneMockup(color: color) {
            VStack(spacing: 10) {
                TourSectionHeader(icon: "sparkles", title: isAr ? "مساعد الإعداد" : "Setup Assistant", color: color)

                VStack(spacing: 0) {
                    ForEach(steps.indices, id: \.self) { index in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(steps[index].1.opacity(0.15))
                                Text("\(index + 1)")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(steps[index].1)
                            }
                            .frame(width: 26, height: 26)

                            Text(steps[index].0)
                                .font(.subheadline.weight(.semibold))

                            Spacer()

                            if index < steps.count - 1 {
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            } else {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundStyle(steps[index].1)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .tourReveal(isVisible: revealStep >= index + 1, reduceMotion: reduceMotion, yOffset: 8, scale: 0.98)

                        if index < steps.count - 1 {
                            Divider()
                                .padding(.leading, 48)
                                .opacity(revealStep >= index + 2 ? 1 : 0)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Label(isAr ? "إعداد يدوي. مفيش ربط بنكي." : "Manual setup. No bank connection.", systemImage: "lock.shield.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { runReveal() }
        .onChange(of: animationToken) { _, _ in runReveal() }
        .onChange(of: isActive) { _, active in
            if active { runReveal() }
        }
    }

    private func runReveal() {
        TourRevealSequence(
            isActive: isActive,
            animationToken: animationToken,
            reduceMotion: reduceMotion,
            maxStep: 6,
            setStep: { revealStep = $0 }
        ).run()
    }
}

// MARK: - Page 3: Today

private struct TourDashboardMockup: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: WalletStore

    let color: Color
    let isActive: Bool
    let animationToken: UUID

    @State private var revealStep = 0

    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    var body: some View {
        TourPhoneMockup(color: color) {
            VStack(spacing: 10) {
                TourSectionHeader(icon: "house.fill", title: isAr ? "النهارده" : "Today", color: color)

                HStack(spacing: 10) {
                    dashboardCard(icon: "arrow.right.circle.fill", title: isAr ? "مدى الكاش" : "Cash Runway", color: color)
                        .tourReveal(isVisible: revealStep >= 1, reduceMotion: reduceMotion, yOffset: 8, scale: 0.97)
                    dashboardCard(icon: "calendar", title: isAr ? "الجاي" : "Upcoming", color: .orange)
                        .tourReveal(isVisible: revealStep >= 3, reduceMotion: reduceMotion, yOffset: 8, scale: 0.97)
                }

                TourInfoCard(icon: "chart.pie.fill", title: isAr ? "تقدم الميزانية" : "Budget progress", subtitle: isAr ? "المخطط مقابل الفعلي" : "Plan vs actual", color: .indigo)
                    .tourReveal(isVisible: revealStep >= 4, reduceMotion: reduceMotion, yOffset: 8, scale: 0.98)

                VStack(alignment: .leading, spacing: 8) {
                    Text(isAr ? "محتاج متابعة" : "Needs attention")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    attentionRow(isAr ? "فاتورة قربت" : "Bill due soon", color: .red)
                    attentionRow(isAr ? "راجع الميزانية" : "Review budget", color: .orange)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .tourReveal(isVisible: revealStep >= 2, reduceMotion: reduceMotion, yOffset: 8, scale: 0.98)

                VStack(alignment: .leading, spacing: 8) {
                    Text(isAr ? "إضافة سريعة" : "Quick Add")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        quickTile(icon: "cart.fill", color: .orange)
                        quickTile(icon: "house.fill", color: .blue)
                        quickTile(icon: "arrow.up.circle.fill", color: .red)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .tourReveal(isVisible: revealStep >= 5, reduceMotion: reduceMotion, yOffset: 8, scale: 0.98)
            }
        }
        .onAppear { runReveal() }
        .onChange(of: animationToken) { _, _ in runReveal() }
        .onChange(of: isActive) { _, active in
            if active { runReveal() }
        }
    }

    private func runReveal() {
        TourRevealSequence(
            isActive: isActive,
            animationToken: animationToken,
            reduceMotion: reduceMotion,
            maxStep: 5,
            setStep: { revealStep = $0 }
        ).run()
    }

    private func dashboardCard(icon: String, title: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Capsule()
                .fill(color.opacity(0.22))
                .frame(height: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func attentionRow(_ title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func quickTile(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 20))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Page 4: Transactions

private struct TourTransactionsMockup: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: WalletStore

    let color: Color
    let isActive: Bool
    let animationToken: UUID

    @State private var revealStep = 0

    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    var body: some View {
        TourPhoneMockup(color: color) {
            VStack(spacing: 10) {
                TourSectionHeader(icon: "list.bullet.rectangle", title: isAr ? "الحركات" : "Transactions", color: color)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    Text(isAr ? "ابحث في الحركات" : "Search transactions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(spacing: 0) {
                    txRow(icon: "arrow.up.circle.fill", title: isAr ? "مصروف" : "Expense", tag: isAr ? "مدفوع" : "Paid", tagColor: .red)
                        .tourReveal(isVisible: revealStep >= 1, reduceMotion: reduceMotion, yOffset: 8, scale: 0.98)
                    Divider().padding(.leading, 50)
                    txRow(icon: "arrow.down.circle.fill", title: isAr ? "دخل مستلم" : "Received Income", tag: isAr ? "مستلم" : "Received", tagColor: .green)
                        .tourReveal(isVisible: revealStep >= 2, reduceMotion: reduceMotion, yOffset: 8, scale: 0.98)
                    Divider().padding(.leading, 50)
                    txRow(icon: "arrow.left.arrow.right.circle.fill", title: isAr ? "تحويل" : "Transfer", tag: isAr ? "تحويل" : "Transfer", tagColor: .blue)
                        .tourReveal(isVisible: revealStep >= 3, reduceMotion: reduceMotion, yOffset: 8, scale: 0.98)
                    Divider().padding(.leading, 50)
                    txRow(icon: "clock.fill", title: isAr ? "متوقع / جاي" : "Expected / Future", tag: isAr ? "لسه" : "Not yet", tagColor: .orange)
                        .tourReveal(isVisible: revealStep >= 4, reduceMotion: reduceMotion, yOffset: 8, scale: 0.98)
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    if revealStep >= 4 {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.orange.opacity(0.22), lineWidth: 1)
                    }
                }

                Label(isAr ? "البنود المتوقعة بتفضل منفصلة لحد ما تتأكد" : "Expected items stay separate until confirmed", systemImage: "info.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tourReveal(isVisible: revealStep >= 5, reduceMotion: reduceMotion, yOffset: 6, scale: 1)
            }
        }
        .onAppear { runReveal() }
        .onChange(of: animationToken) { _, _ in runReveal() }
        .onChange(of: isActive) { _, active in
            if active { runReveal() }
        }
    }

    private func runReveal() {
        TourRevealSequence(
            isActive: isActive,
            animationToken: animationToken,
            reduceMotion: reduceMotion,
            maxStep: 5,
            setStep: { revealStep = $0 }
        ).run()
    }

    private func txRow(icon: String, title: String, tag: String, tagColor: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tagColor)
                .frame(width: 36, height: 36)
                .background(tagColor.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.subheadline.weight(.semibold))

            Spacer()

            Text(tag)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tagColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tagColor.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Page 5: Budget

private struct TourBudgetMockup: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: WalletStore

    let color: Color
    let isActive: Bool
    let animationToken: UUID

    @State private var revealStep = 0

    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    var body: some View {
        TourPhoneMockup(color: color) {
            VStack(spacing: 12) {
                TourSectionHeader(icon: "tablecells", title: isAr ? "الميزانية" : "Budget", color: color)

                HStack(spacing: 10) {
                    metricCard(isAr ? "المخطط" : "Planned", color: color)
                        .tourReveal(isVisible: revealStep >= 1, reduceMotion: reduceMotion, yOffset: 8, scale: 0.96)
                    metricCard(isAr ? "الفعلي" : "Actual", color: .green)
                        .tourReveal(isVisible: revealStep >= 2, reduceMotion: reduceMotion, yOffset: 8, scale: 0.96)
                    metricCard(isAr ? "المتبقي" : "Remaining", color: .orange)
                        .tourReveal(isVisible: revealStep >= 3, reduceMotion: reduceMotion, yOffset: 8, scale: 0.96)
                }

                VStack(spacing: 12) {
                    TourBar(label: AppText.categoryDisplayName("Food & Groceries", language: store.appLanguage), ratio: 0.68, color: .orange, isActive: isActive && revealStep >= 4, animationToken: animationToken)
                    TourBar(label: AppText.categoryDisplayName("Housing", language: store.appLanguage), ratio: 0.82, color: .blue, isActive: isActive && revealStep >= 5, animationToken: animationToken)
                    TourBar(label: AppText.categoryDisplayName("Transport", language: store.appLanguage), ratio: 0.46, color: .green, isActive: isActive && revealStep >= 6, animationToken: animationToken)
                    TourBar(label: AppText.categoryDisplayName("Health", language: store.appLanguage), ratio: 0.30, color: .teal, isActive: isActive && revealStep >= 7, animationToken: animationToken)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .tourReveal(isVisible: revealStep >= 4, reduceMotion: reduceMotion, yOffset: 8, scale: 0.98)
            }
        }
        .onAppear { runReveal() }
        .onChange(of: animationToken) { _, _ in runReveal() }
        .onChange(of: isActive) { _, active in
            if active { runReveal() }
        }
    }

    private func runReveal() {
        TourRevealSequence(
            isActive: isActive,
            animationToken: animationToken,
            reduceMotion: reduceMotion,
            maxStep: 7,
            setStep: { revealStep = $0 }
        ).run()
    }

    private func metricCard(_ title: String, color: Color) -> some View {
        VStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.11))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Page 6: Analysis

private struct TourAnalysisMockup: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: WalletStore

    let color: Color
    let isActive: Bool
    let animationToken: UUID

    @State private var revealStep = 0

    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    private var categories: [(String, Double, Color)] {
        [
            (AppText.categoryDisplayName("Food & Groceries", language: store.appLanguage), 0.72, .orange),
            (AppText.categoryDisplayName("Housing", language: store.appLanguage), 0.85, .blue),
            (AppText.categoryDisplayName("Transport", language: store.appLanguage), 0.51, .green),
            (AppText.categoryDisplayName("Health", language: store.appLanguage), 0.38, .teal)
        ]
    }

    var body: some View {
        TourPhoneMockup(color: color) {
            VStack(spacing: 10) {
                TourSectionHeader(icon: "chart.pie.fill", title: isAr ? "التحليل" : "Analysis", color: color)

                HStack(spacing: 8) {
                    monthChip(isAr ? "أبر" : "Apr", selected: false)
                    monthChip(isAr ? "مايو" : "May", selected: false)
                    monthChip(isAr ? "يونيو" : "Jun", selected: true)
                    Spacer()
                }

                VStack(spacing: 12) {
                    ForEach(Array(categories.enumerated()), id: \.element.0) { index, category in
                        TourBar(
                            label: category.0,
                            ratio: category.1,
                            color: category.2,
                            isActive: isActive && revealStep >= index + 1,
                            animationToken: animationToken
                        )
                        .tourReveal(isVisible: revealStep >= index + 1, reduceMotion: reduceMotion, yOffset: 7, scale: 0.98)
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Label(isAr ? "تفصيل التصنيفات، أكبر مصاريف، ومقارنة الشهور" : "Category breakdown, top spenders, month comparison", systemImage: "info.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tourReveal(isVisible: revealStep >= 5, reduceMotion: reduceMotion, yOffset: 6, scale: 1)
            }
        }
        .onAppear { runReveal() }
        .onChange(of: animationToken) { _, _ in runReveal() }
        .onChange(of: isActive) { _, active in
            if active { runReveal() }
        }
    }

    private func runReveal() {
        TourRevealSequence(
            isActive: isActive,
            animationToken: animationToken,
            reduceMotion: reduceMotion,
            maxStep: 5,
            setStep: { revealStep = $0 }
        ).run()
    }

    private func monthChip(_ label: String, selected: Bool) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(selected ? color : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selected ? color.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
            .clipShape(Capsule())
    }
}

// MARK: - Page 7: Backup & Settings

private struct TourBackupMockup: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var store: WalletStore

    let color: Color
    let isActive: Bool
    let animationToken: UUID

    @State private var revealStep = 0

    private var isAr: Bool { store.appLanguage == .arabicEgyptian }

    var body: some View {
        TourPhoneMockup(color: color) {
            VStack(spacing: 10) {
                TourSectionHeader(icon: "gearshape.fill", title: isAr ? "الإعدادات" : "Settings", color: color)

                VStack(spacing: 0) {
                    settingsRow(icon: "wallet.pass.fill", title: isAr ? "الحسابات والكروت" : "Accounts & Cards", color: .blue)
                        .tourReveal(isVisible: revealStep >= 1, reduceMotion: reduceMotion, yOffset: 8, scale: 0.98)
                    Divider().padding(.leading, 50)
                    settingsRow(icon: "square.grid.2x2.fill", title: isAr ? "التصنيفات" : "Categories", color: .purple)
                        .tourReveal(isVisible: revealStep >= 2, reduceMotion: reduceMotion, yOffset: 8, scale: 0.98)
                    Divider().padding(.leading, 50)
                    settingsRow(icon: "sparkles", title: isAr ? "مساعد الإعداد" : "Setup Assistant", color: color)
                        .tourReveal(isVisible: revealStep >= 3, reduceMotion: reduceMotion, yOffset: 8, scale: 0.98)
                    Divider().padding(.leading, 50)
                    settingsRow(icon: "arrow.up.doc.fill", title: isAr ? "تصدير نسخة احتياطية" : "Export Backup", color: color)
                        .tourReveal(isVisible: revealStep >= 4, reduceMotion: reduceMotion, yOffset: 8, scale: 0.98)
                    Divider().padding(.leading, 50)
                    settingsRow(icon: "square.and.arrow.down", title: isAr ? "استيراد نسخة احتياطية" : "Import Backup", color: color)
                        .tourReveal(isVisible: revealStep >= 5, reduceMotion: reduceMotion, yOffset: 8, scale: 0.98)
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Label(isAr ? "بياناتك محلية. مفيش ربط بنكي. مفيش مدفوعات تلقائية." : "Local-first. No bank connection. No automatic payments.", systemImage: "lock.shield.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tourReveal(isVisible: revealStep >= 6, reduceMotion: reduceMotion, yOffset: 6, scale: 1)
            }
        }
        .onAppear { runReveal() }
        .onChange(of: animationToken) { _, _ in runReveal() }
        .onChange(of: isActive) { _, active in
            if active { runReveal() }
        }
    }

    private func runReveal() {
        TourRevealSequence(
            isActive: isActive,
            animationToken: animationToken,
            reduceMotion: reduceMotion,
            maxStep: 6,
            setStep: { revealStep = $0 }
        ).run()
    }

    private func settingsRow(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.subheadline.weight(.semibold))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
