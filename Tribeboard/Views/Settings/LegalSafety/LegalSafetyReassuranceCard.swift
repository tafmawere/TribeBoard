import SwiftUI

struct LegalSafetyReassuranceCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LegalSafetyTheme.brandPurple)
                .frame(width: 36, height: 36)
                .background(LegalSafetyTheme.brandPurple.opacity(0.12))
                .clipShape(Circle())

            Text("Your privacy and safety are our top priorities. Thank you for being part of the TribeBoard family.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(LegalSafetyTheme.subtitleSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Image(systemName: "heart.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LegalSafetyTheme.brandPurple.opacity(0.85))
                .padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(LegalSafetyTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LegalSafetyTheme.cardCornerRadius, style: .continuous))
        .shadow(color: LegalSafetyTheme.cardShadow, radius: 12, x: 0, y: 4)
    }
}

#Preview {
    LegalSafetyReassuranceCard()
        .padding()
        .background(LegalSafetyTheme.screenBackground)
}
