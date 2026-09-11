import SwiftUI

struct TribeOnboardingRootView: View {
    @EnvironmentObject private var flow: AppFlowState
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendProfileContext: BackendProfileContext
    @StateObject private var coordinator = OnboardingFlowCoordinator()
    @State private var isFinishing = false

    var body: some View {
        NavigationStack {
            Group {
                if coordinator.isBootstrapping {
                    bootstrappingShell
                } else if coordinator.route == .welcome {
                    welcomeShell
                } else {
                    flowShell
                }
            }
            .navigationTitle(coordinator.route == .welcome ? "" : coordinator.route.title)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await coordinator.bootstrap()
            }
            .alert("Onboarding issue", isPresented: Binding(
                get: { coordinator.errorMessage != nil },
                set: { if !$0 { coordinator.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { coordinator.errorMessage = nil }
            } message: {
                Text(coordinator.errorMessage ?? "Unable to continue.")
            }
        }
    }

    private var bootstrappingShell: some View {
        VStack(spacing: 14) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var welcomeShell: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.white)
            .toolbar(.hidden, for: .navigationBar)
    }

    private var flowShell: some View {
        VStack(spacing: 14) {
            OnboardingProgressHeader(
                label: coordinator.progressLabel,
                current: coordinator.progressIndex,
                total: coordinator.progressTotal
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 24)
            }
            if showsFooter {
                footer
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await authSession.signOut() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Dismiss onboarding")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if coordinator.isBootstrapping {
            OnboardingCard {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Checking invitations…")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        } else {
            switch coordinator.route {
            case .welcome:
                OnboardingWelcomeStep(
                    onSelectSetup: { coordinator.selectPath(.setup) },
                    onSelectJoin: { coordinator.selectPath(.join) }
                )
            case .invitedAcceptance:
                OnboardingInvitedAcceptanceStep(
                    invites: coordinator.pendingEmailInvites,
                    selectedInviteId: $coordinator.selectedPendingInviteId,
                    profileDraft: $coordinator.profileDraft,
                    requiresProfileFields: coordinator.requiresInviteProfileCapture,
                    canAccept: coordinator.canAcceptSelectedInvite,
                    isLoading: coordinator.isLoading,
                    onAccept: { acceptInvite() },
                    onDecline: { coordinator.declineInvitesForNow() }
                )
            case .joinCode:
                OnboardingJoinCodeStep(
                    joinCode: $coordinator.joinCode,
                    hasEmailPendingInvite: coordinator.hasEmailPendingInvite
                )
            case .joinProfile:
                OnboardingProfileStep(profile: $coordinator.profileDraft, title: "Your profile")
            case .joinResult:
                OnboardingJoinResultStep(
                    status: coordinator.joinResultStatus,
                    message: coordinator.joinResultMessage,
                    householdName: coordinator.joinResultHouseholdName
                )
            case .setupProfile:
                OnboardingCreateProfileStep(
                    profile: $coordinator.profileDraft,
                    accessToken: authSession.currentAccessToken ?? "",
                    userId: authSession.currentUserId.flatMap(UUID.init(uuidString:))
                )
            case .setupTribe:
                OnboardingCreateFamilyStep(
                    familyName: $coordinator.tribeDraft.tribeName,
                    lastName: coordinator.profileDraft.lastName,
                    firstChildName: coordinator.firstChildDisplayName,
                    userAvatar: coordinator.profileDraft.avatarIdentity
                )
            case .setupHome:
                OnboardingCreateHomeStep(
                    selectedLocation: $coordinator.homeLocation,
                    phase: $coordinator.homeLocationPhase
                )
            case .nextUp:
                OnboardingNextUpStep(
                    familyName: coordinator.tribeDraft.tribeName,
                    onAddChild: { finishAndAddChild() }
                )
            case .setupChildren:
                OnboardingChildrenStep(
                    children: $coordinator.children,
                    onAdd: { coordinator.addChild() },
                    onRemove: { coordinator.removeChild($0) }
                )
            case .childSetupList:
                OnboardingChildSetupListStep(
                    children: coordinator.children,
                    onSelectChild: { coordinator.setActiveChild($0) }
                )
            case .childSchool(let childId):
                if let child = coordinator.children.first(where: { $0.id == childId }) {
                    OnboardingChildSchoolStep(
                        child: child,
                        siblingSchools: coordinator.siblingSchoolOptions(for: childId)
                    ) { updated in
                        coordinator.updateChild(childId) { $0 = updated }
                    }
                }
            case .childRoutine(let childId):
                if let child = coordinator.children.first(where: { $0.id == childId }) {
                    OnboardingChildRoutineStep(child: child) { updated in
                        coordinator.updateChild(childId) { $0 = updated }
                    }
                }
            case .childActivities(let childId):
                if let child = coordinator.children.first(where: { $0.id == childId }) {
                    OnboardingChildActivitiesStep(child: child) { updated in
                        coordinator.updateChild(childId) { $0 = updated }
                    }
                }
            case .supportPeople:
                OnboardingSupportPeopleStep(
                    people: $coordinator.supportPeople,
                    onAddInviteMember: { coordinator.appendInvitedMemberCandidate() },
                    onRemove: { coordinator.removeSupportPerson($0) }
                )
            case .review:
                OnboardingReviewStep(
                    profile: coordinator.profileDraft,
                    tribe: coordinator.tribeDraft,
                    homeLocation: coordinator.homeLocation,
                    children: coordinator.children,
                    supportPeople: coordinator.supportPeople
                )
            case .finishing:
                OnboardingFinishingStep()
            }
        }
    }

    private var showsFooter: Bool {
        !coordinator.isBootstrapping
            && coordinator.route != .welcome
            && coordinator.route != .invitedAcceptance
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if showBackButton {
                Button("Back") {
                    coordinator.goBack()
                }
                .buttonStyle(.bordered)
                .disabled(coordinator.isLoading || coordinator.route == .finishing || isReviewFinishing)
            }
            if shouldShowSkip {
                Button("Skip for now") {
                    advance()
                }
                .buttonStyle(.bordered)
                .disabled(coordinator.isLoading || isReviewFinishing)
            }
            Button {
                advance()
            } label: {
                if isReviewFinishing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Finishing...")
                    }
                } else {
                    Text(primaryButtonTitle)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(coordinator.isLoading || isReviewFinishing || !coordinator.canContinue(route: coordinator.route))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var showBackButton: Bool {
        coordinator.route != .welcome
            && coordinator.route != .invitedAcceptance
            && coordinator.route != .finishing
    }

    private var shouldShowSkip: Bool {
        coordinator.route == .supportPeople
    }

    private var primaryButtonTitle: String {
        switch coordinator.route {
        case .joinProfile where coordinator.hasEmailPendingInvite:
            return "Complete profile and join"
        case .joinResult:
            return "Continue to app"
        case .nextUp:
            return "Go to Home"
        case .review:
            return "Finish setup"
        case .finishing:
            return "Saving..."
        default:
            return "Next"
        }
    }

    private var isReviewFinishing: Bool {
        coordinator.route == .review && isFinishing
    }

    private func acceptInvite() {
        Task {
            await coordinator.acceptSelectedInvite(flow: flow)
            await backendProfileContext.refreshProfile(
                authEmail: authSession.currentUserEmail,
                providerDisplayName: nil
            )
        }
    }

    private func finishAndAddChild() {
        Task {
            await coordinator.finishMinimalSetup(flow: flow, openAddChild: true)
        }
    }

    private func advance() {
        if coordinator.route == .review {
            guard !isFinishing else {
#if DEBUG
                print("[Onboarding] finish_setup_duplicate_tap_ignored")
#endif
                return
            }
            isFinishing = true
#if DEBUG
            print("[Onboarding] finish_setup_button_tapped_start")
#endif
            Task {
                await coordinator.advance(flow: flow, store: flow.tribeStore)
                await MainActor.run {
                    isFinishing = false
#if DEBUG
                    print("[Onboarding] finish_setup_button_tapped_end")
#endif
                }
            }
            return
        }
        Task {
            await coordinator.advance(flow: flow, store: flow.tribeStore)
        }
    }
}

#Preview {
    TribeOnboardingRootView()
        .environmentObject(AppFlowState())
        .environmentObject(AuthSessionContext())
}
