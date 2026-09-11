import SwiftUI

struct DriverPickerView: View {
    let runId: UUID
    var runHouseholdId: UUID?
    var onAddDriver: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var householdContext: ActiveHouseholdContext
    @EnvironmentObject private var backendDriversContext: BackendDriversContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var authSession: AuthSessionContext

    @State private var isAssigning = false

    private var activeHouseholdId: UUID {
        householdContext.householdId
    }

    var body: some View {
        VStack(spacing: 0) {
            if backendDriversContext.drivers.isEmpty {
                emptyState
            } else {
                driverList
            }
        }
        .background(UIRunDesignSystem.background.ignoresSafeArea())
        .navigationTitle("Assign Driver")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .task {
            await refreshCandidates()
        }
        .alert(
            "Driver Assignment",
            isPresented: Binding(
                get: { backendDriversContext.lastError != nil },
                set: { isPresented in
                    if !isPresented {
                        backendDriversContext.lastError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                backendDriversContext.lastError = nil
            }
        } message: {
            Text(backendDriversContext.lastError ?? BackendDriversContext.loadFailedUserMessage)
        }
    }

    private var driverList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(backendDriversContext.drivers) { driver in
                    Button {
                        Task { await assign(driver) }
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(driver.displayName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(UIRunDesignSystem.textPrimary)
                                Text(driver.role.capitalized)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(UIRunDesignSystem.textSecondary)
                            }
                            Spacer()
                            if backendDriversContext.assignedDriverId(forRunId: runId) == driver.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(UIRunDesignSystem.primary)
                            } else if isAssigning {
                                ProgressView()
                                    .scaleEffect(0.85)
                            }
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isAssigning)
                }
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 12)

            UICard {
                VStack(spacing: 14) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(UIRunDesignSystem.primary)

                    Text("No drivers yet")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(UIRunDesignSystem.textPrimary)

                    Text("Add an adult or enable driving permissions before assigning this run.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(UIRunDesignSystem.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 16)

            VStack(spacing: 10) {
                Button {
                    dismiss()
                    if let onAddDriver {
                        onAddDriver()
                    } else {
                        NotificationCenter.default.post(name: .tribeboardOpenFamilyForDriverSetup, object: nil)
                    }
                } label: {
                    Text("Add driver")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(UIRunDesignSystem.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button("Cancel") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UIRunDesignSystem.textSecondary)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    private func refreshCandidates() async {
        await backendHouseholdPeopleContext.refreshPeople(householdId: activeHouseholdId)
        if let peopleError = backendHouseholdPeopleContext.lastError, !peopleError.isEmpty {
            backendDriversContext.reportLoadFailure(
                error: peopleError,
                attemptedSource: "household_people"
            )
            return
        }

        await backendDriversContext.refreshDrivers(
            householdId: activeHouseholdId,
            memberships: backendHouseholdContext.activeHouseholdMembers,
            profilesByUserId: backendHouseholdContext.activeHouseholdProfilesByUserId,
            householdPeople: backendHouseholdPeopleContext.people,
            childIds: Set(backendChildrenContext.children.map(\.id)),
            currentUserId: authSession.currentUserId.flatMap(UUID.init(uuidString:))
        )
    }

    private func assign(_ driver: BackendDriver) async {
        guard !isAssigning else { return }
        isAssigning = true
        defer { isAssigning = false }
        let assigned = await backendDriversContext.assignDriver(
            runId: runId,
            driverId: driver.id,
            driverName: driver.displayName,
            runHouseholdId: runHouseholdId,
            activeHouseholdId: activeHouseholdId
        )
        if assigned {
            dismiss()
        }
    }
}

#Preview {
    let householdContext = ActiveHouseholdContext()
    NavigationStack {
        DriverPickerView(runId: UUID())
            .environmentObject(householdContext)
            .environmentObject(BackendDriversContext(backendRunsContext: BackendRunsContext()))
            .environmentObject(BackendHouseholdContext(
                localHouseholdContext: householdContext,
                localHouseholdDataSource: HouseholdDataSource(
                    repository: LocalHouseholdRepository(),
                    activeContext: householdContext
                )
            ))
            .environmentObject(BackendHouseholdPeopleContext(activeHouseholdStore: ActiveHouseholdStore()))
            .environmentObject(BackendChildrenContext(
                householdContext: BackendHouseholdContext(
                    localHouseholdContext: householdContext,
                    localHouseholdDataSource: HouseholdDataSource(
                        repository: LocalHouseholdRepository(),
                        activeContext: householdContext
                    )
                ),
                store: TribeStore()
            ))
            .environmentObject(AuthSessionContext())
    }
}
