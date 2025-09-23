import SwiftUI

/// Privacy Policy placeholder view for prototype
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privacy Policy")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.brandPrimary)
                        
                        Text("Last updated: [Date]")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Placeholder content
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Privacy Matters")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("This is a prototype version of TribeBoard. The following privacy practices would apply to the full version of the application:")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Group {
                            privacySection(
                                title: "Information We Collect",
                                content: "TribeBoard collects information you provide when creating your family profile, including names, roles, and family activities."
                            )
                            
                            privacySection(
                                title: "How We Use Your Information",
                                content: "Your information is used to provide family organization features, synchronize data across devices, and improve the TribeBoard experience."
                            )
                            
                            privacySection(
                                title: "Data Security",
                                content: "We implement industry-standard security measures to protect your family's information, including encryption and secure cloud storage."
                            )
                            
                            privacySection(
                                title: "CloudKit Integration",
                                content: "TribeBoard uses Apple's CloudKit service to synchronize your data. Your information is stored securely in your personal iCloud account."
                            )
                            
                            privacySection(
                                title: "Family Data Sharing",
                                content: "Information is only shared within your family group. Family administrators control who has access to family information."
                            )
                            
                            privacySection(
                                title: "Children's Privacy",
                                content: "We take special care to protect children's information and comply with applicable privacy laws regarding minors."
                            )
                        }
                        
                        // Prototype notice
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Prototype Notice")
                                .font(.headline)
                                .foregroundColor(.orange)
                            
                            Text("This is a UI/UX prototype. No real personal data is collected, stored, or transmitted. All functionality is simulated for demonstration purposes only.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding()
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(BrandStyle.cornerRadius)
                        }
                        
                        // Contact information
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Contact Us")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("If you have questions about this Privacy Policy, please contact us at [contact information].")
                                .font(.body)
                                .foregroundColor(.secondary)
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
    
    private func privacySection(title: String, content: String) -> some View {
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
    PrivacyPolicyView()
}