import Combine
import Foundation

/// Persisted family shortcuts and recent stop picks for the Create Run location picker (no MapKit UI).
@MainActor
final class FamilyQuickPlacesStore: ObservableObject {
    struct BuiltInSlot: Identifiable, Equatable {
        let id: String
        let title: String
    }

    /// Fixed shortcuts shown in the picker (addresses filled when the family saves them).
    static let builtInSlots: [BuiltInSlot] = [
        BuiltInSlot(id: "home", title: "Home"),
        BuiltInSlot(id: "school", title: "School"),
        BuiltInSlot(id: "work", title: "Work"),
        BuiltInSlot(id: "church", title: "Church"),
        BuiltInSlot(id: "grandma", title: "Grandma’s house"),
        BuiltInSlot(id: "helper", title: "Helper’s address")
    ]

    @Published private(set) var slotPlaces: [String: ResolvedFamilyPlace] = [:]
    /// User-added named places (from “Save place”).
    @Published private(set) var namedPlaces: [ResolvedFamilyPlace] = []
    /// Previously selected stop addresses (most recent first).
    @Published private(set) var recentPlaces: [ResolvedFamilyPlace] = []

    private let slotsKey = "FamilyQuickPlaces.slots.v1"
    private let namedKey = "FamilyQuickPlaces.named.v1"
    private let recentKey = "FamilyQuickPlaces.recent.v1"

    init() {
        load()
    }

    func place(forSlotId slotId: String) -> ResolvedFamilyPlace? {
        slotPlaces[slotId]
    }

    func saveToSlot(slotId: String, selection: StopLocationSelection, slotTitle: String) {
        guard let lat = selection.latitude, let lon = selection.longitude else { return }
        let place = ResolvedFamilyPlace(
            id: UUID(),
            locationName: slotTitle,
            formattedAddress: selection.formattedAddress,
            latitude: lat,
            longitude: lon,
            placeId: selection.placeId,
            provider: selection.provider
        )
        slotPlaces[slotId] = place
        persistSlots()
        recordRecent(from: selection, titleOverride: slotTitle)
    }

    func saveNamedPlace(selection: StopLocationSelection, customName: String) {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let lat = selection.latitude, let lon = selection.longitude else { return }
        let place = ResolvedFamilyPlace(
            id: UUID(),
            locationName: trimmed,
            formattedAddress: selection.formattedAddress,
            latitude: lat,
            longitude: lon,
            placeId: selection.placeId,
            provider: selection.provider
        )
        namedPlaces.removeAll { $0.locationName.caseInsensitiveCompare(trimmed) == .orderedSame }
        namedPlaces.insert(place, at: 0)
        if namedPlaces.count > 24 {
            namedPlaces = Array(namedPlaces.prefix(24))
        }
        persistNamed()
        recordRecent(from: selection, titleOverride: trimmed)
    }

    func recordRecent(from selection: StopLocationSelection, titleOverride: String? = nil) {
        guard let lat = selection.latitude, let lon = selection.longitude else { return }
        let title = titleOverride ?? selection.placeName
        let entry = ResolvedFamilyPlace(
            id: UUID(),
            locationName: title,
            formattedAddress: selection.formattedAddress,
            latitude: lat,
            longitude: lon,
            placeId: selection.placeId,
            provider: selection.provider
        )
        recentPlaces.removeAll { existing in
            roughlySameCoordinate(existing, lat: lat, lon: lon)
                || existing.formattedAddress.caseInsensitiveCompare(selection.formattedAddress) == .orderedSame
        }
        recentPlaces.insert(entry, at: 0)
        if recentPlaces.count > 20 {
            recentPlaces = Array(recentPlaces.prefix(20))
        }
        persistRecent()
    }

    private func roughlySameCoordinate(_ p: ResolvedFamilyPlace, lat: Double, lon: Double) -> Bool {
        abs(p.latitude - lat) < 0.000_05 && abs(p.longitude - lon) < 0.000_05
    }

    private func persistSlots() {
        if let data = try? JSONEncoder().encode(slotPlaces) {
            UserDefaults.standard.set(data, forKey: slotsKey)
        }
    }

    private func persistNamed() {
        if let data = try? JSONEncoder().encode(namedPlaces) {
            UserDefaults.standard.set(data, forKey: namedKey)
        }
    }

    private func persistRecent() {
        if let data = try? JSONEncoder().encode(recentPlaces) {
            UserDefaults.standard.set(data, forKey: recentKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: slotsKey),
           let decoded = try? JSONDecoder().decode([String: ResolvedFamilyPlace].self, from: data) {
            slotPlaces = decoded
        }
        if let data = UserDefaults.standard.data(forKey: namedKey),
           let decoded = try? JSONDecoder().decode([ResolvedFamilyPlace].self, from: data) {
            namedPlaces = decoded
        }
        if let data = UserDefaults.standard.data(forKey: recentKey),
           let decoded = try? JSONDecoder().decode([ResolvedFamilyPlace].self, from: data) {
            recentPlaces = decoded
        }
    }
}

struct ResolvedFamilyPlace: Codable, Equatable, Identifiable {
    let id: UUID
    var locationName: String
    var formattedAddress: String
    var latitude: Double
    var longitude: Double
    var placeId: String?
    var provider: String?

    func toStopSelection() -> StopLocationSelection {
        StopLocationSelection(
            placeId: placeId,
            placeName: locationName,
            formattedAddress: formattedAddress,
            latitude: latitude,
            longitude: longitude,
            provider: provider
        )
    }
}
