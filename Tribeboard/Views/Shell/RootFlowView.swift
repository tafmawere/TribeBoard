import SwiftUI

struct RootFlowView: View {
    private enum PostAuthScreen {
        case loading
        case onboarding
        case mainApp
    }

    @EnvironmentObject var flow: AppFlowState
    @EnvironmentObject private var authSession: AuthSessionContext
    @StateObject private var termsStore = TermsAcceptanceStore()
    @State private var postAuthScreen: PostAuthScreen = .loading
    @State private var isEvaluatingOnboardingState = false
    @State private var pendingInvitePreview: HouseholdInvitePreview?
    @State private var skipPendingInviteGateOnce = false
    @State private var pendingInviteError: String?
    @State private var unauthenticatedInviteBanner: String?
    @State private var globalInviteNotice: String?
    private let authService: AuthService = SupabaseAuthService()
    private let householdService: HouseholdBackendService = SupabaseHouseholdBackendService()
    private let childService: ChildBackendService = SupabaseChildBackendService()
    private let profileService: ProfileBackendService = SupabaseProfileBackendService()
    private let userDefaults: UserDefaults = .standard

    var body: some View {
        ZStack {
            Group {
                switch flow.route {
                case .splash:
                    Color.clear
                case .auth:
                    authShell
                case .home:
                    homeShell
                }
            }
            .modifier(SplashDestinationEntranceModifier(
                progress: flow.destinationEntranceProgress,
                isActive: flow.isSplashOverlayVisible
            ))
            .allowsHitTesting(!flow.isSplashOverlayVisible)

            if flow.isSplashOverlayVisible {
                SplashScreenView()
                    .zIndex(1)
            }
        }
        .id(flow.rootReloadToken)
        .onAppear {
            applyDebugSkipOnboardingIfNeeded()
            applyKnownPostAuthRoute()
            if !authSession.didRestoreSession {
                Task {
                    await authSession.restoreSession()
                    flow.syncAuthenticationState(authSession.isAuthenticated)
                    applyKnownPostAuthRoute()
                    await evaluatePostAuthScreen()
                    flow.markLaunchReady()
                }
            } else {
                Task {
                    applyKnownPostAuthRoute()
                    await evaluatePostAuthScreen()
                    flow.markLaunchReady()
                }
            }
        }
        .onChange(of: authSession.isAuthenticated) { _, authenticated in
            flow.syncAuthenticationState(authenticated)
            if authenticated {
                unauthenticatedInviteBanner = nil
                applyKnownPostAuthRoute()
            } else {
                postAuthScreen = .loading
            }
            Task {
                await evaluatePostAuthScreen()
            }
        }
        .onChange(of: flow.isOnboarded) { _, isOnboarded in
            if isOnboarded {
                postAuthScreen = .mainApp
            }
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL {
                handleIncomingURL(url)
            }
        }
    }

    @ViewBuilder
    private var authShell: some View {
        ZStack(alignment: .top) {
            NavigationStack {
                AuthLandingView()
            }
            if let inviteBannerText = unauthenticatedInviteBanner {
                inviteFlowNoticeBar(text: inviteBannerText) {
                    unauthenticatedInviteBanner = nil
                }
            }
        }
    }

