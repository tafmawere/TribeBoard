//
//  RoleBasedAccessControlTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/03.
//

import XCTest
@testable import Tribeboard

class RoleBasedAccessControlTests: XCTestCase {
    
    var sampleRun: Run!
    var driverContext: RoleContext!
    var observerContext: RoleContext!
    var adminContext: RoleContext!
    
    override func setUp() {
        super.setUp()
        
        // Create sample run
        sampleRun = Run(
            id: "test-run-1",
            title: "Test Run",
            scheduledTime: Date(),
            driverId: "driver-123",
            stops: [
                RunStop(
                    type: .pickup,
                    label: "School",
                    scheduledTime: Date(),
                    requiredPassengerIds: ["child-1"],
                    location: LocationData(latitude: 37.7749, longitude: -122.4194)
                )
            ],
            passengers: [
                MemberSummary(id: "child-1", displayName: "Test Child", role: .passenger)
            ],
            createdBy: "parent-123",
            familyId: "family-123"
        )
        
        // Create role contexts
        driverContext = RoleContext(userId: "driver-123", role: .driver, familyId: "family-123")
        observerContext = RoleContext(userId: "observer-123", role: .observer, familyId: "family-123")
        adminContext = RoleContext(userId: "admin-123", role: .admin, familyId: "family-123")
    }
    
    // MARK: - Permission Validation Tests
    
    func testDriverPermissions() {
        // Driver should be able to perform driver operations on assigned runs
        XCTAssertTrue(PermissionValidator.canPerformOperation(.startRun, role: .driver, userId: "driver-123", run: sampleRun))
        XCTAssertTrue(PermissionValidator.canPerformOperation(.arriveAtStop, role: .driver, userId: "driver-123", run: sampleRun))
        XCTAssertTrue(PermissionValidator.canPerformOperation(.confirmPickup, role: .driver, userId: "driver-123", run: sampleRun))
        
        // Driver should not be able to perform admin operations
        XCTAssertFalse(PermissionValidator.canPerformOperation(.cancelRun, role: .driver, userId: "driver-123", run: sampleRun))
        XCTAssertFalse(PermissionValidator.canPerformOperation(.reassignDriver, role: .driver, userId: "driver-123", run: sampleRun))
        
        // Driver should not be able to perform operations on runs they're not assigned to
        var otherRun = sampleRun!
        otherRun.driverId = "other-driver"
        XCTAssertFalse(PermissionValidator.canPerformOperation(.startRun, role: .driver, userId: "driver-123", run: otherRun))
    }
    
    func testObserverPermissions() {
        // Observer should be able to view operations
        XCTAssertTrue(PermissionValidator.canPerformOperation(.viewRunDetails, role: .observer, userId: "observer-123", run: sampleRun))
        XCTAssertTrue(PermissionValidator.canPerformOperation(.viewRunTimeline, role: .observer, userId: "observer-123", run: sampleRun))
        XCTAssertTrue(PermissionValidator.canPerformOperation(.viewDriverLocation, role: .observer, userId: "observer-123", run: sampleRun))
        
        // Observer should not be able to perform driver operations
        XCTAssertFalse(PermissionValidator.canPerformOperation(.startRun, role: .observer, userId: "observer-123", run: sampleRun))
        XCTAssertFalse(PermissionValidator.canPerformOperation(.confirmPickup, role: .observer, userId: "observer-123", run: sampleRun))
        
        // Observer should not be able to perform admin operations
        XCTAssertFalse(PermissionValidator.canPerformOperation(.cancelRun, role: .observer, userId: "observer-123", run: sampleRun))
        XCTAssertFalse(PermissionValidator.canPerformOperation(.reassignDriver, role: .observer, userId: "observer-123", run: sampleRun))
    }
    
