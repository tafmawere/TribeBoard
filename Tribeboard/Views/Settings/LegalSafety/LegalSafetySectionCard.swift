import SwiftUI

struct LegalSafetySectionCard<Rows: View>: View {
    let title: String
    let accent: LegalSafetySectionAccent
    @ViewBuilder let rows: () -> Rows

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

            rows()
        }
        .background(LegalSafetyTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LegalSafetyTheme.cardCornerRadius, style: .continuous))
        .shadow(color: LegalSafetyTheme.cardShadow, radius: 12, x: 0, y: 4)
    }

    private var sectionHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: accent.headerIcon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accent.titleColor)

            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(accent.titleColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    LegalSafetySectionCard(title: "Legal", accent: .legal) {
        LegalSafetyRowButton(
            icon: "hand.raised.fill",
            title: "Privacy Policy",
            subtitle: "How we collect, use, and protect your data",
            accent: .legal
        ) {}
        LegalSafetyRowButton(
            icon: "doc.text.fill",
            title: "Terms of Service",
            subtitle: "Rules for using TribeBoard",
            accent: .legal,
            showsDivider: false
        ) {}
    }
    .padding()
    .background(LegalSafetyTheme.screenBackground)
}
