import SwiftUI

struct AppPreferencesView: View {

    @EnvironmentObject private var store: WalletStore
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var appLanguage: AppLanguage = .english
    @State private var forecastHorizonMonths = 12
    @State private var hideBalances = false
    @State private var incomeMode: IncomeMode = .unknown
    @State private var salaryResumeDate = Date()

    private var language: AppLanguage {
        store.appLanguage
    }

    var body: some View {
        Form {
            Section(language == .arabicEgyptian ? "الملف الشخصي" : "Profile") {
                TextField(language == .arabicEgyptian ? "اسمك" : "Display Name", text: $displayName)
                    .textInputAutocapitalization(.words)

                Text(language == .arabicEgyptian ? "الاسم ده هيظهر في تحية النهارده بس." : "This name is used only in the Today greeting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(language == .arabicEgyptian ? "اللغة" : "Language") {
                Picker(language == .arabicEgyptian ? "اللغة" : "App Language", selection: $appLanguage) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.displayName)
                            .tag(option)
                    }
                }
            }

            Section(language == .arabicEgyptian ? "التخطيط" : "Planning") {
                Picker(language == .arabicEgyptian ? "مدة التوقع" : "Forecast Horizon", selection: $forecastHorizonMonths) {
                    ForEach([6, 12, 18, 24], id: \.self) { months in
                        Text(language == .arabicEgyptian ? "\(months) شهر" : "\(months) months")
                            .tag(months)
                    }
                }
            }

            Section(language == .arabicEgyptian ? "إعدادات الدخل" : "Income Settings") {
                Picker(language == .arabicEgyptian ? "وضع الدخل" : "Income Mode", selection: $incomeMode) {
                    ForEach(IncomeMode.allCases) { mode in
                        Text(mode.title(language: language))
                            .tag(mode)
                    }
                }

                if incomeMode == .noSalaryUntilDate || incomeMode == .vacationUnpaidPeriod {
                    DatePicker(
                        incomeMode == .noSalaryUntilDate
                            ? (language == .arabicEgyptian ? "مفيش مرتب لحد" : "No salary until")
                            : (language == .arabicEgyptian ? "المرتب يرجع من" : "Salary resumes"),
                        selection: $salaryResumeDate,
                        displayedComponents: .date
                    )
                }

                Text(language == .arabicEgyptian ? "الإعداد ده بيوضح افتراضات اختبار الأمان، من غير ما يضيف دخل أو يغيّر الرصيد." : "This clarifies Runway Check assumptions without adding income or changing balances.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(AppText.privacy(language)) {
                Toggle(AppText.hideBalances(language), isOn: $hideBalances)

                Text(language == .arabicEgyptian ? "بيخفي الأرقام في الشاشات اللي بتعرض البيانات، من غير ما يغيّر أي قيمة محفوظة." : "Masks read-only amounts across the app without changing saved values.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        Spacer()
                        Text(language == .arabicEgyptian ? "حفظ" : "Save")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(language == .arabicEgyptian ? "الملف واللغة" : "Profile & App Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            displayName = store.displayName
            appLanguage = store.appLanguage
            forecastHorizonMonths = store.forecastHorizonMonths
            hideBalances = store.hideBalances
            incomeMode = store.incomeMode
            salaryResumeDate = store.salaryResumeDate ?? Date()
        }
    }

    private func save() {
        store.updateAppPreferences(
            displayName: displayName,
            appLanguage: appLanguage,
            forecastHorizonMonths: forecastHorizonMonths,
            hideBalances: hideBalances
        )
        store.updateIncomeSettings(
            incomeMode: incomeMode,
            salaryResumeDate: incomeMode == .noSalaryUntilDate || incomeMode == .vacationUnpaidPeriod ? salaryResumeDate : nil
        )
        dismiss()
    }
}
