import SwiftUI

struct HistoricalSummaryView: View {

    @EnvironmentObject private var store: WalletStore

    @State private var selectedMonthDate = Date()
    @State private var isAddingEntry = false
    @State private var isBulkEntry = false
    @State private var editingEntry: HistoricalMonthlySummaryEntry?

    private var monthComponents: (year: Int, month: Int) {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedMonthDate)
        return (components.year ?? 2026, components.month ?? 1)
    }

    private var entries: [HistoricalMonthlySummaryEntry] {
        store.historicalSummaries(year: monthComponents.year, month: monthComponents.month)
    }

    private var totalAmount: Double {
        entries.map { $0.amount }.reduce(0, +)
    }

    var body: some View {
        List {
            Section {
                monthSelector
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(store.appLanguage == .arabicEgyptian ? "بيانات ملخصة بس" : "Summary-only historical data", systemImage: "doc.text.magnifyingglass")
                        .font(.headline)

                    Text(store.appLanguage == .arabicEgyptian ? "استخدمها للشهور القديمة لما تكون عارف إجماليات البنود بس. مش بتغيّر الأرصدة ومش بتعمل حركات." : "Use this for old months when you only know category totals. These entries do not change account balances and do not create transactions.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(store.appLanguage == .arabicEgyptian ? "استخدمها للشهور القديمة بس. بتسجل إجماليات من غير ما تغيّر الأرصدة." : "Use this for old months only. It saves summary totals without changing balances.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section(store.appLanguage == .arabicEgyptian ? "إجمالي الشهر" : "Month Total") {
                HStack {
                    Text(store.appLanguage == .arabicEgyptian ? "صرف ملخص" : "Summary-only spending")
                    Spacer()
                    Text(formatCurrency(totalAmount))
                        .fontWeight(.semibold)
                }
            }

            Section(store.appLanguage == .arabicEgyptian ? "الإدخالات" : "Entries") {
                if entries.isEmpty {
                    Text(store.appLanguage == .arabicEgyptian ? "لسه مفيش ملخصات للشهر ده." : "No summary-only entries for this month.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entries) { entry in
                        Button {
                            editingEntry = entry
                        } label: {
                            historicalEntryRow(entry)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                store.deleteHistoricalMonthlySummary(entry)
                            } label: {
                                Label(store.appLanguage == .arabicEgyptian ? "حذف" : "Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "ملخص الشهور القديمة" : "Past Month Fast Logging")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        isAddingEntry = true
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "أضف إدخال" : "Add Entry", systemImage: "plus")
                    }

                    Button {
                        isBulkEntry = true
                    } label: {
                        Label(store.appLanguage == .arabicEgyptian ? "إدخال شهر قديم بسرعة" : "Bulk Entry", systemImage: "square.and.pencil")
                    }
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "إضافة" : "Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingEntry) {
            HistoricalSummaryEditorView(
                entry: nil,
                year: monthComponents.year,
                month: monthComponents.month
            )
            .environmentObject(store)
        }
        .sheet(isPresented: $isBulkEntry) {
            HistoricalSummaryBulkEntryView(
                year: monthComponents.year,
                month: monthComponents.month
            )
            .environmentObject(store)
        }
        .sheet(item: $editingEntry) { entry in
            HistoricalSummaryEditorView(
                entry: entry,
                year: entry.year,
                month: entry.month
            )
            .environmentObject(store)
        }
    }

    private var monthSelector: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)

            Spacer()

            VStack(spacing: 4) {
                Text(formatMonth(selectedMonthDate))
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(store.appLanguage == .arabicEgyptian ? "اختار الشهر القديم للتلخيص" : "Select the old month to summarize")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderless)
        }
    }

    private func historicalEntryRow(_ entry: HistoricalMonthlySummaryEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppText.categoryDisplayName(entry.categoryName, language: store.appLanguage))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(AppText.subcategoryDisplayName(entry.subCategoryName, language: store.appLanguage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(formatCurrency(entry.amount))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    private func moveMonth(by value: Int) {
        selectedMonthDate = Calendar.current.date(byAdding: .month, value: value, to: selectedMonthDate) ?? selectedMonthDate
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        if store.appLanguage == .arabicEgyptian {
            formatter.locale = Locale(identifier: "ar_EG")
        }
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount)
    }
}

private struct HistoricalSummaryBulkEntryView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let year: Int
    let month: Int

    @State private var amountTexts: [String: String] = [:]
    @State private var subcategoryNames: [String: String] = [:]

    private var activeCategories: [Category] {
        store.categories
            .filter { $0.isActive }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var hasInvalidAmounts: Bool {
        amountTexts.values.contains { text in
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            Double(text.replacingOccurrences(of: ",", with: ".")) == nil
        }
    }

    private var hasAnyAmount: Bool {
        amountTexts.values.contains { text in
            (Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(store.appLanguage == .arabicEgyptian ? "احفظ إجماليات شهر قديم كملخص فقط. مش هيأثر على الرصيد ومش هيعمل حركات." : "Save old-month category totals as summary-only data. This does not affect balances and does not create transactions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(store.appLanguage == .arabicEgyptian ? "البنود" : "Categories") {
                    ForEach(activeCategories) { category in
                        categoryBulkRow(category)
                    }
                }
            }
            .navigationTitle(store.appLanguage == .arabicEgyptian ? "إدخال شهر قديم بسرعة" : "Bulk Historical Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.appLanguage == .arabicEgyptian ? "حفظ" : "Save") {
                        saveBulkEntries()
                    }
                    .disabled(hasInvalidAmounts || !hasAnyAmount)
                }
            }
            .onAppear {
                loadExistingValues()
            }
        }
    }

    private func categoryBulkRow(_ category: Category) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppText.categoryDisplayName(category.name, language: store.appLanguage))
                .font(.headline)

            Picker(store.appLanguage == .arabicEgyptian ? "التصنيف الفرعي" : "Subcategory", selection: subcategoryBinding(for: category.name)) {
                ForEach(store.activeSubcategories(for: category.name), id: \.self) { subcategory in
                    Text(AppText.subcategoryDisplayName(subcategory, language: store.appLanguage)).tag(subcategory)
                }
            }

            TextField(store.appLanguage == .arabicEgyptian ? "المبلغ" : "Amount", text: amountBinding(for: category.name))
                .keyboardType(.decimalPad)
        }
        .padding(.vertical, 4)
    }

    private func loadExistingValues() {
        let entries = store.historicalSummaries(year: year, month: month)
        var loadedAmounts: [String: String] = [:]
        var loadedSubcategories: [String: String] = [:]

        for category in activeCategories {
            let existingEntry = entries.first { $0.categoryName == category.name }
            loadedAmounts[category.name] = existingEntry.map { Self.cleanNumberText($0.amount) } ?? ""
            loadedSubcategories[category.name] = existingEntry?.subCategoryName ?? store.activeSubcategories(for: category.name).first ?? ""
        }

        amountTexts = loadedAmounts
        subcategoryNames = loadedSubcategories
    }

    private func saveBulkEntries() {
        guard !hasInvalidAmounts else {
            return
        }

        let existingEntries = store.historicalSummaries(year: year, month: month)

        for category in activeCategories {
            let amount = Double((amountTexts[category.name] ?? "").replacingOccurrences(of: ",", with: ".")) ?? 0

            guard amount > 0 else {
                continue
            }

            let subcategoryName = subcategoryNames[category.name] ?? store.activeSubcategories(for: category.name).first ?? ""

            if let existingEntry = existingEntries.first(where: { $0.categoryName == category.name && $0.subCategoryName == subcategoryName }) {
                store.updateHistoricalMonthlySummary(
                    entryID: existingEntry.id,
                    categoryName: category.name,
                    subCategoryName: subcategoryName,
                    amount: amount,
                    note: existingEntry.note
                )
            } else {
                store.addHistoricalMonthlySummary(
                    year: year,
                    month: month,
                    categoryName: category.name,
                    subCategoryName: subcategoryName,
                    amount: amount,
                    note: nil
                )
            }
        }

        dismiss()
    }

    private func amountBinding(for categoryName: String) -> Binding<String> {
        Binding(
            get: { amountTexts[categoryName] ?? "" },
            set: { amountTexts[categoryName] = $0 }
        )
    }

    private func subcategoryBinding(for categoryName: String) -> Binding<String> {
        Binding(
            get: { subcategoryNames[categoryName] ?? store.activeSubcategories(for: categoryName).first ?? "" },
            set: { subcategoryNames[categoryName] = $0 }
        )
    }

    private static func cleanNumberText(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return "\(amount)"
    }
}

