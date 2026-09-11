import SwiftUI
import Foundation

enum CalendarMockModel {
    struct UIStop: Identifiable, Hashable {
        let id: UUID
        var type: String
        var label: String
        var address: String

        init(id: UUID = UUID(), type: String, label: String, address: String) {
            self.id = id
            self.type = type
            self.label = label
            self.address = address
        }
    }

    struct UISchedule: Identifiable, Hashable {
        let id: UUID
        var title: String
        var timeString: String
        var recurrenceLabel: String
        var driverName: String
        var passengerNames: [String]
        var isEnabled: Bool
        var stops: [UIStop]

        init(
            id: UUID = UUID(),
            title: String,
            timeString: String,
            recurrenceLabel: String,
            driverName: String,
            passengerNames: [String],
            isEnabled: Bool,
            stops: [UIStop]
        ) {
            self.id = id
            self.title = title
            self.timeString = timeString
            self.recurrenceLabel = recurrenceLabel
            self.driverName = driverName
            self.passengerNames = passengerNames
            self.isEnabled = isEnabled
            self.stops = stops
        }
    }

    enum OccurrenceStatus: Hashable {
        case none
        case alreadyCreated
    }

    struct UIScheduleOccurrence: Identifiable, Hashable {
        let id: UUID
        var schedule: UISchedule
        var date: Date
        var status: OccurrenceStatus
        var subtitle: String

        init(
            id: UUID = UUID(),
            schedule: UISchedule,
            date: Date,
            status: OccurrenceStatus,
            subtitle: String
        ) {
            self.id = id
            self.schedule = schedule
            self.date = date
            self.status = status
            self.subtitle = subtitle
        }
    }
}

struct CalendarView: View {
    @EnvironmentObject private var activeHouseholdStore: ActiveHouseholdStore
    @EnvironmentObject private var authSession: AuthSessionContext
    @EnvironmentObject private var backendProfileContext: BackendProfileContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext
    @EnvironmentObject private var backendHouseholdPeopleContext: BackendHouseholdPeopleContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var backendSchedulesContext: BackendSchedulesContext
    @EnvironmentObject private var scheduleDataSource: ScheduleDataSource
    @EnvironmentObject private var runDataSource: RunDataSource
    @EnvironmentObject private var syncCoordinator: SyncCoordinator
    var suggestedRunsProvider: (() -> [RunSuggestion])? = nil
    var childMembersProvider: (() -> [TribeMember])? = nil
    var driverNameProvider: ((UUID) -> String?)? = nil
    @State private var monthDate = Date()
    @State private var selectedDate = Date()
    @State private var goToDaySchedule = false
    @State private var dayScheduleDate = Date()

    @State private var isShowingCreator = false
    @State private var dayActionMessage: String?
    @State private var showTemplateValidationAlert = false
    @State private var templateValidationMessage = ""
    @AppStorage("tb.education.dismissed.scheduleRunTip") private var hasDismissedScheduleRunTip = false
    @AppStorage("tb.education.dismissed.calendarMeaningTip") private var hasDismissedCalendarMeaningTip = false

    private let calendar = Calendar.current
    private let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let tribeBackground = Color(hex: "#f6f6f8")
    private let tribeCard = Color.white
    private let tribeIndigo = Color(hex: "#135bec")
    private let tribeSecondaryText = Color(hex: "#4c669a")

    private var selectedDayContext: CalendarDayContext {
        CalendarDayContextBuilder.build(
            date: selectedDate,
            calendar: calendar,
            children: calendarChildren,
            schedules: validTemplatesForCalendar,
            runs: runDataSource.runsForDay(selectedDate, calendar: calendar),
            driverNameProvider: driverNameProvider
        )
    }

    private var awarenessItemsForSelectedDate: [RunAwarenessItem] {
        let built = RunAwarenessBuilder().build(
            date: selectedDate,
            children: calendarChildren,
            schedules: validTemplatesForCalendar,
            runs: runDataSource.runsForDay(selectedDate, calendar: calendar)
        )
        return Array(built.prefix(5))
    }

