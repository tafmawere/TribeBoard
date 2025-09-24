import SwiftUI

/// Font modifier to resolve ambiguity
struct FontModifier: ViewModifier {
    let font: Font
    
    func body(content: Content) -> some View {
        content.font(font)
    }
}

/// School Run UI View - UI/UX showcase implementation with static data
struct SchoolRunView: View {
    @State private var isRunActive: Bool = false
    @StateObject private var toastManager = ToastManager.shared
    
    // Accessibility environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: 0) {
            // Map placeholder component with route visualization
            MapPlaceholderView(isRunActive: isRunActive)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("School run route map")
                .accessibilityHint("Shows the route from home to school with current driver position")
                .accessibilityValue(isRunActive ? "Run is in progress" : "Run has not started")
            
            // Trip information card
            TripInformationCard(isRunActive: $isRunActive)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            
            Spacer()
        }
        .navigationTitle("School Run")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Family logo/avatar placeholder with adequate touch target
                Button(action: {
                    // Add haptic feedback for family avatar tap
                    HapticManager.shared.lightImpact()
                }) {
                    Image(systemName: "person.2.circle.fill")
                        .font(DesignSystem.Typography.titleMedium) // SF Pro font from DesignSystem
                        .foregroundColor(colorSchemeContrast == .increased ? .blue : .brandPrimary)
                        .frame(width: 44, height: 44) // Minimum 44pt touch target
                }
                .accessibilityLabel("Family profile")
                .accessibilityHint("View family information and settings")
                .accessibilityAddTraits(.isButton)
            }
        }
        .withToast() // Add toast notification support
        .accessibilityElement(children: .contain)
        .accessibilityLabel("School Run Screen")
        .accessibilityHint("Manage and track school transportation runs")
    }
}

// MARK: - Map Placeholder Component

/// Map placeholder component with route visualization and location icons
struct MapPlaceholderView: View {
    let isRunActive: Bool
    
    // Accessibility environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var body: some View {
        ZStack {
            // Gray rectangle container with "Map Placeholder" text
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color.gray.opacity(colorSchemeContrast == .increased ? 0.2 : 0.1))
                .frame(height: 250)
                .overlay(
                    Text("Map Placeholder")
                        .font(scaledFont(DesignSystem.Typography.bodyMedium))
                        .foregroundColor(colorSchemeContrast == .increased ? .primary : .secondary)
                )
            
            // Static route line using Path
            RouteLineView(isRunActive: isRunActive)
            
            // Location icons overlay
            LocationIconsOverlay(isRunActive: isRunActive)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.lg)
    }
    
    /// Scale font based on dynamic type size with reasonable limits
    private func scaledFont(_ baseFont: Font) -> Font {
        let scaleFactor = min(dynamicTypeSize.scaleFactor, 1.5) // Cap at 150% for map text
        return Font.system(size: 16 * scaleFactor, weight: .regular, design: .default)
    }
}

// MARK: - Route Line Component

/// Static route line visualization using Path and stroke
struct RouteLineView: View {
    let isRunActive: Bool
    
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Path { path in
            let points = SchoolRunUIData.routePoints
            
            // Convert static points to relative positions within the 250pt height container
            let containerWidth: CGFloat = 300 // Approximate container width
            let containerHeight: CGFloat = 250
            
            // Scale points to fit within container
            let scaledPoints = points.map { point in
                CGPoint(
                    x: (point.x / 250) * containerWidth,
                    y: (point.y / 150) * containerHeight * 0.6 + containerHeight * 0.2
                )
            }
            
            // Draw route path
            if let firstPoint = scaledPoints.first {
                path.move(to: firstPoint)
                
                for point in scaledPoints.dropFirst() {
                    path.addLine(to: point)
                }
            }
        }
        .stroke(
            routeColor,
            lineWidth: isRunActive ? 4 : 3
        )
        .animation(reduceMotion ? nil : DesignSystem.Animation.standard, value: isRunActive)
        .accessibilityHidden(true) // Route line is decorative, described by parent element
    }
    
    /// Route color with high contrast support
    private var routeColor: Color {
        if colorSchemeContrast == .increased {
            return isRunActive ? .blue : .blue.opacity(0.7)
        } else {
            return isRunActive ? Color.brandPrimary : Color.brandPrimary.opacity(0.6)
        }
    }
}

