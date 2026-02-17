//
//  MockHomeData.swift
//  Tribeboard
//
//  Mock data for UI development and previews
//

import Foundation

struct MockHomeData {
    
    // MARK: - Mock Family Members
    
    static let mockFamilyMembers: [FamilyMemberDisplay] = [
        FamilyMemberDisplay(
            id: "user_1",
            displayName: "Tafadzwa",
            avatarInitials: "TM",
            isParent: true,
            phone: "+1234567890",
            roleBadges: [
                .init(name: "Parent", color: .purple),
                .init(name: "Driver", color: .blue),
                .init(name: "Admin", color: .orange)
            ],
            capabilities: ["Can create runs", "Can start/drive runs", "Can track runs", "Can manage family"],
            isLocationSharingEnabled: true
        ),
        FamilyMemberDisplay(
            id: "user_2",
            displayName: "Rue",
            avatarInitials: "RM",
            isParent: true,
            phone: "+1234567891",
            roleBadges: [
                .init(name: "Parent", color: .purple),
                .init(name: "Observer", color: .green),
                .init(name: "Admin", color: .orange)
            ],
            capabilities: ["Can create runs", "Can track runs", "Can manage family"],
            isLocationSharingEnabled: true
        ),
        FamilyMemberDisplay(
            id: "user_3",
            displayName: "Emma",
            avatarInitials: "EM",
            isParent: false,
            phone: nil,
            roleBadges: [
                .init(name: "Child", color: .blue),
                .init(name: "Passenger", color: .green)
            ],
            capabilities: ["Can create runs"],
            isLocationSharingEnabled: true
        ),
        FamilyMemberDisplay(
            id: "user_4",
            displayName: "Noah",
            avatarInitials: "NM",
            isParent: false,
            phone: nil,
            roleBadges: [
                .init(name: "Child", color: .blue),
                .init(name: "Passenger", color: .green)
            ],
            capabilities: ["Can create runs"],
            isLocationSharingEnabled: true
        )
    ]
    
    // MARK: - Mock Runs
    
    static let mockRuns: [Run] = [
        Run(
            id: "run_1",
            title: "School Drop-off",
            scheduledTime: Date().addingTimeInterval(3600),
            driverId: "user_1",
            status: .scheduled,
            stops: [
                RunStop(
                    type: .pickup,
                    label: "Home",
                    scheduledTime: Date().addingTimeInterval(3600),
                    requiredPassengerIds: ["user_3", "user_4"],
                    location: LocationData(latitude: 37.7749, longitude: -122.4194, address: "123 Main St")
                ),
                RunStop(
                    type: .dropoff,
                    label: "Elementary School",
                    scheduledTime: Date().addingTimeInterval(4500),
                    requiredPassengerIds: ["user_3"],
                    location: LocationData(latitude: 37.7849, longitude: -122.4094, address: "456 School Ave")
                ),
                RunStop(
                    type: .dropoff,
                    label: "Middle School",
                    scheduledTime: Date().addingTimeInterval(5400),
                    requiredPassengerIds: ["user_4"],
                    location: LocationData(latitude: 37.7949, longitude: -122.3994, address: "789 Education Blvd")
                )
            ],
            passengers: [
                MemberSummary(id: "user_3", displayName: "Emma", role: .passenger),
                MemberSummary(id: "user_4", displayName: "Noah", role: .passenger)
            ],
            createdBy: "user_1",
            familyId: "family_1"
        ),
        Run(
            id: "run_2",
            title: "Soccer Practice",
            scheduledTime: Date().addingTimeInterval(14400),
            driverId: "user_2",
            status: .activeEnroute,
            stops: [
                RunStop(
                    type: .pickup,
                    label: "Home",
                    scheduledTime: Date().addingTimeInterval(14400),
                    requiredPassengerIds: ["user_3"],
                    location: LocationData(latitude: 37.7749, longitude: -122.4194, address: "123 Main St")
                ),
                RunStop(
                    type: .dropoff,
                    label: "Soccer Field",
                    scheduledTime: Date().addingTimeInterval(15300),
                    requiredPassengerIds: ["user_3"],
                    location: LocationData(latitude: 37.8049, longitude: -122.4294, address: "321 Sports Complex")
                )
            ],
            passengers: [
                MemberSummary(id: "user_3", displayName: "Emma", role: .passenger, status: .onboard)
            ],
            createdBy: "user_2",
            familyId: "family_1",
            currentStopIndex: 1,
            lastLocation: GeoPoint(latitude: 37.7899, longitude: -122.4244),
            lastLocationUpdatedAt: Date(),
            startTime: Date().addingTimeInterval(-300)
        ),
        Run(
            id: "run_3",
            title: "Piano Lesson",
            scheduledTime: Date().addingTimeInterval(86400),
            driverId: "user_1",
            status: .scheduled,
            stops: [
                RunStop(
                    type: .pickup,
                    label: "Home",
                    scheduledTime: Date().addingTimeInterval(86400),
                    requiredPassengerIds: ["user_4"],
                    location: LocationData(latitude: 37.7749, longitude: -122.4194, address: "123 Main St")
                ),
                RunStop(
                    type: .dropoff,
                    label: "Music Academy",
                    scheduledTime: Date().addingTimeInterval(87300),
                    requiredPassengerIds: ["user_4"],
                    location: LocationData(latitude: 37.7649, longitude: -122.4294, address: "555 Melody Lane")
                )
            ],
            passengers: [
                MemberSummary(id: "user_4", displayName: "Noah", role: .passenger)
            ],
            createdBy: "user_1",
            familyId: "family_1"
        )
    ]
    
