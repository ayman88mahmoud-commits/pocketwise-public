import SwiftUI

struct StartRealUseChecklistView: View {

    @EnvironmentObject private var store: WalletStore

    private var checklistItems: [StartRealUseChecklistItem] {
        if store.appLanguage == .arabicEgyptian {
            return [
                StartRealUseChecklistItem(title: "صدّر نسخة احتياطية قبل البداية", detail: "خلي معاك نسخة نضيفة قبل ما تدخل بيانات الشهر الحقيقي."),
                StartRealUseChecklistItem(title: "راجع أرصدة الحسابات", detail: "راجع الكاش، البنوك، المحافظ، وأي حسابات نشطة."),
                StartRealUseChecklistItem(title: "راجع البنود والبنود الفرعية", detail: "اتأكد إن البنود اللي هتستخدمها واضحة ومفعّلة."),
                StartRealUseChecklistItem(title: "جهّز ميزانية الشهر", detail: "دخل المخطط للشهر الجديد قبل ما تبدأ الصرف اليومي."),
                StartRealUseChecklistItem(title: "انسخ ميزانية الشهر الجاي لو ينفع", detail: "استخدم نسخ الميزانية لو الشهر الجاي شبه الحالي."),
                StartRealUseChecklistItem(title: "راجع المدفوعات المتكررة", detail: "إيجار، اشتراكات، مدرسة، وأي التزامات ثابتة."),
                StartRealUseChecklistItem(title: "راجع الأقساط / Valu", detail: "اتأكد من الباقي، القسط الشهري، والمعاد الجاي."),
                StartRealUseChecklistItem(title: "أضف الدخل المتوقع", detail: "عشان التوقعات واختبار الأمان يبقوا أقرب للواقع."),
                StartRealUseChecklistItem(title: "أضف الالتزامات المعروفة", detail: "أي مصاريف جاية عارفها حطها في الخطة."),
                StartRealUseChecklistItem(title: "اختياري: دخل الشهور القديمة", detail: "استخدم ملخص الشهور القديمة كإجماليات بس."),
                StartRealUseChecklistItem(title: "صدّر نسخة تانية بعد التجهيز", detail: "خلي معاك نسخة بعد ما تخلص إعداد الشهر.")
            ]
        }

        return [
            StartRealUseChecklistItem(title: "Export a backup before starting", detail: "Use Manual Backup so you have a clean copy before entering real month-start data."),
            StartRealUseChecklistItem(title: "Verify account balances", detail: "Check Cash, bank accounts, wallets, and any other active accounts."),
            StartRealUseChecklistItem(title: "Review categories and subcategories", detail: "Make sure the categories you plan to use this month are active and clear."),
            StartRealUseChecklistItem(title: "Set up the current month budget", detail: "Enter planned amounts for the new month before daily spending starts."),
            StartRealUseChecklistItem(title: "Copy or prefill next month if useful", detail: "Use Monthly Budget copy when the next month should start from the same plan."),
            StartRealUseChecklistItem(title: "Check recurring payments", detail: "Review rent, subscriptions, school fees, and other recurring obligations."),
            StartRealUseChecklistItem(title: "Check installment plans", detail: "Confirm Valu or installment plans, remaining payments, and next due dates."),
            StartRealUseChecklistItem(title: "Add expected income", detail: "Add known income so runway and forecast reflect the month ahead."),
            StartRealUseChecklistItem(title: "Add known future obligations", detail: "Add any planned future expenses that should appear in the timeline."),
            StartRealUseChecklistItem(title: "Optional: enter past months", detail: "Use Past Month Fast Logging for summary-only historical totals."),
            StartRealUseChecklistItem(title: "Export another backup after setup", detail: "Keep a clean post-setup backup before starting real daily use.")
        ]
    }

    var body: some View {
        List {
            Section {
                Text(store.appLanguage == .arabicEgyptian ? "راجع الخطوات قبل تسجيل شهر جديد." : "Review these steps before tracking a new month.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section(store.appLanguage == .arabicEgyptian ? "قبل ما تبدأ" : "Before You Start") {
                ForEach(checklistItems) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)

                            Text(item.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(store.appLanguage == .arabicEgyptian ? "قائمة بداية الشهر" : "Month Start Checklist")
    }
}

private struct StartRealUseChecklistItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}
