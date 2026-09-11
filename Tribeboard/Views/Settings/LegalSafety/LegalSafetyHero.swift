import SwiftUI

struct LegalSafetyHero: View {
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Review policies, report concerns, and manage account requests.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(LegalSafetyTheme.subtitleSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 6)

            heroIllustration
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(LegalSafetyTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LegalSafetyTheme.cardCornerRadius, style: .continuous))
        .shadow(color: LegalSafetyTheme.cardShadow, radius: 10, x: 0, y: 3)
    }

    private var heroIllustration: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            LegalSafetyTheme.brandPurple.opacity(0.16),
                            LegalSafetyTheme.brandPurple.opacity(0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)

            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(LegalSafetyTheme.brandPurple)
                .symbolRenderingMode(.hierarchical)

            Image(systemName: "person.3.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.95))
                .offset(y: 3)
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }
}

#Preview {
    LegalSafetyHero()
        .padding()
        .background(LegalSafetyTheme.screenBackground)
}
