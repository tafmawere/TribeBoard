import SwiftUI

struct HelpSupportView: View {
    @Environment(\.openURL) private var openURL
    @State private var expandedFAQIDs: Set<String> = []

    private let faqs: [FAQItem] = [
        FAQItem(
            id: "invite",
            question: "How do I invite another adult to the tribe?",
            answer: "Go to Tribe, tap Add member, then share your tribe code. They can join from the Join Tribe screen."
        ),
        FAQItem(
            id: "driver",
            question: "Why can’t I assign a run driver?",
            answer: "At least one adult needs Driver permission. Update their role in member management first."
        ),
        FAQItem(
            id: "missing-runs",
            question: "My scheduled runs are missing. What should I check?",
            answer: "Verify weekday selection, trip mode, and run times in each venue rule. Disabled schedules will not generate runs."
        ),
        FAQItem(
            id: "notifications",
            question: "How do I enable run notifications?",
            answer: "Open More, then Notifications, and confirm both app permissions and in-app notification settings are enabled."
        ),
        FAQItem(
            id: "location",
            question: "Location updates seem delayed. What can I do?",
            answer: "Ensure Location Sharing is enabled, battery saver is off, and TribeBoard has Always/While Using location permission."
        ),
        FAQItem(
            id: "account",
            question: "Can I use TribeBoard without adding photos?",
            answer: "Yes. Photos are optional for all members. The app will show avatar symbols or initials when no photo is set."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                faqCard
                contactSupportCard
                troubleshootingCard
                privacyAndSafetyCard
            }
            .padding(16)
        }
        .background(Color(red: 0.976, green: 0.980, blue: 0.984).ignoresSafeArea())
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var faqCard: some View {
        supportCard(title: "FAQs", icon: "questionmark.circle.fill") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(faqs) { faq in
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedFAQIDs.contains(faq.id) },
                            set: { isExpanded in
                                if isExpanded {
                                    expandedFAQIDs.insert(faq.id)
                                } else {
                                    expandedFAQIDs.remove(faq.id)
                                }
                            }
                        )
                    ) {
                        Text(faq.answer)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    } label: {
                        Text(faq.question)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    if faq.id != faqs.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var contactSupportCard: some View {
        supportCard(title: "Contact Support", icon: "envelope.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Need help with setup, scheduling, or account issues? Reach out to our support team.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    let messageBody = """
                    App: \(ExternalLinks.appDisplayName)
                    Version: \(ExternalLinks.appVersionBuildText)
                    iOS: \(UIDevice.current.systemVersion)

                    Describe your issue:
                    """
                    guard let url = ExternalLinks.supportEmailURL(
                        subject: "TribeBoard Support",
                        body: messageBody
                    ) else { return }
                    openURL(url)
                } label: {
                    actionRow(
                        title: "Email Support",
                        subtitle: ExternalLinks.supportEmail,
                        icon: "paperplane.fill"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var troubleshootingCard: some View {
        supportCard(title: "Troubleshooting", icon: "wrench.and.screwdriver.fill") {
            VStack(alignment: .leading, spacing: 10) {
                troubleshootingItem("Confirm the latest app version is installed.")
                troubleshootingItem("Review member permissions for driver/observer roles.")
                troubleshootingItem("Re-check venue rules, weekday selection, and trip times.")
                troubleshootingItem("Ensure notification and location permissions are enabled.")
                troubleshootingItem("Sign out and sign back in if sync appears stale.")
            }
        }
    }

    private var privacyAndSafetyCard: some View {
        supportCard(title: "Privacy & Safety", icon: "lock.shield.fill") {
            VStack(spacing: 8) {
                NavigationLink {
                    LegalSafetyView()
                } label: {
                    actionRow(
                        title: "Legal & Safety",
                        subtitle: "Policies, safety reporting, and account requests",
                        icon: "doc.text.magnifyingglass"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func supportCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
            }
            content()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func actionRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                .frame(width: 26, height: 26)
                .background(Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func troubleshootingItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FAQItem: Identifiable {
    let id: String
    let question: String
    let answer: String
}

#Preview {
    NavigationStack {
        HelpSupportView()
    }
}
