import SwiftUI

enum AccountVisualIdentity {

    private static var normalizedNameCache: [String: String] = [:]

    static func isInstaPayName(_ name: String) -> Bool {
        let normalized = normalizedName(name)
        return normalized.contains("instapay")
            || normalized.contains("insta pay")
            || normalized.contains("انستاباي")
    }

    static func isCashName(_ name: String) -> Bool {
        let normalized = normalizedName(name)
        return normalized.contains("cash")
            || normalized.contains("كاش")
    }

    static func isValuName(_ name: String) -> Bool {
        let normalized = normalizedName(name)
        return normalized.contains("valu")
            || normalized.contains("ڤاليو")
            || normalized.contains("فاليو")
            || normalized.contains("value")
    }

    static func warmUp(accounts: [Account]) {
        accounts.forEach { _ = normalizedName($0.name) }
    }

    static func systemImage(for account: Account) -> String {
        if isInstaPayName(account.name) {
            return "arrow.left.arrow.right.circle.fill"
        }

        switch account.type {
        case .cash:
            return "banknote.fill"
        case .bank:
            return "building.columns.fill"
        case .wallet:
            return "wallet.pass.fill"
        }
    }

    static func systemImage(forPaymentName name: String) -> String {
        if isCashName(name) {
            return "banknote.fill"
        }

        if isInstaPayName(name) {
            return "arrow.left.arrow.right.circle.fill"
        }

        if isValuName(name) {
            return "calendar.badge.clock"
        }

        let normalized = normalizedName(name)
        if normalized.contains("transfer") || normalized.contains("تحويل") {
            return "arrow.left.arrow.right.circle.fill"
        }

        if normalized.contains("installment") || normalized.contains("قسط") {
            return "calendar.badge.clock"
        }

        if normalized.contains("card") || normalized.contains("visa") || normalized.contains("master") {
            return "creditcard.fill"
        }

        return "square.grid.2x2.fill"
    }

    static func color(for account: Account) -> Color {
        if let appearanceColor = account.appearanceColor {
            return appearanceColor.swiftUIColor
        }

        switch account.type {
        case .cash:
            return ProviderAppearanceColor.green.swiftUIColor
        case .bank:
            return ProviderAppearanceColor.blue.swiftUIColor
        case .wallet:
            return ProviderAppearanceColor.teal.swiftUIColor
        }
    }

    static func color(forPaymentName name: String, fallback: ProviderAppearanceColor = .gray) -> Color {
        if isCashName(name) {
            return ProviderAppearanceColor.green.swiftUIColor
        }

        if isInstaPayName(name) {
            return ProviderAppearanceColor.indigo.swiftUIColor
        }

        if isValuName(name) {
            return ProviderAppearanceColor.orange.swiftUIColor
        }

        let normalized = normalizedName(name)
        if normalized.contains("visa") || normalized.contains("master") || normalized.contains("card") {
            return ProviderAppearanceColor.purple.swiftUIColor
        }

        if normalized.contains("transfer") || normalized.contains("تحويل") {
            return ProviderAppearanceColor.teal.swiftUIColor
        }

        if normalized.contains("installment") || normalized.contains("قسط") {
            return ProviderAppearanceColor.orange.swiftUIColor
        }

        return fallback.swiftUIColor
    }

    private static func normalizedName(_ value: String) -> String {
        if let cached = normalizedNameCache[value] {
            return cached
        }

        let normalized = value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        normalizedNameCache[value] = normalized
        return normalized
    }

}

extension ProviderAppearanceColor {

    var displayName: String { rawValue }

    var swiftUIColor: Color {
        switch self {
        case .blue:
            return .blue
        case .indigo:
            return .indigo
        case .purple:
            return .purple
        case .green:
            return .green
        case .mint:
            return .mint
        case .teal:
            return .teal
        case .orange:
            return .orange
        case .red:
            return .red
        case .pink:
            return .pink
        case .gray:
            return .gray
        }
    }
}

struct AccountVisualMark: View {

    let account: Account
    var size: CGFloat = 30

    var body: some View {
        ProviderAppearanceBadge(
            systemName: AccountVisualIdentity.systemImage(for: account),
            color: AccountVisualIdentity.color(for: account),
            size: size
        )
    }
}

struct AccountIdentityLabel: View {

