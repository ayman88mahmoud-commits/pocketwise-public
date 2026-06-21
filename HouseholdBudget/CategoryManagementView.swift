import SwiftUI

struct CategoryManagementView: View {

    @EnvironmentObject private var store: WalletStore

    @State private var isAddingCategory = false
    @State private var selectedCategory: Category?

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var sortedCategories: [Category] {
        store.categories.sorted {
            if $0.isActive == $1.isActive {
                return $0.name < $1.name
            }

            return $0.isActive && !$1.isActive
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(isArabic ? "التصنيفات" : "Categories") {
                    ForEach(sortedCategories) { category in
                        NavigationLink {
                            CategoryDetailManagementView(categoryID: category.id)
                                .environmentObject(store)
                        } label: {
                            ManagedCategoryRow(category: category)
                                .environmentObject(store)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                selectedCategory = category
                            } label: {
                                Label(isArabic ? "تعديل" : "Edit", systemImage: "pencil")
                            }
                        }
                    }
                }
            }
            .navigationTitle(isArabic ? "إدارة التصنيفات" : "Manage Categories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isAddingCategory = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(isArabic ? "أضف تصنيف" : "Add Category")
                }
            }
            .sheet(isPresented: $isAddingCategory) {
                CategoryEditorView(mode: .add)
                    .environmentObject(store)
            }
            .sheet(item: $selectedCategory) { category in
                CategoryEditorView(mode: .edit(category))
                    .environmentObject(store)
            }
        }
    }
}

struct ManagedCategoryRow: View {

    @EnvironmentObject private var store: WalletStore

    let category: Category

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    var body: some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(
                systemName: "tag.fill",
                semanticColor: .categories,
                size: 36,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(AppText.categoryDisplayName(category.name, language: store.appLanguage))
                        .font(.headline)

                    if !category.isActive {
                        statusChip(isArabic ? "غير نشط" : "Inactive")
                    }
                }

                Text(isArabic
                    ? "\(activeSubcategoryCount) نشط من \(category.subcategories.count) تصنيف فرعي"
                    : "\(activeSubcategoryCount) active of \(category.subcategories.count) subcategories"
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var activeSubcategoryCount: Int {
        category.subcategories.filter { subcategory in
            !category.inactiveSubcategoryNames.contains { inactiveName in
                inactiveName.caseInsensitiveCompare(subcategory) == .orderedSame
            }
        }.count
    }

    private func statusChip(_ text: String) -> some View {
        Text(text)
            .pocketWiseChip(semanticColor: .neutral, isSelected: false)
    }
}

struct CategoryDetailManagementView: View {

    @EnvironmentObject private var store: WalletStore

    let categoryID: UUID

    @State private var isAddingSubcategory = false
    @State private var isEditingCategory = false
    @State private var selectedSubcategoryName: String?

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var category: Category? {
        store.categories.first { $0.id == categoryID }
    }

    private var sortedSubcategories: [String] {
        guard let category else {
            return []
        }

        return category.subcategories.sorted {
            let firstActive = store.isSubcategoryActive($0, in: category.name)
            let secondActive = store.isSubcategoryActive($1, in: category.name)

            if firstActive == secondActive {
                return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }

            return firstActive && !secondActive
        }
    }

