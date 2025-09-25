import SwiftUI

/// Form-based interface for creating new school runs with multiple stops and child assignments
struct ScheduleNewRunView: View {
    
    // MARK: - Environment
    
    @SafeEnvironmentObject(fallback: { AppState.createFallback() }) private var appState: AppState
    
    // MARK: - State Management
    
    @StateObject private var runManager = ScheduledSchoolRunManager()
    
    // MARK: - Form State
    
    @State private var runName = ""
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var stops: [RunStop] = []
    
    // MARK: - UI State
    
    @State private var showingValidationErrors = false
    @State private var validationErrors: [ValidationError] = []
    @State private var isSaving = false
    
    // MARK: - Data
    
    private let availableChildren = MockSchoolRunDataProvider.children
    
    var body: some View {
        Form {
                // MARK: - Run Details Section
                
                Section("Run Details") {
                    // Run name input
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        TextField("Enter run name", text: $runName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(DesignSystem.Typography.bodyMedium)
                        
                        if let nameError = validationErrors.first(where: { 
                            if case .emptyRunName = $0 { return true }
                            return false
                        }) {
                            Text(nameError.errorDescription ?? "")
                                .font(DesignSystem.Typography.captionMedium)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Date selection
                    DatePicker(
                        "Day",
                        selection: $selectedDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .font(DesignSystem.Typography.bodyMedium)
                    
                    // Time selection
                    DatePicker(
                        "Time",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                    .font(DesignSystem.Typography.bodyMedium)
                }
                
                // MARK: - Stops Section
                
                Section {
                    // Stops list
                    ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                        StopConfigurationRow(
                            stop: $stops[index],
                            children: availableChildren,
                            stopNumber: index + 1,
                            onDelete: {
                                deleteStop(at: index)
                            }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                    
                    // Add stop button
                    Button(action: addNewStop) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.brandPrimary)
                                .font(.title2)
                            
                            Text("Add Stop")
                                .font(DesignSystem.Typography.buttonMedium)
                                .foregroundColor(.brandPrimary)
                            
                            Spacer()
                        }
                        .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                    .listRowBackground(Color.clear)
                    
                    if let stopsError = validationErrors.first(where: { 
                        if case .noStops = $0 { return true }
                        return false
                    }) {
                        Text(stopsError.errorDescription ?? "")
                            .font(DesignSystem.Typography.captionMedium)
                            .foregroundColor(.red)
                            .listRowBackground(Color.clear)
                    }
                    
                } header: {
                    Text("Stops")
                } footer: {
                    if !stops.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Total estimated duration: \(formattedTotalDuration)")
                                .font(DesignSystem.Typography.captionMedium)
                                .foregroundColor(.secondary)
                            
                            Text("Participating children: \(participatingChildrenText)")
                                .font(DesignSystem.Typography.captionMedium)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // MARK: - Validation Errors Section
                
                if !validationErrors.isEmpty {
                    Section {
                        ValidationErrorView(errors: validationErrors)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
                
                // MARK: - Save Section
                
                Section {
                    Button(action: saveRun) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                            }
                            
                            Text(isSaving ? "Saving..." : "Save Run")
                                .font(DesignSystem.Typography.buttonLarge)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: DesignSystem.Layout.buttonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                                .fill(LinearGradient.brandGradient)
                        )
                    }
                    .disabled(isSaving)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Schedule New Run")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    TribeBoardLogo(size: .small, showBackground: false)
                        .accessibilityHidden(true)
                }
            }
            .alert("Please Fix These Issues", isPresented: $showingValidationErrors) {
                Button("OK") { }
            } message: {
                Text(validationErrors.compactMap(\.errorDescription).joined(separator: "\n"))
            }
            .onAppear {
                // Initialize with one empty stop
                if stops.isEmpty {
                    addNewStop()
                }
            }
        .withToast()
    }
    
    // MARK: - Computed Properties
    
    /// Formatted total duration for all stops
    private var formattedTotalDuration: String {
        let totalMinutes = stops.reduce(0) { $0 + $1.estimatedMinutes }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Text representation of participating children
    private var participatingChildrenText: String {
        let children = stops.compactMap(\.assignedChild)
        let uniqueChildren = Array(Set(children))
        
        if uniqueChildren.isEmpty {
            return "None assigned"
        } else if uniqueChildren.count == 1 {
            return uniqueChildren[0].name
        } else if uniqueChildren.count == 2 {
            return "\(uniqueChildren[0].name) and \(uniqueChildren[1].name)"
        } else {
            return "\(uniqueChildren[0].name) and \(uniqueChildren.count - 1) others"
        }
    }
    
    // MARK: - Actions
    
    /// Adds a new empty stop to the stops array
    private func addNewStop() {
        let newStop = MockSchoolRunDataProvider.createEmptyStop()
        stops.append(newStop)
    }
    
    /// Deletes a stop at the specified index
    private func deleteStop(at index: Int) {
        guard index < stops.count else { return }
        stops.remove(at: index)
    }
    
    /// Validates the form using the RunValidation utility
    private func validateForm() -> [ValidationError] {
        return RunValidation.validateFormData(name: runName, stops: stops)
    }
    
    /// Saves the run after validation
    private func saveRun() {
        // Validate form
        let errors = validateForm()
        validationErrors = errors
        
        if !errors.isEmpty {
            showingValidationErrors = true
            ToastManager.shared.error("Please fix the errors above")
            return
        }
        
        // Start saving
        isSaving = true
        
        // Create the run
        let newRun = ScheduledSchoolRun(
            name: runName.trimmingCharacters(in: .whitespacesAndNewlines),
            scheduledDate: selectedDate,
            scheduledTime: selectedTime,
            stops: stops
        )
        
        // Simulate save delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Save the run
            runManager.createRun(newRun)
            
            // Show success toast
            ToastManager.shared.success("Run saved successfully!")
            
            // Reset saving state
            isSaving = false
            
            // Navigate back after a short delay to show the toast
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                appState.navigationPath.removeLast()
            }
        }
    }
}

// MARK: - Preview

#Preview("Schedule New Run - Empty Form") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            ScheduleNewRunView()
        }
    }
}

#Preview("Schedule New Run - Partial Form") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            ScheduleNewRunView()
                .onAppear {
                    // This would simulate a partially filled form
                }
        }
    }
}

#Preview("Schedule New Run - Complete Form") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            ScheduleNewRunView()
                .onAppear {
                    // This would simulate a completed form
                }
        }
    }
}

#Preview("Schedule New Run - Dark Mode") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            ScheduleNewRunView()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Schedule New Run - Large Text") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            ScheduleNewRunView()
        }
    }
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Schedule New Run - High Contrast") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            ScheduleNewRunView()
        }
    }

}

#Preview("Schedule New Run - Validation Errors") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            ScheduleNewRunView()
                .onAppear {
                    // This would simulate validation errors
                }
        }
    }
}

#Preview("Schedule New Run - Interactive") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            ScheduleNewRunView()
        }
    }
    .previewDisplayName("Interactive Form")
}