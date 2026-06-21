import SwiftUI

struct TodaySectionTitle: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)

            Spacer()
        }
    }
}

struct TodayStatusBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(colorScheme == .dark ? 0.24 : 0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct TodayBudgetStatusPill: View {
    @Environment(\.colorScheme) private var colorScheme

    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(color)
            .background(color.opacity(colorScheme == .dark ? 0.22 : 0.12))
            .clipShape(Capsule())
    }
}

struct TodayCircleIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .frame(width: 34, height: 34)
                .background(PocketWiseTheme.secondaryCardBackground)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct TodayHeaderBalanceSummary: View {
    let title: String
    let value: String
    let actionText: String

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .trailing, spacing: 3) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(actionText)
                    .font(.caption2)
                    .foregroundStyle(PocketWiseSemanticColor.accounts.tint)
            }

            Image(systemName: "chevron.forward")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

struct TodayIconMessageRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let systemImage: String
    let message: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(colorScheme == .dark ? 0.24 : 0.12))
                .clipShape(Circle())

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TodaySourceMetricButton: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    var semanticColor: PocketWiseSemanticColor = .neutral

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                Image(systemName: "chevron.forward")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(semanticColor == .neutral ? PocketWiseSemanticColor.accounts.tint : semanticColor.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PocketWiseTheme.secondaryCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TodayChevronInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Image(systemName: "chevron.forward")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(PocketWiseTheme.secondaryCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TodayDetailMetricRow: View {
    let title: String
    let value: String
    let showsDisclosure: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Text(value)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.trailing)

                if showsDisclosure {
                    Image(systemName: "chevron.forward")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!showsDisclosure)
    }
}

struct TodayPrimaryActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)

                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)

                Spacer()

                Image(systemName: "chevron.forward")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(PocketWiseSemanticColor.spending.tint)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct TodaySmallMetricCard: View {
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(PocketWiseTheme.secondaryCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct TodaySafeUntilSummaryLine: View {
    let title: String
    let value: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(title):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct TodaySecondaryActionButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let icon: String
    var semanticColor: PocketWiseSemanticColor = .setup
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(semanticColor.tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(PocketWiseTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(semanticColor.borderColor(for: colorScheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TodayQuickAddTile: View {
    @Environment(\.colorScheme) private var colorScheme

    let name: String
    let subcategoryName: String
    let iconName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.headline)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(PocketWiseSemanticColor.spending.tint)

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(subcategoryName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(12)
            .frame(width: 170)
            .background(PocketWiseTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(PocketWiseSemanticColor.spending.borderColor(for: colorScheme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TodayRecentEventRow: View {
    let title: String
    let classification: String
    let paymentLabel: String?
    let amountText: String
    let dateText: String
    let iconName: String

    var body: some View {
        HStack(spacing: 12) {
            NamedVisualMark(
                name: title,
                fallbackSystemImage: iconName,
                size: 36
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(classification)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let paymentLabel {
                    Text(paymentLabel)
                        .pocketWiseChip(semanticColor: .neutral)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(amountText)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .pocketWiseCard(semanticColor: .spending, padding: 14, showsBorder: true)
    }
}

struct TodayAttentionRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(colorScheme == .dark ? 0.24 : 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
