import SwiftUI

struct AuthLandingView: View {
    var body: some View {
        SignupView()
    }
}

#Preview {
    NavigationStack {
        AuthLandingView()
            .environmentObject(AppFlowState())
    }
}

private struct SocialAuthButton: View {
    let title: String
    let systemImage: String
    let isAppleStyle: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(isAppleStyle ? Color.primary : Color(uiColor: .secondarySystemBackground))
            .foregroundStyle(isAppleStyle ? Color(uiColor: .systemBackground) : Color.primary)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isAppleStyle ? Color.clear : Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
            }
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(isAppleStyle ? 0.18 : 0.06), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
