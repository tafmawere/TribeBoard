import SwiftUI

enum LoginV3Theme {
    static let indigo = Color(tribeHex: "5B6BE5")
    static let headline = Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255)
    static let secondary = Color(red: 156 / 255, green: 163 / 255, blue: 175 / 255)
    static let border = Color(red: 229 / 255, green: 231 / 255, blue: 235 / 255)
    static let ssoFill = Color(red: 249 / 255, green: 250 / 255, blue: 251 / 255)
}

struct LoginV3AppIcon: View {
    var body: some View {
        Image("TribeBoardColorLogo")
            .resizable()
            .scaledToFill()
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color(tribeHex: "5B6BE5").opacity(0.3), radius: 20, x: 0, y: 8)
    }
}

struct LoginV3EmailField: View {
    let placeholder: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder).foregroundStyle(LoginV3Theme.secondary)
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .keyboardType(.emailAddress)
        .textContentType(.emailAddress)
        .focused(isFocused)
        .font(.system(size: 15))
        .foregroundStyle(LoginV3Theme.headline)
        .tint(LoginV3Theme.indigo)
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isFocused.wrappedValue ? LoginV3Theme.indigo : LoginV3Theme.border, lineWidth: 1.5)
        }
        .overlay {
            if isFocused.wrappedValue {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(LoginV3Theme.indigo.opacity(0.12), lineWidth: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct LoginV3BorderedField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        Group {
            if isSecure {
                SecureField(
                    "",
                    text: $text,
                    prompt: Text(placeholder).foregroundStyle(LoginV3Theme.secondary)
                )
            } else {
                TextField(
                    "",
                    text: $text,
                    prompt: Text(placeholder).foregroundStyle(LoginV3Theme.secondary)
                )
            }
        }
        .textInputAutocapitalization(isSecure ? .never : .words)
        .autocorrectionDisabled()
        .keyboardType(keyboardType)
        .textContentType(textContentType)
        .focused(isFocused)
        .font(.system(size: 15))
        .foregroundStyle(LoginV3Theme.headline)
        .tint(LoginV3Theme.indigo)
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isFocused.wrappedValue ? LoginV3Theme.indigo : LoginV3Theme.border, lineWidth: 1.5)
        }
        .overlay {
            if isFocused.wrappedValue {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(LoginV3Theme.indigo.opacity(0.12), lineWidth: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct LoginV3ContinueButton: View {
    let title: String
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    private var isInteractive: Bool {
        !isDisabled && !isLoading
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isDisabled ? LoginV3Theme.indigo.opacity(0.35) : LoginV3Theme.indigo)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(!isInteractive)
        .buttonStyle(.plain)
    }
}

struct LoginV3EmailPill: View {
    let email: String
    var onChangeEmail: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LoginV3Theme.indigo)
            Text(email)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(LoginV3Theme.headline)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let onChangeEmail {
                Button("Change", action: onChangeEmail)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LoginV3Theme.indigo)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LoginV3Theme.ssoFill)
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(LoginV3Theme.border, lineWidth: 1)
        }
        .clipShape(Capsule(style: .continuous))
    }
}

struct LoginV3OrDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(LoginV3Theme.border)
                .frame(height: 1)
            Text("or")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LoginV3Theme.secondary)
            Rectangle()
                .fill(LoginV3Theme.border)
                .frame(height: 1)
        }
    }
}

struct LoginV3GoogleContinueButton: View {
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image("GoogleLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text("Continue with Google")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LoginV3Theme.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(LoginV3Theme.ssoFill)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(LoginV3Theme.border, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.7 : 1)
        .buttonStyle(.plain)
    }
}

struct LoginV3AppleContinueButton: View {
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "applelogo")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LoginV3Theme.headline)
                Text("Continue with Apple")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LoginV3Theme.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(LoginV3Theme.ssoFill)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(LoginV3Theme.border, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.7 : 1)
        .buttonStyle(.plain)
        .accessibilityLabel("Continue with Apple")
    }
}

struct LoginV3SSOIconButton: View {
    enum Provider {
        case google
        case apple
    }

    let provider: Provider
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                switch provider {
                case .google:
                    GoogleMarkIcon()
                case .apple:
                    Image(systemName: "apple.logo")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(LoginV3Theme.headline)
                }
            }
            .frame(width: 64, height: 52)
            .background(LoginV3Theme.ssoFill)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(LoginV3Theme.border, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.7 : 1)
        .buttonStyle(.plain)
    }
}

private struct GoogleMarkIcon: View {
    var body: some View {
        Image("GoogleLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
    }
}

struct LoginV3LegalFooter: View {
    var body: some View {
        Text(legalAttributedString)
            .font(.system(size: 10.5))
            .foregroundStyle(LoginV3Theme.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 28)
    }

    private var legalAttributedString: AttributedString {
        var result = AttributedString("By continuing, you agree to our ")

        var terms = AttributedString("Terms of Service")
        terms.link = URL(string: ExternalLinks.termsOfService)
        terms.foregroundColor = LoginV3Theme.indigo
        terms.font = .systemFont(ofSize: 10.5, weight: .semibold)
        result.append(terms)

        result.append(AttributedString(" and acknowledge our "))

        var privacy = AttributedString("Privacy Policy")
        privacy.link = URL(string: ExternalLinks.privacyPolicy)
        privacy.foregroundColor = LoginV3Theme.indigo
        privacy.font = .systemFont(ofSize: 10.5, weight: .semibold)
        result.append(privacy)

        result.append(AttributedString("."))
        return result
    }
}
