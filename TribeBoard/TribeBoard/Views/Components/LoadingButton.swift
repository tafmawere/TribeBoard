import SwiftUI

/// A button that shows loading state with spinner
struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    let style: LoadingButtonStyle
    
    enum LoadingButtonStyle {
        case primary
        case secondary
        case destructive
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                } else {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColor)
            .cornerRadius(BrandStyle.cornerRadius)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return Color.brandPrimary
        case .secondary:
            return Color(.systemGray5)
        case .destructive:
            return Color.red
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary, .destructive:
            return .white
        case .secondary:
            return .primary
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        LoadingButton(title: "Primary Button", isLoading: false, action: {}, style: .primary)
        LoadingButton(title: "Loading...", isLoading: true, action: {}, style: .primary)
        LoadingButton(title: "Secondary Button", isLoading: false, action: {}, style: .secondary)
        LoadingButton(title: "Destructive Button", isLoading: false, action: {}, style: .destructive)
    }
    .padding()
}