import SwiftUI

// MARK: - Enhanced Button Styles with Animations

struct PrimaryButtonStyle: ButtonStyle {
    let hapticStyle: HapticStyle
    
    init(hapticStyle: HapticStyle = .medium) {
        self.hapticStyle = hapticStyle
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(LinearGradient.brandGradient)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
                    .shadow(
                        color: BrandStyle.standardShadow,
                        radius: configuration.isPressed ? 4 : 8,
                        x: 0,
                        y: configuration.isPressed ? 2 : 4
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AnimationUtilities.buttonPress, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue {
                    hapticStyle.trigger()
                }
            }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    let hapticStyle: HapticStyle
    
    init(hapticStyle: HapticStyle = .light) {
        self.hapticStyle = hapticStyle
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.brandPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .stroke(Color.brandPrimary, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                            .fill(Color(.systemBackground))
                            .opacity(configuration.isPressed ? 0.8 : 1.0)
                    )
                    .shadow(
                        color: BrandStyle.standardShadow,
                        radius: configuration.isPressed ? 2 : 4,
                        x: 0,
                        y: configuration.isPressed ? 1 : 2
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AnimationUtilities.buttonPress, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue {
                    hapticStyle.trigger()
                }
            }
    }
}

struct TertiaryButtonStyle: ButtonStyle {
    let hapticStyle: HapticStyle
    
    init(hapticStyle: HapticStyle = .light) {
        self.hapticStyle = hapticStyle
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.brandPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                    .fill(Color.brandPrimary.opacity(configuration.isPressed ? 0.2 : 0.1))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AnimationUtilities.buttonPress, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue {
                    hapticStyle.trigger()
                }
            }
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    let hapticStyle: HapticStyle
    
    init(hapticStyle: HapticStyle = .warning) {
        self.hapticStyle = hapticStyle
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(Color.red)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
                    .shadow(
                        color: Color.red.opacity(0.3),
                        radius: configuration.isPressed ? 4 : 8,
                        x: 0,
                        y: configuration.isPressed ? 2 : 4
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AnimationUtilities.buttonPress, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue {
                    hapticStyle.trigger()
                }
            }
    }
}

struct IconButtonStyle: ButtonStyle {
    let size: CGFloat
    let backgroundColor: Color?
    let hapticStyle: HapticStyle
    
    init(size: CGFloat = 44, backgroundColor: Color? = nil, hapticStyle: HapticStyle = .light) {
        self.size = size
        self.backgroundColor = backgroundColor
        self.hapticStyle = hapticStyle
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.4, weight: .medium))
            .foregroundColor(.brandPrimary)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(backgroundColor ?? Color.brandPrimary.opacity(0.1))
                    .opacity(configuration.isPressed ? 0.6 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(AnimationUtilities.buttonPress, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue {
                    hapticStyle.trigger()
                }
            }
    }
}

struct CardButtonStyle: ButtonStyle {
    let hapticStyle: HapticStyle
    
    init(hapticStyle: HapticStyle = .light) {
        self.hapticStyle = hapticStyle
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: BrandStyle.standardShadow,
                        radius: configuration.isPressed ? 4 : 8,
                        x: 0,
                        y: configuration.isPressed ? 2 : 4
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AnimationUtilities.smooth, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue {
                    hapticStyle.trigger()
                }
            }
    }
}

struct FloatingActionButtonStyle: ButtonStyle {
    let hapticStyle: HapticStyle
    
    init(hapticStyle: HapticStyle = .medium) {
        self.hapticStyle = hapticStyle
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: 56, height: 56)
            .background(
                Circle()
                    .fill(LinearGradient.brandGradient)
                    .shadow(
                        color: BrandStyle.standardShadow,
                        radius: configuration.isPressed ? 8 : 12,
                        x: 0,
                        y: configuration.isPressed ? 4 : 6
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(AnimationUtilities.spring, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue {
                    hapticStyle.trigger()
                }
            }
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
// MARK: - Preview

#Preview("Enhanced Button Styles") {
    ScrollView {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Primary Buttons")
                    .font(.headline)
                
                Button("Create Family") {}
                    .buttonStyle(PrimaryButtonStyle())
                
                Button("Sign In") {}
                    .buttonStyle(PrimaryButtonStyle(hapticStyle: .success))
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Secondary Buttons")
                    .font(.headline)
                
                Button("Join Family") {}
                    .buttonStyle(SecondaryButtonStyle())
                
                Button("Cancel") {}
                    .buttonStyle(SecondaryButtonStyle(hapticStyle: .light))
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Tertiary Buttons")
                    .font(.headline)
                
                Button("Learn More") {}
                    .buttonStyle(TertiaryButtonStyle())
                
                Button("Skip") {}
                    .buttonStyle(TertiaryButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Destructive Buttons")
                    .font(.headline)
                
                Button("Delete Family") {}
                    .buttonStyle(DestructiveButtonStyle())
                
                Button("Remove Member") {}
                    .buttonStyle(DestructiveButtonStyle(hapticStyle: .error))
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Icon Buttons")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    Button(action: {}) {
                        Image(systemName: "heart.fill")
                    }
                    .buttonStyle(IconButtonStyle(backgroundColor: Color.red.opacity(0.1)))
                    
                    Button(action: {}) {
                        Image(systemName: "star.fill")
                    }
                    .buttonStyle(IconButtonStyle(size: 52, backgroundColor: Color.yellow.opacity(0.1)))
                    
                    Button(action: {}) {
                        Image(systemName: "message.fill")
                    }
                    .buttonStyle(IconButtonStyle())
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Card Buttons")
                    .font(.headline)
                
                Button(action: {}) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundColor(.brandPrimary)
                        
                        VStack(alignment: .leading) {
                            Text("Family Calendar")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("View upcoming events")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
                .buttonStyle(CardButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Floating Action Button")
                    .font(.headline)
                
                HStack {
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(FloatingActionButtonStyle())
                }
            }
        }
        .padding()
    }
}