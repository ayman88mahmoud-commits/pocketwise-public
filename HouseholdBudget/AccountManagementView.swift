import SwiftUI

struct AccountManagementView: View {

    @EnvironmentObject private var store: WalletStore
    let requestUserInitiatedSync: () async -> Void

    @State private var isAddingAccount = false
    @State private var selectedAccount: Account?

    init(requestUserInitiatedSync: @escaping () async -> Void = {}) {
        self.requestUserInitiatedSync = requestUserInitiatedSync
    }

    private var sortedAccounts: [Account] {
        store.activeAccounts.sorted {
            if $0.isActive == $1.isActive {
                return $0.name < $1.name
            }

            return $0.isActive && !$1.isActive
        }
    }

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    var body: some View {
        NavigationStack {
            List {
                Section(isArabic ? "الحسابات" : "Accounts") {
                    ForEach(sortedAccounts) { account in
                        Button {
                            selectedAccount = account
                        } label: {
                            ManagedAccountRow(account: account)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(isArabic ? "إدارة الحسابات" : "Manage Accounts")
            .refreshable {
                await requestUserInitiatedSync()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isAddingAccount = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(isArabic ? "أضف حساب" : "Add Account")
                }
            }
            .sheet(isPresented: $isAddingAccount) {
                AccountEditorView(mode: .add)
                    .environmentObject(store)
            }
            .sheet(item: $selectedAccount) { account in
                AccountEditorView(mode: .edit(account))
                    .environmentObject(store)
            }
        }
    }
}

struct ManagedAccountRow: View {

    @EnvironmentObject private var store: WalletStore

    let account: Account

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    var body: some View {
        HStack(spacing: 12) {
            AccountVisualMark(account: account, size: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(account.name)
                        .font(.headline)

                    if !account.isActive {
                        Text(isArabic ? "غير نشط" : "Inactive")
                            .pocketWiseChip(semanticColor: .neutral, isSelected: false)
                    }
                }

                Text(accountTypeLabel(account.type))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(account.balance))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(PocketWiseSemanticColor.accounts.tint)

                Text(isArabic ? "اضغط للتعديل" : "Tap to edit")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ amount: Double) -> String {
        store.displayCurrency(amount, maximumFractionDigits: 2)
    }

    private func accountTypeLabel(_ accountType: AccountType) -> String {
        guard isArabic else {
            return accountType.rawValue
        }

        switch accountType {
        case .cash:
            return "كاش"
        case .bank:
            return "بنك"
        case .wallet:
            return "محفظة"
        }
    }
}

struct AccountEditorView: View {

    enum Mode {
        case add
        case edit(Account)
    }

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var name: String = ""
    @State private var type: AccountType = .bank
    @State private var balanceText: String = ""
    @State private var smsMatchingEndings: [String] = []
    @State private var newSMSEnding: String = ""
    @State private var appearanceColor: ProviderAppearanceColor?
    @State private var isActive = true
    @State private var showDeactivateConfirmation = false
    @State private var showDeleteConfirmation = false

    private var editingAccount: Account? {
        if case .edit(let account) = mode {
            return account
        }

        return nil
    }

    private var title: String {
        editingAccount == nil ? (isArabic ? "أضف حساب" : "Add Account") : (isArabic ? "تعديل حساب" : "Edit Account")
    }

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(isArabic ? "الحساب" : "Account") {
                    TextField(isArabic ? "اسم الحساب" : "Account name", text: $name)
                        .pocketWiseInputField(semanticColor: .accounts)

                    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        validationMessage(isArabic ? "دخل اسم الحساب." : "Enter an account name.")
                    }

                    if isDuplicateName {
                        validationMessage(isArabic ? "اسم الحساب موجود بالفعل." : "Account name already exists.")
                    }

                    Picker(isArabic ? "النوع" : "Type", selection: $type) {
                        ForEach(AccountType.allCases) { accountType in
                            Text(accountTypeLabel(accountType))
                                .tag(accountType)
                        }
                    }
                    .pocketWiseInputField(semanticColor: .accounts)

                    TextField(isArabic ? "الرصيد" : "Balance", text: $balanceText)
                        .keyboardType(.decimalPad)
                        .pocketWiseInputField(semanticColor: .accounts, isProminent: true)

                    if balanceValue == nil || (balanceValue ?? 0) < 0 {
                        validationMessage(isArabic ? "دخل رصيد صحيح." : "Enter a valid balance.")
                    }
                }

                Section(isArabic ? "الشكل" : "Appearance") {
                    HStack(spacing: 12) {
                        AccountVisualMark(
                            account: Account(
                                name: name.isEmpty ? (isArabic ? "حساب" : "Account") : name,
                                balance: 0,
                                type: type,
                                appearanceColor: appearanceColor ?? defaultAppearanceColor
                            ),
                            size: 38
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(isArabic ? "علامة حساب عامة" : "Generic provider badge")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(isArabic ? "بيستخدم أيقونة ولون آمنين بدل شعارات خارجية." : "Uses a safe icon and color instead of third-party logos.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ProviderAppearanceColorPicker(
                        title: isArabic ? "اللون" : "Color",
                        selection: $appearanceColor,
                        defaultColor: defaultAppearanceColor
                    )
                }

                Section(isArabic ? "آخر ٤ أرقام لمطابقة إشعارات البنك" : "Bank Notification Matching Last 4 Digits") {
                    HStack {
                        TextField(isArabic ? "أضف آخر الأرقام" : "Add ending", text: $newSMSEnding)
                            .keyboardType(.numberPad)
                            .pocketWiseInputField(semanticColor: .accounts)
                            .onChange(of: newSMSEnding) { _, newValue in
                                newSMSEnding = String(newValue.filter(\.isNumber).prefix(4))
                            }

                        Button(isArabic ? "إضافة" : "Add") {
                            addSMSEnding()
                        }
                        .disabled(!canAddSMSEnding)
                    }

                    if !smsMatchingEndings.isEmpty {
                        ForEach(smsMatchingEndings, id: \.self) { ending in
                            HStack {
                                Text(ending)
                                    .font(.body.monospacedDigit())
                                Spacer()
                                Button(role: .destructive) {
                                    removeSMSEnding(ending)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Text(isArabic ? "أضف آخر ٤ أرقام الظاهرة في إشعارات البنك للحساب ده، بما فيها كروت الخصم المرتبطة. ما تدخلش رقم حساب أو كارت كامل." : "Add the last 4 digits shown in bank notification messages for this account, including linked debit cards. Do not enter full account or card numbers.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !newSMSEnding.isEmpty && newSMSEnding.count != 4 {
                        validationMessage(isArabic ? "كل نهاية لازم تكون ٤ أرقام بالضبط." : "Each ending must be exactly 4 digits.")
                    }

                    if smsMatchingEndings.count != Set(smsMatchingEndings).count {
                        validationMessage(isArabic ? "نهايات مطابقة الرسائل لازم تكون غير مكررة للحساب ده." : "SMS matching endings must be unique for this account.")
                    }
                }

                if editingAccount != nil {
                    Section(isArabic ? "الحالة" : "Status") {
                        Toggle(isArabic ? "نشط" : "Active", isOn: $isActive)

                        Text(isArabic ? "الحسابات غير النشطة بتختفي من اختيارات الحركات الجديدة، لكن الحركات القديمة بتفضل تعرض حسابها الأصلي." : "Inactive accounts are hidden from new transaction pickers, but old transactions keep showing their original account.")
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
                            Text(isArabic ? "حفظ الحساب" : "Save Account")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!canSave)
                }

                if let editingAccount {
                    Section(isArabic ? "إزالة الحساب" : "Remove Account") {
                        if editingAccount.isActive {
                            Button(role: .destructive) {
                                showDeactivateConfirmation = true
                            } label: {
                                Text(isArabic ? "إلغاء تنشيط الحساب" : "Deactivate Account")
                            }
                        } else {
                            Button {
                                store.activateAccount(editingAccount)
                                dismiss()
                            } label: {
                                Text(isArabic ? "إعادة تنشيط الحساب" : "Reactivate Account")
                            }
                        }

                        if store.accountHasTransactions(editingAccount) {
                            Text(isArabic ? "الحساب ده عليه حركات، فمش ممكن يتحذف. الغي تنشيطه بدل الحذف." : "This account has transactions, so it cannot be deleted. Deactivate it instead.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Text(isArabic ? "حذف الحساب" : "Delete Account")
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
                isArabic ? "تلغي تنشيط الحساب ده؟" : "Deactivate this account?",
                isPresented: $showDeactivateConfirmation,
                titleVisibility: .visible
            ) {
                Button(isArabic ? "إلغاء تنشيط الحساب" : "Deactivate Account", role: .destructive) {
                    if let editingAccount {
                        store.deactivateAccount(editingAccount)
                    }
                    dismiss()
                }

                Button(isArabic ? "إلغاء" : "Cancel", role: .cancel) { }
            } message: {
                Text(isArabic ? "هيختفي من اختيارات الحركات الجديدة. الحركات الموجودة هتفضل تعرض الحساب ده." : "It will be hidden from new transaction pickers. Existing transactions will still show this account.")
            }
            .confirmationDialog(
                isArabic ? "تحذف الحساب ده؟" : "Delete this account?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(isArabic ? "حذف الحساب" : "Delete Account", role: .destructive) {
                    if let editingAccount {
                        store.deleteAccountIfUnused(editingAccount)
                    }
                    dismiss()
                }

                Button(isArabic ? "إلغاء" : "Cancel", role: .cancel) { }
            } message: {
                Text(isArabic ? "الحسابات غير المستخدمة فقط هي اللي ممكن تتحذف." : "Only unused accounts can be deleted.")
            }
        }
    }

    private var balanceValue: Double? {
        Double(balanceText.replacingOccurrences(of: ",", with: "."))
    }

    private var isDuplicateName: Bool {
        store.accountNameExists(
            name,
            excluding: editingAccount?.id
        )
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isDuplicateName &&
        (balanceValue ?? -1) >= 0 &&
        smsMatchingEndingsAreValid
    }

    private var smsMatchingEndingsAreValid: Bool {
        smsMatchingEndings.allSatisfy { $0.count == 4 && $0.allSatisfy(\.isNumber) } &&
        smsMatchingEndings.count == Set(smsMatchingEndings).count
    }

    private var canAddSMSEnding: Bool {
        newSMSEnding.count == 4 &&
        newSMSEnding.allSatisfy(\.isNumber) &&
        !smsMatchingEndings.contains(newSMSEnding)
    }

    private func setupInitialValues() {
        guard let account = editingAccount else {
            balanceText = "0"
            return
        }

        name = account.name
        type = account.type
        balanceText = cleanNumberText(account.balance)
        smsMatchingEndings = account.recognitionCardEndings
        appearanceColor = account.appearanceColor
        isActive = account.isActive
    }

    private func save() {
        guard let balanceValue else {
            return
        }

        if let account = editingAccount {
            store.updateAccount(
                accountID: account.id,
                name: name,
                type: type,
                balance: balanceValue,
                isActive: isActive,
                recognitionCardEndings: smsMatchingEndings,
                appearanceColor: appearanceColor ?? defaultAppearanceColor
            )
        } else {
            store.addAccount(
                name: name,
                type: type,
                balance: balanceValue,
                recognitionCardEndings: smsMatchingEndings,
                appearanceColor: appearanceColor ?? defaultAppearanceColor
            )
        }

        dismiss()
    }

    private func addSMSEnding() {
        guard canAddSMSEnding else {
            return
        }

        smsMatchingEndings.append(newSMSEnding)
        smsMatchingEndings.sort()
        newSMSEnding = ""
    }

    private func removeSMSEnding(_ ending: String) {
        smsMatchingEndings.removeAll { $0 == ending }
    }

    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
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

    private func accountTypeLabel(_ accountType: AccountType) -> String {
        guard isArabic else {
            return accountType.rawValue
        }

        switch accountType {
        case .cash:
            return "كاش"
        case .bank:
            return "بنك"
        case .wallet:
            return "محفظة"
        }
    }

    private func cleanNumberText(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(amount))"
        }

        return "\(amount)"
    }

}

struct AccountManagementView_Previews: PreviewProvider {
    static var previews: some View {
        AccountManagementView()
            .environmentObject(WalletStore())
    }
}
