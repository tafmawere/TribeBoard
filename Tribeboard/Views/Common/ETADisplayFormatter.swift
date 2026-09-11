import Foundation

enum ETADisplayFormatter {
  static let maxReasonableMinutes = 120

  static func minutesLabel(for minutes: Int?) -> String {
    guard let minutes else { return "ETA unavailable" }
    guard minutes >= 0, minutes <= maxReasonableMinutes else { return "ETA unavailable" }
    if minutes == 0 { return "< 1 min" }
    return "\(minutes) min"
  }

  static func minutesLabel(for prediction: ETAPrediction?) -> String {
    guard let prediction else { return "ETA unavailable" }
    return minutesLabel(for: prediction.estimatedMinutesRemaining)
  }

  static let maxReasonableMeters = 150_000.0

  static func distanceKilometersLabel(meters: Double?) -> String {
    guard let meters, meters.isFinite, meters >= 0 else { return "—" }
    guard meters <= maxReasonableMeters else { return "Distance unavailable" }
    let km = meters / 1000.0
    if km < 0.1 { return "< 0.1 km" }
    return String(format: "%.1f km", km)
  }
}