    // MARK: - Mock Schedules
    
    static let mockSchedules: [Schedule] = [
        Schedule(
            id: "schedule_1",
            title: "School Drop-off",
            recurrence: .weekdays,
            time: DateComponents(hour: 8, minute: 0),
            driverId: "user_1",
            passengers: ["user_3", "user_4"],
            stops: [
                ScheduleStop(label: "Home", address: "123 Main St"),
                ScheduleStop(label: "Elementary School", address: "456 School Ave"),
                ScheduleStop(label: "Middle School", address: "789 Education Blvd")
            ],
            isActive: true
        ),
        Schedule(
            id: "schedule_2",
            title: "Soccer Practice",
            recurrence: .custom([.tuesday, .thursday]),
            time: DateComponents(hour: 16, minute: 30),
            driverId: "user_2",
            passengers: ["user_3"],
            stops: [
                ScheduleStop(label: "Home", address: "123 Main St"),
                ScheduleStop(label: "Soccer Field", address: "321 Sports Complex")
            ],
            isActive: true
        ),
        Schedule(
            id: "schedule_3",
            title: "Piano Lesson",
            recurrence: .custom([.wednesday]),
            time: DateComponents(hour: 15, minute: 0),
            driverId: "user_1",
            passengers: ["user_4"],
            stops: [
                ScheduleStop(label: "Home", address: "123 Main St"),
                ScheduleStop(label: "Music Academy", address: "555 Melody Lane")
            ],
            isActive: true
        )
    ]
    
    // MARK: - Mock Calendar Events
    
    static let mockCalendarEvents: [CalendarEvent] = [
        CalendarEvent(
            id: "event_1",
            title: "School Drop-off",
            date: Date().addingTimeInterval(3600),
            type: .run,
            runId: "run_1"
        ),
        CalendarEvent(
            id: "event_2",
            title: "Soccer Practice",
            date: Date().addingTimeInterval(14400),
            type: .run,
            runId: "run_2"
        ),
        CalendarEvent(
            id: "event_3",
            title: "Piano Lesson",
            date: Date().addingTimeInterval(86400),
            type: .run,
            runId: "run_3"
        ),
        CalendarEvent(
            id: "event_4",
            title: "Dentist Appointment",
            date: Date().addingTimeInterval(172800),
            type: .other,
            runId: nil
        )
    ]
}

// MARK: - Supporting Types

struct Schedule: Identifiable {
    let id: String
    let title: String
    let recurrence: Recurrence
    let time: DateComponents
    let driverId: String
    let passengers: [String]
    let stops: [ScheduleStop]
    let isActive: Bool
    
    enum Recurrence {
        case daily
        case weekdays
        case weekends
        case custom([Weekday])
        
        enum Weekday {
            case monday, tuesday, wednesday, thursday, friday, saturday, sunday
        }
    }
}

struct ScheduleStop {
    let label: String
    let address: String
}

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let date: Date
    let type: EventType
    let runId: String?
    
    enum EventType {
        case run
        case other
    }
}

struct GeoPoint: Codable {
    let latitude: Double
    let longitude: Double
}
