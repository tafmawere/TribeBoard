//
//  Run.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation
import CoreLocation

// MARK: - Extensions

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - Core Data Models

struct Run: Codable, Identifiable {
    let id: String
    let title: String
    let scheduledTime: Date
    var driverId: String
    var status: RunStatus
    var stops: [RunStop]
    var passengers: [MemberSummary]
    let createdBy: String
    let familyId: String
    var isDelayed: Bool
    var delayReason: String?
    var currentStopIndex: Int
    var lastLocation: GeoPoint?
    var lastLocationUpdatedAt: Date?
    var startTime: Date?
    
    init(id: String = UUID().uuidString,
         title: String,
         scheduledTime: Date,
         driverId: String,
         status: RunStatus = .scheduled,
         stops: [RunStop],
         passengers: [MemberSummary],
         createdBy: String,
         familyId: String,
         isDelayed: Bool = false,
         delayReason: String? = nil,
         currentStopIndex: Int = 0,
         lastLocation: GeoPoint? = nil,
         lastLocationUpdatedAt: Date? = nil,
         startTime: Date? = nil) {
        self.id = id
        self.title = title
        self.scheduledTime = scheduledTime
        self.driverId = driverId
        self.status = status
        self.stops = stops
        self.passengers = passengers
        self.createdBy = createdBy
        self.familyId = familyId
        self.isDelayed = isDelayed
        self.delayReason = delayReason
        self.currentStopIndex = currentStopIndex
        self.lastLocation = lastLocation
        self.lastLocationUpdatedAt = lastLocationUpdatedAt
        self.startTime = startTime
    }
}

enum RunStatus: String, Codable, CaseIterable {
    case scheduled = "scheduled"
    case activeEnroute = "activeEnroute"
    case arrivedAtStop = "arrivedAtStop"
    case paused = "paused"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .activeEnroute: return "En Route"
        case .arrivedAtStop: return "Arrived at Stop"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .activeEnroute, .arrivedAtStop, .paused:
            return true
        default:
            return false
        }
    }
    
    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled:
            return true
        default:
            return false
        }
    }
}

struct RunStop: Codable, Identifiable {
    let id: String
    let type: StopType
    let label: String
    let scheduledTime: Date
    let requiredPassengerIds: [String]
    var isCompleted: Bool
    var completedAt: Date?
    let location: LocationData
    var notes: String?
    
    init(id: String = UUID().uuidString,
         type: StopType,
         label: String,
         scheduledTime: Date,
         requiredPassengerIds: [String],
         location: LocationData,
         notes: String? = nil) {
        self.id = id
        self.type = type
        self.label = label
        self.scheduledTime = scheduledTime
        self.requiredPassengerIds = requiredPassengerIds
        self.isCompleted = false
        self.completedAt = nil
        self.location = location
        self.notes = notes
    }
}

enum StopType: String, Codable, CaseIterable {
    case pickup = "pickup"
    case dropoff = "dropoff"
    case waypoint = "waypoint"
    
    var displayName: String {
        switch self {
        case .pickup: return "Pickup"
        case .dropoff: return "Dropoff"
        case .waypoint: return "Waypoint"
        }
    }
}

struct MemberSummary: Codable, Identifiable {
    let id: String
    let displayName: String
    let role: MemberRole
    var status: PassengerStatus
    let avatarURL: String?
    
    init(id: String,
         displayName: String,
         role: MemberRole,
         status: PassengerStatus = .waiting,
         avatarURL: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.status = status
        self.avatarURL = avatarURL
    }
}

enum MemberRole: String, Codable, CaseIterable {
    case driver = "driver"
    case observer = "observer"
    case passenger = "passenger"
    
    var displayName: String {
        switch self {
        case .driver: return "Driver"
        case .observer: return "Observer"
        case .passenger: return "Passenger"
        }
    }
}

enum PassengerStatus: String, Codable, CaseIterable {
    case waiting = "waiting"
    case onboard = "onboard"
    case droppedOff = "droppedOff"
    
    var displayName: String {
        switch self {
        case .waiting: return "Waiting"
        case .onboard: return "On Board"
        case .droppedOff: return "Dropped Off"
        }
    }
}

struct LocationData: Codable {
    let latitude: Double
    let longitude: Double
    let address: String?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double, address: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }
    
    init(coordinate: CLLocationCoordinate2D, address: String? = nil) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.address = address
    }
}