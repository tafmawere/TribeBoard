import SwiftUI

struct TermsAndConditionsView: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    @State private var hasAgreed = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms & Conditions")
                    .font(.system(size: 30, weight: .bold))
                    .accessibilityLabel("Terms and Conditions title")

                Text("Please review and accept to continue.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        termsSection(
                            title: "1. Introduction",
                            body: "These terms are placeholder content for product flow and UI testing only. They do not constitute legal advice."
                        )
                        termsSection(
                            title: "2. Use of the App",
                            body: "You agree to use TribeBoard responsibly and only for family coordination purposes supported by the app."
                        )
                        termsSection(
                            title: "3. Account Responsibility",
                            body: "You are responsible for the activity under your account and the accuracy of information you provide."
                        )
                        termsSection(
                            title: "4. Data & Privacy",
                            body: "Your data may be stored locally on your device for app functionality. This section is placeholder text and not a legal policy."
                        )
                        termsSection(
                            title: "5. Changes to Terms",
                            body: "Terms may be updated over time. Continued use after acceptance indicates agreement to the active version shown in the app."
                        )
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel("Terms and conditions content")

                Button {
                    hasAgreed.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: hasAgreed ? "checkmark.square.fill" : "square")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(hasAgreed ? Color(red: 0.388, green: 0.400, blue: 0.945) : Color.secondary)
                        Text("I have read and agree")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("I have read and agree checkbox")

                Button {
                    onAccept()
                } label: {
                    Text("I Agree & Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.388, green: 0.400, blue: 0.945))
                        .clipShape(Capsule())
                }
                .disabled(!hasAgreed)
                .opacity(hasAgreed ? 1 : 0.6)
                .accessibilityLabel("Agree and continue")

                Button(role: .destructive) {
                    onDecline()
                } label: {
                    Text("Decline")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .accessibilityLabel("Decline terms")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
            .background(Color(red: 0.976, green: 0.980, blue: 0.984).ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func termsSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.primary)
            Text(body)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    TermsAndConditionsView(
        onAccept: {},
        onDecline: {}
    )
}
