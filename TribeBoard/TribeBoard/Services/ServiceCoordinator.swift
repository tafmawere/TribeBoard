import Foundation
import SwiftData

/// Coordinates services and provides dependency injection for ViewModels
@MainActor
class ServiceCoordinator: ObservableObject {
    
    // MARK: - Services
    
    let dataService: DataService
    let cloudKitService: CloudKitService
    let syncManager: SyncManager
    let authService: AuthService
    let qrCodeService: QRCodeService
    let codeGenerator: CodeGenerator
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.dataService = DataService(modelContext: modelContext)
        self.cloudKitService = CloudKitService()
        self.syncManager = SyncManager(dataService: dataService, cloudKitService: cloudKitService)
        self.authService = AuthService()
        self.qrCodeService = QRCodeService()
        self.codeGenerator = CodeGenerator()
        
        // Set up service dependencies
        self.authService.setDataService(dataService)
        
        // Set up CloudKit
        Task {
            try? await cloudKitService.performInitialSetup()
        }
    }
    
    // MARK: - ViewModel Factory Methods
    
    /// Creates CreateFamilyViewModel with proper dependencies
    func createFamilyViewModel() -> CreateFamilyViewModel {
        return CreateFamilyViewModel(
            qrCodeService: qrCodeService
        )
    }
    
    /// Creates JoinFamilyViewModel with proper dependencies
    func joinFamilyViewModel() -> JoinFamilyViewModel {
        return JoinFamilyViewModel()
    }
    
    /// Creates RoleSelectionViewModel with proper dependencies (legacy method for CloudKit/DataService)
    func roleSelectionViewModel(family: Family, user: UserProfile) -> RoleSelectionViewModel {
        // For backward compatibility, create temporary in-memory models
        // This is a bridge method until full migration to in-memory storage
        let inMemoryFamily = InMemoryFamily(name: family.name, code: family.code)
        let inMemoryUser = InMemoryUser(name: user.displayName)
        
        return RoleSelectionViewModel(
            family: inMemoryFamily,
            user: inMemoryUser
        )
    }
    
    /// Creates RoleSelectionViewModel with in-memory models for SwiftUI compatibility
    func roleSelectionViewModel(family: InMemoryFamily, user: InMemoryUser) -> RoleSelectionViewModel {
        return RoleSelectionViewModel(
            family: family,
            user: user
        )
    }
    
    /// Creates FamilyDashboardViewModel with proper dependencies
    func familyDashboardViewModel(family: Family, currentUserId: UUID, currentUserRole: Role) -> FamilyDashboardViewModel {
        // For the enhanced in-memory version, we use the family ID instead of the full Family object
        return FamilyDashboardViewModel(
            familyId: family.id,
            currentUserId: currentUserId
        )
    }
}