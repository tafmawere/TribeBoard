import SwiftUI

/// Form-based component for editing stop details with all input fields
struct StopConfigurationRow: View {
    @Binding var stop: RunStop
    let children: [ChildProfile]
    let stopNumber: Int
    let onDelete: () -> Void
    
    @State private var showingChildPicker = false
    @State private var selectedChildId: UUID?
    @State private var showingDeleteAlert = false
    
    // Accessibility environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Header with stop number and delete button
            HStack {
                Text("Stop \(stopNumber)")
                    .titleSmall()
                    .foregroundColor(.primary)
                    .dynamicTypeSupport(minSize: 14, maxSize: 24)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(colorSchemeContrast == .increased ? .red : .red)
                        .font(.callout)
                }
                .buttonStyle(IconButtonStyle(size: 32, backgroundColor: Color.red.opacity(0.1)))
                .accessibilityLabel("Delete stop \(stopNumber)")
                .accessibilityHint("Removes this stop from the run")
                .accessibilityIdentifier("DeleteStopButton_\(stopNumber)")
            }
            
            // Stop type and name section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Location")
                    .labelMedium()
                    .foregroundColor(.secondary)
                    .dynamicTypeSupport(minSize: 12, maxSize: 20)
                    .accessibilityAddTraits(.isHeader)
                
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Map thumbnail
                    MapPlaceholderThumbnail(for: stop.type)
                        .accessibilityHidden(true)
                    
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        // Stop type picker
                        Menu {
                            ForEach(RunStop.StopType.allCases, id: \.self) { type in
                                Button(action: {
                                    stop.type = type
                                    if type != .custom {
                                        stop.name = type.rawValue
                                    }
                                }) {
                                    HStack {
                                        Text(type.icon)
                                        Text(type.rawValue)
                                    }
                                }
                                .accessibilityLabel("Select \(type.rawValue) as stop type")
                            }
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Text(stop.type.icon)
                                    .font(.title3)
                                    .accessibilityHidden(true)
                                Text(stop.type.rawValue)
                                    .bodyMedium()
                                    .dynamicTypeSupport(minSize: 12, maxSize: 22)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                                    .fill(Color(.systemGray6))
                            )
                        }
                        .accessibilityLabel("Stop type: \(stop.type.rawValue)")
                        .accessibilityHint("Tap to change the type of location for this stop")
                        .accessibilityIdentifier("StopTypePicker_\(stopNumber)")
                        
                        // Custom name field (only for custom type)
                        if stop.type == .custom {
                            TextField("Enter location name", text: $stop.name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .accessibilityLabel("Custom location name")
                                .accessibilityHint("Enter the name for this custom location")
                                .accessibilityIdentifier("CustomLocationField_\(stopNumber)")
                        }
                    }
                }
            }
            
            // Child assignment section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Assign Child")
                    .labelMedium()
                    .foregroundColor(.secondary)
                    .dynamicTypeSupport(minSize: 12, maxSize: 20)
                    .accessibilityAddTraits(.isHeader)
                
                Button(action: { showingChildPicker = true }) {
                    HStack {
                        if let assignedChild = stop.assignedChild {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(colorSchemeContrast == .increased ? .blue : .brandPrimary)
                                .accessibilityHidden(true)
                            Text(assignedChild.displayName)
                                .bodyMedium()
                                .foregroundColor(.primary)
                                .dynamicTypeSupport(minSize: 12, maxSize: 22)
                        } else {
                            Image(systemName: "person.circle")
                                .foregroundColor(.secondary)
                                .accessibilityHidden(true)
                            Text("Select child")
                                .bodyMedium()
                                .foregroundColor(.secondary)
                                .dynamicTypeSupport(minSize: 12, maxSize: 22)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                            .fill(Color(.systemGray6))
                    )
                }
                .accessibilityLabel(childAssignmentLabel)
                .accessibilityHint("Tap to select which child this stop is for")
                .accessibilityIdentifier("ChildAssignmentButton_\(stopNumber)")
                .sheet(isPresented: $showingChildPicker) {
                    ChildSelectionSheet(
                        children: children,
                        selectedChildId: $selectedChildId,
                        onSelection: { childId in
                            if let childId = childId {
                                stop.assignedChild = children.first { $0.id == childId }
                            } else {
                                stop.assignedChild = nil
                            }
                            showingChildPicker = false
                        }
                    )
                }
            }
            
            // Task and duration section
            HStack(spacing: DesignSystem.Spacing.md) {
                // Task input
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Task")
                        .labelMedium()
                        .foregroundColor(.secondary)
                        .dynamicTypeSupport(minSize: 12, maxSize: 20)
                        .accessibilityAddTraits(.isHeader)
                    
                    TextField("e.g., Pick up backpack", text: $stop.task)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .accessibilityLabel("Task for stop \(stopNumber)")
                        .accessibilityHint("Enter what needs to be done at this stop")
                        .accessibilityIdentifier("TaskField_\(stopNumber)")
                }
                
                // Duration input
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Duration")
                        .labelMedium()
                        .foregroundColor(.secondary)
                        .dynamicTypeSupport(minSize: 12, maxSize: 20)
                        .accessibilityAddTraits(.isHeader)
                    
                    HStack {
                        TextField("5", value: $stop.estimatedMinutes, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .accessibilityLabel("Duration in minutes for stop \(stopNumber)")
                            .accessibilityHint("Enter how many minutes this stop will take")
                            .accessibilityIdentifier("DurationField_\(stopNumber)")
                        
                        Text("min")
                            .bodyMedium()
                            .foregroundColor(.secondary)
                            .dynamicTypeSupport(minSize: 10, maxSize: 18)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Stop \(stopNumber) configuration")
        .accessibilityHint("Configure location, child assignment, task, and duration for this stop")
        .accessibilityIdentifier("StopConfigurationRow_\(stopNumber)")
        .onAppear {
            selectedChildId = stop.assignedChild?.id
        }
        .alert("Delete Stop", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Stop", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete Stop \(stopNumber): \(stop.name)?\n\nThis action cannot be undone.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var childAssignmentLabel: String {
        if let assignedChild = stop.assignedChild {
            return "Assigned to \(assignedChild.displayName)"
        } else {
            return "No child assigned"
        }
    }
}

// MARK: - Child Selection Sheet

private struct ChildSelectionSheet: View {
    let children: [ChildProfile]
    @Binding var selectedChildId: UUID?
    let onSelection: (UUID?) -> Void
    
    var body: some View {
        NavigationView {
            List {
                // None option
                Button(action: { onSelection(nil) }) {
                    HStack {
                        Image(systemName: "person.slash")
                            .foregroundColor(.secondary)
                        Text("No child assigned")
                            .bodyMedium()
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if selectedChildId == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.brandPrimary)
                        }
                    }
                }
                
                // Children options
                ForEach(children) { child in
                    Button(action: { onSelection(child.id) }) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.brandPrimary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(child.name)
                                    .bodyMedium()
                                    .foregroundColor(.primary)
                                Text("Age \(child.age) • \(child.ageGroup)")
                                    .captionMedium()
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedChildId == child.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.brandPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Child")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    onSelection(selectedChildId)
                }
            )
        }
    }
}

