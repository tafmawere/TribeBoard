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

#Preview {
    VStack(spacing: 20) {
        LoadingStateView(message: "Loading...", style: .inline)
        LoadingStateView(message: "Creating your family...", style: .card)
    }
    .padding()
}