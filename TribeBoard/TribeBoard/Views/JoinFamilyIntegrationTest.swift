import SwiftUI

/// Simple integration test view to verify JoinFamilyView components work together
struct JoinFamilyIntegrationTest: View {
    @State private var familyCode = ""
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Test FamilyCodeCard
                        FamilyCodeCard(
                            familyCode: $familyCode,
                            isCodeFieldFocused: $isCodeFieldFocused,
                            isValidFormat: familyCode.count == 6,
                            canSearch: familyCode.count == 6,
                            isSearching: false,
                            onSearch: {
                                print("Search initiated with code: \(familyCode)")
                            }
                        )
                        
                        // Test OrDivider
                        OrDivider()
                        
                        // Test QRCodeScanSection
                        QRCodeScanSection(
                            isScanning: false,
                            onScan: {
                                print("QR scan initiated")
                            }
                        )
                        
                        Spacer()
                        
                        // Test InstructionalFooter
                        InstructionalFooter()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("Join Family Test")
        .withToast()
    }
}

#Preview {
    JoinFamilyIntegrationTest()
}