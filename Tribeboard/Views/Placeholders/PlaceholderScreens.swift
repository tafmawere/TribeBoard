import SwiftUI

struct MyRunsView: View {
    var body: some View {
        EmptyStateView(
            icon: "car.fill",
            title: "My Runs",
            message: "This branch does not include the final MyRuns screen yet.",
            primaryButtonTitle: "Back to Shell"
        )
    }
}

struct RunFocusView: View {
    var body: some View {
        EmptyStateView(
            icon: "map.fill",
            title: "Run Focus",
            message: "Run Focus UI placeholder for shell navigation.",
            primaryButtonTitle: "OK"
        )
    }
}

struct DriverFocusModeView: View {
    var body: some View {
        EmptyStateView(
            icon: "steeringwheel",
            title: "Driver Focus",
            message: "Driver execution cockpit placeholder.",
            primaryButtonTitle: "OK"
        )
    }
}

struct ObserverTrackingView: View {
    var body: some View {
        EmptyStateView(
            icon: "location.viewfinder",
            title: "Observer Tracking",
            message: "Live read-only tracking placeholder.",
            primaryButtonTitle: "OK"
        )
    }
}

struct RunScheduledConfirmationView: View {
    var body: some View {
        EmptyStateView(
            icon: "checkmark.seal.fill",
            title: "Run Scheduled",
            message: "Run scheduled confirmation placeholder.",
            primaryButtonTitle: "Done"
        )
    }
}

struct ScheduleDeleteConfirmationView: View {
    @State private var showingDeleteSheet = false

    var body: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                icon: "trash.fill",
                title: "Delete Confirmation",
                message: "Open a confirmation dialog for schedule deletion.",
                primaryButtonTitle: "Open Dialog"
            ) {
                showingDeleteSheet = true
            }
        }
        .confirmationDialog(
            "Delete schedule?",
            isPresented: $showingDeleteSheet,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                // UI-only placeholder
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is a UI-only confirmation placeholder.")
        }
    }
}

struct CancelRunDemoHostView: View {
    @State private var showingSheet = false
    @State private var reason = ""

    var body: some View {
        VStack(spacing: 16) {
            EmptyStateView(
                icon: "xmark.circle.fill",
                title: "Cancel Run Demo",
                message: reason.isEmpty ? "Open cancel modal preview." : "Last reason: \(reason)",
                primaryButtonTitle: "Open Cancel Modal"
            ) {
                showingSheet = true
            }
        }
        .sheet(isPresented: $showingSheet) {
            CancelRunConfirmView { selectedReason in
                reason = selectedReason
            }
        }
    }
}

struct ProfileRolesEntryView: View {
    @StateObject private var store = TribeStore(demoFlow: true)

    var body: some View {
        Group {
            if let first = store.members.first {
                MemberProfileView(store: store, memberID: first.id)
            } else {
                EmptyStateView(
                    icon: "person.3.fill",
                    title: "Profile & Roles",
                    message: "No members in demo store.",
                    primaryButtonTitle: "OK"
                )
            }
        }
    }
}

struct MemberProfileEntryView: View {
    let memberId: String
    @StateObject private var store = TribeStore(demoFlow: true)

    var body: some View {
        Group {
            if let member = resolvedMember {
                MemberProfileView(store: store, memberID: member.id)
            } else {
                EmptyStateView(
                    icon: "person.crop.circle.badge.exclamationmark",
                    title: "Profile & Roles",
                    message: "TODO: implement member profile mapping for id \(memberId)",
                    primaryButtonTitle: "OK"
                )
            }
        }
    }

    private var resolvedMember: TribeMember? {
        if let id = UUID(uuidString: memberId) {
            return store.members.first(where: { $0.id == id }) ?? store.members.first
        }
        return store.members.first
    }
}

struct RolesAndPermissionsView: View {
    let memberId: String

    var body: some View {
        EmptyStateView(
            icon: "checkmark.shield.fill",
            title: "Roles & Permissions",
            message: "TODO: implement roles and permissions screen for member \(memberId)",
            primaryButtonTitle: "OK"
        )
        .navigationTitle("Roles & Permissions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HomeHubView: View {
    var body: some View {
        EmptyStateView(
            icon: "house.fill",
            title: "Home Hub",
            message: "TODO: implement HomeDashboardView integration",
            primaryButtonTitle: "OK"
        )
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FamilyHubPlaceholderView: View {
    var body: some View {
        EmptyStateView(
            icon: "person.3.fill",
            title: "Family",
            message: "TODO: implement FamilyHubView integration",
            primaryButtonTitle: "OK"
        )
        .navigationTitle("Family")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ScheduleDetailPlaceholderView: View {
    let scheduleId: String

    var body: some View {
        EmptyStateView(
            icon: "calendar.badge.clock",
            title: "Schedule Detail",
            message: "TODO: implement schedule detail routing for \(scheduleId)",
            primaryButtonTitle: "OK"
        )
        .navigationTitle("Schedule Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SafetyPrivacyView: View {
    var body: some View {
        List {
            NavigationLink("Location Sharing") {
                LocationSharingSettingsView()
            }
            NavigationLink("Permissions / Consent") {
                PermissionsConsentView()
            }
            NavigationLink("Emergency Contacts") {
                EmergencyContactsView()
            }
        }
        .navigationTitle("Safety & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DemoToolsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                EmptyStateView(
                    icon: "hammer.fill",
                    title: "Demo Tools",
                    message: "TODO: implement demo diagnostics and tooling.",
                    primaryButtonTitle: "OK"
                )
                .frame(height: 260)

                LoadingStateView()
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                ErrorStateView(kind: .runNotFound)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(16)
        }
        .background(GeneralUXTheme.background.ignoresSafeArea())
        .navigationTitle("Demo Tools")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct RunCreationSheetPlaceholder: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            EmptyStateView(
                icon: "plus.circle.fill",
                title: "Run Creation",
                message: "TODO: implement run creation flow sheet",
                primaryButtonTitle: "Close"
            ) {
                onDismiss()
            }
            .navigationTitle("Create Run")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ScheduleEditorDestinationPlaceholder: View {
    let scheduleId: String?

    var body: some View {
        EmptyStateView(
            icon: "square.and.pencil",
            title: "Schedule Editor",
            message: "TODO: open editor for \(scheduleId ?? "new schedule")",
            primaryButtonTitle: "OK"
        )
        .navigationTitle("Schedule Editor")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ShellMessageErrorView: View {
    let message: String

    var body: some View {
        ErrorStateView(kind: .runNotFound, retryButtonTitle: "Retry")
            .overlay(alignment: .bottom) {
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(GeneralUXTheme.textSecondary)
                    .padding(.bottom, 28)
            }
            .navigationTitle("Error")
            .navigationBarTitleDisplayMode(.inline)
    }
}