// MARK: - Location Icons Overlay

/// Location icons (🚗, 🏫, 🏠) positioned as overlays
struct LocationIconsOverlay: View {
    let isRunActive: Bool
    @State private var driverOffset: CGFloat = 0
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Home icon (🏠) - left side
                LocationIcon(emoji: "🏠", label: "Home")
                    .position(
                        x: width * 0.2,
                        y: height * 0.7
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Home location")
                    .accessibilityHint("Starting point of the school run")
                
                // School icon (🏫) - right side  
                LocationIcon(emoji: "🏫", label: "School")
                    .position(
                        x: width * 0.8,
                        y: height * 0.6
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("School location")
                    .accessibilityHint("Destination of the school run")
                
                // Driver icon (🚗) - center-left, representing current position with animation
                LocationIcon(emoji: "🚗", label: "Driver", isActive: isRunActive)
                    .position(
                        x: width * 0.5 + driverOffset,
                        y: height * 0.5
                    )
                    .onAppear {
                        if isRunActive && !reduceMotion {
                            startDriverAnimation()
                        }
                    }
                    .onChange(of: isRunActive) { _, newValue in
                        if newValue && !reduceMotion {
                            startDriverAnimation()
                        } else {
                            stopDriverAnimation()
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Driver current position")
                    .accessibilityHint(isRunActive ? "Driver is currently on route" : "Driver has not started the run")
                    .accessibilityValue(isRunActive ? "Moving" : "Stationary")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Route locations")
        .accessibilityHint("Shows home, school, and current driver position")
    }
    
    private func startDriverAnimation() {
        guard !reduceMotion else { return }
        withAnimation(
            Animation.easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
        ) {
            driverOffset = 20
        }
    }
    
    private func stopDriverAnimation() {
        withAnimation(reduceMotion ? nil : DesignSystem.Animation.standard) {
            driverOffset = 0
        }
    }
}

// MARK: - Individual Location Icon

/// Individual location icon with emoji and background
struct LocationIcon: View {
    let emoji: String
    let label: String
    let isActive: Bool
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(emoji: String, label: String, isActive: Bool = false) {
        self.emoji = emoji
        self.label = label
        self.isActive = isActive
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: 44, height: 44) // Minimum 44pt touch target
                    .mediumShadow()
                    .overlay(
                        Circle()
                            .stroke(
                                strokeColor,
                                lineWidth: isActive ? 2 : 0
                            )
                            .animation(reduceMotion ? nil : DesignSystem.Animation.standard, value: isActive)
                    )
                
                Text(emoji)
                    .font(scaledEmojiFont)
                    .scaleEffect(isActive && !reduceMotion ? 1.1 : 1.0)
                    .animation(reduceMotion ? nil : DesignSystem.Animation.spring, value: isActive)
                    .accessibilityHidden(true) // Emoji is decorative, label provides context
            }
            
            Text(label)
                .font(scaledLabelFont)
                .foregroundColor(labelColor)
                .fontWeight(isActive ? .semibold : .regular)
                .animation(reduceMotion ? nil : DesignSystem.Animation.standard, value: isActive)
                .dynamicTypeSupport(minSize: 8, maxSize: 16) // Limit scaling for map labels
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) location")
        .accessibilityValue(isActive ? "Active" : "Inactive")
    }
    
    /// Stroke color with high contrast support
    private var strokeColor: Color {
        if colorSchemeContrast == .increased {
            return isActive ? .blue : .clear
        } else {
            return isActive ? Color.brandPrimary : .clear
        }
    }
    
