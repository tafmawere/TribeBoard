import SwiftUI

/// Inline error view for displaying validation errors within forms and input fields
struct CalendarInlineErrorView: View {
    
    // MARK: - Properties
    
    let error: CalendarError?
    let isVisible: Bool
    let style: InlineErrorStyle
    
    @State private var isAnimating = false
    
    // MARK: - Initialization
    
    init(
        error: CalendarError?,
        isVisible: Bool = true,
        style: InlineErrorStyle = .standard
    ) {
        self.error = error
        self.isVisible = isVisible && error != nil
        self.style = style
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isVisible, let error = error {
                HStack(alignment: .top, spacing: 8) {
                    // Error Icon
                    Image(systemName: style.icon)
                        .font(.system(size: style.iconSize, weight: .medium))
                        .foregroundColor(style.color)
                        .accessibilityHidden(true)
                    
                    // Error Message
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error.localizedDescription)
                            .font(style.font)
                            .foregroundColor(style.color)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Recovery suggestion for validation errors
                        if error.category == .validation,
                           let suggestion = error.recoverySuggestion {
                            Text(suggestion)
                                .font(style.suggestionFont)
                                .foregroundColor(style.suggestionColor)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    Spacer()
                }
                .padding(style.padding)
                .background(style.backgroundColor)
                .cornerRadius(style.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .stroke(style.borderColor, lineWidth: style.borderWidth)
                )
                .scaleEffect(isAnimating ? 1.0 : 0.95)
                .opacity(isAnimating ? 1.0 : 0.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAnimating)
                .onAppear {
                    isAnimating = true
                }
                .onDisappear {
                    isAnimating = false
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Error: \(error.localizedDescription)")
                .accessibilityRole(.alert)
            }
        }
    }
}

// MARK: - Inline Error Styles

struct InlineErrorStyle {
    let icon: String
    let iconSize: CGFloat
    let font: Font
    let suggestionFont: Font
    let color: Color
    let suggestionColor: Color
    let backgroundColor: Color
    let borderColor: Color
    let borderWidth: CGFloat
    let cornerRadius: CGFloat
    let padding: EdgeInsets
    
    static let standard = InlineErrorStyle(
        icon: "exclamationmark.circle.fill",
        iconSize: 16,
        font: .caption,
        suggestionFont: .caption2,
        color: .red,
        suggestionColor: .red.opacity(0.8),
        backgroundColor: Color.red.opacity(0.1),
        borderColor: Color.red.opacity(0.3),
        borderWidth: 1,
        cornerRadius: 8,
        padding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    )
    
    static let compact = InlineErrorStyle(
        icon: "exclamationmark.triangle.fill",
        iconSize: 14,
        font: .caption2,
        suggestionFont: .caption2,
        color: .orange,
        suggestionColor: .orange.opacity(0.8),
        backgroundColor: Color.orange.opacity(0.1),
        borderColor: Color.orange.opacity(0.3),
        borderWidth: 1,
        cornerRadius: 6,
        padding: EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
    )
    
    static let minimal = InlineErrorStyle(
        icon: "xmark.circle.fill",
        iconSize: 12,
        font: .caption2,
        suggestionFont: .caption2,
        color: .red,
        suggestionColor: .red.opacity(0.8),
        backgroundColor: Color.clear,
        borderColor: Color.clear,
        borderWidth: 0,
        cornerRadius: 0,
        padding: EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
    )
    
    static let warning = InlineErrorStyle(
        icon: "exclamationmark.triangle.fill",
        iconSize: 16,
        font: .caption,
        suggestionFont: .caption2,
        color: .orange,
        suggestionColor: .orange.opacity(0.8),
        backgroundColor: Color.orange.opacity(0.1),
        borderColor: Color.orange.opacity(0.3),
        borderWidth: 1,
        cornerRadius: 8,
        padding: EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    )
}

// MARK: - Form Field Error Wrapper

struct CalendarFormFieldWithError<Content: View>: View {
    let content: Content
    let error: CalendarError?
    let errorStyle: InlineErrorStyle
    
    init(
        error: CalendarError?,
        errorStyle: InlineErrorStyle = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.error = error
        self.errorStyle = errorStyle
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content
            
            CalendarInlineErrorView(
                error: error,
                style: errorStyle
            )
        }
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Adds an inline error view below this view
    func calendarError(
        _ error: CalendarError?,
        style: InlineErrorStyle = .standard
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            self
            
            CalendarInlineErrorView(
                error: error,
                style: style
            )
        }
    }
    
    /// Adds validation error styling to a form field
    func validationError(_ error: CalendarError?) -> some View {
        self.calendarError(error, style: .standard)
    }
    
    /// Adds warning error styling to a form field
    func warningError(_ error: CalendarError?) -> some View {
        self.calendarError(error, style: .warning)
    }
    
    /// Adds minimal error styling to a form field
    func minimalError(_ error: CalendarError?) -> some View {
        self.calendarError(error, style: .minimal)
    }
}

// MARK: - Error Collection View

struct CalendarErrorCollectionView: View {
    let errors: [CalendarError]
    let style: InlineErrorStyle
    let maxVisible: Int
    
    @State private var isExpanded = false
    
    init(
        errors: [CalendarError],
        style: InlineErrorStyle = .standard,
        maxVisible: Int = 3
    ) {
        self.errors = errors
        self.style = style
        self.maxVisible = maxVisible
    }
    
    var body: some View {
        if !errors.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(visibleErrors.indices, id: \.self) { index in
                    CalendarInlineErrorView(
                        error: visibleErrors[index],
                        style: style
                    )
                }
                
                if errors.count > maxVisible {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            Text(isExpanded ? "Show Less" : "Show \(errors.count - maxVisible) More")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .accessibilityLabel(isExpanded ? "Show fewer errors" : "Show \(errors.count - maxVisible) more errors")
                }
            }
        }
    }
    
    private var visibleErrors: [CalendarError] {
        if isExpanded {
            return errors
        } else {
            return Array(errors.prefix(maxVisible))
        }
    }
}

// MARK: - Preview

#Preview("Standard Error") {
    VStack(spacing: 20) {
        TextField("Event Title", text: .constant(""))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .validationError(.invalidEventTitle(""))
        
        TextField("Location", text: .constant("Very long location name that exceeds the maximum allowed character limit"))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .warningError(.invalidLocation("Location too long"))
        
        TextField("Notes", text: .constant(""))
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .minimalError(.missingRequiredField("Notes"))
    }
    .padding()
}

#Preview("Error Collection") {
    CalendarErrorCollectionView(
        errors: [
            .invalidEventTitle(""),
            .invalidEventDates("End date before start date"),
            .eventDurationTooShort(300, minimum: 900),
            .invalidLocation("Location too long"),
            .missingRequiredField("Description")
        ]
    )
    .padding()
}

#Preview("Form with Errors") {
    CalendarFormFieldWithError(error: .invalidEventTitle("Title cannot be empty")) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Event Title")
                .font(.headline)
            
            TextField("Enter event title", text: .constant(""))
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
    .padding()
}