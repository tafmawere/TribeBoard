import SwiftUI

struct NavigationAppsSettingsView: View {
    @AppStorage(AppSettings.allowGoogleMapsKey) private var allowGoogleMaps = true
    @AppStorage(AppSettings.allowWazeKey) private var allowWaze = true
    @AppStorage(AppSettings.arrivalRadiusMetersKey) private var arrivalRadiusMeters = 100.0

    var body: some View {
        ScrollView {
            VStack(spacing: SettingsHubTheme.sectionSpacing) {
                SettingsHubSectionCard(title: "Navigation Apps", accent: .app) {
                    SettingsHubRow(
                        icon: "map.fill",
                        title: "Google Maps",
                        subtitle: "Open directions in Google Maps",
                        accent: .app,
                        toggle: $allowGoogleMaps
                    )
                    SettingsHubRow(
                        icon: "car.fill",
                        title: "Waze",
                        subtitle: "Open directions in Waze",
                        accent: .app,
                        toggle: $allowWaze,
                        showsDivider: false
                    )
                }

                SettingsHubSectionCard(title: "Arrival", accent: .app) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Arrival radius", systemImage: "location.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Text("\(Int(arrivalRadiusMeters)) m")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(SettingsHubTheme.subtitleSecondary)
                        }
                        Stepper("Arrival radius", value: $arrivalRadiusMeters, in: 25...500, step: 25)
                            .labelsHidden()
                    }
                    .padding(16)
                }
            }
            .padding(.horizontal, SettingsHubTheme.horizontalPadding)
            .padding(.vertical, 12)
        }
        .background(SettingsHubTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Navigation Apps")
        .navigationBarTitleDisplayMode(.inline)
    }
}