    /// Label color with high contrast support
    private var labelColor: Color {
        if colorSchemeContrast == .increased {
            return isActive ? .blue : .primary
        } else {
            return isActive ? .brandPrimary : .secondary
        }
    }
    
    /// Scaled emoji font with reasonable limits
    private var scaledEmojiFont: Font {
        let scaleFactor = min(dynamicTypeSize.scaleFactor, 1.3) // Cap emoji scaling
        return Font.system(size: 20 * scaleFactor, weight: .regular, design: .default)
    }
    
    /// Scaled label font with reasonable limits
    private var scaledLabelFont: Font {
        let scaleFactor = min(dynamicTypeSize.scaleFactor, 1.2) // Cap label scaling
        return Font.system(size: 10 * scaleFactor, weight: .regular, design: .default)
    }
}

// MARK: - Trip Information Card

/// Main trip information card with rounded corners, shadow, and proper spacing
struct TripInformationCard: View {
    @Binding var isRunActive: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Driver info section with static data
            DriverInfoSection()
            
            // Children section with multiple static avatars
            ChildrenSection()
            
            // Destination info section with static data
            DestinationInfoSection()
            
            // ETA section with static data
            ETASection()
            
            // Status badge component
            StatusBadgeSection(isRunActive: isRunActive)
            
            // Primary action button with toggle functionality
            PrimaryActionButtonSection(isRunActive: $isRunActive)
            
            // Secondary action buttons
            SecondaryActionButtonsSection()
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .mediumShadow()
                .animation(reduceMotion ? nil : DesignSystem.Animation.standard, value: isRunActive)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Trip information card")
        .accessibilityHint("Contains details about the current school run including driver, children, destination, and controls")
    }
}

// MARK: - Driver Info Section

/// Driver info section displaying static avatar and name with proper typography and spacing
struct DriverInfoSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Driver avatar with adequate touch target
            Image(systemName: SchoolRunUIData.driverInfo.avatar)
                .font(scaledAvatarFont)
                .foregroundColor(avatarColor)
                .frame(width: 44, height: 44) // Minimum 44pt touch target
                .background(
                    Circle()
                        .fill(avatarBackgroundColor)
                )
                .accessibilityHidden(true) // Icon is decorative, name provides context
            
            // Driver name with SF Pro typography
            Text(SchoolRunUIData.driverInfo.name)
                .modifier(FontModifier(font: scaledNameFont))
                .foregroundColor(.primary)
                .dynamicTypeSupport()
            
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Driver: \(SchoolRunUIData.driverInfo.name)")
        .accessibilityHint(Text("The person driving for this school run"))
        .accessibilityAddTraits(.isStaticText)
    }
    
    /// Avatar color with high contrast support
    private var avatarColor: Color {
        colorSchemeContrast == .increased ? .blue : .brandPrimary
    }
    
    /// Avatar background color with high contrast support
    private var avatarBackgroundColor: Color {
        if colorSchemeContrast == .increased {
            return Color.blue.opacity(0.15)
        } else {
            return Color.brandPrimary.opacity(0.1)
        }
    }
    
    /// Scaled avatar font
    private var scaledAvatarFont: Font {
        let scaleFactor = min(dynamicTypeSize.scaleFactor, 1.3)
        return Font.system(size: 22 * scaleFactor, weight: .regular, design: .default)
    }
    
    /// Scaled name font
    private var scaledNameFont: Font {
        let scaleFactor = dynamicTypeSize.scaleFactor
        return Font.system(size: 17 * scaleFactor, weight: .regular, design: .default)
    }
}

// MARK: - Children Section

