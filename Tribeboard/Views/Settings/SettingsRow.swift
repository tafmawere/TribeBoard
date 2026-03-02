import SwiftUI

struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var trailingValue: String? = nil
    var toggle: Binding<Bool>? = nil
    var showsChevron: Bool = false
    var foreground: Color = .primary
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .padding(.vertical, 4)
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 28, height: 28)
                .background(Color.gray.opacity(0.10))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(foreground)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if let toggle {
                Toggle("", isOn: toggle)
                    .labelsHidden()
                    .tint(Color(red: 0.388, green: 0.400, blue: 0.945))
            } else {
                if let trailingValue {
                    Text(trailingValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
