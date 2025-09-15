import SwiftUI

/// View for selecting user role in a family with constraint validation
struct RoleSelectionView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: RoleSelectionViewModel
    
    // MARK: - Initialization
    
    init(family: Family, user: UserProfile) {
        self._viewModel = StateObject(wrappedValue: RoleSelectionViewModel(
            family: family,
            user: user
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                roleCardsSection
                continueButton
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
                    message: "Updating your role...",
                    style: .overlay
                )
            }
        }
        .withToast()
        .alert("Role Selection Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .onAppear {
            // Inject the actual app state
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
            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundColor(.brandPrimary)
            
            Text("Choose Your Role")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Select the role that best describes your position in the family. This will determine your permissions and access level.")
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
                RoleCard(
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
                title: "Continue",
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
}

// MARK: - Role Card Component

struct RoleCard: View {
    let data: RoleCardData
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon
                Image(systemName: data.icon)
                    .font(.system(size: 32))
                    .foregroundColor(iconColor)
                
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
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
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
        .scaleEffect(data.isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: data.isSelected)
    }
    
    // MARK: - Computed Properties
    
    private var backgroundColor: Color {
        if !data.isEnabled {
            return Color(.systemGray6)
        } else if data.isSelected {
            return Color.brandPrimary.opacity(0.1)
        } else {
            return Color(.systemBackground)
        }
    }
    
    private var borderColor: Color {
        if !data.isEnabled {
            return Color(.systemGray4)
        } else if data.isSelected {
            return Color.brandPrimary
        } else {
            return Color(.systemGray5)
        }
    }
    
    private var borderWidth: CGFloat {
        data.isSelected ? 2 : 1
    }
    
    private var iconColor: Color {
        if !data.isEnabled {
            return Color(.systemGray3)
        } else if data.isSelected {
            return Color.brandPrimary
        } else {
            return Color(.systemGray)
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
            return Color.brandPrimary.opacity(0.2)
        } else {
            return BrandStyle.standardShadow
        }
    }
    
    private var shadowRadius: CGFloat {
        data.isSelected ? 8 : 4
    }
    
    private var shadowOffset: CGFloat {
        data.isSelected ? 4 : 2
    }
}

// MARK: - Preview

#Preview("Role Selection") {
    NavigationStack {
        RoleSelectionView(
            family: Family.mock(name: "The Johnson Family"),
            user: UserProfile.mock(displayName: "John Doe")
        )
    }
    .environmentObject(AppState())
}

#Preview("Role Card - Selected") {
    RoleCard(
        data: RoleCardData(
            role: .parentAdmin,
            isSelected: true,
            isEnabled: true,
            icon: "crown.fill",
            title: "Parent Admin",
            description: "Full access to manage family members and settings"
        ),
        onTap: {}
    )
    .padding()
    .frame(width: 160)
}

#Preview("Role Card - Disabled") {
    RoleCard(
        data: RoleCardData(
            role: .parentAdmin,
            isSelected: false,
            isEnabled: false,
            icon: "crown.fill",
            title: "Parent Admin",
            description: "Full access to manage family members and settings"
        ),
        onTap: {}
    )
    .padding()
    .frame(width: 160)
}