/// Children section displaying 2-3 static child avatars in horizontal layout with names
struct ChildrenSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Section title with SF Pro typography
            Text("Children")
                .modifier(FontModifier(font: scaledTitleFont))
                .foregroundColor(.secondary)
                .dynamicTypeSupport()
            
            // Children avatars in horizontal layout
            HStack(spacing: DesignSystem.Spacing.md) {
                ForEach(SchoolRunUIData.children.indices, id: \.self) { index in
                    let child = SchoolRunUIData.children[index]
                    ChildAvatarView(child: child)
                }
                
                Spacer()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Children on this run")
        .accessibilityHint("List of children participating in the school run")
    }
    
    /// Scaled title font
    private var scaledTitleFont: Font {
        let scaleFactor = dynamicTypeSize.scaleFactor
        return Font.system(size: 14 * scaleFactor, weight: .medium, design: .default)
    }
}

// MARK: - Individual Child Avatar

/// Individual child avatar component with consistent sizing and spacing
struct ChildAvatarView: View {
    let child: ChildInfo
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            // Child avatar with adequate touch target (44x44 minimum)
            Image(systemName: child.avatar)
                .font(scaledAvatarFont)
                .foregroundColor(avatarColor)
                .frame(width: 44, height: 44) // Minimum 44pt touch target
                .background(
                    Circle()
                        .fill(avatarBackgroundColor)
                )
                .accessibilityHidden(true) // Icon is decorative, name provides context
            
            // Child name with SF Pro typography
            Text(child.name)
                .font(scaledNameFont)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .dynamicTypeSupport(minSize: 9, maxSize: 14) // Limit scaling for compact layout
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Child: \(child.name)")
        .accessibilityHint("Participating in this school run")
        .accessibilityAddTraits(.isStaticText)
    }
    
    /// Avatar color with high contrast support
    private var avatarColor: Color {
        colorSchemeContrast == .increased ? .blue : .brandPrimary
    }
    
    /// Avatar background color with high contrast support
    private var avatarBackgroundColor: Color {
        if colorSchemeContrast == .increased {
            return Color.blue.opacity(0.15)
        } else {
            return Color.brandPrimary.opacity(0.1)
        }
    }
    
    /// Scaled avatar font
    private var scaledAvatarFont: Font {
        let scaleFactor = min(dynamicTypeSize.scaleFactor, 1.2)
        return Font.system(size: 20 * scaleFactor, weight: .regular, design: .default)
    }
    
    /// Scaled name font
    private var scaledNameFont: Font {
        let scaleFactor = min(dynamicTypeSize.scaleFactor, 1.3)
        return Font.system(size: 11 * scaleFactor, weight: .regular, design: .default)
    }
}

// MARK: - Destination Info Section

/// Destination info section displaying static destination name and time
struct DestinationInfoSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Destination icon with adequate touch target
            Image(systemName: "location.fill")
                .font(scaledIconFont)
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44) // Minimum 44pt touch target
                .background(
                    Circle()
                        .fill(iconBackgroundColor)
                )
                .accessibilityHidden(true) // Icon is decorative, text provides context
            
            // Destination info with SF Pro typography
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Destination")
                    .modifier(FontModifier(font: scaledLabelFont))
                    .foregroundColor(.secondary)
                    .dynamicTypeSupport()
                
                Text("\(SchoolRunUIData.destination.name) – \(SchoolRunUIData.destination.time)")
                    .font(scaledValueFont)
                    .foregroundColor(.primary)
                    .dynamicTypeSupport()
            }
            
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Destination: \(SchoolRunUIData.destination.name) at \(SchoolRunUIData.destination.time)")
        .accessibilityHint(Text("The destination and scheduled time for this school run"))
        .accessibilityAddTraits(.isStaticText)
    }
    
    /// Icon color with high contrast support
    private var iconColor: Color {
        colorSchemeContrast == .increased ? .blue : .brandPrimary
    }
    
    /// Icon background color with high contrast support
    private var iconBackgroundColor: Color {
        if colorSchemeContrast == .increased {
            return Color.blue.opacity(0.15)
        } else {
            return Color.brandPrimary.opacity(0.1)
        }
    }
    
    /// Scaled icon font
    private var scaledIconFont: Font {
        let scaleFactor = min(dynamicTypeSize.scaleFactor, 1.3)
        return Font.system(size: 20 * scaleFactor, weight: .regular, design: .default)
    }
    
    /// Scaled label font
    private var scaledLabelFont: Font {
        let scaleFactor = dynamicTypeSize.scaleFactor
        return Font.system(size: 13 * scaleFactor, weight: .medium, design: .default)
    }
    
    /// Scaled value font
    private var scaledValueFont: Font {
        let scaleFactor = dynamicTypeSize.scaleFactor
        return Font.system(size: 17 * scaleFactor, weight: .regular, design: .default)
    }
}

