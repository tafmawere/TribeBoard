import CoreLocation
import SwiftUI

/// Payload for a stop after the user picks a search result. Google Places is used to resolve search; map UI uses Google Maps SDK.
struct StopLocationSelection: Equatable {
    var placeId: String?
    var placeName: String
    var formattedAddress: String
    var latitude: Double?
    var longitude: Double?
    var householdLocationId: UUID?
    /// `"google"` when resolved via Google Places; optional for legacy persisted shortcuts.
    var provider: String?

    var coordinate: CLLocationCoordinate2D? {
        guard let la = latitude, let lo = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: la, longitude: lo)
    }

    static func from(_ result: LocationSearchResult) -> StopLocationSelection {
        StopLocationSelection(
            placeId: result.placeId,
            placeName: result.title,
            formattedAddress: result.fullAddress,
            latitude: result.latitude,
            longitude: result.longitude,
            provider: "google"
        )
    }
}

/// In-app location picker: TribeBoard UI; Google Places autocomplete. Native Google Maps for other surfaces.
struct StopAddressSearchSheet: View {
    @EnvironmentObject private var locationService: LocationReadinessService
    @EnvironmentObject private var familyPlaces: FamilyQuickPlacesStore
    @EnvironmentObject private var backendHouseholdLocationsContext: BackendHouseholdLocationsContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchModel = LocationSearchModel(mode: .runStopSearch)
    @FocusState private var searchFieldFocused: Bool
    @State private var savePlaceNameField = ""

    /// Resolved coordinates for the stop being edited (lets the family save shortcuts without a new search).
    let resolvedSnapshot: StopLocationSelection?

    let onSelect: (StopLocationSelection) -> Void
    var onCancel: (() -> Void)?

    private var snapshotHasCoordinates: Bool {
        guard let s = resolvedSnapshot else { return false }
        return s.latitude != nil && s.longitude != nil
    }

    // MARK: - De-duplication (household locations win over saved/recent places)

    /// Identity keys for a place: Google placeId, normalized address, and rounded coordinates.
    /// A place is a duplicate if any key matches an already-listed place.
    private static func placeKeys(
        placeId: String?,
        address: String?,
        latitude: Double?,
        longitude: Double?
    ) -> Set<String> {
        var keys = Set<String>()
        if let placeId = placeId?.trimmingCharacters(in: .whitespacesAndNewlines), !placeId.isEmpty {
            keys.insert("pid:\(placeId)")
        }
        if let address, let normalized = normalizedAddressKey(address) {
            keys.insert("addr:\(normalized)")
        }
        if let latitude, let longitude {
            keys.insert(String(format: "geo:%.4f,%.4f", latitude, longitude))
        }
        return keys
    }

    private static func normalizedAddressKey(_ address: String) -> String? {
        let scalars = address.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let key = String(String.UnicodeScalarView(scalars))
        return key.isEmpty ? nil : key
    }

    private static func keys(for place: ResolvedFamilyPlace) -> Set<String> {
        placeKeys(
            placeId: place.placeId,
            address: place.formattedAddress,
            latitude: place.latitude,
            longitude: place.longitude
        )
    }

    /// Keys of every household location; these take priority over saved/recent places.
    private var householdLocationKeys: Set<String> {
        backendHouseholdLocationsContext.locations.reduce(into: Set<String>()) { keys, location in
            keys.formUnion(Self.placeKeys(
                placeId: location.placeId,
                address: location.formattedAddress,
                latitude: location.latitude,
                longitude: location.longitude
            ))
        }
    }

    private struct DedupedSavedPlace: Identifiable {
        let id: String
        let title: String
        let place: ResolvedFamilyPlace
    }

    /// Saved places (built-in slots + named), excluding unset slots and anything already
    /// listed under Household locations. Only selectable, resolved places are returned.
    private var dedupedSavedPlaces: [DedupedSavedPlace] {
        var seen = householdLocationKeys
        var result: [DedupedSavedPlace] = []

        for slot in FamilyQuickPlacesStore.builtInSlots {
            guard let place = familyPlaces.place(forSlotId: slot.id) else { continue }
            let keys = Self.keys(for: place)
            guard seen.isDisjoint(with: keys) else { continue }
            seen.formUnion(keys)
            result.append(DedupedSavedPlace(id: "slot-\(slot.id)", title: slot.title, place: place))
        }

        for place in familyPlaces.namedPlaces {
            let keys = Self.keys(for: place)
            guard seen.isDisjoint(with: keys) else { continue }
            seen.formUnion(keys)
            result.append(DedupedSavedPlace(id: "named-\(place.id.uuidString)", title: place.locationName, place: place))
        }

        return result
    }

