import SwiftUI

// MARK: - Haptic Form Validation Components

/// Enhanced form field with haptic feedback for validation states
struct HapticFormField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool
    let validation: ValidationResult?
    let keyboardType: UIKeyboardType
    let isMultiline: Bool
    
    @FocusState private var isFocused: Bool
    @State private var lastValidationState: Bool = true
    
    init(
        title: String,
        text: Binding<String>,
        placeholder: String = "",
        isSecure: Bool = false,
        validation: ValidationResult? = nil,
        keyboardType: UIKeyboardType = .default,
        isMultiline: Bool = false
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.isSecure = isSecure
        self.validation = validation
        self.keyboardType = keyboardType
        self.isMultiline = isMultiline
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AccessibleText(
                title,
                style: .headline,
                weight: .medium
            )
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else if isMultiline {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(3...6)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .focused($isFocused)
            .keyboardType(keyboardType)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .accessibilityLabel("\(title) input field")
            .accessibilityHint(placeholder.isEmpty ? "Enter \(title.lowercased())" : placeholder)
            .accessibilityValue(text.isEmpty ? "Empty" : "Contains text")
            .onChange(of: validation?.isValid) { _, newValidationState in
                handleValidationChange(newValidationState)
            }
            
            if let validation = validation, !validation.message.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: validation.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(validation.isValid ? .green : .red)
                        .accessibilityHidden(true)
                    
                    AccessibleText(
                        validation.message,
                        style: .caption,
                        color: validation.isValid ? .green : .red
                    )
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(validation.isValid ? "Valid: \(validation.message)" : "Error: \(validation.message)")
                .accessibilityAddTraits(validation.isValid ? [] : [.isStaticText])
            }
        }
    }
    
    private func handleValidationChange(_ newValidationState: Bool?) {
        guard let newState = newValidationState else { return }
        
        // Only trigger haptic feedback when validation state changes
        if newState != lastValidationState {
            if newState {
                // Validation passed
                CalendarHapticManager.shared.validationSuccess(title)
            } else {
                // Validation failed
                CalendarHapticManager.shared.validationError(title)
            }
            lastValidationState = newState
        }
    }
}

// MARK: - Haptic Toggle Components

/// Toggle with haptic feedback for state changes
struct HapticToggle: View {
    let title: String
    @Binding var isOn: Bool
    let onToggle: ((Bool) -> Void)?
    
    init(title: String, isOn: Binding<Bool>, onToggle: ((Bool) -> Void)? = nil) {
        self.title = title
        self._isOn = isOn
        self.onToggle = onToggle
    }
    
    var body: some View {
        HStack {
            AccessibleText(title, style: .body)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .accessibilityLabel(title)
                .accessibilityHint(isOn ? "\(title) is enabled" : "\(title) is disabled")
                .onChange(of: isOn) { _, newValue in
                    CalendarHapticManager.shared.selection()
                    onToggle?(newValue)
                }
        }
    }
}

// MARK: - Haptic Button Components

/// Button with context-aware haptic feedback
struct HapticButton<Content: View>: View {
    let action: () -> Void
    let hapticContext: HapticButtonContext
    let isEnabled: Bool
    let isLoading: Bool
    let content: () -> Content
    
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(
        action: @escaping () -> Void,
        hapticContext: HapticButtonContext = .standard,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.action = action
        self.hapticContext = hapticContext
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.content = content
    }
    
    var body: some View {
        Button(action: performAction) {
            content()
        }
        .disabled(!isEnabled || isLoading)
        .scaleEffect(isPressed && !reduceMotion ? 0.95 : 1.0)
        .opacity((isEnabled && !isLoading) ? 1.0 : 0.6)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
            if pressing && isEnabled && !isLoading {
                triggerHapticFeedback()
            }
        }, perform: {})
    }
    
    private func performAction() {
        guard isEnabled && !isLoading else { return }
        action()
    }
    
    private func triggerHapticFeedback() {
        switch hapticContext {
        case .standard:
            CalendarHapticManager.shared.lightImpact()
        case .primary:
            CalendarHapticManager.shared.mediumImpact()
        case .destructive:
            CalendarHapticManager.shared.warning()
        case .success:
            CalendarHapticManager.shared.success()
        case .navigation:
            CalendarHapticManager.shared.selection()
        case .creation:
            CalendarHapticManager.shared.mediumImpact()
        case .deletion:
            CalendarHapticManager.shared.warning()
        }
    }
}

/// Context for haptic button feedback
enum HapticButtonContext {
    case standard
    case primary
    case destructive
    case success
    case navigation
    case creation
    case deletion
}

// MARK: - Haptic Picker Components

/// Picker with haptic feedback for selection changes
struct HapticPicker<SelectionValue: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: SelectionValue
    let content: () -> Content
    let onSelectionChange: ((SelectionValue) -> Void)?
    
    init(
        title: String,
        selection: Binding<SelectionValue>,
        onSelectionChange: ((SelectionValue) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self._selection = selection
        self.onSelectionChange = onSelectionChange
        self.content = content
    }
    
    var body: some View {
        Picker(title, selection: $selection) {
            content()
        }
        .accessibilityLabel(title)
        .onChange(of: selection) { _, newValue in
            CalendarHapticManager.shared.selection()
            onSelectionChange?(newValue)
        }
    }
}

