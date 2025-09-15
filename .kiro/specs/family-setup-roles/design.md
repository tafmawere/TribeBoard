# Design Document: Family Setup & Roles Module

## Overview

The Family Setup & Roles module implements a comprehensive family management system for TribeBoard using modern iOS development practices. The architecture follows MVVM pattern with service-oriented design, leveraging SwiftData for local persistence, CloudKit for cloud synchronization, and Sign in with Apple for authentication.

## Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   SwiftUI Views │◄──►│   ViewModels    │◄──►│    Services     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                       ┌─────────────────┐             │
                       │   Data Models   │◄────────────┘
                       └─────────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
            ┌───────▼────────┐    ┌────────▼────────┐
            │   SwiftData    │    │    CloudKit     │
            │ (Local Store)  │    │ (Cloud Sync)    │
            └────────────────┘    └─────────────────┘
```

### MVVM + Services Pattern

- **Views**: SwiftUI views that mirror Figma designs, handle user interactions
- **ViewModels**: ObservableObject classes managing view state and business logic
- **Services**: Singleton services handling data operations, authentication, and external APIs
- **Models**: SwiftData entities with CloudKit synchronization capabilities

## Components and Interfaces

### Core Services

#### AuthService
```swift
@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: UserProfile?
    
    func signInWithApple() async throws -> UserProfile
    func signOut() async throws
    func getCurrentUser() -> UserProfile?
}
```

#### CloudKitService
```swift
class CloudKitService {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    func save<T: CloudKitSyncable>(_ record: T) async throws
    func fetch<T: CloudKitSyncable>(_ type: T.Type, predicate: NSPredicate) async throws -> [T]
    func delete(_ recordID: CKRecord.ID) async throws
}
```

#### QRCodeService
```swift
class QRCodeService {
    func generateQRCode(from string: String) -> UIImage?
    func scanQRCode(from image: UIImage) -> String?
}
```

#### KeychainService
```swift
class KeychainService {
    func store(_ data: Data, for key: String) throws
    func retrieve(for key: String) throws -> Data?
    func delete(for key: String) throws
}
```

### ViewModels

#### OnboardingViewModel
```swift
@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let authService: AuthService
    
    func signInWithApple() async
}
```

#### CreateFamilyViewModel
```swift
@MainActor
class CreateFamilyViewModel: ObservableObject {
    @Published var familyName = ""
    @Published var isCreating = false
    @Published var createdFamily: Family?
    @Published var qrCodeImage: UIImage?
    
    func createFamily() async
    private func generateFamilyCode() -> String
}
```

#### JoinFamilyViewModel
```swift
@MainActor
class JoinFamilyViewModel: ObservableObject {
    @Published var familyCode = ""
    @Published var isJoining = false
    @Published var foundFamily: Family?
    @Published var showConfirmation = false
    
    func searchFamily(by code: String) async
    func joinFamily() async
    func scanQRCode() async
}
```

#### RoleSelectionViewModel
```swift
@MainActor
class RoleSelectionViewModel: ObservableObject {
    @Published var selectedRole: Role = .adult
    @Published var isUpdating = false
    @Published var canSelectParentAdmin = true
    
    func setRole(_ role: Role) async
    private func checkParentAdminAvailability() async
}
```

#### FamilyDashboardViewModel
```swift
@MainActor
class FamilyDashboardViewModel: ObservableObject {
    @Published var members: [Membership] = []
    @Published var currentUserRole: Role = .adult
    @Published var isLoading = false
    
    func loadMembers() async
    func changeRole(for member: Membership, to role: Role) async
    func removeMember(_ member: Membership) async
}
```

## Data Models

### SwiftData Models with CloudKit Sync

#### Family
```swift
@Model
class Family {
    @Attribute(.unique) var id: UUID
    var name: String
    @Attribute(.unique) var code: String
    var createdByUserId: UUID
    var createdAt: Date
    
    // CloudKit sync properties
    var ckRecordID: String?
    var lastSyncDate: Date?
    
    init(name: String, code: String, createdByUserId: UUID) {
        self.id = UUID()
        self.name = name
        self.code = code
        self.createdByUserId = createdByUserId
        self.createdAt = Date()
    }
}
```

#### UserProfile
```swift
@Model
class UserProfile {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var appleUserIdHash: String
    var avatarUrl: URL?
    
    // CloudKit sync properties
    var ckRecordID: String?
    var lastSyncDate: Date?
    
    init(displayName: String, appleUserIdHash: String) {
        self.id = UUID()
        self.displayName = displayName
        self.appleUserIdHash = appleUserIdHash
    }
}
```

#### Membership
```swift
@Model
class Membership {
    @Attribute(.unique) var id: UUID
    var familyId: UUID
    var userId: UUID
    var role: Role
    var joinedAt: Date
    var status: MembershipStatus
    
    // CloudKit sync properties
    var ckRecordID: String?
    var lastSyncDate: Date?
    
    init(familyId: UUID, userId: UUID, role: Role) {
        self.id = UUID()
        self.familyId = familyId
        self.userId = userId
        self.role = role
        self.joinedAt = Date()
        self.status = .active
    }
}
```

#### Enums
```swift
enum Role: String, CaseIterable, Codable {
    case parentAdmin = "parent_admin"
    case adult = "adult"
    case kid = "kid"
    case visitor = "visitor"
    
