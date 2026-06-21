import SwiftUI

struct CategorySubcategoryPickerView: View {
    @EnvironmentObject private var store: WalletStore
    @Environment(\.colorScheme) private var colorScheme

    @Binding var categoryName: String
    @Binding var subCategoryName: String

    var title: String = "Category"
    var showsValidation: Bool = false
    var categoryValidationMessage: String = "Select a category."
    var subcategoryValidationMessage: String = "Select a subcategory."
    var includesInactiveSelection: Bool = false
    var suggestion: CategorySubcategorySuggestion?
    var highlightsSelectedCategory: Bool = false

    @State private var isShowingSelector = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(title, selection: categorySelection) {
                Text(store.appLanguage == .arabicEgyptian ? "اختر التصنيف" : "Select category")
                    .tag("")

                ForEach(categoriesForSelection) { category in
                    Text(categoryLabel(for: category))
                        .tag(category.name)
                }
            }
            .pocketWiseInputField(semanticColor: .categories)
            .overlay {
                if highlightsSelectedCategory && !categoryName.isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(PocketWiseSemanticColor.categories.tint.opacity(0.75), lineWidth: 1.5)
                }
            }
            .background {
                if highlightsSelectedCategory && !categoryName.isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(PocketWiseSemanticColor.categories.softBackground(for: colorScheme).opacity(0.55))
                }
            }

            Picker(store.appLanguage == .arabicEgyptian ? "التصنيف الفرعي" : "Subcategory", selection: $subCategoryName) {
                Text(store.appLanguage == .arabicEgyptian ? "اختر التصنيف الفرعي" : "Select subcategory")
                    .tag("")

                ForEach(availableSubcategories, id: \.self) { subcategory in
                    Text(subcategoryLabel(subcategory))
                        .tag(subcategory)
                }
            }
            .pocketWiseInputField(semanticColor: .categories)
            .disabled(categoryName.isEmpty)

            if let suggestion, !isCurrentSelection(suggestion), canApplySuggestion(suggestion) {
                Button {
                    categoryName = suggestion.categoryName
                    subCategoryName = suggestion.subCategoryName
                } label: {
                    HStack(spacing: 12) {
                        PocketWiseIconBadge(
                            systemName: "sparkles",
                            semanticColor: .categories,
                            size: 34
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.appLanguage == .arabicEgyptian ? "اقتراح من معاملات سابقة" : "Suggested from past transactions")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("\(categoryDisplayName(suggestion.categoryName)) → \(subcategoryDisplayName(suggestion.subCategoryName))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Text(store.appLanguage == .arabicEgyptian ? "تطبيق" : "Apply")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PocketWiseSemanticColor.categories.tint)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pocketWiseInputField(semanticColor: .categories)
            }

            Button {
                isShowingSelector = true
            } label: {
                HStack(spacing: 12) {
                    PocketWiseIconBadge(
                        systemName: "tag.fill",
                        semanticColor: .categories,
                        size: 34
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.appLanguage == .arabicEgyptian ? "بحث سريع" : "Search helper")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(store.appLanguage == .arabicEgyptian ? "ابحث في كل التصنيفات" : "Find category/subcategory")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if hasSelection {
                            Text(AppText.categorySubcategoryDisplayText(
                                categoryName: categoryName,
                                subCategoryName: subCategoryName,
                                language: store.appLanguage
                            ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    Image(systemName: "magnifyingglass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PocketWiseSemanticColor.categories.tint)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pocketWiseInputField(semanticColor: .categories)

            if showsValidation && categoryName.isEmpty {
                validationMessage(categoryValidationMessage)
            }

            if showsValidation && subCategoryName.isEmpty {
                validationMessage(subcategoryValidationMessage)
            }
        }
        .sheet(isPresented: $isShowingSelector) {
            CategorySubcategorySearchSheet(
                categoryName: $categoryName,
                subCategoryName: $subCategoryName,
                includesInactiveSelection: includesInactiveSelection
            )
            .environmentObject(store)
        }
    }

    private var hasSelection: Bool {
        !categoryName.isEmpty && !subCategoryName.isEmpty
    }

    private var categorySelection: Binding<String> {
        Binding(
            get: { categoryName },
            set: { newCategoryName in
                categoryName = newCategoryName
                normalizeSubcategory(for: newCategoryName)
            }
        )
    }

    private var categoriesForSelection: [Category] {
        store.categories
            .filter { category in
                category.isActive ||
                (includesInactiveSelection && category.name == categoryName)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var availableSubcategories: [String] {
        guard !categoryName.isEmpty else {
            return []
        }

        if includesInactiveSelection {
            return store.subcategoriesForEditing(
                categoryName: categoryName,
                selectedSubcategoryName: subCategoryName
            )
        }

        return store.activeSubcategories(for: categoryName)
    }

    private func normalizeSubcategory(for categoryName: String) {
        guard !categoryName.isEmpty else {
            subCategoryName = ""
            return
        }

        let subcategories: [String]
        if includesInactiveSelection {
            subcategories = store.subcategoriesForEditing(
                categoryName: categoryName,
                selectedSubcategoryName: subCategoryName
            )
        } else {
            subcategories = store.activeSubcategories(for: categoryName)
        }

        guard subcategories.contains(subCategoryName) else {
            subCategoryName = subcategories.first ?? ""
            return
        }
    }

    private func categoryLabel(for category: Category) -> String {
        let displayName = categoryDisplayName(category.name)
        if category.isActive {
            return displayName
        }

        return store.appLanguage == .arabicEgyptian
            ? "\(displayName) (غير نشط)"
            : "\(displayName) (inactive)"
    }

    private func subcategoryLabel(_ subcategory: String) -> String {
        subcategoryDisplayName(subcategory)
    }

    private func categoryDisplayName(_ category: String) -> String {
        AppText.categoryDisplayName(category, language: store.appLanguage)
    }

    private func subcategoryDisplayName(_ subcategory: String) -> String {
        AppText.subcategoryDisplayName(subcategory, language: store.appLanguage)
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(PocketWiseSemanticColor.danger.tint)
    }

    private func isCurrentSelection(_ suggestion: CategorySubcategorySuggestion) -> Bool {
        categoryName == suggestion.categoryName && subCategoryName == suggestion.subCategoryName
    }

    private func canApplySuggestion(_ suggestion: CategorySubcategorySuggestion) -> Bool {
        categoriesForSelection.contains { category in
            category.name == suggestion.categoryName &&
            subcategories(for: category).contains(suggestion.subCategoryName)
        }
    }

    private func subcategories(for category: Category) -> [String] {
        if includesInactiveSelection && category.name == categoryName {
            return store.subcategoriesForEditing(
                categoryName: category.name,
                selectedSubcategoryName: subCategoryName
            )
        }

        return store.activeSubcategories(for: category.name)
    }
}

struct CategorySubcategorySuggestion: Equatable {
    let categoryName: String
    let subCategoryName: String
    let matchCount: Int
}

struct CategorySuggestionRequest {
    var title: String = ""
    var merchant: String? = nil
    var note: String = ""
    var rawText: String? = nil
    var accountName: String = ""
    var paymentMethodName: String = ""
    var allowedEventTypes: Set<FinancialEventType>? = nil
    var includeCreditCardPurchases: Bool = true
    var excludingFinancialEventID: UUID? = nil
    var excludingCreditCardPurchaseID: UUID? = nil
}

extension WalletStore {
    func suggestedCategorySubcategory(for request: CategorySuggestionRequest) -> CategorySubcategorySuggestion? {
        let clues = CategorySuggestionClues(request: request)
        guard clues.hasUsefulClues else {
            return nil
        }

        var aggregates: [String: CategorySuggestionAggregate] = [:]

        for event in financialEvents {
            guard event.id != request.excludingFinancialEventID,
                  event.status == .paid,
                  let categoryName = event.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let subCategoryName = event.subCategoryName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !categoryName.isEmpty,
                  !subCategoryName.isEmpty,
                  categorySubcategoryIsAvailable(categoryName: categoryName, subCategoryName: subCategoryName) else {
                continue
            }

            if let allowedEventTypes = request.allowedEventTypes,
               !allowedEventTypes.contains(event.type) {
                continue
            }

            guard let score = clues.score(
                title: event.title,
                note: event.note ?? "",
                accountName: event.accountName ?? "",
                paymentMethodName: event.paymentMethodName ?? "",
                extraText: event.walletEventName ?? ""
            ) else {
                continue
            }

            addSuggestionMatch(
                score: score,
                categoryName: categoryName,
                subCategoryName: subCategoryName,
                createdAt: event.createdAt,
                aggregates: &aggregates
            )
        }

        if request.includeCreditCardPurchases {
            for purchase in creditCardPurchases {
                guard purchase.id != request.excludingCreditCardPurchaseID,
                      categorySubcategoryIsAvailable(categoryName: purchase.categoryName, subCategoryName: purchase.subCategoryName) else {
                    continue
                }

                let cardName = creditCards.first { $0.id == purchase.cardID }?.name ?? ""
                guard let score = clues.score(
                    title: purchase.title,
                    note: purchase.note ?? "",
                    accountName: cardName,
                    paymentMethodName: "Credit Card",
                    extraText: cardName
                ) else {
                    continue
                }

                addSuggestionMatch(
                    score: score,
                    categoryName: purchase.categoryName,
                    subCategoryName: purchase.subCategoryName,
                    createdAt: purchase.createdAt,
                    aggregates: &aggregates
                )
            }
        }

        let rankedSuggestions = aggregates.values
            .sorted {
                if $0.matchCount != $1.matchCount {
                    return $0.matchCount > $1.matchCount
                }

                if $0.score != $1.score {
                    return $0.score > $1.score
                }

                return $0.latestMatch > $1.latestMatch
            }

        guard let topSuggestion = rankedSuggestions.first,
              topSuggestion.score >= CategorySuggestionClues.minimumSuggestionScore,
              suggestionIsDominant(topSuggestion, over: rankedSuggestions.dropFirst().first) else {
            return nil
        }

        return CategorySubcategorySuggestion(
            categoryName: topSuggestion.categoryName,
            subCategoryName: topSuggestion.subCategoryName,
            matchCount: topSuggestion.matchCount
        )
    }

    private func suggestionIsDominant(
        _ topSuggestion: CategorySuggestionAggregate,
        over secondSuggestion: CategorySuggestionAggregate?
    ) -> Bool {
        guard let secondSuggestion else {
            return true
        }

        if topSuggestion.matchCount >= secondSuggestion.matchCount * 2,
           topSuggestion.score >= secondSuggestion.score + CategorySuggestionClues.minimumSuggestionScore {
            return true
        }

        if topSuggestion.matchCount >= secondSuggestion.matchCount + 2,
           topSuggestion.score > secondSuggestion.score {
            return true
        }

        return false
    }

    private func addSuggestionMatch(
        score: Int,
        categoryName: String,
        subCategoryName: String,
        createdAt: Date,
        aggregates: inout [String: CategorySuggestionAggregate]
    ) {
        guard score >= CategorySuggestionClues.minimumCandidateScore else {
            return
        }

        let key = "\(categoryName)\u{1F}\(subCategoryName)"
        var aggregate = aggregates[key] ?? CategorySuggestionAggregate(
            categoryName: categoryName,
            subCategoryName: subCategoryName,
            score: 0,
            matchCount: 0,
            latestMatch: .distantPast
        )

        aggregate.score += score
        aggregate.matchCount += 1
        aggregate.latestMatch = max(aggregate.latestMatch, createdAt)
        aggregates[key] = aggregate
    }

    private func categorySubcategoryIsAvailable(categoryName: String, subCategoryName: String) -> Bool {
        categories.contains { category in
            category.name == categoryName &&
            category.subcategories.contains { $0.caseInsensitiveCompare(subCategoryName) == .orderedSame }
        }
    }
}

private struct CategorySuggestionAggregate {
    let categoryName: String
    let subCategoryName: String
    var score: Int
    var matchCount: Int
    var latestMatch: Date
}

private struct CategorySuggestionClues {
    static let minimumCandidateScore = 7
    static let minimumSuggestionScore = 7

    let title: String
    let merchant: String
    let note: String
    let rawText: String
    let accountName: String
    let paymentMethodName: String
    let primaryTokens: Set<String>

    init(request: CategorySuggestionRequest) {
        title = request.title.trimmingCharacters(in: .whitespacesAndNewlines)
        merchant = request.merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        note = request.note.trimmingCharacters(in: .whitespacesAndNewlines)
        rawText = request.rawText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        accountName = request.accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        paymentMethodName = request.paymentMethodName.trimmingCharacters(in: .whitespacesAndNewlines)
        primaryTokens = Self.tokens(from: [title, merchant, rawText])
    }

    var hasUsefulClues: Bool {
        !merchant.isEmpty || !title.isEmpty || !primaryTokens.isEmpty
    }

    func score(
        title candidateTitle: String,
        note candidateNote: String,
        accountName candidateAccountName: String,
        paymentMethodName candidatePaymentMethodName: String,
        extraText: String
    ) -> Int? {
        let candidateTitleText = [candidateTitle, extraText].joined(separator: " ")
        let candidateNoteText = candidateNote
        let normalizedCandidateTitleText = Self.normalized(candidateTitleText)
        let normalizedCandidateNoteText = Self.normalized(candidateNoteText)
        let candidateTitleTokens = Self.tokens(from: [candidateTitleText])
        let candidateNoteTokens = Self.tokens(from: [candidateNoteText])
        let titleOverlap = primaryTokens.intersection(candidateTitleTokens).count
        let noteOverlap = primaryTokens.intersection(candidateNoteTokens).count

        var primaryScore = 0
        if titleOverlap > 0 {
            primaryScore += min(titleOverlap * 4, 12)
        }

        if !merchant.isEmpty {
            primaryScore += directTextScore(
                query: merchant,
                candidateText: normalizedCandidateTitleText
            )
        }

        if !title.isEmpty {
            primaryScore += directTextScore(
                query: title,
                candidateText: normalizedCandidateTitleText
            )
        }

        guard primaryScore >= Self.minimumCandidateScore else {
            return nil
        }

        var score = primaryScore
        if noteOverlap > 0 {
            score += min(noteOverlap, 2)
        }

        if !merchant.isEmpty {
            score += min(
                directTextScore(query: merchant, candidateText: normalizedCandidateNoteText),
                2
            )
        }

        if !accountName.isEmpty &&
            Self.normalized(candidateAccountName) == Self.normalized(accountName) {
            score += 1
        }

        if !paymentMethodName.isEmpty &&
            Self.normalized(candidatePaymentMethodName) == Self.normalized(paymentMethodName) {
            score += 1
        }

        return score
    }

    private func directTextScore(query: String, candidateText: String) -> Int {
        let normalizedQuery = Self.normalized(query)
        guard !normalizedQuery.isEmpty else {
            return 0
        }

        if candidateText == normalizedQuery {
            return 14
        }

        if candidateText.contains(normalizedQuery) {
            return 8
        }

        let queryTokens = Self.tokens(from: [query])
        let candidateTokens = Self.tokens(from: [candidateText])
        if !queryTokens.isEmpty,
           queryTokens.isSubset(of: candidateTokens) {
            return 6
        }

        return 0
    }

    private static func tokens(from values: [String]) -> Set<String> {
        let separators = CharacterSet.letters.union(.decimalDigits).inverted
        return Set(
            values
                .flatMap { normalizedForMatching($0).components(separatedBy: separators) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.count >= 3 && !genericTokens.contains($0) }
        )
    }

    private static let genericTokens: Set<String> = [
        "account",
        "bank",
        "bill",
        "card",
        "cash",
        "credit",
        "debit",
        "egp",
        "fee",
        "from",
        "instapay",
        "payment",
        "paid",
        "purchase",
        "transaction",
        "transfer"
    ]

    private static let genericPhrases: [String] = [
        "apple pay",
        "applepay"
    ]

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private static func normalizedForMatching(_ value: String) -> String {
        var normalizedValue = normalized(value)
        for phrase in genericPhrases {
            normalizedValue = normalizedValue.replacingOccurrences(of: phrase, with: " ")
        }

        return normalizedValue
    }
}

private struct CategorySubcategorySearchSheet: View {
    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @Binding var categoryName: String
    @Binding var subCategoryName: String

    let includesInactiveSelection: Bool

    @State private var searchText = ""

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var results: [CategorySubcategorySearchResult] {
        let query = normalized(searchText)

        return allResults.filter { result in
            guard !query.isEmpty else {
                return true
            }

            return normalized(result.categoryName).contains(query) ||
            normalized(result.subCategoryName).contains(query) ||
            normalized(AppText.categoryDisplayName(result.categoryName, language: store.appLanguage)).contains(query) ||
            normalized(AppText.subcategoryDisplayName(result.subCategoryName, language: store.appLanguage)).contains(query)
        }
    }

    private var allResults: [CategorySubcategorySearchResult] {
        categoriesForSelection.flatMap { category in
            subcategories(for: category).map { subcategory in
                CategorySubcategorySearchResult(
                    categoryName: category.name,
                    subCategoryName: subcategory,
                    isCategoryActive: category.isActive
                )
            }
        }
    }

    private var categoriesForSelection: [Category] {
        store.categories
            .filter { category in
                category.isActive ||
                (includesInactiveSelection && category.name == categoryName)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if results.isEmpty {
                    Text(isArabic ? "لا توجد نتائج" : "No matching categories")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(results) { result in
                        Button {
                            categoryName = result.categoryName
                            subCategoryName = result.subCategoryName
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                PocketWiseIconBadge(
                                    systemName: "tag.fill",
                                    semanticColor: .categories,
                                    size: 32
                                )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(AppText.subcategoryDisplayName(result.subCategoryName, language: store.appLanguage))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text(AppText.categoryDisplayName(result.categoryName, language: store.appLanguage))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if result.categoryName == categoryName &&
                                    result.subCategoryName == subCategoryName {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(PocketWiseSemanticColor.success.tint)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(isArabic ? "اختر التصنيف" : "Choose Category")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: isArabic ? "ابحث بالتصنيف أو التصنيف الفرعي" : "Search category or subcategory"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isArabic ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func subcategories(for category: Category) -> [String] {
        if includesInactiveSelection && category.name == categoryName {
            return store.subcategoriesForEditing(
                categoryName: category.name,
                selectedSubcategoryName: subCategoryName
            )
        }

        return store.activeSubcategories(for: category.name)
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

private struct CategorySubcategorySearchResult: Identifiable {
    let categoryName: String
    let subCategoryName: String
    let isCategoryActive: Bool

    var id: String {
        "\(categoryName)|\(subCategoryName)"
    }
}
