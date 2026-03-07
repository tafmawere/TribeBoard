import SwiftUI

struct DriverModeSelectorView: View {
    @EnvironmentObject private var driverDataSource: DriverDataSource

    var body: some View {
        List {
            if driverDataSource.drivers.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No active drivers available",
                        systemImage: "person.2.slash",
                        description: Text("Activate or create drivers to enter Driver Mode.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                }
            } else {
                Section("Active Drivers") {
                    ForEach(driverDataSource.drivers) { driver in
                        NavigationLink {
                            DriverModeView(driverId: driver.id)
                        } label: {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.indigo.opacity(0.14))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Text(driverInitials(driver.name))
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.indigo)
                                    }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(driver.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text("Open Driver Mode")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(minHeight: 44)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Driver Mode")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await driverDataSource.bootstrapIfNeeded()
        }
        .refreshable {
            await driverDataSource.refresh()
        }
    }

    private func driverInitials(_ name: String) -> String {
        let parts = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        let initials = String(parts)
        return initials.isEmpty ? "DR" : initials.uppercased()
    }
}

#Preview {
    NavigationStack {
        DriverModeSelectorView()
            .environmentObject(DriverDataSource())
    }
}
