import SwiftUI

/// Reusable quick action buttons component with consistent styling
struct QuickActionButtons: View {
    let actions: [QuickAction]
    let layout: Layout
    
    enum Layout {
        case horizontal
        case vertical
        case grid(columns: Int)
    }
    
    struct QuickAction {
        let id = UUID()
        let title: String
        let icon: String
        let color: Color
        let action: () -> Void
        let isEnabled: Bool
        let hapticStyle: HapticStyle
        
        init(
            title: String,
            icon: String,
            color: Color = .brandPrimary,
            isEnabled: Bool = true,
            hapticStyle: HapticStyle = .light,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.icon = icon
            self.color = color
            self.isEnabled = isEnabled
            self.hapticStyle = hapticStyle
            self.action = action
        }
    }
    
    init(actions: [QuickAction], layout: Layout = .horizontal) {
        self.actions = actions
        self.layout = layout
    }
    
    var body: some View {
        Group {
            switch layout {
            case .horizontal:
                horizontalLayout
            case .vertical:
                verticalLayout
            case .grid(let columns):
                gridLayout(columns: columns)
            }
        }
    }
    
    // MARK: - Layout Variants
    
    private var horizontalLayout: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ForEach(actions, id: \.id) { action in
                QuickActionButton(
                    title: action.title,
                    icon: action.icon,
                    color: action.color,
                    action: action.action
                )
            }
        }
    }
    
    private var verticalLayout: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ForEach(actions, id: \.id) { action in
                QuickActionButton(
                    title: action.title,
                    icon: action.icon,
                    color: action.color,
                    action: action.action
                )
            }
        }
    }
    
    private func gridLayout(columns: Int) -> some View {
        let gridColumns = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.md), count: columns)
        
        return LazyVGrid(columns: gridColumns, spacing: DesignSystem.Spacing.md) {
            ForEach(actions, id: \.id) { action in
                QuickActionButton(
                    title: action.title,
                    icon: action.icon,
                    color: action.color,
                    action: action.action
                )
            }
        }
    }
}



// MARK: - Predefined Action Sets

extension QuickActionButtons {
    
    /// Common school run actions
    static func schoolRunActions(
        onNewRun: @escaping () -> Void,
        onHistory: @escaping () -> Void,
        onSettings: @escaping () -> Void
    ) -> QuickActionButtons {
        let actions = [
            QuickAction(
                title: "New Run",
                icon: "plus.circle.fill",
                color: .green,
                hapticStyle: .medium,
                action: onNewRun
            ),
            QuickAction(
                title: "History",
                icon: "clock.arrow.circlepath",
                color: .blue,
                action: onHistory
            ),
            QuickAction(
                title: "Settings",
                icon: "gear",
                color: .gray,
                action: onSettings
            )
        ]
        
        return QuickActionButtons(actions: actions, layout: .horizontal)
    }
    
    /// Active run control actions
    static func activeRunActions(
        onNextStop: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onEndRun: @escaping () -> Void,
        canPause: Bool = true,
        canEnd: Bool = true
    ) -> QuickActionButtons {
        let actions = [
            QuickAction(
                title: "Next Stop",
                icon: "arrow.right.circle.fill",
                color: .blue,
                hapticStyle: .medium, // Medium haptic for progression actions
                action: onNextStop
            ),
            QuickAction(
                title: "Pause",
                icon: "pause.circle.fill",
                color: .orange,
                isEnabled: canPause,
                hapticStyle: .light, // Light haptic for pause actions
                action: onPause
            ),
            QuickAction(
                title: "End Run",
                icon: "stop.circle.fill",
                color: .red,
                isEnabled: canEnd,
                hapticStyle: .heavy, // Heavy haptic for destructive actions (end run)
                action: onEndRun
            )
        ]
        
        return QuickActionButtons(actions: actions, layout: .horizontal)
    }
    
    /// Run management actions
    static func runManagementActions(
        onEdit: @escaping () -> Void,
        onDuplicate: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        canEdit: Bool = true,
        canDelete: Bool = true
    ) -> QuickActionButtons {
        let actions = [
            QuickAction(
                title: "Edit",
                icon: "pencil.circle.fill",
                color: .blue,
                isEnabled: canEdit,
                hapticStyle: .light, // Light haptic for navigation actions
                action: onEdit
            ),
            QuickAction(
                title: "Duplicate",
                icon: "doc.on.doc.fill",
                color: .green,
                hapticStyle: .light, // Light haptic for navigation actions
                action: onDuplicate
            ),
            QuickAction(
                title: "Delete",
                icon: "trash.circle.fill",
                color: .red,
                isEnabled: canDelete,
                hapticStyle: .heavy, // Heavy haptic for destructive actions
                action: onDelete
            )
        ]
        
        return QuickActionButtons(actions: actions, layout: .horizontal)
    }
}

// MARK: - Preview

#Preview("Quick Action Buttons") {
    ScrollView {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Horizontal layout
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Horizontal Layout")
                    .headlineSmall()
                
                QuickActionButtons.schoolRunActions(
                    onNewRun: { print("New Run") },
                    onHistory: { print("History") },
                    onSettings: { print("Settings") }
                )
            }
            
            Divider()
            
            // Vertical layout
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Vertical Layout")
                    .headlineSmall()
                
                QuickActionButtons.runManagementActions(
                    onEdit: { print("Edit") },
                    onDuplicate: { print("Duplicate") },
                    onDelete: { print("Delete") }
                )
                .environment(\.layoutDirection, .leftToRight)
            }
            
            Divider()
            
            // Grid layout
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Grid Layout (2 Columns)")
                    .headlineSmall()
                
                let gridActions = [
                    QuickActionButtons.QuickAction(title: "Start", icon: "play.fill", color: .green) { print("Start") },
                    QuickActionButtons.QuickAction(title: "Edit", icon: "pencil", color: .blue) { print("Edit") },
                    QuickActionButtons.QuickAction(title: "Share", icon: "square.and.arrow.up", color: .purple) { print("Share") },
                    QuickActionButtons.QuickAction(title: "Delete", icon: "trash", color: .red) { print("Delete") }
                ]
                
                QuickActionButtons(actions: gridActions, layout: .grid(columns: 2))
            }
            
            Divider()
            
            // Active run actions
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Active Run Actions")
                    .headlineSmall()
                
                QuickActionButtons.activeRunActions(
                    onNextStop: { print("Next Stop") },
                    onPause: { print("Pause") },
                    onEndRun: { print("End Run") }
                )
            }
            
            Divider()
            
            // Different button styles
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Button Styles")
                    .headlineSmall()
                
                let sampleAction = QuickActionButtons.QuickAction(
                    title: "Sample Action",
                    icon: "star.fill",
                    color: .yellow
                ) { print("Sample") }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Different button styles would be shown here")
                        .captionMedium()
                        .foregroundColor(.secondary)
                }
            }
        }
        .screenPadding()
    }
}