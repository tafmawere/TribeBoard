import SwiftUI

/// An inline error message view with dismiss functionality
struct InlineErrorView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.subheadline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.7))
                    .font(.subheadline)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.scale.combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: message)
    }
}

/// Enhanced error view designed for card-based layouts
struct CardLayoutErrorView: View {
    let message: String
    let onDismiss: () -> Void
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var cardPadding: CGFloat {
        BrandStyle.paddingMedium * min(dynamicTypeSize.customScaleFactor, 1.4)
    }
    
    var body: some View {
        HStack(spacing: cardPadding) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(dynamicTypeSize.isAccessibilitySize ? .body : .subheadline)
                .accessibilityHidden(true)
            
            Text(message)
                .accessibleFont(size: 15, maxSize: 20, weight: .medium)
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.7))
                    .font(dynamicTypeSize.isAccessibilitySize ? .body : .subheadline)
            }
            .accessibilityLabel("Dismiss error message")
            .accessibilityHint("Removes this error message from the screen")
        }
        .padding(.horizontal, cardPadding)
        .padding(.vertical, cardPadding * 0.8)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                .fill(Color(.systemBackground))
                .shadow(
                    color: Color.red.opacity(0.2),
                    radius: BrandStyle.shadowRadius,
                    x: BrandStyle.shadowOffset.width,
                    y: BrandStyle.shadowOffset.height
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                )
        )
        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: message)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Error message: \(message)")
        .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    VStack(spacing: 16) {
        InlineErrorView(message: "This is a short error message") {}
        InlineErrorView(message: "This is a longer error message that might wrap to multiple lines to show how it handles longer text") {}
        
        CardLayoutErrorView(message: "This is a card layout error message") {}
        CardLayoutErrorView(message: "This is a longer card layout error message that demonstrates how it handles multiple lines of text in the card-based design") {}
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}