import SwiftUI

/// View for creating a new family with name input and QR code generation
struct CreateFamilyView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CreateFamilyViewModel()
    @FocusState private var isTextFieldFocused: Bool
    
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
                        headerSection
                        
                        // Family name input section
                        familyNameInputSection
                        
                        // Create button
                        createFamilyButton
                        
                        // Family code display (shown after creation)
                        if let family = viewModel.createdFamily {
                            familyCodeSection(family: family)
                        }
                        
                        Spacer(minLength: geometry.size.height * 0.1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle("Create Family")
        .navigationBarTitleDisplayMode(.inline)

        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .overlay {
            if viewModel.isCreating {
                LoadingOverlay()
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "house.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.brandPrimary)
            
            // Title and description
            VStack(spacing: 8) {
                Text("Create Your Family")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Give your family a name and we'll generate a unique code for others to join")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
    }
    
    private var familyNameInputSection: some View {
        VStack(spacing: 16) {
            // Input field
            VStack(alignment: .leading, spacing: 8) {
                Text("Family Name")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Enter your family name", text: $viewModel.familyName)
                    .textFieldStyle(CustomTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        if viewModel.canCreateFamily {
                            Task {
                                await viewModel.createFamily(with: appState)
                            }
                        }
                    }
                
                // Validation message
                if let validationMessage = viewModel.familyNameValidationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .transition(.opacity)
                }
            }
            
            // Input guidelines
            VStack(alignment: .leading, spacing: 4) {
                Text("Guidelines:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text("• 2-50 characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• Choose something your family will recognize")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 8)
    }
    
    private var createFamilyButton: some View {
        Button(action: {
            isTextFieldFocused = false
            Task {
                await viewModel.createFamily(with: appState)
            }
        }) {
            HStack(spacing: 12) {
                if viewModel.isCreating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                
                Text(viewModel.isCreating ? "Creating Family..." : "Create Family")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient.brandGradient
                    .opacity(viewModel.canCreateFamily ? 1.0 : 0.6)
            )
            .cornerRadius(BrandStyle.cornerRadius)
            .shadow(
                color: viewModel.canCreateFamily ? BrandStyle.standardShadow : .clear,
                radius: BrandStyle.shadowRadius,
                x: BrandStyle.shadowOffset.width,
                y: BrandStyle.shadowOffset.height
            )
        }
        .disabled(!viewModel.canCreateFamily)
        .animation(.easeInOut(duration: 0.2), value: viewModel.canCreateFamily)
    }
    
    private func familyCodeSection(family: Family) -> some View {
        VStack(spacing: 24) {
            // Success message
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                
                Text("Family Created Successfully!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Share this code with family members so they can join")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Family code display
            VStack(spacing: 16) {
                Text("Family Code")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Code display card
                VStack(spacing: 16) {
                    Text(family.code)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.brandPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                                .fill(Color(.systemBackground))
                                .shadow(
                                    color: BrandStyle.standardShadow,
                                    radius: 4,
                                    x: 0,
                                    y: 2
                                )
                        )
                    
                    // Copy button
                    Button(action: {
                        UIPasteboard.general.string = family.code
                        // TODO: Add haptic feedback and toast notification
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Code")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.brandPrimary)
                    }
                }
            }
            
            // QR Code display
            if let qrImage = viewModel.qrCodeImage {
                VStack(spacing: 12) {
                    Text("QR Code")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 180, height: 180)
                        .background(Color.white)
                        .cornerRadius(BrandStyle.cornerRadius)
                        .shadow(
                            color: BrandStyle.standardShadow,
                            radius: BrandStyle.shadowRadius,
                            x: BrandStyle.shadowOffset.width,
                            y: BrandStyle.shadowOffset.height
                        )
                    
                    Text("Others can scan this QR code to join your family")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Continue button
            Button(action: {
                // Navigation is handled automatically by the view model
                // when it updates the app state
            }) {
                HStack(spacing: 8) {
                    Text("Continue to Dashboard")
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(LinearGradient.brandGradient)
                .cornerRadius(BrandStyle.cornerRadius)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                .fill(Color(.systemBackground))
                .shadow(
                    color: BrandStyle.standardShadow,
                    radius: BrandStyle.shadowRadius,
                    x: BrandStyle.shadowOffset.width,
                    y: BrandStyle.shadowOffset.height
                )
        )
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.createdFamily != nil)
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: BrandStyle.standardShadow,
                        radius: 2,
                        x: 0,
                        y: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}



// MARK: - Preview

#Preview {
    NavigationStack {
        CreateFamilyView()
            .environmentObject({
                let appState = AppState()
                appState.currentUser = UserProfile.mock(displayName: "John Doe")
                return appState
            }())
    }
}

#Preview("Loading State") {
    NavigationStack {
        CreateFamilyView()
            .environmentObject({
                let appState = AppState()
                appState.currentUser = UserProfile.mock(displayName: "John Doe")
                return appState
            }())
            .onAppear {
                // Simulate loading state for preview
            }
    }
}