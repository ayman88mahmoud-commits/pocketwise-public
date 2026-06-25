import Foundation
import SwiftUI

enum AppText {

    static func tabToday(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "النهارده" : "Today"
    }

    static func tabTransactions(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الحركات" : "Transactions"
    }

    static func tabPlan(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الميزانية" : "Budget"
    }

    static func tabAnalysis(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "التحليل" : "Analysis"
    }

    static func tabSettings(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الإعدادات" : "Settings"
    }

    static func greeting(language: AppLanguage, displayName: String, date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        let base: String
        switch language {
        case .english:
            if hour < 12 {
                base = "Good morning"
            } else if hour < 18 {
                base = "Good afternoon"
            } else {
                base = "Good evening"
            }

            return cleanName.isEmpty ? base : "\(base), \(cleanName)"

        case .arabicEgyptian:
            if hour < 12 {
                base = "صباح الفل"
            } else if hour >= 23 || hour < 5 {
                base = "مساء الفل"
            } else {
                base = "مساء الخير"
            }

            return cleanName.isEmpty ? base : "\(base) يا \(cleanName)"
        }
    }

    static func readySubtitle(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "محفظتك جاهزة." : "Your wallet is ready."
    }

    static func appTagline(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "رتب فلوسك" : "WalletBoard helps you plan your money clearly"
    }

    static func addExpense(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "أضف مصروف" : "Add Expense"
    }

    static func addTransfer(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "تحويل" : "Transfer"
    }

    static func addIncome(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "أضف دخل" : "Add Income"
    }

    static func more(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "المزيد" : "More"
    }

    static func hideBalances(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "إخفاء الأرقام" : "Hide Balances"
    }

    static func showBalances(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "إظهار الأرقام" : "Show Balances"
    }

    static func privacy(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الخصوصية" : "Privacy"
    }

    static func layoutDirection(_ language: AppLanguage) -> LayoutDirection {
        language == .arabicEgyptian ? .rightToLeft : .leftToRight
    }

    // MARK: - Sections & Navigation

    static func thisMonth(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الشهر ده" : "This Month"
    }

    static func upcoming(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الجاي" : "Upcoming"
    }

    static func recentActivity(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "آخر الحركات" : "Recent Activity"
    }

    static func needsAttention(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "محتاج انتباه" : "Needs Attention"
    }

    static func quickAdd(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "إضافة سريعة" : "Quick Add"
    }

    static func commitments(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الالتزامات" : "Commitments"
    }

    static func budgetGrid(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "جدول الميزانية" : "Budget Grid"
    }

    static func currentMonth(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الشهر الحالي" : "Current Month"
    }

    static func obligations(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الالتزامات" : "Obligations"
    }

    static func setup(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الإعداد" : "Setup"
    }

    static func recurring(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "متكرر" : "Recurring"
    }

    static func installments(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "أقساط" : "Installments"
    }

    static func futureItems(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "بنود مستقبلية" : "Future Items"
    }

    static func expectedIncome(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "دخل متوقع" : "Expected Income"
    }

    static func peopleDebts(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "أشخاص / ديون" : "People / Debts"
    }

    static func monthlyCommitted(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "شهريًا" : "monthly committed"
    }

    static func recurringSeries(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "سلاسل متكررة" : "Recurring series"
    }

    static func thisMonthCommitted(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "ملتزم به هذا الشهر" : "This month committed"
    }

    static func planCheck(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "مراجعة الخطة" : "Plan Check"
    }

    static func planStatusIssues(_ language: AppLanguage, count: Int, range: String) -> String {
        if language == .arabicEgyptian {
            return "حالة الخطة: \(count) عناصر تحتاج مراجعة · \(range)"
        }

        return "Plan status: \(count) things need review · \(range)"
    }

    static func planLooksCompleteThrough(_ language: AppLanguage, month: String) -> String {
        if language == .arabicEgyptian {
            return "الخطة تبدو مكتملة حتى \(month)"
        }

        return "Plan looks complete through \(month)"
    }

