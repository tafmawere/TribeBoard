import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @State private var showDiagnostics = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerCard
                linksCard
                diagnosticsCard
            }
            .padding(16)
        }
        .background(Color(red: 0.976, green: 0.980, blue: 0.984).ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.14))
                        .frame(width: 52, height: 52)
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(ExternalLinks.appDisplayName)
                        .font(.system(size: 20, weight: .bold))
                    Text(ExternalLinks.appVersionBuildText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text("TribeBoard helps families coordinate school and activity mobility with clear schedules, role-based collaboration, and safer run visibility.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var linksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Links")
                .font(.system(size: 16, weight: .bold))

            buttonRow(title: "Terms of Service", subtitle: ExternalLinks.termsOfService, icon: "doc.text.fill") {
                guard let url = URL(string: ExternalLinks.termsOfService) else { return }
                openURL(url)
            }

            buttonRow(title: "Privacy Policy", subtitle: ExternalLinks.privacyPolicy, icon: "hand.raised.fill") {
                guard let url = URL(string: ExternalLinks.privacyPolicy) else { return }
                openURL(url)
            }

            buttonRow(title: "Website", subtitle: ExternalLinks.website, icon: "globe") {
                guard let url = URL(string: ExternalLinks.website) else { return }
                openURL(url)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup("Diagnostics", isExpanded: $showDiagnostics) {
                VStack(alignment: .leading, spacing: 8) {
                    diagnosticRow("iOS", UIDevice.current.systemVersion)
                    diagnosticRow("Device", UIDevice.current.model)
                    diagnosticRow("App Build", ExternalLinks.appVersionBuildText)
                }
                .padding(.top, 8)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func buttonRow(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func diagnosticRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
