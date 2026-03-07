import MapKit
import SwiftUI

struct SetHomeView: View {
    @Binding var homeLabel: String
    @Binding var homeAddress: String
    @Binding var homeAddressTitle: String
    @Binding var homeAddressSubtitle: String
    @Binding var homeLatitude: Double?
    @Binding var homeLongitude: Double?

    let onContinue: () -> Void

    @StateObject private var vm = HomeLocationViewModel()
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        VStack(spacing: 16) {
            homeFormCard

            mapView

            saveHomeButton

            Spacer()
        }
        .onAppear {
            vm.setInitialAddress(homeAddress)
            if let lat = homeLatitude, let lon = homeLongitude {
                vm.selectedLatitude = lat
                vm.selectedLongitude = lon
                vm.mapRegion = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                )
            }
            cameraPosition = .region(vm.mapRegion)
        }
        .onChange(of: vm.selectedTitle) { _, newValue in
            homeAddressTitle = newValue
        }
        .onChange(of: vm.selectedSubtitle) { _, newValue in
            homeAddressSubtitle = newValue
        }
        .onChange(of: vm.selectedLatitude) { _, newValue in
            homeLatitude = newValue
        }
        .onChange(of: vm.selectedLongitude) { _, newValue in
            homeLongitude = newValue
        }
        .onChange(of: mapRegionChangeToken) { _, _ in
            cameraPosition = .region(vm.mapRegion)
        }
    }

    private var homeCoordinate: CLLocationCoordinate2D? {
        guard let lat = vm.selectedLatitude, let lon = vm.selectedLongitude else { return nil }
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

            TextField("Home address", text: $vm.addressQuery)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(.primary)
                .tint(Color(red: 0.388, green: 0.400, blue: 0.945))
                .onChange(of: vm.addressQuery) { _, newValue in
                    homeAddress = newValue
                    vm.updateQuery(newValue)
                }

            suggestionsList

            Button {
                vm.useCurrentLocation()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                    Text(vm.isResolvingCurrentLocation ? "Locating..." : "Use current location")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.10))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(vm.isResolvingCurrentLocation)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    @ViewBuilder
    private var suggestionsList: some View {
        if !vm.suggestions.isEmpty {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(vm.suggestions.enumerated()), id: \.offset) { _, completion in
                        Button {
                            vm.selectSuggestion(completion)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(completion.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 180)
            .background(Color(uiColor: .tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
            }
        }
    }

    private var homePin: HomePin? {
        guard let coordinate = homeCoordinate else { return nil }
        return HomePin(coordinate: coordinate)
    }

    private var mapRegionChangeToken: HomeChangeKey {
        HomeChangeKey(
            lat: vm.mapRegion.center.latitude,
            lon: vm.mapRegion.center.longitude,
            spanLat: vm.mapRegion.span.latitudeDelta,
            spanLon: vm.mapRegion.span.longitudeDelta
        )
    }

    @MapContentBuilder
    private var mapContent: some MapContent {
        if let pin = homePin {
            Marker("Home", coordinate: pin.coordinate)
        }
    }

    private var mapView: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            mapContent
        }
        .onMapCameraChange { context in
            vm.mapRegion = context.region
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var saveHomeButton: some View {
        Button("Save Home") {
            onContinue()
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(red: 0.388, green: 0.400, blue: 0.945))
        .clipShape(Capsule())
        .shadow(color: Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.24), radius: 12, x: 0, y: 8)
        .disabled(homeAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}

private struct HomePin: Identifiable {
    let id: String = "home"
    let coordinate: CLLocationCoordinate2D
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
