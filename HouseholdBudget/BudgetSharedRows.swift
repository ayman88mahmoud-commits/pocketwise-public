import SwiftUI

struct MonthStepperCard: View {

    @Environment(\.colorScheme) private var colorScheme

    let title: String
    @Binding var monthDate: Date
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                PocketWiseIconBadge(
                    systemName: "calendar",
                    semanticColor: .budgets,
                    size: 34,
                    cornerRadius: 10
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Text(BudgetDateHelper.monthTitle(monthDate))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        if isCurrentMonth {
                            Text(language == .arabicEgyptian ? "الشهر الحالي" : "Current month")
                                .pocketWiseChip(semanticColor: .budgets)
                        }
                    }
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    monthDate = BudgetDateHelper.addMonths(-1, to: monthDate)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 38, height: 34)
                }
                .buttonStyle(.bordered)

                Button {
                    monthDate = BudgetDateHelper.startOfMonth(for: Date())
                } label: {
                    Text(monthSubtitle)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(isCurrentMonth ? PocketWiseSemanticColor.budgets.tint : .secondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Button {
                    monthDate = BudgetDateHelper.addMonths(1, to: monthDate)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 38, height: 34)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
        .pocketWiseCard(
            semanticColor: isCurrentMonth ? .budgets : .neutral,
            padding: 14,
            cornerRadius: 14,
            showsBorder: true
        )
        .background {
            if isCurrentMonth {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PocketWiseSemanticColor.budgets.softBackground(for: colorScheme))
                    .blur(radius: 8)
                    .opacity(0.35)
            }
        }
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(monthDate, equalTo: Date(), toGranularity: .month)
    }

    private var monthSubtitle: String {
        let selected = BudgetDateHelper.startOfMonth(for: monthDate)
        let current = BudgetDateHelper.startOfMonth(for: Date())

        if Calendar.current.isDate(selected, equalTo: current, toGranularity: .month) {
            return language == .arabicEgyptian ? "الشهر ده" : "This Month"
        }

        if selected > current {
            let next = BudgetDateHelper.addMonths(1, to: current)
            if Calendar.current.isDate(selected, equalTo: next, toGranularity: .month) {
                return language == .arabicEgyptian ? "الشهر الجاي" : "Next Month"
            }

            return language == .arabicEgyptian ? "شهر مستقبلي" : "Future Month"
        }

        return language == .arabicEgyptian ? "شهر سابق" : "Past Month"
    }
}

struct BudgetMetricCard: View {

    @EnvironmentObject private var store: WalletStore

    let title: String
    let value: Double
    var color: Color = .primary
    var showsDisclosure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                if showsDisclosure {
                    Image(systemName: "chevron.forward")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(store.displayCurrency(value))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pocketWiseCard(
            semanticColor: .budgets,
            padding: 10,
            cornerRadius: 10,
            showsBorder: true
        )
    }
}

struct LabelValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }
}
