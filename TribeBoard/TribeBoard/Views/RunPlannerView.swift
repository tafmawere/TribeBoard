import SwiftUI

/// View for planning and creating new school runs with comprehensive form interface
struct RunPlannerView: View {
    @StateObject private var viewModel = RunPlannerViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: FocusedField?
    @State private var showingDiscardAlert = false
    
    // MARK: - Focus Management
    
    enum FocusedField: Hashable {
        case title
        case stopName(UUID)
        case stopNote(UUID)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.lg) {
                        // Header section
                        headerSection
                        
                        // Form sections
                        runDetailsSection
                        stopsSection
                        
                        // Summary section
                        if !viewModel.stops.isEmpty {
                            summarySection
                        }
                        
                        // Save button
                        saveButton
                    }
                    .screenPadding()
                    .padding(.vertical, DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Plan Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Haptic feedback for navigation actions (respects accessibility settings)
                        SchoolRunHapticFeedback.navigationAction()
                        handleCancelAction()
                    }
                    .foregroundColor(.brandPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Stop") {
                        // Haptic feedback for form interaction (respects accessibility settings)
                        SchoolRunHapticFeedback.formInteraction()
                        addNewStop()
                    }
                    .foregroundColor(.brandPrimary)
                    .disabled(viewModel.stops.count >= 10) // Reasonable limit
                }
            }
            .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    // Haptic feedback for destructive actions (respects accessibility settings)
                    SchoolRunHapticFeedback.destructiveAction()
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) { 
                    // Haptic feedback for navigation actions (respects accessibility settings)
                    SchoolRunHapticFeedback.navigationAction()
                }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .overlay {
                if viewModel.isLoading {
                    LoadingStateView(
                        message: "Saving run...",
                        style: .overlay
                    )
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "car.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.brandPrimary)
                .accessibilityHidden(true)
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("Plan Your School Run")
                    .titleLarge()
                    .foregroundColor(.primary)
                    .accessibilityAddTraits([.isHeader])
                .dynamicTypeSupport()
                
                Text("Create a schedule with pickup and drop-off stops")
                    .bodyMedium()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .dynamicTypeSupport()
                    .highContrastSupport(
                        normalColor: .secondary,
                        highContrastColor: .primary
                    )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Plan Your School Run. Create a schedule with pickup and drop-off stops")
    }
    
    // MARK: - Run Details Section
    
    private var runDetailsSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Section header
            HStack {
                Text("Run Details")
                    .titleMedium()
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: DesignSystem.Spacing.md) {
                // Title input
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Run Title")
                        .labelLarge()
                        .foregroundColor(.primary)
                    
                    TextField("e.g., Morning School Run", text: $viewModel.title)
                        .textFieldStyle(CustomTextFieldStyle())
                        .focused($focusedField, equals: .title)
                        .onSubmit {
                            focusedField = nil
                        }
                        .onChange(of: viewModel.title) { _, _ in
                            viewModel.validateTitleRealTime()
                        }
                        .accessibilityLabel("Run title")
                        .accessibilityHint("Enter a descriptive name for this school run")
                        .dynamicTypeSupport()
                        .accessibleTouchTarget()
                        .validationFeedback(viewModel.titleValidationState)
                    
                    // Title validation error
                    if let titleError = viewModel.titleError {
                        InlineErrorView(message: titleError) {
                            viewModel.titleError = nil
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                
                // Date picker
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Run Date")
                        .labelLarge()
                        .foregroundColor(.primary)
                    
                    DatePicker(
                        "Select date",
                        selection: $viewModel.selectedDate,
                        in: Date()...,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.compact)
                    .accessibilityLabel("Run date")
                    .accessibilityHint("Select the date for this school run")
                    
                    // Date validation error
                    if let dateError = viewModel.dateError {
                        InlineErrorView(message: dateError) {
                            viewModel.dateError = nil
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .mediumShadow()
        )
    }
    
    // MARK: - Stops Section
    
    private var stopsSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Section header
            HStack {
                Text("Stops")
                    .titleMedium()
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(viewModel.stops.count)/10")
                    .captionLarge()
                    .foregroundColor(.secondary)
            }
            
            // Stops validation error
            if let stopsError = viewModel.stopsError {
                InlineErrorView(message: stopsError) {
                    viewModel.stopsError = nil
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Validation warnings
            if viewModel.showValidationWarnings && !viewModel.validationWarnings.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    ForEach(viewModel.validationWarnings, id: \.self) { warning in
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.caption)
                            
                            Text(warning)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                        .fill(Color.orange.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // Stops list
            if viewModel.stops.isEmpty {
                emptyStopsView
            } else {
                LazyVStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(Array(viewModel.stops.enumerated()), id: \.element.id) { index, stop in
                        StopConfigurationRow(
                            stop: Binding(
                                get: { viewModel.stops[index] },
                                set: { updatedStop in
                                    viewModel.updateStop(
                                        id: stop.id,
                                        name: updatedStop.name,
                                        time: updatedStop.time,
                                        type: updatedStop.type,
                                        note: updatedStop.note
                                    )
                                }
                            ),
                            children: MockSchoolRunDataProvider.children,
                            stopNumber: index + 1,
                            onDelete: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    viewModel.removeStop(id: stop.id)
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
            }
            
            // Add stop button
            Button(action: {
                // Haptic feedback for form interaction (respects accessibility settings)
                SchoolRunHapticFeedback.formInteraction()
                addNewStop()
            }) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                    
                    Text("Add Stop")
                        .labelLarge()
                }
                .foregroundColor(.brandPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: DesignSystem.Layout.inputHeight)
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .stroke(Color.brandPrimary, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                                .fill(Color.brandPrimary.opacity(0.05))
                        )
                )
            }
            .disabled(viewModel.stops.count >= 10)
            .opacity(viewModel.stops.count >= 10 ? 0.5 : 1.0)
            .accessibilityLabel("Add new stop")
            .accessibilityHint("Adds a new stop to the school run")
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .mediumShadow()
        )
    }
    
    // MARK: - Empty Stops View
    
    private var emptyStopsView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "mappin.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("No Stops Added")
                    .titleSmall()
                    .foregroundColor(.primary)
                
                Text("Add pickup and drop-off locations for your run")
                    .bodySmall()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No stops added. Add pickup and drop-off locations for your run")
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Run Summary")
                    .titleMedium()
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text("Estimated Duration:")
                        .bodyMedium()
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.estimatedDurationText)
                        .bodyMedium()
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.secondary)
                    Text("Total Stops:")
                        .bodyMedium()
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(viewModel.stops.count)")
                        .bodyMedium()
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                if viewModel.hasMixedStopTypes {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.secondary)
                        Text("Stop Types:")
                            .bodyMedium()
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(viewModel.pickupStops.count) pickup, \(viewModel.dropoffStops.count) drop-off")
                            .bodyMedium()
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .mediumShadow()
        )
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // General error message
            if let errorMessage = viewModel.errorMessage {
                InlineErrorView(message: errorMessage) {
                    viewModel.errorMessage = nil
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            Button(action: {
                // Haptic feedback for save action (respects accessibility settings)
                SchoolRunHapticFeedback.saveSuccessful()
                saveRun()
            }) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                    }
                    
                    Text(viewModel.isLoading ? "Saving..." : "Save Run")
                        .labelLarge()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .standardButtonHeight()
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .fill(viewModel.isValid ? Color.brandPrimary : Color.secondary)
                )
            }
            .disabled(!viewModel.isValid || viewModel.isLoading)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isValid)
            .accessibilityLabel("Save school run")
            .accessibilityHint(viewModel.isValid ? "Saves the school run with all configured stops" : "Complete all required fields to enable saving")
        }
    }
    
    // MARK: - Actions
    
    private func addNewStop() {
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.addStop()
        }
        
        // Focus on the new stop's name field
        if let lastStop = viewModel.stops.last {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .stopName(lastStop.id)
            }
        }
    }
    
    private func saveRun() {
        focusedField = nil // Dismiss keyboard
        
        Task {
            if let savedRun = await viewModel.saveRun() {
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }
    
    private func handleCancelAction() {
        if viewModel.hasUnsavedChanges {
            showingDiscardAlert = true
        } else {
            dismiss()
        }
    }
}



// MARK: - Compact Text Field Style

struct CompactTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(DesignSystem.Typography.bodyMedium)
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RunPlannerView()
    }
    .previewEnvironment(.authenticated)
}

#Preview("With Stops") {
    NavigationStack {
        RunPlannerView()
    }
    .previewEnvironment(.authenticated)
    .onAppear {
        // This would be set up in a proper preview environment
    }
}