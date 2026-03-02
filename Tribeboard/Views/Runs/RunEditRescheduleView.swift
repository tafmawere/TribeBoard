import SwiftUI

struct RunEditRescheduleView: View {
    @Environment(\.dismiss) private var dismiss

    let run: RunDetailsData.UIRun
    let onSave: (RunDetailsData.UIRun) -> Void

    @State private var title: String
    @State private var date: Date
    @State private var driverName: String
    @State private var selectedPassengers: Set<String>
    @State private var stops: [RunDetailsData.UIStop]

    private let drivers = ["Rue", "Tafadzwa"]
    private let passengersPool = ["TJ", "Tawana", "Rue"]

    init(run: RunDetailsData.UIRun, onSave: @escaping (RunDetailsData.UIRun) -> Void) {
        self.run = run
        self.onSave = onSave
        _title = State(initialValue: run.title)
        _date = State(initialValue: run.scheduledTime)
        _driverName = State(initialValue: run.driverName)
        _selectedPassengers = State(initialValue: Set(run.passengerNames))
        _stops = State(initialValue: run.stops)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                warningBanner
                basicInfoCard
                participantsCard
                stopsCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
        .background(RunStitchTheme.background.ignoresSafeArea())
        .navigationTitle("Edit Run")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
    }

    private var warningBanner: some View {
        StitchCard {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(RunStitchTheme.warning)
                Text("Changes will notify all members")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RunStitchTheme.textPrimary)
                Spacer()
            }
        }
    }

    private var basicInfoCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Basic Info")
                labeledField("Title", text: $title)
                DatePicker("Date & Time", selection: $date)
                    .datePickerStyle(.compact)
                    .tint(RunStitchTheme.indigo)
            }
        }
    }

    private var participantsCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Participants")
                Picker("Driver", selection: $driverName) {
                    ForEach(drivers, id: \.self) { driver in
                        Text(driver).tag(driver)
                    }
                }
                .pickerStyle(.menu)

                Text("Passengers")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RunStitchTheme.textSecondary)
                HStack {
                    ForEach(passengersPool, id: \.self) { passenger in
                        RoleChip(
                            text: passenger,
                            color: selectedPassengers.contains(passenger) ? RunStitchTheme.indigo : RunStitchTheme.textSecondary
                        )
                        .onTapGesture {
                            if selectedPassengers.contains(passenger) {
                                selectedPassengers.remove(passenger)
                            } else {
                                selectedPassengers.insert(passenger)
                            }
                        }
                    }
                }
            }
        }
    }

    private var stopsCard: some View {
        StitchCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionTitle(title: "Stops")
                    Spacer()
                    Button("Add stop") {
                        stops.append(.init(type: "Dropoff", label: "", address: "", timeEstimate: "--"))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RunStitchTheme.indigo)
                }

                ForEach(stops.indices, id: \.self) { idx in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            RoleChip(
                                text: stops[idx].type,
                                color: stops[idx].type == "Pickup" ? RunStitchTheme.indigo : RunStitchTheme.success
                            )
                            Spacer()
                            Button {
                                stops.remove(at: idx)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(RunStitchTheme.danger)
                            }
                        }

                        Picker("Type", selection: $stops[idx].type) {
                            Text("Pickup").tag("Pickup")
                            Text("Dropoff").tag("Dropoff")
                        }
                        .pickerStyle(.segmented)

                        labeledField("Label", text: $stops[idx].label)
                        labeledField("Address", text: $stops[idx].address)
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            PrimaryButton(title: "Save Changes") {
                var updated = run
                updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.scheduledTime = date
                updated.driverName = driverName
                updated.passengerNames = selectedPassengers.sorted()
                updated.stops = stops
                onSave(updated)
                dismiss()
            }
            .opacity(canSave ? 1 : 0.55)
            .disabled(!canSave)

            SecondaryButton(title: "Discard") {
                dismiss()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !stops.isEmpty &&
        !stops.contains(where: { $0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RunStitchTheme.textSecondary)
            TextField(title, text: text)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

#Preview {
    NavigationStack {
        RunEditRescheduleView(run: RunDetailsData.scheduledRun) { _ in }
    }
}
