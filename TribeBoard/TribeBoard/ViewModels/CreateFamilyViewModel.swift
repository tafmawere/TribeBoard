import SwiftUI
import Foundation

/// ViewModel for family creation with mock data implementation
@MainActor
class CreateFamilyViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Family name input by user
    @Published var familyName: String = ""
    
    /// Loading state during family creation
    @Published var isCreating: Bool = false
    
    /// Created family after successful creation
    @Published var createdFamily: Family?
    
    /// Generated QR code image for the family code
    @Published var qrCodeImage: UIImage?
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Validation state for family name
    @Published var isValidFamilyName: Bool = false
    

    
    // MARK: - Computed Properties
    
    /// Validation state for family name using the new validation system
    var familyNameValidation: ValidationState {
        return ValidationRules.familyName.validate(familyName)
    }
    
    /// Whether the create button should be enabled
    var canCreateFamily: Bool {
        return isValidFamilyName && !isCreating && !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Initialization
    
    init() {
        // Set up validation
        setupValidation()
    }
    
    // MARK: - Public Methods
    
    /// Create a new family with mock implementation
    func createFamily(with appState: AppState) async {
        guard canCreateFamily else { return }
        
        isCreating = true
        errorMessage = nil
        
        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            // Mock family creation logic
            let familyCode = generateFamilyCode()
            let trimmedName = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let currentUser = appState.currentUser else {
                throw CreateFamilyError.userNotAuthenticated
            }
            
            // Create mock family
            let family = Family(
                name: trimmedName,
                code: familyCode,
                createdByUserId: currentUser.id
            )
            
            // Generate mock QR code
            let qrImage = generateMockQRCode(for: familyCode)
            
            // Create membership for the creator as Parent Admin
            let membership = Membership(
                family: family,
                user: currentUser,
                role: .parentAdmin
            )
            
            // Update state
            createdFamily = family
            qrCodeImage = qrImage
            
            // Success haptic feedback
            HapticManager.shared.success()
            
            // Show success toast
            ToastManager.shared.success("Family '\(trimmedName)' created successfully!")
            
            // Update app state and navigate to dashboard
            appState.setFamily(family, membership: membership)
            
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
        
        isCreating = false
    }
    
    /// Clear any error messages
    func clearError() {
        errorMessage = nil
    }
    
    /// Reset the form
    func resetForm() {
        familyName = ""
        createdFamily = nil
        qrCodeImage = nil
        errorMessage = nil
        isCreating = false
    }
    

    
    // MARK: - Private Methods
    
    /// Set up real-time validation for family name
    private func setupValidation() {
        // Use Combine to validate family name in real-time
        $familyName
            .map { name in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.count >= 2 && trimmed.count <= 50
            }
            .assign(to: &$isValidFamilyName)
    }
    
    /// Generate a unique family code (mock implementation)
    private func generateFamilyCode() -> String {
        // Mock implementation - generate 6-8 character alphanumeric code
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let codeLength = Int.random(in: 6...8)
        
        var code = ""
        for _ in 0..<codeLength {
            if let randomChar = characters.randomElement() {
                code.append(randomChar)
            }
        }
        
        // Ensure uniqueness in mock implementation
        // In real implementation, this would check against CloudKit
        return code
    }
    
    /// Generate a mock QR code image
    private func generateMockQRCode(for code: String) -> UIImage? {
        // Mock QR code generation - create a simple placeholder image
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Draw a simple placeholder QR code pattern
            let cgContext = context.cgContext
            
            // Background
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Border
            cgContext.setStrokeColor(UIColor.black.cgColor)
            cgContext.setLineWidth(2)
            cgContext.stroke(CGRect(x: 10, y: 10, width: size.width - 20, height: size.height - 20))
            
            // Mock QR pattern (simple grid)
            cgContext.setFillColor(UIColor.black.cgColor)
            let cellSize: CGFloat = 8
            let startX: CGFloat = 20
            let startY: CGFloat = 20
            let gridSize = Int((size.width - 40) / cellSize)
            
            // Create a simple pattern based on the code
            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    let shouldFill = (row + col + code.count) % 3 == 0
                    if shouldFill {
                        let rect = CGRect(
                            x: startX + CGFloat(col) * cellSize,
                            y: startY + CGFloat(row) * cellSize,
                            width: cellSize - 1,
                            height: cellSize - 1
                        )
                        cgContext.fill(rect)
                    }
                }
            }
            
            // Add text at bottom
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.black
            ]
            
            let text = "Code: \(code)"
            let textSize = text.size(withAttributes: textAttributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: size.height - 25,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: textAttributes)
        }
    }
}

// MARK: - Error Types

enum CreateFamilyError: LocalizedError {
    case userNotAuthenticated
    case invalidFamilyName
    case familyCodeExists
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated. Please sign in again."
        case .invalidFamilyName:
            return "Please enter a valid family name."
        case .familyCodeExists:
            return "Family code already exists. Please try again."
        case .networkUnavailable:
            return "Network unavailable. Please check your connection."
        }
    }
}