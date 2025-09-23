import SwiftUI

/// Comprehensive showcase of all enhanced shared components for prototype demonstration
struct MockComponentShowcase: View {
    @State private var selectedTab = 0
    @State private var showToast = false
    @State private var showError = false
    @State private var isLoading = false
    @State private var familyName = ""
    @State private var familyCode = ""
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                loadingShowcaseTab
                    .tabItem {
                        Image(systemName: "arrow.clockwise")
                        Text("Loading")
                    }
                    .tag(0)
                
                errorShowcaseTab
                    .tabItem {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Errors")
                    }
                    .tag(1)
                
                toastShowcaseTab
                    .tabItem {
                        Image(systemName: "bell")
                        Text("Toasts")
                    }
                    .tag(2)
                
                validationShowcaseTab
                    .tabItem {
                        Image(systemName: "checkmark.shield")
                        Text("Validation")
                    }
                    .tag(3)
            }
            .navigationTitle("Component Showcase")
            .navigationBarTitleDisplayMode(.inline)
        }
        .withToast()
    }
    
    // MARK: - Loading Showcase Tab
    
    private var loadingShowcaseTab: some View {
        ScrollView {
            VStack(spacing: 30) {
                sectionHeader("Loading States", subtitle: "Various loading animations and scenarios")
                
                // Loading styles showcase
                VStack(alignment: .leading, spacing: 16) {
                    Text("Loading Styles")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        LoadingStateView(
                            message: "Creating family...",
                            style: .card,
                            mockScenario: .familyCreation
                        )
                        .frame(height: 120)
                        
                        LoadingStateView(
                            message: "Signing in...",
                            style: .progress,
                            mockScenario: .authentication
                        )
                        .frame(height: 120)
                        
                        LoadingStateView(
                            message: "Syncing data...",
                            style: .shimmer,
                            mockScenario: .dataSync
                        )
                        .frame(height: 120)
                        
                        LoadingStateView(
                            message: "Generating QR...",
                            style: .pulse,
                            mockScenario: .qrGeneration
                        )
                        .frame(height: 120)
                    }
                }
                
                // Loading buttons showcase
                VStack(alignment: .leading, spacing: 16) {
                    Text("Loading Buttons")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        LoadingButton(
                            title: "Create Family",
                            isLoading: isLoading,
                            action: {
                                isLoading = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    isLoading = false
                                    ToastManager.shared.showMockFamilyCreated()
                                }
                            },
                            style: .primary
                        )
                        
                        LoadingButton(
                            title: "Join Family",
                            isLoading: false,
                            action: {
                                ToastManager.shared.showFamilyJoiningToasts()
                            },
                            style: .secondary
                        )
                    }
                }
                
                // Skeleton loading showcase
                VStack(alignment: .leading, spacing: 16) {
                    Text("Skeleton Loading")
                        .font(.headline)
                    
                    SkeletonLoadingView(rows: 3, showAvatar: true)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Error Showcase Tab
    
    private var errorShowcaseTab: some View {
        ScrollView {
            VStack(spacing: 30) {
                sectionHeader("Error States", subtitle: "Comprehensive error scenarios with recovery actions")
                
                // Network errors
                errorSection("Network Errors") {
                    VStack(spacing: 16) {
                        MockErrorScenarios.networkError()
                        MockErrorScenarios.offlineError()
                    }
                }
                
                // Family management errors
                errorSection("Family Management") {
                    VStack(spacing: 16) {
                        MockErrorScenarios.familyNotFound()
                        MockErrorScenarios.familyFull()
                        MockErrorScenarios.alreadyInFamily()
                    }
                }
                
                // Permission errors
                errorSection("Permission Errors") {
                    VStack(spacing: 16) {
                        MockErrorScenarios.permissionDenied()
                        MockErrorScenarios.childRestriction()
                        MockErrorScenarios.cameraPermission()
                    }
                }
                
                // Prototype-specific errors
                errorSection("Prototype Errors") {
                    VStack(spacing: 16) {
                        MockErrorScenarios.prototypeDataLimitReached()
                        MockErrorScenarios.prototypeFeaturePreview(featureName: "Advanced Analytics")
                    }
                }
                
                // Random error generator
                VStack(alignment: .leading, spacing: 16) {
                    Text("Random Error Generator")
                        .font(.headline)
                    
                    Button("Show Random Error") {
                        showError = true
                    }
                    .buttonStyle(.borderedProminent)
                    .sheet(isPresented: $showError) {
                        NavigationView {
                            VStack {
                                Spacer()
                                MockErrorScenarios.randomError()
                                Spacer()
                            }
                            .navigationTitle("Random Error")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        showError = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Toast Showcase Tab
    
    private var toastShowcaseTab: some View {
        ScrollView {
            VStack(spacing: 30) {
                sectionHeader("Toast Notifications", subtitle: "Non-blocking feedback messages")
                
                // Success toasts
                toastSection("Success Messages") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        toastButton("Family Created", color: .green) {
                            ToastManager.shared.showMockFamilyCreated()
                        }
                        
                        toastButton("Task Complete", color: .green) {
                            ToastManager.shared.showMockTaskCompleted()
                        }
                        
                        toastButton("Message Sent", color: .green) {
                            ToastManager.shared.showMockMessageSent()
                        }
                        
                        toastButton("Data Synced", color: .green) {
                            ToastManager.shared.showMockDataSynced()
                        }
                    }
                }
                
                // Error toasts
                toastSection("Error Messages") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        toastButton("Network Error", color: .red) {
                            ToastManager.shared.showMockNetworkError()
                        }
                        
                        toastButton("Permission Error", color: .red) {
                            ToastManager.shared.showMockPermissionError()
                        }
                        
                        toastButton("Validation Error", color: .red) {
                            ToastManager.shared.showMockValidationError()
                        }
                        
                        toastButton("Auth Error", color: .red) {
                            ToastManager.shared.showMockAuthenticationError()
                        }
                    }
                }
                
                // Warning toasts
                toastSection("Warning Messages") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        toastButton("Sync Warning", color: .orange) {
                            ToastManager.shared.showMockSyncWarning()
                        }
                        
                        toastButton("Battery Warning", color: .orange) {
                            ToastManager.shared.showMockBatteryWarning()
                        }
                        
                        toastButton("Storage Warning", color: .orange) {
                            ToastManager.shared.showMockStorageWarning()
                        }
                        
                        toastButton("Offline Warning", color: .orange) {
                            ToastManager.shared.showMockOfflineWarning()
                        }
                    }
                }
                
                // Info toasts
                toastSection("Info Messages") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        toastButton("Offline Mode", color: .blue) {
                            ToastManager.shared.showMockOfflineMode()
                        }
                        
                        toastButton("New Feature", color: .blue) {
                            ToastManager.shared.showMockNewFeature()
                        }
                        
                        toastButton("Tip of Day", color: .blue) {
                            ToastManager.shared.showMockTipOfTheDay()
                        }
                        
                        toastButton("Backup Complete", color: .blue) {
                            ToastManager.shared.showMockBackupComplete()
                        }
                    }
                }
                
                // Toast sequences
                VStack(alignment: .leading, spacing: 16) {
                    Text("Toast Sequences")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        Button("Family Creation Sequence") {
                            ToastManager.shared.showFamilyCreationToasts()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Sync Sequence") {
                            ToastManager.shared.showSyncSequenceToasts()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Prototype Welcome") {
                            ToastManager.shared.showPrototypeWelcomeSequence()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Demo Mode") {
                            ToastManager.shared.showDemoModeSequence()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Validation Showcase Tab
    
    private var validationShowcaseTab: some View {
        ScrollView {
            VStack(spacing: 30) {
                sectionHeader("Form Validation", subtitle: "Instant validation feedback with helpful hints")
                
                // Standard validation
                VStack(alignment: .leading, spacing: 16) {
                    Text("Standard Validation")
                        .font(.headline)
                    
                    ValidatedTextField(
                        title: "Family Name",
                        placeholder: "Enter your family name",
                        text: $familyName,
                        validation: ValidationRules.familyName
                    )
                    
                    ValidatedTextField(
                        title: "Family Code",
                        placeholder: "Enter 4-8 characters",
                        text: $familyCode,
                        validation: ValidationRules.familyCode,
                        textInputAutocapitalization: .characters,
                        autocorrectionDisabled: true
                    )
                }
                
                // Prototype validation with hints
                VStack(alignment: .leading, spacing: 16) {
                    Text("Prototype Validation (with hints)")
                        .font(.headline)
                    
                    MockValidationScenarios.mockPrototypeValidation()
                }
                
                // Pre-filled examples
                VStack(alignment: .leading, spacing: 16) {
                    Text("Valid Form Example")
                        .font(.headline)
                    
                    MockValidationScenarios.mockValidForm()
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Error Form Example")
                        .font(.headline)
                    
                    MockValidationScenarios.mockErrorForm()
                }
                
                // Inline validation messages
                VStack(alignment: .leading, spacing: 16) {
                    Text("Inline Messages")
                        .font(.headline)
                    
                    VStack(spacing: 12) {
                        InlineErrorView(
                            message: "Family name must be at least 2 characters",
                            onDismiss: {}
                        )
                        
                        SuccessMessageView(
                            message: "Family created successfully!",
                            onDismiss: {}
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.brandPrimary)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private func errorSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            
            content()
        }
    }
    
    private func toastSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            
            content()
        }
    }
    
    private func toastButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(color)
                .cornerRadius(8)
        }
    }
}

// MARK: - Preview

#Preview("Component Showcase") {
    MockComponentShowcase()
}

#Preview("Loading Tab") {
    NavigationView {
        ScrollView {
            VStack(spacing: 30) {
                LoadingStateView(
                    style: .card,
                    mockScenario: .familyCreation
                )
                
                LoadingStateView(
                    style: .progress,
                    mockScenario: .authentication
                )
                
                SkeletonLoadingView(rows: 3, showAvatar: true)
            }
            .padding()
        }
        .navigationTitle("Loading States")
    }
}

#Preview("Error Tab") {
    NavigationView {
        ScrollView {
            VStack(spacing: 20) {
                MockErrorScenarios.networkError()
                MockErrorScenarios.familyNotFound()
                MockErrorScenarios.permissionDenied()
            }
            .padding()
        }
        .navigationTitle("Error States")
    }
}