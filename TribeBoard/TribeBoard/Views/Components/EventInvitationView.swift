import SwiftUI
import SwiftData

/// View for managing event invitations and RSVPs
struct EventInvitationView: View {
    let event: CalendarEvent
    let currentUserId: UUID
    
    @StateObject private var coordinationService: FamilyEventCoordinationService
    @State private var invitations: [CalendarEventInvitation] = []
    @State private var rsvpSummary: EventRSVPSummary?
    @State private var showingInviteSheet = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private var canInviteUsers: Bool {
        // Check if current user can invite others to this event
        event.createdBy == currentUserId || event.privacyLevel == .familyShared
    }
    
    init(event: CalendarEvent, currentUserId: UUID, modelContext: ModelContext) {
        self.event = event
        self.currentUserId = currentUserId
        let permissionManager = CalendarPermissionManager(modelContext: modelContext)
        self._coordinationService = StateObject(wrappedValue: FamilyEventCoordinationService(
            modelContext: modelContext,
            permissionManager: permissionManager
        ))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            headerSection
            
            if isLoading {
                loadingSection
            } else if let errorMessage = errorMessage {
                errorSection(errorMessage)
            } else {
                // RSVP Summary
                if let summary = rsvpSummary {
                    rsvpSummarySection(summary)
                }
                
                // Invitations list
                invitationsListSection
                
                // Invite actions
                if canInviteUsers {
                    inviteActionsSection
                }
            }
        }
        .onAppear {
            loadInvitations()
        }
        .sheet(isPresented: $showingInviteSheet) {
            SendEventInvitationView(
                event: event,
                currentUserId: currentUserId,
                coordinationService: coordinationService
            ) {
                loadInvitations()
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "envelope.badge.person.crop")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("Event Invitations")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if canInviteUsers {
                    Button("Invite") {
                        showingInviteSheet = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            Text("Manage invitations and track RSVPs for '\(event.title)'")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading invitations...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundColor(.orange)
            
            Text("Invitation Error")
                .font(.headline)
                .fontWeight(.medium)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                loadInvitations()
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func rsvpSummarySection(_ summary: EventRSVPSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RSVP Summary")
                .font(.headline)
                .fontWeight(.medium)
            
            // Response statistics
            HStack(spacing: 16) {
                rsvpStatCard("Accepted", count: summary.accepted, color: .green, icon: "checkmark.circle.fill")
                rsvpStatCard("Declined", count: summary.declined, color: .red, icon: "xmark.circle.fill")
                rsvpStatCard("Maybe", count: summary.tentative, color: .yellow, icon: "questionmark.circle.fill")
                rsvpStatCard("Pending", count: summary.pending, color: .orange, icon: "clock.fill")
            }
            
            // Response rate
            if summary.totalInvited > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Response Rate")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(summary.responseRate * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    ProgressView(value: summary.responseRate)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func rsvpStatCard(_ title: String, count: Int, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var invitationsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invitations (\(invitations.count))")
                .font(.headline)
                .fontWeight(.medium)
            
            if invitations.isEmpty {
                EmptyStateView(
                    icon: "envelope.open",
                    title: "No Invitations",
                    message: "No invitations have been sent for this event yet."
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(invitations, id: \.id) { invitation in
                        InvitationRowView(
                            invitation: invitation,
                            isCurrentUser: invitation.invitedUserId == currentUserId,
                            onRespond: { response, message in
                                respondToInvitation(invitation, response: response, message: message)
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var inviteActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invite Actions")
                .font(.headline)
                .fontWeight(.medium)
            
            Button(action: {
                showingInviteSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text("Send New Invitations")
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private func loadInvitations() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedInvitations = try coordinationService.getEventInvitations(eventId: event.id)
                let summary = try coordinationService.getEventRSVPSummary(eventId: event.id)
                
                await MainActor.run {
                    self.invitations = fetchedInvitations
                    self.rsvpSummary = summary
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func respondToInvitation(
        _ invitation: CalendarEventInvitation,
        response: EventResponseStatus,
        message: String?
    ) {
        Task {
            do {
                try coordinationService.respondToInvitation(
                    invitationId: invitation.id,
                    response: response,
                    message: message
                )
                
                await MainActor.run {
                    loadInvitations()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

/// Individual invitation row view
struct InvitationRowView: View {
    let invitation: CalendarEventInvitation
    let isCurrentUser: Bool
    let onRespond: (EventResponseStatus, String?) -> Void
    
    @State private var showingResponseSheet = false
    @State private var selectedResponse: EventResponseStatus = .pending
    @State private var responseMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // User info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("User \(invitation.invitedUserId.uuidString.prefix(8))...")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if isCurrentUser {
                            Text("(You)")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("Invited \(invitation.invitedAt, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Response status
                responseStatusBadge
            }
            
            // Invitation message
            if let message = invitation.invitationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            // Response message
            if let responseMessage = invitation.responseMessage {
                HStack {
                    Image(systemName: "quote.bubble.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(responseMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.top, 4)
            }
            
            // Response actions (for current user)
            if isCurrentUser && invitation.isPending {
                HStack(spacing: 12) {
                    responseButton("Accept", status: .accepted, color: .green)
                    responseButton("Decline", status: .declined, color: .red)
                    responseButton("Maybe", status: .tentative, color: .yellow)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .sheet(isPresented: $showingResponseSheet) {
            RSVPResponseView(
                invitation: invitation,
                selectedResponse: $selectedResponse,
                responseMessage: $responseMessage
            ) {
                onRespond(selectedResponse, responseMessage.isEmpty ? nil : responseMessage)
                showingResponseSheet = false
            }
        }
    }
    
    private var responseStatusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: invitation.responseStatus.icon)
                .font(.caption)
                .foregroundColor(Color(invitation.responseStatus.color))
            
            Text(invitation.responseStatus.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(invitation.responseStatus.color).opacity(0.1))
        .cornerRadius(6)
    }
    
    private func responseButton(_ title: String, status: EventResponseStatus, color: Color) -> some View {
        Button(action: {
            selectedResponse = status
            showingResponseSheet = true
        }) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(color)
                .cornerRadius(6)
        }
    }
}

/// View for responding to an RSVP
struct RSVPResponseView: View {
    let invitation: CalendarEventInvitation
    @Binding var selectedResponse: EventResponseStatus
    @Binding var responseMessage: String
    let onSubmit: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Response") {
                    Picker("Your Response", selection: $selectedResponse) {
                        ForEach(EventResponseStatus.allCases, id: \.self) { status in
                            HStack {
                                Image(systemName: status.icon)
                                    .foregroundColor(Color(status.color))
                                Text(status.displayName)
                            }
                            .tag(status)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Optional Message") {
                    TextField("Add a message...", text: $responseMessage, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Text("Responding to invitation for '\(invitation.eventId)'")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("RSVP Response")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        onSubmit()
                    }
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CalendarEvent.self, CalendarEventInvitation.self, configurations: config)
    
    let event = CalendarEvent(
        title: "Family Dinner",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        privacyLevel: .familyShared,
        createdBy: UUID(),
        familyId: UUID()
    )
    
    return EventInvitationView(
        event: event,
        currentUserId: UUID(),
        modelContext: container.mainContext
    )
    .padding()
}