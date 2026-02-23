import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject var flow: AppFlowState
    @StateObject private var state = OnboardingState()
    @StateObject private var tribeStore = TribeStore()

    var body: some View {
        ZStack {
            Color(red: 0.976, green: 0.980, blue: 0.984)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                header

                Group {
                    switch state.step {
                    case .chooseMode:
                        OnboardingScreens.ChooseTribeModeView(state: state)
                    case .createTribe:
                        CreateTribeView(store: tribeStore) {
                            state.step = .addMembers
                        }
                    case .joinTribe:
                        OnboardingScreens.JoinTribeView(state: state)
                    case .addMembers:
                        AddMembersView(store: tribeStore) {
                            state.continueFromMembers()
                        }
                        .onAppear {
                            if tribeStore.tribe == nil {
                                let fallbackName = state.tribeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? "Joined Family"
                                    : state.tribeName
                                let invite = state.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
                                tribeStore.createTribe(
                                    name: fallbackName,
                                    tribeCode: invite.isEmpty ? nil : invite
                                )
                            }
                        }
                    case .permissions:
                        OnboardingScreens.PermissionsSetupView(
                            state: state,
                            kidsCount: tribeStore.children().count,
                            driversCount: tribeStore.members.filter { $0.roles.contains(.driver) }.count
                        )
                    case .firstSchedule:
                        ScheduleEditorView(mode: .create, isOnboardingContext: true) { _ in
                            flow.completeOnboarding()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }

    private var header: some View {
        HStack {
            if state.step != .chooseMode {
                Button {
                    state.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Spacer()
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Text(state.step.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.primary)

            Spacer()

            Spacer()
                .frame(width: 36, height: 36)
        }
    }
}

private enum OnboardingScreens {
    struct ChooseTribeModeView: View {
        @ObservedObject var state: OnboardingState

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text("Let's set up your family")
                        .font(.system(size: 32, weight: .bold))

                    Text("Start by creating a family or joining one with an invite code.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 20)

                    ActionTile(
                        icon: "house.fill",
                        title: "Create Family",
                        subtitle: "Start a new family group for your household."
                    ) {
                        state.goToCreateTribe()
                    }

                    ActionTile(
                        icon: "link",
                        title: "Join Family",
                        subtitle: "Use an invite code to join an existing family."
                    ) {
                        state.goToJoinTribe()
                    }
                }
                .padding(.bottom, 12)
            }
        }
    }

    struct CreateTribeView: View {
        @ObservedObject var state: OnboardingState

        var body: some View {
            VStack(spacing: 16) {
                OnboardingCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Create your family")
                            .font(.system(size: 30, weight: .bold))
                        Text("Give your family group a name you can all recognize.")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)

                        TextField("Family name", text: $state.tribeName)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Button("Continue") {
                    state.continueFromCreateTribe()
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .disabled(state.tribeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
        }
    }

    struct JoinTribeView: View {
        @ObservedObject var state: OnboardingState

        var body: some View {
            VStack(spacing: 16) {
                OnboardingCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Join a family")
                            .font(.system(size: 30, weight: .bold))
                        Text("Enter the invite code shared with you.")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)

                        TextField("Invite code", text: $state.inviteCode)
                            .textInputAutocapitalization(.characters)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Button("Continue") {
                    state.continueFromJoinTribe()
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .disabled(state.inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
        }
    }

    struct AddMembersView: View {
        @ObservedObject var state: OnboardingState

        var body: some View {
            VStack(spacing: 16) {
                OnboardingCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add members")
                            .font(.system(size: 30, weight: .bold))
                        Text("Add kid names and an optional driver.")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 10) {
                            ForEach(Array(state.kidNames.enumerated()), id: \.offset) { index, _ in
                                HStack {
                                    TextField("Kid name", text: $state.kidNames[index])
                                        .textFieldStyle(.roundedBorder)

                                    Button {
                                        state.removeKidRow(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Button {
                            state.addKidRow()
                        } label: {
                            Label("Add another kid", systemImage: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                        }
                        .buttonStyle(.plain)

                        TextField("Driver name (optional)", text: $state.driverName)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Button("Continue") {
                    state.continueFromMembers()
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())

                Spacer()
            }
        }
    }

    struct PermissionsSetupView: View {
        @ObservedObject var state: OnboardingState
        let kidsCount: Int
        let driversCount: Int
        @State private var isShowingLearnMore = false

        var body: some View {
            ZStack {
                Color(red: 0.976, green: 0.980, blue: 0.984)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Privacy & safety")
                            .font(.system(size: 32, weight: .bold))

                        Text("TribeBoard shares location only during active runs — never continuously. You stay in control.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.secondary)

                        SettingCard {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Location sharing")
                                        .font(.system(size: 17, weight: .semibold))
                                    Text(driversCount == 0 ? "Allow trusted adults to see location updates during runs." : "Allow trusted adults to see driver progress during runs.")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(.secondary)

                                    Button("Learn how this works \u{2192}") {
                                        isShowingLearnMore = true
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                                    .buttonStyle(.plain)
                                }

                                Spacer(minLength: 8)

                                Toggle("", isOn: $state.locationSharingEnabled)
                                    .labelsHidden()
                                    .accessibilityLabel("Location sharing")
                                    .tint(Color(red: 0.388, green: 0.400, blue: 0.945))
                            }
                        }

                        if kidsCount > 0 {
                            SettingCard {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "shield.lefthalf.filled")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))

                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Text("Kids tracking consent")
                                                .font(.system(size: 17, weight: .semibold))
                                            Text("Recommended")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.12))
                                                .clipShape(Capsule())
                                        }

                                        Text("Enable tracking for kids during active runs only.")
                                            .font(.system(size: 14, weight: .regular))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer(minLength: 8)

                                    Toggle("", isOn: $state.kidsTrackingConsent)
                                        .labelsHidden()
                                        .accessibilityLabel("Kids tracking consent")
                                        .tint(Color(red: 0.388, green: 0.400, blue: 0.945))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Continue") {
                    state.continueFromPermissions()
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(Color(red: 0.976, green: 0.980, blue: 0.984).ignoresSafeArea())
            }
            .sheet(isPresented: $isShowingLearnMore) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("How location sharing works")
                        .font(.system(size: 24, weight: .bold))
                    Group {
                        Text("• Location is shared only during active runs")
                        Text("• Who can see it depends on roles (Parent/Guardian/Admin/Observer)")
                        Text("• You can turn it off anytime")
                    }
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(20)
                .presentationDetents([.medium, .large])
            }
        }
    }

    struct CreateFirstScheduleView: View {
        @ObservedObject var state: OnboardingState
        let onFinish: () -> Void

        var body: some View {
            VStack(spacing: 16) {
                OnboardingCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Create first schedule")
                            .font(.system(size: 30, weight: .bold))
                        Text("Set your default school run times and weekdays.")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)

                        DatePicker("Dropoff time", selection: $state.dropoffTime, displayedComponents: .hourAndMinute)
                        DatePicker("Pickup time", selection: $state.pickupTime, displayedComponents: .hourAndMinute)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Weekdays")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)

                            FlexibleDayRow(days: Weekday.allCases, selected: state.selectedWeekdays) { day in
                                state.toggleWeekday(day)
                            }
                        }
                    }
                }

                Button("Finish Setup") {
                    onFinish()
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())

                Spacer()
            }
        }
    }
}

private struct OnboardingCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
    }
}

private struct SettingCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 3)
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(red: 0.388, green: 0.400, blue: 0.945))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .shadow(color: Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.24), radius: 12, x: 0, y: 8)
    }
}

private struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white)
            .overlay {
                Capsule(style: .continuous)
                    .stroke(Color.black.opacity(0.10), lineWidth: 1)
            }
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

private struct FlexibleDayRow: View {
    let days: [Weekday]
    let selected: Set<Weekday>
    let onTap: (Weekday) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.self) { day in
                let isSelected = selected.contains(day)
                Button(day.rawValue) {
                    onTap(day)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : Color(red: 0.24, green: 0.28, blue: 0.34))
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(isSelected ? Color(red: 0.388, green: 0.400, blue: 0.945) : Color.black.opacity(0.06))
                .clipShape(Capsule(style: .continuous))
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ActionTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))

                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(ActionTileButtonStyle())
    }
}

private struct ActionTileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

#Preview {
    OnboardingFlowView()
        .environmentObject(AppFlowState())
}
