import SwiftUI

enum AuthTheme {
    static let canvasBackground = Color(red: 0.975, green: 0.972, blue: 0.995)
    static let background = canvasBackground
    static let primary = Color(red: 0.388, green: 0.408, blue: 0.945)
    static let primaryGradientEnd = Color(red: 0.49, green: 0.36, blue: 0.98)
    static let headlineNavy = Color(red: 0.11, green: 0.13, blue: 0.22)
    static let textPrimary = headlineNavy
    static let textSecondary = Color(red: 0.42, green: 0.44, blue: 0.52)
    static let cardBorder = Color.black.opacity(0.06)
    static let cardFill = Color.white
    static let fieldFill = Color.white
    static let teal = Color(red: 0.18, green: 0.72, blue: 0.68)
    static let orange = Color(red: 0.96, green: 0.58, blue: 0.22)
    static let liveGreen = Color(red: 0.22, green: 0.78, blue: 0.48)

    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primaryGradientEnd],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct AuthBrandLockup: View {
    private let logoSize: CGFloat = 30

    var body: some View {
        HStack(spacing: 9) {
            Image("TribeBoardLogo")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
                .clipShape(RoundedRectangle(cornerRadius: logoSize * 0.24, style: .continuous))
                .shadow(color: AuthTheme.primary.opacity(0.18), radius: 6, y: 3)

            Text("TribeBoard")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AuthTheme.headlineNavy.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("TribeBoard")
    }
}

struct AuthLiveStatusPill: View {
    let name: String
    let status: String
    let dotColor: Color
    var breathe: Bool = false
    var reduceMotion: Bool = false

    private var dotScale: CGFloat {
        guard !reduceMotion, breathe else { return 1 }
        return 1.12
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
                .scaleEffect(dotScale)
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: breathe)

            Text("\(name) · \(status)")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AuthTheme.headlineNavy.opacity(0.78))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .background(Capsule().fill(Color.white.opacity(0.88)))
        }
        .clipShape(Capsule())
        .overlay {
            Capsule().strokeBorder(Color.white.opacity(0.65), lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
    }
}

struct AuthScreenContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            AuthTheme.canvasBackground.ignoresSafeArea()
            RadialGradient(
                colors: [
                    AuthTheme.primary.opacity(0.10),
                    AuthTheme.canvasBackground
                ],
                center: .top,
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()
            content
        }
    }
}

// MARK: - Marketing

struct AuthFeatureChip: View {
    let icon: String
    let iconBackground: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconBackground.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconBackground)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AuthTheme.headlineNavy)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AuthTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 168, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AuthTheme.cardBorder, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
    }
}

// MARK: - Form chrome

struct AuthCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .strokeBorder(AuthTheme.cardBorder, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.09), radius: 36, x: 0, y: 16)
    }
}

struct AuthSegmentedControl: View {
    @Binding var authMode: AuthMode

    var body: some View {
        HStack(spacing: 0) {
            segmentButton(title: "Sign In", mode: .signIn)
            segmentButton(title: "Sign Up", mode: .signUp)
        }
        .padding(4)
        .background(Color(red: 0.94, green: 0.945, blue: 0.97))
        .clipShape(Capsule())
    }

    private func segmentButton(title: String, mode: AuthMode) -> some View {
        let isSelected = authMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                authMode = mode
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? AuthTheme.primary : AuthTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

enum AuthMode: Hashable {
    case signIn
    case signUp

    var buttonTitle: String {
        switch self {
        case .signIn: return "Continue"
        case .signUp: return "Create Account"
        }
    }
}

struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    @Binding var isPasswordVisible: Bool

    init(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        isSecure: Bool = false,
        isPasswordVisible: Binding<Bool> = .constant(false)
    ) {
        self.icon = icon
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.isSecure = isSecure
        self._isPasswordVisible = isPasswordVisible
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AuthTheme.primary.opacity(0.85))
                .frame(width: 22)

            Group {
                if isSecure && !isPasswordVisible {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(keyboardType)
                }
            }
            .font(.system(size: 16))
            .foregroundStyle(AuthTheme.headlineNavy)
            .tint(AuthTheme.primary)

            if isSecure {
                Button {
                    isPasswordVisible.toggle()
                } label: {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AuthTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(AuthTheme.fieldFill)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AuthTheme.cardBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct AuthAppleSignInButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.primary)
                } else {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 18, weight: .semibold))
                }
                Text("Continue with Apple")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
            }
            .clipShape(Capsule())
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled || isLoading ? 0.7 : 1)
        .buttonStyle(.plain)
    }
}

struct AuthLegalFooter: View {
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AuthTheme.primary.opacity(0.7))
                .padding(.top, 1)

            Text(legalAttributedString)
                .font(.system(size: 11))
                .foregroundStyle(AuthTheme.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var legalAttributedString: AttributedString {
        var result = AttributedString("By continuing, you agree to our ")

        var terms = AttributedString("Terms of Service")
        terms.link = URL(string: ExternalLinks.termsOfService)
        terms.foregroundColor = AuthTheme.primary
        terms.font = .systemFont(ofSize: 11, weight: .semibold)
        result.append(terms)

        result.append(AttributedString(" and "))

        var privacy = AttributedString("Privacy Policy")
        privacy.link = URL(string: ExternalLinks.privacyPolicy)
        privacy.foregroundColor = AuthTheme.primary
        privacy.font = .systemFont(ofSize: 11, weight: .semibold)
        result.append(privacy)

        result.append(AttributedString("."))
        return result
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
            .background(AuthTheme.primaryGradient)
            .clipShape(Capsule())
            .shadow(color: AuthTheme.primary.opacity(0.28), radius: 14, x: 0, y: 8)
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled || isLoading ? 0.7 : 1.0)
    }
}

struct AuthSecondaryOutlineButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(AuthTheme.primary)
                }
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
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
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled || isLoading ? 0.7 : 1.0)
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
