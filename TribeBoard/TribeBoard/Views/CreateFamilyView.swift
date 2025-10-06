import SwiftUI

// MARK: - Placeholder Utilities (to be implemented in later tasks)

// MARK: - View Extensions

extension View {
    func dynamicTypeSupport(minSize: CGFloat, maxSize: CGFloat) -> some View {
        self.font(.system(size: min(max(minSize, UIFont.preferredFont(forTextStyle: .body).pointSize), maxSize)))
    }
}

/// View for creating a new family with name input and QR code generation
struct CreateFamilyView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: CreateFamilyViewModel
    @StateObject private var validationPublisher = ValidationPublisher()
    @FocusState private var isTextFieldFocused: Bool
    
    // MARK: - Initialization
    
    init() {
        // Initialize with enhanced ViewModel using in-memory data manager
        self._viewModel = StateObject(wrappedValue: CreateFamilyViewModel(
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
                    .accessibilityHint("Returns to the family selection screen")
                }
            }

            .overlay {
                if viewModel.isCreating {
                    LoadingStateView(
                        message: "Creating your family...",
                        style: .overlay
                    )
                    .accessibilityLabel("Creating family")
                    .accessibilityHint("Please wait while your family is being created")
                }
            }
            .alert("Error Creating Family", isPresented: $viewModel.showErrorAlert) {
                Button("OK") {
                    viewModel.clearError()
                }
                if viewModel.canRetry {
                    Button("Retry") {
                        Task {
                            await viewModel.retryCreation(with: appState)
                        }
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
                    // Navigate to role selection
                    appState.navigateToRoleSelection()
                }
            } message: {
                Text("Family created successfully!")
            }
            .withToast()
            .onAppear {
                // Set up real-time validation
                validationPublisher.setupFamilyNameValidation(for: viewModel.$familyName)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Create Family Screen")
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
                    .accessibilityLabel("Give your family a name and we'll generate a unique code for others to join")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Create Your Family screen. Give your family a name and we'll generate a unique code for others to join")
        .accessibilityHint("Enter a family name below to create your family")
    }
    
    private var familyNameInputSection: some View {
        VStack(spacing: 16) {
            // Enhanced input field with validation
            VStack(alignment: .leading, spacing: 8) {
                Text("Family Name")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .accessibilityAddTraits([.isHeader])
                
                TextField("Enter your family name", text: $viewModel.familyName)
                    .textFieldStyle(CustomTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .validation(validationPublisher.familyNameValidation, showValidation: !viewModel.familyName.isEmpty)
                    .onSubmit {
                        if viewModel.canCreateFamily {
                            Task {
                                await viewModel.createFamily(with: appState)
                            }
                        }
                    }
                    .accessibilityLabel("Family name")
                    .accessibilityHint("Enter a name for your family between 2 and 50 characters")
                    .accessibilityValue(viewModel.familyName.isEmpty ? "Empty" : viewModel.familyName)
            }
            
            // Input guidelines
            VStack(alignment: .leading, spacing: 4) {
                Text("Guidelines:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .accessibilityAddTraits([.isHeader])
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("• 2-50 characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• Choose something your family will recognize")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Guidelines: 2 to 50 characters. Choose something your family will recognize")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }
    
    private var createFamilyButton: some View {
        LoadingButton(
            title: "Create Family",
            isLoading: viewModel.isCreating,
            action: {
                isTextFieldFocused = false
                HapticManager.shared.selection()
                Task {
                    await viewModel.createFamily(with: appState)
                }
            },
            style: .primary
        )
        .disabled(!viewModel.canCreateFamily)
        .opacity(viewModel.canCreateFamily ? 1.0 : 0.6)
        .animation(.easeInOut(duration: 0.2), value: viewModel.canCreateFamily)
        .accessibilityLabel("Create Family")
        .accessibilityHint(viewModel.canCreateFamily ? "Creates a new family with the entered name" : "Enter a valid family name to enable this button")
        .accessibilityAddTraits(viewModel.canCreateFamily ? [] : [.isButton])
    }
    
    private func familyCodeSection(family: InMemoryFamily) -> some View {
        VStack(spacing: 24) {
            // Success message with animation
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                    .scaleEffect(viewModel.createdFamily != nil ? 1.0 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: viewModel.createdFamily != nil)
                
                Text("Family Created Successfully!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .opacity(viewModel.createdFamily != nil ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.6).delay(0.2), value: viewModel.createdFamily != nil)
                
                Text("Share this code with family members so they can join")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(viewModel.createdFamily != nil ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.6).delay(0.4), value: viewModel.createdFamily != nil)
            }
            
            // Family code display with enhanced animations
            VStack(spacing: 16) {
                Text("Family Code")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .opacity(viewModel.createdFamily != nil ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.6).delay(0.6), value: viewModel.createdFamily != nil)
                
                // Code display card with pulse animation
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
                        .scaleEffect(viewModel.createdFamily != nil ? 1.0 : 0.8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.8), value: viewModel.createdFamily != nil)
                    
                    // Enhanced copy button with visual feedback
                    CopyCodeButton(familyCode: family.code)
                        .opacity(viewModel.createdFamily != nil ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.6).delay(1.0), value: viewModel.createdFamily != nil)
                }
            }
            
            // QR Code display with placeholder fallback
            VStack(spacing: 12) {
                Text("QR Code")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .opacity(viewModel.createdFamily != nil ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.6).delay(1.2), value: viewModel.createdFamily != nil)
                
                // QR Code or placeholder
                Group {
                    if let qrImage = viewModel.qrCodeImage {
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
                    } else {
                        // QR Code placeholder using SF Symbol
                        VStack(spacing: 8) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 80))
                                .foregroundColor(.brandPrimary.opacity(0.6))
                            
                            Text("QR Code")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 180, height: 180)
                        .background(Color(.systemGray6))
                        .cornerRadius(BrandStyle.cornerRadius)
                        .shadow(
                            color: BrandStyle.standardShadow,
                            radius: BrandStyle.shadowRadius,
                            x: BrandStyle.shadowOffset.width,
                            y: BrandStyle.shadowOffset.height
                        )
                    }
                }
                .scaleEffect(viewModel.createdFamily != nil ? 1.0 : 0.8)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(1.4), value: viewModel.createdFamily != nil)
                
                Text("Others can scan this QR code to join your family")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(viewModel.createdFamily != nil ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.6).delay(1.6), value: viewModel.createdFamily != nil)
            }
            
            // Continue button with slide-up animation
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
            .offset(y: viewModel.createdFamily != nil ? 0 : 50)
            .opacity(viewModel.createdFamily != nil ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.8), value: viewModel.createdFamily != nil)
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