    var body: some View {
        List {
            if let category {
                Section(isArabic ? "التصنيف" : "Category") {
                    Button {
                        isEditingCategory = true
                    } label: {
                        ManagedCategoryRow(category: category)
                            .environmentObject(store)
                    }
                    .buttonStyle(.plain)
                }

                Section(isArabic ? "التصنيفات الفرعية" : "Subcategories") {
                    if sortedSubcategories.isEmpty {
                        Text(isArabic ? "لسه مفيش تصنيفات فرعية" : "No subcategories yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedSubcategories, id: \.self) { subcategory in
                            Button {
                                selectedSubcategoryName = subcategory
                            } label: {
                                ManagedSubcategoryRow(
                                    name: subcategory,
                                    categoryName: category.name,
                                    isActive: store.isSubcategoryActive(subcategory, in: category.name),
                                    isUsed: store.subcategoryHasReferences(subcategory, in: category)
                                )
                                .environmentObject(store)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Section {
                    Text(isArabic ? "التصنيف غير موجود" : "Category not found")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(category.map { AppText.categoryDisplayName($0.name, language: store.appLanguage) } ?? (isArabic ? "التصنيف" : "Category"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isAddingSubcategory = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(isArabic ? "أضف تصنيف فرعي" : "Add Subcategory")
                .disabled(category == nil)
            }
        }
        .sheet(isPresented: $isAddingSubcategory) {
            if let category {
                SubcategoryEditorView(mode: .add(category))
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: $isEditingCategory) {
            if let category {
                CategoryEditorView(mode: .edit(category))
                    .environmentObject(store)
            }
        }
        .sheet(isPresented: isEditingSubcategory) {
            if let category,
               let subcategoryName = selectedSubcategoryName {
                SubcategoryEditorView(mode: .edit(category, subcategoryName))
                    .environmentObject(store)
            }
        }
    }

    private var isEditingSubcategory: Binding<Bool> {
        Binding(
            get: { selectedSubcategoryName != nil },
            set: { isPresented in
                if !isPresented {
                    selectedSubcategoryName = nil
                }
            }
        )
    }
}

struct ManagedSubcategoryRow: View {

    @EnvironmentObject private var store: WalletStore

    let name: String
    let categoryName: String
    let isActive: Bool
    let isUsed: Bool

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    var body: some View {
        HStack(spacing: 12) {
            PocketWiseIconBadge(
                systemName: "tag",
                semanticColor: .categories,
                size: 34,
                cornerRadius: 10
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(AppText.subcategoryDisplayName(name, language: store.appLanguage))
                        .font(.headline)

                    if !isActive {
                        chip(isArabic ? "غير نشط" : "Inactive")
                    }
                }

                if isArabic, AppText.subcategoryDisplayName(name, language: store.appLanguage) != name {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(isUsed ? (isArabic ? "مستخدم في بيانات محفوظة" : "Used by saved data") : (isArabic ? "غير مستخدم" : "Unused"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .pocketWiseChip(semanticColor: .neutral, isSelected: false)
    }
}

struct CategoryEditorView: View {

    enum Mode {
        case add
        case edit(Category)
    }

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var name = ""
    @State private var isActive = true
    @State private var showDeactivateConfirmation = false
    @State private var showDeleteConfirmation = false

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var editingCategory: Category? {
        if case .edit(let category) = mode {
            return category
        }

        return nil
    }

    private var title: String {
        editingCategory == nil
            ? (isArabic ? "أضف تصنيف" : "Add Category")
            : (isArabic ? "تعديل تصنيف" : "Edit Category")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(isArabic ? "التصنيف" : "Category") {
                    TextField(isArabic ? "اسم التصنيف" : "Category name", text: $name)
                        .pocketWiseInputField(semanticColor: .categories)

                    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        validationMessage(isArabic ? "اكتب اسم التصنيف." : "Enter a category name.")
                    }

                    if isDuplicateName {
                        validationMessage(isArabic ? "اسم التصنيف موجود بالفعل." : "Category name already exists.")
                    }
                }

                if editingCategory != nil {
                    Section(isArabic ? "الحالة" : "Status") {
                        Toggle(isArabic ? "نشط" : "Active", isOn: $isActive)

                        Text(isArabic ? "التصنيفات غير النشطة بتختفي من اختيارات المعاملات الجديدة. المعاملات القديمة بتفضل محتفظة بتصنيفها الأصلي." : "Inactive categories are hidden from new transaction pickers. Existing transactions keep showing their original category.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isArabic ? "حفظ التصنيف" : "Save Category")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }

                if let editingCategory {
                    Section(isArabic ? "منطقة حساسة" : "Danger Zone") {
                        if editingCategory.isActive {
                            Button(role: .destructive) {
                                showDeactivateConfirmation = true
                            } label: {
                                Text(isArabic ? "تعطيل التصنيف" : "Deactivate Category")
                            }
                        } else {
                            Button {
                                store.activateCategory(editingCategory)
                                dismiss()
                            } label: {
                                Text(isArabic ? "إعادة تفعيل التصنيف" : "Reactivate Category")
                            }
                        }

                        if store.categoryHasReferences(editingCategory) {
                            Text(isArabic ? "التصنيف ده مستخدم في بيانات محفوظة، فمش ممكن يتم حذفه. عطّله بدل الحذف." : "This category is used by saved data, so it cannot be deleted. Deactivate it instead.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Text(isArabic ? "حذف التصنيف" : "Delete Category")
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isArabic ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupInitialValues()
            }
            .confirmationDialog(
                isArabic ? "تعطيل التصنيف؟" : "Deactivate this category?",
                isPresented: $showDeactivateConfirmation,
                titleVisibility: .visible
            ) {
                Button(isArabic ? "تعطيل التصنيف" : "Deactivate Category", role: .destructive) {
                    if let editingCategory {
                        store.deactivateCategory(editingCategory)
                    }
                    dismiss()
                }

                Button(isArabic ? "إلغاء" : "Cancel", role: .cancel) { }
            } message: {
                Text(isArabic ? "هيختفي من اختيارات المعاملات الجديدة. المعاملات القديمة هتفضل تعرض التصنيف ده." : "It will be hidden from new transaction pickers. Existing transactions will still show this category.")
            }
            .confirmationDialog(
                isArabic ? "حذف التصنيف؟" : "Delete this category?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(isArabic ? "حذف التصنيف" : "Delete Category", role: .destructive) {
                    if let editingCategory {
                        store.deleteCategoryIfUnused(editingCategory)
                    }
                    dismiss()
                }

                Button(isArabic ? "إلغاء" : "Cancel", role: .cancel) { }
            } message: {
                Text(isArabic ? "الحذف متاح للتصنيفات غير المستخدمة فقط." : "Only unused categories can be deleted.")
            }
        }
    }

    private var isDuplicateName: Bool {
        store.categoryNameExists(
            name,
            excluding: editingCategory?.id
        )
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isDuplicateName
    }

    private func setupInitialValues() {
        guard let category = editingCategory else {
            return
        }

        name = category.name
        isActive = category.isActive
    }

    private func save() {
        if let category = editingCategory {
            store.updateCategory(
                categoryID: category.id,
                name: name,
                isActive: isActive
            )
        } else {
            store.addCategory(name: name)
        }

        dismiss()
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
    }
}

struct SubcategoryEditorView: View {

    enum Mode {
        case add(Category)
        case edit(Category, String)
    }

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var name = ""
    @State private var isActive = true
    @State private var showDeactivateConfirmation = false
    @State private var showDeleteConfirmation = false

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var category: Category {
        switch mode {
        case .add(let category), .edit(let category, _):
            return category
        }
    }

    private var editingSubcategoryName: String? {
        if case .edit(_, let subcategoryName) = mode {
            return subcategoryName
        }

        return nil
    }

    private var title: String {
        editingSubcategoryName == nil
            ? (isArabic ? "أضف تصنيف فرعي" : "Add Subcategory")
            : (isArabic ? "تعديل تصنيف فرعي" : "Edit Subcategory")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(isArabic ? "التصنيف الفرعي" : "Subcategory") {
                    TextField(isArabic ? "اسم التصنيف الفرعي" : "Subcategory name", text: $name)
                        .pocketWiseInputField(semanticColor: .categories)

                    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        validationMessage(isArabic ? "اكتب اسم التصنيف الفرعي." : "Enter a subcategory name.")
                    }

                    if isDuplicateName {
                        validationMessage(isArabic ? "اسم التصنيف الفرعي موجود بالفعل في التصنيف ده." : "Subcategory name already exists in this category.")
                    }
                }

                if editingSubcategoryName != nil {
                    Section(isArabic ? "الحالة" : "Status") {
                        Toggle(isArabic ? "نشط" : "Active", isOn: $isActive)

                        Text(isArabic ? "التصنيفات الفرعية غير النشطة بتختفي من اختيارات المعاملات الجديدة. المعاملات القديمة بتفضل محتفظة بالتصنيف الفرعي الأصلي." : "Inactive subcategories are hidden from new transaction pickers. Existing transactions keep showing their original subcategory.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isArabic ? "حفظ التصنيف الفرعي" : "Save Subcategory")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }

                if let editingSubcategoryName {
                    Section(isArabic ? "منطقة حساسة" : "Danger Zone") {
                        if isActive {
                            Button(role: .destructive) {
                                showDeactivateConfirmation = true
                            } label: {
                                Text(isArabic ? "تعطيل التصنيف الفرعي" : "Deactivate Subcategory")
                            }
                        } else {
                            Button {
                                store.activateSubcategory(editingSubcategoryName, in: category)
                                dismiss()
                            } label: {
                                Text(isArabic ? "إعادة تفعيل التصنيف الفرعي" : "Reactivate Subcategory")
                            }
                        }

                        if store.subcategoryHasReferences(editingSubcategoryName, in: category) {
                            Text(isArabic ? "التصنيف الفرعي ده مستخدم في بيانات محفوظة، فمش ممكن يتم حذفه. عطّله بدل الحذف." : "This subcategory is used by saved data, so it cannot be deleted. Deactivate it instead.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Text(isArabic ? "حذف التصنيف الفرعي" : "Delete Subcategory")
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isArabic ? "إلغاء" : "Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupInitialValues()
            }
            .confirmationDialog(
                isArabic ? "تعطيل التصنيف الفرعي؟" : "Deactivate this subcategory?",
                isPresented: $showDeactivateConfirmation,
                titleVisibility: .visible
            ) {
                Button(isArabic ? "تعطيل التصنيف الفرعي" : "Deactivate Subcategory", role: .destructive) {
                    if let editingSubcategoryName {
                        store.deactivateSubcategory(editingSubcategoryName, in: category)
                    }
                    dismiss()
                }

                Button(isArabic ? "إلغاء" : "Cancel", role: .cancel) { }
            } message: {
                Text(isArabic ? "هيختفي من اختيارات المعاملات الجديدة. المعاملات القديمة هتفضل تعرض التصنيف الفرعي ده." : "It will be hidden from new transaction pickers. Existing transactions will still show this subcategory.")
            }
            .confirmationDialog(
                isArabic ? "حذف التصنيف الفرعي؟" : "Delete this subcategory?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(isArabic ? "حذف التصنيف الفرعي" : "Delete Subcategory", role: .destructive) {
                    if let editingSubcategoryName {
                        store.deleteSubcategoryIfUnused(editingSubcategoryName, in: category)
                    }
                    dismiss()
                }

                Button(isArabic ? "إلغاء" : "Cancel", role: .cancel) { }
            } message: {
                Text(isArabic ? "الحذف متاح للتصنيفات الفرعية غير المستخدمة فقط." : "Only unused subcategories can be deleted.")
            }
        }
    }

    private var isDuplicateName: Bool {
        store.subcategoryNameExists(
            name,
            in: category.id,
            excluding: editingSubcategoryName
        )
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isDuplicateName
    }

    private func setupInitialValues() {
        guard let editingSubcategoryName else {
            return
        }

        name = editingSubcategoryName
        isActive = store.isSubcategoryActive(editingSubcategoryName, in: category.name)
    }

    private func save() {
        if let editingSubcategoryName {
            store.updateSubcategory(
                in: category.id,
                oldName: editingSubcategoryName,
                newName: name,
                isActive: isActive
            )
        } else {
            store.addSubcategory(name, to: category.name)
        }

        dismiss()
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
    }
}

struct CategoryManagementView_Previews: PreviewProvider {
    static var previews: some View {
        CategoryManagementView()
            .environmentObject(WalletStore())
    }
}
