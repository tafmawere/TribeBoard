import SwiftUI

/// Card-based component for family code entry with modern design
struct FamilyCodeCard: View {
    @Binding var familyCode: String
    @FocusState.Binding var isCodeFieldFocused: Bool
    let isValidFormat: Bool
    let canSearch: Bool
    let isSearching: Bool
    let onSearch: () -> Void
    
    // Error handling properties
    let validationMessage: String?
    let showInlineError: Bool
    
    init(
        familyCode: Binding<String>,
        isCodeFieldFocused: FocusState<Bool>.Binding,
        isValidFormat: Bool,
        canSearch: Bool,
        isSearching: Bool,
        onSearch: @escaping () -> Void,
        validationMessage: String? = nil,
        showInlineError: Bool = false
    ) {
        self._familyCode = familyCode
        self._isCodeFieldFocused = isCodeFieldFocused
        self.isValidFormat = isValidFormat
        self.canSearch = canSearch
        self.isSearching = isSearching
        self.onSearch = onSearch
        self.validationMessage = validationMessage
        self.showInlineError = showInlineError
    }
    
    @State private var showPasteButton = false
    
    // Responsive design environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    // Computed properties for responsive design
    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }
    
    private var cardPadding: CGFloat {
        let basePadding = BrandStyle.paddingLarge
        let scaleFactor = min(dynamicTypeSize.customScaleFactor, 1.5)
        return isCompactLayout ? basePadding * 0.8 * scaleFactor : basePadding * scaleFactor
    }
    
    private var headerSpacing: CGFloat {
        let baseSpacing = BrandStyle.paddingLarge
        let scaleFactor = min(dynamicTypeSize.customScaleFactor, 1.3)
        return isCompactLayout ? baseSpacing * 0.7 * scaleFactor : baseSpacing * scaleFactor
    }
    
    private var inputSpacing: CGFloat {
        let baseSpacing = BrandStyle.paddingMedium
        let scaleFactor = min(dynamicTypeSize.customScaleFactor, 1.4)
        return baseSpacing * scaleFactor
    }
    
    private var iconFont: Font {
        return dynamicTypeSize.isAccessibilitySize ? .title3 : .title2
    }
    
    private var iconColor: Color {
        if colorSchemeContrast == .increased {
            return .brandPrimaryAccessible
        } else {
            return .brandPrimaryDynamic
        }
    }
    
    private var pasteButtonColor: Color {
        if colorSchemeContrast == .increased {
            return .brandPrimaryAccessible
        } else {
            return .brandPrimaryDynamic
        }
    }
    
    private var findFamilyButtonColor: Color {
        if canSearch {
            if colorSchemeContrast == .increased {
                return Color.brandPrimaryAccessible
            } else {
                return Color.brandPrimaryDynamic
            }
        } else {
            return Color.secondary.opacity(0.6)
        }
    }
    
    private var accessibilityValueText: String {
        if familyCode.isEmpty {
            return "Empty"
        } else {
            return "\(familyCode.count) of 6 characters entered"
        }
    }
    
    private var findFamilyButtonLabel: String {
        if isSearching {
            return "Searching for family"
        } else {
            return "Find family button"
        }
    }
    
    private var findFamilyButtonHint: String {
        if canSearch {
            return "Searches for a family with the entered code \(familyCode)"
        } else {
            return "Enter a valid 6-digit family code to enable this button"
        }
    }
    
    private var headerText: some View {
        Text("Enter Family Code")
            .accessibleFont(size: 17, maxSize: 24, weight: .semibold)
            .foregroundColor(.primary)
            .accessibilityAddTraits([.isHeader])
            .accessibilityLabel("Family code entry section")
    }
    
    private var familyCodeTextField: some View {
        TextField("Enter 6-digit code", text: $familyCode)
            .textFieldStyle(CardTextFieldStyle(
                isCompact: isCompactLayout,
                dynamicTypeSize: dynamicTypeSize
            ))
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .focused($isCodeFieldFocused)
            .accessibleTouchTarget()
            .onSubmit {
                handleTextFieldSubmit()
            }
            .onChange(of: isCodeFieldFocused) { _, isFocused in
                handleFocusChange(isFocused: isFocused)
            }
            .onChange(of: familyCode) { _, newValue in
                handleCodeChange(newValue: newValue)
            }
            .accessibilityLabel("Family code input field")
            .accessibilityHint("Enter the 6-digit family code to join a family. Double tap to edit.")
            .accessibilityValue(accessibilityValueText)
    }
    
    private var pasteButton: some View {
        Button(action: pasteFromClipboard) {
            Text("Paste")
                .accessibleFont(size: 15, maxSize: 18, weight: .medium)
                .foregroundColor(pasteButtonColor)
        }
        .accessibleTouchTarget()
        .transition(pasteButtonTransition)
        .accessibilityLabel("Paste family code")
        .accessibilityHint("Pastes the family code from your clipboard into the text field")
        .accessibilityAddTraits(.isButton)
    }
    
    private var pasteButtonTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        } else {
            return .scale.combined(with: .opacity)
        }
    }
    
    private var errorMessageTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        } else {
            return .scale.combined(with: .opacity)
        }
    }
    
    private var findFamilyButton: some View {
        Button(action: handleFindFamilyAction) {
            findFamilyButtonContent
        }
        .disabled(!canSearch || isSearching)
        .accessibleTouchTarget()
        .scaleEffect(findFamilyButtonScale)
        .animation(.easeInOut(duration: 0.1), value: isSearching)
        .accessibilityLabel(findFamilyButtonLabel)
        .accessibilityHint(findFamilyButtonHint)
        .accessibilityAddTraits(findFamilyButtonTraits)
    }
    
    private var findFamilyButtonContent: some View {
        HStack(spacing: 8) {
            if isSearching {
                ProgressView()
                    .scaleEffect(dynamicTypeSize.isAccessibilitySize ? 1.2 : 0.9)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .accessibilityLabel("Searching for family")
            } else {
                Text("Find Family")
                    .accessibleFont(size: 17, maxSize: 22, weight: .semibold)
            }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: max(50, 44 * dynamicTypeSize.customScaleFactor))
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(findFamilyButtonColor)
        )
    }
    
    private var findFamilyButtonScale: CGFloat {
        if isSearching && !reduceMotion {
            return 0.98
        } else {
            return 1.0
        }
    }
    
    private var findFamilyButtonTraits: AccessibilityTraits {
        if canSearch {
            return [.isButton]
        } else {
            return [.isButton]
        }
    }
    
    var body: some View {
        VStack(spacing: headerSpacing) {
            // Header with search icon and title
            HStack(spacing: inputSpacing) {
                Image(systemName: "magnifyingglass")
                    .font(iconFont)
                    .foregroundColor(iconColor)
                    .accessibilityHidden(true)
                
                headerText
                
                Spacer()
            }
            
            // Input section
            VStack(alignment: .leading, spacing: inputSpacing) {
                Text("Family Code")
                    .accessibleFont(size: 15, maxSize: 20, weight: .medium)
                    .foregroundColor(.secondary)
                    .accessibilityAddTraits([.isHeader])
                    .accessibilityLabel("Family code input field label")
                
                // Input field with paste functionality
                HStack(spacing: inputSpacing) {
                    familyCodeTextField
                    
                    // Paste button (appears when focused and clipboard has content)
                    if showPasteButton {
                        pasteButton
                    }
                }
                
                // Inline validation error message
                if showInlineError, let validationMessage = validationMessage {
                    CardInlineErrorView(message: validationMessage)
                        .transition(errorMessageTransition)
                }
            }
            
            // Find Family button
            findFamilyButton
        }
        .padding(cardPadding)
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Family code entry section")
        .accessibilityHint("Enter a 6-digit family code to join an existing family")
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Update paste button visibility when app becomes active (clipboard might have changed)
            if isCodeFieldFocused {
                let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.2)
                withAnimation(animation) {
                    showPasteButton = hasValidClipboardContent()
                }
            }
        }
    }
    
    /// Checks if clipboard contains valid content for pasting
    private func hasValidClipboardContent() -> Bool {
        guard let clipboardString = UIPasteboard.general.string else { return false }
        
        let cleanedString = clipboardString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isLetter || $0.isNumber }
        
        return !cleanedString.isEmpty && cleanedString.count <= 6
    }
    
    /// Handles text field submit action
    private func handleTextFieldSubmit() {
        if canSearch {
            HapticManager.shared.selection()
            // Announce action to VoiceOver users
            EnhancedAccessibility.announce("Searching for family")
            onSearch()
        } else {
            HapticManager.shared.error()
            EnhancedAccessibility.announce("Please enter a valid 6-digit family code")
        }
    }
    
    /// Handles focus state changes
    private func handleFocusChange(isFocused: Bool) {
        let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.2)
        withAnimation(animation) {
            showPasteButton = isFocused && hasValidClipboardContent()
        }
        
        // Announce focus changes for accessibility
        if isFocused {
            EnhancedAccessibility.announce("Family code input field focused")
        }
    }
    
    /// Handles family code text changes
    private func handleCodeChange(newValue: String) {
        // Provide feedback for code validation
        if newValue.count == 6 && isValidFormat {
            HapticManager.shared.lightImpact()
            EnhancedAccessibility.announce("Valid family code entered")
        }
    }
    
    /// Handles find family button action
    private func handleFindFamilyAction() {
        if canSearch && !isSearching {
            HapticManager.shared.selection()
            isCodeFieldFocused = false
            EnhancedAccessibility.announce("Searching for family with code \(familyCode)")
            onSearch()
        } else {
            HapticManager.shared.error()
            if !canSearch {
                EnhancedAccessibility.announce("Please enter a valid 6-digit family code first")
            }
        }
    }
    
    /// Pastes content from clipboard with validation and error handling
    private func pasteFromClipboard() {
        guard let clipboardString = UIPasteboard.general.string else {
            // Provide error feedback if clipboard is unexpectedly empty
            HapticManager.shared.error()
            EnhancedAccessibility.announce("Clipboard is empty")
            return
        }
        
        // Clean the pasted string (remove spaces, convert to uppercase)
        let cleanedCode = clipboardString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        
        // Validate the cleaned code
        if cleanedCode.isEmpty {
            // Provide error feedback for empty content
            HapticManager.shared.error()
            EnhancedAccessibility.announce("Clipboard contains no valid family code")
        } else if cleanedCode.count > 6 {
            // Truncate to 6 characters and provide warning feedback
            familyCode = String(cleanedCode.prefix(6))
            HapticManager.shared.warning()
            EnhancedAccessibility.announce("Family code pasted and truncated to 6 characters: \(familyCode)")
        } else {
            // Valid paste - provide success feedback
            familyCode = cleanedCode
            HapticManager.shared.lightImpact()
            EnhancedAccessibility.announce("Family code pasted: \(familyCode)")
        }
        
        // Hide paste button after pasting
        let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.2)
        withAnimation(animation) {
            showPasteButton = false
        }
    }
}

