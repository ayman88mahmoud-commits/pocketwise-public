import SwiftUI

struct GlobalSearchRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let detail: String?
    let badge: String
    let dateText: String?
    var account: Account? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let account {
                AccountVisualMark(account: account, size: 34)
            } else {
                NamedVisualMark(
                    name: title,
                    fallbackSystemImage: icon,
                    size: 34
                )
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(badge)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 4) {
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if let dateText {
                    Text(dateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 5)
    }
}
