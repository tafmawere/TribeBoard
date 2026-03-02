import SwiftUI

struct QuickContactView: View {
    @Environment(\.openURL) private var openURL

    @State private var showUnsupportedAlert = false
    @State private var unsupportedMessage = ""

    private let driverContacts = NotificationMockData.driverContacts
    private let parentContacts = NotificationMockData.parentContacts

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NotificationStitchCard {
                    NotificationSectionHeading(
                        title: "Quick contact",
                        subtitle: "Tap to call your driver or parent contacts."
                    )
                }

                contactsSection(title: "Driver", contacts: driverContacts)
                contactsSection(title: "Parents", contacts: parentContacts)
            }
            .padding(16)
        }
        .background(NotificationTheme.background.ignoresSafeArea())
        .navigationTitle("Quick Contact")
        .alert("Call unavailable", isPresented: $showUnsupportedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(unsupportedMessage)
        }
    }

    @ViewBuilder
    private func contactsSection(title: String, contacts: [ContactShortcut]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NotificationTheme.textPrimary)

            ForEach(contacts) { contact in
                QuickContactButton(contact: contact) {
                    call(contact)
                }
            }
        }
    }

    private func call(_ contact: ContactShortcut) {
        guard let url = contact.telURL else {
            unsupportedMessage = "No valid phone number for \(contact.name)."
            showUnsupportedAlert = true
            return
        }

        openURL(url) { accepted in
            guard !accepted else { return }
            unsupportedMessage = "This device cannot place phone calls. UI-only shortcut shown."
            showUnsupportedAlert = true
        }
    }
}

#Preview {
    NavigationStack {
        QuickContactView()
    }
}
