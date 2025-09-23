import SwiftUI

/// Message composer view for sending new family messages
struct MessageComposerView: View {
    let onSend: (String, FamilyMessage.MessageType) async -> Void
    
    @State private var messageContent = ""
    @State private var selectedType: FamilyMessage.MessageType = .text
    @State private var isSending = false
    @Environment(\.dismiss) private var dismiss
    
    private var isValid: Bool {
        !messageContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Message type selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Message Type")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(FamilyMessage.MessageType.allCases, id: \.self) { type in
                            MessageTypeButton(
                                type: type,
                                isSelected: selectedType == type,
                                action: {
                                    selectedType = type
                                }
                            )
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Message content input
                VStack(alignment: .leading, spacing: 12) {
                    Text("Message")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextField(
                        "Type your message here...",
                        text: $messageContent,
                        axis: .vertical
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...8)
                    
                    // Character count
                    HStack {
                        Spacer()
                        Text("\(messageContent.count)/500")
                            .font(.caption)
                            .foregroundColor(messageContent.count > 500 ? .red : .secondary)
                    }
                }
                
                // Message preview
                if !messageContent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        MessagePreview(
                            content: messageContent,
                            type: selectedType
                        )
                    }
                }
                
                Spacer()
                
                // Send button
                Button(action: {
                    Task {
                        await sendMessage()
                    }
                }) {
                    HStack {
                        if isSending {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        
                        Text(isSending ? "Sending..." : "Send Message")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isValid || isSending || messageContent.count > 500)
            }
            .padding()
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func sendMessage() async {
        guard isValid else { return }
        
        isSending = true
        await onSend(messageContent, selectedType)
        isSending = false
        dismiss()
    }
}

// MARK: - Message Type Button

struct MessageTypeButton: View {
    let type: FamilyMessage.MessageType
    let isSelected: Bool
    let action: () -> Void
    
    private var typeIcon: String {
        switch type {
        case .text:
            return "text.bubble"
        case .announcement:
            return "megaphone"
        case .photo:
            return "camera"
        case .reminder:
            return "bell"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: typeIcon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .brandPrimary)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isSelected {
                        LinearGradient.brandGradient
                    } else {
                        Color(.systemBackground)
                    }
                }
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.clear : Color.brandPrimary.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Message Preview

struct MessagePreview: View {
    let content: String
    let type: FamilyMessage.MessageType
    
    private var typeIcon: String {
        switch type {
        case .text:
            return ""
        case .announcement:
            return "📢"
        case .photo:
            return "📷"
        case .reminder:
            return "⏰"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Type indicator
            if type != .text {
                HStack(spacing: 6) {
                    Text(typeIcon)
                        .font(.caption)
                    
                    Text(type.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Content
            Text(content)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient.brandGradient)
        )
        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
    }
}

// MARK: - Preview

#Preview {
    MessageComposerView(
        onSend: { content, type in
            print("Sending: \(content) as \(type)")
        }
    )
}