// MARK: - ETA Section

/// ETA section displaying static estimated time of arrival
struct ETASection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // ETA icon with adequate touch target
            Image(systemName: "clock.fill")
                .font(scaledIconFont)
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44) // Minimum 44pt touch target
                .background(
                    Circle()
                        .fill(iconBackgroundColor)
                )
                .accessibilityHidden(true) // Icon is decorative, text provides context
            
            // ETA info with SF Pro typography
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Estimated Arrival")
                    .modifier(FontModifier(font: scaledLabelFont))
                    .foregroundColor(.secondary)
                    .dynamicTypeSupport()
                
                Text("ETA: \(SchoolRunUIData.eta)")
                    .font(scaledValueFont)
                    .foregroundColor(.primary)
                    .dynamicTypeSupport()
            }
            
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Estimated arrival time: \(SchoolRunUIData.eta)")
        .accessibilityHint(Text("How long until the driver reaches the destination"))
        .accessibilityAddTraits(.isStaticText)
    }
    
    /// Icon color with high contrast support
    private var iconColor: Color {
        colorSchemeContrast == .increased ? .blue : .brandPrimary
    }
    
    /// Icon background color with high contrast support
    private var iconBackgroundColor: Color {
        if colorSchemeContrast == .increased {
            return Color.blue.opacity(0.15)
        } else {
            return Color.brandPrimary.opacity(0.1)
        }
    }
    
    /// Scaled icon font
    private var scaledIconFont: Font {
        let scaleFactor = min(dynamicTypeSize.scaleFactor, 1.3)
        return Font.system(size: 20 * scaleFactor, weight: .regular, design: .default)
    }
    
    /// Scaled label font
    private var scaledLabelFont: Font {
        let scaleFactor = dynamicTypeSize.scaleFactor
        return Font.system(size: 13 * scaleFactor, weight: .medium, design: .default)
    }
    
    /// Scaled value font
    private var scaledValueFont: Font {
        let scaleFactor = dynamicTypeSize.scaleFactor
        return Font.system(size: 17 * scaleFactor, weight: .regular, design: .default)
    }
}

// MARK: - Status Badge Section

/// Status badge section displaying current run status as rounded capsule
struct StatusBadgeSection: View {
    let isRunActive: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack {
            Spacer()
            
            // Status badge as rounded capsule with dynamic status
            SchoolRunStatusBadge(status: isRunActive ? .inProgress : .notStarted)
                .animation(reduceMotion ? nil : DesignSystem.Animation.standard, value: isRunActive)
            
            Spacer()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Run status")
        .accessibilityHint("Current status of the school run")
    }
}

// MARK: - School Run Status Badge Component

