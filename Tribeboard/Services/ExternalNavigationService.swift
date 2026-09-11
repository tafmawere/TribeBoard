import Foundation
import UIKit

enum NavigationApp: String, CaseIterable {
    case appleMaps
    case googleMaps
    case waze
}

struct ExternalNavigationService {
    static func canOpen(_ app: NavigationApp) -> Bool {
        switch app {
        case .appleMaps:
            return true
        case .googleMaps:
            guard AppSettings.allowGoogleMaps else { return false }
            guard let url = URL(string: "comgooglemaps://") else { return false }
            return UIApplication.shared.canOpenURL(url)
        case .waze:
            guard AppSettings.allowWaze else { return false }
            guard let url = URL(string: "waze://") else { return false }
            return UIApplication.shared.canOpenURL(url)
        }
    }

    static func open(
        app: NavigationApp,
        destinationName: String,
        latitude: Double,
        longitude: Double
    ) {
        switch app {
        case .appleMaps:
            openAppleMaps(destinationName: destinationName, latitude: latitude, longitude: longitude)
        case .googleMaps:
            guard canOpen(.googleMaps) else {
                openAppleMaps(destinationName: destinationName, latitude: latitude, longitude: longitude)
                return
            }
            let encodedName = destinationName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destinationName
            if let url = URL(string: "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=driving&q=\(encodedName)") {
                UIApplication.shared.open(url)
            } else {
                openAppleMaps(destinationName: destinationName, latitude: latitude, longitude: longitude)
            }
        case .waze:
            guard canOpen(.waze) else {
                openAppleMaps(destinationName: destinationName, latitude: latitude, longitude: longitude)
                return
            }
            if let url = URL(string: "waze://?ll=\(latitude),\(longitude)&navigate=yes") {
                UIApplication.shared.open(url)
            } else {
                openAppleMaps(destinationName: destinationName, latitude: latitude, longitude: longitude)
            }
        }
    }

    private static func openAppleMaps(
        destinationName: String,
        latitude: Double,
        longitude: Double
    ) {
        let encodedName = destinationName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? destinationName
        let urlString = "http://maps.apple.com/?daddr=\(latitude),\(longitude)&dirflg=d"
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