    static func addBudgetOrIncomeToCheckPeriod(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "أضف ميزانية أو دخل لمراجعة الفترة" : "Add budget or income to check this period"
    }

    static func openPlanCheck(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "افتح مراجعة الخطة" : "Open Plan Check"
    }

    static func remainingUnpaid(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "متبقي غير مدفوع" : "remaining unpaid"
    }

    static func total(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الإجمالي" : "total"
    }

    static func dueSoon(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "قريب" : "Due Soon"
    }

    static func later(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "بعد كده" : "Later"
    }

    static func summary(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الملخص" : "Summary"
    }

    static func categories(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "البنود" : "Categories"
    }

    static func whatsIncluded(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "إيه اللي محسوب" : "What's included"
    }

    // MARK: - Actions

    static func save(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "حفظ" : "Save"
    }

    static func saved(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "تم الحفظ" : "Saved"
    }

    static func pay(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "دفع" : "Pay"
    }

    static func payDue(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "سداد المستحق" : "Pay Due"
    }

    static func manageAccounts(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "إدارة الحسابات" : "Manage accounts"
    }

    // MARK: - Common Labels

    static func planned(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "المخطط" : "Planned"
    }

    static func remaining(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "المتبقي" : "Remaining"
    }

    static func notSet(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "غير محدد" : "Not set"
    }

    static func noCategoriesYet(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "لسه مفيش بنود" : "No categories yet"
    }

    // MARK: - Budget Grid & Phase 2 Rename Keys

    static func committed(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "ملتزم به" : "Committed"
    }

    static func committedExpenses(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "مصاريف ملتزم بها" : "Committed Expenses"
    }

    static func endBalance(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "رصيد آخر الفترة" : "End Balance"
    }

    static func totalExpected(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "المتوقع إجمالًا" : "Total Expected"
    }

    static func income(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الدخل" : "Income"
    }

    static func budget(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الميزانية" : "Budget"
    }

    // MARK: - Runway / Today

    static func availableNow(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "معاك دلوقتي" : "Available now"
    }

    static func keepAtLeast(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "احتفظ بحد أدنى" : "Keep at least"
    }

    static func lowestCashReach(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "أسوأ رصيد" : "Worst balance"
    }

    static func targetDate(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "تاريخ الهدف" : "Target date"
    }

    static func incomeMode(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "وضع الدخل" : "Income Mode"
    }

    static func available(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "المتاح" : "Available"
    }

    // MARK: - Credit Card

    static func creditCardDue(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "مستحق كارت ائتمان" : "Credit Card Due"
    }

    static func dueAmount(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "المطلوب سداده" : "Due amount"
    }

    // MARK: - Analysis

    static func householdSpending(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "مصروفات البيت" : "Household Spending"
    }

    static func cashMovements(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "حركات نقدية" : "Cash Movements"
    }

    static func managedInPeopleDebts(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "تتم إدارته من الأشخاص والديون" : "Managed in People/Debts"
    }

    static func noPaidSpendingThisMonth(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "مفيش حركات مدفوعة للشهر ده." : "No paid spending for this month."
    }

    // MARK: - Cash Timeline

    static func timelineTitle(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "تدفق الفلوس" : "Cash Timeline"
    }

    static func timelineHorizon30(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "٣٠ يوم" : "30 days"
    }

    static func timelineHorizon60(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "٦٠ يوم" : "60 days"
    }

    static func timelineHorizon90(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "٩٠ يوم" : "90 days"
    }

    static func timelineHorizonPickDate(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "تاريخ محدد" : "Pick date"
    }

    static func done(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "تمام" : "Done"
    }

    static func timelineToday(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "النهارده" : "Today"
    }

    static func timelineBalanceAfter(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الرصيد بعد كده" : "Balance after"
    }

    static func timelineOverdueHeader(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "متأخر — لسه متدفعش" : "Overdue — not yet paid"
    }

    static func timelineOverdueNote(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "عدى موعده" : "Past due"
    }

