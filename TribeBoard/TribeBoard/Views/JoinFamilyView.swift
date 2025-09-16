import SwiftUI

/// View for joining an existing family using family code or QR scan
struct JoinFamilyView: View {
    @StateObject private var viewModel = JoinFamilyViewModel()
    @EnvironmentObject private var appState: AppState
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
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
                            
                            Text("Enter your family code or scan the QR code to join an existing family")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        // Input section
                        VStack(spacing: 24) {
                            // Family code input
                            FamilyCodeInputSection(
                                familyCode: $viewModel.familyCode,
                                isCodeFieldFocused: $isCodeFieldFocused,
                                isValidFormat: viewModel.isValidCodeFormat,
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
                                        await viewModel.scanQRCode()
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
                    Task {
                        await viewModel.joinFamily()
                        // Set the found family in app state and navigate to role selection
                        if let family = viewModel.foundFamily,
                           let user = appState.currentUser {
                            // Create a temporary membership for role selection
                            let tempMembership = Membership(
                                familyId: family.id,
                                userId: user.id,
                                role: .adult // Default role, will be updated in role selection
                            )
                            appState.currentFamily = family
                            appState.currentMembership = tempMembership
                            appState.navigateTo(.roleSelection)
                        }
                    }
                },
                onCancel: {
                    viewModel.cancelJoin()
                }
            )
        }
        .withToast()
        .onAppear {
            viewModel.reset()
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
                
                HStack {
                    TextField("Enter family code", text: $familyCode)
                        .textFieldStyle(ValidatedTextFieldStyle(
                            isValid: isValidFormat || familyCode.isEmpty,
                            isFocused: isCodeFieldFocused,
                            hasError: !isValidFormat && !familyCode.isEmpty
                        ))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($isCodeFieldFocused)
                        .onSubmit {
                            if canSearch {
                                onSearch()
                            }
                        }
                    
                    // Search button
                    Button(action: onSearch) {
                        Group {
                            if isSearching {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "magnifyingglass")
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
                }
                
                // Validation feedback
                if !familyCode.isEmpty {
                    ValidationFeedbackView(
                        state: ValidationRules.familyCode.validate(familyCode),
                        showSuccess: false
                    )
                } else {
                    Text("Family codes are 4-8 characters (letters and numbers)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
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
    let family: Family?
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
            .environmentObject({
                let appState = AppState()
                appState.currentUser = MockDataGenerator.mockAuthenticatedUser()
                return appState
            }())
    }
}

#Preview("With Error") {
    NavigationStack {
        JoinFamilyView()
            .environmentObject({
                let appState = AppState()
                appState.currentUser = MockDataGenerator.mockAuthenticatedUser()
                return appState
            }())
            .onAppear {
                // This would show an error state in the preview
            }
    }
}