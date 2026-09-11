import CoreLocation
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var flow: AppFlowState
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendProfileContext: BackendProfileContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var activeHouseholdStore: ActiveHouseholdStore
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var scheduleDataSource: ScheduleDataSource
    @EnvironmentObject private var locationService: LocationReadinessService
    @EnvironmentObject private var notificationService: NotificationService
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    @EnvironmentObject private var backendDriversContext: BackendDriversContext
    @EnvironmentObject private var runLocationObserverStore: RunLocationObserverStore
    @EnvironmentObject private var activeRunDriverSessionStore: ActiveRunDriverSessionStore
    var onOpenRuns: () -> Void = {}
    var onOpenDispatch: () -> Void = {}
    var onOpenCalendar: () -> Void = {}
    var onOpenFamily: () -> Void = {}
    var onCreateRun: () -> Void = {}
    var onOpenDriverMode: () -> Void = {}
    var onOpenRunDetails: (String) -> Void = { _ in }
    var onOpenProfile: () -> Void = {}
    var onOpenNotifications: () -> Void = {}
    /// When true, card sections show skeleton placeholders while cached/live data loads.
    var isContentLoading: Bool = false
    /// Set when a unified unread-notification count is available; badge hidden when zero.
    var unreadNotificationCount: Int = 0
    @State private var isActivePulseOn = false
    @StateObject private var etaSmoothingService = ETASmoothingService()
    @AppStorage("tb.education.dismissed.childFirstTip") private var hasDismissedChildFirstTip = false

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Data (unchanged wiring to Supabase-backed sources)
    // ─────────────────────────────────────────────────────────────────────────

    private var isRefreshInProgress: Bool {
        runDataSource.isRefreshing || runDataSource.isLoading
    }

    private var attentionItems: [AttentionItem] {
        runDataSource.attentionItems(for: Date())
    }

    private var scopedChildren: [TribeMember] {
        let scoped = flow.tribeStore.children().filter { member in
            backendChildrenContext.children.contains(where: { $0.id == member.id })
        }
        return scoped.isEmpty ? flow.tribeStore.children() : scoped
    }

    private var runAwarenessItems: [RunAwarenessItem] {
        let scoped = flow.tribeStore.children().filter { member in
            backendChildrenContext.children.contains(where: { $0.id == member.id })
        }
        let built = RunAwarenessBuilder().build(
            date: Date(),
            children: scoped,
            schedules: scheduleDataSource.templates,
            runs: runDataSource.runsForDay(Date())
        )
        return Array(built.prefix(3))
    }

    private var childrenCount: Int {
        flow.tribeStore.familyStore.summary.totalChildren
    }

    private var hasSchedules: Bool {
        !scheduleDataSource.templates.isEmpty
    }

    private var hasRunsToday: Bool {
        !runDataSource.runsForDay(Date()).isEmpty
    }

    private var profileAvatarIdentity: TribeAvatarIdentity {
        if let profile = backendProfileContext.currentUserProfile {
            return profile.avatarIdentity(
                fallbackDisplayName: backendProfileContext.currentUserProfile?.resolvedDisplayName(
                    providerDisplayName: authSession.currentUserProviderDisplayName,
                    fallbackEmail: authSession.currentUserEmail
                ).value ?? "User"
            )
        }
        return TribeAvatarIdentity(displayName: greetingName)
    }

    private var greetingName: String {
        let full = backendProfileContext.currentUserProfile?.resolvedDisplayName(
            providerDisplayName: authSession.currentUserProviderDisplayName,
            fallbackEmail: authSession.currentUserEmail
        ).value ?? "there"
        return full.split(separator: " ").first.map(String.init) ?? full
    }

    private var activeHouseholdName: String {
        guard let activeHouseholdId = activeHouseholdStore.activeHouseholdId else { return "None" }
        return backendHouseholdContext.households.first(where: { $0.id == activeHouseholdId })?.name ?? "Unknown household"
    }

    private var earlyStageEducationMessage: ProductEducationItem? {
        guard !hasDismissedChildFirstTip else { return nil }
        if childrenCount == 0 {
            return ProductEducationProvider.item(for: .childFirstSetup)
        }
        if childrenCount > 0 && !hasSchedules {
            return ProductEducationItem(
                id: UUID(),
                topic: .childFirstSetup,
                title: "Next step",
                message: "You've added children. Next, add schedules to start planning runs."
            )
        }
        if childrenCount > 0 && hasSchedules && !hasRunsToday {
            return ProductEducationItem(
                id: UUID(),
                topic: .scheduleVsRun,
                title: "You are close",
                message: "School routines are set. Add or generate runs when you're ready."
            )
        }
        return nil
    }

    private var showNotificationHint: Bool {
        notificationService.authorizationState == .notDetermined
            || notificationService.authorizationState == .denied
    }

    private var showSyncWarningHint: Bool {
        syncCoordinator.recentSyncWarning != nil
    }

    private var showPendingSyncHint: Bool {
        syncCoordinator.pendingCount > 0 || syncCoordinator.lastError != nil
    }

    private var activeRun: SystemDomain.RunInstance? {
        runDataSource.runs
            .filter { $0.status == .inProgress }
            .sorted { $0.date < $1.date }
            .first
    }

    private var activeRunETA: ETAPrediction? {
        guard let activeRun else { return nil }
        guard let location = driverLocationForETA(run: activeRun) else {
            etaSmoothingService.clear(runId: activeRun.id)
            return nil
        }
        return runDataSource.smoothedETAForRun(
            activeRun.id,
            currentLocation: location,
            liveSpeedMetersPerSecond: locationService.estimatedSpeedMetersPerSecond,
            sampleCount: locationService.speedSampleCount,
            speedVariance: locationService.speedVariance,
            smoothingService: etaSmoothingService
        )
    }

    private func driverLocationForETA(run: SystemDomain.RunInstance) -> CLLocation? {
        let currentUserId = authSession.currentUserId.flatMap(UUID.init(uuidString:))
        if RunDriverIdentityResolver.isCurrentUserDriver(
            run: run,
            drivers: backendDriversContext.drivers,
            currentUserId: currentUserId
        ) {
            return locationService.currentLocation
        }
        return runLocationObserverStore.position(for: run.id)?.location
    }

    private var viewModel: HomeViewModel {
        let calendar = Calendar.current
        let now = Date()
        let activeRunCount = runDataSource.runs.filter { $0.status == .inProgress }.count
        let todayRuns = runDataSource.runs
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .sorted { $0.date < $1.date }
            .map { run in
                HomeRunItem(
                    title: run.stopSnapshots.last?.name ?? "Scheduled Run",
                    subtitle: homeRunSubtitle(for: run),
                    status: run.status == .completed ? .completed : .pending
                )
            }
        let upcoming = runDataSource.runs
            .filter { $0.date > now && $0.status == .scheduled }
            .sorted { $0.date < $1.date }
            .first

        return HomeViewModel(
            activeRunCount: activeRunCount,
            syncStatusText: syncStatusText,
            upcomingEvent: mapUpcomingEvent(upcoming),
            todaysRuns: todayRuns
        )
    }

    private var syncStatusText: String {
        let status = syncCoordinator.status
        switch status.state {
        case .syncing:
            return "SYNCING..."
        case .pending:
            return "PENDING (\(status.pendingCount))"
        case .failed:
            return "FAILED"
        case .succeeded:
            if let lastSyncAt = status.lastSyncAt {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                return formatter.localizedString(for: lastSyncAt, relativeTo: Date()).uppercased()
            }
            return "JUST NOW"
        case .idle:
            return status.pendingCount > 0 ? "PENDING (\(status.pendingCount))" : "JUST NOW"
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Body
    // ─────────────────────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            TribePalette.canvas
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    greetingHeader
                    if isContentLoading {
                        HomeLoadingPlaceholder()
                    } else {
                        heroSection
                        familyStatusSection
                        journeySection
                        activitiesSection
                    }
                    quickActionsSection
                    if !isContentLoading {
                        operationalSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .refreshable {
                await runDataSource.refresh()
            }
        }
        .task {
            await runDataSource.bootstrapIfNeeded()
            await syncCoordinator.refreshStatus()
            await notificationService.refreshAuthorizationState()
        }
        .onChange(of: activeHouseholdStore.activeHouseholdId) { _, _ in
            Task {
                await backendChildrenContext.refreshForActiveHousehold()
                await runDataSource.refresh()
                await scheduleDataSource.refresh()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isActivePulseOn = true
            }
#if DEBUG
            let displayName = backendProfileContext.currentUserProfile?.resolvedDisplayName(
                providerDisplayName: authSession.currentUserProviderDisplayName,
                fallbackEmail: authSession.currentUserEmail
            ).value ?? "User"
            print(
                "[HomeView] auth.uid=\(authSession.currentUserId ?? "nil"), currentUserProfile.displayName=\(displayName), " +
                "memberships.count=\(backendHouseholdContext.memberships.count), households.count=\(backendHouseholdContext.households.count), " +
                "activeHouseholdId=\(activeHouseholdStore.activeHouseholdId?.uuidString ?? "nil"), household_name=\(activeHouseholdName)"
            )
#endif
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Greeting header
    // ─────────────────────────────────────────────────────────────────────────

    private var greetingHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Hi \(greetingName) 👋")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(TribePalette.ink)
                HStack(spacing: 6) {
                    Text("Here's what's happening today")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TribePalette.muted)
                    SyncingMicroStatus(isActive: isContentLoading)
                }
            }

            Spacer(minLength: 8)

            headerIconButton(
                system: "bell.fill",
                badge: unreadNotificationCount,
                action: onOpenNotifications
            )
            headerProfileButton(action: onOpenProfile)
        }
    }

    private func headerIconButton(system: String, badge: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: system)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TribePalette.primary)
                    .frame(width: 42, height: 42)
                    .background(TribePalette.surface, in: Circle())
                    .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                if badge > 0 {
                    Text(badge > 9 ? "9+" : "\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .padding(.horizontal, badge > 9 ? 3 : 0)
                        .background(Color.red, in: Capsule())
                        .overlay(Capsule().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notifications")
    }

    private func headerProfileButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            TribeAvatarView(
                identity: profileAvatarIdentity,
                size: .small,
                accessToken: authSession.currentAccessToken
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
    }

    private var headerProfileFallback: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.system(size: 28, weight: .regular))
            .foregroundStyle(TribePalette.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(TribePalette.surface)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - 1. Hero Live Run
    // ─────────────────────────────────────────────────────────────────────────

    private var heroSection: some View {
        let run = activeRun
        return HeroRunCard(
            info: heroInfo,
            onPrimary: {
                if let run {
                    let currentUserId = authSession.currentUserId.flatMap(UUID.init(uuidString:))
                    if RunDriverIdentityResolver.isCurrentUserDriver(
                        run: run,
                        drivers: backendDriversContext.drivers,
                        currentUserId: currentUserId
                    ) {
                        activeRunDriverSessionStore.present(runId: run.id)
                    } else {
                        onOpenRunDetails(run.id.uuidString)
                    }
                } else if viewModel.upcomingEvent != nil {
                    onOpenCalendar()
                } else {
                    onCreateRun()
                }
            },
            onCall: run != nil ? { onOpenDispatch() } : nil
        )
    }

    private var heroInfo: HeroRunInfo {
        if let run = activeRun {
            let childName = childDisplayName(for: run)
            let etaMinutes = activeRunETA.map(\.estimatedMinutesRemaining)
            let journey = RunJourneyStatusBuilder.build(
                run: run,
                childDisplayName: childName,
                etaMinutes: etaMinutes
            )
            let driverIdentity = RunDriverIdentityResolver.resolve(
                run: run,
                backendDriversContext: backendDriversContext,
                profilesByUserId: backendHouseholdContext.activeHouseholdProfilesByUserId
            )
            let destination = run.stopSnapshots.last?.name ?? "Destination"
            var stats: [HeroStat] = []
            let etaLabel = ETADisplayFormatter.minutesLabel(for: activeRunETA)
            if activeRunETA != nil {
                stats.append(HeroStat(icon: "clock.fill", label: "ETA", value: etaLabel))
                if let eta = activeRunETA {
                    stats.append(HeroStat(icon: "mappin.and.ellipse", label: "Arrive", value: formattedTime(eta.nextStopETA)))
                }
            } else {
                stats.append(HeroStat(icon: "clock.fill", label: "ETA", value: etaLabel))
                stats.append(HeroStat(icon: "mappin.and.ellipse", label: "To", value: destination))
            }
            let footnote: String = {
                if let remote = runLocationObserverStore.position(for: run.id) {
                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .short
                    return "Last update: \(formatter.localizedString(for: remote.updatedAt, relativeTo: Date()))"
                }
                return "Last update: \(syncStatusText.lowercased())"
            }()
            return HeroRunInfo(
                statusLabel: "LIVE RUN",
                isLive: true,
                headline: journey.headline,
                bannerArt: TribeArt.runTracking,
                destinationName: activeRunETA?.nextStopName ?? destination,
                destinationTime: activeRunETA.map { formattedTime($0.nextStopETA) },
                stats: stats,
                driverName: driverIdentity.displayName,
                driverRating: nil,
                driverAvatar: nil,
                driverAvatarIdentity: driverIdentity.avatar,
                ctaText: "Track Live Trip",
                footnote: footnote
            )
        } else if let upcoming = viewModel.upcomingEvent {
            return HeroRunInfo(
                statusLabel: "NEXT RUN",
                isLive: false,
                headline: "\(upcoming.title) is coming up next",
                bannerArt: TribeArt.runSchool,
                destinationName: upcoming.location,
                destinationTime: upcoming.timeRange,
                stats: [
                    HeroStat(icon: "clock.fill", label: "Time", value: upcoming.timeRange),
                    HeroStat(icon: "mappin.and.ellipse", label: "Where", value: upcoming.location)
                ],
                driverName: nil,
                driverRating: nil,
                driverAvatar: nil,
                ctaText: "View Schedule",
                footnote: nil
            )
        } else {
            return HeroRunInfo(
                statusLabel: "ALL CLEAR",
                isLive: false,
                headline: "No active runs right now",
                bannerArt: TribeArt.runHome,
                destinationName: nil,
                destinationTime: nil,
                stats: [],
                driverName: nil,
                driverRating: nil,
                driverAvatar: nil,
                ctaText: "Create a Run",
                footnote: "You're all caught up for now"
            )
        }
    }

    private func childDisplayName(for run: SystemDomain.RunInstance) -> String {
        if let child = scopedChildren.first(where: { $0.id == run.childId }) {
            let name = child.displayName ?? child.fullName
            return name.split(separator: " ").first.map(String.init) ?? name
        }
        return heroSubject(run)
    }

    private func heroSubject(_ run: SystemDomain.RunInstance) -> String {
        if let first = scopedChildren.first {
            let name = (first.displayName ?? first.fullName)
            return name.split(separator: " ").first.map(String.init) ?? name
        }
        return runTitle(run)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - 2. Family status ("Who's where?")
    // ─────────────────────────────────────────────────────────────────────────

    private var familyStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "Who's where?", actionTitle: "View all", action: onOpenFamily)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(familyEntries) { entry in
                        FamilyStatusChip(
                            entry: entry,
                            accessToken: authSession.currentAccessToken
                        ) { onOpenFamily() }
                    }
                    AddChildChip { onOpenFamily() }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var familyEntries: [FamilyStatusEntry] {
        let driving = activeRun != nil
        var result: [FamilyStatusEntry] = []

        result.append(
            FamilyStatusEntry(
                id: UUID(),
                name: "You",
                avatarIdentity: profileAvatarIdentity,
                status: driving ? .driving : .available,
                statusTitle: driving ? "Driving" : "Available",
                detail: driving ? "On duty" : "At home",
                accentIcon: driving ? TribeArt.iconCar : TribeArt.iconHome
            )
        )

        for (index, child) in scopedChildren.prefix(5).enumerated() {
            let fullName = child.displayName ?? child.fullName
            let shortName = fullName.split(separator: " ").first.map(String.init) ?? fullName
            let onTheWay = driving && index == 0

            if onTheWay {
                let destination = activeRun?.stopSnapshots.last?.name ?? "Activity"
                result.append(
                    FamilyStatusEntry(
                        id: child.id,
                        name: shortName,
                        avatarIdentity: child.avatarIdentity,
                        status: .activity,
                        statusTitle: "On the way",
                        detail: destination,
                        accentIcon: TribeArt.iconCar
                    )
                )
            } else if index.isMultiple(of: 2) {
                result.append(
                    FamilyStatusEntry(
                        id: child.id,
                        name: shortName,
                        avatarIdentity: child.avatarIdentity,
                        status: .atSchool,
                        statusTitle: "At school",
                        detail: child.schoolName ?? "In class",
                        accentIcon: TribeArt.iconSchool
                    )
                )
            } else {
                result.append(
                    FamilyStatusEntry(
                        id: child.id,
                        name: shortName,
                        avatarIdentity: child.avatarIdentity,
                        status: .available,
                        statusTitle: "At home",
                        detail: "Available",
                        accentIcon: TribeArt.iconHome
                    )
                )
            }
        }

        return result
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - 3. Today's Journey timeline
    // ─────────────────────────────────────────────────────────────────────────

    private var journeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "Today's Plan", actionTitle: "See full schedule", action: onOpenCalendar)
            JourneyTimelineView(stops: journeyStops)
                .illustratedPanel(cornerRadius: 22, padding: 14)
        }
    }

    private var journeyStops: [JourneyStop] {
        let runs = runDataSource.runsForDay(Date()).sorted { $0.date < $1.date }
        guard !runs.isEmpty else { return defaultJourney }

        var stops: [JourneyStop] = []
        stops.append(JourneyStop(id: UUID(), time: "Start", title: "Home", subtitle: "Day started", icon: TribeArt.iconHome, state: .done))
        for run in runs.prefix(4) {
            let destination = run.stopSnapshots.last?.name ?? runTitle(run)
            let state: JourneyState
            let subtitle: String
            switch run.status {
            case .completed: state = .done; subtitle = "Completed"
            case .inProgress: state = .live; subtitle = "In progress"
            default: state = .upcoming; subtitle = "Scheduled"
            }
            stops.append(
                JourneyStop(
                    id: run.id,
                    time: formattedTime(run.date),
                    title: destination,
                    subtitle: subtitle,
                    icon: TribeArt.locationIcon(for: destination),
                    state: state
                )
            )
        }
        stops.append(JourneyStop(id: UUID(), time: "Eve", title: "Home", subtitle: "Expected", icon: TribeArt.iconHome, state: .upcoming))
        return stops
    }

    private var defaultJourney: [JourneyStop] {
        let liveTitle = viewModel.upcomingEvent?.title ?? "Tennis Practice"
        let liveTime = viewModel.upcomingEvent?.timeRange.split(separator: " ").first.map(String.init) ?? "3:30 PM"
        return [
            JourneyStop(id: UUID(), time: "7:30 AM", title: "Home", subtitle: "Day started", icon: TribeArt.iconHome, state: .done),
            JourneyStop(id: UUID(), time: "8:00 AM", title: "School Run", subtitle: "Completed", icon: TribeArt.iconCar, state: .done),
            JourneyStop(id: UUID(), time: "8:30 AM", title: "School", subtitle: "Completed", icon: TribeArt.iconSchool, state: .done),
            JourneyStop(id: UUID(), time: liveTime, title: liveTitle, subtitle: "In progress", icon: TribeArt.iconTennis, state: .live),
            JourneyStop(id: UUID(), time: "5:00 PM", title: "Home", subtitle: "Expected", icon: TribeArt.iconHome, state: .upcoming)
        ]
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - 4. Activities carousel
    // ─────────────────────────────────────────────────────────────────────────

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "Upcoming Activities", actionTitle: "View calendar", action: onOpenCalendar)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(activityEntries) { entry in
                        ActivityChip(entry: entry) { onOpenCalendar() }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var activityEntries: [ActivityEntry] {
        let now = Date()
        let upcoming = runDataSource.runs
            .filter { $0.date > now && $0.status == .scheduled }
            .sorted { $0.date < $1.date }
            .prefix(6)

        if !upcoming.isEmpty {
            return upcoming.map { run in
                let title = run.stopSnapshots.last?.name ?? runTitle(run)
                return ActivityEntry(
                    id: run.id,
                    title: title,
                    timeText: "\(relativeDay(run.date)) • \(formattedTime(run.date))",
                    statusText: nil,
                    statusColor: TribePalette.primary,
                    art: TribeArt.activityArtwork(for: title),
                    tint: tint(forArtwork: TribeArt.activityArtwork(for: title))
                )
            }
        }
        return curatedActivities
    }

    private var curatedActivities: [ActivityEntry] {
        [
            ActivityEntry(id: UUID(), title: "Tennis Practice", timeText: "Today • 3:30 PM", statusText: "In progress", statusColor: TribePalette.primary, art: TribeArt.activityTennis, tint: TribePalette.greenSoft),
            ActivityEntry(id: UUID(), title: "Piano Lesson", timeText: "Tomorrow • 4:00 PM", statusText: nil, statusColor: TribePalette.pink, art: TribeArt.activityPiano, tint: TribePalette.pinkSoft),
            ActivityEntry(id: UUID(), title: "Soccer Match", timeText: "Sat • 9:00 AM", statusText: nil, statusColor: TribePalette.blue, art: TribeArt.activitySoccer, tint: TribePalette.blueSoft),
            ActivityEntry(id: UUID(), title: "Art Class", timeText: "Sun • 11:00 AM", statusText: nil, statusColor: TribePalette.orange, art: TribeArt.activityArt, tint: TribePalette.orangeSoft)
        ]
    }

    private func tint(forArtwork art: String) -> Color {
        switch art {
        case TribeArt.activityTennis, TribeArt.activitySoccer: return TribePalette.greenSoft
        case TribeArt.activityPiano, TribeArt.activityBallet: return TribePalette.pinkSoft
        case TribeArt.activityArt, TribeArt.activityChess: return TribePalette.orangeSoft
        case TribeArt.activitySwimming, TribeArt.activityRobotics: return TribePalette.blueSoft
        default: return TribePalette.primarySoft
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - 5. Quick actions
    // ─────────────────────────────────────────────────────────────────────────

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "Quick Actions")
            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(quickActions) { QuickActionTile(item: $0) }
            }
        }
    }

    private var quickActions: [QuickActionItem] {
        [
            QuickActionItem(title: "Start Drive", subtitle: "Be a driver", systemIcon: "steeringwheel", tint: TribePalette.blue, softTint: TribePalette.blueSoft, action: onOpenDriverMode),
            QuickActionItem(title: "Track Child", subtitle: "Live location", systemIcon: "location.fill", tint: TribePalette.green, softTint: TribePalette.greenSoft, action: onOpenDispatch),
            QuickActionItem(title: "Create Run", subtitle: "New trip", systemIcon: "plus", tint: TribePalette.primary, softTint: TribePalette.primarySoft, action: onCreateRun),
            QuickActionItem(title: "Add Activity", subtitle: "To calendar", systemIcon: "calendar", tint: TribePalette.orange, softTint: TribePalette.orangeSoft, action: onOpenCalendar)
        ]
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Operational hints (kept functional, tucked below the fold)
    // ─────────────────────────────────────────────────────────────────────────

    private var operationalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            attentionPanel
            logisticsGapsPanel
            onboardingEducationHint
            notificationHint
            pendingSyncHint
            syncWarningHint
        }
    }

    @ViewBuilder
    private var notificationHint: some View {
        if showNotificationHint {
            HomeCard {
                HStack(spacing: 8) {
                    Text("Enable notifications for run reminders")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HomeTheme.textSecondary)
                    Spacer()
                    Button("Enable") {
                        Task {
                            let granted = await notificationService.requestAuthorization()
                            if granted {
                                await runDataSource.reconcileNotifications(notificationService: notificationService)
                            }
                        }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HomeTheme.primary)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var pendingSyncHint: some View {
        if showPendingSyncHint {
            HomeCard {
                HStack(spacing: 8) {
                    Image(systemName: syncCoordinator.lastError == nil ? "arrow.triangle.2.circlepath" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(syncCoordinator.lastError == nil ? HomeTheme.primary : .orange)
                    Text(syncCoordinator.lastError ?? "Some updates are pending sync. Changes will sync when connection returns.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HomeTheme.textSecondary)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private var syncWarningHint: some View {
        if showSyncWarningHint, let warning = syncCoordinator.recentSyncWarning {
            HomeCard {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text(warning)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HomeTheme.textSecondary)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private var onboardingEducationHint: some View {
        if let item = earlyStageEducationMessage {
            ProductEducationCard(item: item) {
                hasDismissedChildFirstTip = true
            }
        }
    }

    @ViewBuilder
    private var logisticsGapsPanel: some View {
        if !runAwarenessItems.isEmpty && attentionItems.isEmpty {
            HomeCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Needs Attention")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(HomeTheme.textPrimary)

                    ForEach(runAwarenessItems) { item in
                        if let runId = item.relatedRunId {
                            Button {
                                onOpenRunDetails(runId.uuidString)
                            } label: {
                                awarenessRow(item.message)
                            }
                            .buttonStyle(.plain)
                        } else {
                            awarenessRow(item.message)
                        }
                    }
                }
            }
        }
    }

    private func awarenessRow(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
                .padding(.top, 2)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(HomeTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var attentionPanel: some View {
        let visible = Array(attentionItems.prefix(3))
        let remaining = max(0, attentionItems.count - visible.count)
        if !visible.isEmpty {
            HomeCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Attention")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(HomeTheme.textPrimary)

                    ForEach(visible) { item in
                        Button {
                            if let runId = item.runId?.uuidString {
                                onOpenRunDetails(runId)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(attentionColor(item.severity))
                                Text(item.message)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(HomeTheme.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(item.runId == nil)
                    }

                    if remaining > 0 {
                        Text("+\(remaining) more")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(HomeTheme.textSecondary)
                    }

                    Button {
                        onOpenDispatch()
                    } label: {
                        Text("Open Dispatch")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HomeTheme.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Helpers (unchanged)
    // ─────────────────────────────────────────────────────────────────────────

    private func homeRunSubtitle(for run: SystemDomain.RunInstance) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeText = formatter.string(from: run.date)
        if run.status == .completed {
            return "Completed at \(timeText)"
        }
        return "Starts at \(timeText)"
    }

    private func mapUpcomingEvent(_ run: SystemDomain.RunInstance?) -> HomeUpcomingEvent? {
        guard let run else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeText = formatter.string(from: run.date)
        return HomeUpcomingEvent(
            category: "RUN",
            label: "UPCOMING EVENT",
            title: run.stopSnapshots.last?.name ?? "Scheduled Run",
            timeRange: timeText,
            location: run.stopSnapshots.first?.name ?? "Route",
            passengerInitials: ["TB"]
        )
    }

    private func attentionColor(_ severity: AttentionSeverity) -> Color {
        switch severity {
        case .critical:
            return Color.red
        case .warning:
            return Color.orange
        case .info:
            return HomeTheme.primary
        }
    }

    private func runTitle(_ run: SystemDomain.RunInstance) -> String {
        let trimmed = run.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Scheduled Run" : trimmed
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func relativeDay(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    HomeView()
        .environmentObject(RunDataSource())
        .environmentObject(LocationReadinessService())
        .environmentObject(NotificationService())
        .environmentObject(SyncCoordinator(queueRepository: LocalSyncQueueRepository()))
}
