import SwiftUI

struct HouseholdLocationPickerField: View {
    let title: String
    let placeholder: String
    @Binding var selectedLocationId: UUID?
    var preferredTypes: [HouseholdLocationType] = HouseholdLocationType.allCases
    var onAddLocation: (() -> Void)?

    @EnvironmentObject private var backendHouseholdLocationsContext: BackendHouseholdLocationsContext

    private var eligibleLocations: [BackendHouseholdLocation] {
        backendHouseholdLocationsContext.locations
            .filter { preferredTypes.contains($0.locationType) }
            .filter { $0.readiness == .complete }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Picker(placeholder, selection: $selectedLocationId) {
                Text(placeholder).tag(nil as UUID?)
                ForEach(eligibleLocations) { location in
                    Text(location.displayName).tag(Optional(location.id))
                }
            }
            .pickerStyle(.menu)

            if let selectedLocationId,
               let location = backendHouseholdLocationsContext.location(id: selectedLocationId) {
                Text(location.formattedAddress)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if eligibleLocations.isEmpty {
                Text("No saved locations with valid coordinates yet.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
            }

            if let onAddLocation {
                Button("Add location", action: onAddLocation)
                    .font(.system(size: 13, weight: .semibold))
            }
        }
    }
}
