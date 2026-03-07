import SwiftUI

struct HouseholdSwitcherView: View {
    @EnvironmentObject private var householdDataSource: HouseholdDataSource
    @EnvironmentObject private var activeHouseholdContext: ActiveHouseholdContext

    @State private var isPresentingCreateSheet = false
    @State private var newHouseholdName = ""

    var body: some View {
        List {
            Section {
                ForEach(householdDataSource.households) { household in
                    Button {
                        Task { await householdDataSource.switchHousehold(id: household.id) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(household.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                if household.id == activeHouseholdContext.householdId {
                                    Text("Active")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if household.id == activeHouseholdContext.householdId {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("All runs, schedules and drivers belong to a household.")
            }
        }
        .navigationTitle("Households")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newHouseholdName = ""
                    isPresentingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await householdDataSource.refresh()
        }
        .sheet(isPresented: $isPresentingCreateSheet) {
            NavigationStack {
                Form {
                    Section("New Household") {
                        TextField("Household name", text: $newHouseholdName)
                            .textInputAutocapitalization(.words)
                    }
                }
                .navigationTitle("Create Household")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresentingCreateSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            Task {
                                await householdDataSource.createHousehold(name: newHouseholdName)
                                if householdDataSource.lastError == nil {
                                    isPresentingCreateSheet = false
                                }
                            }
                        }
                        .disabled(newHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .alert("Household Error", isPresented: Binding(
            get: { householdDataSource.lastError != nil },
            set: { newValue in
                if !newValue { householdDataSource.lastError = nil }
            }
        )) {
            Button("OK", role: .cancel) {
                householdDataSource.lastError = nil
            }
        } message: {
            Text(householdDataSource.lastError ?? "Unknown error")
        }
    }
}