// MARK: - Preview

#Preview("Stop Configuration - Various Types") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        // Home stop
        StopConfigurationRow(
            stop: .constant(RunStop(
                name: "Home",
                type: .home,
                task: "Get ready to go",
                estimatedMinutes: 5
            )),
            children: SchoolRunPreviewProvider.sampleChildren,
            stopNumber: 1,
            onDelete: {}
        )
        
        // School stop with child
        StopConfigurationRow(
            stop: .constant(RunStop(
                name: "School",
                type: .school,
                assignedChild: SchoolRunPreviewProvider.sampleChildren[0],
                task: "Pick up Emma from classroom 3B",
                estimatedMinutes: 10
            )),
            children: SchoolRunPreviewProvider.sampleChildren,
            stopNumber: 2,
            onDelete: {}
        )
        
        // Custom stop
        StopConfigurationRow(
            stop: .constant(RunStop(
                name: "Grocery Store",
                type: .custom,
                task: "Quick grocery run",
                estimatedMinutes: 15
            )),
            children: SchoolRunPreviewProvider.sampleChildren,
            stopNumber: 3,
            onDelete: {}
        )
        
        // Empty stop
        StopConfigurationRow(
            stop: .constant(RunStop(
                name: "",
                type: .home,
                task: "",
                estimatedMinutes: 5
            )),
            children: SchoolRunPreviewProvider.sampleChildren,
            stopNumber: 4,
            onDelete: {}
        )
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Stop Configuration - Dark Mode") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        StopConfigurationRow(
            stop: .constant(SchoolRunPreviewProvider.sampleStops[1]),
            children: SchoolRunPreviewProvider.sampleChildren,
            stopNumber: 1,
            onDelete: {}
        )
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("Stop Configuration - Large Text") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        StopConfigurationRow(
            stop: .constant(RunStop(
                name: "Riverside Elementary School",
                type: .school,
                assignedChild: ChildProfile(name: "Emma-Louise", avatar: "person.circle.fill", age: 8),
                task: "Pick up Emma-Louise from her classroom and collect her art project from the teacher",
                estimatedMinutes: 15
            )),
            children: SchoolRunPreviewProvider.sampleChildren,
            stopNumber: 1,
            onDelete: {}
        )
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .environment(\.dynamicTypeSize, .accessibility1)
}

#Preview("Stop Configuration - High Contrast") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        StopConfigurationRow(
            stop: .constant(SchoolRunPreviewProvider.sampleStops[1]),
            children: SchoolRunPreviewProvider.sampleChildren,
            stopNumber: 1,
            onDelete: {}
        )
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))

}

#Preview("Stop Configuration - Interactive") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        StopConfigurationRow(
            stop: .constant(SchoolRunPreviewProvider.sampleStops[1]),
            children: SchoolRunPreviewProvider.sampleChildren,
            stopNumber: 1,
            onDelete: {}
        )
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .previewDisplayName("Interactive Configuration")
}