import SwiftUI

/// Mock version of RoleSelectionView for prototype with enhanced UX and instant responses
struct MockRoleSelectionView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: MockRoleSelectionViewModel
    
    // MARK: - Initialization
    
    init(family: Family, user: UserProfile, scenario: MockRoleSelectionViewModel.MockRoleScenario = .normalFamily) {
        self._viewModel = StateObject(wrappedValue: MockRoleSelectionViewModel(
            family: family,
            user: user,
            scenario: scenario
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                roleCardsSection
                continueButton
                mockInfoSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("Select Your Role")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .background(Color(.systemGroupedBackground))
        .overlay {
            if viewModel.isUpdating {
                LoadingStateView(
                    message: "Setting up your role...",
                    style: .overlay
                )
            }
        }
        .withToast()
        .alert("Role Selection", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            viewModel.setAppState(appState)
        }
        .onChange(of: viewModel.roleSelectionComplete) { _, isComplete in
            if isComplete {
                // Navigation is handled by AppState update in ViewModel
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Animated role icon
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.brandPrimary, .brandSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: UUID())
            
            Text("Choose Your Role")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Select the role that best describes your position in the family. This determines your permissions and what you can access in the app.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Role Cards Section
    
    private var roleCardsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 16) {
            ForEach(viewModel.getRoleCardData()) { cardData in
                EnhancedRoleCard(
                    data: cardData,
                    onTap: {
                        Task {
                            await viewModel.setRole(cardData.role)
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        VStack(spacing: 12) {
            LoadingButton(
                title: "Continue to Dashboard",
                isLoading: viewModel.isUpdating,
                action: {
                    Task {
                        await viewModel.updateRole(viewModel.selectedRole)
                    }
                },
                style: .primary
            )
            .accessibilityLabel("Continue with selected role")
            .accessibilityHint("Confirms your role selection and continues to the family dashboard")
            
            Text("You can change your role later in family settings")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Mock Info Section (for demo purposes)
    
    private var mockInfoSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Prototype Mode")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
            }
            
            Text("This is a demo version with instant responses. Role selection will immediately navigate to the dashboard with mock family data.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
        .padding(.top, 16)
    }
}

// MARK: - Enhanced Role Card Component

struct EnhancedRoleCard: View {
    let data: RoleCardData
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
                onTap()
            }
        }) {
            VStack(spacing: 12) {
                // Icon with gradient for selected state
                Image(systemName: data.icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(iconGradient)
                
                // Title
                Text(data.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(titleColor)
                    .multilineTextAlignment(.center)
                
                // Description
                Text(data.description)
                    .font(.caption)
                    .foregroundColor(descriptionColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Selection indicator
                if data.isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.brandPrimary)
                        Text("Selected")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.brandPrimary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 160)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .stroke(borderGradient, lineWidth: borderWidth)
            )
            .cornerRadius(BrandStyle.cornerRadius)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowOffset
            )
        }
        .disabled(!data.isEnabled)
        .scaleEffect(scaleEffect)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: data.isSelected)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        if !data.isEnabled {
            return Color(.systemGray6)
        } else if data.isSelected {
            return Color.brandPrimary.opacity(0.15)
        } else {
            return Color(.systemBackground)
        }
    }
    
    private var borderGradient: LinearGradient {
        if !data.isEnabled {
            return LinearGradient(colors: [Color(.systemGray4)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if data.isSelected {
            return LinearGradient(
                colors: [.brandPrimary, .brandSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(colors: [Color(.systemGray5)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var borderWidth: CGFloat {
        data.isSelected ? 2 : 1
    }
    
    private var iconGradient: LinearGradient {
        if !data.isEnabled {
            return LinearGradient(colors: [Color(.systemGray3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        } else if data.isSelected {
            return LinearGradient(
                colors: [.brandPrimary, .brandSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(colors: [Color(.systemGray)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var titleColor: Color {
        if !data.isEnabled {
            return Color(.systemGray3)
        } else {
            return Color.primary
        }
    }
    
    private var descriptionColor: Color {
        if !data.isEnabled {
            return Color(.systemGray4)
        } else {
            return Color.secondary
        }
    }
    
    private var shadowColor: Color {
        if data.isSelected {
            return Color.brandPrimary.opacity(0.3)
        } else {
            return BrandStyle.standardShadow
        }
    }
    
    private var shadowRadius: CGFloat {
        data.isSelected ? 12 : 4
    }
    
    private var shadowOffset: CGFloat {
        data.isSelected ? 6 : 2
    }
    
    private var scaleEffect: CGFloat {
        if isPressed {
            return 0.95
        } else if data.isSelected {
            return 1.05
        } else {
            return 1.0
        }
    }
}

// MARK: - Preview

#Preview("Mock Role Selection - Normal") {
    NavigationStack {
        MockRoleSelectionView(
            family: MockDataGenerator.mockMawereFamily().family,
            user: MockDataGenerator.mockAuthenticatedUser(),
            scenario: .normalFamily
        )
    }
    .environmentObject(AppState())
}

#Preview("Mock Role Selection - Parent Admin Exists") {
    NavigationStack {
        MockRoleSelectionView(
            family: MockDataGenerator.mockMawereFamily().family,
            user: MockDataGenerator.mockAuthenticatedUser(),
            scenario: .parentAdminExists
        )
    }
    .environmentObject(AppState())
}

#Preview("Mock Role Selection - Full Family") {
    NavigationStack {
        MockRoleSelectionView(
            family: MockDataGenerator.mockMawereFamily().family,
            user: MockDataGenerator.mockAuthenticatedUser(),
            scenario: .fullFamily
        )
    }
    .environmentObject(AppState())
}

#Preview("Enhanced Role Card - Selected") {
    EnhancedRoleCard(
        data: RoleCardData(
            role: .parentAdmin,
            isSelected: true,
            isEnabled: true,
            icon: "crown.fill",
            title: "Parent Admin",
            description: "Full access to manage family members, settings, and all features"
        ),
        onTap: {}
    )
    .padding()
    .frame(width: 160)
}

#Preview("Enhanced Role Card - Disabled") {
    EnhancedRoleCard(
        data: RoleCardData(
            role: .parentAdmin,
            isSelected: false,
            isEnabled: false,
            icon: "crown.fill",
            title: "Parent Admin",
            description: "Full access to manage family members, settings, and all features"
        ),
        onTap: {}
    )
    .padding()
    .frame(width: 160)
}