import SwiftUI
import UniformTypeIdentifiers

struct DataBackupView: View {

    @EnvironmentObject private var store: WalletStore

    @State private var backupDocument = WalletBackupDocument(data: Data())
    @State private var backupFileName = "PocketWiseBackup.json"
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingImportData: Data?
    @State private var pendingRestorePreview: BackupRestorePreview?

    var body: some View {
        List {
            Section(store.appLanguage == .arabicEgyptian ? "نسخة احتياطية يدوية" : "Manual backup") {
                HStack(alignment: .top, spacing: 12) {
                    PocketWiseIconBadge(
                        systemName: "externaldrive.fill",
                        semanticColor: .backupPrivacy,
                        size: 40,
                        cornerRadius: 12
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.appLanguage == .arabicEgyptian ? "التصدير بيعمل ملف نسخة كاملة من بيانات المحفظة." : "Export creates a full backup file of your wallet data.")
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Text(store.appLanguage == .arabicEgyptian ? "الاستيراد يفتح معاينة أولًا، ثم يستبدل بيانات التطبيق بعد تأكيد الاستعادة." : "Import opens a review first, then restores and replaces current app data after confirmation.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(store.appLanguage == .arabicEgyptian ? "احفظ النسخة في مكان آمن، مثل Files أو iCloud Drive." : "Save your backup somewhere safe, such as Files or iCloud Drive.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Text(store.appLanguage == .arabicEgyptian ? "اختار مجلد آمن يدويًا وقت الحفظ. الاستيراد يقبل ملفات JSON المتوافقة، بما فيها النسخ القديمة." : "Choose a safe folder manually when saving. Import accepts compatible JSON backup files, including older exports.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                Button {
                    exportBackup()
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "صدّر ملف نسخة احتياطية" : "Export Backup File", systemImage: "square.and.arrow.up")
                }
                .tint(PocketWiseSemanticColor.backupPrivacy.tint)

                Button {
                    isImporting = true
                } label: {
                    Label(store.appLanguage == .arabicEgyptian ? "استورد ملف للمراجعة" : "Import Backup File to Review", systemImage: "square.and.arrow.down")
                }
                .tint(PocketWiseSemanticColor.backupPrivacy.tint)
            }

            Section(store.appLanguage == .arabicEgyptian ? "محتويات النسخة" : "Included data") {
                backupDetailRow("Accounts", store.accounts.count)
                backupDetailRow("Categories", store.categories.count)
                backupDetailRow("Quick Events", store.walletEvents.count)
                backupDetailRow("Financial Events", store.financialEvents.count)
                backupDetailRow("Installment Plans", store.installmentPlans.count)
                backupDetailRow("Monthly Budgets", store.monthlyBudgets.count)
                backupDetailRow("Historical Summaries", store.historicalMonthlySummaries.count)
                backupDetailRow("Credit Cards", store.creditCards.count)
                backupDetailRow("Credit Card Purchases", store.creditCardPurchases.count)
                backupDetailRow("Credit Card Payments", store.creditCardPayments.count)
                backupDetailRow("People Debts", store.personDebts.count)
                backupDetailRow("Debt Entries", store.personDebtEntries.count)
            }

            Section(store.appLanguage == .arabicEgyptian ? "حالة النسخ اليدوي" : "Manual backup status") {
                if let statusMessage {
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(store.appLanguage == .arabicEgyptian ? "لم يتم تصدير أو استيراد نسخة احتياطية في هذه الجلسة." : "No backup file has been exported or imported in this session.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .accessibilityIdentifier("screen.dataBackup")
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "نسخة احتياطية يدوية" : "Manual Backup")
        .fileExporter(
            isPresented: $isExporting,
            document: backupDocument,
            contentType: .json,
            defaultFilename: backupFileName
        ) { result in
            handleExportResult(result)
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .sheet(item: $pendingRestorePreview) { preview in
            BackupRestorePreviewSheet(
                preview: preview,
                currentSummary: currentBackupSummary,
                onCancel: {
                    pendingImportData = nil
                    pendingRestorePreview = nil
                },
                onRestore: {
                    importPendingBackup()
                }
            )
            .environmentObject(store)
        }
    }

    private var currentBackupSummary: CurrentBackupSummary {
        CurrentBackupSummary(
            accountsCount: store.accounts.count,
            transactionsCount: store.financialEvents.count,
            latestTransactionDate: latestTransactionDate(
                financialEvents: store.financialEvents,
                creditCardPurchases: store.creditCardPurchases,
                creditCardPayments: store.creditCardPayments
            )
        )
    }

    private func backupDetailRow(_ title: String, _ count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundStyle(PocketWiseSemanticColor.backupPrivacy.tint)
        }
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func exportBackup() {
        do {
            let data = try store.encodeBackupSnapshotToJSON()
            backupDocument = WalletBackupDocument(data: data)
            backupFileName = makeBackupFileName()
            statusMessage = "Backup file is ready to save or share."
            errorMessage = nil
            isExporting = true
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            statusMessage = "Backup file exported successfully."
            errorMessage = nil

        case .failure(let error):
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }

            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(WalletDataSnapshot.self, from: data)
            let validationReport = store.makeBackupValidationReport(for: snapshot)

            pendingImportData = data
            pendingRestorePreview = BackupRestorePreview(
                fileName: url.lastPathComponent,
                snapshot: snapshot,
                validationReport: validationReport
            )
            errorMessage = nil
        } catch {
            pendingImportData = nil
            pendingRestorePreview = nil
            errorMessage = error.localizedDescription
        }
    }

    private func importPendingBackup() {
        guard let pendingImportData else {
            return
        }

        if let validationReport = pendingRestorePreview?.validationReport, validationReport.hasErrors {
            let firstErrorDetail = validationReport.issues.first(where: { $0.severity == .error })?.detail ?? "Validation failed."
            errorMessage = "Restore blocked: \(firstErrorDetail)"
            statusMessage = nil
            self.pendingImportData = nil
            pendingRestorePreview = nil
            return
        }

        do {
            let validationReport = pendingRestorePreview?.validationReport
            try store.importBackupSnapshotFromJSON(pendingImportData)
            if let validationReport, validationReport.hasIssues {
                statusMessage = "Backup restored successfully. \(validationReport.summaryText)"
            } else {
                statusMessage = "Backup restored successfully."
            }
            errorMessage = nil
            self.pendingImportData = nil
            pendingRestorePreview = nil
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
            self.pendingImportData = nil
            pendingRestorePreview = nil
        }
    }

    private func makeBackupFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "PocketWiseBackup-\(formatter.string(from: Date())).json"
    }

    private func formattedOptionalDate(_ date: Date?) -> String {
        guard let date else {
            return "Never"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func latestTransactionDate(
        financialEvents: [FinancialEvent],
        creditCardPurchases: [CreditCardPurchase],
        creditCardPayments: [CreditCardPayment]
    ) -> Date? {
        (
            financialEvents.map(\.date) +
            creditCardPurchases.map(\.purchaseDate) +
            creditCardPayments.map(\.paymentDate)
        ).max()
    }
}

private struct BackupRestorePreview: Identifiable {
    let id = UUID()
    let fileName: String
    let snapshot: WalletDataSnapshot
    let validationReport: BackupValidationReport
}

private struct CurrentBackupSummary {
    let accountsCount: Int
    let transactionsCount: Int
    let latestTransactionDate: Date?
}

private struct BackupRestorePreviewSheet: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    let preview: BackupRestorePreview
    let currentSummary: CurrentBackupSummary
    let onCancel: () -> Void
    let onRestore: () -> Void

    private var isArabic: Bool {
        store.appLanguage == .arabicEgyptian
    }

    private var metadata: WalletBackupMetadata? {
        preview.snapshot.backupMetadata
    }

    var body: some View {
        NavigationStack {
            List {
                Section(isArabic ? "ملف النسخة" : "Backup File") {
                    detailRow(isArabic ? "اسم الملف" : "File name", preview.fileName)
                    detailRow(isArabic ? "وقت إنشاء النسخة" : "Backup created at", metadataDateText(metadata?.backupCreatedAt))
                    detailRow(isArabic ? "إصدار النسخة" : "Backup schema version", "\(metadata?.backupSchemaVersion ?? preview.snapshot.schemaVersion)")
                    if metadata == nil {
                        Text(isArabic ? "بيانات تعريف النسخة غير متاحة في الملف ده." : "Backup metadata is not available in this file.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(isArabic ? "محتويات النسخة" : "Backup Contents") {
                    detailRow(isArabic ? "الحسابات" : "Accounts", "\(metadata?.totalAccounts ?? preview.snapshot.accounts.count)")
                    detailRow(isArabic ? "المعاملات" : "Transactions", "\(metadata?.totalTransactions ?? preview.snapshot.financialEvents.count)")
                    detailRow(isArabic ? "بنود مستقبلية" : "Future items", "\(metadata?.totalFutureItems ?? futureItemsCount)")
                    detailRow(isArabic ? "بنود متكررة" : "Recurring items", "\(metadata?.totalRecurringItems ?? recurringItemsCount)")
                    detailRow(isArabic ? "الأقساط" : "Installments", "\(metadata?.totalInstallments ?? preview.snapshot.installmentPlans.count)")
                    detailRow(isArabic ? "كروت ائتمان" : "Credit cards", "\(metadata?.totalCreditCards ?? preview.snapshot.creditCards.count)")
                    detailRow(isArabic ? "مشتريات كروت" : "Credit card purchases", "\(metadata?.totalCreditCardPurchases ?? preview.snapshot.creditCardPurchases.count)")
                    detailRow(isArabic ? "سداد كروت" : "Credit card payments", "\(metadata?.totalCreditCardPayments ?? preview.snapshot.creditCardPayments.count)")
                    detailRow(isArabic ? "أحدث معاملة" : "Latest transaction", metadataDateText(metadata?.latestTransactionDate ?? latestBackupTransactionDate))
                }

                Section(isArabic ? "البيانات الحالية" : "Current App Data") {
                    detailRow(isArabic ? "الحسابات الحالية" : "Current accounts", "\(currentSummary.accountsCount)")
                    detailRow(isArabic ? "المعاملات الحالية" : "Current transactions", "\(currentSummary.transactionsCount)")
                    detailRow(isArabic ? "أحدث معاملة حالية" : "Current latest transaction", metadataDateText(currentSummary.latestTransactionDate))
                }

                if preview.validationReport.hasErrors {
                    Section(isArabic ? "خطأ — الاسترجاع محظور" : "Restore Blocked") {
                        Text(isArabic ? "مش ممكن استرجاع النسخة دي. في مشكلة بتمنع الاسترجاع الآمن." : "This backup cannot be restored. A blocking error was detected that prevents safe restore.")
                            .font(.footnote)
                            .foregroundStyle(.red)

                        ForEach(preview.validationReport.issues.filter { $0.severity == .error }) { issue in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(issue.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.red)
                                Text(issue.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } else if preview.validationReport.hasIssues {
                    Section(isArabic ? "تحذيرات التوافق" : "Compatibility Warnings") {
                        Text(isArabic ? "الاسترجاع لسه مسموح. التحذيرات دي للمراجعة فقط ومش بتعدل بيانات النسخة." : "Restore is still allowed. These warnings are review-only and do not change the backup data.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        detailRow(isArabic ? "التحذيرات" : "Warnings", "\(preview.validationReport.warningCount)")
                        if preview.validationReport.infoCount > 0 {
                            detailRow(isArabic ? "للمراجعة" : "Review items", "\(preview.validationReport.infoCount)")
                        }

                        ForEach(preview.validationReport.issues.prefix(5)) { issue in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(issue.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(issue.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }

                        if preview.validationReport.issues.count > 5 {
                            Text(isArabic ? "وفي تحذيرات إضافية للمراجعة بعد الاسترجاع." : "Additional warnings should be reviewed after restore.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Text(isArabic ? "استرجاع النسخة دي هيستبدل بيانات التطبيق الحالية. اعمل نسخة احتياطية جديدة الأول لو مش متأكد." : "Restoring this backup will replace your current app data. Export a fresh backup first if you are not sure.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(isArabic ? "معاينة الاسترجاع" : "Restore Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isArabic ? "إلغاء" : "Cancel") {
                        onCancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isArabic ? "استرجع النسخة دي" : "Restore This Backup", role: .destructive) {
                        onRestore()
                        dismiss()
                    }
                    .disabled(preview.validationReport.hasErrors)
                }
            }
        }
    }

    private var futureItemsCount: Int {
        preview.snapshot.financialEvents.filter { $0.status != .paid && $0.repeatRule == .none }.count
    }

    private var recurringItemsCount: Int {
        preview.snapshot.financialEvents.filter { $0.repeatRule != .none }.count
    }

    private var latestBackupTransactionDate: Date? {
        (
            preview.snapshot.financialEvents.map(\.date) +
            preview.snapshot.creditCardPurchases.map(\.purchaseDate) +
            preview.snapshot.creditCardPayments.map(\.paymentDate)
        ).max()
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func metadataDateText(_ date: Date?) -> String {
        guard let date else {
            return isArabic ? "غير متاح" : "Not available"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter.string(from: date)
    }
}

struct WalletBackupDocument: FileDocument {

    static var readableContentTypes: [UTType] {
        [.json]
    }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct DataBackupView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            DataBackupView()
                .environmentObject(WalletStore())
        }
    }
}
