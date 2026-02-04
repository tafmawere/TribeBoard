//
//  ActivityStreamView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import SwiftUI

/// View that displays run events in chronological order with timestamps
/// Implements Requirements 8.1, 8.2, 8.3, 8.4, 8.5
struct ActivityStreamView: View {
    
    @StateObject private var viewModel: ActivityStreamViewModel
    @State private var showingCommentSheet = false
    @State private var selectedEventId: String?
    @State private var commentText = ""
    
    init(runId: String, runEventService: RunEventService) {
        self._viewModel = StateObject(wrappedValue: ActivityStreamViewModel(runId: runId, runEventService: runEventService))
    }
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading activity...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.events.isEmpty {
                    emptyStateView
                } else {
                    eventListView
                }
            }
            .navigationTitle("Activity Stream")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                viewModel.loadEvents()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .sheet(isPresented: $showingCommentSheet) {
                commentSheetView
            }
        }
    }
    
    // MARK: - View Components
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Activity Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Run events will appear here as they happen")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    private var eventListView: some View {
        List {
            // Group events by date - Requirement 8.4: Display events in chronological order
            ForEach(sortedDateSections, id: \.0) { date, events in
                Section(header: dateHeaderView(date)) {
                    ForEach(events, id: \.id) { event in
                        ActivityEventRowView(
                            event: event,
                            isAcknowledged: viewModel.isEventAcknowledged(event.id),
                            comment: viewModel.getComment(for: event.id),
                            onAcknowledge: {
                                viewModel.acknowledgeEvent(event.id)
                            },
                            onAddComment: {
                                selectedEventId = event.id
                                commentText = viewModel.getComment(for: event.id) ?? ""
                                showingCommentSheet = true
                            }
                        )
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func dateHeaderView(_ date: Date) -> some View {
        HStack {
            Text(viewModel.formatDate(date))
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var commentSheetView: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add Comment")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                TextEditor(text: $commentText)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingCommentSheet = false
                        commentText = ""
                        selectedEventId = nil
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let eventId = selectedEventId {
                            viewModel.addComment(to: eventId, comment: commentText)
                        }
                        showingCommentSheet = false
                        commentText = ""
                        selectedEventId = nil
                    }
                    .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Helper Properties
    
    private var sortedDateSections: [(Date, [RunEvent])] {
        let eventsByDate = viewModel.eventsByDate
        return eventsByDate.keys.sorted(by: >).map { date in
            (date, eventsByDate[date]?.sorted { $0.timestamp > $1.timestamp } ?? [])
        }
    }
}

/// Activity Event Row View for RunEvent objects
struct ActivityEventRowView: View {
    let event: RunEvent
    let isAcknowledged: Bool
    let comment: String?
    let onAcknowledge: () -> Void
    let onAddComment: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if let note = event.note {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(event.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if isAcknowledged {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            
            if let comment = comment, !comment.isEmpty {
                Text("Note: \(comment)")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            
            HStack {
                if !isAcknowledged {
                    Button("Acknowledge") {
                        onAcknowledge()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button(comment?.isEmpty == false ? "Edit Note" : "Add Note") {
                    onAddComment()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    let mockRunEventService = RunEventService(firebaseService: MockFirebaseRunService())
    
    return ActivityStreamView(runId: "test-run-id", runEventService: mockRunEventService)
}