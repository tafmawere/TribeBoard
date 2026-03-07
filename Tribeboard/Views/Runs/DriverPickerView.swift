import SwiftUI

struct DriverPickerView: View {
    let runId: UUID
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var driverDataSource: DriverDataSource
    @EnvironmentObject private var runDataSource: RunDataSource

    var body: some View {
        List {
            if driverDataSource.drivers.isEmpty {
                Text("No active drivers available.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(driverDataSource.drivers) { driver in
                    Button {
                        Task {
                            await runDataSource.assignDriver(runId: runId, driverId: driver.id)
                            if runDataSource.lastError == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Text(driver.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            if let run = runDataSource.runs.first(where: { $0.id == runId }),
                               run.assignedDriverId == driver.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.indigo)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Assign Driver")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await driverDataSource.bootstrapIfNeeded()
        }
    }
}

#Preview {
    NavigationStack {
        DriverPickerView(runId: UUID())
            .environmentObject(RunDataSource())
            .environmentObject(DriverDataSource())
    }
}
