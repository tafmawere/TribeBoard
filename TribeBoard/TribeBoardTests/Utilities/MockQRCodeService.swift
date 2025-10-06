import Foundation
import SwiftUI
@testable import TribeBoard

/// Mock implementation of QRCodeService for testing purposes
/// Provides configurable QR code generation and error scenarios
@MainActor
class MockQRCodeService: ObservableObject {
    
    // MARK: - Configuration Properties
    
    /// Controls whether QR code generation should succeed
    var shouldSucceed: Bool = true
    
    /// The error to throw when operations fail
    var errorToThrow: QRCodeError = .generationFailed
    
    /// Mock QR code image to return
    var mockQRImage: Image?
    
    /// Delay to simulate async operations
    var simulatedDelay: TimeInterval = 0.05
    
    // MARK: - Call Tracking
    
    private(set) var generateQRCodeCallCount = 0
    private(set) var lastGeneratedText: String?
    
    // MARK: - Mock Data
    
    /// Default mock QR code image
    private let defaultMockImage = Image(systemName: "qrcode")
    
    // MARK: - Initialization
    
    init() {
        mockQRImage = defaultMockImage
    }
    
    // MARK: - Test Configuration Methods
    
    /// Reset the mock to its default state
    func reset() {
        shouldSucceed = true
        errorToThrow = .generationFailed
        mockQRImage = defaultMockImage
        simulatedDelay = 0.05
        
        // Reset call tracking
        generateQRCodeCallCount = 0
        lastGeneratedText = nil
    }
    
    /// Configure the mock to fail
    /// - Parameter error: The error to throw when operations fail
    func setError(_ error: QRCodeError) {
        errorToThrow = error
        shouldSucceed = false
    }
    
    /// Set the mock QR code image to return
    /// - Parameter image: The image to return
    func setMockQRImage(_ image: Image) {
        mockQRImage = image
    }
    
    /// Set whether operations should succeed
    /// - Parameter succeed: Whether operations should succeed
    func setShouldSucceed(_ succeed: Bool) {
        shouldSucceed = succeed
    }
    
    /// Set the simulated delay for async operations
    /// - Parameter delay: The delay in seconds
    func setSimulatedDelay(_ delay: TimeInterval) {
        simulatedDelay = delay
    }
    
    // MARK: - Private Helper Methods
    
    private func simulateDelay() async {
        if simulatedDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
    }
    
    // MARK: - QRCodeService Interface Implementation
    
    /// Mock implementation of generateQRCode
    /// - Parameter text: The text to encode in the QR code
    /// - Returns: A mock QR code image
    /// - Throws: QRCodeError if configured to fail
    func generateQRCode(from text: String) async throws -> Image {
        generateQRCodeCallCount += 1
        lastGeneratedText = text
        
        await simulateDelay()
        
        if !shouldSucceed {
            throw errorToThrow
        }
        
        guard let qrImage = mockQRImage else {
            throw QRCodeError.generationFailed
        }
        
        return qrImage
    }
    
    /// Mock implementation of generateQRCode with size
    /// - Parameters:
    ///   - text: The text to encode in the QR code
    ///   - size: The desired size of the QR code (ignored in mock)
    /// - Returns: A mock QR code image
    /// - Throws: QRCodeError if configured to fail
    func generateQRCode(from text: String, size: CGSize) async throws -> Image {
        // For mock purposes, size is ignored
        return try await generateQRCode(from: text)
    }
    
    /// Mock implementation of generateQRCodeData
    /// - Parameter text: The text to encode in the QR code
    /// - Returns: Mock QR code data
    /// - Throws: QRCodeError if configured to fail
    func generateQRCodeData(from text: String) async throws -> Data {
        generateQRCodeCallCount += 1
        lastGeneratedText = text
        
        await simulateDelay()
        
        if !shouldSucceed {
            throw errorToThrow
        }
        
        // Return mock data
        return "mock_qr_code_data_\(text)".data(using: .utf8) ?? Data()
    }
    
    // MARK: - Test Utility Methods
    
    /// Get call counts for test verification
    /// - Returns: Dictionary of operation names to call counts
    func getCallCounts() -> [String: Int] {
        return [
            "generateQRCode": generateQRCodeCallCount
        ]
    }
    
    /// Check if QR code was generated for specific text
    /// - Parameter text: The expected text
    /// - Returns: True if QR code was generated for the text
    func wasQRCodeGenerated(for text: String) -> Bool {
        return lastGeneratedText == text
    }
    
    /// Get the last text that was used to generate a QR code
    /// - Returns: The last generated text, or nil if none
    func getLastGeneratedText() -> String? {
        return lastGeneratedText
    }
    
    /// Simulate QR code generation failure
    /// - Parameter error: The error to simulate
    func simulateGenerationFailure(with error: QRCodeError) {
        setError(error)
    }
    
    /// Simulate successful QR code generation
    /// - Parameter image: The image to return on success
    func simulateGenerationSuccess(with image: Image) {
        setMockQRImage(image)
        setShouldSucceed(true)
    }
    
    /// Create a mock QR code image with specific system name
    /// - Parameter systemName: The SF Symbol name to use
    /// - Returns: A mock image
    static func createMockImage(systemName: String = "qrcode") -> Image {
        return Image(systemName: systemName)
    }
    
    /// Create mock QR code data
    /// - Parameter text: The text to encode in mock data
    /// - Returns: Mock data representing the QR code
    static func createMockData(for text: String) -> Data {
        return "mock_qr_\(text)_\(UUID().uuidString.prefix(8))".data(using: .utf8) ?? Data()
    }
}

// MARK: - QRCodeError Definition

enum QRCodeError: LocalizedError {
    case generationFailed
    case invalidInput
    case encodingFailed
    case imageTooLarge
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "Failed to generate QR code"
        case .invalidInput:
            return "Invalid input for QR code generation"
        case .encodingFailed:
            return "Failed to encode text in QR code"
        case .imageTooLarge:
            return "Generated QR code image is too large"
        case .unsupportedFormat:
            return "Unsupported QR code format"
        }
    }
}

// MARK: - Test Scenarios

extension MockQRCodeService {
    
    /// Configure for successful QR code generation
    func configureForSuccess() {
        reset()
        setShouldSucceed(true)
        setMockQRImage(Self.createMockImage())
    }
    
    /// Configure for QR code generation failure
    func configureForFailure(error: QRCodeError = .generationFailed) {
        reset()
        setError(error)
    }
    
    /// Configure for performance testing
    func configureForPerformanceTest() {
        reset()
        setSimulatedDelay(0.001) // Very small delay for performance tests
    }
    
    /// Configure for slow network simulation
    func configureForSlowGeneration() {
        reset()
        setSimulatedDelay(2.0) // 2 second delay to simulate slow generation
    }
}