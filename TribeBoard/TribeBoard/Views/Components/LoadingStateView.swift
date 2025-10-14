import SwiftUI

/// A loading state view with message and different styles
struct LoadingStateView: View {
    let message: String
    let style: LoadingStateStyle
    
    /// Initialize with explicit message and style
    init(message: String, style: LoadingStateStyle) {
        self.message = message
        self.style = style
    }
    
    /// Initialize with mock scenario for prototyping
    init(style: LoadingStateStyle, mockScenario: MockLoadingScenario, onComplete: (() -> Void)? = nil) {
        self.style = style
        self.message = mockScenario.message
        // Note: onComplete callback is ignored in this simple implementation
    }
    
    enum LoadingStateStyle {
        case overlay
        case card
        case inline
    }
    
    enum MockLoadingScenario {
        case familyCreation
        case dataSync
        case authentication
        case qrGeneration
        case general
        
        var message: String {
            switch self {
            case .familyCreation:
                return "Creating your family..."
            case .dataSync:
                return "Syncing data..."
            case .authentication:
                return "Authenticating..."
            case .qrGeneration:
                return "Generating QR code..."
            case .general:
                return "Loading..."
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(style == .overlay ? 1.2 : 1.0)
                .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
            
            Text(message)
                .font(style == .overlay ? .headline : .subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(style == .overlay ? 32 : 20)
        .background(backgroundView)
        .cornerRadius(style == .card ? BrandStyle.cornerRadius : 0)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .overlay:
            Color(.systemBackground)
                .opacity(0.95)
                .shadow(color: .black.opacity(0.1), radius: 10)
        case .card:
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 4)
        case .inline:
            Color.clear
        }
    }
}

/// Loading overlay specifically designed for card components
struct CardLoadingOverlay: View {
    let message: String
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var body: some View {
        VStack(spacing: BrandStyle.paddingMedium * min(dynamicTypeSize.customScaleFactor, 1.3)) {
            ProgressView()
                .scaleEffect(dynamicTypeSize.isAccessibilitySize ? 1.2 : 1.0)
                .progressViewStyle(CircularProgressViewStyle(tint: colorSchemeContrast == .increased ? .brandPrimaryAccessible : .brandPrimaryDynamic))
            
            Text(message)
                .accessibleFont(size: 15, maxSize: 18, weight: .medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(BrandStyle.paddingLarge * min(dynamicTypeSize.customScaleFactor, 1.3))
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                .fill(Color(.systemBackground).opacity(0.95))
                .shadow(
                    color: BrandStyle.standardShadow,
                    radius: BrandStyle.shadowRadius,
                    x: BrandStyle.shadowOffset.width,
                    y: BrandStyle.shadowOffset.height
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading: \(message)")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    VStack(spacing: 20) {
        LoadingStateView(message: "Loading...", style: .inline)
        LoadingStateView(message: "Creating your family...", style: .card)
        
        CardLoadingOverlay(message: "Searching for family...")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}