    static func timelineNotReceivedYet(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "لسه متستلمش" : "Not received yet"
    }

    static func timelineExpectedBadge(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "متوقع" : "Expected"
    }

    static func timelinePinchPoint(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "نقطة ضغط مالي" : "Pinch point"
    }

    static func timelinePinchDetail(_ language: AppLanguage, amount: String, dateString: String) -> String {
        language == .arabicEgyptian
            ? "الرصيد هيوصل \(amount) في \(dateString)"
            : "Balance drops to \(amount) around \(dateString)"
    }

    static func timelineAllClear(_ language: AppLanguage, dateString: String) -> String {
        language == .arabicEgyptian
            ? "كل شيء تمام لحد \(dateString)"
            : "Clear through \(dateString)"
    }

    static func timelineTight(_ language: AppLanguage, dateString: String) -> String {
        language == .arabicEgyptian
            ? "ضغط مالي في \(dateString)"
            : "Tight around \(dateString)"
    }

    static func timelineEmpty(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "مفيش بنود للفترة دي" : "No upcoming items in this period"
    }

    static func timelineInstallmentPosition(_ language: AppLanguage, current: Int, total: Int) -> String {
        language == .arabicEgyptian
            ? "دفعة \(current) من \(total)"
            : "Payment \(current) of \(total)"
    }

    // MARK: - Runway Map

    static func runwayMapTitle(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "خريطة التدفق المالي" : "Cash Runway Map"
    }

    static func runwayMapSubtitle(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "شوف فلوسك هتمشي إزاي لحد التدفق النقدي الداخل الجاي." : "See how your cash moves until your next cash inflow."
    }

    static func viewRunwayMap(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "شوف خريطة التدفق" : "View Runway Map"
    }

    static func runwayMapHorizon180(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "١٨٠ يوم" : "180 days"
    }

    static func cashOutlookSection(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "توقعات الفلوس" : "Cash Outlook"
    }

    static func affordabilityTitle(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "هقدر أشتري ده؟" : "Can I Afford This?"
    }

    static func affordabilityAmount(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "المبلغ" : "Amount"
    }

    static func affordabilityDate(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "التاريخ" : "Date"
    }

    static func affordabilityReset(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "إعادة ضبط" : "Reset"
    }

    static func affordabilitySafe(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "آمن" : "Safe"
    }

    static func affordabilityTight(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "ضغط" : "Tight"
    }

    static func affordabilityAtRisk(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "في خطر" : "At Risk"
    }

    static func runwayUpcomingItems(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "البنود الجاية" : "Upcoming items"
    }

    static func runwayNextIncome(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "التدفق النقدي الداخل الجاي" : "Next cash inflow"
    }

    static func runwaySafeFloor(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "الحد الأدنى الآمن" : "Safe floor"
    }

    static func runwayNewLowestBalance(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "أقل رصيد جديد" : "New lowest balance"
    }

    static func runwayReducesBuffer(_ language: AppLanguage, days: Int) -> String {
        language == .arabicEgyptian
            ? "بيقلل الهامش بـ \(days) يوم"
            : "Reduces buffer by \(days) days"
    }

    static func runwayNoEffect(_ language: AppLanguage) -> String {
        language == .arabicEgyptian ? "ما بيأثرش على التدفق" : "Does not affect runway"
    }

    // MARK: - Display Localization Helpers

    static func categoryDisplayName(_ name: String, language: AppLanguage) -> String {
        guard language == .arabicEgyptian else {
            return name
        }

        return arabicCategoryNames[normalizeDisplayKey(name)] ?? name
    }

    static func subcategoryDisplayName(_ name: String, language: AppLanguage) -> String {
        guard language == .arabicEgyptian else {
            return name
        }

        return arabicSubcategoryNames[normalizeDisplayKey(name)] ?? name
    }

    static func categorySubcategoryDisplayText(
        categoryName: String,
        subCategoryName: String,
        language: AppLanguage
    ) -> String {
        "\(categoryDisplayName(categoryName, language: language)) / \(subcategoryDisplayName(subCategoryName, language: language))"
    }