    private var calendarChildren: [TribeMember] {
        var mapped = Dictionary(uniqueKeysWithValues: (childMembersProvider?() ?? []).map { ($0.id, $0) })
        for backendChild in backendChildrenContext.children {
            if mapped[backendChild.id] == nil {
                mapped[backendChild.id] = TribeMember(
                    id: backendChild.id,
                    fullName: {
                        let trimmed = backendChild.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        return trimmed.isEmpty ? backendChild.legalName : trimmed
                    }(),
                    memberType: .child,
                    schoolName: backendChild.schoolName,
                    gradeOrClass: backendChild.gradeOrClass,
                    roles: [.child, .passenger],
                    isLocationSharingEnabled: true,
                    isOnline: false
                )
            }
        }
        return Array(mapped.values).sorted { $0.fullName < $1.fullName }
    }

    private var weekStripDates: [Date] {
        let startOfSelected = calendar.startOfDay(for: selectedDate)
        let weekday = calendar.component(.weekday, from: startOfSelected) // Sun=1
        let mondayOffset = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: startOfSelected) else {
            return [startOfSelected]
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    // MARK: Illustrated timeline data

    private var timelineItems: [CalTimelineItem] {
        var rows: [(Int, CalTimelineItem)] = []

        for item in selectedDayContext.schoolItems {
            let t = extractTime(item.startTimeText ?? "")
            rows.append((t.minute, CalTimelineItem(
                id: "school-\(item.id.uuidString)",
                time: t.display.isEmpty ? "School" : t.display,
                icon: TribeArt.iconSchool, iconTint: TribePalette.blueSoft,
                avatar: CalArt.avatar(forName: item.childName, isChild: true),
                title: item.schoolName, place: "School", driver: item.childName,
                status: .scheduled
            )))
        }

        for item in selectedDayContext.activityItems {
            let t = extractTime(item.summaryLine)
            rows.append((t.minute, CalTimelineItem(
                id: "activity-\(item.id.uuidString)",
                time: t.display.isEmpty ? item.summaryLine : t.display,
                icon: TribeArt.locationIcon(for: item.activityName), iconTint: TribePalette.greenSoft,
                avatar: CalArt.avatar(forName: item.childName, isChild: true),
                title: item.activityName, place: item.detailLine ?? "Activity", driver: item.childName,
                status: .scheduled
            )))
        }

        for item in selectedDayContext.scheduleItems {
            let template = item.template
            rows.append((template.hour * 60 + template.minute, CalTimelineItem(
                id: "schedule-\(item.id.uuidString)",
                time: templateTimeText(template),
                icon: TribeArt.locationIcon(for: template.stops.first?.name ?? template.name), iconTint: TribePalette.primarySoft,
                avatar: nil,
                title: template.name, place: template.stops.first?.name, driver: nil,
                status: .scheduled
            )))
        }

        for item in selectedDayContext.runItems {
            let uiRun = RunUIAdapter.mapToUIRun(item.run)
            let status: CalStatus = uiRun.status == .active ? .live : (uiRun.status == .completed ? .done : .scheduled)
            let t = extractTime(templateTimeText(item.run.date))
            rows.append((t.minute, CalTimelineItem(
                id: "run-\(item.id.uuidString)",
                time: templateTimeText(item.run.date),
                icon: TribeArt.locationIcon(for: item.destinationContext ?? uiRun.title), iconTint: TribePalette.orangeSoft,
                avatar: item.driverName.map { CalArt.avatar(forName: $0, isChild: false) },
                title: uiRun.title, place: item.destinationContext, driver: item.driverName,
                status: status
            )))
        }

        return rows.sorted { $0.0 < $1.0 }.map { $0.1 }
    }

    private var heroAllSet: Bool { awarenessItemsForSelectedDate.isEmpty }

    private var heroHighlight: String {
        let count = timelineItems.count
        if count == 0 { return "Nothing planned" }
        return "\(count) \(count == 1 ? "activity" : "activities") planned"
    }

    private var heroFootnote: String {
        if timelineItems.isEmpty { return "Enjoy the free day" }
        return heroAllSet ? "Everyone is all set" : "\(awarenessItemsForSelectedDate.count) need attention"
    }

    private var summaryText: String {
        let acts = timelineItems.count
        let locs = Set(timelineItems.compactMap { ($0.place?.isEmpty == false) ? $0.place : nil }).count
        let drivers = Set(timelineItems.compactMap { ($0.driver?.isEmpty == false) ? $0.driver : nil }).count
        let actWord = acts == 1 ? "activity" : "activities"
        return "\(acts) \(actWord) • \(locs) location\(locs == 1 ? "" : "s") • \(drivers) driver\(drivers == 1 ? "" : "s")"
    }

    private var upcomingItems: [CalUpcomingItem] {
        var result: [CalUpcomingItem] = []
        let base = calendar.startOfDay(for: selectedDate)
        var lookahead = 0
        while result.count < 3 && lookahead < 14 {
            lookahead += 1
            guard let next = calendar.date(byAdding: .day, value: lookahead, to: base) else { break }
            let ctx = CalendarDayContextBuilder.build(
                date: next,
                calendar: calendar,
                children: calendarChildren,
                schedules: validTemplatesForCalendar,
                runs: runDataSource.runsForDay(next, calendar: calendar),
                driverNameProvider: driverNameProvider
            )
            let count = ctx.schoolItems.count + ctx.activityItems.count + ctx.scheduleItems.count + ctx.runItems.count
            guard count > 0 else { continue }

            var icons: [String] = []
            var tints: [Color] = []
            for a in ctx.activityItems.prefix(3) {
                icons.append(TribeArt.locationIcon(for: a.activityName)); tints.append(TribePalette.greenSoft)
            }
            if icons.count < 3 {
                for _ in ctx.scheduleItems.prefix(3 - icons.count) { icons.append(TribeArt.iconCar); tints.append(TribePalette.primarySoft) }
            }
            if icons.count < 3 {
                for _ in ctx.schoolItems.prefix(3 - icons.count) { icons.append(TribeArt.iconSchool); tints.append(TribePalette.blueSoft) }
            }
            let artworkSeed = ctx.activityItems.first?.activityName ?? ctx.scheduleItems.first?.template.name ?? "home"
            result.append(CalUpcomingItem(
                id: "up-\(Int(next.timeIntervalSince1970))",
                date: next,
                dayTitle: upcomingTitle(next),
                activityCount: count,
                miniIcons: icons,
                miniTints: tints,
                artwork: TribeArt.activityArtwork(for: artworkSeed)
            ))
        }
        return result
    }

    private var feedItems: [CalFeedItem] {
        selectedDayContext.runItems.compactMap { item in
            let uiRun = RunUIAdapter.mapToUIRun(item.run)
            guard uiRun.status == .completed else { return nil }
            let name = item.driverName ?? "Driver"
            return CalFeedItem(
                id: "feed-\(item.id.uuidString)",
                name: name,
                action: "completed \(uiRun.title)",
                timeText: "Today • \(templateTimeText(item.run.date))",
                avatar: CalArt.avatar(forName: name, isChild: false)
            )
        }
    }

    private var creatableTemplatesToday: [SystemDomain.ScheduleTemplate] {
        guard backendHouseholdContext.canStartRuns else { return [] }
        let existing = Set(runDataSource.runsForDay(selectedDate, calendar: calendar).compactMap { $0.templateId })
        return selectedDayContext.scheduleItems
            .map { $0.template }
            .filter { canCreateRunNow(for: $0) && !existing.contains($0.id) }
    }

    private func extractTime(_ s: String) -> (display: String, minute: Int) {
        guard let r = s.range(of: "([0-9]{1,2}):([0-9]{2})\\s*([AaPp][Mm])?", options: .regularExpression) else {
            return ("", Int.max)
        }
        let token = String(s[r])
        let comps = token.split(whereSeparator: { $0 == ":" || $0 == " " })
        var minute = Int.max
        if comps.count >= 2, var hour = Int(comps[0]), let mins = Int(comps[1].prefix(2)) {
            let lower = token.lowercased()
            if lower.contains("pm"), hour < 12 { hour += 12 }
            if lower.contains("am"), hour == 12 { hour = 0 }
            minute = hour * 60 + mins
        }
        return (token.uppercased(), minute)
    }

    private func longDayTitle(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMMM"; return f.string(from: date)
    }

    private func upcomingTitle(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMM"; return f.string(from: date)
    }

    private func startRun(for template: SystemDomain.ScheduleTemplate) {
        Task {
            guard hasHouseholdScope else { dayActionMessage = "Select an active household first."; return }
            guard backendHouseholdContext.canStartRuns else { dayActionMessage = "Only organisers and drivers can start runs."; return }
            guard canCreateRunNow(for: template) else {
                templateValidationMessage = "This schedule is not fully configured yet."
                showTemplateValidationAlert = true
                return
            }
            let created = await runDataSource.createRun(template: template, date: selectedDate)
            dayActionMessage = created
                ? "Created run for \(template.name)"
                : (runDataSource.lastError ?? "Run already exists for \(template.name)")
        }
    }

    private func hasLogistics(_ date: Date) -> Bool {
        !runDataSource.runsForDay(date, calendar: calendar).isEmpty || !occurrencesForDay(date).isEmpty
    }

    var body: some View {
        ZStack {
            TribePalette.canvas.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    calHeader
                    calWeekStrip
                    syncStatusHint
                    heroSection
                    if timelineItems.isEmpty {
                        familySuggestionsSection
                    } else {
                        dayTimelineCard
                        scheduleActionsSection
                        dailySummarySection
                    }
                    upcomingSection
                    familyFeedSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }

            if backendHouseholdContext.canManageSchedules {
                FloatingActionButton(
                    icon: "plus",
                    tint: TribePalette.primary
                ) {
                    isShowingCreator = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $goToDaySchedule) {
            DayScheduleListView(
                date: dayScheduleDate,
                occurrences: occurrencesForDay(dayScheduleDate)
            )
        }
        .sheet(isPresented: $isShowingCreator) {
            NavigationStack {
                ScheduleCreatorView()
                    .environmentObject(backendProfileContext)
                    .environmentObject(backendHouseholdContext)
                    .environmentObject(backendChildrenContext)
                    .environmentObject(backendSchedulesContext)
                    .environmentObject(backendHouseholdPeopleContext)
            }
        }
        .alert("Schedule Not Ready", isPresented: $showTemplateValidationAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(templateValidationMessage)
        }
        .onAppear {
            Task { await scheduleDataSource.refresh() }
        }
        .onChange(of: activeHouseholdStore.activeHouseholdId) { _, _ in
            Task {
                await backendChildrenContext.refreshForActiveHousehold()
                await scheduleDataSource.refresh()
                await runDataSource.refresh()
            }
        }
        .onChange(of: isShowingCreator) { _, isPresented in
            if !isPresented {
                Task { await scheduleDataSource.refresh() }
            }
        }
    }
    
    @ViewBuilder
    private var syncStatusHint: some View {
        if syncCoordinator.pendingCount > 0 || syncCoordinator.lastError != nil {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: syncCoordinator.lastError == nil ? "arrow.triangle.2.circlepath" : "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(syncCoordinator.lastError == nil ? tribeIndigo : .orange)
                    Text(syncCoordinator.lastError ?? "Some updates are pending sync. Changes will sync when connection returns.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tribeSecondaryText)
                    Spacer()
                }
            }
            .padding(16)
            .background(tribeCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        }
    }

    // MARK: - Illustrated sections

    private var calHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Calendar")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(TribePalette.ink)
                Text("Your family schedule")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TribePalette.muted)
            }
            Spacer()
            Button {
                let today = Date()
                selectedDate = calendar.startOfDay(for: today)
                monthDate = today
            } label: { headerIconLabel("calendar") }
            .buttonStyle(.plain)

