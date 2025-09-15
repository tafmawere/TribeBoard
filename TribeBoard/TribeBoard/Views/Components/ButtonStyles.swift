import SwiftUI

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient.brandGradient
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .cornerRadius(BrandStyle.cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.brandPrimary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                Color.clear
                    .overlay(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                            .stroke(Color.brandPrimary, lineWidth: 2)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview("Button Styles") {
    VStack(spacing: 20) {
        Button("Primary Button") {}
            .buttonStyle(PrimaryButtonStyle())
        
        Button("Secondary Button") {}
            .buttonStyle(SecondaryButtonStyle())
    }
    .padding()
}