    /// Recent places excluding anything already shown under Household locations or Saved places.
    private var dedupedRecentPlaces: [ResolvedFamilyPlace] {
        var seen = householdLocationKeys
        for entry in dedupedSavedPlaces {
            seen.formUnion(Self.keys(for: entry.place))
        }
        var result: [ResolvedFamilyPlace] = []
        for place in familyPlaces.recentPlaces {
            let keys = Self.keys(for: place)
            guard seen.isDisjoint(with: keys) else { continue }
            seen.formUnion(keys)
            result.append(place)
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    searchCard
                    householdLocationsSection
                    savedPlacesSection
                    recentPlacesSection
                    savePlaceSection
                    searchResultsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(RunStitchTheme.background.ignoresSafeArea())
        .onAppear {
            requestLocationForSearchBias()
            applyRegionBiasFromService()
            searchFieldFocused = true
            savePlaceNameField = resolvedSnapshot?.placeName ?? ""
        }
        .onChange(of: locationService.lastLocationTimestamp) { _, _ in
            applyRegionBiasFromService()
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center) {
            Button {
                onCancel?()
                dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RunStitchTheme.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Choose location")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(RunStitchTheme.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 56, height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(RunStitchTheme.indigo.opacity(0.85))

                TextField("Search place or address", text: Binding(
                    get: { searchModel.query },
                    set: { searchModel.setQuery($0) }
                ))
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(RunStitchTheme.textPrimary)
                .tint(RunStitchTheme.indigo)
                .textInputAutocapitalization(.words)
                .focused($searchFieldFocused)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(RunStitchTheme.indigo.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)

            Text("Try pharmacy, school, mall, or a street address.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(RunStitchTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var householdLocationsSection: some View {
        let locations = backendHouseholdLocationsContext.locations
        return Group {
            if !locations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeading("Household locations")

                    VStack(spacing: 0) {
                        ForEach(Array(locations.enumerated()), id: \.element.id) { index, location in
                            quickPlaceButton(
                                title: location.displayName,
                                subtitle: location.formattedAddress,
                                filled: true
                            ) {
                                applyAndDismiss(location.toStopLocationSelection())
                            }
                            if index < locations.count - 1 {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(RunStitchTheme.indigo.opacity(0.10), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)
                }
            }
        }
    }

    private var savedPlacesSection: some View {
        let places = dedupedSavedPlaces
        return Group {
            if !places.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeading("Saved places")

                    VStack(spacing: 0) {
                        ForEach(Array(places.enumerated()), id: \.element.id) { index, entry in
                            quickPlaceButton(title: entry.title, subtitle: entry.place.formattedAddress, filled: true) {
                                applyAndDismiss(entry.place.toStopSelection())
                            }
                            if index < places.count - 1 {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(RunStitchTheme.indigo.opacity(0.10), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)
                }
            }
        }
    }

    private var recentPlacesSection: some View {
        let places = dedupedRecentPlaces
        return Group {
            if !places.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeading("Recent places")

                    VStack(spacing: 0) {
                        ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                            quickPlaceButton(title: place.locationName, subtitle: place.formattedAddress, filled: true) {
                                applyAndDismiss(place.toStopSelection())
                            }
                            if index < places.count - 1 {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(RunStitchTheme.indigo.opacity(0.10), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)
                }
            }
        }
    }

    @ViewBuilder
    private var savePlaceSection: some View {
        if snapshotHasCoordinates, let snap = resolvedSnapshot {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeading("Save for later")

                VStack(alignment: .leading, spacing: 12) {
                    Text("Save this address as a named place or family shortcut for quick runs.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(RunStitchTheme.textSecondary)

                    TextField("Name this place", text: $savePlaceNameField)
                        .font(.system(size: 16, weight: .regular))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        let name = savePlaceNameField.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        familyPlaces.saveNamedPlace(selection: snap, customName: name)
                    } label: {
                        Text("Save named place")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RunStitchTheme.indigo)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(savePlaceNameField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Menu {
                        ForEach(FamilyQuickPlacesStore.builtInSlots) { slot in
                            Button {
                                familyPlaces.saveToSlot(slotId: slot.id, selection: snap, slotTitle: slot.title)
                            } label: {
                                Text("Save as \(slot.title)")
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bookmark.fill")
                            Text("Save to family shortcut…")
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(RunStitchTheme.textSecondary)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RunStitchTheme.indigo)
                        .padding(.vertical, 10)
                    }
                }
                .padding(14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(RunStitchTheme.indigo.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)
            }
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        if !searchModel.results.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeading("Search results")

                VStack(spacing: 0) {
                    ForEach(Array(searchModel.results.enumerated()), id: \.element.id) { index, result in
                        resultRow(result)
                        if index < searchModel.results.count - 1 {
                            Divider()
                                .padding(.leading, 14)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(RunStitchTheme.indigo.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)
            }
        } else if searchModel.noMatchesFound {
            Text("No matches found. Try a different spelling or a nearby place.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RunStitchTheme.textSecondary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(RunStitchTheme.textSecondary)
            .padding(.leading, 2)
    }

    private func quickPlaceButton(title: String, subtitle: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RunStitchTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(filled ? RunStitchTheme.textSecondary : RunStitchTheme.textSecondary.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func resultRow(_ result: LocationSearchResult) -> some View {
        Button {
            Task { await selectSearchResultAndDismiss(result) }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RunStitchTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(RunStitchTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func applyAndDismiss(_ selection: StopLocationSelection) {
        onSelect(selection)
        dismiss()
    }

    private func requestLocationForSearchBias() {
        locationService.requestWhenInUseAccess()
        locationService.refreshAuthorizationState()
        if locationService.authorizationState == .authorizedWhenInUse
            || locationService.authorizationState == .authorizedAlways {
            locationService.startUpdatingLocation()
        }
    }

    private func applyRegionBiasFromService() {
        if let loc = locationService.currentLocation {
            searchModel.applyRegionBias(
                LocationSearchRegionBias(
                    regionMetersCenter: loc.coordinate,
                    latitudinalMeters: 50_000,
                    longitudinalMeters: 50_000
                )
            )
        } else {
            searchModel.applyRegionBias(nil)
        }
    }

    private func selectSearchResultAndDismiss(_ result: LocationSearchResult) async {
        let resolved = await searchModel.selectResult(result)
        applyAndDismiss(StopLocationSelection.from(resolved))
    }
}

#Preview {
    StopAddressSearchSheet(resolvedSnapshot: nil, onSelect: { _ in }, onCancel: nil)
        .environmentObject(LocationReadinessService())
        .environmentObject(FamilyQuickPlacesStore())
}