            NavigationLink(value: Destination.schedulesList) {
                headerIconLabel("slider.horizontal.3")
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private func headerIconLabel(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(TribePalette.primary)
            .frame(width: 42, height: 42)
            .background(TribePalette.surface, in: Circle())
            .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    private var calWeekStrip: some View {
        HStack(spacing: 6) {
            ForEach(weekStripDates, id: \.self) { date in
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                Button { selectedDate = date } label: {
                    VStack(spacing: 6) {
                        Text(shortWeekdayLabel(date))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(isSelected ? .white : TribePalette.muted)
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isSelected ? .white : TribePalette.ink)
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.9) : (hasLogistics(date) ? TribePalette.primary : Color.clear))
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSelected ? TribePalette.primary : Color.clear,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: isSelected ? TribePalette.primary.opacity(0.35) : .clear, radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var heroSection: some View {
        CalHeroCard(title: heroTitle, highlight: heroHighlight, footnote: heroFootnote, allSet: heroAllSet)
    }

    private var heroTitle: String {
        timelineItems.isEmpty ? "Family Day" : "All together"
    }

    private var familySuggestions: [CalSuggestion] {
        [
            CalSuggestion(title: "Board Game", subtitle: "Snakes & Ladders, chess or cards",
                          systemIcon: "die.face.5.fill", tint: TribePalette.primary, soft: TribePalette.primarySoft),
            CalSuggestion(title: "Movie Night", subtitle: "Pick a family favourite",
                          systemIcon: "popcorn.fill", tint: TribePalette.orange, soft: TribePalette.orangeSoft),
            CalSuggestion(title: "Family Walk", subtitle: "Get some fresh air together",
                          systemIcon: "figure.walk", tint: TribePalette.green, soft: TribePalette.greenSoft)
        ]
    }

    private var familySuggestionsSection: some View {
        CalFamilySuggestionsCard(dayTitle: longDayTitle(selectedDate), suggestions: familySuggestions)
    }

    private var dayTimelineCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(longDayTitle(selectedDate))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(TribePalette.ink)
                    Text(timelineItems.isEmpty ? "No activities planned" : "\(timelineItems.count) activities planned")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TribePalette.muted)
                }
                Spacer()
                if calendar.isDateInToday(selectedDate) {
                    Text("Today")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TribePalette.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(TribePalette.primarySoft, in: Capsule())
                }
            }
            .padding(.bottom, 6)

            ForEach(Array(timelineItems.enumerated()), id: \.element.id) { idx, item in
                CalTimelineRow(item: item, isFirst: idx == 0, isLast: idx == timelineItems.count - 1)
            }
            Button {
                dayScheduleDate = selectedDate
                goToDaySchedule = true
            } label: {
                HStack(spacing: 4) {
                    Spacer()
                    Text("View full day")
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    Spacer()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TribePalette.primary)
                .padding(.top, 8)
            }
            .buttonStyle(.plain)
        }
        .illustratedPanel(cornerRadius: 24, padding: 18)
    }

    @ViewBuilder
    private var scheduleActionsSection: some View {
        if !creatableTemplatesToday.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HomeSectionHeader(title: "Ready to start")
                ForEach(creatableTemplatesToday, id: \.id) { template in
                    HStack(spacing: 12) {
                        Image(TribeArt.locationIcon(for: template.stops.first?.name ?? template.name))
                            .resizable().scaledToFit()
                            .frame(width: 22, height: 22)
                            .padding(8)
                            .background(TribePalette.primarySoft, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(TribePalette.ink)
                            Text(templateTimeText(template))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(TribePalette.muted)
                        }
                        Spacer()
                        Button { startRun(for: template) } label: {
                            Text("Start run")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(TribePalette.primary, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(TribePalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.black.opacity(0.04), lineWidth: 1))
                }
                if let dayActionMessage {
                    Text(dayActionMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TribePalette.muted)
                }
            }
        }
    }

    @ViewBuilder
    private var dailySummarySection: some View {
        if !timelineItems.isEmpty {
            CalDailySummaryRow(summary: summaryText) {
                dayScheduleDate = selectedDate
                goToDaySchedule = true
            }
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        if !upcomingItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HomeSectionHeader(title: "Upcoming", actionTitle: "View all") {
                    if let first = upcomingItems.first {
                        selectedDate = first.date
                    }
                }
                ForEach(upcomingItems) { item in
                    CalUpcomingCard(item: item) {
                        selectedDate = calendar.startOfDay(for: item.date)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var familyFeedSection: some View {
        if !feedItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HomeSectionHeader(title: "Family Feed")
                VStack(spacing: 10) {
                    ForEach(feedItems) { item in
                        CalFeedRow(item: item)
                    }
                }
                .illustratedPanel(cornerRadius: 24, padding: 16)
            }
        }
    }


    private func weekdaysLabel(_ weekdays: Set<Int>) -> String {
        let ordered = [2, 3, 4, 5, 6, 7, 1]
        let labels: [Int: String] = [1: "Sun", 2: "Mon", 3: "Tue", 4: "Wed", 5: "Thu", 6: "Fri", 7: "Sat"]
        let names = ordered.compactMap { day in weekdays.contains(day) ? labels[day] : nil }
        if names == ["Mon", "Tue", "Wed", "Thu", "Fri"] { return "Weekdays" }
        return names.joined(separator: ", ")
    }

    private func templateTimeText(_ template: SystemDomain.ScheduleTemplate) -> String {
        var components = DateComponents()
        components.hour = template.hour
        components.minute = template.minute
        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func templateTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func occurrencesForDay(_ date: Date) -> [CalendarMockModel.UIScheduleOccurrence] {
        occurrencesForMonth(containing: monthDate).filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func occurrencesForMonth(containing date: Date) -> [CalendarMockModel.UIScheduleOccurrence] {
        guard
            let interval = calendar.dateInterval(of: .month, for: date),
            let range = calendar.range(of: .day, in: .month, for: date)
        else {
            return []
        }

        var generated: [CalendarMockModel.UIScheduleOccurrence] = []
        for day in range {
            guard let dayDate = calendar.date(byAdding: .day, value: day - 1, to: interval.start) else { continue }
            let weekday = calendar.component(.weekday, from: dayDate)

            for template in validTemplatesForCalendar where template.isActive {
                guard template.weekdays.contains(weekday) else { continue }
                var dc = calendar.dateComponents([.year, .month, .day], from: dayDate)
                dc.hour = template.hour
                dc.minute = template.minute
                let occurrenceDate = calendar.date(from: dc) ?? dayDate

                var occurrence = CalendarMockModel.UIScheduleOccurrence(
                    id: deterministicOccurrenceID(scheduleID: template.id, date: dayDate),
                    schedule: calendarSchedule(from: template),
                    date: occurrenceDate,
                    status: .none,
                    subtitle: weekdaysLabel(template.weekdays)
                )
                if runDataSource.runsForDay(dayDate, calendar: calendar).contains(where: { $0.templateId == template.id }) {
                    occurrence.status = .alreadyCreated
                }
                generated.append(occurrence)
            }
        }
        return generated.sorted { $0.date < $1.date }
    }

    private func deterministicOccurrenceID(scheduleID: UUID, date: Date) -> UUID {
        let dayKey = Int(calendar.startOfDay(for: date).timeIntervalSince1970)
        let seed = scheduleID.uuidString + "-\(dayKey)"
        let hash = abs(seed.hashValue)
        let hex = String(format: "%032llx", UInt64(hash))
        let uuidString = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
        return UUID(uuidString: uuidString) ?? UUID()
    }

    private func shiftMonth(_ value: Int) {
        guard let shifted = calendar.date(byAdding: .month, value: value, to: monthDate) else { return }
        monthDate = shifted
        if !calendar.isDate(selectedDate, equalTo: shifted, toGranularity: .month) {
            selectedDate = calendar.startOfDay(for: shifted)
        }
    }

    private func formattedMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date)
    }

    private func formattedDayHeader(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMM"
        return f.string(from: date)
    }

    private func editorialDayHeader(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    private func shortWeekdayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    private func childName(for childId: UUID) -> String {
        calendarChildren.first(where: { $0.id == childId })?.preferredDisplayName ?? "Child"
    }

    private func monthGrid(for month: Date) -> [CalendarGridDay] {
        guard
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
            let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
        else {
            return []
        }

        let weekday = calendar.component(.weekday, from: monthStart) // Sun=1
        let mondayBasedOffset = (weekday + 5) % 7

        var result: [CalendarGridDay] = Array(repeating: CalendarGridDay(date: nil, dayNumber: nil), count: mondayBasedOffset)
        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                result.append(CalendarGridDay(date: date, dayNumber: day))
            }
        }
        while result.count % 7 != 0 {
            result.append(CalendarGridDay(date: nil, dayNumber: nil))
        }
        return result
    }

    private var hasHouseholdScope: Bool {
        if !authSession.isAuthenticated {
            return true
        }
        return backendHouseholdContext.hasActiveMembership && activeHouseholdStore.activeHouseholdId != nil
    }

    private func canCreateRunNow(for template: SystemDomain.ScheduleTemplate) -> Bool {
        guard backendHouseholdContext.canStartRuns else { return false }
        guard hasHouseholdScope else { return false }
        guard template.householdId == activeHouseholdStore.activeHouseholdId || !authSession.isAuthenticated else {
            return false
        }
        guard validChildIds.contains(template.childId) else { return false }
        return scheduleDataSource.templateExists(id: template.id, in: activeHouseholdStore.activeHouseholdId)
    }

    private var validChildIds: Set<UUID> {
        Set(calendarChildren.filter { $0.memberType == .child }.map(\.id))
    }

    private var validTemplatesForCalendar: [SystemDomain.ScheduleTemplate] {
        let templates = scheduleDataSource.templates.filter { template in
            if authSession.isAuthenticated, let householdId = activeHouseholdStore.activeHouseholdId {
                guard template.householdId == householdId else { return false }
            }
            guard validChildIds.contains(template.childId) else {
#if DEBUG
                print("CalendarView: skipping template \(template.id) because child is missing.")
#endif
                return false
            }
            return true
        }
        return templates
    }

    private func calendarSchedule(from template: SystemDomain.ScheduleTemplate) -> CalendarMockModel.UISchedule {
        CalendarMockModel.UISchedule(
            id: template.id,
            title: template.name,
            timeString: templateTimeText(template),
            recurrenceLabel: weekdaysLabel(template.weekdays),
            driverName: "Unassigned",
            passengerNames: [],
            isEnabled: template.isActive,
            stops: template.stops.map { stop in
                CalendarMockModel.UIStop(
                    id: stop.id,
                    type: stop.order == 0 ? "Pickup" : "Stop",
                    label: stop.name,
                    address: ""
                )
            }
        )
    }
}