/// Rounded capsule status badge showing run status with proper color styling
struct SchoolRunStatusBadge: View {
    let status: RunStatus
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var body: some View {
        Text(status.displayText)
            .modifier(FontModifier(font: scaledFont))
            .foregroundColor(textColor)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                Capsule()
                    .fill(badgeColor)
            )
            .dynamicTypeSupport()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Status: \(status.displayText)")
            .accessibilityHint("Current state of the school run")
            .accessibilityAddTraits(.isStaticText)
    }
    
    /// Badge color with high contrast support
    private var badgeColor: Color {
        if colorSchemeContrast == .increased {
            switch status {
            case .notStarted: return .gray
            case .inProgress: return .blue
            case .completed: return .green
            }
        } else {
            return status.color
        }
    }
    
    /// Text color with high contrast support
    private var textColor: Color {
        if colorSchemeContrast == .increased {
            return .white
        } else {
            return .white
        }
    }
    
    /// Scaled font
    private var scaledFont: Font {
        let scaleFactor = dynamicTypeSize.scaleFactor
        return Font.system(size: 13 * scaleFactor, weight: .medium, design: .default)
    }
}

// MARK: - Primary Action Button Section

/// Primary action button with toggle functionality between "Start Run" and "End Run"
struct PrimaryActionButtonSection: View {
    @Binding var isRunActive: Bool
    @State private var isPressed: Bool = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        if isRunActive {
            Button("End Run") {
                // Add haptic feedback for destructive action
                HapticManager.shared.heavyImpact()
                
                // Animate button state change
                withAnimation(reduceMotion ? nil : DesignSystem.Animation.standard) {
                    isRunActive.toggle()
                }
            }
            .buttonStyle(DestructiveButtonStyle())
            .scaleEffect(isPressed && !reduceMotion ? 0.95 : 1.0)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(reduceMotion ? nil : DesignSystem.Animation.buttonPress) {
                    isPressed = pressing
                }
            }, perform: {})
            .accessibilityLabel("End school run")
            .accessibilityHint("Tap to stop the current school run")
            .accessibilityAddTraits(.isButton)
            .accessibilityRemoveTraits(.isSelected)
        } else {
            Button("Start Run") {
                // Add haptic feedback for primary action
                HapticManager.shared.success()
                
                // Animate button state change
                withAnimation(reduceMotion ? nil : DesignSystem.Animation.standard) {
                    isRunActive.toggle()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .scaleEffect(isPressed && !reduceMotion ? 0.95 : 1.0)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(reduceMotion ? nil : DesignSystem.Animation.buttonPress) {
                    isPressed = pressing
                }
            }, perform: {})
            .accessibilityLabel("Start school run")
            .accessibilityHint("Tap to begin the school run")
            .accessibilityAddTraits(.isButton)
        }
    }
}

// MARK: - Secondary Action Buttons Section