// MARK: - Haptic Date Picker Components

/// Date picker with haptic feedback for date changes
struct HapticDatePicker: View {
    let title: String
    @Binding var date: Date
    let displayedComponents: DatePickerComponents
    let onDateChange: ((Date) -> Void)?
    
    init(
        title: String,
        date: Binding<Date>,
        displayedComponents: DatePickerComponents = [.date, .hourAndMinute],
        onDateChange: ((Date) -> Void)? = nil
    ) {
        self.title = title
        self._date = date
        self.displayedComponents = displayedComponents
        self.onDateChange = onDateChange
    }
    
    var body: some View {
        DatePicker(title, selection: $date, displayedComponents: displayedComponents)
            .accessibilityLabel(title)
            .onChange(of: date) { _, newDate in
                CalendarHapticManager.shared.selection()
                onDateChange?(newDate)
            }
    }
}

// MARK: - Haptic Alert Components

/// Alert with haptic feedback for different alert types
struct HapticAlert {
    static func show(
        title: String,
        message: String,
        alertType: AlertType,
        primaryAction: AlertAction? = nil,
        secondaryAction: AlertAction? = nil
    ) {
        // Trigger appropriate haptic feedback based on alert type
        switch alertType {
        case .info:
            CalendarHapticManager.shared.lightImpact()
        case .warning:
            CalendarHapticManager.shared.warning()
        case .error:
            CalendarHapticManager.shared.error()
        case .success:
            CalendarHapticManager.shared.success()
        case .destructive:
            CalendarHapticManager.shared.warning()
        }
        
        // Note: In a real implementation, this would show the actual alert
        // For now, we're just providing the haptic feedback pattern
    }
    
    enum AlertType {
        case info
        case warning
        case error
        case success
        case destructive
    }
    
    struct AlertAction {
        let title: String
        let style: ActionStyle
        let action: () -> Void
        
        enum ActionStyle {
            case `default`
            case cancel
            case destructive
        }
    }
}

// MARK: - Haptic Loading Components

/// Loading view with haptic feedback for state changes
struct HapticLoadingView: View {
    let message: String
    let isLoading: Bool
    
    @State private var lastLoadingState: Bool = false
    
    var body: some View {
        HStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .accessibilityHidden(true)
            }
            
            AccessibleText(
                message,
                style: .subheadline,
                weight: .medium
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLoading ? "Loading: \(message)" : message)
        .accessibilityAddTraits(isLoading ? [.updatesFrequently] : [])
        .onChange(of: isLoading) { _, newLoadingState in
            if newLoadingState != lastLoadingState {
                CalendarHapticManager.shared.loadingStateChanged(newLoadingState)
                lastLoadingState = newLoadingState
            }
        }
    }
}

// MARK: - Haptic Success/Error Feedback

/// View modifier for success/error haptic feedback
struct HapticFeedbackModifier: ViewModifier {
    let feedbackType: FeedbackType
    let trigger: Bool
    
    enum FeedbackType {
        case success
        case error
        case warning
        case selection
    }
    
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { _, shouldTrigger in
                if shouldTrigger {
                    switch feedbackType {
                    case .success:
                        CalendarHapticManager.shared.success()
                    case .error:
                        CalendarHapticManager.shared.error()
                    case .warning:
                        CalendarHapticManager.shared.warning()
                    case .selection:
                        CalendarHapticManager.shared.selection()
                    }
                }
            }
    }
}

extension View {
    /// Adds haptic feedback when the trigger value becomes true
    func hapticFeedback(_ type: HapticFeedbackModifier.FeedbackType, trigger: Bool) -> some View {
        self.modifier(HapticFeedbackModifier(feedbackType: type, trigger: trigger))
    }
}

// MARK: - Preview

#Preview("Haptic Form Components") {
    NavigationView {
        Form {
            Section("Form Fields") {
                HapticFormField(
                    title: "Event Title",
                    text: .constant(""),
                    placeholder: "Enter event title",
                    validation: ValidationResult(errors: [CalendarError.invalidTitle("Title is required")], message: "Title is required")
                )
                
                HapticToggle(
                    title: "All Day Event",
                    isOn: .constant(false)
                ) { isOn in
                    print("All day toggled: \(isOn)")
                }
            }
            
            Section("Buttons") {
                HapticButton(
                    action: { print("Primary action") },
                    hapticContext: .primary
                ) {
                    Text("Primary Button")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                
                HapticButton(
                    action: { print("Destructive action") },
                    hapticContext: .destructive
                ) {
                    Text("Delete")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(8)
                }
            }
            
            Section("Date Picker") {
                HapticDatePicker(
                    title: "Event Date",
                    date: .constant(Date())
                ) { date in
                    print("Date changed: \(date)")
                }
            }
        }
        .navigationTitle("Haptic Components")
    }
}