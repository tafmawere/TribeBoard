import SwiftUI

struct QuickContactView: View {
    @Environment(\.openURL) private var openURL

    @State private var showUnsupportedAlert = false
    @State private var unsupportedMessage = ""

    let driverContacts: [ContactShortcut]
    let parentContacts: [ContactShortcut]

    init(
        driverContacts: [ContactShortcut] = [],
        parentContacts: [ContactShortcut] = []
    ) {
        self.driverContacts = driverContacts
        self.parentContacts = parentContacts
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NotificationStitchCard {
                    NotificationSectionHeading(
                        title: "Quick contact",
                        subtitle: "Tap to call your driver or parent contacts."
                    )
                }

                if driverContacts.isEmpty && parentContacts.isEmpty {
                    NotificationStitchCard {
                        VStack(spacing: 8) {
                            Text("No saved numbers")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(NotificationTheme.textPrimary)
                            Text("Household contacts with a phone number will show here.")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(NotificationTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    contactsSection(title: "Driver", contacts: driverContacts)
                    contactsSection(title: "Family", contacts: parentContacts)
                }
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

            if contacts.isEmpty {
                Text("None saved")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(NotificationTheme.textSecondary)
            } else {
                ForEach(contacts) { contact in
                    QuickContactButton(contact: contact) {
                        call(contact)
                    }
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
        QuickContactView(
            driverContacts: NotificationMockData.driverContacts,
            parentContacts: NotificationMockData.parentContacts
        )
    }
}