/// Secondary action buttons including "Notify Family" and circular red "SOS" button
struct SecondaryActionButtonsSection: View {
    @State private var showNotificationSent: Bool = false
    @State private var showSOSAlert: Bool = false
    @State private var notifyButtonPressed: Bool = false
    @State private var sosButtonPressed: Bool = false
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // "Notify Family" button with outline style using SecondaryButtonStyle
            Button("Notify Family") {
                // Add haptic feedback for notification action
                HapticManager.shared.success()
                
                // Show toast notification feedback
                ToastManager.shared.success("📱 Family has been notified about the school run")
                
                showNotificationSent = true
            }
            .buttonStyle(SecondaryButtonStyle())
            .scaleEffect(notifyButtonPressed && !reduceMotion ? 0.95 : 1.0)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(reduceMotion ? nil : DesignSystem.Animation.buttonPress) {
                    notifyButtonPressed = pressing
                }
            }, perform: {})
            .accessibilityLabel("Notify family")
            .accessibilityHint("Send a notification to all family members about the school run status")
            .accessibilityAddTraits(.isButton)
            
            // SOS button positioned at bottom-right of card
            HStack {
                Spacer()
                
                Button("SOS") {
                    // Add strong haptic feedback for emergency action
                    HapticManager.shared.error()
                    
                    // Animate SOS button press
                    if !reduceMotion {
                        withAnimation(DesignSystem.Animation.quick) {
                            sosButtonPressed = true
                        }
                        
                        // Reset animation and show alert
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(DesignSystem.Animation.quick) {
                                sosButtonPressed = false
                            }
                            showSOSAlert = true
                        }
                    } else {
                        showSOSAlert = true
                    }
                }
                .buttonStyle(IconButtonStyle(size: 44, backgroundColor: .red))
                .foregroundColor(.white)
                .scaleEffect(sosButtonPressed && !reduceMotion ? 0.9 : 1.0)
                .shadow(color: .red.opacity(sosButtonPressed ? 0.4 : 0.2), radius: sosButtonPressed ? 8 : 4)
                .accessibilityLabel("Emergency SOS")
                .accessibilityHint("Send an emergency alert to all family members. Double tap to confirm.")
                .accessibilityAddTraits([.isButton])
            }
        }
        .alert("Emergency Alert", isPresented: $showSOSAlert) {
            Button("Send SOS", role: .destructive) {
                // Add haptic feedback for SOS confirmation
                HapticManager.shared.error()
                
                // Show toast notification for SOS sent
                ToastManager.shared.error("🚨 Emergency alert sent to all family members")
            }
            .accessibilityLabel("Confirm emergency alert")
            .accessibilityHint("This will immediately send an emergency notification to all family members")
            
            Button("Cancel", role: .cancel) {
                // Add light haptic feedback for cancel
                HapticManager.shared.lightImpact()
            }
            .accessibilityLabel("Cancel emergency alert")
            .accessibilityHint("Do not send the emergency notification")
        } message: {
            Text("This will send an emergency alert to all family members.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Secondary actions")
        .accessibilityHint("Additional controls for family communication and emergency situations")
    }
}

// MARK: - Accessibility Support
// Note: DynamicTypeSize extension and dynamicTypeSupport modifier are already defined in AccessibilityHelpers.swift

// MARK: - Comprehensive SwiftUI Previews

/// Preview showing the default "Not Started" state
#Preview("Not Started State") {
    NavigationView {
        SchoolRunView()
    }
}

/// Preview showing the "In Progress" state with active run
#Preview("In Progress State") {
    NavigationView {
        SchoolRunInProgressPreview()
    }
}

/// Preview showing dark mode compatibility
#Preview("Dark Mode") {
    NavigationView {
        SchoolRunView()
    }
    .preferredColorScheme(.dark)
}

/// Preview showing dark mode with active run
#Preview("Dark Mode - Active Run") {
    NavigationView {
        SchoolRunInProgressPreview()
    }
    .preferredColorScheme(.dark)
}

/// Preview showing accessibility support with large text
#Preview("Large Text (A11y)") {
    NavigationView {
        SchoolRunView()
    }
    .environment(\.dynamicTypeSize, .accessibility2)
}

/// Preview showing extra large text accessibility
#Preview("Extra Large Text") {
    NavigationView {
        SchoolRunView()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

/// Preview showing high contrast mode simulation
#Preview("High Contrast") {
    NavigationView {
        HighContrastPreview()
    }
}

/// Preview showing reduced motion accessibility
#Preview("Reduced Motion") {
    NavigationView {
        ReducedMotionPreview()
    }
}

/// Preview demonstrating interactive button state changes
#Preview("Interactive States") {
    NavigationView {
        SchoolRunInteractivePreview()
    }
}

/// Preview showing compact device layout (iPhone SE)
#Preview("iPhone SE", traits: .fixedLayout(width: 375, height: 667)) {
    NavigationView {
        SchoolRunView()
    }
}

/// Preview showing large device layout (iPhone Pro Max)
#Preview("iPhone Pro Max", traits: .fixedLayout(width: 428, height: 926)) {
    NavigationView {
        SchoolRunView()
    }
}

/// Preview showing landscape orientation
#Preview("Landscape", traits: .landscapeLeft) {
    NavigationView {
        SchoolRunView()
    }
}

/// Preview combining multiple accessibility features
#Preview("Full A11y Features") {
    NavigationView {
        FullAccessibilityPreview()
    }
}

