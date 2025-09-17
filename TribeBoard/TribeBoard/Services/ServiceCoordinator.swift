import Foundation
import SwiftData

/// Coordinates services and provides dependency injection for ViewModels
@MainActor
class ServiceCoordinator: ObservableObject {
    
    // MARK: - Services
    
    let dataService: DataService
    let cloudKitService: CloudKitService
    let authService: AuthService
    let qrCodeService: QRCodeService
    let codeGenerator: CodeGenerator
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.dataService = DataService(modelContext: modelContext)
        self.cloudKitService = CloudKitService()
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
            dataService: dataService,
            cloudKitService: cloudKitService,
            qrCodeService: qrCodeService,
            codeGenerator: codeGenerator
        )
    }
    
    /// Creates JoinFamilyViewModel with proper dependencies
    func joinFamilyViewModel() -> JoinFamilyViewModel {
        return JoinFamilyViewModel(
            dataService: dataService,
            cloudKitService: cloudKitService,
            qrCodeService: qrCodeService
        )
    }
    
    /// Creates RoleSelectionViewModel with proper dependencies
    func roleSelectionViewModel(family: Family, user: UserProfile) -> RoleSelectionViewModel {
        return RoleSelectionViewModel(
            family: family,
            user: user,
            dataService: dataService,
            cloudKitService: cloudKitService
        )
    }
    
    /// Creates FamilyDashboardViewModel with proper dependencies
    func familyDashboardViewModel(family: Family, currentUserId: UUID, currentUserRole: Role) -> FamilyDashboardViewModel {
        return FamilyDashboardViewModel(
            family: family,
            currentUserId: currentUserId,
            currentUserRole: currentUserRole,
            dataService: dataService,
            cloudKitService: cloudKitService
        )
    }
}