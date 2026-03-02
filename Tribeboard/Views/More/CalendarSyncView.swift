import SwiftUI
import Combine
import EventKit
import UIKit

@MainActor
private final class CalendarSyncViewModel: ObservableObject {
    @Published var isEnabled: Bool
    @Published var statusText: String
    @Published var isRequesting: Bool
    @Published var lastSyncText: String?
    @Published var showError: Bool
    @Published var errorMessage: String

    private let service: CalendarSyncService

    init(service: CalendarSyncService) {
        self.service = service
        self.isEnabled = false
        self.statusText = "Not connected"
        self.isRequesting = false
        self.lastSyncText = nil
        self.showError = false
        self.errorMessage = ""
        refreshStatus()
    }

    var isAuthorized: Bool {
        service.authorizationState() == .authorized
    }

    var isDeniedOrRestricted: Bool {
        let state = service.authorizationState()
        return state == .denied || state == .restricted
    }

    func refreshStatus() {
        let state = service.authorizationState()
        switch state {
        case .authorized:
            isEnabled = true
            statusText = "Connected"
        case .denied:
            isEnabled = false
            statusText = "Access denied"
        case .restricted:
            isEnabled = false
            statusText = "Access restricted"
        case .notDetermined:
            isEnabled = false
            statusText = "Not connected"
        }
    }

    func connect() async {
        guard !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }

        let granted = await service.requestCalendarAccess()
        if granted {
            refreshStatus()
            return
        }

        refreshStatus()
        errorMessage = "Calendar access was not granted."
        showError = true
    }

    func syncNow() async {
        guard !isRequesting else { return }
        isRequesting = true
        defer { isRequesting = false }

        do {
            let selected = service.tribeBoardCalendar() ?? service.writableCalendars().first
            _ = try await service.syncNow(using: selected)
            lastSyncText = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct CalendarSyncView: View {
    @StateObject private var vm = CalendarSyncViewModel(service: CalendarSyncService())

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                explanationCard

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Status")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(vm.statusText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(vm.isAuthorized ? .green : .orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background((vm.isAuthorized ? Color.green : Color.orange).opacity(0.12))
                            .clipShape(Capsule())
                    }

                    if !vm.isAuthorized {
                        Button {
                            Task { await vm.connect() }
                        } label: {
                            HStack(spacing: 8) {
                                if vm.isRequesting {
                                    ProgressView()
                                }
                                Text("Connect Calendar")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color(red: 0.388, green: 0.400, blue: 0.945))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isRequesting)
                    } else {
                        Button {
                            Task { await vm.syncNow() }
                        } label: {
                            HStack(spacing: 8) {
                                if vm.isRequesting {
                                    ProgressView()
                                }
                                Text("Sync Now")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color(red: 0.388, green: 0.400, blue: 0.945))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.isRequesting)

                        if let lastSyncText = vm.lastSyncText {
                            Text("Last sync: \(lastSyncText)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if vm.isDeniedOrRestricted {
                        Text("Calendar access is disabled. Open Settings and allow Calendar access for TribeBoard.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Open Settings") {
                            openSystemSettings()
                        }
                        .font(.system(size: 14, weight: .semibold))
                    }
                }
                .padding(16)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(16)
        }
        .background(Color(red: 0.976, green: 0.980, blue: 0.984).ignoresSafeArea())
        .navigationTitle("Calendar Sync")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Calendar Sync", isPresented: $vm.showError) {
            Button("OK", role: .cancel) { vm.showError = false }
        } message: {
            Text(vm.errorMessage)
        }
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sync run plans to your calendar")
                .font(.system(size: 18, weight: .bold))
            Text("Calendar sync creates a dedicated TribeBoard calendar and exports planned run events so your family can see schedules in one place.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack {
        CalendarSyncView()
    }
}
