import SwiftUI
import PhotosUI
import UIKit

struct OnboardingFlowView: View {
    private enum VenueSetupRoute: Equatable {
        case addVenue
        case venueRules(UUID)
        case editRule(venueId: UUID, ruleId: UUID?)
    }

    private enum AvatarEditTarget {
        case adult(UUID)
        case child(UUID)
        case pendingChild
    }

    @EnvironmentObject var flow: AppFlowState
    @StateObject private var state = OnboardingState()
    @State private var pendingChildID = UUID()
    @State private var pendingChildName = ""
    @State private var pendingChildDisplayName = ""
    @State private var pendingChildDateOfBirth: Date?
    @State private var pendingChildSchoolName = ""
    @State private var pendingChildSchoolAddress = ""
    @State private var pendingChildGradeOrClass = ""
    @State private var pendingChildSchoolDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @State private var pendingChildSchoolStartTime: DateComponents?
    @State private var pendingChildSchoolEndTime: DateComponents?
    @State private var pendingChildPhotoURL: String?
    @State private var pendingChildAvatarSymbol: AvatarSymbol?
    @State private var showingAddChildSheet = false
    @State private var showContinueWithIncompleteChildren = false
    @State private var selectedAdultPhotoItem: PhotosPickerItem?
    @State private var selectedChildPhotoItem: PhotosPickerItem?
    @State private var activeAdultAvatarID: UUID?
    @State private var activeChildAvatarID: UUID?
    @State private var showingAdultAvatarActionSheet = false
    @State private var showingChildAvatarActionSheet = false
    @State private var showingAdultPhotoLibrary = false
    @State private var showingChildPhotoLibrary = false
    @State private var showingPendingChildAvatarOptions = false
    @State private var showingPendingChildPhotoLibrary = false
    @State private var selectedPendingChildPhotoItem: PhotosPickerItem?
    @State private var showingAvatarPickerSheet = false
    @State private var avatarEditTarget: AvatarEditTarget?
    @StateObject private var venueSearchModel = LocationSearchModel()
    @StateObject private var pendingChildSchoolSearchModel = LocationSearchModel()
    @State private var venueTypeSelection: VenueType = .school
    @State private var venueLabel: String = ""
    @State private var venueWeekdays: Set<OnboardingWeekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @State private var venueDropOffTime = DateComponents(hour: 7, minute: 45)
    @State private var venuePickupTime = DateComponents(hour: 14, minute: 30)
    @State private var tripModeSelection: TripMode = .roundTrip
    @State private var venueSetupRoute: VenueSetupRoute = .addVenue
    @State private var previewWeekdaySelection: OnboardingWeekday = .monday
    @State private var showingSetupSuccessMoment = false
    private let adaptiveCardBackground = Color(uiColor: .secondarySystemBackground)
    private let adaptiveFieldBackground = Color(uiColor: .tertiarySystemBackground)
    private let adaptiveChipBackground = Color(uiColor: .tertiarySystemBackground)
    private let adaptiveBorder = Color(uiColor: .separator).opacity(0.35)
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case primaryAdultName
        case otherAdultName(Int)
        case venueLabel
        case venueSearch
        case childName
        case childDisplayName
        case childGrade
        case childSchoolName
        case childSchoolAddress
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 16) {
                header

                Group {
                    switch state.step {
                    case .welcome:
                        welcomeStep
                    case .createTribe:
                        createTribeScreen
                    case .joinTribe:
                        joinTribeStep
                    case .setHome:
                        setHomeStep
                    case .addAdults:
                        addAdultsStep
                    case .addChildren:
                        addChildrenStep
                    case .childSetup:
                        childSetupStep
                    case .review:
                        reviewStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)

            if showingSetupSuccessMoment {
                setupSuccessOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(10)
            }
        }
    }

    private var header: some View {
        HStack {
            if state.step != .welcome {
                Button {
                    state.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(adaptiveCardBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 36, height: 36)
            }

            Spacer()

            Text(state.step.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()
            Spacer().frame(width: 36, height: 36)
        }
    }

    private var welcomeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Let's set up your tribe")
                    .font(.system(size: 32, weight: .bold))
                Text("Choose how you'd like to get started.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)

                onboardingChoiceCard(
                    icon: "house.fill",
                    title: "Create Tribe",
                    subtitle: "Start a new tribe and configure child mobility."
                ) {
                    state.goToCreateTribe()
                }

                onboardingChoiceCard(
                    icon: "person.3.fill",
                    title: "Join Tribe",
                    subtitle: "Enter a family code to join an existing tribe."
                ) {
                    state.goToJoinTribe()
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var createTribeScreen: some View {
        CreateTribeView(store: flow.tribeStore) {
            state.tribeName = flow.tribeStore.tribe?.name ?? state.tribeName
            state.familyCode = flow.tribeStore.tribe?.tribeCode ?? state.familyCode
            state.continueFromCreateTribe()
        }
    }

    private var joinTribeStep: some View {
        JoinTribeView(store: flow.tribeStore) {
            state.familyCode = flow.tribeStore.tribe?.tribeCode ?? state.familyCode
            // Join-by-code skips the remaining onboarding steps.
            flow.completeOnboarding(startingTab: .home)
        }
    }

    private var setHomeStep: some View {
        SetHomeView(
            homeLabel: $state.homeLabel,
            homeAddress: $state.homeAddress,
            homeAddressTitle: $state.homeAddressTitle,
            homeAddressSubtitle: $state.homeAddressSubtitle,
            homeLatitude: $state.homeLatitude,
            homeLongitude: $state.homeLongitude
        ) {
            state.continueFromSetHome()
        }
    }

    private var addAdultsStep: some View {
        VStack(spacing: 12) {
            onboardingCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Adults")
                        .font(.system(size: 24, weight: .bold))
                    Text("Add adults and assign access and driving permissions. Next, add your children.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }

            ProductEducationCard(item: ProductEducationProvider.item(for: .childFirstSetup))

            if !state.hasDriver {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.78, green: 0.58, blue: 0.20))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No drivers assigned yet")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("You can continue, but runs can't be executed until a driver is added.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.bottom, 8)
            }

            if let primaryBinding = primaryAdultBinding {
                onboardingCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 10) {
                            Text("Primary Admin")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.primary)
                            Spacer()
                            AppBadge(text: "PRIMARY", style: .info)
                        }

                        HStack(spacing: 12) {
                            editableAdultAvatar(for: primaryBinding, fallbackName: "You", size: .medium)
                            onboardingInputField("Primary adult name", text: primaryBinding.name, field: .primaryAdultName)
                        }

                        relationshipSection(for: primaryBinding)
                        accessSection(for: primaryBinding, isPrimaryAdmin: true)
                        driverCapabilitySection(for: primaryBinding)
                    }
                }
            }

            onboardingCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Other Adults")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Assign support roles for additional adults.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(otherAdultIndices, id: \.self) { index in
                let adultBinding = Binding<Adult>(
                    get: { state.adults[index] },
                    set: { state.adults[index] = $0 }
                )
                onboardingCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            editableAdultAvatar(for: adultBinding, fallbackName: "Adult", size: .small)
                            onboardingInputField("Adult name", text: adultBinding.name, field: .otherAdultName(index))
                        }
                        relationshipSection(for: adultBinding)
                        accessSection(for: adultBinding, isPrimaryAdmin: false)
                        driverCapabilitySection(for: adultBinding)
                    }
                }
            }

            Button {
                state.addAdult()
            } label: {
                Label("Invite Parent / Add Adult", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
            }
            .buttonStyle(.plain)

            primaryButton("Continue") {
                state.continueFromAddAdults()
            }
            .disabled(!state.canContinueFromCurrentStep)
        }
    }

    private var addChildrenStep: some View {
        VStack(spacing: 12) {
            onboardingCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Children Setup Dashboard")
                        .font(.system(size: 24, weight: .bold))
                    Text("Add your children first, then configure school and routine for each.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text("\(state.readyChildrenCount) of \(state.children.count) children ready")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                    Text("Schedules and runs are created around your child's routine.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Activities help Tribeboard understand where your child needs to be beyond school.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    if state.children.contains(where: { !$0.hasSchoolConfigured }) {
                        Text("Adding your child's school helps Tribeboard plan runs and schedules.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ProductEducationCard(item: ProductEducationProvider.item(for: .schoolAndActivities))

            onboardingCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Household Members")
                        .font(.system(size: 16, weight: .bold))
                    ForEach(state.adults.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { adult in
                        HStack {
                            Text(adult.name)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Text(adult.canDrive ? "Driver" : "Helper")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            ForEach(state.children) { child in
                Button {
                    state.selectedChildID = child.id
                    venueSetupRoute = .addVenue
                    state.step = .childSetup
                } label: {
                    onboardingCard {
                        HStack {
                            MemberAvatarView(
                                member: child.avatar,
                                size: 42,
                                showCameraBadge: true,
                                onTap: {
                                    activeChildAvatarID = child.id
                                    avatarEditTarget = .child(child.id)
                                    showingChildAvatarActionSheet = true
                                }
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(child.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? (child.name.isEmpty ? "Unnamed child" : child.name))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                if let age = child.age {
                                    Text("\(age) years old")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                                Text(child.schoolRoutineSummary)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text(child.activityCountText)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if child.isSetupComplete {
                                statusPill(title: "Ready", icon: "checkmark.circle.fill", isPositive: true)
                            } else {
                                setupRequiredPill
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            if state.children.isEmpty {
                onboardingCard {
                    Text("Start by adding your children.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            onboardingCard {
                Button {
                    pendingChildID = UUID()
                    pendingChildName = ""
                    pendingChildDisplayName = ""
                    pendingChildDateOfBirth = nil
                    pendingChildSchoolName = ""
                    pendingChildSchoolAddress = ""
                    pendingChildGradeOrClass = ""
                    pendingChildSchoolDays = [.monday, .tuesday, .wednesday, .thursday, .friday]
                    pendingChildSchoolStartTime = nil
                    pendingChildSchoolEndTime = nil
                    pendingChildPhotoURL = nil
                    pendingChildAvatarSymbol = nil
                    showingAddChildSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Add Child")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                }
                .buttonStyle(.plain)
            }

            primaryButton("Continue") {
                if state.children.isEmpty {
                    return
                }
                if state.readyChildrenCount == 0 {
                    showContinueWithIncompleteChildren = true
                } else {
                    state.continueFromAddChildren()
                }
            }
            .disabled(state.children.isEmpty)
        }
        .sheet(isPresented: $showingAddChildSheet) {
            addChildSheet
                .presentationDetents([.medium])
        }
        .photosPicker(isPresented: $showingAdultPhotoLibrary, selection: $selectedAdultPhotoItem, matching: .images)
        .photosPicker(isPresented: $showingChildPhotoLibrary, selection: $selectedChildPhotoItem, matching: .images)
        .photosPicker(isPresented: $showingPendingChildPhotoLibrary, selection: $selectedPendingChildPhotoItem, matching: .images)
        .onChange(of: selectedAdultPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data),
                   let id = activeAdultAvatarID {
                    let savedPhoto = AvatarPhotoStore.saveAvatarPhoto(from: uiImage, memberId: id)
                    state.setAdultAvatarURL(id: id, photoURL: savedPhoto)
                }
                selectedAdultPhotoItem = nil
            }
        }
        .onChange(of: selectedChildPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data),
                   let id = activeChildAvatarID {
                    let savedPhoto = AvatarPhotoStore.saveAvatarPhoto(from: uiImage, memberId: id)
                    state.setChildAvatarURL(id: id, photoURL: savedPhoto)
                }
                selectedChildPhotoItem = nil
            }
        }
        .onChange(of: selectedPendingChildPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    pendingChildPhotoURL = AvatarPhotoStore.saveAvatarPhoto(from: uiImage, memberId: pendingChildID)
                }
                selectedPendingChildPhotoItem = nil
            }
        }
        .confirmationDialog("Update Adult Avatar", isPresented: $showingAdultAvatarActionSheet, titleVisibility: .visible) {
            Button("Edit Avatar") {
                showingAvatarPickerSheet = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Update Child Avatar", isPresented: $showingChildAvatarActionSheet, titleVisibility: .visible) {
            Button("Edit Avatar") {
                showingAvatarPickerSheet = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingAvatarPickerSheet) {
            AvatarPickerSheet(
                onUploadPhoto: {
                    switch avatarEditTarget {
                    case .adult:
                        showingAdultPhotoLibrary = true
                    case .child:
                        showingChildPhotoLibrary = true
                    case .pendingChild, .none:
                        showingPendingChildPhotoLibrary = true
                    }
                },
                onSelectSymbol: { selected in
                    applySelectedAvatarSymbol(selected)
                },
                onRemovePhoto: hasPhotoForAvatarTarget ? {
                    removePhotoForAvatarTarget()
                } : nil
            )
        }
        .confirmationDialog("Child Avatar", isPresented: $showingPendingChildAvatarOptions, titleVisibility: .visible) {
            Button("Edit Avatar") {
                showingAvatarPickerSheet = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog(
            "Some children still need setup",
            isPresented: $showContinueWithIncompleteChildren,
            titleVisibility: .visible
        ) {
            Button("Finish Setup") { }
            Button("Continue Anyway") {
                state.continueFromAddChildren()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You can finish configuration later in Tribe → Children.")
        }
    }

    private var childSetupStep: some View {
        VStack(spacing: 12) {
            if let selected = state.selectedChild, let index = state.selectedChildIndex {
                switch venueSetupRoute {
                case .addVenue:
                    childSetupEditor(for: selected, index: index)
                case .venueRules(let venueId):
                    venueRulesView(for: selected, index: index, venueId: venueId)
                case .editRule(let venueId, let ruleId):
                    ruleEditorView(for: selected, index: index, venueId: venueId, ruleId: ruleId)
                }
            } else {
                onboardingCard {
                    Text("Select a child first.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func childSetupEditor(for _: OnboardingChildDraft, index: Int) -> some View {
        let binding = Binding<OnboardingChildDraft>(
            get: { state.children[index] },
            set: { state.updateChild($0) }
        )

        return VStack(spacing: 12) {
            onboardingCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Venue")
                        .font(.system(size: 20, weight: .bold))
                    Text("Venue Type")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(VenueType.allCases, id: \.self) { type in
                            Button(type.rawValue) {
                                venueTypeSelection = type
                                if venueLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    venueLabel = type.rawValue
                                }
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(venueTypeSelection == type ? .white : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(venueTypeSelection == type ? Color(red: 0.388, green: 0.400, blue: 0.945) : adaptiveChipBackground)
                            .clipShape(Capsule())
                            .buttonStyle(.plain)
                        }
                    }
                    onboardingInputField("Label (e.g., School, Soccer)", text: $venueLabel, field: .venueLabel)
                    LocationSearchField(
                        title: "Venue Search",
                        placeholder: "Search venue",
                        model: venueSearchModel,
                        onSelected: { _ in },
                        onCleared: { }
                    )
                }
            }

            primaryButton("Save Venue") {
                guard let place = selectedVenuePlace else { return }
                var updated = binding.wrappedValue
                let normalizedLabel = venueLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? venueTypeSelection.rawValue : venueLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                let venue = Venue(
                    id: UUID(),
                    type: venueTypeSelection,
                    label: normalizedLabel,
                    place: place,
                    ruleIds: []
                )
                updated.venues.append(venue)
                state.updateChild(updated)
                venueSetupRoute = .venueRules(venue.id)
            }
            .disabled(!canSaveVenue)
        }
        .onAppear {
            venueSetupRoute = .addVenue
            venueSearchModel.clearSelection()
            venueTypeSelection = .school
            venueLabel = ""
        }
    }

    private func venueRulesView(for child: OnboardingChildDraft, index: Int, venueId: UUID) -> some View {
        let rules = rulesForVenue(child: child, venueId: venueId)
        let venue = child.venues.first(where: { $0.id == venueId })
        let totalRuns = rules.reduce(0) { $0 + ($1.weekdays.count * $1.tripMode.runsPerDay) }
        let today = currentWeekday()
        let previewDay = previewWeekdaySelection

        return VStack(spacing: 12) {
            onboardingCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Schedules for \(venue?.label ?? "Venue")")
                        .font(.system(size: 20, weight: .bold))
                    Text("This venue has \(rules.count) schedule rules")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Runs/week from all rules: \(totalRuns)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let sample = rules.first(where: { $0.weekdays.contains(today) }) {
                        Text("Sample today (\(today.rawValue)): \(summaryText(for: sample))")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preview by weekday")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        weekdayPillsRow(weekdays: Binding(
                            get: { [previewWeekdaySelection] },
                            set: { newValue in
                                if let first = OnboardingWeekday.calendarOrder.first(where: { newValue.contains($0) }) {
                                    previewWeekdaySelection = first
                                }
                            }
                        ))
                        if let sample = rules.first(where: { $0.weekdays.contains(previewDay) }) {
                            Text("\(previewDay.rawValue): \(summaryText(for: sample))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("\(previewDay.rawValue): No runs configured")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            ForEach(rules, id: \.id) { rule in
                Button {
                    venueWeekdays = rule.weekdays
                    tripModeSelection = rule.tripMode
                    venueDropOffTime = rule.dropOffTime ?? DateComponents(hour: 7, minute: 45)
                    venuePickupTime = rule.pickupTime ?? DateComponents(hour: 14, minute: 30)
                    venueSetupRoute = .editRule(venueId: venueId, ruleId: rule.id)
                } label: {
                    onboardingCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(OnboardingWeekday.joinedLabel(rule.weekdays)) • \(rule.tripMode.rawValue)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            if rule.tripMode != .pickupOnly, let drop = rule.dropOffTime {
                                Text("Drop-off: \(formatTime(drop))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            if rule.tripMode != .dropOffOnly, let pick = rule.pickupTime {
                                Text("Pickup: \(formatTime(pick))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Button {
                venueWeekdays = [.monday, .tuesday, .wednesday, .thursday, .friday]
                tripModeSelection = .roundTrip
                venueDropOffTime = DateComponents(hour: 7, minute: 45)
                venuePickupTime = DateComponents(hour: 14, minute: 30)
                venueSetupRoute = .editRule(venueId: venueId, ruleId: nil)
            } label: {
                Label("+ Add schedule rule", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button("Back") {
                    venueSetupRoute = .addVenue
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(adaptiveCardBackground)
                .clipShape(Capsule())

                primaryButton("Done") {
                    state.step = .addChildren
                }
            }
        }
    }

    private func ruleEditorView(for child: OnboardingChildDraft, index: Int, venueId: UUID, ruleId: UUID?) -> some View {
        let binding = Binding<OnboardingChildDraft>(
            get: { state.children[index] },
            set: { state.updateChild($0) }
        )
        let overlapWarnings = overlappingWarnings(for: child, venueId: venueId, editingRuleId: ruleId)

        return VStack(spacing: 12) {
            onboardingCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(ruleId == nil ? "Add Rule" : "Edit Rule")
                        .font(.system(size: 20, weight: .bold))
                    weekdayPillsRow(weekdays: $venueWeekdays)
                }
            }

            onboardingCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trip Mode")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(TripMode.allCases, id: \.self) { mode in
                            Button(mode.rawValue) { tripModeSelection = mode }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(tripModeSelection == mode ? .white : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(tripModeSelection == mode ? Color(red: 0.388, green: 0.400, blue: 0.945) : adaptiveChipBackground)
                                .clipShape(Capsule())
                                .buttonStyle(.plain)
                        }
                    }
                    if tripModeSelection != .pickupOnly {
                        DatePicker("Drop-off time", selection: timeBinding(for: $venueDropOffTime), displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                    }
                    if tripModeSelection != .dropOffOnly {
                        DatePicker("Pickup time", selection: timeBinding(for: $venuePickupTime), displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                    }
                    if !isVenueRuleValid {
                        Text("Pickup time must be after drop-off time.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                    ForEach(overlapWarnings, id: \.self) { warning in
                        Text(warning)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }

            HStack(spacing: 10) {
                Button("Cancel") {
                    venueSetupRoute = .venueRules(venueId)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(adaptiveCardBackground)
                .clipShape(Capsule())

                primaryButton("Save Rule") {
                    var updated = binding.wrappedValue
                    let newRule = VenueRule(
                        id: ruleId ?? UUID(),
                        venueId: venueId,
                        weekdays: venueWeekdays,
                        dropOffTime: tripModeSelection == .pickupOnly ? nil : venueDropOffTime,
                        pickupTime: tripModeSelection == .dropOffOnly ? nil : venuePickupTime,
                        tripMode: tripModeSelection
                    )

                    if let ruleId, let idx = updated.venueRules.firstIndex(where: { $0.id == ruleId }) {
                        updated.venueRules[idx] = newRule
                    } else {
                        updated.venueRules.append(newRule)
                    }

                    if let venueIdx = updated.venues.firstIndex(where: { $0.id == venueId }) {
                        var ids = Set(updated.venues[venueIdx].ruleIds)
                        ids.insert(newRule.id)
                        updated.venues[venueIdx].ruleIds = Array(ids)
                    }
                    state.updateChild(updated)
                    venueSetupRoute = .venueRules(venueId)
                }
                .disabled(!isVenueRuleValid || hasDuplicateRule(for: child, venueId: venueId, editingRuleId: ruleId))
            }
        }
    }

    private var reviewStep: some View {
        VStack(spacing: 12) {
            onboardingCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Review & Finish")
                        .font(.system(size: 24, weight: .bold))
                    Text("\(state.scheduleTemplatesToCreate) schedules will generate runs when you tap Create Run.")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(state.scheduleTemplatesToCreate > 0 ? Color.primary : Color.orange)
                    Text("Children come first. Drivers support the routine you set.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Home: \(state.homeAddress)")
                        .font(.system(size: 14))
                    Divider()
                    ForEach(state.children) { child in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(child.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? child.name)
                                .font(.system(size: 15, weight: .semibold))
                            if let age = child.age {
                                Text("\(age) years old")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Text(child.schoolRoutineSummary)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text("Venues: \(child.venues.isEmpty ? "Not set" : "\(child.venues.count)")")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text("Rules: \(child.venueRules.count)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text("\(child.preferredDisplayName): \(child.isSetupComplete ? "\(scheduleCount(for: child)) schedules ready" : "Setup Required")")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(child.isSetupComplete ? Color.green.opacity(0.9) : .orange)
                        }
                    }
                    Text("Adults: \(state.adults.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map(\.name).joined(separator: ", "))")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }

            if state.scheduleTemplatesToCreate == 0 {
                HStack(alignment: .top, spacing: 10) {
                    Text("⚠")
                        .font(.system(size: 16))
                    Text("No schedules are ready yet. Add at least one child with venue and schedule rules.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            primaryButton("Finish Setup") {
                let didSaveSetup = state.finishOnboarding(into: flow.tribeStore)
                guard didSaveSetup else { return }
                presentSuccessMoment()
            }
            .disabled(!state.canFinish)
        }
    }

    private func onboardingCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(adaptiveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    private func onboardingChoiceCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            onboardingCard {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(red: 0.388, green: 0.400, blue: 0.945))
            .clipShape(Capsule())
            .shadow(color: Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.24), radius: 12, x: 0, y: 8)
    }

    private var primaryAdultBinding: Binding<Adult>? {
        guard !state.adults.isEmpty else { return nil }
        return Binding<Adult>(
            get: { state.adults[0] },
            set: { state.adults[0] = $0 }
        )
    }

    private var otherAdultIndices: [Int] {
        guard state.adults.count > 1 else { return [] }
        return Array(1..<state.adults.count)
    }

    private func roleChip(title: String, isSelected: Bool, action: @escaping () -> Void, isDisabled: Bool = false, trailingIcon: String? = nil) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color(red: 0.388, green: 0.400, blue: 0.945) : adaptiveChipBackground)
            .clipShape(Capsule())
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.75 : 1)
        .buttonStyle(.plain)
    }

    private func relationshipSection(for adult: Binding<Adult>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Relationship")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Optional label.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Adult.RelationshipTag.allCases, id: \.self) { tag in
                    roleChip(
                        title: tag.rawValue,
                        isSelected: adult.wrappedValue.relationshipTag == tag,
                        action: {
                            if adult.wrappedValue.relationshipTag == tag {
                                adult.relationshipTag.wrappedValue = nil
                            } else {
                                adult.relationshipTag.wrappedValue = tag
                            }
                        }
                    )
                }
            }
        }
    }

    private func accessSection(for adult: Binding<Adult>, isPrimaryAdmin: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Access")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Required.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Adult.AccessLevel.allCases, id: \.self) { level in
                    roleChip(
                        title: level.rawValue.capitalized,
                        isSelected: adult.wrappedValue.accessLevel == level,
                        action: {
                            guard !isPrimaryAdmin else { return }
                            adult.accessLevel.wrappedValue = level
                            if level == .observer {
                                adult.canDrive.wrappedValue = false
                            }
                        },
                        isDisabled: isPrimaryAdmin,
                        trailingIcon: (isPrimaryAdmin && level == .admin) ? "lock.fill" : nil
                    )
                }
            }
        }
    }

    private func driverCapabilitySection(for adult: Binding<Adult>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Driver capability")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Toggle("Can drive / execute runs", isOn: adult.canDrive)
                .font(.system(size: 13, weight: .semibold))
                .disabled(adult.wrappedValue.accessLevel == .observer)
                .onChange(of: adult.wrappedValue.accessLevel) { _, newValue in
                    if newValue == .observer {
                        adult.canDrive.wrappedValue = false
                    }
                }
        }
    }

    private func editableAdultAvatar(for adult: Binding<Adult>, fallbackName: String, size: MemberAvatarView.AvatarSize) -> some View {
        MemberAvatarView(
            member: MemberAvatarData(
                photoURL: adult.wrappedValue.avatar.photoURL,
                imageReference: adult.wrappedValue.avatar.imageReference,
                symbol: adult.wrappedValue.avatar.symbol,
                seed: adult.wrappedValue.avatar.seed,
                name: adult.wrappedValue.name.isEmpty ? fallbackName : adult.wrappedValue.name
            ),
            size: size,
            showCameraBadge: true,
            onTap: {
                activeAdultAvatarID = adult.wrappedValue.id
                avatarEditTarget = .adult(adult.wrappedValue.id)
                showingAdultAvatarActionSheet = true
            }
        )
    }

    private func weekdaySelector(weekdays: Binding<Set<OnboardingWeekday>>) -> some View {
        HStack(spacing: 8) {
            ForEach(OnboardingWeekday.calendarOrder, id: \.self) { day in
                let selected = weekdays.wrappedValue.contains(day)
                Button(day.rawValue) {
                    if selected {
                        weekdays.wrappedValue.remove(day)
                    } else {
                        weekdays.wrappedValue.insert(day)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? .white : .secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(selected ? Color(red: 0.388, green: 0.400, blue: 0.945) : adaptiveChipBackground)
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }
        }
    }

    private func weekdayPillsRow(weekdays: Binding<Set<OnboardingWeekday>>) -> some View {
        HStack(spacing: 8) {
            ForEach(OnboardingWeekday.calendarOrder, id: \.self) { day in
                let selected = weekdays.wrappedValue.contains(day)
                Button(shortDay(day)) {
                    if selected {
                        weekdays.wrappedValue.remove(day)
                    } else {
                        weekdays.wrappedValue.insert(day)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? .white : .secondary)
                .frame(width: 32, height: 32)
                .background(selected ? Color(red: 0.388, green: 0.400, blue: 0.945) : adaptiveChipBackground)
                .clipShape(Circle())
                .buttonStyle(.plain)
            }
        }
    }

    private func statusPill(title: String, icon: String, isPositive: Bool) -> some View {
        AppBadge(text: title, style: isPositive ? .success : .neutral, icon: icon)
    }

    private func formatTime(_ components: DateComponents) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    private func summaryText(for rule: VenueRule) -> String {
        let timeWindow: String
        switch rule.tripMode {
        case .roundTrip:
            let drop = rule.dropOffTime.map(formatTime) ?? "--"
            let pick = rule.pickupTime.map(formatTime) ?? "--"
            timeWindow = "\(drop) -> \(pick)"
        case .dropOffOnly:
            timeWindow = "Drop-off \(rule.dropOffTime.map(formatTime) ?? "--")"
        case .pickupOnly:
            timeWindow = "Pickup \(rule.pickupTime.map(formatTime) ?? "--")"
        }
        return "\(timeWindow) • \(rule.tripMode.rawValue)"
    }

    private func applySelectedAvatarSymbol(_ symbol: AvatarSymbol) {
        // A single chooser updates adult, child, or pending child draft based on context.
        switch avatarEditTarget {
        case .adult(let id):
            state.setAdultAvatarSymbol(id: id, symbol: symbol)
        case .child(let id):
            state.setChildAvatarSymbol(id: id, symbol: symbol)
        case .pendingChild:
            pendingChildAvatarSymbol = symbol
        case .none:
            pendingChildAvatarSymbol = symbol
        }
    }

    private var hasPhotoForAvatarTarget: Bool {
        switch avatarEditTarget {
        case .adult(let id):
            return state.adults.first(where: { $0.id == id })?.avatarURL != nil
        case .child(let id):
            return state.children.first(where: { $0.id == id })?.avatarURL != nil
        case .pendingChild, .none:
            return pendingChildPhotoURL != nil
        }
    }

    private func removePhotoForAvatarTarget() {
        switch avatarEditTarget {
        case .adult(let id):
            let existingReference = state.adults.first(where: { $0.id == id })?.avatarURL
            AvatarPhotoStore.deletePhoto(reference: existingReference)
            state.setAdultAvatarURL(id: id, photoURL: nil)
        case .child(let id):
            let existingReference = state.children.first(where: { $0.id == id })?.avatarURL
            AvatarPhotoStore.deletePhoto(reference: existingReference)
            state.setChildAvatarURL(id: id, photoURL: nil)
        case .pendingChild, .none:
            AvatarPhotoStore.deletePhoto(reference: pendingChildPhotoURL)
            pendingChildPhotoURL = nil
        }
    }

    private var pendingChildDateOfBirthBinding: Binding<Date> {
        Binding(
            get: {
                pendingChildDateOfBirth ?? Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date()
            },
            set: { newValue in
                if newValue <= Date() {
                    pendingChildDateOfBirth = newValue
                }
            }
        )
    }

    private func age(from dateOfBirth: Date) -> Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 0
    }

    private func shortDay(_ day: OnboardingWeekday) -> String {
        switch day {
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "Th"
        case .friday: return "F"
        case .saturday: return "Sa"
        case .sunday: return "Su"
        }
    }

    private func currentWeekday() -> OnboardingWeekday {
        switch Calendar.current.component(.weekday, from: Date()) {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        default: return .saturday
        }
    }

    private func timeBinding(for components: Binding<DateComponents>) -> Binding<Date> {
        Binding<Date>(
            get: { Calendar.current.date(from: components.wrappedValue) ?? Date() },
            set: { newDate in
                components.wrappedValue = Calendar.current.dateComponents([.hour, .minute], from: newDate)
            }
        )
    }

    private var selectedVenuePlace: Place? {
        guard let selected = venueSearchModel.selectedResult else { return nil }
        guard let latitude = selected.latitude, let longitude = selected.longitude else { return nil }
        return Place(
            name: selected.title,
            formattedAddress: selected.fullAddress,
            latitude: latitude,
            longitude: longitude,
            placeId: nil
        )
    }

    private var isVenueRuleValid: Bool {
        guard !venueWeekdays.isEmpty else { return false }
        switch tripModeSelection {
        case .roundTrip:
            guard let dh = venueDropOffTime.hour, let dm = venueDropOffTime.minute, let ph = venuePickupTime.hour, let pm = venuePickupTime.minute else { return false }
            return (ph * 60 + pm) > (dh * 60 + dm)
        case .dropOffOnly:
            return venueDropOffTime.hour != nil && venueDropOffTime.minute != nil
        case .pickupOnly:
            return venuePickupTime.hour != nil && venuePickupTime.minute != nil
        }
    }

    private var canSaveVenue: Bool {
        selectedVenuePlace != nil
    }

    private func overlappingWarnings(for child: OnboardingChildDraft, venueId: UUID, editingRuleId: UUID?) -> [String] {
        let existingRules = rulesForVenue(child: child, venueId: venueId).filter { $0.id != editingRuleId }
        var warnings: [String] = []

        for day in OnboardingWeekday.calendarOrder where venueWeekdays.contains(day) {
            let dayConflicts = existingRules.filter { $0.weekdays.contains(day) }
            guard !dayConflicts.isEmpty else { continue }

            let hasDifferentTimes = dayConflicts.contains { !ruleTimingEquals(existing: $0) }
            if hasDifferentTimes {
                warnings.append("Warning: \(day.rawValue) overlaps with another rule at different times.")
            } else {
                warnings.append("Warning: \(day.rawValue) overlaps with another rule.")
            }
        }

        return Array(Set(warnings)).sorted()
    }

    private var setupSuccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 70, height: 70)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(Color.green)
                }
                .accessibilityHidden(true)

                Text("Setup complete. Your schedules are ready.")
                    .font(.system(size: 17, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button("View Calendar") {
                        completeSetupFromSuccessMoment(openTab: .calendar)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.10))
                    .clipShape(Capsule())

                    Button("Go to Home") {
                        completeSetupFromSuccessMoment(openTab: .home)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.388, green: 0.400, blue: 0.945))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
            .background(adaptiveCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 26)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Setup complete. Your schedules are ready.")
            .accessibilityHint("Double-tap View Calendar or Go to Home.")
        }
    }

    private func presentSuccessMoment() {
        withAnimation(.easeInOut(duration: 0.18)) {
            showingSetupSuccessMoment = true
        }
        UIAccessibility.post(notification: .announcement, argument: "Setup complete. Your schedules are ready.")
    }

    private func completeSetupFromSuccessMoment(openTab: AppTab) {
        withAnimation(.easeInOut(duration: 0.18)) {
            showingSetupSuccessMoment = false
        }
        flow.completeOnboarding(startingTab: openTab)
    }

    private func scheduleCount(for child: OnboardingChildDraft) -> Int {
        child.venueRules
            .filter(\.isValid)
            .reduce(0) { count, rule in
                count + ((rule.tripMode == .roundTrip) ? 2 : 1)
            }
    }

    private var pendingChildSchoolStartBinding: Binding<Date> {
        Binding(
            get: {
                let fallback = DateComponents(hour: 7, minute: 45)
                return Calendar.current.date(from: pendingChildSchoolStartTime ?? fallback) ?? Date()
            },
            set: { pendingChildSchoolStartTime = Calendar.current.dateComponents([.hour, .minute], from: $0) }
        )
    }

    private var pendingChildSchoolEndBinding: Binding<Date> {
        Binding(
            get: {
                let fallback = DateComponents(hour: 13, minute: 45)
                return Calendar.current.date(from: pendingChildSchoolEndTime ?? fallback) ?? Date()
            },
            set: { pendingChildSchoolEndTime = Calendar.current.dateComponents([.hour, .minute], from: $0) }
        )
    }

    private var pendingChildSchoolDaysPicker: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases, id: \.self) { day in
                let selected = pendingChildSchoolDays.contains(day)
                Button(day.shortLabel) {
                    if selected {
                        pendingChildSchoolDays.remove(day)
                    } else {
                        pendingChildSchoolDays.insert(day)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? .white : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selected ? Color(red: 0.388, green: 0.400, blue: 0.945) : Color(uiColor: .tertiarySystemBackground))
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }
        }
    }

    private func hasDuplicateRule(for child: OnboardingChildDraft, venueId: UUID, editingRuleId: UUID?) -> Bool {
        let existingRules = rulesForVenue(child: child, venueId: venueId).filter { $0.id != editingRuleId }
        return existingRules.contains { existing in
            existing.tripMode == tripModeSelection &&
            existing.weekdays == venueWeekdays &&
            ruleTimingEquals(existing: existing)
        }
    }

    private func ruleTimingEquals(existing: VenueRule) -> Bool {
        switch tripModeSelection {
        case .roundTrip:
            return existing.dropOffTime == venueDropOffTime && existing.pickupTime == venuePickupTime
        case .dropOffOnly:
            return existing.dropOffTime == venueDropOffTime
        case .pickupOnly:
            return existing.pickupTime == venuePickupTime
        }
    }

    private func rulesForVenue(child: OnboardingChildDraft, venueId: UUID) -> [VenueRule] {
        guard let venue = child.venues.first(where: { $0.id == venueId }) else {
            return child.venueRules.filter { $0.venueId == venueId }
        }
        let venueRuleIds = Set(venue.ruleIds)
        if venueRuleIds.isEmpty {
            return child.venueRules.filter { $0.venueId == venueId }
        }
        return child.venueRules.filter { $0.venueId == venueId && venueRuleIds.contains($0.id) }
    }

    private var setupRequiredPill: some View {
        AppBadge.setupRequired
    }

    private var addChildSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                Text("Add Child")
                    .font(.system(size: 24, weight: .bold))
                Button {
                    avatarEditTarget = .pendingChild
                    showingPendingChildAvatarOptions = true
                } label: {
                    VStack(spacing: 10) {
                        MemberAvatarView(
                            member: MemberAvatarData(
                                photoURL: pendingChildPhotoURL,
                                imageReference: pendingChildAvatarSymbol?.rawValue,
                                symbol: pendingChildAvatarSymbol,
                                seed: "pending-child-avatar",
                                name: pendingChildName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Child" : pendingChildName
                            ),
                            size: 104,
                            showCameraBadge: true
                        )
                        Text("Tap avatar to choose")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Basic Info")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    onboardingInputField("Child name", text: $pendingChildName, field: .childName)
                    onboardingInputField("Preferred display name (optional)", text: $pendingChildDisplayName, field: .childDisplayName)
                    onboardingInputField("Grade/Class (optional)", text: $pendingChildGradeOrClass, field: .childGrade)
                    DatePicker(
                        "Date of birth (optional)",
                        selection: pendingChildDateOfBirthBinding,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)

                    if let pendingChildDateOfBirth {
                        Text("\(age(from: pendingChildDateOfBirth)) years old")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("School Info")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    onboardingInputField("School name (optional)", text: $pendingChildSchoolName, field: .childSchoolName)
                    LocationSearchField(
                        title: "School Search",
                        placeholder: "Search school",
                        model: pendingChildSchoolSearchModel,
                        onSelected: { result in
                            if pendingChildSchoolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                pendingChildSchoolName = result.title
                            }
                            pendingChildSchoolAddress = result.fullAddress
                        },
                        onCleared: { }
                    )
                    onboardingInputField("School address (optional)", text: $pendingChildSchoolAddress, field: .childSchoolAddress)
                    Text("School routine (optional)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    pendingChildSchoolDaysPicker
                    DatePicker(
                        "School start time",
                        selection: pendingChildSchoolStartBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                    DatePicker(
                        "School end time",
                        selection: pendingChildSchoolEndBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                    Text("Adding your child's school helps Tribeboard plan runs and schedules.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Button("Save Child") {
                    state.addChild(
                        id: pendingChildID,
                        name: pendingChildName,
                        displayName: pendingChildDisplayName.nilIfEmpty,
                        dateOfBirth: pendingChildDateOfBirth,
                        schoolName: pendingChildSchoolName.nilIfEmpty,
                        schoolAddress: pendingChildSchoolAddress.nilIfEmpty,
                        gradeOrClass: pendingChildGradeOrClass.nilIfEmpty,
                        schoolStartTime: pendingChildSchoolStartTime,
                        schoolEndTime: pendingChildSchoolEndTime,
                        schoolDays: pendingChildSchoolDays.isEmpty ? nil : pendingChildSchoolDays,
                        avatarImageName: pendingChildAvatarSymbol?.rawValue ?? "",
                        avatarURL: pendingChildPhotoURL,
                        avatarId: pendingChildAvatarSymbol?.rawValue,
                        avatarSymbol: pendingChildAvatarSymbol
                    )
                    pendingChildName = ""
                    pendingChildDisplayName = ""
                    pendingChildID = UUID()
                    pendingChildDateOfBirth = nil
                    pendingChildSchoolName = ""
                    pendingChildSchoolAddress = ""
                    pendingChildGradeOrClass = ""
                    pendingChildSchoolDays = [.monday, .tuesday, .wednesday, .thursday, .friday]
                    pendingChildSchoolStartTime = nil
                    pendingChildSchoolEndTime = nil
                    pendingChildPhotoURL = nil
                    pendingChildAvatarSymbol = nil
                    showingAddChildSheet = false
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(red: 0.388, green: 0.400, blue: 0.945))
                .clipShape(Capsule())
                .disabled(pendingChildName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(pendingChildName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1)

                Spacer(minLength: 0)
            }
            .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func onboardingInputField(_ title: String, text: Binding<String>, field: Field) -> some View {
        TextField(title, text: text)
            .focused($focusedField, equals: field)
            .foregroundStyle(.primary)
            .tint(Color(red: 0.388, green: 0.400, blue: 0.945))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(adaptiveFieldBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        focusedField == field ? Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.7) : adaptiveBorder,
                        lineWidth: focusedField == field ? 1.5 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    OnboardingFlowView()
        .environmentObject(AppFlowState())
}
