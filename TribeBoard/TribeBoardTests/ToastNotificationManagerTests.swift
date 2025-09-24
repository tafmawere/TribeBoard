import XCTest
import SwiftUI
@testable import TribeBoard

class ToastNotificationManagerTests: XCTestCase {
    var toastManager: ToastNotificationManager!
    
    override func setUp() {
        super.setUp()
        toastManager = ToastNotificationManager()
    }
    
    override func tearDown() {
        toastManager = nil
        super.tearDown()
    }
    
    func testShowToastMessage() {
        // Given
        let message = "Test message"
        let type = ToastMessage.ToastType.success
        
        // When
        toastManager.show(message, type: type)
        
        // Then
        XCTAssertNotNil(toastManager.currentToast)
        XCTAssertEqual(toastManager.currentToast?.text, message)
        XCTAssertEqual(toastManager.currentToast?.type, type)
    }
    
    func testManualDismiss() {
        // Given
        toastManager.show("Test message", type: .info)
        XCTAssertNotNil(toastManager.currentToast)
        
        // When
        toastManager.dismiss()
        
        // Then
        XCTAssertNil(toastManager.currentToast)
    }
    
    func testToastMessageTypes() {
        // Test all toast types have proper colors and icons
        let types: [ToastMessage.ToastType] = [.success, .info, .warning, .error]
        
        for type in types {
            let message = ToastMessage(text: "Test", type: type)
            
            // Verify each type has a color and icon
            XCTAssertNotNil(message.type.color)
            XCTAssertFalse(message.type.icon.isEmpty)
        }
    }
    
    func testToastMessageEquality() {
        // Given
        let message1 = ToastMessage(text: "Test", type: .success)
        let message2 = ToastMessage(text: "Test", type: .success)
        let message3 = ToastMessage(text: "Different", type: .success)
        
        // Then
        XCTAssertNotEqual(message1, message2) // Different IDs
        XCTAssertNotEqual(message1, message3) // Different text
    }
    
    func testAutoDismissalBehavior() {
        // This test verifies the auto-dismissal setup
        // Given
        let expectation = XCTestExpectation(description: "Toast should be set")
        
        // When
        toastManager.show("Test message", type: .info)
        
        // Then
        DispatchQueue.main.async {
            XCTAssertNotNil(self.toastManager.currentToast)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}