    static func eventTypeLabel(_ type: FinancialEventType, language: AppLanguage) -> String {
        guard language == .arabicEgyptian else { return type.rawValue }
        switch type {
        case .expense: return "مصروف"
        case .income: return "دخل"
        case .obligation: return "التزام"
        case .expectedExpense: return "مصروف متوقع"
        case .installment: return "قسط"
        case .transfer: return "تحويل"
        }
    }

    static func repeatRuleLabel(_ rule: RepeatRule, language: AppLanguage) -> String {
        guard language == .arabicEgyptian else { return rule.rawValue }
        switch rule {
        case .none: return ""
        case .monthly: return "شهري"
        case .quarterly: return "ربع سنوي"
        case .yearly: return "سنوي"
        }
    }

    static func confidenceLevelLabel(_ level: ConfidenceLevel, language: AppLanguage) -> String {
        guard language == .arabicEgyptian else { return level.rawValue }
        switch level {
        case .low: return "منخفضة"
        case .medium: return "متوسطة"
        case .high: return "عالية"
        }
    }

    static func statusLabel(_ status: FinancialEventStatus, language: AppLanguage) -> String {
        switch status {
        case .planned:
            return language == .arabicEgyptian ? "مخطط" : "Planned"
        case .expected:
            return language == .arabicEgyptian ? "متوقع" : "Expected"
        case .paid:
            return language == .arabicEgyptian ? "مدفوع" : "Paid"
        case .unpaid:
            return language == .arabicEgyptian ? "غير مدفوع" : "Unpaid"
        case .skipped:
            return language == .arabicEgyptian ? "متخطي" : "Skipped"
        case .cancelled:
            return language == .arabicEgyptian ? "ملغي" : "Cancelled"
        }
    }

    static func transactionChip(_ key: String, language: AppLanguage) -> String {
        guard language == .arabicEgyptian else {
            return key
        }

        switch key {
        case "Expected income": return "دخل متوقع"
        case "Received": return "تم الاستلام"
        case "Paid": return "مدفوع"
        case "Future": return "قادم"
        case "Transfer": return "تحويل"
        case "Expense": return "مصروف"
        case "Card": return "بطاقة"
        case "Purchase": return "شراء"
        case "Payment": return "سداد"
        case "Settlement": return "تسوية"
        default: return key
        }
    }

    private static func normalizeDisplayKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static let arabicCategoryNames: [String: String] = [
        "food & groceries": "أكل ودليفري",
        "food & dining": "أكل ودليفري",
        "groceries": "سوبر ماركت",
        "supermarket": "سوبر ماركت",
        "dining & delivery": "أكل ودليفري",
        "transportation": "مواصلات",
        "transport": "مواصلات",
        "car": "العربية",
        "car & transport": "عربية ومواصلات",
        "fuel": "بنزين",
        "home": "البيت",
        "housing": "السكن",
        "home essentials": "حاجات البيت",
        "household": "البيت",
        "utilities": "مرافق",
        "utilities & bills": "مرافق وفواتير",
        "school": "مدرسة",
        "education": "تعليم",
        "health": "صحة",
        "medical": "علاج وصحة",
        "health & medical": "علاج وصحة",
        "entertainment": "ترفيه",
        "subscriptions": "اشتراكات",
        "digital & subscriptions": "ديجيتال واشتراكات",
        "fixed obligations": "التزامات ثابتة",
        "debt & installments": "ديون وأقساط",
        "kids": "الأولاد",
        "kids & school": "الأولاد والمدرسة",
        "family support": "دعم الأسرة",
        "personal": "شخصي",
        "work & business": "شغل وبيزنس",
        "giving & charity": "تبرعات وخير",
        "household help & services": "خدمات ومساعدة البيت",
        "banking & fees": "مصاريف بنكية",
        "money lent / receivables": "سلف ومستحقات",
        "people / debts": "أشخاص وديون",
        "pets": "حيوانات أليفة",
        "travel": "سفر",
        "shopping": "تسوق",
        "other": "أخرى"
    ]

