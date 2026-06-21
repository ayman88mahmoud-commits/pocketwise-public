import SwiftUI

enum PocketWiseSemanticColor: CaseIterable, Identifiable {
    case accounts
    case income
    case obligations
    case budgets
    case spending
    case categories
    case backupPrivacy
    case setup
    case warning
    case danger
    case success
    case creditCards
    case neutral

    var id: String {
        String(describing: self)
    }

    var tint: Color {
        switch self {
        case .accounts:
            return .blue
        case .income, .success:
            return .green
        case .obligations, .warning:
            return .orange
        case .budgets:
            return .indigo
        case .spending, .danger:
            return .red
        case .categories:
            return .purple
        case .backupPrivacy:
            return .teal
        case .setup:
            return .blue
        case .creditCards:
            return .purple
        case .neutral:
            return .secondary
        }
    }

    func softBackground(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .neutral:
            return Color(.secondarySystemGroupedBackground)
        default:
            return tint.opacity(colorScheme == .dark ? 0.24 : 0.12)
        }
    }

    func iconBadgeBackground(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .neutral:
            return Color(.tertiarySystemGroupedBackground)
        default:
            return tint.opacity(colorScheme == .dark ? 0.28 : 0.14)
        }
    }

    func borderColor(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .neutral:
            return Color.secondary.opacity(colorScheme == .dark ? 0.22 : 0.14)
        default:
            return tint.opacity(colorScheme == .dark ? 0.38 : 0.20)
        }
    }

    var defaultIconName: String {
        switch self {
        case .accounts:
            return "wallet.pass.fill"
        case .income:
            return "arrow.down.circle.fill"
        case .obligations:
            return "calendar.badge.clock"
        case .budgets:
            return "chart.pie.fill"
        case .spending:
            return "arrow.up.circle.fill"
        case .categories:
            return "square.grid.2x2.fill"
        case .backupPrivacy:
            return "lock.shield.fill"
        case .setup:
            return "sparkles"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .danger:
            return "xmark.octagon.fill"
        case .success:
            return "checkmark.seal.fill"
        case .creditCards:
            return "creditcard.fill"
        case .neutral:
            return "circle.fill"
        }
    }
}

enum PocketWiseTheme {
    static let compactCornerRadius: CGFloat = 10
    static let chipCornerRadius: CGFloat = 999
    static let cardCornerRadius: CGFloat = 16
    static let largeCardCornerRadius: CGFloat = 22
    static let iconBadgeSize: CGFloat = 36
    static let cardPadding: CGFloat = 16
    static let compactPadding: CGFloat = 12

    static var screenBackground: Color {
        Color(.systemGroupedBackground)
    }

    static var cardBackground: Color {
        Color(.systemBackground)
    }

    static var secondaryCardBackground: Color {
        Color(.secondarySystemGroupedBackground)
    }

    static var tertiaryCardBackground: Color {
        Color(.tertiarySystemGroupedBackground)
    }

    static func shadowColor(for colorScheme: ColorScheme) -> Color {
        Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06)
    }

    static func shadowRadius(for colorScheme: ColorScheme) -> CGFloat {
        colorScheme == .dark ? 14 : 10
    }
}

struct PocketWiseCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let semanticColor: PocketWiseSemanticColor?
    let padding: CGFloat
    let cornerRadius: CGFloat
    let showsBorder: Bool
    let showsShadow: Bool

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(PocketWiseTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if showsBorder {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                }
            }
            .shadow(
                color: showsShadow ? PocketWiseTheme.shadowColor(for: colorScheme) : .clear,
                radius: showsShadow ? PocketWiseTheme.shadowRadius(for: colorScheme) : 0,
                x: 0,
                y: showsShadow ? 5 : 0
            )
    }

    private var borderColor: Color {
        if let semanticColor {
            return semanticColor.borderColor(for: colorScheme)
        }

        return Color.secondary.opacity(colorScheme == .dark ? 0.18 : 0.10)
    }
}

extension View {
    func pocketWiseCard(
        semanticColor: PocketWiseSemanticColor? = nil,
        padding: CGFloat = PocketWiseTheme.cardPadding,
        cornerRadius: CGFloat = PocketWiseTheme.cardCornerRadius,
        showsBorder: Bool = false,
        showsShadow: Bool = false
    ) -> some View {
        modifier(
            PocketWiseCardStyle(
                semanticColor: semanticColor,
                padding: padding,
                cornerRadius: cornerRadius,
                showsBorder: showsBorder,
                showsShadow: showsShadow
            )
        )
    }
}

struct PocketWiseIconBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let systemName: String
    let semanticColor: PocketWiseSemanticColor
    var size: CGFloat = PocketWiseTheme.iconBadgeSize
    var cornerRadius: CGFloat = PocketWiseTheme.compactCornerRadius

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(semanticColor.tint)
            .frame(width: size, height: size)
            .background(semanticColor.iconBadgeBackground(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct PocketWiseChipStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let semanticColor: PocketWiseSemanticColor
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? semanticColor.tint : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(borderColor, lineWidth: isSelected ? 1 : 0)
            }
    }

    private var backgroundColor: Color {
        isSelected ? semanticColor.softBackground(for: colorScheme) : Color(.secondarySystemGroupedBackground)
    }

    private var borderColor: Color {
        isSelected ? semanticColor.borderColor(for: colorScheme) : .clear
    }
}

extension View {
    func pocketWiseChip(
        semanticColor: PocketWiseSemanticColor,
        isSelected: Bool = true
    ) -> some View {
        modifier(
            PocketWiseChipStyle(
                semanticColor: semanticColor,
                isSelected: isSelected
            )
        )
    }
}

struct PocketWiseInputFieldStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let semanticColor: PocketWiseSemanticColor
    let isProminent: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, isProminent ? 12 : 10)
            .padding(.vertical, isProminent ? 10 : 8)
            .background(inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: PocketWiseTheme.compactCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PocketWiseTheme.compactCornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: isProminent ? 1.2 : 1)
            }
    }

    private var inputBackground: Color {
        if isProminent {
            return semanticColor.softBackground(for: colorScheme)
        }

        return Color(.secondarySystemGroupedBackground)
    }

    private var borderColor: Color {
        isProminent
            ? semanticColor.borderColor(for: colorScheme)
            : Color.secondary.opacity(colorScheme == .dark ? 0.20 : 0.12)
    }
}

extension View {
    func pocketWiseInputField(
        semanticColor: PocketWiseSemanticColor = .neutral,
        isProminent: Bool = false
    ) -> some View {
        modifier(
            PocketWiseInputFieldStyle(
                semanticColor: semanticColor,
                isProminent: isProminent
            )
        )
    }
}
