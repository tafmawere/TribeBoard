import CoreLocation
import SwiftUI

struct FamilyLocationsSectionView: View {
    @EnvironmentObject private var backendHouseholdLocationsContext: BackendHouseholdLocationsContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext

    @State private var isShowingAddLocation = false
    @State private var editingLocation: BackendHouseholdLocation?
    @State private var schoolLinkChild: BackendChild?

    private let sectionTypes: [HouseholdLocationType] = [.home, .school, .activity, .pickup, .custom]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(
                title: "Family Locations",
                actionTitle: backendHouseholdContext.canManageMembers ? "Add" : nil,
                action: backendHouseholdContext.canManageMembers ? { isShowingAddLocation = true } : nil
            )

            if backendHouseholdLocationsContext.isLoading && backendHouseholdLocationsContext.locations.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else if backendHouseholdLocationsContext.locations.isEmpty,
                      let loadError = backendHouseholdLocationsContext.lastError,
                      !loadError.isEmpty,
                      !isCancellationMessage(loadError) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loadError)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await backendHouseholdLocationsContext.refreshForActiveHousehold() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TribeTheme.primary)
                }
                .padding(.vertical, 4)
            } else if backendHouseholdLocationsContext.locations.isEmpty {
                Text("No family locations yet. Add home, school, or pickup places to reuse them on runs.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sectionTypes, id: \.self) { type in
                    locationGroup(type)
                }

                schoolLinkPrompts
            }
        }
        .sheet(isPresented: $isShowingAddLocation) {
            NavigationStack {
                AddEditHouseholdLocationView()
            }
        }
        .sheet(item: $editingLocation) { location in
            NavigationStack {
                AddEditHouseholdLocationView(existing: location)
            }
        }
        .sheet(item: $schoolLinkChild) { child in
            NavigationStack {
                AddEditHouseholdLocationView(
                    prefilledDraft: HouseholdLocationDraft(
                        name: child.schoolName ?? child.displayName ?? child.legalName,
                        label: child.schoolName ?? "School",
                        locationType: .school
                    ),
                    linkSchoolChildId: child.id
                )
            }
        }
        .task {
            await backendHouseholdLocationsContext.refreshForActiveHousehold()
        }
    }

    @ViewBuilder
    private func locationGroup(_ type: HouseholdLocationType) -> some View {
        let rows = backendHouseholdLocationsContext.locations(ofType: type)
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(type.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                ForEach(rows) { location in
                    HouseholdLocationCard(location: location) {
                        editingLocation = location
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var schoolLinkPrompts: some View {
        let childrenNeedingSchool = backendChildrenContext.children.filter { child in
            let hasSchoolName = !(child.schoolName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            return hasSchoolName && child.schoolLocationId == nil
        }
        if !childrenNeedingSchool.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("School addresses needed")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.orange)
                ForEach(childrenNeedingSchool) { child in
                    let name = child.displayName?.nilIfEmpty ?? child.legalName
                    Button {
                        schoolLinkChild = child
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(name): School address missing")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text("Add school address for \(child.schoolName ?? "school")")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Add")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(TribeTheme.primary)
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct HouseholdLocationCard: View {
    let location: BackendHouseholdLocation
    var onTap: () -> Void

    private var readinessColor: Color {
        switch location.readiness {
        case .complete: return .green
        case .missingAddress, .missingPin: return .orange
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: location.locationType.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TribeTheme.primary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(location.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    if !location.formattedAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(location.formattedAddress)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Text(location.readiness.label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(readinessColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(readinessColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct AddEditHouseholdLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var backendHouseholdLocationsContext: BackendHouseholdLocationsContext
    @EnvironmentObject private var backendChildrenContext: BackendChildrenContext
    @EnvironmentObject private var backendHouseholdContext: BackendHouseholdContext

    let existing: BackendHouseholdLocation?
    let prefilledDraft: HouseholdLocationDraft?
    let linkSchoolChildId: UUID?

    @State private var draft: HouseholdLocationDraft
    @State private var showAdvancedCoordinates = false
    @State private var manualLatitude = ""
    @State private var manualLongitude = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @StateObject private var searchModel = LocationSearchModel(mode: .runStopSearch)
    @State private var mapRegion = CoordinateRegionDegrees(
        center: CLLocationCoordinate2D(latitude: -26.1076, longitude: 28.0567),
        latitudeDelta: 0.03,
        longitudeDelta: 0.03
    )

    init(
        existing: BackendHouseholdLocation? = nil,
        prefilledDraft: HouseholdLocationDraft? = nil,
        linkSchoolChildId: UUID? = nil
    ) {
        self.existing = existing
        self.prefilledDraft = prefilledDraft
        self.linkSchoolChildId = linkSchoolChildId
        let initial = prefilledDraft ?? (existing.map(HouseholdLocationDraft.init) ?? HouseholdLocationDraft(name: ""))
        _draft = State(initialValue: initial)
        _manualLatitude = State(initialValue: initial.latitude.map { String($0) } ?? "")
        _manualLongitude = State(initialValue: initial.longitude.map { String($0) } ?? "")
    }

    private var navTitle: String {
        if existing != nil { return "Edit Location" }
        if linkSchoolChildId != nil { return "Add School Address" }
        return "Add Location"
    }

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $draft.name)
                Picker("Type", selection: $draft.locationType) {
                    ForEach(HouseholdLocationType.allCases) { type in
                        Text(type.singularTitle).tag(type)
                    }
                }
            }

            Section("Address") {
                LocationSearchField(
                    title: "Search address",
                    placeholder: "Search for address or place",
                    model: searchModel,
                    onSelected: { result in
                        draft.formattedAddress = result.fullAddress
                        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            draft.name = result.title
                        }
                        draft.label = draft.name
                        draft.placeId = result.placeId
                        draft.latitude = result.latitude
                        draft.longitude = result.longitude
                        manualLatitude = result.latitude.map { String($0) } ?? ""
                        manualLongitude = result.longitude.map { String($0) } ?? ""
                        if let lat = result.latitude, let lon = result.longitude {
                            mapRegion = CoordinateRegionDegrees(
                                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                latitudeDelta: 0.012,
                                longitudeDelta: 0.012
                            )
                        }
                    },
                    onCleared: {
                        draft.formattedAddress = ""
                        draft.latitude = nil
                        draft.longitude = nil
                        manualLatitude = ""
                        manualLongitude = ""
                    }
                )
                TextField("Formatted address", text: $draft.formattedAddress, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Map preview") {
                locationMapPreview
            }

            #if DEBUG
            Section("Advanced") {
                Toggle("Manual coordinates", isOn: $showAdvancedCoordinates)
                if showAdvancedCoordinates {
                    TextField("Latitude", text: $manualLatitude)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Longitude", text: $manualLongitude)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            #endif
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "Saving..." : "Save") {
                    Task { await save() }
                }
                .disabled(isSaving || !canSave)
            }
        }
        .onAppear {
            if !draft.formattedAddress.isEmpty {
                searchModel.applySelectedAddress(draft.formattedAddress)
            }
            if let lat = draft.latitude, let lon = draft.longitude {
                mapRegion = CoordinateRegionDegrees(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    latitudeDelta: 0.012,
                    longitudeDelta: 0.012
                )
            }
        }
        .alert("Unable to Save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Save failed.")
        }
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !draft.formattedAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var locationMapPreview: some View {
        let pin: GoogleMapMarkerModel? = {
            guard let lat = draft.latitude, let lon = draft.longitude else { return nil }
            return GoogleMapMarkerModel(
                id: draft.id,
                title: draft.name,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                kind: .generic,
                orderLabel: nil,
                isSelected: true
            )
        }()
        return TribeGoogleMapView(
            markers: pin.map { [$0] } ?? [],
            polylineCoordinates: [],
            strokeUIColor: .clear,
            lineWidth: 0,
            cameraHint: mapRegion,
            externalCamera: nil,
            showsUserLocation: false,
            padding: .init(top: 8, left: 8, bottom: 8, right: 8),
            onMarkerIdTap: nil
        )
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @MainActor
    private func save() async {
        if showAdvancedCoordinates {
            if let lat = Double(manualLatitude.trimmingCharacters(in: .whitespacesAndNewlines)),
               let lon = Double(manualLongitude.trimmingCharacters(in: .whitespacesAndNewlines)) {
                draft.latitude = lat
                draft.longitude = lon
            }
        }
        if draft.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.label = draft.name
        }
        isSaving = true
        defer { isSaving = false }

        guard let saved = await backendHouseholdLocationsContext.saveLocation(
            draft: draft,
            existingId: existing?.id
        ) else {
            saveError = backendHouseholdLocationsContext.lastError ?? "Unable to save location."
            return
        }

        if let childId = linkSchoolChildId,
           var child = backendChildrenContext.children.first(where: { $0.id == childId }) {
            child.schoolLocationId = saved.id
            if child.schoolName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                child.schoolName = saved.displayName
            }
            await backendChildrenContext.updateChildSchoolLocation(child)
        }

        dismiss()
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
