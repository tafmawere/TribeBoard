import SwiftUI
import MapKit

// MARK: - Shared chrome

struct OnboardingFlowStepHeader: View {
    let heading: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(OnboardingTheme.headlineNavy)
            Text(bodyText)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OnboardingStyledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isOptional: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.headlineNavy)
                if isOptional {
                    Text("(optional)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(OnboardingTheme.brandPurple.opacity(0.15), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

struct OnboardingElevatedCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(OnboardingTheme.brandPurple.opacity(0.1), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }
}

// MARK: - Profile

struct OnboardingCreateProfileStep: View {
    @Binding var profile: OnboardingProfileDraft
    let accessToken: String
    let userId: UUID?
    @State private var showingAvatarPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingFlowStepHeader(
                heading: "Let's get to know you",
                bodyText: "This is how you'll appear to your family."
            )

            VStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    TribeAvatarView(identity: profile.avatarIdentity, size: .hero)
                    Button {
                        showingAvatarPicker = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(OnboardingTheme.brandPurple)
                            .clipShape(Circle())
                            .overlay {
                                Circle().strokeBorder(Color.white, lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                    .offset(x: 4, y: 4)
                }
                .frame(maxWidth: .infinity)
                .onTapGesture { showingAvatarPicker = true }

                OnboardingElevatedCard {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(OnboardingTheme.brandPurple)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Choose an avatar now.")
                                .font(.system(size: 14, weight: .semibold))
                            Text("You can change it later.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            VStack(spacing: 14) {
                OnboardingStyledTextField(label: "First name", placeholder: "First name", text: $profile.firstName)
                OnboardingStyledTextField(label: "Last name", placeholder: "Last name", text: $profile.lastName)
                OnboardingStyledTextField(
                    label: "Display name",
                    placeholder: "Display name",
                    text: $profile.displayName,
                    isOptional: true
                )
            }

            Text("This is how your name will appear in your tribe.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showingAvatarPicker) {
            if let userId, !accessToken.isEmpty {
                NavigationStack {
                    AvatarPickerView(
                        subjectKind: .profile(userId),
                        displayName: profile.resolvedDisplayName,
                        initialIdentity: profile.avatarIdentity,
                        accessToken: accessToken
                    ) { saved in
                        profile.avatarType = saved.avatarType
                        profile.avatarKey = saved.avatarKey
                        profile.avatarURL = saved.avatarURL
                    }
                }
            }
        }
    }
}

// MARK: - Create family

struct OnboardingCreateFamilyStep: View {
    @Binding var familyName: String
    let lastName: String
    let firstChildName: String?
    let userAvatar: TribeAvatarIdentity

    private var suggestions: [FamilyNameSuggestion] {
        var items: [FamilyNameSuggestion] = []
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLast.isEmpty {
            items.append(FamilyNameSuggestion(icon: "person.3.fill", title: "\(trimmedLast) Family"))
            items.append(FamilyNameSuggestion(icon: "heart.fill", title: "The \(trimmedLast)s"))
        }
        if let child = firstChildName?.trimmingCharacters(in: .whitespacesAndNewlines), !child.isEmpty {
            items.append(FamilyNameSuggestion(icon: "star.fill", title: "\(child) Crew"))
        }
        return items
    }

    private var isValid: Bool {
        !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingFlowStepHeader(
                heading: "Create your family",
                bodyText: "What should everyone call this family?"
            )

            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(suggestions) { suggestion in
                            Button {
                                familyName = suggestion.title
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: suggestion.icon)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(suggestion.title)
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(OnboardingTheme.brandPurple)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(OnboardingTheme.brandPurple.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Family name")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.headlineNavy)
                HStack {
                    TextField("Family name", text: $familyName)
                        .textInputAutocapitalization(.words)
                    if isValid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isValid ? Color.green.opacity(0.45) : OnboardingTheme.brandPurple.opacity(0.15),
                            lineWidth: 1
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            OnboardingElevatedCard {
                Text("Your family will appear as:")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(OnboardingTheme.brandPurple.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Image(systemName: "house.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(OnboardingTheme.brandPurple)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isValid ? familyName : "Your family name")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(OnboardingTheme.headlineNavy)
                        HStack(spacing: -8) {
                            TribeAvatarView(identity: userAvatar, size: .small)
                            placeholderAvatar
                            placeholderAvatar
                            ZStack {
                                Circle()
                                    .fill(OnboardingTheme.brandPurple.opacity(0.12))
                                    .frame(width: 34, height: 34)
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(OnboardingTheme.brandPurple)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var placeholderAvatar: some View {
        Circle()
            .fill(Color(uiColor: .tertiarySystemFill))
            .frame(width: 34, height: 34)
            .overlay {
                Circle().strokeBorder(Color.white, lineWidth: 2)
            }
    }
}

private struct FamilyNameSuggestion: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
}

// MARK: - Home location

struct OnboardingCreateHomeStep: View {
    @Binding var selectedLocation: ResolvedLocationDraft?
    @Binding var phase: OnboardingHomeLocationPhase
    @StateObject private var locationModel = LocationSearchModel()
    @State private var showManualEntry = false
    @State private var manualAddress = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if phase == .confirm, let location = selectedLocation {
                confirmView(location: location)
            } else {
                searchView
            }
        }
        .onAppear {
            if let selectedLocation {
                locationModel.applySelectedAddress(selectedLocation.address)
            }
        }
    }

    private var searchView: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingFlowStepHeader(
                heading: "Where is home?",
                bodyText: "Search and select your home so pickups can be routed correctly."
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Home address")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.headlineNavy)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search home address", text: Binding(
                        get: { locationModel.query },
                        set: { locationModel.setQuery($0) }
                    ))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                    if !locationModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            locationModel.clearSelection()
                            selectedLocation = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(OnboardingTheme.brandPurple.opacity(0.15), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !locationModel.results.isEmpty {
                OnboardingElevatedCard {
                    VStack(spacing: 0) {
                        ForEach(locationModel.results) { result in
                            Button {
                                Task {
                                    let resolved = await locationModel.selectResult(result)
                                    applySelection(resolved)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            if result.id != locationModel.results.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            } else if locationModel.noMatchesFound {
                Text("No matches found")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Button {
                showManualEntry = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Enter address manually")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(OnboardingTheme.brandPurple)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showManualEntry) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Manual addresses still need map confirmation before saving.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    TextField("Full address", text: $manualAddress, axis: .vertical)
                        .lineLimit(3...5)
                        .padding(12)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Spacer()
                }
                .padding(20)
                .navigationTitle("Manual address")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showManualEntry = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use") {
                            let trimmed = manualAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            locationModel.applySelectedAddress(trimmed)
                            locationModel.setQuery(trimmed)
                            showManualEntry = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    private func confirmView(location: ResolvedLocationDraft) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingFlowStepHeader(
                heading: "Home location",
                bodyText: "Please confirm this is your home."
            )

            OnboardingHomeMapPreview(
                latitude: location.latitude ?? 0,
                longitude: location.longitude ?? 0
            )
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            OnboardingElevatedCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.brandPurple)
                    Text(location.address)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(OnboardingTheme.headlineNavy)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("Verified location selected")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.green)
            }

            Button("Change address") {
                phase = .search
                locationModel.clearSelection()
                selectedLocation = nil
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(OnboardingTheme.brandPurple)
            .buttonStyle(.plain)
        }
    }

    private func applySelection(_ result: LocationSearchResult) {
        guard let latitude = result.latitude, let longitude = result.longitude else { return }
        selectedLocation = ResolvedLocationDraft(
            title: result.title,
            address: result.fullAddress,
            latitude: latitude,
            longitude: longitude,
            placeId: result.placeId
        )
        phase = .confirm
    }
}

struct OnboardingHomeMapPreview: View {
    let latitude: Double
    let longitude: Double

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            if latitude != 0 || longitude != 0 {
                Marker("Home", coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                    .tint(OnboardingTheme.brandPurple)
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .allowsHitTesting(false)
        .onAppear {
            if latitude != 0 || longitude != 0 {
                position = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
            }
        }
    }
}

// MARK: - Next up

struct OnboardingNextUpStep: View {
    let familyName: String
    let onAddChild: () -> Void

    private let checklist = [
        "Add children",
        "Add school run",
        "Invite driver or guardian",
        "Add emergency contacts"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingFlowStepHeader(
                heading: "You're ready to start",
                bodyText: "Your family is set up. You can now add children, school runs, drivers and activities."
            )

            if !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(familyName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.brandPurple)
            }

            VStack(spacing: 10) {
                ForEach(checklist, id: \.self) { item in
                    OnboardingElevatedCard {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(OnboardingTheme.brandPurple.opacity(0.55))
                            Text(item)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(OnboardingTheme.headlineNavy)
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(OnboardingTheme.brandPurple.opacity(0.6))
                        }
                    }
                }
            }

            Button(action: onAddChild) {
                Text("Add child now")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.brandPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(OnboardingTheme.brandPurple.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
