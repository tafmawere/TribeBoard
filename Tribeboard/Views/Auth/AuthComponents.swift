import SwiftUI

enum AuthTheme {
    static let background = Color(uiColor: .systemBackground)
    static let primary = Color(red: 0.388, green: 0.400, blue: 0.945) // #6366F1
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let cardBorder = Color(uiColor: .separator).opacity(0.35)
    static let cardFill = Color(uiColor: .secondarySystemBackground)
    static let fieldFill = Color(uiColor: .tertiarySystemBackground)
}

struct AuthScreenContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            AuthTheme.background.ignoresSafeArea()
            content
        }
    }
}

struct AuthCardField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AuthTheme.textPrimary)

            Group {
                if isSecure {
                    SecureField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundStyle(.secondary)
                    )
                } else {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundStyle(.secondary)
                    )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(.primary)
            .tint(AuthTheme.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AuthTheme.fieldFill)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AuthTheme.cardBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        }
    }
}

struct AuthPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(AuthTheme.primary)
            .clipShape(Capsule())
            .shadow(color: AuthTheme.primary.opacity(0.20), radius: 12, x: 0, y: 8)
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled || isLoading ? 0.7 : 1.0)
    }
}

struct AuthSecondaryOutlineButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AuthTheme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(AuthTheme.primary, lineWidth: 2)
                }
        }
    }
}

struct AuthInlineErrorView: View {
    let message: String?

    var body: some View {
        Group {
            if let message, !message.isEmpty {
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

struct AuthCheckboxRow: View {
    @Binding var isChecked: Bool
    let label: String

    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isChecked ? AuthTheme.primary : AuthTheme.textSecondary)

                Text(label)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AuthTheme.textPrimary)

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}

struct AuthDividerText: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color(uiColor: .separator))
                .frame(height: 1)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AuthTheme.textSecondary)
            Rectangle()
                .fill(Color(uiColor: .separator))
                .frame(height: 1)
        }
    }
}
