import SwiftUI

/// View for creating a new family with name input and QR code generation
struct CreateFamilyView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var mockViewModel: MockCreateFamilyViewModel
    @FocusState private var isTextFieldFocused: Bool
    
    // MARK: - Initialization
    
    init() {
        // Initialize with mock services for prototype
        let mockServiceCoordinator = MockServiceCoordinator()
        self._mockViewModel = StateObject(wrappedValue: MockCreateFamilyViewModel(
            mockDataService: mockServiceCoordinator.dataService,
            mockCloudKitService: mockServiceCoordinator.cloudKitService
        ))
    }
    
    // Computed properties to maintain compatibility with existing UI code
    private var viewModel: MockCreateFamilyViewModel { mockViewModel }
    private var syncManager: MockSyncManager { 
        MockSyncManager(
            dataService: mockViewModel.mockDataService, 
            cloudKitService: mockViewModel.mockCloudKitService
        ) 
    }
    
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
                        if let family = mockViewModel.createdFamily {
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
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    appState.navigateTo(.familySelection)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(.body)
                    }
                    .foregroundColor(.brandPrimary)
                }
                .accessibilityLabel("Go back to family selection")
            }
            
            // Removed sync status for prototype
        }

        .overlay {
            if mockViewModel.isCreating {
                LoadingStateView(
                    message: "Creating your family...",
                    style: .overlay
                )
            }
        }
        .withToast()
        .alert("Error", isPresented: .constant(mockViewModel.errorMessage != nil)) {
            Button("OK") {
                mockViewModel.clearError()
            }
        } message: {
            if let errorMessage = mockViewModel.errorMessage {
                Text(errorMessage)
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
                .accessibilityHidden(true)
            
            // Title and description
            VStack(spacing: 8) {
                Text("Create Your Family")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .dynamicTypeSupport(minSize: 28, maxSize: 40)
                    .accessibilityAddTraits([.isHeader])
                
                Text("Give your family a name and we'll generate a unique code for others to join")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .dynamicTypeSupport(minSize: 16, maxSize: 22)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Create Your Family. Give your family a name and we'll generate a unique code for others to join")
    }
    
    private var familyNameInputSection: some View {
        VStack(spacing: 16) {
            // Enhanced input field with validation
            ValidatedTextField(
                title: "Family Name",
                placeholder: "Enter your family name",
                text: $mockViewModel.familyName,
                validation: ValidationRules.familyName,
                submitLabel: .done,
                onSubmit: {
                    if mockViewModel.canCreateFamily {
                        Task {
                            await mockViewModel.createFamily(with: appState)
                        }
                    }
                }
            )
            
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
        LoadingButton(
            title: "Create Family",
            isLoading: mockViewModel.isCreating,
            action: {
                isTextFieldFocused = false
                Task {
                    await mockViewModel.createFamily(with: appState)
                }
            },
            style: .primary
        )
        .disabled(!mockViewModel.canCreateFamily)
        .opacity(mockViewModel.canCreateFamily ? 1.0 : 0.6)
        .animation(.easeInOut(duration: 0.2), value: mockViewModel.canCreateFamily)
        .accessibilityLabel("Create Family")
        .accessibilityHint("Creates a new family with the entered name")
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
                    
                    // Copy button with enhanced feedback
                    CopyableText(
                        text: family.code,
                        displayText: "Copy Code",
                        successMessage: "Family code copied to clipboard!"
                    )
                }
            }
            
            // QR Code display
            if let qrImage = mockViewModel.qrCodeImage {
                VStack(spacing: 12) {
                    Text("QR Code")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    qrImage
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
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: mockViewModel.createdFamily != nil)
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
                appState.currentUser = MockDataGenerator.mockAuthenticatedUser()
                return appState
            }())
    }
}

#Preview("Loading State") {
    NavigationStack {
        CreateFamilyView()
            .environmentObject({
                let appState = AppState()
                appState.currentUser = MockDataGenerator.mockAuthenticatedUser()
                return appState
            }())
            .onAppear {
                // Simulate loading state for preview
            }
    }
}