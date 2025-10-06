import SwiftUI



/// View for joining an existing family using family code or QR scan
struct JoinFamilyView: View {
    @StateObject private var viewModel: JoinFamilyViewModel
    @StateObject private var validationPublisher = ValidationPublisher()
    @EnvironmentObject private var appState: AppState
    @FocusState private var isCodeFieldFocused: Bool
    
    init() {
        // Initialize with enhanced ViewModel using in-memory data manager
        self._viewModel = StateObject(wrappedValue: JoinFamilyViewModel(
            dataManager: InMemoryFamilyDataManager.shared
        ))
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background gradient
                    LinearGradient.brandGradientSubtle
                        .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 32) {
                            Spacer(minLength: geometry.size.height * 0.05)
                            
                            // Header section
                            VStack(spacing: 16) {
                                Text("Join Family")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .accessibilityAddTraits([.isHeader])
                                
                                Text("Enter your family code or scan the QR code to join an existing family")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                    .accessibilityLabel("Enter your family code or scan the QR code to join an existing family")
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Join Family screen. Enter your family code or scan the QR code to join an existing family")
                        
                        // Input section
                        VStack(spacing: 24) {
                            // Family code input
                            FamilyCodeInputSection(
                                familyCode: $viewModel.familyCode,
                                isCodeFieldFocused: $isCodeFieldFocused,
                                isValidFormat: viewModel.isValidCode,
                                canSearch: viewModel.canSearch,
                                isSearching: viewModel.isSearching,
                                onSearch: {
                                    Task {
                                        await viewModel.searchFamily(by: viewModel.familyCode)
                                    }
                                }
                            )
                            
                            // Divider with "OR"
                            HStack {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(height: 1)
                                
                                Text("OR")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(height: 1)
                            }
                            .padding(.horizontal, 40)
                            
                            // QR scan button
                            QRScanButton(
                                isScanning: viewModel.isSearching,
                                onScan: {
                                    isCodeFieldFocused = false
                                    Task {
                                        await viewModel.handleScannedCode("DEMO123") // Placeholder for QR scanning
                                    }
                                }
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        // Error message with enhanced styling
                        if let errorMessage = viewModel.errorMessage {
                            InlineErrorView(message: errorMessage) {
                                viewModel.clearError()
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: geometry.size.height * 0.1)
                    }
                    .padding(.vertical, 20)
                }
            }
        }
            .navigationTitle("Join Family")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .confirmationDialog(
                "Join Family",
                isPresented: $viewModel.showConfirmation,
                titleVisibility: .visible
            ) {
                FamilyConfirmationDialog(
                    family: viewModel.foundFamily,
                    memberCount: viewModel.memberCount,
                    isJoining: viewModel.isJoining,
                    onJoin: {
                        HapticManager.shared.selection()
                        Task {
                            await viewModel.joinFamily(with: appState)
                            // Navigation is handled by the view model
                            appState.navigateTo(.roleSelection)
                        }
                    },
                    onCancel: {
                        HapticManager.shared.lightImpact()
                        viewModel.cancelJoin()
                    }
                )
            }
            .alert("Error Joining Family", isPresented: $viewModel.showErrorAlert) {
                Button("OK") {
                    viewModel.clearError()
                }
                Button("Try Again") {
                    Task {
                        await viewModel.searchFamily(by: viewModel.familyCode)
                    }
                }
            } message: {
                if let error = viewModel.currentError {
                    Text(error.localizedDescription)
                }
            }
            .alert("Success!", isPresented: $viewModel.showSuccessAlert) {
                Button("Continue") {
                    viewModel.showSuccessAlert = false
                    appState.navigateTo(.roleSelection)
                }
            } message: {
                Text("Successfully joined family!")
            }
            .onAppear {
                viewModel.reset()
                // Set up real-time validation
                validationPublisher.setupFamilyCodeValidation(for: viewModel.$familyCode)
            }
            .withToast()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Join Family Screen")
        }
    }
}

// MARK: - Family Code Input Section

struct FamilyCodeInputSection: View {
    @Binding var familyCode: String
    @FocusState.Binding var isCodeFieldFocused: Bool
    let isValidFormat: Bool
    let canSearch: Bool
    let isSearching: Bool
    let onSearch: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Input field
            VStack(alignment: .leading, spacing: 8) {
                Text("Family Code")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .accessibilityAddTraits([.isHeader])
                
                HStack {
                    TextField("Enter family code", text: $familyCode)
                        .textFieldStyle(CustomTextFieldStyle())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isCodeFieldFocused)
                        .validation(ValidationRules.validateFamilyCode(familyCode), showValidation: !familyCode.isEmpty)
                        .onSubmit {
                            if canSearch {
                                HapticManager.shared.selection()
                                onSearch()
                            }
                        }
                        .accessibilityLabel("Family code")
                        .accessibilityHint("Enter the 6-character family code to join a family")
                        .accessibilityValue(familyCode.isEmpty ? "Empty" : familyCode)
                    
                    // Search button
                    Button(action: {
                        HapticManager.shared.selection()
                        onSearch()
                    }) {
                        Group {
                            if isSearching {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .accessibilityLabel("Searching")
                            } else {
                                Image(systemName: "magnifyingglass")
                                    .accessibilityLabel("Search")
                            }
                        }
                        .frame(width: 20, height: 20)
                    }
                    .disabled(!canSearch)
                    .foregroundColor(canSearch ? .brandPrimary : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                    .accessibilityLabel("Search for family")
                    .accessibilityHint(canSearch ? "Searches for a family with the entered code" : "Enter a valid family code to search")
                    .accessibilityAddTraits(canSearch ? [] : [.isButton])
                }
                
                // Validation feedback is now handled by the validation modifier
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - QR Scan Button

struct QRScanButton: View {
    let isScanning: Bool
    let onScan: () -> Void
    
    var body: some View {
        Button(action: onScan) {
            HStack(spacing: 12) {
                if isScanning {
                    ProgressView()
                        .scaleEffect(0.9)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.title2)
                }
                
                Text(isScanning ? "Scanning..." : "Scan QR Code")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient.brandGradient
                    .opacity(isScanning ? 0.7 : 1.0)
            )
            .cornerRadius(BrandStyle.cornerRadius)
        }
        .disabled(isScanning)
        .scaleEffect(isScanning ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isScanning)
    }
}

// MARK: - Family Confirmation Dialog

struct FamilyConfirmationDialog: View {
    let family: InMemoryFamily?
    let memberCount: Int
    let isJoining: Bool
    let onJoin: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        Group {
            if let family = family {
                Button("Join \(family.name)") {
                    onJoin()
                }
                .disabled(isJoining)
                
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .disabled(isJoining)
            }
        }
    }
}

// MARK: - Error Message View

struct ErrorMessageView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button("Dismiss") {
                onDismiss()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        JoinFamilyView()
    }
    .previewEnvironment(.authenticated)
}

#Preview("With Error") {
    NavigationStack {
        JoinFamilyView()
    }
    .previewEnvironmentError()
}