    @ViewBuilder
    private var homeShell: some View {
        if authSession.isAuthenticated {
            TermsGateView(termsStore: termsStore, onDecline: {
                Task { await authSession.signOut() }
            }) {
                ZStack {
                    postAuthEntryView
                    if let pendingInvitePreview {
                        PendingInviteAcceptanceView(
                            preview: pendingInvitePreview,
                            localizedError: pendingInviteError,
                            onAccept: {
                                await handlePendingInviteAccept()
                            },
                            onDecline: {
                                await handlePendingInviteDecline()
                            }
                        )
                        .transition(.opacity)
                    } else if let inviteGateNoticeText = globalInviteNotice {
                        inviteFlowNoticeBar(text: inviteGateNoticeText) {
                            globalInviteNotice = nil
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        } else {
            NavigationStack {
                AuthLandingView()
            }
        }
    }

    @ViewBuilder
    private var postAuthEntryView: some View {
        switch postAuthScreen {
        case .loading:
            postAuthRoutingPlaceholder
        case .onboarding:
            TribeOnboardingRootView()
        case .mainApp:
            DemoShellView(store: flow.tribeStore, initialTab: flow.onboardingDestinationTab)
        }
    }

    /// Minimal placeholder while onboarding route is resolved — never the Home shell.
    private var postAuthRoutingPlaceholder: some View {
        Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()
    }

    /// Applies instant shell only when returning-user cache is present; otherwise waits for evaluation.
    private func applyKnownPostAuthRoute() {
        guard authSession.isAuthenticated else {
            postAuthScreen = .loading
            return
        }
        if OnboardingTestingPreferences.forceOnboardingOnNextLaunch {
            postAuthScreen = .onboarding
            return
        }
        if OnboardingPreferences.hasReturningUserCache(userDefaults: userDefaults) {
            postAuthScreen = .mainApp
            return
        }
        postAuthScreen = .loading
    }

    private func inviteFlowNoticeBar(text: String, onDismiss: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "envelope.badge.fill")
                .foregroundStyle(.tint)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    @MainActor
    private func handleIncomingURL(_ url: URL) {
        if GoogleSignInService.handleOpenURL(url) {
            return
        }
        if handleAuthCallbackDeepLink(url) {
            return
        }
        handleInviteDeepLink(url)
    }

    @MainActor
    private func handleAuthCallbackDeepLink(_ url: URL) -> Bool {
        guard AuthCallbackURLParser.isAuthCallbackURL(url),
              let parsed = AuthCallbackURLParser.parseSession(from: url) else {
            return false
        }
        Task {
            await authSession.applyAuthCallbackSession(parsed)
            flow.syncAuthenticationState(authSession.isAuthenticated)
            if authSession.isAuthenticated {
                await evaluatePostAuthScreen()
            }
        }
        return true
    }

    @MainActor
    private func handleInviteDeepLink(_ url: URL) {
        guard PendingInvitePersistence.ingestInviteURL(url) else { return }
        InviteFlowLogger.inviteDeepLinkIngested(
            authPresent: authSession.isAuthenticated,
            host: url.host
        )
        if authSession.isAuthenticated {
            globalInviteNotice = nil
            Task {
                await evaluatePostAuthScreen()
            }
        } else {
            unauthenticatedInviteBanner = "We saved your invite. Sign in or create an account to finish joining."
        }
    }

    @MainActor
    private func evaluatePostAuthScreen() async {
        guard authSession.isAuthenticated else {
            flow.updateOnboardingSnapshot(membershipCount: 0, childCount: 0)
            return
        }
        guard !isEvaluatingOnboardingState else { return }
        isEvaluatingOnboardingState = true
        defer { isEvaluatingOnboardingState = false }

        if OnboardingTestingPreferences.forceOnboardingOnNextLaunch {
            flow.updateOnboardingSnapshot(
                membershipCount: flow.onboardingMembershipCount,
                childCount: flow.onboardingChildCount,
                onboardingComplete: false
            )
            postAuthScreen = .onboarding
#if DEBUG
            print("[Onboarding] forced_onboarding_launch flag=true")
#endif
            return
        }

        do {
            guard let session = try await authService.restoreSession() else {
#if DEBUG
                print("[OnboardingCheck] sessionRestoreFailed=true")
#endif
                if OnboardingPreferences.hasReturningUserCache(userDefaults: userDefaults) {
                    postAuthScreen = .mainApp
                } else {
                    postAuthScreen = .onboarding
                }
                return
            }
            await refreshPendingInviteGate(session: session)
            InviteFlowLogger.postAuthInviteGate(
                authUserId: session.userId,
                showedAcceptanceUI: pendingInvitePreview != nil,
                householdId: pendingInvitePreview?.householdId,
                inviteId: pendingInvitePreview?.inviteId
            )
            let pendingInvites = try await householdService.fetchPendingInvitesForSignedInUser(session: session)
            let membershipsBeforeAccept = try await householdService.fetchMyMemberships(session: session)
            let shouldDeferInviteAcceptToOnboarding = !pendingInvites.isEmpty && membershipsBeforeAccept.isEmpty
#if DEBUG
            print("[RootFlowView] pending_invites_for_onboarding=\(pendingInvites.count) defer_accept=\(shouldDeferInviteAcceptToOnboarding)")
#endif
            if !shouldDeferInviteAcceptToOnboarding {
#if DEBUG
                print("[RootFlowView] invite accept pipeline start user_id=\(session.userId)")
#endif
                try await householdService.acceptPendingInvitesForSignedInUser(session: session)
#if DEBUG
                print("[RootFlowView] accepted pending invites pipeline completed user_id=\(session.userId)")
#endif
            }
            let memberships = try await householdService.fetchMyMemberships(session: session)
            let profile = try await profileService.fetchMyProfile()
            let householdIds = Set(memberships.map(\.householdId))
            let activeHouseholdId = userDefaults.activeHouseholdId
            let hasHousehold = !householdIds.isEmpty
            let selectedHouseholdId: UUID? = {
                if let activeHouseholdId, householdIds.contains(activeHouseholdId) {
                    return activeHouseholdId
                }
                return householdIds.first
            }()
            if let selectedHouseholdId {
                userDefaults.activeHouseholdId = selectedHouseholdId
            }

            var allChildIds = Set<UUID>()
            for householdId in householdIds {
                let children = try await childService.fetchChildren(householdId: householdId, session: session)
                allChildIds.formUnion(children.map(\.id))
            }
            let childCount = allChildIds.count
            let membershipCount = memberships.count
            let hasMembership = membershipCount > 0
            let hasActiveMembership = memberships.contains(where: \.isActiveMembership)
            let hasPendingMembershipOnly = hasMembership && !hasActiveMembership

            let backendSnapshot = OnboardingPreferences.evaluateBackendCompletion(
                profile: profile,
                memberships: memberships,
                activeHouseholdId: selectedHouseholdId ?? activeHouseholdId,
                childCount: childCount
            )

            let onboardingComplete = backendSnapshot.isComplete
            flow.updateOnboardingSnapshot(
                membershipCount: membershipCount,
                childCount: childCount,
                onboardingComplete: onboardingComplete
            )

            if onboardingComplete || hasHousehold || hasPendingMembershipOnly {
                postAuthScreen = .mainApp
                OnboardingPreferences.setCompletedOnboarding(true, userDefaults: userDefaults)
            } else {
                postAuthScreen = .onboarding
                OnboardingPreferences.setCompletedOnboarding(false, userDefaults: userDefaults)
            }

            InviteFlowLogger.routingDestination(screenLabel(postAuthScreen), authUserId: session.userId)

#if DEBUG
            OnboardingPreferences.logBackendSnapshot(backendSnapshot, routingTo: screenLabel(postAuthScreen))
            print(
                "[Onboarding] onboarding_route_decided user_id=\(session.userId), memberships=\(membershipCount), " +
                "children=\(childCount), hasActiveMembership=\(hasActiveMembership), " +
                "screen=\(screenLabel(postAuthScreen))"
            )
            print("[RootFlowView] bootstrap refresh complete user_id=\(session.userId), screen=\(screenLabel(postAuthScreen))")
#endif
        } catch {
            if OnboardingPreferences.hasReturningUserCache(userDefaults: userDefaults) {
                postAuthScreen = .mainApp
#if DEBUG
                print("[RootFlowView] onboarding evaluation failed error=\(error.localizedDescription), keeping main_app from returning-user cache")
#endif
            } else if postAuthScreen == .loading {
                postAuthScreen = .onboarding
#if DEBUG
                print("[RootFlowView] onboarding evaluation failed error=\(error.localizedDescription), screen=onboarding")
#endif
            } else {
#if DEBUG
                print("[RootFlowView] onboarding evaluation failed error=\(error.localizedDescription), keeping screen=\(screenLabel(postAuthScreen))")
#endif
            }
        }
    }

    private func screenLabel(_ screen: PostAuthScreen) -> String {
        switch screen {
        case .loading: return "loading"
        case .onboarding: return "onboarding"
        case .mainApp: return "main_app"
        }
    }

    private func applyDebugSkipOnboardingIfNeeded() {
#if DEBUG
        guard DebugFlags.skipOnboarding else { return }
        flow.syncAuthenticationState(true)
        if !flow.onboardingComplete {
            // Reuse normal completion path so shell/tab state stays consistent.
            flow.completeOnboarding(startingTab: .home)
        } else {
            OnboardingPreferences.setCompletedOnboarding(true)
        }
#endif
    }

    @MainActor
    private func refreshPendingInviteGate(session: AuthUserSession) async {
        pendingInviteError = nil
        globalInviteNotice = nil
        if skipPendingInviteGateOnce {
            skipPendingInviteGateOnce = false
            pendingInvitePreview = nil
            return
        }
        guard let snap = PendingInvitePersistence.load() else {
            pendingInvitePreview = nil
            return
        }
        let loaded: HouseholdInvitePreview?
        do {
            if let inviteId = snap.inviteId {
                loaded = try await householdService.fetchInvitePreviewByInviteId(inviteId, session: session)
            } else if snap.prefersToken, let token = snap.inviteToken {
                loaded = try await householdService.fetchInvitePreviewByToken(token, session: session)
            } else if let code = snap.inviteCode {
                loaded = try await householdService.fetchInvitePreviewByCode(code, session: session)
            } else {
                loaded = nil
            }
        } catch {
            PendingInvitePersistence.clear(reason: "preview_rpc_error")
            pendingInvitePreview = nil
            globalInviteNotice = SupabaseHouseholdBackendService.ServiceError.userFacingInviteJoinMessage(for: error)
#if DEBUG
            print("[RootFlowView] pending invite preview failed error=\(error.localizedDescription)")
#endif
            return
        }
        guard let loaded else {
            PendingInvitePersistence.clear(reason: "preview_empty")
            pendingInvitePreview = nil
            globalInviteNotice = "This invite link is not valid anymore."
            return
        }
        if loaded.isPendingAndNotExpired {
            let backup = loaded.backupInviteCode?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            PendingInvitePersistence.save(
                code: (backup?.isEmpty == false) ? backup : snap.inviteCode,
                token: snap.inviteToken,
                inviteId: loaded.inviteId,
                householdId: loaded.householdId,
                email: snap.invitedEmail
            )
            pendingInvitePreview = loaded
#if DEBUG
            print("[RootFlowView] pending invite gate shown household_id=\(loaded.householdId.uuidString)")
#endif
        } else {
            let message = userFacingStalePreviewMessage(loaded)
            PendingInvitePersistence.clear(reason: "preview_not_actionable")
            pendingInvitePreview = nil
            globalInviteNotice = message
        }
    }

    @MainActor
    private func handlePendingInviteAccept() async {
        pendingInviteError = nil
        do {
            guard let session = try await authService.restoreSession() else { return }
            guard let snap = PendingInvitePersistence.load() else {
                pendingInvitePreview = nil
                return
            }
            let response: HouseholdInviteAcceptRPCResponse
            if let inviteId = snap.inviteId {
                response = try await householdService.acceptHouseholdInviteRPC(inviteId: inviteId, session: session)
            } else if snap.prefersToken, let token = snap.inviteToken {
                response = try await householdService.acceptHouseholdInviteRPC(inviteToken: token, session: session)
            } else if let code = snap.inviteCode {
                response = try await householdService.acceptHouseholdInviteRPC(inviteCode: code, session: session)
            } else {
                pendingInvitePreview = nil
                return
            }
#if DEBUG
            print("[RootFlowView] pending invite accept outcome=\(response.outcome)")
#endif
            switch response.outcome.lowercased() {
            case "joined", "already_member":
                PendingInvitePersistence.clear(reason: "accept_from_gate_success")
                pendingInvitePreview = nil
                globalInviteNotice = nil
                if let householdId = response.householdId {
                    userDefaults.activeHouseholdId = householdId
                }
                skipPendingInviteGateOnce = true
                InviteFlowLogger.routingDestination("post_pending_accept_reevaluate", authUserId: session.userId)
                await evaluatePostAuthScreen()
            default:
                pendingInviteError = inviteOutcomeMessage(for: response.outcome)
            }
        } catch {
            pendingInviteError = SupabaseHouseholdBackendService.ServiceError.userFacingInviteJoinMessage(for: error)
        }
    }

    @MainActor
    private func handlePendingInviteDecline() async {
        pendingInviteError = nil
        do {
            guard let session = try await authService.restoreSession() else { return }
            if let code = PendingInvitePersistence.load()?.inviteCode, !code.isEmpty {
                _ = try await householdService.declineHouseholdInviteRPC(inviteCode: code, session: session)
            }
            PendingInvitePersistence.clear(reason: "decline_from_gate")
            pendingInvitePreview = nil
            skipPendingInviteGateOnce = true
            await evaluatePostAuthScreen()
        } catch {
            pendingInviteError = SupabaseHouseholdBackendService.ServiceError.userFacingInviteJoinMessage(for: error)
        }
    }

    private func userFacingStalePreviewMessage(_ preview: HouseholdInvitePreview) -> String {
        guard let status = preview.normalizedInviteStatus else {
            return "This invite is no longer available."
        }
        switch status {
        case .pending:
            if let expiresAt = preview.expiresAt,
               let parsed = BackendTimestampParser.parse(expiresAt),
               parsed < Date() {
                return inviteOutcomeMessage(for: "expired")
            }
            return inviteOutcomeMessage(for: "invalid_code")
        case .cancelled:
            return inviteOutcomeMessage(for: "cancelled")
        case .accepted:
            return inviteOutcomeMessage(for: "already_used")
        case .declined:
            return inviteOutcomeMessage(for: "declined")
        case .expired:
            return inviteOutcomeMessage(for: "expired")
        }
    }

    private func inviteOutcomeMessage(for outcome: String) -> String {
        switch outcome.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "invalid_code":
            return "This invite code does not exist."
        case "expired":
            return "This invite has expired."
        case "already_used":
            return "This invite has already been used."
        case "cancelled":
            return "This invite was cancelled by the organiser."
        case "declined":
            return "This invite is no longer available."
        case "not_authenticated":
            return "Session expired. Please sign in again to continue."
        default:
            return "Something went wrong while joining the household. Please try again."
        }
    }
}

/// Gentle rise + fade for auth/home as the splash crossfades away.
private struct SplashDestinationEntranceModifier: ViewModifier {
    var progress: CGFloat
    var isActive: Bool

    func body(content: Content) -> some View {
        if isActive {
            content
                .opacity(0.12 + 0.88 * progress)
                .scaleEffect(0.965 + 0.035 * progress, anchor: .center)
                .offset(y: (1 - progress) * 24)
        } else {
            content
        }
    }
}

#Preview {
    RootFlowView()
        .environmentObject(AppFlowState())
}
