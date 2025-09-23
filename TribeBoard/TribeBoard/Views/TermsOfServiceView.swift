import SwiftUI

/// Terms of Service placeholder view for prototype
struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Terms of Service")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.brandPrimary)
                        
                        Text("Last updated: [Date]")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Placeholder content
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Welcome to TribeBoard")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("This is a prototype version of TribeBoard. The following terms would apply to the full version of the application:")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Group {
                            termsSection(
                                title: "1. Acceptance of Terms",
                                content: "By using TribeBoard, you agree to be bound by these Terms of Service and all applicable laws and regulations."
                            )
                            
                            termsSection(
                                title: "2. Family Data and Privacy",
                                content: "TribeBoard is designed to help families stay organized and connected. We take your family's privacy seriously and implement appropriate security measures."
                            )
                            
                            termsSection(
                                title: "3. User Responsibilities",
                                content: "Users are responsible for maintaining the confidentiality of their account information and for all activities that occur under their account."
                            )
                            
                            termsSection(
                                title: "4. Family Management",
                                content: "Family administrators have the ability to manage family members, assign roles, and control access to family information."
                            )
                            
                            termsSection(
                                title: "5. Data Synchronization",
                                content: "TribeBoard uses CloudKit to synchronize your family data across devices. This ensures your information is available when and where you need it."
                            )
                        }
                        
                        // Prototype notice
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Prototype Notice")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Text("This is a UI/UX prototype. No real data is collected or stored. All functionality is simulated for demonstration purposes.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(BrandStyle.cornerRadius)
                        }
                    }
                    
                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.brandPrimary)
                }
            }
        }
    }
    
    private func termsSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    TermsOfServiceView()
}