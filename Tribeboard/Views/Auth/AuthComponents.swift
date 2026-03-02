import SwiftUI

enum AuthTheme {
    static let background = Color(red: 0.976, green: 0.980, blue: 0.984) // #F9FAFB
    static let primary = Color(red: 0.388, green: 0.400, blue: 0.945) // #6366F1
    static let textPrimary = Color(red: 0.098, green: 0.110, blue: 0.145)
    static let textSecondary = Color(red: 0.384, green: 0.459, blue: 0.612)
    static let cardBorder = Color.black.opacity(0.08)
    static let cardFill = Color.white.opacity(0.9)
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
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .font(.system(size: 16, weight: .regular))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AuthTheme.cardFill)
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
                        .fill(AuthTheme.background)
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
                    .foregroundStyle(AuthTheme.textSecondary)

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
                .fill(Color.black.opacity(0.10))
                .frame(height: 1)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AuthTheme.textSecondary)
            Rectangle()
                .fill(Color.black.opacity(0.10))
                .frame(height: 1)
        }
    }
}
