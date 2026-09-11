import GoogleMaps
import SwiftUI
import UIKit

struct SetHomeView: View {
    @Binding var homeLabel: String
    @Binding var homeAddress: String
    @Binding var homeAddressTitle: String
    @Binding var homeAddressSubtitle: String
    @Binding var homeLatitude: Double?
    @Binding var homeLongitude: Double?

    let onContinue: () -> Void

    @StateObject private var searchModel = LocationSearchModel()
    @State private var mapRegion = CoordinateRegionDegrees(
        center: CLLocationCoordinate2D(latitude: -17.8252, longitude: 31.0335),
        latitudeDelta: 0.03,
        longitudeDelta: 0.03
    )

    var body: some View {
        VStack(spacing: 16) {
            homeFormCard

            mapView

            saveHomeButton

            Spacer()
        }
        .onAppear {
            searchModel.applySelectedAddress(homeAddress)
            if let lat = homeLatitude, let lon = homeLongitude {
                mapRegion = CoordinateRegionDegrees(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    latitudeDelta: 0.012,
                    longitudeDelta: 0.012
                )
            }
        }
        .onChange(of: mapRegionChangeToken) { _, _ in
            // Region updates when the user picks a new resolved address from search.
        }
    }

    private var homeCoordinate: CLLocationCoordinate2D? {
        guard let lat = homeLatitude, let lon = homeLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private var homeFormCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set home")
                .font(.system(size: 30, weight: .bold))
            Text("Home is tribe-level and inherited by all children.")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            TextField("Label", text: $homeLabel)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(.primary)
                .tint(Color(red: 0.388, green: 0.400, blue: 0.945))

            LocationSearchField(
                title: "Home Address",
                placeholder: "Search home address",
                model: searchModel,
                onSelected: { result in
                    homeAddress = result.fullAddress
                    homeAddressTitle = result.title
                    homeAddressSubtitle = result.subtitle
                    homeLatitude = result.latitude
                    homeLongitude = result.longitude
                    if let lat = result.latitude, let lon = result.longitude {
                        mapRegion = CoordinateRegionDegrees(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            latitudeDelta: 0.012,
                            longitudeDelta: 0.012
                        )
                    }
                },
                onCleared: {
                    homeAddress = ""
                    homeAddressTitle = ""
                    homeAddressSubtitle = ""
                    homeLatitude = nil
                    homeLongitude = nil
                }
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    private var homePin: GoogleMapMarkerModel? {
        guard let coordinate = homeCoordinate else { return nil }
        return GoogleMapMarkerModel(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
            title: "Home",
            coordinate: coordinate,
            kind: .generic,
            orderLabel: nil,
            isSelected: false
        )
    }

    private var mapRegionChangeToken: HomeChangeKey {
        HomeChangeKey(
            lat: mapRegion.center.latitude,
            lon: mapRegion.center.longitude,
            spanLat: mapRegion.latitudeDelta,
            spanLon: mapRegion.longitudeDelta
        )
    }

    private var mapView: some View {
        TribeGoogleMapView(
            markers: homePin.map { [$0] } ?? [],
            polylineCoordinates: [],
            strokeUIColor: .clear,
            lineWidth: 0,
            cameraHint: mapRegion,
            externalCamera: nil,
            showsUserLocation: false,
            padding: .init(top: 12, left: 12, bottom: 12, right: 12),
            onMarkerIdTap: nil
        )
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var saveHomeButton: some View {
        Button("Save Home") {
            homeAddress = searchModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
            onContinue()
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(red: 0.388, green: 0.400, blue: 0.945))
        .clipShape(Capsule())
        .shadow(color: Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.24), radius: 12, x: 0, y: 8)
        .disabled(searchModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

private struct HomeChangeKey: Equatable {
    let lat: Double
    let lon: Double
    let spanLat: Double
    let spanLon: Double
}

#Preview {
    SetHomeView(
        homeLabel: .constant("Home"),
        homeAddress: .constant(""),
        homeAddressTitle: .constant(""),
        homeAddressSubtitle: .constant(""),
        homeLatitude: .constant(nil),
        homeLongitude: .constant(nil),
        onContinue: {}
    )
}
