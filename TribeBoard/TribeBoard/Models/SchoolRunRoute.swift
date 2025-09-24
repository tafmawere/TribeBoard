import Foundation

/// Navigation routes for School Run feature
enum SchoolRunRoute: Hashable, Codable {
    case dashboard
    case scheduleNew
    case scheduledList
    case runDetail(ScheduledSchoolRun)
    case runExecution(ScheduledSchoolRun)
    
    // MARK: - Hashable Conformance
    
    func hash(into hasher: inout Hasher) {
        switch self {
        case .dashboard:
            hasher.combine("dashboard")
        case .scheduleNew:
            hasher.combine("scheduleNew")
        case .scheduledList:
            hasher.combine("scheduledList")
        case .runDetail(let run):
            hasher.combine("runDetail")
            hasher.combine(run.id)
        case .runExecution(let run):
            hasher.combine("runExecution")
            hasher.combine(run.id)
        }
    }
    
    // MARK: - Equatable Conformance
    
    static func == (lhs: SchoolRunRoute, rhs: SchoolRunRoute) -> Bool {
        switch (lhs, rhs) {
        case (.dashboard, .dashboard):
            return true
        case (.scheduleNew, .scheduleNew):
            return true
        case (.scheduledList, .scheduledList):
            return true
        case (.runDetail(let lhsRun), .runDetail(let rhsRun)):
            return lhsRun.id == rhsRun.id
        case (.runExecution(let lhsRun), .runExecution(let rhsRun)):
            return lhsRun.id == rhsRun.id
        default:
            return false
        }
    }
    
    // MARK: - Codable Conformance
    
    enum CodingKeys: String, CodingKey {
        case type
        case runId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "dashboard":
            self = .dashboard
        case "scheduleNew":
            self = .scheduleNew
        case "scheduledList":
            self = .scheduledList
        case "runDetail":
            // For demo purposes, we'll create a placeholder run
            // In a real app, this would fetch the run from storage
            let runId = try container.decode(UUID.self, forKey: .runId)
            let placeholderRun = ScheduledSchoolRun(
                name: "Placeholder Run",
                scheduledDate: Date(),
                scheduledTime: Date(),
                stops: []
            )
            self = .runDetail(placeholderRun)
        case "runExecution":
            // For demo purposes, we'll create a placeholder run
            let runId = try container.decode(UUID.self, forKey: .runId)
            let placeholderRun = ScheduledSchoolRun(
                name: "Placeholder Run",
                scheduledDate: Date(),
                scheduledTime: Date(),
                stops: []
            )
            self = .runExecution(placeholderRun)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown route type: \(type)"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .dashboard:
            try container.encode("dashboard", forKey: .type)
        case .scheduleNew:
            try container.encode("scheduleNew", forKey: .type)
        case .scheduledList:
            try container.encode("scheduledList", forKey: .type)
        case .runDetail(let run):
            try container.encode("runDetail", forKey: .type)
            try container.encode(run.id, forKey: .runId)
        case .runExecution(let run):
            try container.encode("runExecution", forKey: .type)
            try container.encode(run.id, forKey: .runId)
        }
    }
}