    private static let arabicSubcategoryNames: [String: String] = [
        "groceries": "سوبر ماركت",
        "supermarket": "سوبر ماركت",
        "instashop": "إنستاشوب",
        "mini market": "ميني ماركت",
        "butcher": "جزار",
        "delivery": "دليفري",
        "coffee & snacks": "قهوة وسناكس",
        "rent": "إيجار",
        "mortgage": "قرض عقاري",
        "home maintenance": "صيانة البيت",
        "furniture & appliances": "أثاث وأجهزة",
        "renovation": "تجديدات",
        "restaurants": "مطاعم",
        "restaurant": "مطاعم",
        "cafe": "كافيه",
        "fuel": "بنزين",
        "ride-hailing": "مشاوير بتطبيقات",
        "public transport": "مواصلات عامة",
        "parking": "ركنة",
        "transportation": "مواصلات",
        "maintenance": "صيانة",
        "car maintenance": "صيانة عربية",
        "insurance": "تأمين",
        "license & registration": "رخصة وتجديد",
        "tires": "كاوتش",
        "car wash": "غسيل العربية",
        "nursery": "حضانة",
        "supplies": "مستلزمات",
        "uniform": "يونيفورم",
        "bus": "باص",
        "activities": "أنشطة",
        "kids health": "صحة الأولاد",
        "swimming": "سباحة",
        "toys": "لعب",
        "lessons": "دروس",
        "pharmacy": "صيدلية",
        "dentist": "دكتور أسنان",
        "dental": "أسنان",
        "lab & tests": "تحاليل",
        "lab tests": "تحاليل",
        "doctors": "دكاترة",
        "school fees": "مصاريف المدرسة",
        "internet": "إنترنت",
        "electricity": "كهرباء",
        "water": "مياه",
        "gas": "غاز",
        "medicine": "دواء",
        "medical": "علاج وصحة",
        "doctor": "دكتور",
        "subscriptions": "اشتراكات",
        "streaming": "ستريمنج",
        "apps": "تطبيقات",
        "outings": "خروجات",
        "hobbies": "هوايات",
        "clothes": "لبس",
        "clothing": "لبس",
        "gifts": "هدايا",
        "gift": "هدية",
        "miscellaneous": "متفرقات",
        "home essentials": "حاجات البيت",
        "maid": "مساعدة البيت",
        "loan payment": "سداد قرض",
        "installment": "قسط",
        "credit card payment": "سداد كارت ائتمان",
        "buy now pay later": "اشتر دلوقتي وادفع بعدين",
        "club installments": "أقساط النادي",
        "wife pocket money": "مصروف البيت",
        "cigarettes": "سجاير",
        "personal spending": "مصاريف شخصية",
        "instapay fee": "رسوم إنستاباي",
        "transfer fee": "رسوم تحويل",
        "card fee": "رسوم كارت",
        "bank fees": "رسوم بنكية",
        "salary": "مرتب",
        "reimbursement": "استرداد",
        "bonus": "مكافأة",
        "business income": "دخل شغل",
        "other income": "دخل تاني",
        "installments": "أقساط",
        "sports": "رياضة",
        "equipment": "معدات",
        "software": "سوفت وير",
        "meals": "وجبات",
        "training": "تدريب",
        "office supplies": "مستلزمات مكتب",
        "charity": "صدقة",
        "donations": "تبرعات",
        "home help": "مساعدة البيت",
        "cleaning": "تنضيف",
        "repairs": "تصليحات",
        "security": "أمن",
        "property fees": "رسوم عقار",
        "mobile": "موبايل",
        "other": "أخرى",
        "food": "أكل",
        "vet": "بيطري",
        "grooming": "عناية",
        "flights": "طيران",
        "hotels": "فنادق",
        "documents": "مستندات"
    ]

}
