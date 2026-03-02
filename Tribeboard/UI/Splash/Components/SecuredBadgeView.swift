import SwiftUI

struct SecuredBadgeView: View {
    let text: String

    init(text: String = SplashMockData.preview.securityMessage) {
        self.text = text
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.19, green: 0.43, blue: 0.95))

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(red: 0.62, green: 0.64, blue: 0.67))
                .tracking(0.6)
        }
    }
}

#Preview {
    SecuredBadgeView()
}
