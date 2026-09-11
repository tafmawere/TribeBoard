import SwiftUI

struct LegalSafetyView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LegalSafetyTheme.sectionSpacing) {
                LegalSafetyHero()

                LegalSafetySectionCard(title: "Legal", accent: .legal) {
                    LegalSafetyRowButton(
                        icon: "hand.raised.fill",
                        title: "Privacy Policy",
                        subtitle: "How we protect your data",
                        accent: .legal
                    ) {
                        openPolicy(ExternalLinks.privacyPolicy)
                    }

                    LegalSafetyRowButton(
                        icon: "doc.text.fill",
                        title: "Terms of Service",
                        subtitle: "Rules for using TribeBoard",
                        accent: .legal
                    ) {
                        openPolicy(ExternalLinks.termsOfService)
                    }

                    LegalSafetyRowButton(
                        icon: "globe.americas.fill",
                        title: "Cookie Policy",
                        subtitle: "How we use cookies on our website",
                        accent: .legal,
                        showsDivider: false
                    ) {
                        openPolicy(ExternalLinks.cookiePolicy)
                    }
                }

                LegalSafetySectionCard(title: "Safety", accent: .safety) {
                    LegalSafetyRowButton(
                        icon: "figure.and.child.holdinghands",
                        title: "Child Safety Policy",
                        subtitle: "Keeping children safe on TribeBoard",
                        accent: .safety
                    ) {
                        openPolicy(ExternalLinks.childSafetyPolicy)
                    }

                    LegalSafetyRowButton(
                        icon: "person.3.fill",
                        title: "Community Guidelines",
                        subtitle: "How we build a respectful community",
                        accent: .safety
                    ) {
                        openPolicy(ExternalLinks.communityGuidelines)
                    }

                    LegalSafetyRowButton(
                        icon: "exclamationmark.shield.fill",
                        title: "Report Safety Concern",
                        subtitle: ExternalLinks.securityEmail,
                        accent: .alert,
                        showsDivider: false
                    ) {
                        openSafetyConcernEmail()
                    }
                }

                LegalSafetySectionCard(title: "Account", accent: .account) {
                    NavigationLink {
                        DeleteAccountView()
                    } label: {
                        LegalSafetyRow(
                            icon: "trash.fill",
                            title: "Delete My Account",
                            subtitle: "Permanently remove your account and data",
                            accent: .danger
                        )
                    }
                    .buttonStyle(.plain)

                    LegalSafetyRowButton(
                        icon: "envelope.fill",
                        title: "Contact Support",
                        subtitle: ExternalLinks.supportEmail,
                        accent: .support,
                        showsDivider: false
                    ) {
                        openSupportEmail()
                    }
                }

                LegalSafetyReassuranceCard()
            }
            .padding(.horizontal, LegalSafetyTheme.horizontalPadding)
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .background(LegalSafetyTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Legal & Safety")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: LegalSafetyTheme.tabBarClearance)
        }
    }

    private func openPolicy(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        openURL(url)
    }

    private func openSupportEmail() {
        let body = """
        App: \(ExternalLinks.appDisplayName)
        Version: \(ExternalLinks.appVersionBuildText)
        iOS: \(UIDevice.current.systemVersion)

        How can we help?
        """
        guard let url = ExternalLinks.supportEmailURL(body: body) else { return }
        openURL(url)
    }

    private func openSafetyConcernEmail() {
        let body = """
        App: \(ExternalLinks.appDisplayName)
        Version: \(ExternalLinks.appVersionBuildText)

        Please describe the safety concern:
        """
        guard let url = ExternalLinks.securityConcernEmailURL(body: body) else { return }
        openURL(url)
    }
}

#Preview {
    NavigationStack {
        LegalSafetyView()
    }
}