private struct HistoricalSummaryEditorView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let entry: HistoricalMonthlySummaryEntry?
    let year: Int
    let month: Int

    @State private var selectedCategoryName: String
    @State private var selectedSubCategoryName: String
    @State private var amountText: String
    @State private var note: String

    private var isAr: Bool {
        store.appLanguage == .arabicEgyptian
    }

    init(entry: HistoricalMonthlySummaryEntry?, year: Int, month: Int) {
        self.entry = entry
        self.year = year
        self.month = month
        _selectedCategoryName = State(initialValue: entry?.categoryName ?? "")
        _selectedSubCategoryName = State(initialValue: entry?.subCategoryName ?? "")
        _amountText = State(initialValue: entry.map { Self.cleanNumberText($0.amount) } ?? "")
        _note = State(initialValue: entry?.note ?? "")
    }

    private var activeCategories: [Category] {
        store.categories
            .filter { $0.isActive || $0.name == entry?.categoryName }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var subcategories: [String] {
        store.subcategoriesForEditing(
            categoryName: selectedCategoryName,
            selectedSubcategoryName: selectedSubCategoryName
        )
    }

    private var amountValue: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var canSave: Bool {
        amountValue > 0 &&
        activeCategories.contains(where: { $0.name == selectedCategoryName }) &&
        subcategories.contains(where: { $0.caseInsensitiveCompare(selectedSubCategoryName) == .orderedSame })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(isAr ? "بيانات ملخصة بس. مش بتغيّر أرصدة الحسابات ومش بتعمل حركات." : "Summary-only historical data. This does not change account balances and does not create transactions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(isAr ? "التصنيف" : "Category") {
                    CategorySubcategoryPickerView(
                        categoryName: $selectedCategoryName,
                        subCategoryName: $selectedSubCategoryName
                    )
                }

                Section(isAr ? "المبلغ" : "Amount") {
                    TextField(isAr ? "المبلغ" : "Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                Section(isAr ? "ملاحظات" : "Note") {
                    TextField(isAr ? "ملاحظة اختيارية" : "Optional note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let entry {
                    Section {
                        Button(role: .destructive) {
                            store.deleteHistoricalMonthlySummary(entry)
                            dismiss()
                        } label: {
                            Text(isAr ? "حذف الإدخال" : "Delete Entry")
                        }
                    }
                }
            }
            .navigationTitle(entry == nil ? (isAr ? "أضف إدخال ملخص" : "Add Summary Entry") : (isAr ? "تعديل إدخال ملخص" : "Edit Summary Entry"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isAr ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isAr ? "حفظ" : "Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                applyDefaultCategoryIfNeeded()
            }
            .onChange(of: selectedCategoryName) { _, _ in
                applyDefaultSubcategoryIfNeeded()
            }
        }
    }

    private func applyDefaultCategoryIfNeeded() {
        guard selectedCategoryName.isEmpty,
              let category = activeCategories.first else {
            applyDefaultSubcategoryIfNeeded()
            return
        }

        selectedCategoryName = category.name
        applyDefaultSubcategoryIfNeeded()
    }

    private func applyDefaultSubcategoryIfNeeded() {
        guard !subcategories.isEmpty,
              !subcategories.contains(where: { $0.caseInsensitiveCompare(selectedSubCategoryName) == .orderedSame }) else {
            return
        }

        selectedSubCategoryName = subcategories[0]
    }

    private func save() {
        if let entry {
            store.updateHistoricalMonthlySummary(
                entryID: entry.id,
                categoryName: selectedCategoryName,
                subCategoryName: selectedSubCategoryName,
                amount: amountValue,
                note: note
            )
        } else {
            store.addHistoricalMonthlySummary(
                year: year,
                month: month,
                categoryName: selectedCategoryName,
                subCategoryName: selectedSubCategoryName,
                amount: amountValue,
                note: note
            )
        }

        dismiss()
    }

    private static func cleanNumberText(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return "\(amount)"
    }
}