    let account: Account
    var subtitle: String?
    var markSize: CGFloat = 28

    var body: some View {
        HStack(spacing: 8) {
            AccountVisualMark(account: account, size: markSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct AccountSelectedLabel: View {

    let account: Account?
    let placeholder: String
    var markSize: CGFloat = 26

    var body: some View {
        HStack(spacing: 8) {
            if let account {
                AccountVisualMark(account: account, size: markSize)

                Text(account.name)
                    .lineLimit(1)
            } else {
                Text(placeholder)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct AccountMenuPickerField: View {

    let title: String
    @Binding var selection: String
    let accounts: [Account]
    var placeholder: String = "Select account"
    var emptyTitle: String?
    var emptySelectionValue: String = ""
    var inactiveSubtitle: Bool = false

    private var selectedAccount: Account? {
        accounts.first { $0.name == selection }
    }

    var body: some View {
        Menu {
            if let emptyTitle {
                Button {
                    selection = emptySelectionValue
                } label: {
                    Text(emptyTitle)
                }
            }

            ForEach(accounts) { account in
                Button {
                    selection = account.name
                } label: {
                    HStack {
                        AccountIdentityLabel(
                            account: account,
                            subtitle: inactiveSubtitle && !account.isActive ? "Inactive" : nil,
                            markSize: 24
                        )

                        if selection == account.name {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                AccountSelectedLabel(
                    account: selectedAccount,
                    placeholder: selectedPlaceholder,
                    markSize: 26
                )
                .foregroundStyle(.primary)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var selectedPlaceholder: String {
        if selection == emptySelectionValue || selection.isEmpty {
            return placeholder
        }

        return selection
    }
}

struct NamedVisualMark: View {

    let name: String
    let fallbackSystemImage: String
    var size: CGFloat = 28
    var fallbackColor: Color = .secondary

    var body: some View {
        ProviderAppearanceBadge(
            systemName: fallbackSystemImage,
            color: fallbackColor,
            size: size
        )
    }
}

struct PaymentMethodVisualMark: View {

    let name: String
    var size: CGFloat = 28

    var body: some View {
        ProviderAppearanceBadge(
            systemName: AccountVisualIdentity.systemImage(forPaymentName: name),
            color: AccountVisualIdentity.color(forPaymentName: name),
            size: size
        )
    }
}

struct ProviderAppearanceBadge: View {

    let systemName: String
    let color: Color
    var size: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(color.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .stroke(color.opacity(0.28), lineWidth: 1)
            )
            .fixedSize()
    }
}

struct ProviderAppearanceColorPicker: View {

    let title: String
    @Binding var selection: ProviderAppearanceColor?
    var defaultColor: ProviderAppearanceColor

    private var effectiveSelection: ProviderAppearanceColor {
        selection ?? defaultColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8)], spacing: 8) {
                ForEach(ProviderAppearanceColor.allCases) { color in
                    Button {
                        selection = color
                    } label: {
                        VStack(spacing: 6) {
                            Circle()
                                .fill(color.swiftUIColor)
                                .frame(width: 22, height: 22)
                                .overlay {
                                    if effectiveSelection == color {
                                        Image(systemName: "checkmark")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                    }
                                }

                            Text(color.displayName)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(color.swiftUIColor.opacity(effectiveSelection == color ? 0.18 : 0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(color.swiftUIColor.opacity(effectiveSelection == color ? 0.48 : 0.16), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct PaymentMethodSelectedLabel: View {

    let title: String
    var identityName: String? = nil
    var markSize: CGFloat = 26

    var body: some View {
        HStack(spacing: 8) {
            PaymentMethodVisualMark(name: identityName ?? title, size: markSize)

            Text(title)
                .lineLimit(1)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct PaymentMethodMenuPickerField<Option: Hashable & Identifiable>: View {

    let title: String
    @Binding var selection: Option
    let options: [Option]
    let optionTitle: (Option) -> String
    var identityName: (Option) -> String

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    HStack {
                        PaymentMethodSelectedLabel(
                            title: optionTitle(option),
                            identityName: identityName(option),
                            markSize: 24
                        )

                        if selection == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                PaymentMethodSelectedLabel(
                    title: optionTitle(selection),
                    identityName: identityName(selection),
                    markSize: 26
                )
                .foregroundStyle(.primary)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
