import SwiftUI

/// Noticeboard composer view for creating new family announcements and posts
struct NoticeboardComposerView: View {
    let onPost: (String, String) async -> Void
    
    @State private var title = ""
    @State private var content = ""
    @State private var isPinned = false
    @State private var isPosting = false
    @Environment(\.dismiss) private var dismiss
    
    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Post details section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Post Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Title input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Title")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField("Enter post title...", text: $title)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                HStack {
                                    Spacer()
                                    Text("\(title.count)/100")
                                        .font(.caption)
                                        .foregroundColor(title.count > 100 ? .red : .secondary)
                                }
                            }
                            
                            // Content input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Content")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                TextField(
                                    "Write your announcement or post content here...",
                                    text: $content,
                                    axis: .vertical
                                )
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(5...12)
                                
                                HStack {
                                    Spacer()
                                    Text("\(content.count)/1000")
                                        .font(.caption)
                                        .foregroundColor(content.count > 1000 ? .red : .secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Post options section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Post Options")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            // Pin option
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Pin to Top")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("Pinned posts appear at the top of the noticeboard")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $isPinned)
                                    .labelsHidden()
                            }
                            
                            // Future options placeholder
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Add Attachment")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Coming soon - attach photos or documents")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button("Add") {
                                    // Future attachment functionality
                                }
                                .disabled(true)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Post preview
                    if !title.isEmpty || !content.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Preview")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            NoticeboardPostPreview(
                                title: title.isEmpty ? "Post Title" : title,
                                content: content.isEmpty ? "Post content will appear here..." : content,
                                isPinned: isPinned
                            )
                        }
                    }
                    
                    // Post button
                    Button(action: {
                        Task {
                            await createPost()
                        }
                    }) {
                        HStack {
                            if isPosting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "pin.fill")
                            }
                            
                            Text(isPosting ? "Posting..." : "Create Post")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isValid || isPosting || title.count > 100 || content.count > 1000)
                }
                .padding()
            }
            .navigationTitle("New Post")
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
    
    private func createPost() async {
        guard isValid else { return }
        
        isPosting = true
        await onPost(title, content)
        isPosting = false
        dismiss()
    }
}

// MARK: - Noticeboard Post Preview

struct NoticeboardPostPreview: View {
    let title: String
    let content: String
    let isPinned: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                // Mock avatar
                Circle()
                    .fill(LinearGradient.brandGradient)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text("You")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title with pin indicator
                    HStack(spacing: 8) {
                        if isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Text(title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    // Author and timestamp
                    HStack(spacing: 8) {
                        Text("You")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("now")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Content
            Text(content)
                .font(.subheadline)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview {
    NoticeboardComposerView(
        onPost: { title, content in
            print("Creating post: \(title) - \(content)")
        }
    )
}