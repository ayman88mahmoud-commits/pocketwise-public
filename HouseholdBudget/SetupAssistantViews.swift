import SwiftUI

// MARK: - Onboarding

enum OnboardingSetupStep: String, CaseIterable, Identifiable {
    case household = "Household"
    case accounts = "Accounts"
    case categories = "Build Categories"
    case cardsAndBNPL = "Cards & BNPL"
    case income = "Income"
    case obligations = "Obligations"
    case recurringObligations = "Recurring Bills"
    case budgets = "Budgets"
    case review = "Review"

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        guard language == .arabicEgyptian else {
            return rawValue
        }

        switch self {
        case .household:
            return "البيت"
        case .accounts:
            return "الحسابات"
        case .categories:
            return "بناء الفئات"
        case .cardsAndBNPL:
            return "الكروت والتقسيط"
        case .income:
            return "الدخل"
        case .obligations:
            return "الالتزامات"
        case .recurringObligations:
            return "فواتير متكررة"
        case .budgets:
            return "الميزانيات"
        case .review:
            return "مراجعة"
        }
    }

    var systemImage: String {
        switch self {
        case .household:
            return "person.2.fill"
        case .accounts:
            return "wallet.pass.fill"
        case .categories:
            return "square.grid.2x2.fill"
        case .cardsAndBNPL:
            return "creditcard.fill"
        case .income:
            return "arrow.down.circle.fill"
        case .obligations:
            return "calendar.badge.clock"
        case .recurringObligations:
            return "arrow.triangle.2.circlepath"
        case .budgets:
            return "chart.pie.fill"
        case .review:
            return "checkmark.seal.fill"
        }
    }
}

struct OnboardingWelcomeView: View {

    enum PresentationMode {
        case firstLaunch
        case settings
    }

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let presentationMode: PresentationMode
    var onSkip: (() -> Void)? = nil
    var onDone: (() -> Void)? = nil

    @State private var isShowingSetupShell = false