// MARK: - Copy Code Button Component

struct CopyCodeButton: View {
    let familyCode: String
    @State private var isCopied = false
    @State private var buttonScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: copyToClipboard) {
            HStack(spacing: 8) {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundColor(isCopied ? .green : .brandPrimary)
                    .animation(.easeInOut(duration: 0.2), value: isCopied)
                
                Text(isCopied ? "Copied!" : "Copy Code")
                    .foregroundColor(isCopied ? .green : .brandPrimary)
                    .animation(.easeInOut(duration: 0.2), value: isCopied)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill((isCopied ? Color.green : Color.brandPrimary).opacity(0.1))
                    .animation(.easeInOut(duration: 0.2), value: isCopied)
            )
            .scaleEffect(buttonScale)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: buttonScale)
        }
        .accessibilityLabel("Copy family code to clipboard")
        .accessibilityHint("Copies the family code \(familyCode) to your clipboard")
    }
    
    private func copyToClipboard() {
        // Copy to clipboard
        UIPasteboard.general.string = familyCode
        
        // Provide haptic feedback
        HapticManager.shared.success()
        
        // Show visual feedback with animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            buttonScale = 1.1
        }
        
        // Set copied state
        isCopied = true
        
        // Show success toast
        ToastManager.shared.success("Family code copied to clipboard!")
        
        // Reset button scale
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                buttonScale = 1.0
            }
        }
        
        // Reset copied state after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                isCopied = false
            }
        }
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
    }
    .previewEnvironment(.authenticated)
}

#Preview("Loading State") {
    NavigationStack {
        CreateFamilyView()
    }
    .previewEnvironmentLoading()
}