// MARK: - Card Text Field Style

struct CardTextFieldStyle: TextFieldStyle {
    let isCompact: Bool
    let dynamicTypeSize: DynamicTypeSize
    
    init(isCompact: Bool = false, dynamicTypeSize: DynamicTypeSize = .medium) {
        self.isCompact = isCompact
        self.dynamicTypeSize = dynamicTypeSize
    }
    
    func _body(configuration: TextField<Self._Label>) -> some View {
        let scaleFactor = min(dynamicTypeSize.customScaleFactor, 1.4)
        let horizontalPadding = BrandStyle.paddingMedium * scaleFactor
        let verticalPadding = (isCompact ? 12 : 14) * scaleFactor
        
        configuration
            .accessibleFont(size: 16, maxSize: 20, weight: .regular)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

// MARK: - Card Inline Error View

/// Inline error view specifically designed for card components
struct CardInlineErrorView: View {
    let message: String
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var body: some View {
        HStack(spacing: BrandStyle.paddingSmall * min(dynamicTypeSize.customScaleFactor, 1.3)) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(dynamicTypeSize.isAccessibilitySize ? .caption : .caption2)
                .foregroundColor(.red)
                .accessibilityHidden(true)
            
            Text(message)
                .accessibleFont(size: 13, maxSize: 17, weight: .medium)
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(.horizontal, BrandStyle.paddingSmall * min(dynamicTypeSize.customScaleFactor, 1.2))
        .padding(.vertical, BrandStyle.paddingSmall * 0.8 * min(dynamicTypeSize.customScaleFactor, 1.2))
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius * 0.8)
                .fill(Color.red.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius * 0.8)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Validation error: \(message)")
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Preview

struct FamilyCodeCardPreview: View {
    @State private var familyCode = ""
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: BrandStyle.paddingLarge) {
            // Normal state
            FamilyCodeCard(
                familyCode: $familyCode,
                isCodeFieldFocused: $isCodeFieldFocused,
                isValidFormat: false,
                canSearch: false,
                isSearching: false,
                onSearch: {}
            )
            
            // Valid state
            FamilyCodeCard(
                familyCode: .constant("ABC123"),
                isCodeFieldFocused: $isCodeFieldFocused,
                isValidFormat: true,
                canSearch: true,
                isSearching: false,
                onSearch: {}
            )
            
            // Loading state
            FamilyCodeCard(
                familyCode: .constant("ABC123"),
                isCodeFieldFocused: $isCodeFieldFocused,
                isValidFormat: true,
                canSearch: true,
                isSearching: true,
                onSearch: {}
            )
            
            // Error state
            FamilyCodeCard(
                familyCode: .constant("AB"),
                isCodeFieldFocused: $isCodeFieldFocused,
                isValidFormat: false,
                canSearch: false,
                isSearching: false,
                onSearch: {},
                validationMessage: "Code must be 6 characters with letters and numbers",
                showInlineError: true
            )
        }
        .padding(BrandStyle.paddingMedium)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    FamilyCodeCardPreview()
}