    private var isFirstLaunch: Bool {
        presentationMode == .firstLaunch
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    benefitsGrid
                    actions
                    privacyNote
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isFirstLaunch ? "" : (store.appLanguage == .arabicEgyptian ? "مساعد الإعداد" : "Setup Assistant"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isFirstLaunch {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(store.appLanguage == .arabicEgyptian ? "إغلاق" : "Close") {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingSetupShell) {
                OnboardingSetupShellView(
                    presentationMode: presentationMode,
                    onClose: handleSkip,
                    onDone: handleDone
                )
                .environmentObject(store)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 34, weight: .semibold))
                .frame(width: 64, height: 64)
                .background(PocketWiseSemanticColor.setup.tint.opacity(0.14))
                .foregroundStyle(PocketWiseSemanticColor.setup.tint)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(store.appLanguage == .arabicEgyptian ? "جهّز WalletBoard" : "Set up WalletBoard")
                .font(.largeTitle)
                .fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)

            Text(store.appLanguage == .arabicEgyptian ? "أضف حساباتك، كروتك، الفواتير، والميزانيات يدويًا. بياناتك تحت سيطرتك." : "Add your accounts, cards, bills, and budgets manually. Your data stays under your control.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefitsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            benefitCard(
                title: store.appLanguage == .arabicEgyptian ? "الحسابات والمحافظ" : "Add accounts and wallets",
                icon: "banknote.fill",
                semanticColor: .accounts
            )

            benefitCard(
                title: store.appLanguage == .arabicEgyptian ? "الكروت والتقسيط" : "Add credit cards and BNPLs",
                icon: "creditcard.fill",
                semanticColor: .creditCards
            )

            benefitCard(
                title: store.appLanguage == .arabicEgyptian ? "الدخل والالتزامات" : "Plan income and fixed obligations",
                icon: "calendar.badge.clock",
                semanticColor: .obligations
            )

            benefitCard(
                title: store.appLanguage == .arabicEgyptian ? "ميزانيات البداية" : "Start with budgets",
                icon: "chart.pie.fill",
                semanticColor: .budgets
            )
        }
    }

    private func benefitCard(title: String, icon: String, semanticColor: PocketWiseSemanticColor) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PocketWiseIconBadge(
                systemName: icon,
                semanticColor: semanticColor,
                size: 34,
                cornerRadius: 10
            )

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .pocketWiseCard(
            semanticColor: semanticColor,
            padding: 14,
            cornerRadius: 12,
            showsBorder: true
        )
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                isShowingSetupShell = true
            } label: {
                Label(store.appLanguage == .arabicEgyptian ? "ابدأ الإعداد" : "Start setup", systemImage: "arrow.forward.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            NavigationLink {
                DataBackupView()
                    .environmentObject(store)
            } label: {
                Label(store.appLanguage == .arabicEgyptian ? "استيراد نسخة احتياطية" : "Import backup", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                handleSkip()
            } label: {
                Text(isFirstLaunch ? (store.appLanguage == .arabicEgyptian ? "تخطي الآن" : "Skip for now") : (store.appLanguage == .arabicEgyptian ? "إغلاق" : "Close"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(PocketWiseSemanticColor.backupPrivacy.tint)
                .padding(.top, 2)

            Text(store.appLanguage == .arabicEgyptian ? "لا تحتاج لتسجيل دخول بنكي. التطبيق يدوي أولًا، والاستيراد والنسخ الاحتياطي منفصلان عن الإعداد." : "No bank login is required. This app is manual-entry first. Backup import and export stay separate from setup.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .pocketWiseCard(
            semanticColor: .backupPrivacy,
            padding: 14,
            cornerRadius: 12,
            showsBorder: true
        )
    }

    private func handleSkip() {
        if let onSkip {
            onSkip()
        } else {
            dismiss()
        }
    }

    private func handleDone() {
        if let onDone {
            onDone()
        } else {
            dismiss()
        }
    }
}

struct OnboardingSetupShellView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let presentationMode: OnboardingWelcomeView.PresentationMode
    let onClose: () -> Void
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.appLanguage == .arabicEgyptian ? "هيكل الإعداد" : "Setup progress")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(store.appLanguage == .arabicEgyptian ? "اختَر خطوة إعداد يدوي. الخطوات المتاحة تحفظ بيانات الإعداد فقط، ولا تنشئ معاملات أو مدفوعات." : "Choose a manual setup step. Available steps save setup records only and do not create transactions or payments.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                Section(store.appLanguage == .arabicEgyptian ? "الخطوات القادمة" : "Future Steps") {
                    ForEach(Array(OnboardingSetupStep.allCases.enumerated()), id: \.element.id) { index, step in
                        if step == .accounts {
                            NavigationLink {
                                OnboardingAccountsSetupView()
                                    .environmentObject(store)
                            } label: {
                                setupStepRow(index: index, step: step, status: store.appLanguage == .arabicEgyptian ? "متاح الآن" : "Available now")
                            }
                        } else if step == .categories {
                            NavigationLink {
                                OnboardingCategoryBuilderSetupView()
                                    .environmentObject(store)
                            } label: {
                                setupStepRow(index: index, step: step, status: store.appLanguage == .arabicEgyptian ? "متاح الآن" : "Available now")
                            }
                        } else if step == .cardsAndBNPL {
                            NavigationLink {
                                OnboardingCreditCardsSetupView()
                                    .environmentObject(store)
                            } label: {
                                setupStepRow(index: index, step: step, status: store.appLanguage == .arabicEgyptian ? "الكروت متاحة" : "Cards available")
                            }
                        } else if step == .income {
                            NavigationLink {
                                OnboardingIncomeSetupView()
                                    .environmentObject(store)
                            } label: {
                                setupStepRow(index: index, step: step, status: store.appLanguage == .arabicEgyptian ? "الدخل المتوقع متاح" : "Expected income available")
                            }
                        } else if step == .obligations {
                            NavigationLink {
                                OnboardingObligationsSetupView()
                                    .environmentObject(store)
                            } label: {
                                setupStepRow(index: index, step: step, status: store.appLanguage == .arabicEgyptian ? "الالتزامات متاحة" : "Obligations available")
                            }
                        } else if step == .recurringObligations {
                            NavigationLink {
                                OnboardingMonthlyRecurringObligationsSetupView()
                                    .environmentObject(store)
                            } label: {
                                setupStepRow(index: index, step: step, status: store.appLanguage == .arabicEgyptian ? "شهري فقط" : "Monthly only")
                            }
                        } else if step == .budgets {
                            NavigationLink {
                                OnboardingBudgetsSetupView()
                                    .environmentObject(store)
                            } label: {
                                setupStepRow(index: index, step: step, status: store.appLanguage == .arabicEgyptian ? "متاح الآن" : "Available now")
                            }
                        } else {
                            setupStepRow(index: index, step: step, status: store.appLanguage == .arabicEgyptian ? "لاحقًا" : "Later")
                        }
                    }
                }

                Section {
                    Text(store.appLanguage == .arabicEgyptian ? "المتاح الآن هو إضافة حسابات، محافظ، فئات، كروت ائتمان، دخل متوقع، التزامات غير مدفوعة، التزامات شهرية متكررة، والميزانيات المخططة يدويًا. التقسيط مؤجل." : "Manual accounts, wallets, categories, credit cards, expected income, unpaid obligations, monthly recurring obligations, and planned budgets are available now. BNPL is deferred.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(store.appLanguage == .arabicEgyptian ? "مساعد الإعداد" : "Setup Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(store.appLanguage == .arabicEgyptian ? "إغلاق" : "Close") {
                        dismiss()
                        onClose()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(store.appLanguage == .arabicEgyptian ? "تم" : "Done") {
                        store.updateOnboardingLastStep(OnboardingSetupStep.allCases.count - 1)
                        dismiss()
                        onDone()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func setupStepRow(index: Int, step: OnboardingSetupStep, status: String) -> some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(
                systemName: step.systemImage,
                semanticColor: semanticColor(for: step),
                size: 34,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title(language: store.appLanguage))
                    .font(.headline)

                Text(stepDetail(for: step))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(index + 1)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(status)
                    .font(.caption2)
                    .pocketWiseChip(semanticColor: semanticColor(for: step), isSelected: step != .household && step != .review)
            }
        }
        .padding(.vertical, 4)
    }

    private func semanticColor(for step: OnboardingSetupStep) -> PocketWiseSemanticColor {
        switch step {
        case .household:
            return .setup
        case .accounts:
            return .accounts
        case .categories:
            return .categories
        case .cardsAndBNPL:
            return .creditCards
        case .income:
            return .income
        case .obligations, .recurringObligations:
            return .obligations
        case .budgets:
            return .budgets
        case .review:
            return .success
        }
    }

    private func stepDetail(for step: OnboardingSetupStep) -> String {
        switch step {
        case .household:
            return store.appLanguage == .arabicEgyptian ? "اسم البيت أو المستخدم." : "Household or display name."
        case .accounts:
            return store.appLanguage == .arabicEgyptian ? "حسابات بنكية، كاش، ومحافظ يدوية." : "Manual bank, cash, and wallet accounts."
        case .categories:
            return store.appLanguage == .arabicEgyptian ? "فئات وفئات فرعية فقط، بدون معاملات." : "Categories and subcategories only, no transactions."
        case .cardsAndBNPL:
            return store.appLanguage == .arabicEgyptian ? "كروت ائتمان وتقسيط للتتبع." : "Credit cards and installment tracking."
        case .income:
            return store.appLanguage == .arabicEgyptian ? "دخل متوقع، وليس مستلمًا." : "Expected income, not received cash."
        case .obligations:
            return store.appLanguage == .arabicEgyptian ? "التزامات وفواتير غير مدفوعة." : "Unpaid commitments and bills."
        case .recurringObligations:
            return store.appLanguage == .arabicEgyptian ? "التزامات شهرية متكررة غير مدفوعة." : "Monthly unpaid recurring bills."
        case .budgets:
            return store.appLanguage == .arabicEgyptian ? "قيم مخططة، وليست مصروفات فعلية." : "Planned values, not actual spending."
        case .review:
            return store.appLanguage == .arabicEgyptian ? "مراجعة قبل أي حفظ مستقبلي." : "Review before any future save."
        }
    }
}

private struct CategoryTemplate: Hashable {
    let name: String
    let subcategories: [String]
}

private struct CategoryPackDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let categories: [CategoryTemplate]

    func displayTitle(language: AppLanguage) -> String {
        guard language == .arabicEgyptian else {
            return title
        }

        switch id {
        case "essential":
            return "البداية الأساسية"
        case "kids":
            return "الأولاد والمدرسة"
        case "car":
            return "العربية"
        case "debt":
            return "ديون وأقساط"
        case "pets":
            return "حيوانات أليفة"
        case "travel":
            return "سفر"
        case "work":
            return "شغل / بيزنس"
        case "giving":
            return "تبرعات وخير"
        case "householdHelp":
            return "خدمات ومساعدة البيت"
        default:
            return title
        }
    }
}

private struct CategoryPreviewItem: Identifiable {
    let name: String
    let subcategories: [String]
    let existingCategoryName: String?
    let duplicateSubcategories: [String]

    var id: String { name.lowercased() }
    var isExistingCategory: Bool { existingCategoryName != nil }

    var missingSubcategories: [String] {
        subcategories.filter { subcategory in
            !duplicateSubcategories.contains { duplicate in
                duplicate.caseInsensitiveCompare(subcategory) == .orderedSame
            }
        }
    }

    var createsChanges: Bool {
        !isExistingCategory || !missingSubcategories.isEmpty
    }
}

struct OnboardingCategoryBuilderSetupView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPackIDs: Set<String> = ["essential"]
    @State private var lastCreateSummary: String?

    private static let categoryPacks: [CategoryPackDefinition] = [
        CategoryPackDefinition(
            id: "essential",
            title: "Essential Starter",
            systemImage: "person.fill",
            categories: [
                CategoryTemplate(name: "Food & Groceries", subcategories: ["Groceries", "Supermarket", "Delivery", "Coffee & Snacks"]),
                CategoryTemplate(name: "Housing", subcategories: ["Rent", "Mortgage", "Home Maintenance", "Furniture & Appliances", "Renovation"]),
                CategoryTemplate(name: "Utilities & Bills", subcategories: ["Electricity", "Water", "Gas", "Internet", "Mobile", "Subscriptions"]),
                CategoryTemplate(name: "Transport", subcategories: ["Ride-hailing", "Public Transport", "Parking"]),
                CategoryTemplate(name: "Health", subcategories: ["Pharmacy", "Doctor", "Lab & Tests", "Insurance", "Dental"]),
                CategoryTemplate(name: "Personal", subcategories: ["Clothing", "Grooming", "Gifts", "Miscellaneous"]),
                CategoryTemplate(name: "Entertainment", subcategories: ["Outings", "Streaming", "Hobbies", "Sports"]),
                CategoryTemplate(name: "Other", subcategories: ["Miscellaneous"])
            ]
        ),
        CategoryPackDefinition(
            id: "kids",
            title: "Kids & School",
            systemImage: "figure.2.and.child.holdinghands",
            categories: [
                CategoryTemplate(name: "Kids & School", subcategories: ["School Fees", "Nursery", "Supplies", "Uniform", "Bus", "Activities", "Toys", "Kids Health"])
            ]
        ),
        CategoryPackDefinition(
            id: "car",
            title: "Car",
            systemImage: "car.fill",
            categories: [
                CategoryTemplate(name: "Car", subcategories: ["Fuel", "Car Maintenance", "Insurance", "License & Registration", "Tires", "Car Wash"])
            ]
        ),
        CategoryPackDefinition(
            id: "debt",
            title: "Debt & Installments",
            systemImage: "calendar.badge.clock",
            categories: [
                CategoryTemplate(name: "Debt & Installments", subcategories: ["Loan Payment", "Installment", "Credit Card Payment", "Buy Now Pay Later"])
            ]
        ),
        CategoryPackDefinition(
            id: "pets",
            title: "Pets",
            systemImage: "pawprint.fill",
            categories: [
                CategoryTemplate(name: "Pets", subcategories: ["Food", "Vet", "Medicine", "Grooming", "Supplies"])
            ]
        ),
        CategoryPackDefinition(
            id: "travel",
            title: "Travel",
            systemImage: "airplane",
            categories: [
                CategoryTemplate(name: "Travel", subcategories: ["Flights", "Hotels", "Transportation", "Food", "Activities", "Documents"])
            ]
        ),
        CategoryPackDefinition(
            id: "work",
            title: "Work / Business",
            systemImage: "briefcase.fill",
            categories: [
                CategoryTemplate(name: "Work & Business", subcategories: ["Equipment", "Software", "Transport", "Meals", "Training", "Office Supplies"])
            ]
        ),
        CategoryPackDefinition(
            id: "giving",
            title: "Giving & Charity",
            systemImage: "gift.fill",
            categories: [
                CategoryTemplate(name: "Giving & Charity", subcategories: ["Charity", "Gifts", "Family Support", "Donations"])
            ]
        ),
        CategoryPackDefinition(
            id: "householdHelp",
            title: "Household Help & Services",
            systemImage: "house.fill",
            categories: [
                CategoryTemplate(name: "Household Help & Services", subcategories: ["Home Help", "Cleaning", "Repairs", "Security", "Property Fees"])
            ]
        )
    ]

    private var selectedPacks: [CategoryPackDefinition] {
        Self.categoryPacks.filter { selectedPackIDs.contains($0.id) }
    }

    private var previewItems: [CategoryPreviewItem] {
        var mergedTemplates: [CategoryTemplate] = []

        for template in selectedPacks.flatMap(\.categories) {
            let cleanName = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanSubcategories = template.subcategories
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard !cleanName.isEmpty else {
                continue
            }

            if let index = mergedTemplates.firstIndex(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) {
                var subcategories = mergedTemplates[index].subcategories
                for subcategory in cleanSubcategories
                where !subcategories.contains(where: { $0.caseInsensitiveCompare(subcategory) == .orderedSame }) {
                    subcategories.append(subcategory)
                }
                mergedTemplates[index] = CategoryTemplate(name: mergedTemplates[index].name, subcategories: subcategories)
            } else {
                mergedTemplates.append(CategoryTemplate(name: cleanName, subcategories: cleanSubcategories))
            }
        }

        return mergedTemplates
            .map { template in
                let existingCategory = store.categories.first {
                    $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        .caseInsensitiveCompare(template.name) == .orderedSame
                }
                let duplicateSubcategories = template.subcategories.filter { subcategory in
                    existingCategory?.subcategories.contains {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines)
                            .caseInsensitiveCompare(subcategory) == .orderedSame
                    } == true
                }

                return CategoryPreviewItem(
                    name: template.name,
                    subcategories: template.subcategories,
                    existingCategoryName: existingCategory?.name,
                    duplicateSubcategories: duplicateSubcategories
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var changeCount: (categories: Int, subcategories: Int) {
        let categories = previewItems.filter { !$0.isExistingCategory }.count
        let subcategories = previewItems.reduce(0) { total, item in
            total + item.missingSubcategories.count
        }
        return (categories, subcategories)
    }

    private var canCreateCategories: Bool {
        !selectedPackIDs.isEmpty && (changeCount.categories > 0 || changeCount.subcategories > 0)
    }

    var body: some View {
        List {
            headerSection
            packSelectionSection
            previewSection
            actionSection
            safetySection
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "بناء الفئات" : "Build your categories")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(store.appLanguage == .arabicEgyptian ? "بناء الفئات" : "Build your categories")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(store.appLanguage == .arabicEgyptian ? "اختر ما يناسب حياتك. WalletBoard سيقترح فئات وفئات فرعية تقدر تعدلها لاحقًا." : "Choose what applies to your life. WalletBoard will suggest categories and subcategories you can edit later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(store.appLanguage == .arabicEgyptian ? "هذه الخطوة لا تنشئ أرصدة أو معاملات أو ميزانيات أو دخل أو فواتير." : "This step does not create balances, transactions, budgets, income, bills, or payments.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }

    private var packSelectionSection: some View {
        Section(store.appLanguage == .arabicEgyptian ? "اختر حزم الفئات" : "Choose category packs") {
            ForEach(Self.categoryPacks) { pack in
                Toggle(isOn: Binding(
                    get: { selectedPackIDs.contains(pack.id) },
                    set: { isSelected in
                        if isSelected {
                            selectedPackIDs.insert(pack.id)
                        } else {
                            selectedPackIDs.remove(pack.id)
                        }
                        lastCreateSummary = nil
                    }
                )) {
                    HStack(spacing: 12) {
                        PocketWiseIconBadge(
                            systemName: pack.systemImage,
                            semanticColor: .categories,
                            size: 32,
                            cornerRadius: 9
                        )

                        Text(pack.displayTitle(language: store.appLanguage))
                    }
                }
            }
        }
    }

    private var previewSection: some View {
        Section {
            if selectedPackIDs.isEmpty {
                Text(store.appLanguage == .arabicEgyptian ? "اختر حزمة واحدة على الأقل لمعاينة الفئات المقترحة." : "Select at least one pack to preview suggested categories.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(previewItems) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(categoryDisplayName(item.name))
                                .font(.headline)

                            Spacer()

                            if item.isExistingCategory {
                                Text(store.appLanguage == .arabicEgyptian ? "موجودة" : "Existing")
                                    .pocketWiseChip(semanticColor: .neutral, isSelected: false)
                            } else {
                                Text(store.appLanguage == .arabicEgyptian ? "جديدة" : "New")
                                    .pocketWiseChip(semanticColor: .success)
                            }
                        }

                        Text(item.subcategories.map(subcategoryDisplayName).joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !item.duplicateSubcategories.isEmpty {
                            Text((store.appLanguage == .arabicEgyptian ? "سيتم تخطي الموجود: " : "Duplicates skipped: ") + item.duplicateSubcategories.map(subcategoryDisplayName).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text(store.appLanguage == .arabicEgyptian ? "المعاينة" : "Preview")
        } footer: {
            let counts = changeCount
            Text(store.appLanguage == .arabicEgyptian ? "سيتم إنشاء \(counts.categories) فئة و \(counts.subcategories) فئة فرعية جديدة فقط." : "Will create \(counts.categories) new categories and \(counts.subcategories) new subcategories only.")
        }
    }

    private var actionSection: some View {
        Section {
            Button {
                createSuggestedCategories()
            } label: {
                Label(store.appLanguage == .arabicEgyptian ? "إنشاء الفئات المقترحة" : "Create Suggested Categories", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!canCreateCategories)

            Button {
                dismiss()
            } label: {
                Label(store.appLanguage == .arabicEgyptian ? "متابعة" : "Continue", systemImage: "arrow.forward.circle")
                    .frame(maxWidth: .infinity)
            }

            Button {
                dismiss()
            } label: {
                Text(store.appLanguage == .arabicEgyptian ? "تخطي الآن" : "Skip for Now")
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.secondary)

            if let lastCreateSummary {
                Text(lastCreateSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var safetySection: some View {
        Section {
            Label {
                Text(store.appLanguage == .arabicEgyptian ? "الفئات هي هيكل تنظيمي فقط. لن يتم إنشاء معاملات أو أرصدة أو مدفوعات أو بيانات تجريبية." : "Categories are organization structure only. No transactions, balances, payments, or sample data will be created.")
            } icon: {
                Image(systemName: "lock.shield.fill")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func categoryDisplayName(_ name: String) -> String {
        AppText.categoryDisplayName(name, language: store.appLanguage)
    }

    private func subcategoryDisplayName(_ name: String) -> String {
        AppText.subcategoryDisplayName(name, language: store.appLanguage)
    }

    private func createSuggestedCategories() {
        let beforeCategoryCount = store.categories.count
        let beforeSubcategoryCount = store.categories.reduce(0) { $0 + $1.subcategories.count }

        for item in previewItems {
            let targetCategoryName: String

            if let existingCategoryName = item.existingCategoryName {
                targetCategoryName = existingCategoryName
            } else {
                store.addCategory(name: item.name)
                targetCategoryName = store.categories.first {
                    $0.name.caseInsensitiveCompare(item.name) == .orderedSame
                }?.name ?? item.name
            }

            guard let currentCategory = store.categories.first(where: { $0.name.caseInsensitiveCompare(targetCategoryName) == .orderedSame }) else {
                continue
            }

            for subcategory in item.subcategories
            where !currentCategory.subcategories.contains(where: { $0.caseInsensitiveCompare(subcategory) == .orderedSame }) {
                store.addSubcategory(subcategory, to: targetCategoryName)
            }
        }

        let createdCategories = max(store.categories.count - beforeCategoryCount, 0)
        let createdSubcategories = max(store.categories.reduce(0) { $0 + $1.subcategories.count } - beforeSubcategoryCount, 0)

        lastCreateSummary = store.appLanguage == .arabicEgyptian
            ? "تم إنشاء \(createdCategories) فئة و \(createdSubcategories) فئة فرعية. لم يتم إنشاء أي معاملات أو أرصدة."
            : "Created \(createdCategories) categories and \(createdSubcategories) subcategories. No transactions or balances were created."
    }
}

struct OnboardingCreditCardsSetupView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var isAddingCard = false
    @State private var setupAddedCardIDs: Set<UUID> = []

    private var sortedCards: [CreditCard] {
        store.creditCards.sorted {
            if $0.isActive == $1.isActive {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            return $0.isActive && !$1.isActive
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.appLanguage == .arabicEgyptian ? "كروت الائتمان" : "Credit Cards")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(store.appLanguage == .arabicEgyptian ? "أضف الكروت يدويًا. ده مش بيربط بالبنك ومش بينشئ مشتريات." : "Add cards manually. This does not connect to your bank or create purchases.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(store.appLanguage == .arabicEgyptian ? "لا تدخل رقم الكارت، CVV، أو PIN." : "Do not enter your card number, CVV, or PIN.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                Button {
                    isAddingCard = true
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "أضف كارت ائتمان" : "Add Credit Card", systemImage: "creditcard.fill")
                }
            }

            Section(store.appLanguage == .arabicEgyptian ? "الكروت الحالية" : "Current Cards") {
                if sortedCards.isEmpty {
                    Text(store.appLanguage == .arabicEgyptian ? "لسه مفيش كروت." : "No cards yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedCards) { card in
                        onboardingCardRow(card)
                    }
                }
            }

            Section {
                Button {
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "متابعة" : "Continue")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }

                Button {
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "تخطي الآن" : "Skip for now")
                        Spacer()
                    }
                }
                .foregroundStyle(.secondary)
            }

            Section {
                Text(store.appLanguage == .arabicEgyptian ? "تقدر تعدل الكروت لاحقًا من الإعدادات > كروت الائتمان. السداد والمشتريات لا يتم إنشاؤهم من مساعد الإعداد." : "You can edit cards later from Settings > Credit Cards. Payments and purchases are not created from Setup Assistant.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "كروت الائتمان" : "Credit Cards")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddingCard) {
            OnboardingCreditCardEditorSheet { cardName in
                if let card = store.creditCards.first(where: { $0.name.caseInsensitiveCompare(cardName) == .orderedSame }) {
                    setupAddedCardIDs.insert(card.id)
                }
                isAddingCard = false
            }
            .environmentObject(store)
        }
    }

    private func onboardingCardRow(_ card: CreditCard) -> some View {
        HStack(spacing: 12) {
            CreditCardVisualMark(card: card, size: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(card.name)
                        .font(.headline)

                    if setupAddedCardIDs.contains(card.id) {
                        Text(store.appLanguage == .arabicEgyptian ? "جديد" : "New")
                            .pocketWiseChip(semanticColor: .success)
                    }
                }

                Text(card.bankName.isEmpty ? card.cardNetwork.rawValue : "\(card.bankName) - \(card.cardNetwork.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(store.appLanguage == .arabicEgyptian ? "المستحق الحالي: \(store.displayCurrency(store.creditCardOutstanding(cardID: card.id)))" : "Current outstanding: \(store.displayCurrency(store.creditCardOutstanding(cardID: card.id)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(store.displayCurrency(card.creditLimit, maximumFractionDigits: 2))
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

struct OnboardingCreditCardEditorSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let onSaved: (String) -> Void

    @State private var name = ""
    @State private var bankName = ""
    @State private var cardNetwork: CreditCardNetwork = .other
    @State private var appearanceColor: ProviderAppearanceColor?
    @State private var creditLimitText = "0"
    @State private var openingOutstandingText = "0"
    @State private var openingOutstandingDate = Date()
    @State private var statementClosingDayText = "1"
    @State private var paymentDueDayText = "1"
    @State private var defaultPaymentAccountName = ""
    @State private var note = ""

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var creditLimit: Double? {
        parseAmount(creditLimitText)
    }

    private var openingOutstandingBalance: Double? {
        parseAmount(openingOutstandingText)
    }

    private var statementClosingDay: Int? {
        Int(statementClosingDayText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var paymentDueDay: Int? {
        Int(paymentDueDayText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var isDuplicateName: Bool {
        store.creditCards.contains {
            $0.name.caseInsensitiveCompare(cleanName) == .orderedSame
        }
    }

    private var accountsForPayment: [Account] {
        store.accounts
            .filter { $0.isActive }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var validationMessages: [String] {
        var messages: [String] = []

        if cleanName.isEmpty {
            messages.append(store.appLanguage == .arabicEgyptian ? "أدخل اسم الكارت." : "Enter a card name.")
        }

        if isDuplicateName {
            messages.append(store.appLanguage == .arabicEgyptian ? "اسم الكارت موجود بالفعل." : "Card name already exists.")
        }

        if creditLimit == nil || (creditLimit ?? 0) < 0 {
            messages.append(store.appLanguage == .arabicEgyptian ? "أدخل حد ائتماني صحيح صفر أو أكثر." : "Enter a valid credit limit of zero or more.")
        }

        if openingOutstandingBalance == nil || (openingOutstandingBalance ?? 0) < 0 {
            messages.append(store.appLanguage == .arabicEgyptian ? "أدخل مستحق حالي صحيح صفر أو أكثر." : "Enter a valid current outstanding balance of zero or more.")
        }

        if let statementClosingDay {
            if !(1...31).contains(statementClosingDay) {
                messages.append(store.appLanguage == .arabicEgyptian ? "يوم كشف الحساب لازم يكون من 1 إلى 31." : "Statement day must be from 1 to 31.")
            }
        } else {
            messages.append(store.appLanguage == .arabicEgyptian ? "أدخل يوم كشف حساب صحيح." : "Enter a valid statement day.")
        }

        if let paymentDueDay {
            if !(1...31).contains(paymentDueDay) {
                messages.append(store.appLanguage == .arabicEgyptian ? "يوم السداد لازم يكون من 1 إلى 31." : "Due day must be from 1 to 31.")
            }
        } else {
            messages.append(store.appLanguage == .arabicEgyptian ? "أدخل يوم سداد صحيح." : "Enter a valid due day.")
        }

        return messages
    }

    private var canSave: Bool {
        validationMessages.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(store.appLanguage == .arabicEgyptian ? "الكارت" : "Card") {
                    TextField(store.appLanguage == .arabicEgyptian ? "اسم الكارت" : "Card name", text: $name)
                        .textInputAutocapitalization(.words)
                        .pocketWiseInputField(semanticColor: .creditCards)

                    TextField(store.appLanguage == .arabicEgyptian ? "البنك / المزود" : "Bank / provider", text: $bankName)
                        .textInputAutocapitalization(.words)
                        .pocketWiseInputField(semanticColor: .creditCards)

                    Picker(store.appLanguage == .arabicEgyptian ? "الشبكة" : "Network", selection: $cardNetwork) {
                        ForEach(CreditCardNetwork.allCases) { network in
                            Text(network.rawValue)
                                .tag(network)
                        }
                    }
                    .pocketWiseInputField(semanticColor: .creditCards)

                    Text(store.appLanguage == .arabicEgyptian ? "لا تدخل رقم الكارت، CVV، أو PIN." : "Do not enter your card number, CVV, or PIN.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(store.appLanguage == .arabicEgyptian ? "الشبكة تظهر كنص فقط. WalletBoard يستخدم أيقونة آمنة بدل الشعارات الرسمية." : "Network appears as text only. WalletBoard uses a safe generic icon instead of official logos.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(store.appLanguage == .arabicEgyptian ? "الشكل" : "Appearance") {
                    HStack(spacing: 12) {
                        CreditCardVisualMark(
                            card: CreditCard(
                                name: cleanName.isEmpty ? "Credit Card" : cleanName,
                                bankName: bankName,
                                cardNetwork: cardNetwork,
                                appearanceColor: appearanceColor ?? .purple,
                                creditLimit: 0,
                                statementClosingDay: 1,
                                paymentDueDay: 1
                            ),
                            size: 38
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.appLanguage == .arabicEgyptian ? "شارة آمنة" : "Safe card badge")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(store.appLanguage == .arabicEgyptian ? "أيقونة عامة ولون مختار بدون شعارات رسمية." : "Generic icon and selected color without official logos.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ProviderAppearanceColorPicker(
                        title: store.appLanguage == .arabicEgyptian ? "اللون" : "Color",
                        selection: $appearanceColor,
                        defaultColor: .purple
                    )
                }

                Section(store.appLanguage == .arabicEgyptian ? "الحد والمستحقات" : "Limit and outstanding") {
                    TextField(store.appLanguage == .arabicEgyptian ? "الحد الائتماني" : "Credit limit", text: $creditLimitText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .creditCards, isProminent: true)

                    TextField(store.appLanguage == .arabicEgyptian ? "المستحق الحالي" : "Current outstanding balance", text: $openingOutstandingText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .creditCards, isProminent: true)

                    if (openingOutstandingBalance ?? 0) > 0 {
                        DatePicker(
                            store.appLanguage == .arabicEgyptian ? "المستحق بتاريخ" : "Outstanding as of",
                            selection: $openingOutstandingDate,
                            displayedComponents: .date
                        )
                        .pocketWiseInputField(semanticColor: .obligations)
                    }

                    Text(store.appLanguage == .arabicEgyptian ? "المستحق الحالي يضاف كرصيد افتتاحي على الكارت فقط. لا ينشئ مشتريات أو مصروفات ولا يخصم من الكاش." : "Current outstanding is saved only as opening card liability. It does not create purchases or expenses and does not reduce cash.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(store.appLanguage == .arabicEgyptian ? "المواعيد" : "Dates") {
                    TextField(store.appLanguage == .arabicEgyptian ? "يوم كشف الحساب" : "Statement day", text: $statementClosingDayText)
                        .keyboardType(.numberPad)
                        .pocketWiseInputField(semanticColor: .obligations)
                        .onChange(of: statementClosingDayText) { _, newValue in
                            statementClosingDayText = String(newValue.filter(\.isNumber).prefix(2))
                        }

                    TextField(store.appLanguage == .arabicEgyptian ? "يوم السداد" : "Due day", text: $paymentDueDayText)
                        .keyboardType(.numberPad)
                        .pocketWiseInputField(semanticColor: .obligations)
                        .onChange(of: paymentDueDayText) { _, newValue in
                            paymentDueDayText = String(newValue.filter(\.isNumber).prefix(2))
                        }
                }

                Section(store.appLanguage == .arabicEgyptian ? "حساب السداد الافتراضي" : "Default payment account") {
                    AccountMenuPickerField(
                        title: store.appLanguage == .arabicEgyptian ? "الحساب" : "Account",
                        selection: $defaultPaymentAccountName,
                        accounts: accountsForPayment,
                        placeholder: store.appLanguage == .arabicEgyptian ? "بدون حساب افتراضي" : "No default account",
                        emptyTitle: store.appLanguage == .arabicEgyptian ? "بدون حساب افتراضي" : "No default account",
                        inactiveSubtitle: false
                    )

                    Text(store.appLanguage == .arabicEgyptian ? "ده اختيار افتراضي فقط. مساعد الإعداد لا ينشئ سداد ولا يحرك فلوس." : "This is only a default selection. Setup Assistant does not create payments or move money.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(store.appLanguage == .arabicEgyptian ? "ملاحظة" : "Note") {
                    TextField(store.appLanguage == .arabicEgyptian ? "ملاحظة اختيارية" : "Optional note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .pocketWiseInputField(semanticColor: .neutral)
                }

                Section {
                    if !validationMessages.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(validationMessages, id: \.self) { message in
                                Text(message)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()
                            Text(store.appLanguage == .arabicEgyptian ? "حفظ الكارت" : "Save Card")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(store.appLanguage == .arabicEgyptian ? "كارت ائتمان" : "Credit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func parseAmount(_ value: String) -> Double? {
        let cleanValue = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !cleanValue.isEmpty else {
            return nil
        }

        return Double(cleanValue)
    }

    private func save() {
        guard let creditLimit,
              let openingOutstandingBalance,
              let statementClosingDay,
              let paymentDueDay,
              canSave else {
            return
        }

        store.addCreditCard(
            name: cleanName,
            bankName: bankName,
            lastFourDigits: nil,
            cardNetwork: cardNetwork,
            appearanceColor: appearanceColor ?? .purple,
            creditLimit: creditLimit,
            openingOutstandingBalance: openingOutstandingBalance,
            openingOutstandingDate: openingOutstandingBalance > 0 ? openingOutstandingDate : nil,
            statementClosingDay: statementClosingDay,
            paymentDueDay: paymentDueDay,
            defaultPaymentAccountName: defaultPaymentAccountName.isEmpty ? nil : defaultPaymentAccountName,
            note: note.isEmpty ? nil : note
        )
        onSaved(cleanName)
        dismiss()
    }
}

struct OnboardingIncomeSetupView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var isAddingIncome = false
    @State private var setupAddedIncomeIDs: Set<UUID> = []

    private var expectedIncomeEvents: [FinancialEvent] {
        store.financialEvents
            .filter { event in
                event.type == .income &&
                event.status != .paid &&
                event.status != .cancelled &&
                event.status != .skipped
            }
            .sorted {
                if $0.date == $1.date {
                    return $0.createdAt > $1.createdAt
                }

                return $0.date < $1.date
            }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.appLanguage == .arabicEgyptian ? "الدخل" : "Income")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(store.appLanguage == .arabicEgyptian ? "أضف دخلًا متوقعًا يدويًا. ده لا يعلّمه كمستلم ولا يغير رصيد الكاش." : "Add expected income manually. This does not mark it as received or change your cash balance.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(store.appLanguage == .arabicEgyptian ? "تقدر تعلّم الدخل كمستلم لاحقًا من مسار التطبيق العادي." : "You can mark income as received later from the normal app flow.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                Button {
                    isAddingIncome = true
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "أضف دخل متوقع" : "Add Expected Income", systemImage: "arrow.down.circle.fill")
                }
            }

            Section(store.appLanguage == .arabicEgyptian ? "الدخل المتوقع" : "Expected Income") {
                if expectedIncomeEvents.isEmpty {
                    Text(store.appLanguage == .arabicEgyptian ? "لسه مفيش دخل متوقع." : "No expected income yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(expectedIncomeEvents) { event in
                        onboardingIncomeRow(event)
                    }
                }
            }

            Section {
                Button {
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "متابعة" : "Continue")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }

                Button {
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "تخطي الآن" : "Skip for now")
                        Spacer()
                    }
                }
                .foregroundStyle(.secondary)
            }

            Section {
                Text(store.appLanguage == .arabicEgyptian ? "مساعد الإعداد ينشئ دخلًا متوقعًا فقط. لا ينشئ دخل مستلم، معاملات، أو حركة رصيد." : "Setup Assistant creates expected income only. It does not create received income, transactions, or balance movement.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "الدخل" : "Income")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddingIncome) {
            OnboardingExpectedIncomeEditorSheet { incomeID in
                setupAddedIncomeIDs.insert(incomeID)
                isAddingIncome = false
            }
            .environmentObject(store)
        }
    }

    private func onboardingIncomeRow(_ event: FinancialEvent) -> some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(
                systemName: "arrow.down.circle.fill",
                semanticColor: .income,
                size: 34,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.headline)

                    if setupAddedIncomeIDs.contains(event.id) {
                        Text(store.appLanguage == .arabicEgyptian ? "جديد" : "New")
                            .pocketWiseChip(semanticColor: .success)
                    }
                }

                Text(incomeSubtitle(for: event))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(store.signedDisplayCurrency(event.amount, prefix: "+", maximumFractionDigits: 2))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(PocketWiseSemanticColor.income.tint)
        }
        .padding(.vertical, 4)
    }

    private func incomeSubtitle(for event: FinancialEvent) -> String {
        var parts = [
            formatDate(event.date),
            event.effectiveIncomeType.title(language: store.appLanguage)
        ]

        if let accountName = event.accountName,
           !accountName.isEmpty {
            parts.append(accountName)
        }

        return parts.joined(separator: " - ")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

struct OnboardingExpectedIncomeEditorSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let onSaved: (UUID) -> Void

    @State private var title = ""
    @State private var amountText = ""
    @State private var expectedDate = Date()
    @State private var accountName = ""
    @State private var incomeType: IncomeType = .salary
    @State private var note = ""

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var amount: Double? {
        parseAmount(amountText)
    }

    private var referenceAccounts: [Account] {
        store.accounts
            .filter { $0.isActive && ($0.type == .cash || $0.type == .bank || $0.type == .wallet) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var earliestExpectedDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var validationMessages: [String] {
        var messages: [String] = []

        if cleanTitle.isEmpty {
            messages.append(store.appLanguage == .arabicEgyptian ? "أدخل مصدر الدخل." : "Enter an income source.")
        }

        if amount == nil || (amount ?? 0) <= 0 {
            messages.append(store.appLanguage == .arabicEgyptian ? "أدخل مبلغًا صحيحًا أكبر من صفر." : "Enter a valid amount greater than zero.")
        }

        if !accountName.isEmpty &&
            !referenceAccounts.contains(where: { $0.name == accountName }) {
            messages.append(store.appLanguage == .arabicEgyptian ? "اختر حسابًا موجودًا أو اتركه بدون حساب." : "Choose an existing account or leave it without an account.")
        }

        if Calendar.current.startOfDay(for: expectedDate) < Calendar.current.startOfDay(for: Date()) {
            messages.append(store.appLanguage == .arabicEgyptian ? "اختَر تاريخ اليوم أو تاريخًا قادمًا." : "Choose today or a future date.")
        }

        return messages
    }

    private var canSave: Bool {
        validationMessages.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(store.appLanguage == .arabicEgyptian ? "الدخل المتوقع" : "Expected Income") {
                    TextField(store.appLanguage == .arabicEgyptian ? "مصدر الدخل" : "Income source", text: $title)
                        .textInputAutocapitalization(.words)
                        .pocketWiseInputField(semanticColor: .income)

                    TextField(store.appLanguage == .arabicEgyptian ? "المبلغ" : "Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .income, isProminent: true)

                    DatePicker(
                        store.appLanguage == .arabicEgyptian ? "تاريخ متوقع" : "Expected date",
                        selection: $expectedDate,
                        in: earliestExpectedDate...,
                        displayedComponents: .date
                    )
                    .pocketWiseInputField(semanticColor: .income)

                    Picker(store.appLanguage == .arabicEgyptian ? "النوع" : "Type", selection: $incomeType) {
                        Text(IncomeType.salary.title(language: store.appLanguage))
                            .tag(IncomeType.salary)
                        Text(IncomeType.oneTimeCashInflow.title(language: store.appLanguage))
                            .tag(IncomeType.oneTimeCashInflow)
                    }
                }

                Section(store.appLanguage == .arabicEgyptian ? "حساب الاستلام لاحقًا" : "Receiving account later") {
                    AccountMenuPickerField(
                        title: store.appLanguage == .arabicEgyptian ? "الحساب" : "Account",
                        selection: $accountName,
                        accounts: referenceAccounts,
                        placeholder: store.appLanguage == .arabicEgyptian ? "بدون حساب الآن" : "No account now",
                        emptyTitle: store.appLanguage == .arabicEgyptian ? "بدون حساب الآن" : "No account now",
                        inactiveSubtitle: false
                    )

                    Text(store.appLanguage == .arabicEgyptian ? "ده مرجع فقط للدخل المتوقع. لا يتم زيادة رصيد الحساب من مساعد الإعداد." : "This is only a reference for expected income. Setup Assistant does not increase the account balance.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(store.appLanguage == .arabicEgyptian ? "ملاحظة" : "Note") {
                    TextField(store.appLanguage == .arabicEgyptian ? "ملاحظة اختيارية" : "Optional note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .pocketWiseInputField(semanticColor: .neutral)
                }

                Section {
                    Text(store.appLanguage == .arabicEgyptian ? "سيتم حفظ هذا كدخل متوقع فقط. يمكن تعليمه كمستلم لاحقًا من مسار التطبيق العادي." : "This will be saved as expected income only. You can mark it as received later from the normal app flow.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !validationMessages.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(validationMessages, id: \.self) { message in
                                Text(message)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()
                            Text(store.appLanguage == .arabicEgyptian ? "حفظ الدخل المتوقع" : "Save Expected Income")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(store.appLanguage == .arabicEgyptian ? "دخل متوقع" : "Expected Income")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func parseAmount(_ value: String) -> Double? {
        let cleanValue = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !cleanValue.isEmpty else {
            return nil
        }

        return Double(cleanValue)
    }

    private func save() {
        guard let amount, canSave else {
            return
        }

        let event = FinancialEvent(
            type: .income,
            status: .expected,
            title: cleanTitle,
            amount: amount,
            date: expectedDate,
            accountName: accountName.isEmpty ? nil : accountName,
            incomeType: incomeType,
            note: cleanNote.isEmpty ? nil : cleanNote,
            createdAt: Date()
        )

        store.addFinancialEvent(event)
        onSaved(event.id)
        dismiss()
    }
}

struct OnboardingObligationsSetupView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var isAddingObligation = false
    @State private var setupAddedObligationIDs: Set<UUID> = []

    private var unpaidOneTimeObligations: [FinancialEvent] {
        store.financialEvents
            .filter { event in
                event.type == .obligation &&
                event.status != .paid &&
                event.status != .cancelled &&
                event.status != .skipped &&
                event.repeatRule == .none
            }
            .sorted {
                if $0.date == $1.date {
                    return $0.createdAt > $1.createdAt
                }

                return $0.date < $1.date
            }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.appLanguage == .arabicEgyptian ? "الالتزامات والفواتير" : "Obligations / Bills")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(store.appLanguage == .arabicEgyptian ? "أضف التزامات قادمة يدويًا. ده لا يعلّمها كمدفوعة ولا يغير رصيد الكاش." : "Add upcoming obligations manually. This does not mark them as paid or change your cash balance.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(store.appLanguage == .arabicEgyptian ? "تقدر تعلّم الالتزامات كمدفوعة لاحقًا من مسار التطبيق العادي." : "You can mark obligations as paid later from the normal app flow.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                Button {
                    isAddingObligation = true
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "أضف التزام" : "Add Obligation", systemImage: "calendar.badge.clock")
                }
            }

            Section(store.appLanguage == .arabicEgyptian ? "التزامات غير مدفوعة" : "Unpaid Obligations") {
                if unpaidOneTimeObligations.isEmpty {
                    Text(store.appLanguage == .arabicEgyptian ? "لسه مفيش التزامات مرة واحدة." : "No one-time unpaid obligations yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(unpaidOneTimeObligations) { event in
                        onboardingObligationRow(event)
                    }
                }
            }

            Section {
                Button {
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "متابعة" : "Continue")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }

                Button {
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "تخطي الآن" : "Skip for now")
                        Spacer()
                    }
                }
                .foregroundStyle(.secondary)
            }

            Section {
                Text(store.appLanguage == .arabicEgyptian ? "مساعد الإعداد ينشئ التزامًا غير مدفوع لمرة واحدة فقط. لا ينشئ معاملات، مدفوعات، أو حركة رصيد." : "Setup Assistant creates one-time unpaid obligations only. It does not create transactions, payments, or balance movement.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "الالتزامات" : "Obligations")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddingObligation) {
            OnboardingObligationEditorSheet { obligationID in
                setupAddedObligationIDs.insert(obligationID)
                isAddingObligation = false
            }
            .environmentObject(store)
        }
    }

    private func onboardingObligationRow(_ event: FinancialEvent) -> some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(
                systemName: "calendar.badge.clock",
                semanticColor: .obligations,
                size: 34,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.headline)

                    if setupAddedObligationIDs.contains(event.id) {
                        Text(store.appLanguage == .arabicEgyptian ? "جديد" : "New")
                            .pocketWiseChip(semanticColor: .success)
                    }
                }

                Text(obligationSubtitle(for: event))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(store.signedDisplayCurrency(event.amount, prefix: "-", maximumFractionDigits: 2))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(PocketWiseSemanticColor.obligations.tint)
        }
        .padding(.vertical, 4)
    }

    private func obligationSubtitle(for event: FinancialEvent) -> String {
        var parts = [
            formatDate(event.date),
            event.categoryName ?? "Uncategorized"
        ]

        if let subCategoryName = event.subCategoryName,
           !subCategoryName.isEmpty {
            parts.append(subCategoryName)
        }

        if let accountName = event.accountName,
           !accountName.isEmpty {
            parts.append(accountName)
        }

        return parts.joined(separator: " - ")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

struct OnboardingObligationEditorSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let onSaved: (UUID) -> Void

    @State private var title = ""
    @State private var amountText = ""
    @State private var dueDate = Date()
    @State private var accountName = ""
    @State private var categoryName = ""
    @State private var subCategoryName = ""
    @State private var note = ""

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var amount: Double? {
        parseAmount(amountText)
    }

    private var referenceAccounts: [Account] {
        store.accounts
            .filter { $0.isActive && ($0.type == .cash || $0.type == .bank || $0.type == .wallet) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var activeCategories: [Category] {
        store.categories
            .filter { $0.isActive }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var availableSubcategories: [String] {
        store.activeSubcategories(for: categoryName)
    }

    private var earliestDueDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var validationMessages: [String] {
        var messages: [String] = []

        if cleanTitle.isEmpty {
            messages.append(store.appLanguage == .arabicEgyptian ? "أدخل اسم الالتزام." : "Enter an obligation name.")
        }

        if amount == nil || (amount ?? 0) <= 0 {
            messages.append(store.appLanguage == .arabicEgyptian ? "أدخل مبلغًا صحيحًا أكبر من صفر." : "Enter a valid amount greater than zero.")
        }

        if Calendar.current.startOfDay(for: dueDate) < earliestDueDate {
            messages.append(store.appLanguage == .arabicEgyptian ? "اختَر تاريخ اليوم أو تاريخًا قادمًا." : "Choose today or a future date.")
        }

        if categoryName.isEmpty ||
            !activeCategories.contains(where: { $0.name == categoryName }) {
            messages.append(store.appLanguage == .arabicEgyptian ? "اختر تصنيفًا موجودًا." : "Choose an existing category.")
        }

        if subCategoryName.isEmpty ||
            !availableSubcategories.contains(where: { $0 == subCategoryName }) {
            messages.append(store.appLanguage == .arabicEgyptian ? "اختر تصنيفًا فرعيًا موجودًا." : "Choose an existing subcategory.")
        }

        if !accountName.isEmpty &&
            !referenceAccounts.contains(where: { $0.name == accountName }) {
            messages.append(store.appLanguage == .arabicEgyptian ? "اختر حسابًا موجودًا أو اتركه بدون حساب." : "Choose an existing account or leave it without an account.")
        }

        return messages
    }

    private var canSave: Bool {
        validationMessages.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(store.appLanguage == .arabicEgyptian ? "التزام غير مدفوع" : "Unpaid Obligation") {
                    TextField(store.appLanguage == .arabicEgyptian ? "اسم الالتزام" : "Obligation name", text: $title)
                        .textInputAutocapitalization(.words)
                        .pocketWiseInputField(semanticColor: .obligations)

                    TextField(store.appLanguage == .arabicEgyptian ? "المبلغ" : "Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .obligations, isProminent: true)

                    DatePicker(
                        store.appLanguage == .arabicEgyptian ? "تاريخ الاستحقاق" : "Due date",
                        selection: $dueDate,
                        in: earliestDueDate...,
                        displayedComponents: .date
                    )
                    .pocketWiseInputField(semanticColor: .obligations)
                }

                Section(store.appLanguage == .arabicEgyptian ? "التصنيف" : "Category") {
                    CategorySubcategoryPickerView(
                        categoryName: $categoryName,
                        subCategoryName: $subCategoryName,
                        title: store.appLanguage == .arabicEgyptian ? "التصنيف" : "Category",
                        categoryValidationMessage: store.appLanguage == .arabicEgyptian ? "اختر تصنيف" : "Select category",
                        subcategoryValidationMessage: store.appLanguage == .arabicEgyptian ? "اختر تصنيف فرعي" : "Select subcategory"
                    )

                    Text(store.appLanguage == .arabicEgyptian ? "التصنيف هنا للتخطيط فقط. لا يتم احتسابه كمصروف فعلي إلا عند الدفع من المسار العادي." : "Category is for planning only. It is not counted as actual spending until paid from the normal app flow.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(store.appLanguage == .arabicEgyptian ? "حساب الدفع لاحقًا" : "Payment account later") {
                    AccountMenuPickerField(
                        title: store.appLanguage == .arabicEgyptian ? "الحساب" : "Account",
                        selection: $accountName,
                        accounts: referenceAccounts,
                        placeholder: store.appLanguage == .arabicEgyptian ? "بدون حساب الآن" : "No account now",
                        emptyTitle: store.appLanguage == .arabicEgyptian ? "بدون حساب الآن" : "No account now",
                        inactiveSubtitle: false
                    )

                    Text(store.appLanguage == .arabicEgyptian ? "ده مرجع فقط للالتزام غير المدفوع. لا يتم خصم الرصيد من مساعد الإعداد." : "This is only a reference for the unpaid obligation. Setup Assistant does not deduct the account balance.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(store.appLanguage == .arabicEgyptian ? "ملاحظة" : "Note") {
                    TextField(store.appLanguage == .arabicEgyptian ? "ملاحظة اختيارية" : "Optional note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .pocketWiseInputField(semanticColor: .neutral)
                }

                Section {
                    Text(store.appLanguage == .arabicEgyptian ? "سيتم حفظ هذا كالتزام غير مدفوع لمرة واحدة فقط. يمكن تعليمه كمدفوع لاحقًا من مسار التطبيق العادي." : "This will be saved as a one-time unpaid obligation only. You can mark it as paid later from the normal app flow.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !validationMessages.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(validationMessages, id: \.self) { message in
                                Text(message)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()
                            Text(store.appLanguage == .arabicEgyptian ? "حفظ الالتزام" : "Save Obligation")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(store.appLanguage == .arabicEgyptian ? "التزام غير مدفوع" : "Unpaid Obligation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupInitialSelection()
            }
            .onChange(of: categoryName) { _, _ in
                updateSubcategoryForCategory()
            }
        }
    }

    private func parseAmount(_ value: String) -> Double? {
        let cleanValue = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !cleanValue.isEmpty else {
            return nil
        }

        return Double(cleanValue)
    }

    private func setupInitialSelection() {
        guard categoryName.isEmpty else {
            return
        }

        categoryName = activeCategories.first?.name ?? ""
        subCategoryName = availableSubcategories.first ?? ""
    }

    private func updateSubcategoryForCategory() {
        if !availableSubcategories.contains(subCategoryName) {
            subCategoryName = availableSubcategories.first ?? ""
        }
    }

    private func save() {
        guard let amount, canSave else {
            return
        }

        let event = FinancialEvent(
            type: .obligation,
            status: .unpaid,
            title: cleanTitle,
            amount: amount,
            date: dueDate,
            accountName: accountName.isEmpty ? nil : accountName,
            categoryName: categoryName,
            subCategoryName: subCategoryName,
            repeatRule: .none,
            confidence: .high,
            note: cleanNote.isEmpty ? nil : cleanNote,
            createdAt: Date()
        )

        store.addFinancialEvent(event)
        onSaved(event.id)
        dismiss()
    }
}

struct OnboardingMonthlyRecurringObligationsSetupView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var isAddingRecurringObligation = false
    @State private var setupAddedRecurringObligationIDs: Set<UUID> = []

    private var monthlyRecurringTemplates: [FinancialEvent] {
        store.financialEvents
            .filter { event in
                event.type == .obligation &&
                event.status != .paid &&
                event.status != .cancelled &&
                event.status != .skipped &&
                event.repeatRule == .monthly &&
                event.sourceRecurringEventID == nil
            }
            .sorted {
                if $0.date == $1.date {
                    return $0.createdAt > $1.createdAt
                }

                return $0.date < $1.date
            }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.appLanguage == .arabicEgyptian ? "التزامات شهرية متكررة" : "Monthly Recurring Obligations / Bills")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(store.appLanguage == .arabicEgyptian ? "أضف التزامات شهرية متكررة يدويًا. ده لا يعلّمها كمدفوعة ولا يغير رصيد الكاش." : "Add monthly recurring obligations manually. This does not mark them as paid or change your cash balance.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(store.appLanguage == .arabicEgyptian ? "البنود الشهرية المستقبلية للتخطيط فقط لحد ما تعلّمها كمدفوعة من مسار التطبيق العادي." : "Future monthly items are planning only until you mark them as paid from the normal app flow.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                Button {
                    isAddingRecurringObligation = true
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "أضف التزام شهري متكرر" : "Add Monthly Recurring Obligation", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            Section(store.appLanguage == .arabicEgyptian ? "القوالب الشهرية" : "Monthly Templates") {
                if monthlyRecurringTemplates.isEmpty {
                    Text(store.appLanguage == .arabicEgyptian ? "لسه مفيش التزامات شهرية متكررة." : "No monthly recurring obligations yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(monthlyRecurringTemplates) { event in
                        onboardingRecurringObligationRow(event)
                    }
                }
            }

            Section {
                Button {
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "متابعة" : "Continue")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }

                Button {
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "تخطي الآن" : "Skip for now")
                        Spacer()
                    }
                }
                .foregroundStyle(.secondary)
            }

            Section {
                Text(store.appLanguage == .arabicEgyptian ? "مساعد الإعداد ينشئ قالب شهري غير مدفوع فقط. لا ينشئ معاملات، مدفوعات، أو نسخ مستقبلية محفوظة." : "Setup Assistant creates an unpaid monthly template only. It does not create transactions, payments, or persisted future occurrences.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "التزامات شهرية" : "Monthly Recurring")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddingRecurringObligation) {
            OnboardingMonthlyRecurringObligationEditorSheet { eventID in
                setupAddedRecurringObligationIDs.insert(eventID)
                isAddingRecurringObligation = false
            }
            .environmentObject(store)
        }
    }

    private func onboardingRecurringObligationRow(_ event: FinancialEvent) -> some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(
                systemName: "arrow.triangle.2.circlepath",
                semanticColor: .obligations,
                size: 34,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.headline)

                    if setupAddedRecurringObligationIDs.contains(event.id) {
                        Text(store.appLanguage == .arabicEgyptian ? "جديد" : "New")
                            .pocketWiseChip(semanticColor: .success)
                    }
                }

                Text(recurringObligationSubtitle(for: event))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(store.signedDisplayCurrency(event.amount, prefix: "-", maximumFractionDigits: 2))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(PocketWiseSemanticColor.obligations.tint)
        }
        .padding(.vertical, 4)
    }

    private func recurringObligationSubtitle(for event: FinancialEvent) -> String {
        var parts = [
            formatDate(event.date),
            event.repeatRule.rawValue,
            event.categoryName ?? "Uncategorized"
        ]

        if let subCategoryName = event.subCategoryName,
           !subCategoryName.isEmpty {
            parts.append(subCategoryName)
        }

        if let accountName = event.accountName,
           !accountName.isEmpty {
            parts.append(accountName)
        }

        return parts.joined(separator: " - ")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}

struct OnboardingMonthlyRecurringObligationEditorSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let onSaved: (UUID) -> Void

    @State private var title = ""
    @State private var amountText = ""
    @State private var firstDueDate = Date()
    @State private var accountName = ""
    @State private var categoryName = ""
    @State private var subCategoryName = ""
    @State private var note = ""

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var amount: Double? {
        parseAmount(amountText)
    }

    private var referenceAccounts: [Account] {
        store.accounts
            .filter { $0.isActive && ($0.type == .cash || $0.type == .bank || $0.type == .wallet) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var activeCategories: [Category] {
        store.categories
            .filter { $0.isActive }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var availableSubcategories: [String] {
        store.activeSubcategories(for: categoryName)
    }

    private var earliestDueDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var validationMessages: [String] {
        var messages: [String] = []

        if cleanTitle.isEmpty {
            messages.append(store.appLanguage == .arabicEgyptian ? "أدخل اسم الالتزام الشهري." : "Enter a recurring obligation name.")
        }

        if amount == nil || (amount ?? 0) <= 0 {
            messages.append(store.appLanguage == .arabicEgyptian ? "أدخل مبلغًا صحيحًا أكبر من صفر." : "Enter a valid amount greater than zero.")
        }

        if Calendar.current.startOfDay(for: firstDueDate) < earliestDueDate {
            messages.append(store.appLanguage == .arabicEgyptian ? "اختَر تاريخ اليوم أو تاريخًا قادمًا." : "Choose today or a future date.")
        }

        if categoryName.isEmpty ||
            !activeCategories.contains(where: { $0.name == categoryName }) {
            messages.append(store.appLanguage == .arabicEgyptian ? "اختر تصنيفًا موجودًا." : "Choose an existing category.")
        }

        if subCategoryName.isEmpty ||
            !availableSubcategories.contains(where: { $0 == subCategoryName }) {
            messages.append(store.appLanguage == .arabicEgyptian ? "اختر تصنيفًا فرعيًا موجودًا." : "Choose an existing subcategory.")
        }

        if !accountName.isEmpty &&
            !referenceAccounts.contains(where: { $0.name == accountName }) {
            messages.append(store.appLanguage == .arabicEgyptian ? "اختر حسابًا موجودًا أو اتركه بدون حساب." : "Choose an existing account or leave it without an account.")
        }

        return messages
    }

    private var canSave: Bool {
        validationMessages.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(store.appLanguage == .arabicEgyptian ? "قالب شهري غير مدفوع" : "Unpaid Monthly Template") {
                    TextField(store.appLanguage == .arabicEgyptian ? "اسم الالتزام الشهري" : "Recurring obligation name", text: $title)
                        .textInputAutocapitalization(.words)
                        .pocketWiseInputField(semanticColor: .obligations)

                    TextField(store.appLanguage == .arabicEgyptian ? "المبلغ الشهري" : "Monthly amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .obligations, isProminent: true)

                    DatePicker(
                        store.appLanguage == .arabicEgyptian ? "أول تاريخ استحقاق" : "First due date",
                        selection: $firstDueDate,
                        in: earliestDueDate...,
                        displayedComponents: .date
                    )
                    .pocketWiseInputField(semanticColor: .obligations)

                    HStack {
                        Text(store.appLanguage == .arabicEgyptian ? "التكرار" : "Repeat")
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "شهري" : "Monthly")
                            .foregroundStyle(.secondary)
                    }

                    Text(store.appLanguage == .arabicEgyptian ? "المرحلة دي تنشئ قالب شهري فقط، بدون تاريخ نهاية أو عدد مرات." : "This phase creates a monthly template only, with no end date or occurrence count.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(store.appLanguage == .arabicEgyptian ? "التصنيف" : "Category") {
                    CategorySubcategoryPickerView(
                        categoryName: $categoryName,
                        subCategoryName: $subCategoryName,
                        title: store.appLanguage == .arabicEgyptian ? "التصنيف" : "Category",
                        categoryValidationMessage: store.appLanguage == .arabicEgyptian ? "اختر تصنيف" : "Select category",
                        subcategoryValidationMessage: store.appLanguage == .arabicEgyptian ? "اختر تصنيف فرعي" : "Select subcategory"
                    )

                    Text(store.appLanguage == .arabicEgyptian ? "التصنيف للتخطيط فقط. لا يتم احتسابه كمصروف فعلي إلا عند الدفع من المسار العادي." : "Category is for planning only. It is not counted as actual spending until paid from the normal app flow.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(store.appLanguage == .arabicEgyptian ? "حساب الدفع لاحقًا" : "Payment account later") {
                    AccountMenuPickerField(
                        title: store.appLanguage == .arabicEgyptian ? "الحساب" : "Account",
                        selection: $accountName,
                        accounts: referenceAccounts,
                        placeholder: store.appLanguage == .arabicEgyptian ? "بدون حساب الآن" : "No account now",
                        emptyTitle: store.appLanguage == .arabicEgyptian ? "بدون حساب الآن" : "No account now",
                        inactiveSubtitle: false
                    )

                    Text(store.appLanguage == .arabicEgyptian ? "ده مرجع فقط للقالب الشهري غير المدفوع. لا يتم خصم الرصيد من مساعد الإعداد." : "This is only a reference for the unpaid monthly template. Setup Assistant does not deduct the account balance.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(store.appLanguage == .arabicEgyptian ? "ملاحظة" : "Note") {
                    TextField(store.appLanguage == .arabicEgyptian ? "ملاحظة اختيارية" : "Optional note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .pocketWiseInputField(semanticColor: .neutral)
                }

                Section {
                    Text(store.appLanguage == .arabicEgyptian ? "سيتم حفظ هذا كقالب شهري غير مدفوع فقط. البنود المستقبلية تظهر للتخطيط من غير إنشاء سجلات مستقبلية محفوظة." : "This will be saved as an unpaid monthly template only. Future items appear for planning without creating persisted future records.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !validationMessages.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(validationMessages, id: \.self) { message in
                                Text(message)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }

                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()
                            Text(store.appLanguage == .arabicEgyptian ? "حفظ القالب الشهري" : "Save Monthly Template")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(store.appLanguage == .arabicEgyptian ? "التزام شهري" : "Monthly Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupInitialSelection()
            }
            .onChange(of: categoryName) { _, _ in
                updateSubcategoryForCategory()
            }
        }
    }

    private func parseAmount(_ value: String) -> Double? {
        let cleanValue = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !cleanValue.isEmpty else {
            return nil
        }

        return Double(cleanValue)
    }

    private func setupInitialSelection() {
        guard categoryName.isEmpty else {
            return
        }

        categoryName = activeCategories.first?.name ?? ""
        subCategoryName = availableSubcategories.first ?? ""
    }

    private func updateSubcategoryForCategory() {
        if !availableSubcategories.contains(subCategoryName) {
            subCategoryName = availableSubcategories.first ?? ""
        }
    }

    private func save() {
        guard let amount, canSave else {
            return
        }

        let event = FinancialEvent(
            type: .obligation,
            status: .unpaid,
            title: cleanTitle,
            amount: amount,
            date: firstDueDate,
            accountName: accountName.isEmpty ? nil : accountName,
            categoryName: categoryName,
            subCategoryName: subCategoryName,
            repeatRule: .monthly,
            recurringEndKind: nil,
            recurringEndDate: nil,
            recurringEndPaymentCount: nil,
            recurringScheduleOverrides: nil,
            recurringAmountMode: nil,
            recurringEstimatedAmount: nil,
            confidence: .high,
            note: cleanNote.isEmpty ? nil : cleanNote,
            createdAt: Date()
        )

        store.addFinancialEvent(event)
        onSaved(event.id)
        dismiss()
    }
}

// MARK: - Onboarding Budgets Setup

struct OnboardingBudgetsSetupView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMonthIndex: Int = 0
    @State private var plannedAmounts: [String: String] = [:]
    @State private var saveMessage: String?
    @State private var showCopyOverwriteConfirmation = false

    private var availableMonths: [(year: Int, month: Int, label: String)] {
        let cal = Calendar.current
        let now = Date()
        let currentYear = cal.component(.year, from: now)
        let currentMonth = cal.component(.month, from: now)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return (0..<12).compactMap { offset in
            let totalMonth = currentMonth + offset
            let year = currentYear + (totalMonth - 1) / 12
            let month = ((totalMonth - 1) % 12) + 1
            let components = DateComponents(year: year, month: month, day: 1)
            guard let date = cal.date(from: components) else { return nil }
            return (year: year, month: month, label: formatter.string(from: date))
        }
    }

    private var selectedYear: Int {
        guard availableMonths.indices.contains(selectedMonthIndex) else {
            return Calendar.current.component(.year, from: Date())
        }
        return availableMonths[selectedMonthIndex].year
    }

    private var selectedMonth: Int {
        guard availableMonths.indices.contains(selectedMonthIndex) else {
            return Calendar.current.component(.month, from: Date())
        }
        return availableMonths[selectedMonthIndex].month
    }

    private var activeCategories: [Category] {
        store.categories
            .filter { $0.isActive }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var plannedTotal: Double {
        activeCategories.reduce(0.0) { sum, cat in
            sum + parseAmount(plannedAmounts[cat.name] ?? "")
        }
    }

    private var existingBudgetHasNonZeroValues: Bool {
        store.monthlyBudget(year: selectedYear, month: selectedMonth)?
            .items.contains { $0.plannedAmount > 0 } ?? false
    }

    private var previousMonthForCopy: (year: Int, month: Int)? {
        var prevMonth = selectedMonth - 1
        var prevYear = selectedYear
        if prevMonth < 1 {
            prevMonth = 12
            prevYear -= 1
        }
        guard store.monthlyBudget(year: prevYear, month: prevMonth) != nil else {
            return nil
        }
        return (prevYear, prevMonth)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.appLanguage == .arabicEgyptian ? "الميزانيات" : "Budgets")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(store.appLanguage == .arabicEgyptian ? "حدد ميزانيات مخططة يدويًا. ده لا يخلق مصروفات ولا يغير رصيد الكاش." : "Set planned budgets manually. This does not create spending or change your cash balance.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(store.appLanguage == .arabicEgyptian ? "الميزانيات قيم تخطيط فقط. المصروفات الفعلية بتيجي من المعاملات." : "Budgets are planning values only. Actual spending comes from transactions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section(store.appLanguage == .arabicEgyptian ? "الشهر" : "Month") {
                Picker(store.appLanguage == .arabicEgyptian ? "اختر الشهر" : "Select month", selection: $selectedMonthIndex) {
                    ForEach(availableMonths.indices, id: \.self) { idx in
                        Text(availableMonths[idx].label).tag(idx)
                    }
                }
                .pocketWiseInputField(semanticColor: .budgets)

                if existingBudgetHasNonZeroValues {
                    Text(store.appLanguage == .arabicEgyptian ? "محملة قيم ميزانية محفوظة لهذا الشهر." : "Existing saved budget loaded for this month.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if activeCategories.isEmpty {
                Section {
                    Text(store.appLanguage == .arabicEgyptian ? "لا توجد فئات نشطة. أضف فئات من تبويب البودجت أولًا." : "No active categories. Add categories from the Budget tab first.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(store.appLanguage == .arabicEgyptian ? "المبالغ المخططة" : "Planned Amounts") {
                    ForEach(activeCategories) { category in
                        HStack {
                            Text(category.name)
                                .layoutPriority(1)
                            Spacer()
                            TextField("0", text: Binding(
                                get: { plannedAmounts[category.name] ?? "" },
                                set: { plannedAmounts[category.name] = $0 }
                            ))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 110)
                            .pocketWiseInputField(semanticColor: .budgets)
                        }
                    }
                }

                Section {
                    HStack {
                        Text(store.appLanguage == .arabicEgyptian ? "إجمالي مخطط" : "Planned total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(formatAmount(plannedTotal))
                            .fontWeight(.semibold)
                            .foregroundStyle(plannedTotal > 0 ? .primary : .secondary)
                    }
                }
            }

            if previousMonthForCopy != nil {
                Section {
                    Button {
                        if existingBudgetHasNonZeroValues {
                            showCopyOverwriteConfirmation = true
                        } else {
                            if let prev = previousMonthForCopy {
                                performCopy(from: prev)
                            }
                        }
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "نسخ من الشهر السابق" : "Copy from previous month", systemImage: "doc.on.doc")
                    }

                    Text(store.appLanguage == .arabicEgyptian ? "ينسخ المبالغ المخططة من الشهر السابق. المصروفات الفعلية لا تتغير." : "Copies planned amounts from the previous month. Actual spending is not changed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if let message = saveMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.green)
                }

                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "حفظ الميزانية" : "Save Budget")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
                .disabled(activeCategories.isEmpty)
            }

            Section {
                Button {
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "متابعة" : "Continue")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }

                Button {
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "تخطي الآن" : "Skip for now")
                        Spacer()
                    }
                }
                .foregroundStyle(.secondary)
            }

            Section {
                Text(store.appLanguage == .arabicEgyptian ? "مساعد الإعداد يحفظ مبالغ مخططة فقط. لا ينشئ معاملات أو أحداث مالية أو مصروفات فعلية أو حركة كاش." : "Setup Assistant saves planned amounts only. It does not create transactions, financial events, actual spending, or cash movement.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "الميزانيات" : "Budgets")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBudgetForSelectedMonth()
        }
        .onChange(of: selectedMonthIndex) { _, _ in
            loadBudgetForSelectedMonth()
        }
        .confirmationDialog(
            store.appLanguage == .arabicEgyptian ? "هذا الشهر فيه قيم مخططة محفوظة. النسخ هيستبدلها. هل تكمل؟" : "This month already has planned values. Copying will replace them. Continue?",
            isPresented: $showCopyOverwriteConfirmation,
            titleVisibility: .visible
        ) {
            Button(store.appLanguage == .arabicEgyptian ? "نسخ واستبدال" : "Copy and Replace", role: .destructive) {
                if let prev = previousMonthForCopy {
                    performCopy(from: prev)
                }
            }
            Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel", role: .cancel) {}
        }
    }

    private func parseAmount(_ value: String) -> Double {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) ?? 0
    }

    private func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    private func formatAmountForField(_ value: Double) -> String {
        guard !value.isNaN, !value.isInfinite else { return "0" }
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    private func loadBudgetForSelectedMonth() {
        saveMessage = nil
        var newAmounts: [String: String] = [:]
        if let existing = store.monthlyBudget(year: selectedYear, month: selectedMonth) {
            for item in existing.items where item.plannedAmount > 0 {
                newAmounts[item.categoryName] = formatAmountForField(item.plannedAmount)
            }
        }
        plannedAmounts = newAmounts
    }

    private func save() {
        var amounts: [String: Double] = [:]
        for category in activeCategories {
            amounts[category.name] = parseAmount(plannedAmounts[category.name] ?? "")
        }
        store.saveMonthlyBudget(year: selectedYear, month: selectedMonth, plannedAmountsByCategory: amounts)
        saveMessage = store.appLanguage == .arabicEgyptian ? "تم حفظ الميزانية." : "Budget saved."
    }

    private func performCopy(from entry: (year: Int, month: Int)) {
        guard let sourceBudget = store.monthlyBudget(year: entry.year, month: entry.month) else {
            return
        }
        var newAmounts: [String: String] = [:]
        for item in sourceBudget.items where item.plannedAmount > 0 {
            newAmounts[item.categoryName] = formatAmountForField(item.plannedAmount)
        }
        plannedAmounts = newAmounts
        saveMessage = nil
    }
}

struct OnboardingAccountsSetupView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var addAccountType: AccountType?
    @State private var setupAddedAccountIDs: Set<UUID> = []

    private var sortedAccounts: [Account] {
        store.accounts.sorted {
            if $0.isActive == $1.isActive {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            return $0.isActive && !$1.isActive
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.appLanguage == .arabicEgyptian ? "الحسابات والمحافظ" : "Accounts & Wallets")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(store.appLanguage == .arabicEgyptian ? "أضف حساباتك يدويًا. لا تحتاج لتسجيل دخول بنكي." : "Add your accounts manually. No bank login is required.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(store.appLanguage == .arabicEgyptian ? "الرصيد هنا هو رصيد بداية/حالي فقط، ولا ينشئ دخل أو مصروف." : "The balance here is a starting/current balance only. It does not create income or expense records.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section {
                Button {
                    addAccountType = .cash
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "أضف محفظة كاش" : "Add Cash Wallet", systemImage: "banknote.fill")
                }

                Button {
                    addAccountType = .bank
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "أضف حساب بنكي" : "Add Bank Account", systemImage: "building.columns.fill")
                }
            }

            Section(store.appLanguage == .arabicEgyptian ? "الحسابات الحالية" : "Current Accounts") {
                if sortedAccounts.isEmpty {
                    Text(store.appLanguage == .arabicEgyptian ? "لسه مفيش حسابات." : "No accounts yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedAccounts) { account in
                        onboardingAccountRow(account)
                    }
                }
            }

            Section {
                Button {
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "متابعة" : "Continue")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }

                Button {
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text(store.appLanguage == .arabicEgyptian ? "تخطي الآن" : "Skip for now")
                        Spacer()
                    }
                }
                .foregroundStyle(.secondary)
            }

            Section {
                Text(store.appLanguage == .arabicEgyptian ? "تقدر تعدل الحسابات لاحقًا من الإعدادات > إدارة الحسابات." : "You can edit accounts later from Settings > Manage Accounts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "الحسابات والمحافظ" : "Accounts & Wallets")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $addAccountType) { accountType in
            OnboardingAccountEditorSheet(
                initialType: accountType,
                onSaved: { accountName in
                    if let account = store.accounts.first(where: { $0.name.caseInsensitiveCompare(accountName) == .orderedSame }) {
                        setupAddedAccountIDs.insert(account.id)
                    }
                    addAccountType = nil
                }
            )
            .environmentObject(store)
        }
    }

    private func onboardingAccountRow(_ account: Account) -> some View {
        HStack(spacing: 12) {
            AccountVisualMark(account: account, size: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(account.name)
                        .font(.headline)

                    if setupAddedAccountIDs.contains(account.id) {
                        Text(store.appLanguage == .arabicEgyptian ? "جديد" : "New")
                            .pocketWiseChip(semanticColor: .success)
                    }
                }

                Text(account.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(store.displayCurrency(account.balance, maximumFractionDigits: 2))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(PocketWiseSemanticColor.accounts.tint)
        }
        .padding(.vertical, 4)
    }
}

struct OnboardingAccountEditorSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let initialType: AccountType
    let onSaved: (String) -> Void

    @State private var name = ""
    @State private var type: AccountType
    @State private var balanceText = "0"
    @State private var appearanceColor: ProviderAppearanceColor?

    init(initialType: AccountType, onSaved: @escaping (String) -> Void) {
        self.initialType = initialType
        self.onSaved = onSaved
        _type = State(initialValue: initialType)
    }

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var balanceValue: Double? {
        Double(balanceText.replacingOccurrences(of: ",", with: "."))
    }

    private var isDuplicateName: Bool {
        store.accountNameExists(name)
    }

    private var canSave: Bool {
        !cleanName.isEmpty &&
        !isDuplicateName &&
        (balanceValue ?? -1) >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(store.appLanguage == .arabicEgyptian ? "الحساب" : "Account") {
                    TextField(store.appLanguage == .arabicEgyptian ? "اسم الحساب" : "Account name", text: $name)
                        .textInputAutocapitalization(.words)
                        .pocketWiseInputField(semanticColor: .accounts)

                    if cleanName.isEmpty {
                        validationMessage(store.appLanguage == .arabicEgyptian ? "أدخل اسم الحساب." : "Enter an account name.")
                    }

                    if isDuplicateName {
                        validationMessage(store.appLanguage == .arabicEgyptian ? "اسم الحساب موجود بالفعل." : "Account name already exists.")
                    }

                    Picker(store.appLanguage == .arabicEgyptian ? "النوع" : "Type", selection: $type) {
                        Text(store.appLanguage == .arabicEgyptian ? "كاش" : "Cash")
                            .tag(AccountType.cash)
                        Text(store.appLanguage == .arabicEgyptian ? "بنك" : "Bank")
                            .tag(AccountType.bank)
                    }
                    .pocketWiseInputField(semanticColor: .accounts)

                    TextField(store.appLanguage == .arabicEgyptian ? "الرصيد الحالي" : "Opening/current balance", text: $balanceText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .accounts, isProminent: true)

                    if balanceValue == nil || (balanceValue ?? 0) < 0 {
                        validationMessage(store.appLanguage == .arabicEgyptian ? "أدخل رصيدًا صحيحًا صفر أو أكثر." : "Enter a valid balance of zero or more.")
                    }

                    Text(store.appLanguage == .arabicEgyptian ? "الرصيد ده نقطة بداية فقط. مش هيضيف دخل أو مصروف." : "This balance is only a starting point. It will not add income or expense records.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(store.appLanguage == .arabicEgyptian ? "الشكل" : "Appearance") {
                    HStack(spacing: 12) {
                        AccountVisualMark(
                            account: Account(
                                name: cleanName.isEmpty ? "Account" : cleanName,
                                balance: 0,
                                type: type,
                                appearanceColor: appearanceColor ?? defaultAppearanceColor
                            ),
                            size: 38
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.appLanguage == .arabicEgyptian ? "شارة آمنة" : "Safe provider badge")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(store.appLanguage == .arabicEgyptian ? "أيقونة عامة ولون مختار بدون شعارات رسمية." : "Generic icon and selected color without official logos.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ProviderAppearanceColorPicker(
                        title: store.appLanguage == .arabicEgyptian ? "اللون" : "Color",
                        selection: $appearanceColor,
                        defaultColor: defaultAppearanceColor
                    )
                }

                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()
                            Text(store.appLanguage == .arabicEgyptian ? "حفظ الحساب" : "Save Account")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle(type == .cash ? (store.appLanguage == .arabicEgyptian ? "محفظة كاش" : "Cash Wallet") : (store.appLanguage == .arabicEgyptian ? "حساب بنكي" : "Bank Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
    }

    private func save() {
        guard let balanceValue, canSave else {
            return
        }

        store.addAccount(
            name: cleanName,
            type: type,
            balance: balanceValue,
            appearanceColor: appearanceColor ?? defaultAppearanceColor
        )
        onSaved(cleanName)
        dismiss()
    }

    private var defaultAppearanceColor: ProviderAppearanceColor {
        switch type {
        case .cash:
            return .green
        case .bank:
            return .blue
        case .wallet:
            return .teal
        }
    }
}
