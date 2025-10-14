import SwiftUI



/// View for joining an existing family using family code or QR scan
struct JoinFamilyView: View {
    @StateObject private var viewModel: JoinFamilyViewModel
    @EnvironmentObject private var appState: AppState
    @FocusState private var isCodeFieldFocused: Bool
    
    // Responsive design environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init() {
        // Initialize with enhanced ViewModel using in-memory data manager
        self._viewModel = StateObject(wrappedValue: JoinFamilyViewModel(
            dataManager: InMemoryFamilyDataManager.shared
        ))
    }
    
    // Computed properties for responsive design
    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }
    
    private var contentSpacing: CGFloat {
        let baseSpacing = BrandStyle.paddingLarge
        let scaleFactor = min(dynamicTypeSize.customScaleFactor, 1.4)
        return isCompactLayout ? baseSpacing * 0.8 * scaleFactor : baseSpacing * scaleFactor
    }
    
    private var horizontalPadding: CGFloat {
        let basePadding = BrandStyle.paddingLarge
        let compactFactor = isCompactLayout ? 0.8 : 1.0
        return basePadding * compactFactor
    }
    
    private var verticalPadding: CGFloat {
        let basePadding = BrandStyle.paddingLarge
        let scaleFactor = min(dynamicTypeSize.customScaleFactor, 1.3)
        return isCompactLayout ? basePadding * 0.6 * scaleFactor : basePadding * scaleFactor
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Light system background (replacing gradient)
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: contentSpacing) {
                        // Family Code Card Section
                        FamilyCodeCard(
                            familyCode: $viewModel.familyCode,
                            isCodeFieldFocused: $isCodeFieldFocused,
                            isValidFormat: viewModel.isValidCode,
                            canSearch: viewModel.canSearch,
                            isSearching: viewModel.isSearching,
                            onSearch: {
                                Task {
                                    await viewModel.searchFamily(by: viewModel.familyCode)
                                }
                            },
                            validationMessage: viewModel.codeValidationMessage,
                            showInlineError: !viewModel.familyCode.isEmpty && !viewModel.isValidCode && !isCodeFieldFocused
                        )
                        
                        // Divider with "or" text
                        OrDivider()
                        
                        // QR Code Section
                        QRCodeScanSection(
                            isScanning: viewModel.isSearching,
                            onScan: {
                                isCodeFieldFocused = false
                                Task {
                                    await viewModel.handleScannedCode("DEMO12") // Placeholder for QR scanning
                                }
                            },
                            errorMessage: viewModel.currentError?.localizedDescription,
                            showError: viewModel.currentError != nil && !viewModel.showErrorAlert
                        )
                        
                        Spacer()
                        
                        // Instructional footer
                        InstructionalFooter()
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
                }
                
                // Global error message with enhanced styling for card layout
                if let errorMessage = viewModel.errorMessage, viewModel.showErrorAlert == false {
                    VStack {
                        Spacer()
                        CardLayoutErrorView(message: errorMessage) {
                            HapticManager.shared.lightImpact()
                            EnhancedAccessibility.announce("Error message dismissed")
                            viewModel.clearError()
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.bottom, verticalPadding)
                    }
                }
            }
        }
            .navigationTitle("Join Family")
            .navigationBarTitleDisplayMode(isCompactLayout ? .inline : .large)
            .navigationBarBackButtonHidden(false)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Join Family Screen")
            .accessibilityHint("Choose between entering a family code or scanning a QR code to join an existing family")
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
                        EnhancedAccessibility.announce("Joining family")
                        Task {
                            await viewModel.joinFamily(with: appState)
                            // Navigation is handled by the view model
                            appState.navigateTo(.roleSelection)
                        }
                    },
                    onCancel: {
                        HapticManager.shared.lightImpact()
                        EnhancedAccessibility.announce("Family join cancelled")
                        viewModel.cancelJoin()
                    }
                )
            }
            .alert("Error Joining Family", isPresented: $viewModel.showErrorAlert) {
                Button("OK") {
                    HapticManager.shared.lightImpact()
                    EnhancedAccessibility.announce("Error alert dismissed")
                    viewModel.clearError()
                }
                if viewModel.currentError?.isRetryable == true {
                    Button("Try Again") {
                        HapticManager.shared.selection()
                        EnhancedAccessibility.announce("Retrying family search")
                        Task {
                            await viewModel.searchFamily(by: viewModel.familyCode)
                        }
                    }
                }
            } message: {
                if let error = viewModel.currentError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error.localizedDescription)
                        if let recoverySuggestion = error.recoverySuggestion {
                            Text(recoverySuggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .alert("Success!", isPresented: $viewModel.showSuccessAlert) {
                Button("Continue") {
                    HapticManager.shared.success()
                    EnhancedAccessibility.announce("Successfully joined family. Continuing to role selection.")
                    viewModel.showSuccessAlert = false
                    appState.navigateTo(.roleSelection)
                }
            } message: {
                Text("Successfully joined family!")
            }
            .onAppear {
                viewModel.reset()
                
                // Announce screen appearance for accessibility
                EnhancedAccessibility.announceScreenChange()
                EnhancedAccessibility.announce("Join Family screen. Choose between entering a family code or scanning a QR code.")
            }
            .withToast()
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