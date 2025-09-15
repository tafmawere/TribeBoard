import SwiftUI

/// TribeBoard logo component that can be used throughout the app
struct TribeBoardLogo: View {
    
    enum Size {
        case small      // 32x32
        case medium     // 64x64
        case large      // 128x128
        case extraLarge // 256x256
        
        var dimension: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 64
            case .large: return 128
            case .extraLarge: return 256
            }
        }
    }
    
    let size: Size
    let showBackground: Bool
    
    init(size: Size = .medium, showBackground: Bool = true) {
        self.size = size
        self.showBackground = showBackground
    }
    
    var body: some View {
        ZStack {
            if showBackground {
                // Background with brand gradient matching the logo
                RoundedRectangle(cornerRadius: size.dimension * 0.2)
                    .fill(LinearGradient.brandGradient)
            }
            
            // House icon with family figures (simplified representation)
            VStack(spacing: 0) {
                // House roof
                Image(systemName: "house.fill")
                    .font(.system(size: size.dimension * 0.6, weight: .medium))
                    .foregroundColor(showBackground ? .white : .brandPrimary)
            }
        }
        .frame(width: size.dimension, height: size.dimension)
    }
}

// MARK: - Logo with Text

struct TribeBoardLogoWithText: View {
    let size: TribeBoardLogo.Size
    let showBackground: Bool
    
    init(size: TribeBoardLogo.Size = .medium, showBackground: Bool = true) {
        self.size = size
        self.showBackground = showBackground
    }
    
    var body: some View {
        HStack(spacing: size.dimension * 0.2) {
            TribeBoardLogo(size: size, showBackground: showBackground)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("TribeBoard")
                    .font(.system(size: size.dimension * 0.25, weight: .bold, design: .rounded))
                    .foregroundColor(showBackground ? .primary : .brandPrimary)
                
                if size.dimension >= 64 {
                    Text("Family Together")
                        .font(.system(size: size.dimension * 0.12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - App Icon Placeholder

/// A view that represents the app icon for use in UI
struct AppIconView: View {
    let size: CGFloat
    
    init(size: CGFloat = 60) {
        self.size = size
    }
    
    var body: some View {
        TribeBoardLogo(
            size: size <= 32 ? .small :
                  size <= 64 ? .medium :
                  size <= 128 ? .large : .extraLarge,
            showBackground: true
        )
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
        .shadow(
            color: BrandStyle.standardShadow,
            radius: BrandStyle.shadowRadius * (size / 64),
            x: BrandStyle.shadowOffset.width,
            y: BrandStyle.shadowOffset.height
        )
    }
}

// MARK: - Preview

#if DEBUG
struct TribeBoardLogo_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // Different sizes
            HStack(spacing: 20) {
                TribeBoardLogo(size: .small)
                TribeBoardLogo(size: .medium)
                TribeBoardLogo(size: .large)
            }
            
            // With and without background
            HStack(spacing: 20) {
                TribeBoardLogo(size: .medium, showBackground: true)
                TribeBoardLogo(size: .medium, showBackground: false)
            }
            
            // Logo with text
            VStack(spacing: 16) {
                TribeBoardLogoWithText(size: .medium)
                TribeBoardLogoWithText(size: .large)
            }
            
            // App icon representation
            HStack(spacing: 16) {
                AppIconView(size: 40)
                AppIconView(size: 60)
                AppIconView(size: 80)
            }
        }
        .padding()
        .previewDisplayName("TribeBoard Logo")
    }
}
#endif