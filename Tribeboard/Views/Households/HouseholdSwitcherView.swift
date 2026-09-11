import SwiftUI

struct HouseholdSwitcherView: View {
    @EnvironmentObject private var householdDataSource: HouseholdDataSource
    @EnvironmentObject private var activeHouseholdStore: ActiveHouseholdStore
    @EnvironmentObject private var activeHouseholdContext: ActiveHouseholdContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext

    @State private var isPresentingCreateSheet = false
    @State private var isPresentingJoinSheet = false
    @State private var newHouseholdName = ""
    @State private var inviteCode = ""
    
    private var showErrorAlert: Binding<Bool> {
        Binding(
            get: {
                resolvedHouseholdAlertMessage != nil
            },
            set: { newValue in
                if !newValue {
                    householdDataSource.lastError = nil
                    backendHouseholdContext.householdAlertError = nil
                    backendHouseholdContext.lastError = nil
                }
            }
        )
    }

    private var resolvedHouseholdAlertMessage: String? {
        if let alertError = backendHouseholdContext.householdAlertError,
           !isCancellationMessage(alertError) {
            return alertError
        }
        if let dataSourceError = householdDataSource.lastError,
           !isCancellationMessage(dataSourceError) {
            return dataSourceError
        }
        return nil
    }

    var body: some View {
        List {
            backendHouseholdsSection
            localHouseholdsSection
        }
        .navigationTitle("Households")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Join") {
                    inviteCode = ""
                    isPresentingJoinSheet = true
                }
            }
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
            await backendHouseholdContext.refresh()
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
                                await backendHouseholdContext.createHousehold(name: newHouseholdName)
                                if backendHouseholdContext.householdAlertError == nil {
                                    isPresentingCreateSheet = false
                                }
                            }
                        }
                        .disabled(newHouseholdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingJoinSheet) {
            NavigationStack {
                Form {
                    Section("Family Code") {
                        TextField("Enter family code (H-XXXXXXXX)", text: $inviteCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                }
                .navigationTitle("Join Household")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresentingJoinSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Join") {
                            Task {
                                await backendHouseholdContext.joinHousehold(inviteCode: inviteCode)
                                if backendHouseholdContext.householdAlertError == nil {
                                    isPresentingJoinSheet = false
                                }
                            }
                        }
                        .disabled(inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .alert("Household Error", isPresented: showErrorAlert) {
            Button("OK", role: .cancel) {
                householdDataSource.lastError = nil
                backendHouseholdContext.householdAlertError = nil
                backendHouseholdContext.lastError = nil
            }
        } message: {
            Text(resolvedHouseholdAlertMessage ?? "Something went wrong while updating your household.")
        }
    }

    private var backendHouseholdsSection: some View {
        Section {
            if backendHouseholdContext.isLoading && backendHouseholdContext.households.isEmpty {
                ProgressView("Loading households...")
            } else if backendHouseholdContext.households.isEmpty,
                      let loadError = backendHouseholdContext.lastError,
                      !loadError.isEmpty,
                      !isCancellationMessage(loadError) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loadError)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await backendHouseholdContext.refresh() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .padding(.vertical, 4)
            } else if backendHouseholdContext.households.isEmpty {
                Text("No shared households yet. Create one or join with a family code.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(backendHouseholdContext.households) { household in
                    backendHouseholdRow(household)
                }
            }
        } header: {
            Text("Shared Households (Backend)")
        } footer: {
            Text("Joined households: \(backendHouseholdContext.households.count)")
        }
    }

    private var localHouseholdsSection: some View {
        Section {
            if householdDataSource.households.isEmpty {
                Text("No local household cache yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(householdDataSource.households) { household in
                    localHouseholdRow(household)
                }
            }
        } footer: {
            Text("All runs, schedules and drivers belong to a household.")
        }
    }

    private func backendHouseholdRow(_ household: BackendHousehold) -> some View {
        let isActive = household.id == activeHouseholdStore.activeHouseholdId
        let role = backendHouseholdContext.memberships.first(where: { $0.householdId == household.id })?
            .normalizedAccessRole?.rawValue ?? HouseholdAccessRole.observer.rawValue
        let joinCode = formatHouseholdJoinCode(householdId: household.id)
        let identifier = "\(joinCode) • ID \(shortHouseholdId(household.id))"
        let membersSummary: String? = isActive
            ? "\(backendHouseholdContext.activeHouseholdMembers.count) members • \(backendChildrenContext.children.count) children"
            : nil
        return Button {
            guard !isActive else { return }
            backendHouseholdContext.selectHousehold(household.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(household.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("\(role.capitalized) • \(identifier)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let membersSummary {
                        Text(membersSummary)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isActive)
    }

    private func localHouseholdRow(_ household: Household) -> some View {
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

    private func shortHouseholdId(_ id: UUID) -> String {
        String(id.uuidString.prefix(8))
    }
}