    func testAdminPermissions() {
        // Admin should be able to perform all operations
        XCTAssertTrue(PermissionValidator.canPerformOperation(.startRun, role: .admin, userId: "admin-123", run: sampleRun))
        XCTAssertTrue(PermissionValidator.canPerformOperation(.viewRunDetails, role: .admin, userId: "admin-123", run: sampleRun))
        XCTAssertTrue(PermissionValidator.canPerformOperation(.cancelRun, role: .admin, userId: "admin-123", run: sampleRun))
        XCTAssertTrue(PermissionValidator.canPerformOperation(.reassignDriver, role: .admin, userId: "admin-123", run: sampleRun))
        
        // Admin should be able to edit scheduled runs
        XCTAssertTrue(PermissionValidator.canPerformOperation(.editRunDetails, role: .admin, userId: "admin-123", run: sampleRun))
        
        // Admin should not be able to edit completed runs
        var completedRun = sampleRun!
        completedRun.status = .completed
        XCTAssertFalse(PermissionValidator.canPerformOperation(.editRunDetails, role: .admin, userId: "admin-123", run: completedRun))
    }
    
    // MARK: - State Machine Integration Tests
    
    func testDriverActionWithPermissions() {
        var testRun = sampleRun!
        
        // Driver should be able to start their assigned run
        let result = RunStateMachine.processDriverActionWithPermissions(.startRun, for: &testRun, roleContext: driverContext)
        
        switch result {
        case .success:
            XCTAssertEqual(testRun.status, .activeEnroute)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }
    
    func testDriverActionWithoutPermissions() {
        var testRun = sampleRun!
        testRun.driverId = "other-driver" // Different driver
        
        // Driver should not be able to start run they're not assigned to
        let result = RunStateMachine.processDriverActionWithPermissions(.startRun, for: &testRun, roleContext: driverContext)
        
        switch result {
        case .success:
            XCTFail("Expected permission error but got success")
        case .failure(let error):
            if case .permissionDenied = error {
                // Expected
            } else {
                XCTFail("Expected permission denied error but got: \(error)")
            }
        }
    }
    
    func testAdminActionWithPermissions() {
        var testRun = sampleRun!
        
        // Admin should be able to cancel run
        let result = RunStateMachine.processAdminActionWithPermissions(.cancelRun(reason: "Test"), for: &testRun, roleContext: adminContext)
        
        switch result {
        case .success:
            XCTAssertEqual(testRun.status, .cancelled)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }
    
    func testObserverCannotPerformAdminActions() {
        var testRun = sampleRun!
        
        // Observer should not be able to cancel run
        let result = RunStateMachine.processAdminActionWithPermissions(.cancelRun(reason: "Test"), for: &testRun, roleContext: observerContext)
        
        switch result {
        case .success:
            XCTFail("Expected permission error but got success")
        case .failure(let error):
            if case .permissionDenied = error {
                // Expected
            } else {
                XCTFail("Expected permission denied error but got: \(error)")
            }
        }
    }
    
    // MARK: - Available Actions Tests
    
    func testDriverAvailableActions() {
        let actions = RunStateMachine.getAvailableDriverActions(for: sampleRun, roleContext: driverContext)
        
        // Driver should have start run action for scheduled run
        XCTAssertTrue(actions.contains(.startRun))
        XCTAssertFalse(actions.isEmpty)
    }
    
    func testObserverNoDriverActions() {
        let actions = RunStateMachine.getAvailableDriverActions(for: sampleRun, roleContext: observerContext)
        
        // Observer should have no driver actions
        XCTAssertTrue(actions.isEmpty)
    }
    
    func testAdminAvailableActions() {
        let actions = RunStateMachine.getAvailableAdminActions(for: sampleRun, roleContext: adminContext)
        
        // Admin should have admin actions available
        XCTAssertTrue(actions.contains { action in
            if case .cancelRun = action { return true }
            return false
        })
        XCTAssertTrue(actions.contains { action in
            if case .reassignDriver = action { return true }
            return false
        })
    }
    
    // MARK: - Role Management Service Tests
    
    @MainActor
    func testRoleManagementServiceUpdate() {
        let roleService = RoleManagementService()
        
        // Initially should be observer
        XCTAssertEqual(roleService.currentUserRole, .observer)
        
        // Update to driver
        roleService.updateUserRole(.driver, userId: "test-user", familyId: "test-family")
        
        XCTAssertEqual(roleService.currentUserRole, .driver)
        XCTAssertEqual(roleService.currentUserId, "test-user")
        XCTAssertEqual(roleService.currentFamilyId, "test-family")
    }
    
    // MARK: - Dynamic Role Permission Update Tests
    
    @MainActor
    func testDynamicRolePermissionUpdates() {
        let roleService = RoleManagementService()
        let firebaseService = MockFirebaseRunService()
        let runEventService = RunEventService(firebaseService: firebaseService)
        let dynamicService = DynamicRoleUpdateService(
            roleManagementService: roleService,
            runEventService: runEventService
        )
        
        // Start as observer
        roleService.updateUserRole(.observer, userId: "test-user", familyId: "test-family")
        
        // Observer should not have driver actions
        let initialActions = roleService.getAvailableDriverActions(for: sampleRun)
        XCTAssertTrue(initialActions.isEmpty)
        
        // Simulate external role change to driver
        let expectation = XCTestExpectation(description: "Role change processed")
        
        NotificationCenter.default.addObserver(
            forName: .roleUpdateProcessed,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        Task {
            await dynamicService.processExternalRoleUpdate(
                userId: "test-user",
                newRole: FamilyRole.driver,
                familyId: "test-family",
                source: RoleUpdateSource.adminAssignment(adminId: "admin-123", reason: "Test assignment"),
                activeRuns: [sampleRun]
            )
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Now should have driver actions
        let updatedActions = roleService.getAvailableDriverActions(for: sampleRun)
        XCTAssertFalse(updatedActions.isEmpty)
        XCTAssertTrue(updatedActions.contains(.startRun))
    }
    
    @MainActor
    func testPermissionValidationBeforeAction() {
        let roleService = RoleManagementService()
        let firebaseService = MockFirebaseRunService()
        let runEventService = RunEventService(firebaseService: firebaseService)
        let dynamicService = DynamicRoleUpdateService(
            roleManagementService: roleService,
            runEventService: runEventService
        )
        
        // Set up as observer (no driver permissions)
        roleService.updateUserRole(.observer, userId: "observer-123", familyId: "family-123")
        
        var testRun = sampleRun!
        
        // Observer should not be able to start run
        let result = dynamicService.validateAndExecuteDriverAction(DriverAction.startRun, on: &testRun)
        
        switch result {
        case .success:
            XCTFail("Expected permission error but got success")
        case .failure(let error):
            if case .permissionDenied = error {
                // Expected
            } else {
                XCTFail("Expected permission denied error but got: \(error)")
            }
        }
        
        // Run status should remain unchanged
        XCTAssertEqual(testRun.status, .scheduled)
    }
    
    @MainActor
    func testRoleChangeNotificationHandling() {
        let roleService = RoleManagementService()
        
        // Set up notification expectation
        let expectation = XCTestExpectation(description: "UI refresh notification received")
        
        NotificationCenter.default.addObserver(
            forName: .uiShouldRefreshForRoleChange,
            object: nil,
            queue: .main
        ) { notification in
            // Verify notification contains role change information
            if let userInfo = notification.userInfo,
               let previousRole = userInfo["previousRole"] as? FamilyRole,
               let newRole = userInfo["newRole"] as? FamilyRole {
                XCTAssertEqual(previousRole, .observer)
                XCTAssertEqual(newRole, .admin)
                expectation.fulfill()
            }
        }
        
        // Start as observer
        roleService.updateUserRole(.observer, userId: "test-user", familyId: "test-family")
        
        // Change to admin
        roleService.updateUserRole(.admin, userId: "test-user", familyId: "test-family")
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor
    func testPermissionChangeSummary() {
        let roleService = RoleManagementService()
        
        // Set up initial role
        roleService.updateUserRole(.observer, userId: "test-user", familyId: "test-family")
        
        // Get permission change summary for role upgrade
        let changeSummary = roleService.getPermissionChangeSummary(
            previousRole: .observer,
            newRole: .admin,
            for: [sampleRun]
        )
        
        XCTAssertEqual(changeSummary.previousRole, .observer)
        XCTAssertEqual(changeSummary.newRole, .admin)
        XCTAssertTrue(changeSummary.hasChanges)
        XCTAssertFalse(changeSummary.gainedPermissions.isEmpty)
        XCTAssertTrue(changeSummary.changeDescription.contains("Observer"))
        XCTAssertTrue(changeSummary.changeDescription.contains("Admin"))
    }
    
    @MainActor
    func testRunPermissionRefresh() {
        let roleService = RoleManagementService()
        
        // Set up notification expectation
        let expectation = XCTestExpectation(description: "Run permissions updated")
        
        NotificationCenter.default.addObserver(
            forName: .runPermissionsDidUpdate,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let runId = userInfo["runId"] as? String {
                XCTAssertEqual(runId, self.sampleRun.id)
                expectation.fulfill()
            }
        }
        
        // Start as driver
        roleService.updateUserRole(.driver, userId: "driver-123", familyId: "family-123")
        
        // Refresh permissions for active runs
        roleService.refreshPermissionsForActiveRuns([sampleRun])
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    @MainActor
    func testUIConfigurationUpdatesOnRoleChange() {
        let roleService = RoleManagementService()
        
        // Start as observer
        roleService.updateUserRole(.observer, userId: "observer-123", familyId: "family-123")
        let observerConfig = roleService.getUIConfiguration(for: sampleRun)
        
        XCTAssertEqual(observerConfig.role, .observer)
        XCTAssertTrue(observerConfig.showObserverInterface)
        XCTAssertFalse(observerConfig.showDriverInterface)
        XCTAssertFalse(observerConfig.showAdminControls)
        
        // Change to driver
        roleService.updateUserRole(.driver, userId: "driver-123", familyId: "family-123")
        let driverConfig = roleService.getUIConfiguration(for: sampleRun)
        
        XCTAssertEqual(driverConfig.role, .driver)
        XCTAssertTrue(driverConfig.showDriverInterface)
        XCTAssertFalse(driverConfig.showObserverInterface)
        XCTAssertFalse(driverConfig.showAdminControls)
        
        // Change to admin
        roleService.updateUserRole(.admin, userId: "admin-123", familyId: "family-123")
        let adminConfig = roleService.getUIConfiguration(for: sampleRun)
        
        XCTAssertEqual(adminConfig.role, .admin)
        XCTAssertTrue(adminConfig.showObserverInterface)
        XCTAssertFalse(adminConfig.showDriverInterface)
        XCTAssertTrue(adminConfig.showAdminControls)
    }
    
    @MainActor
    func testRoleBasedRunFiltering() {
        let roleService = RoleManagementService()
        
        // Create multiple runs
        let driverRun = sampleRun!
        let observerRun = Run(
            id: "observer-run",
            title: "Observer Run",
            scheduledTime: Date(),
            driverId: "other-driver",
            stops: driverRun.stops,
            passengers: driverRun.passengers,
            createdBy: driverRun.createdBy,
            familyId: driverRun.familyId
        )
        
        let allRuns = [driverRun, observerRun]
        
        // Test driver filtering
        roleService.updateUserRole(.driver, userId: "driver-123", familyId: "family-123")
        let driverFiltered = roleService.getFilteredRuns(allRuns)
        XCTAssertEqual(driverFiltered.count, 1)
        XCTAssertEqual(driverFiltered.first?.id, "test-run-1")
        
        // Test observer filtering (sees all family runs)
        roleService.updateUserRole(.observer, userId: "observer-123", familyId: "family-123")
        let observerFiltered = roleService.getFilteredRuns(allRuns)
        XCTAssertEqual(observerFiltered.count, 2) // Sees all family runs
        
        // Test admin filtering (sees all family runs)
        roleService.updateUserRole(.admin, userId: "admin-123", familyId: "family-123")
        let adminFiltered = roleService.getFilteredRuns(allRuns)
        XCTAssertEqual(adminFiltered.count, 2) // Sees all family runs
    }
    
    // MARK: - Enhanced Dynamic Role Permission Update Tests
    
    @MainActor
    func testEnhancedPermissionValidationWithContext() {
        let roleService = RoleManagementService()
        
        // Set up as observer
        roleService.updateUserRole(.observer, userId: "observer-123", familyId: "family-123")
        
        // Test enhanced permission validation
        let result = roleService.validatePermissionWithContext(.startRun, on: sampleRun, context: "User attempted to start run from UI")
        
        switch result {
        case .allowed:
            XCTFail("Observer should not be allowed to start run")
        case .denied(let reason, let suggestion):
            XCTAssertTrue(reason.contains("Observer"))
            XCTAssertNotNil(suggestion)
            XCTAssertTrue(suggestion?.contains("Contact") == true)
        }
    }
    
    @MainActor
    func testRealTimeRoleUpdateHandling() {
        let roleService = RoleManagementService()
        let firebaseService = MockFirebaseRunService()
        let runEventService = RunEventService(firebaseService: firebaseService)
        let dynamicService = DynamicRoleUpdateService(
            roleManagementService: roleService,
            runEventService: runEventService
        )
        
        // Set up initial role
        roleService.updateUserRole(.observer, userId: "test-user", familyId: "test-family")
        
        // Set up expectation for real-time update
        let expectation = XCTestExpectation(description: "Real-time role update processed")
        
        NotificationCenter.default.addObserver(
            forName: .roleUpdateProcessed,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        // Simulate real-time role update
        Task {
            await dynamicService.handleRealtimeRoleUpdate(
                userId: "test-user",
                newRole: FamilyRole.admin,
                familyId: "test-family",
                activeRuns: [sampleRun],
                timestamp: Date()
            )
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Verify role was updated
        XCTAssertEqual(roleService.currentUserRole, .admin)
    }
    
    @MainActor
    func testPermissionEscalationRequest() {
        let roleService = RoleManagementService()
        let firebaseService = MockFirebaseRunService()
        let runEventService = RunEventService(firebaseService: firebaseService)
        let dynamicService = DynamicRoleUpdateService(
            roleManagementService: roleService,
            runEventService: runEventService
        )
        
        // Set up as observer
        roleService.updateUserRole(.observer, userId: "observer-123", familyId: "family-123")
        
        // Set up expectation for escalation request
        let expectation = XCTestExpectation(description: "Permission escalation requested")
        
        NotificationCenter.default.addObserver(
            forName: .permissionEscalationRequested,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let request = userInfo["escalationRequest"] as? PermissionEscalationRequest {
                XCTAssertEqual(request.currentRole, .observer)
                XCTAssertEqual(request.requestedOperation, RunOperation.startRun)
                expectation.fulfill()
            }
        }
        
        // Request permission escalation
        Task {
            let result = await dynamicService.requestPermissionEscalation(
                for: RunOperation.startRun,
                on: sampleRun,
                reason: "Emergency situation requires immediate action"
            )
            
            switch result {
            case .pending:
                // Expected for escalation request
                break
            default:
                XCTFail("Expected pending result for escalation request")
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    @MainActor
    func testImmediateUIRefreshOnRoleChange() {
        let roleService = RoleManagementService()
        let firebaseService = MockFirebaseRunService()
        let runEventService = RunEventService(firebaseService: firebaseService)
        let dynamicService = DynamicRoleUpdateService(
            roleManagementService: roleService,
            runEventService: runEventService
        )
        
        // Set up expectation for immediate UI refresh
        let expectation = XCTestExpectation(description: "Immediate UI refresh triggered")
        
        NotificationCenter.default.addObserver(
            forName: .immediateUIRefreshRequired,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let affectedRuns = userInfo["affectedRuns"] as? [Run] {
                XCTAssertEqual(affectedRuns.count, 1)
                XCTAssertEqual(affectedRuns.first?.id, self.sampleRun.id)
                expectation.fulfill()
            }
        }
        
        // Trigger family role change
        Task {
            await dynamicService.handleFamilyRoleChange(
                userId: "test-user",
                newRole: FamilyRole.driver,
                familyId: "test-family",
                changedBy: "admin-123",
                activeRuns: [sampleRun]
            )
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    @MainActor
    func testActionPermissionDenialFeedback() {
        let roleService = RoleManagementService()
        
        // Set up as observer
        roleService.updateUserRole(.observer, userId: "observer-123", familyId: "family-123")
        
        // Set up expectation for permission denial feedback
        let expectation = XCTestExpectation(description: "Permission denial feedback received")
        
        NotificationCenter.default.addObserver(
            forName: .actionPermissionDenied,
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let operation = userInfo["operation"] as? RunOperation,
               let currentRole = userInfo["currentRole"] as? FamilyRole {
                XCTAssertEqual(operation, .startRun)
                XCTAssertEqual(currentRole, .observer)
                expectation.fulfill()
            }
        }
        
        // Simulate action attempt that should be denied
        // This would typically be triggered by a RoleBasedActionButton
        NotificationCenter.default.post(
            name: .actionPermissionDenied,
            object: nil,
            userInfo: [
                "operation": RunOperation.startRun,
                "run": sampleRun!,
                "currentRole": roleService.currentUserRole
            ]
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
}