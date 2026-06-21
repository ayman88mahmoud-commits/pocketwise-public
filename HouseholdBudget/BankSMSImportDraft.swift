import Foundation

struct BankSMSImportDraft: Identifiable, Hashable, Codable {
    var id = UUID()
    var amount: Double?
    var currency: String?
    var transactionType: String?
    var sourceEnding: String?
    var sourceKind: String?
    var sourceSubtype: String?
    var merchant: String?
    var sender: String?
    var reference: String?
    var transactionDate: Date?
    var note: String

    var importIdentity: String {
        [
            amount.map { String(format: "%.2f", $0) } ?? "",
            transactionDate.map { String(Int($0.timeIntervalSince1970)) } ?? "",
            transactionType ?? "",
            sourceSubtype ?? "",
            merchant ?? "",
            sender ?? "",
            sourceEnding ?? "",
            reference ?? "",
            note
        ]
            .joined(separator: "|")
    }
}

enum PendingBankSMSImportStore {
    private static let storageKey = "pending_bank_sms_import_drafts"

    static func load() -> [BankSMSImportDraft] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let drafts = try? JSONDecoder().decode([BankSMSImportDraft].self, from: data) else {
            return []
        }

        return drafts
    }

    @discardableResult
    static func append(_ draft: BankSMSImportDraft) -> [BankSMSImportDraft] {
        var drafts = load()
        guard !drafts.contains(where: { $0.importIdentity == draft.importIdentity }) else {
            return drafts
        }

        drafts.append(draft)
        save(drafts)
        return drafts
    }

    @discardableResult
    static func remove(importIdentity: String) -> [BankSMSImportDraft] {
        let drafts = load().filter { $0.importIdentity != importIdentity }
        save(drafts)
        return drafts
    }

    private static func save(_ drafts: [BankSMSImportDraft]) {
        guard let data = try? JSONEncoder().encode(drafts) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

enum BankSMSImportParser {

    private enum InstantTransferDirection {
        case incoming
        case outgoing
        case unclear
        case notInstantTransfer
    }

    static func draft(from url: URL) -> BankSMSImportDraft? {
        guard url.scheme?.lowercased() == "householdbudget",
              url.host?.lowercased() == "import-bank-sms" else {
            return nil
        }

        let rawValue = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "raw" }?
            .value

        guard let rawValue else {
            return BankSMSImportDraft(note: "")
        }

        return parseTransaction(rawValue)
    }

    static func parseTransaction(_ rawText: String) -> BankSMSImportDraft? {
        guard !shouldIgnore(rawText) else {
            return nil
        }

        return parse(rawText)
    }

    static func parse(_ rawText: String) -> BankSMSImportDraft {
        let decodedText = decode(rawText)
        let normalizedText = normalize(decodedText)
        let cleanedText = cleanSMS(normalizedText)
        let amountSearchText = stripAvailableBalance(from: normalizedText)
        let amountMatch = extractAmount(from: amountSearchText)
        let amount = amountMatch.flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
        let currency = amountMatch == nil ? nil : "EGP"
        let sourceEnding = extractSourceEnding(from: normalizedText)
        let sourceKind = normalizedText.contains("بطاقة") || normalizedText.contains("بالبطاقة") ? "card" : normalizedText.contains("حساب") ? "account" : nil
        let sourceSubtype = extractSourceSubtype(from: normalizedText)
        let isInstantTransfer = normalizedText.contains("تحويل لحظي")
        let instantTransferDirection = instantTransferDirection(from: normalizedText)
        let transactionType = instantTransferDirection == .incoming ? "income" : isInstantTransfer ? "transfer" : "expense"
        let sender = instantTransferDirection == .incoming ? extractInstantTransferSender(from: normalizedText) : nil
        let merchant = extractMerchant(from: normalizedText) ?? transferTitle(direction: instantTransferDirection, isInstantTransfer: isInstantTransfer)
        let reference = firstMatch(in: normalizedText, pattern: #"(?i)(?:مرجع|مرجعي|reference|ref)\s+([A-Za-z0-9-]+)"#)
        let transactionDate = extractDate(from: normalizedText)

        return BankSMSImportDraft(
            amount: amount,
            currency: currency,
            transactionType: transactionType,
            sourceEnding: sourceEnding,
            sourceKind: sourceKind,
            sourceSubtype: sourceSubtype,
            merchant: merchant,
            sender: sender,
            reference: reference,
            transactionDate: transactionDate,
            note: buildNote(
                merchant: merchant,
                sender: sender,
                sourceKind: sourceKind,
                sourceEnding: sourceEnding,
                reference: reference,
                transactionType: transactionType,
                instantTransferDirection: instantTransferDirection,
                isInstantTransfer: isInstantTransfer,
                cleanedText: cleanedText
            )
        )
    }

    private static func decode(_ text: String) -> String {
        let plusNormalized = text.replacingOccurrences(of: "+", with: " ")
        return plusNormalized.removingPercentEncoding ?? text
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "،", with: " ")
            .replacingOccurrences(of: "؛", with: " ")
            .replacingOccurrences(of: "ـ", with: "")
            .replacingOccurrences(of: "إلى", with: "الى")
            .replacingOccurrences(of: "إلي", with: "الى")
            .replacingOccurrences(of: "بـ", with: "ب")
            .replacingOccurrences(of: "الساعه", with: "الساعة")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func shouldIgnore(_ text: String) -> Bool {
        let normalizedText = normalize(decode(text)).lowercased()

        if normalizedText.contains("otp") || normalizedText.contains("الكود سري") {
            return true
        }

        if normalizedText.contains("logged into") ||
            normalizedText.contains("al ahli net") ||
            normalizedText.contains("al ahly net") ||
            normalizedText.contains("nbe mobile account") {
            return true
        }

        if normalizedText.contains("لن تكون متاحة مؤقت") ||
            normalizedText.contains("خدمات cib لن تكون متاحة") {
            return true
        }

        if normalizedText.contains("استلام طلبك") &&
            normalizedText.contains("بطاقة ائتمانية") {
            return true
        }

        return false
    }

    private static func cleanSMS(_ text: String) -> String {
        var cleaned = stripAvailableBalance(from: text)
        cleaned = cleaned.replacingOccurrences(
            of: #"\s*(?:للمزيد\s*)?(?:برجاء\s+)?(?:إتصل|اتصل|الاتصال)\s+ب?\s*\d+"#,
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripAvailableBalance(from text: String) -> String {
        text.replacingOccurrences(
            of: #"(?i)\s*(?:الرصيد\s+المتاح|المتاح)\s*(?:EGP\s*)?\d+(?:[,.]\d+)?\s*(?:EGP|ج\.?م|جم)?\.?"#,
            with: "",
            options: .regularExpression
        )
    }

    private static func extractAmount(from text: String) -> String? {
        let patterns = [
            #"خصم\s+مبلغ\s+EGP\s*(\d+(?:[,.]\d{1,2})?)"#,
            #"خصم\s+EGP\s*(\d+(?:[,.]\d{1,2})?)"#,
            #"خصم\s+(\d+(?:[,.]\d{1,2})?)\s*(?:EGP|ج\.?م|جم)"#,
            #"بمبلغ\s+EGP\s*(\d+(?:[,.]\d{1,2})?)"#,
            #"بمبلغ\s+(\d+(?:[,.]\d{1,2})?)\s*(?:EGP|ج\.?م|جم)"#,
            #"EGP\s*(\d+(?:[,.]\d{1,2})?)"#,
            #"(\d+(?:[,.]\d{1,2})?)\s*EGP"#,
            #"(\d+(?:[,.]\d{1,2})?)\s*(?:ج\.?م|جم)"#
        ]

        for pattern in patterns {
            if let amount = firstMatch(in: text, pattern: pattern) {
                return amount
            }
        }

        return nil
    }

    private static func extractSourceEnding(from text: String) -> String? {
        let patterns = [
            #"بطاقة[^\d*#]*(?:رقم|#|المنتهية\s+ب(?:رقم)?)?\s*\**\s*(\d{4})"#,
            #"بالبطاقة\s+المنتهية\s+برقم\s+(\d{4})"#,
            #"لحساب(?:ك(?:م)?)?\s+(?:رقم\s+)?(\d{4})"#,
            #"لحسابك(?:م)?\s+رقم\s+(\d{4})"#,
            #"حسابك\s+المنتهي\s+ب\s*\**\s*(\d{4})"#,
            #"(?:المنتهي|منتهية)\s+ب(?:رقم)?\s*\**\s*(\d{4})"#,
            #"ب\s+(\d{4})\*{4,}"#,
            #"\*{2,}\s*(\d{4})"#
        ]

        for pattern in patterns {
            if let sourceEnding = firstMatch(in: text, pattern: pattern) {
                return sourceEnding
            }
        }

        return nil
    }

    private static func extractMerchant(from text: String) -> String? {
        let patterns = [
            #"عند\s+(.+?)(?=\s+(?:يوم|في\s+\d{1,2}[/-]\d{1,2}|بتاريخ|الرصيد|المتاح|للمزيد)|[.]|$)"#,
            #"لدى\s+(.+?)(?=\s+(?:يوم|في\s+\d{1,2}[/-]\d{1,2}|بتاريخ|الرصيد|المتاح|للمزيد)|[.]|$)"#,
            #"في\s+(.+?)(?=\s+(?:يوم|بتاريخ|الرصيد|المتاح|للمزيد)|[.]|$)"#
        ]

        for pattern in patterns {
            guard let merchant = firstMatch(in: text, pattern: pattern)?
                .trimmingCharacters(in: .whitespacesAndNewlines) else {
                continue
            }

            if !merchant.isEmpty && !looksLikeDate(merchant) {
                return merchant
            }
        }

        return nil
    }

    private static func extractSourceSubtype(from text: String) -> String? {
        let lowercased = text.lowercased()

        if text.contains("بطاقة الخصم المباشر") || lowercased.contains("debit card") {
            return "debitCard"
        }

        if text.contains("بطاقة الائتمان") || lowercased.contains("credit card") {
            return "creditCard"
        }

        return nil
    }

    private static func instantTransferDirection(from text: String) -> InstantTransferDirection {
        guard text.contains("تحويل") else {
            return .notInstantTransfer
        }

        let creditedTransferPattern = #"(?:تم\s+)?(?:إضافة|اضافة|اضافه)\s+تحويل(?:\s+لحظي)?"#
        let destinationAccountPattern = #"(?:الى\s+حسابك|لحساب(?:ك(?:م)?)?(?:\s+(?:رقم\s+)?\d{4})?)"#
        if (text.range(of: creditedTransferPattern, options: .regularExpression) != nil &&
            text.range(of: destinationAccountPattern, options: .regularExpression) != nil) ||
            text.range(of: #"(?:الى\s+حسابك|لحسابك(?:م)?(?:\s+رقم\s+\d{4})?)"#, options: .regularExpression) != nil {
            return .incoming
        }

        if text.range(of: #"(?:من\s+حسابك|من\s+حسابكم|من\s+الحساب)"#, options: .regularExpression) != nil {
            return .outgoing
        }

        return .unclear
    }

    private static func transferTitle(direction: InstantTransferDirection, isInstantTransfer: Bool) -> String? {
        switch direction {
        case .incoming:
            return isInstantTransfer ? "InstaPay incoming transfer" : "Incoming bank transfer"
        case .outgoing:
            return "InstaPay transfer"
        case .unclear:
            return "Instant transfer"
        case .notInstantTransfer:
            return nil
        }
    }

    private static func extractInstantTransferSender(from text: String) -> String? {
        guard instantTransferDirection(from: text) == .incoming else {
            return nil
        }

        return firstMatch(
            in: text,
            pattern: #"من\s+(.+?)(?=\s+(?:برقم|رقم)\s+مرجعي|\s+بتاريخ|\s+يوم\s+\d{1,2}[/-]\d{1,2}|\s+للمزيد|$)"#
        )?
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractDate(from text: String) -> Date? {
        let calendar = Calendar.current
        let today = Date()
        let currentYear = calendar.component(.year, from: today)

        if let captures = firstCaptures(
            in: text,
            pattern: #"(\d{4})[/-](\d{1,2})[/-](\d{1,2})(?:\s+(?:الساعة\s+)?(\d{1,2}):(\d{2}))?"#
        ) {
            return validatedTransactionDate(dateFromYearMonthDay(captures), today: today, calendar: calendar)
        }

        if let captures = firstCaptures(
            in: text,
            pattern: #"(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?(?:\s+(?:الساعة\s+)?(\d{1,2}):(\d{2}))?"#
        ) {
            return validatedTransactionDate(date(from: captures, fallbackYear: currentYear), today: today, calendar: calendar)
        }

        if let captures = firstCaptures(
            in: text,
            pattern: #"(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?.*?الساعة\s+(\d{1,2}):(\d{2})"#
        ) {
            return validatedTransactionDate(date(from: captures, fallbackYear: currentYear), today: today, calendar: calendar)
        }

        return nil
    }

    private static func date(from captures: [String], fallbackYear: Int) -> Date? {
        guard captures.count == 5,
              var day = Int(captures[0]),
              var month = Int(captures[1]) else {
            return nil
        }

        if month > 12 && day <= 12 {
            swap(&day, &month)
        }

        var components = DateComponents()
        components.calendar = Calendar.current
        components.day = day
        components.month = month
        components.year = normalizedYear(captures[2], fallbackYear: fallbackYear)
        components.hour = Int(captures[3]) ?? 0
        components.minute = Int(captures[4]) ?? 0

        return Calendar.current.date(from: components)
    }

    private static func dateFromYearMonthDay(_ captures: [String]) -> Date? {
        guard captures.count == 5,
              let year = Int(captures[0]),
              let month = Int(captures[1]),
              let day = Int(captures[2]) else {
            return nil
        }

        var components = DateComponents()
        components.calendar = Calendar.current
        components.year = year
        components.month = month
        components.day = day
        components.hour = Int(captures[3]) ?? 0
        components.minute = Int(captures[4]) ?? 0

        return Calendar.current.date(from: components)
    }

    private static func validatedTransactionDate(_ parsedDate: Date?, today: Date, calendar: Calendar) -> Date? {
        guard let parsedDate else {
            return nil
        }

        let todayStart = calendar.startOfDay(for: today)
        guard let futureLimit = calendar.date(byAdding: .day, value: 3, to: todayStart) else {
            return parsedDate
        }

        if calendar.startOfDay(for: parsedDate) > futureLimit {
            return today
        }

        return parsedDate
    }

    private static func normalizedYear(_ text: String, fallbackYear: Int) -> Int {
        guard let year = Int(text), year > 0 else {
            return fallbackYear
        }

        if year < 100 {
            return 2000 + year
        }

        return year
    }

    private static func looksLikeDate(_ text: String) -> Bool {
        text.range(of: #"^\d{1,2}[/-]\d{1,2}"#, options: .regularExpression) != nil ||
        text.range(of: #"^\d{4}[/-]\d{1,2}[/-]\d{1,2}"#, options: .regularExpression) != nil
    }

    private static func buildNote(
        merchant: String?,
        sender: String?,
        sourceKind: String?,
        sourceEnding: String?,
        reference: String?,
        transactionType: String?,
        instantTransferDirection: InstantTransferDirection,
        isInstantTransfer: Bool,
        cleanedText: String
    ) -> String {
        var lines: [String] = []

        if transactionType == "income" {
            if isInstantTransfer {
                lines.append("Incoming InstaPay transfer")
                lines.append("Payment method: InstaPay")
            } else {
                lines.append("Incoming bank transfer")
            }
        } else if transactionType == "transfer" {
            if instantTransferDirection == .outgoing {
                lines.append("Outgoing InstaPay transfer")
            } else {
                lines.append("Instant transfer")
            }
            lines.append("Payment method: InstaPay")
        }

        if let merchant, !merchant.isEmpty {
            lines.append("Merchant: \(merchant)")
        }

        if let sender, !sender.isEmpty {
            lines.append("Sender: \(sender)")
        }

        if let sourceEnding, !sourceEnding.isEmpty {
            let sourceLabel = sourceKind == "card" ? "Card ending" : "Account ending"
            lines.append("\(sourceLabel): \(sourceEnding)")
        }

        if let reference, !reference.isEmpty {
            lines.append("Reference: \(reference)")
        }

        if !cleanedText.isEmpty {
            lines.append("SMS: \(cleanedText)")
        }

        return lines.joined(separator: "\n")
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }

        let captureRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
        guard let range = Range(captureRange, in: text) else {
            return nil
        }

        return String(text[range])
    }

    private static func firstCaptures(in text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1 else {
            return nil
        }

        var captures: [String] = []
        for index in 1..<match.numberOfRanges {
            let captureRange = match.range(at: index)
            if captureRange.location == NSNotFound {
                captures.append("")
                continue
            }

            guard let range = Range(captureRange, in: text) else {
                captures.append("")
                continue
            }

            captures.append(String(text[range]))
        }

        return captures
    }
}