/// Preview showing all states in a comparison view
#Preview("State Comparison") {
    ScrollView {
        VStack(spacing: 20) {
            Group {
                Text("Not Started State")
                    .font(.headline)
                    .padding(.top)
                
                SchoolRunView()
                    .frame(height: 600)
                    .border(Color.gray.opacity(0.3))
                
                Text("In Progress State")
                    .font(.headline)
                    .padding(.top)
                
                SchoolRunInProgressPreview()
                    .frame(height: 600)
                    .border(Color.gray.opacity(0.3))
            }
        }
        .padding()
    }
}

// MARK: - Preview Helper Views

/// Helper view to simulate high contrast mode
private struct HighContrastPreview: View {
    var body: some View {
        SchoolRunView()
            .preferredColorScheme(.light)
            .environment(\.dynamicTypeSize, .large)
            // Note: High contrast mode simulation - actual testing requires device/simulator settings
    }
}

/// Helper view to simulate reduced motion
private struct ReducedMotionPreview: View {
    var body: some View {
        SchoolRunView()
            .environment(\.dynamicTypeSize, .large)
            // Note: Reduced motion simulation - actual testing requires device/simulator settings
    }
}

/// Helper view combining multiple accessibility features
private struct FullAccessibilityPreview: View {
    var body: some View {
        SchoolRunView()
            .environment(\.dynamicTypeSize, .accessibility1)
            .preferredColorScheme(.light)
            // Note: Full accessibility testing requires device/simulator settings for contrast and motion
    }
}

/// Helper view to demonstrate the "In Progress" state
private struct SchoolRunInProgressPreview: View {
    @State private var isRunActive: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Map placeholder component with route visualization
            MapPlaceholderView(isRunActive: isRunActive)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("School run route map")
                .accessibilityHint("Shows the route from home to school with current driver position")
                .accessibilityValue(isRunActive ? "Run is in progress" : "Run has not started")
            
            // Trip information card
            TripInformationCard(isRunActive: $isRunActive)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            
            Spacer()
        }
        .navigationTitle("School Run")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "person.2.circle.fill")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(.brandPrimary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Family profile")
                .accessibilityHint("View family information and settings")
            }
        }
        .withToast()
    }
}

/// Helper view to demonstrate interactive state changes
private struct SchoolRunInteractivePreview: View {
    @State private var isRunActive: Bool = false
    @State private var demonstrationStep: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Demonstration controls
            VStack(spacing: 8) {
                Text("Interactive Demo")
                    .font(.headline)
                    .foregroundColor(.brandPrimary)
                
                HStack(spacing: 12) {
                    Button("Not Started") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isRunActive = false
                            demonstrationStep = 0
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("In Progress") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            isRunActive = true
                            demonstrationStep = 1
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Auto Demo") {
                        startAutomaticDemo()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Main content
            VStack(spacing: 0) {
                MapPlaceholderView(isRunActive: isRunActive)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("School run route map")
                    .accessibilityHint("Shows the route from home to school with current driver position")
                    .accessibilityValue(isRunActive ? "Run is in progress" : "Run has not started")
                
                TripInformationCard(isRunActive: $isRunActive)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                
                Spacer()
            }
        }
        .navigationTitle("School Run")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "person.2.circle.fill")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(.brandPrimary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Family profile")
                .accessibilityHint("View family information and settings")
            }
        }
        .withToast()
    }
    
    /// Automatically cycles through different states for demonstration
    private func startAutomaticDemo() {
        // Start with not started state
        withAnimation(.easeInOut(duration: 0.5)) {
            isRunActive = false
            demonstrationStep = 0
        }
        
        // After 2 seconds, switch to in progress
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isRunActive = true
                demonstrationStep = 1
            }
        }
        
        // After 4 seconds, switch back to not started
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isRunActive = false
                demonstrationStep = 0
            }
        }
    }
}