private struct CalendarEventRow: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let timeText: String
    let category: String
    let avatarName: String
    let isActive: Bool
}

private struct CalendarGridView: View {
    let weekdays: [String]
    let gridDays: [CalendarGridDay]
    let selectedDate: Date
    let calendar: Calendar
    let secondaryText: Color
    let accent: Color
    let occurrenceProvider: (Date) -> Bool
    let onSelectDate: (Date) -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .kerning(1.2)
                        .foregroundStyle(secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                ForEach(gridDays.indices, id: \.self) { index in
                    let item = gridDays[index]
                    calendarCell(item)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private func calendarCell(_ item: CalendarGridDay) -> some View {
        if let date = item.date, let dayNumber = item.dayNumber {
            let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
            let hasEvent = occurrenceProvider(date)
            Button {
                onSelectDate(date)
            } label: {
                VStack(spacing: 4) {
                    Text("\(dayNumber)")
                        .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .frame(width: 34, height: 34)
                        .background(isSelected ? accent : .clear)
                        .clipShape(Circle())
                        .shadow(color: isSelected ? accent.opacity(0.35) : .clear, radius: 6, x: 0, y: 3)
                    Circle()
                        .fill(hasEvent ? accent.opacity(0.65) : .clear)
                        .frame(width: 5, height: 5)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear
                .frame(height: 44)
        }
    }
}

private struct EventCardView: View {
    let title: String
    let subtitle: String?
    let timeText: String
    let category: String
    let avatarName: String
    let isActive: Bool
    let accent: Color
    let secondaryText: Color

    @EnvironmentObject private var authSession: AuthSessionContext

    var body: some View {
        HStack(spacing: 12) {
            TribeAvatarView(
                identity: TribeAvatarIdentity(displayName: avatarName),
                size: .medium,
                accessToken: authSession.currentAccessToken
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(secondaryText)
                    Text(timeText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(secondaryText)
                }
            }

            Spacer()

            VStack(spacing: 8) {
                CategoryBadgeView(text: category, tint: accent)
                StatusDotView(state: isActive ? .active : .inactive)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
}

private struct CategoryBadgeView: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.10))
            .clipShape(Capsule())
    }
}

private struct FloatingActionButton: View {
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(tint)
                .clipShape(Circle())
                .shadow(color: tint.opacity(0.45), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

private struct StatusDotView: View {
    enum State {
        case active
        case inactive
    }

    let state: State

    var body: some View {
        Circle()
            .fill(state == .active ? Color.green : Color.gray.opacity(0.45))
            .frame(width: 9, height: 9)
    }
}

private struct CalendarGridDay {
    let date: Date?
    let dayNumber: Int?
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct CalendarPreviewRootView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Manual Preview Entry")
                    .font(.system(size: 22, weight: .bold))
                NavigationLink("Open Calendar") {
                    CalendarView()
                }
                .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CalendarUITheme.offWhite)
            .navigationTitle("Preview")
        }
    }
}

#Preview {
    CalendarPreviewRootView()
        .environmentObject(SyncCoordinator(queueRepository: LocalSyncQueueRepository()))
}