    var displayName: String {
        switch self {
        case .parentAdmin: return "Parent Admin"
        case .adult: return "Adult"
        case .kid: return "Kid"
        case .visitor: return "Visitor"
        }
    }
}

enum MembershipStatus: String, Codable {
    case active = "active"
    case invited = "invited"
    case removed = "removed"
}
```

### CloudKit Schema

#### CKRecord Types

**CKFamily**
- Fields: name (String), code (String), createdByUserId (String), createdAt (Date)
- Indexes: code (queryable, unique)

**CKUserProfile**
- Fields: displayName (String), appleUserIdHash (String), avatarUrl (String)
- Indexes: appleUserIdHash (queryable, unique)

**CKMembership**
- Fields: familyId (Reference to CKFamily), userId (Reference to CKUserProfile), role (String), joinedAt (Date), status (String)
- Indexes: familyId (queryable), userId (queryable), status (queryable)

## Error Handling

### Error Types
```swift
enum FamilyError: LocalizedError {
    case authenticationFailed
    case familyCodeExists
    case familyNotFound
    case parentAdminExists
    case networkUnavailable
    case syncFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .familyCodeExists:
            return "Family code already exists. Please try again."
        case .familyNotFound:
            return "Family not found. Please check the code."
        case .parentAdminExists:
            return "A Parent Admin already exists for this family."
        case .networkUnavailable:
            return "Network unavailable. Changes will sync when connected."
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        }
    }
}
```

### Error Handling Strategy
- **Local-first**: Always write to SwiftData first, queue CloudKit operations
- **Graceful degradation**: Show cached data when offline
- **User feedback**: Non-blocking banners for sync issues
- **Retry logic**: Exponential backoff for failed CloudKit operations

## Testing Strategy

### Unit Tests

#### Service Tests
- **AuthServiceTests**: Mock ASAuthorization, test authentication flows
- **CloudKitServiceTests**: Mock CKDatabase, test CRUD operations
- **QRCodeServiceTests**: Test QR generation and parsing
- **KeychainServiceTests**: Test secure storage operations

#### ViewModel Tests
- **OnboardingViewModelTests**: Test authentication state management
- **CreateFamilyViewModelTests**: Test family creation logic and validation
- **JoinFamilyViewModelTests**: Test family search and joining flows
- **RoleSelectionViewModelTests**: Test role validation and constraints
- **FamilyDashboardViewModelTests**: Test member management operations

#### Model Tests
- **FamilyTests**: Test family code generation and validation
- **MembershipTests**: Test role constraints and status changes
- **UserProfileTests**: Test profile creation and validation

### Integration Tests
- **FamilyFlowTests**: End-to-end family creation and joining
- **SyncTests**: CloudKit synchronization scenarios
- **OfflineTests**: Offline functionality and conflict resolution

### UI Tests
- **OnboardingUITests**: Test Sign in with Apple flow
- **FamilyCreationUITests**: Test family creation workflow
- **QRScanningUITests**: Test QR code scanning functionality

## Security Considerations

### Data Protection
- **Keychain Storage**: Store sensitive data (Apple ID hash, family ID) in Keychain
- **CloudKit Private Database**: Use private database with custom zones
- **Minimal PII**: Store only necessary user information
- **Secure Transmission**: All CloudKit operations use HTTPS

### Authentication
- **Sign in with Apple**: Leverage Apple's secure authentication
- **Token Management**: Store authentication tokens securely
- **Session Management**: Handle token refresh and expiration

### Privacy
- **Data Minimization**: Collect only required information
- **User Consent**: Clear privacy policy and data usage
- **Local Processing**: Process QR codes locally, don't upload images

## Performance Optimizations

### Data Loading
- **Lazy Loading**: Load family members on demand
- **Caching**: Cache frequently accessed data locally
- **Pagination**: Implement pagination for large family lists

### CloudKit Optimization
- **Batch Operations**: Batch CloudKit operations when possible
- **Custom Zones**: Use custom zones for better organization
- **Subscription**: Use CloudKit subscriptions for real-time updates

### UI Performance
- **Async Operations**: Use async/await for all network operations
- **Main Thread**: Ensure UI updates happen on main thread
- **Image Caching**: Cache QR code images and avatars

## Implementation Phases

### Phase 1: Core Infrastructure
- Set up SwiftData models and CloudKit schema
- Implement basic services (Auth, CloudKit, Keychain)
- Create base ViewModels and navigation structure

### Phase 2: Authentication & Onboarding
- Implement Sign in with Apple
- Create onboarding flow
- Set up user profile management

### Phase 3: Family Management
- Implement family creation with code generation
- Add family joining functionality
- Create QR code generation and scanning

### Phase 4: Role Management
- Implement role selection and validation
- Add role change functionality for admins
- Create member management features

### Phase 5: Dashboard & Polish
- Complete family dashboard
- Add real-time sync and conflict resolution
- Implement comprehensive error handling and testing