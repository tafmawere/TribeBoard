#if DEBUG
import SwiftUI

struct DeveloperSettingsView: View {
    @EnvironmentObject private var locationService: LocationReadinessService

    var body: some View {
        ScrollView {
            VStack(spacing: SettingsHubTheme.sectionSpacing) {
                sourceCard
                presetCard
            }
            .padding(.horizontal, SettingsHubTheme.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, SettingsHubTheme.tabBarClearance)
        }
        .background(SettingsHubTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sourceCard: some View {
        SettingsHubSectionCard(title: "Location Source", accent: .app) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current source")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(SettingsHubTheme.subtitleSecondary)
                    Text(locationService.locationGPSourceLabel)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(sourceColor)
                }
                Spacer()
                Image(systemName: locationService.locationGPSourceLabel == "MOCK GPS" ? "location.fill.viewfinder" : "location.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(sourceColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var sourceColor: Color {
        locationService.locationGPSourceLabel == "MOCK GPS" ? TribePalette.orange : TribePalette.green
    }

    private var presetCard: some View {
        SettingsHubSectionCard(title: "Debug Location", accent: .app) {
            ForEach(Array(DebugLocationPreset.allCases.enumerated()), id: \.element.id) { index, preset in
                Button {
                    locationService.setDebugLocationPreset(preset)
                } label: {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: locationService.debugLocationPreset == preset ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(locationService.debugLocationPreset == preset ? TribePalette.primary : SettingsHubTheme.subtitleSecondary)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(SettingsHubTheme.titlePrimary)
                                .multilineTextAlignment(.leading)
                            Text(preset.subtitle)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(SettingsHubTheme.subtitleSecondary)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < DebugLocationPreset.allCases.count - 1 {
                    Divider()
                        .overlay(SettingsHubTheme.divider)
                        .padding(.leading, 16 + 20 + 14)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DeveloperSettingsView()
            .environmentObject(LocationReadinessService())
    }
}
#endif
