import SwiftUI

struct MerchantMemoryView: View {

    @EnvironmentObject private var store: WalletStore

    @State private var isAddingMemory = false
    @State private var editingMemory: MerchantMemory?

    private var memories: [MerchantMemory] {
        store.activeMerchantMemories.sorted {
            $0.merchantName.localizedCaseInsensitiveCompare($1.merchantName) == .orderedAscending
        }
    }

    var body: some View {
        List {
            Section {
                Text(store.appLanguage == .arabicEgyptian ? "احفظ التجار والاختصارات عشان الإضافة اليدوية تبقى أذكى بعدين. ده مش AI ومش بيغير حركات قديمة." : "Save merchants and aliases as a foundation for smarter manual entry later. This is not AI and does not change old transactions.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(store.appLanguage == .arabicEgyptian ? "التجار والاختصارات" : "Merchants & Aliases") {
                if memories.isEmpty {
                    Text(store.appLanguage == .arabicEgyptian ? "لسه مفيش تجار محفوظين." : "No merchant memories yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(memories) { memory in
                        Button {
                            editingMemory = memory
                        } label: {
                            merchantRow(memory)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                store.deleteMerchantMemory(memory)
                            } label: {
                                Label(store.appLanguage == .arabicEgyptian ? "حذف" : "Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "التجار" : "Merchant Memory")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isAddingMemory = true
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "أضف" : "Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingMemory) {
            MerchantMemoryEditorView(memory: nil)
                .environmentObject(store)
        }
        .sheet(item: $editingMemory) { memory in
            MerchantMemoryEditorView(memory: memory)
                .environmentObject(store)
        }
    }

    private func merchantRow(_ memory: MerchantMemory) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(memory.merchantName)
                    .font(.headline)

                Spacer()

                Text(memory.isActive ? (store.appLanguage == .arabicEgyptian ? "نشط" : "Active") : (store.appLanguage == .arabicEgyptian ? "متوقف" : "Inactive"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(memory.defaultCategoryName) • \(memory.defaultSubCategoryName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !memory.aliases.isEmpty {
                Text(memory.aliases.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MerchantMemoryEditorView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let memory: MerchantMemory?

    @State private var merchantName: String
    @State private var aliasesText: String
    @State private var selectedCategoryName: String
    @State private var selectedSubCategoryName: String
    @State private var selectedAccountName: String
    @State private var defaultType: FinancialEventType
    @State private var isActive: Bool

    init(memory: MerchantMemory?) {
        self.memory = memory
        _merchantName = State(initialValue: memory?.merchantName ?? "")
        _aliasesText = State(initialValue: memory?.aliases.joined(separator: ", ") ?? "")
        _selectedCategoryName = State(initialValue: memory?.defaultCategoryName ?? "")
        _selectedSubCategoryName = State(initialValue: memory?.defaultSubCategoryName ?? "")
        _selectedAccountName = State(initialValue: memory?.defaultAccountName ?? "")
        _defaultType = State(initialValue: memory?.defaultType ?? .expense)
        _isActive = State(initialValue: memory?.isActive ?? true)
    }

    private var categories: [Category] {
        store.activeCategories.filter { $0.isActive || $0.name == memory?.defaultCategoryName }
    }

    private var subcategories: [String] {
        store.subcategoriesForEditing(
            categoryName: selectedCategoryName,
            selectedSubcategoryName: selectedSubCategoryName
        )
    }

    private var aliases: [String] {
        aliasesText
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !merchantName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        categories.contains(where: { $0.name == selectedCategoryName }) &&
        subcategories.contains(selectedSubCategoryName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(store.appLanguage == .arabicEgyptian ? "التاجر" : "Merchant") {
                    TextField(store.appLanguage == .arabicEgyptian ? "الاسم" : "Name", text: $merchantName)
                    TextField(store.appLanguage == .arabicEgyptian ? "أسماء بديلة" : "Aliases", text: $aliasesText)
                    Toggle(store.appLanguage == .arabicEgyptian ? "نشط" : "Active", isOn: $isActive)
                }

                Section(store.appLanguage == .arabicEgyptian ? "الافتراضي" : "Defaults") {
                    CategorySubcategoryPickerView(
                        categoryName: $selectedCategoryName,
                        subCategoryName: $selectedSubCategoryName,
                        title: store.appLanguage == .arabicEgyptian ? "التصنيف الافتراضي" : "Default Category",
                        categoryValidationMessage: store.appLanguage == .arabicEgyptian ? "اختر التصنيف الافتراضي" : "Choose a default category.",
                        subcategoryValidationMessage: store.appLanguage == .arabicEgyptian ? "اختر التصنيف الفرعي" : "Choose a subcategory."
                    )

                    AccountMenuPickerField(
                        title: store.appLanguage == .arabicEgyptian ? "الحساب الافتراضي" : "Default Account",
                        selection: $selectedAccountName,
                        accounts: store.activeAccounts.filter { $0.isActive },
                        placeholder: store.appLanguage == .arabicEgyptian ? "بدون" : "None",
                        emptyTitle: store.appLanguage == .arabicEgyptian ? "بدون" : "None"
                    )

                    Picker(store.appLanguage == .arabicEgyptian ? "النوع" : "Type", selection: $defaultType) {
                        Text(store.appLanguage == .arabicEgyptian ? "مصروف" : "Expense").tag(FinancialEventType.expense)
                        Text(store.appLanguage == .arabicEgyptian ? "مصروف متوقع" : "Expected Expense").tag(FinancialEventType.expectedExpense)
                        Text(store.appLanguage == .arabicEgyptian ? "التزام" : "Obligation").tag(FinancialEventType.obligation)
                    }
                }

                if let memory {
                    Section {
                        Button(role: .destructive) {
                            store.deleteMerchantMemory(memory)
                            dismiss()
                        } label: {
                            Text(store.appLanguage == .arabicEgyptian ? "حذف التاجر" : "Delete Merchant")
                        }
                    }
                }
            }
            .navigationTitle(memory == nil ? (store.appLanguage == .arabicEgyptian ? "أضف تاجر" : "Add Merchant") : (store.appLanguage == .arabicEgyptian ? "تعديل تاجر" : "Edit Merchant"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(store.appLanguage == .arabicEgyptian ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.appLanguage == .arabicEgyptian ? "حفظ" : "Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                applyDefaultsIfNeeded()
            }
            .onChange(of: selectedCategoryName) { _, _ in
                applySubcategoryIfNeeded()
            }
        }
    }

    private func applyDefaultsIfNeeded() {
        if selectedCategoryName.isEmpty {
            selectedCategoryName = categories.first?.name ?? ""
        }

        applySubcategoryIfNeeded()
    }

    private func applySubcategoryIfNeeded() {
        guard !subcategories.isEmpty,
              !subcategories.contains(selectedSubCategoryName) else {
            return
        }

        selectedSubCategoryName = subcategories[0]
    }

    private func save() {
        if var memory {
            memory.merchantName = merchantName
            memory.aliases = aliases
            memory.defaultCategoryName = selectedCategoryName
            memory.defaultSubCategoryName = selectedSubCategoryName
            memory.defaultAccountName = selectedAccountName.isEmpty ? nil : selectedAccountName
            memory.defaultType = defaultType
            memory.isActive = isActive
            store.updateMerchantMemory(memory)
        } else {
            store.addMerchantMemory(
                merchantName: merchantName,
                aliases: aliases,
                defaultCategoryName: selectedCategoryName,
                defaultSubCategoryName: selectedSubCategoryName,
                defaultAccountName: selectedAccountName.isEmpty ? nil : selectedAccountName,
                defaultType: defaultType
            )
        }

        dismiss()
    }
}
