import SwiftUI
import CoreImage

/// Service for QR code generation using SwiftUI and CoreImage
class QRCodeService {
    
    // MARK: - Properties
    
    private let context = CIContext()
    
    // MARK: - QR Code Generation
    
    /// Generates a QR code SwiftUI Image from a string
    /// - Parameter string: String to encode in QR code
    /// - Returns: SwiftUI Image containing the QR code, or fallback image if generation fails
    func generateQRCode(from string: String) -> Image {
        return generateQRCodeImage(from: string, size: CGSize(width: 200, height: 200))
    }
    
    /// Generates a QR code SwiftUI Image from a string with specified size
    /// - Parameters:
    ///   - string: String to encode in QR code
    ///   - size: Desired size for the QR code image
    /// - Returns: SwiftUI Image containing the QR code, or fallback image if generation fails
    func generateQRCode(from string: String, size: CGSize) -> Image {
        return generateQRCodeImage(from: string, size: size)
    }
    
    // MARK: - Private Methods
    
    /// Core implementation of QR code generation using CoreImage pipeline
    /// - Parameters:
    ///   - string: String to encode in QR code
    ///   - size: Desired size for the QR code image
    /// - Returns: SwiftUI Image containing the QR code, or fallback image if generation fails
    private func generateQRCodeImage(from string: String, size: CGSize) -> Image {
        // Step 1: Comprehensive input validation and string-to-data conversion
        guard validateInput(string) else {
            return createFallbackImage(reason: "Invalid input string")
        }
        
        guard let inputData = convertStringToData(string) else {
            return createFallbackImage(reason: "String to data conversion failed")
        }
        
        // Step 2: Create CIFilter with comprehensive error handling
        guard let qrCodeFilter = createQRCodeFilter() else {
            return createFallbackImage(reason: "CIFilter creation failed")
        }
        
        // Step 3: Configure filter with error handling for parameter setting
        guard configureQRCodeFilter(qrCodeFilter, with: inputData) else {
            return createFallbackImage(reason: "Filter configuration failed")
        }
        
        // Step 4: Generate QR code image with output validation
        guard let qrCodeImage = generateQRCodeFromFilter(qrCodeFilter) else {
            return createFallbackImage(reason: "QR code generation failed")
        }
        
        // Step 5: Scale the QR code with error handling for transformation
        guard let scaledImage = scaleQRCodeImageSafely(qrCodeImage, to: size) else {
            return createFallbackImage(reason: "Image scaling failed")
        }
        
        // Step 6: Convert to SwiftUI Image with comprehensive error handling
        return convertToSwiftUIImageSafely(scaledImage)
    }
    
    // MARK: - Input Validation and Data Conversion
    
    /// Validates input string for QR code generation
    /// - Parameter string: Input string to validate
    /// - Returns: True if string is valid for QR code generation
    private func validateInput(_ string: String) -> Bool {
        // Check for empty or whitespace-only strings
        guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        
        // Check for reasonable string length (QR codes have practical limits)
        guard string.count <= 4296 else { // QR code maximum capacity for alphanumeric
            return false
        }
        
        return true
    }
    
    /// Safely converts string to UTF-8 data with error handling
    /// - Parameter string: Input string to convert
    /// - Returns: UTF-8 data or nil if conversion fails
    private func convertStringToData(_ string: String) -> Data? {
        // Attempt UTF-8 conversion with fallback handling
        guard let data = string.data(using: .utf8) else {
            // Try alternative encodings if UTF-8 fails
            return string.data(using: .ascii) ?? string.data(using: .isoLatin1)
        }
        
        // Validate data is not empty
        guard !data.isEmpty else {
            return nil
        }
        
        return data
    }
    
    // MARK: - Filter Creation and Configuration
    
    /// Creates QR code filter with comprehensive error handling
    /// - Returns: Configured CIFilter or nil if creation fails
    private func createQRCodeFilter() -> CIFilter? {
        // Primary attempt with CIQRCodeGenerator
        return CIFilter(name: "CIQRCodeGenerator")
    }
    
    /// Configures QR code filter with input data and error correction
    /// - Parameters:
    ///   - filter: CIFilter to configure
    ///   - data: Input data for QR code
    /// - Returns: True if configuration succeeds
    private func configureQRCodeFilter(_ filter: CIFilter, with data: Data) -> Bool {
        // Set input message with error handling
        filter.setValue(data, forKey: "inputMessage")
        
        // Verify the input was set correctly
        guard filter.value(forKey: "inputMessage") != nil else {
            return false
        }
        
        // Set error correction level with fallback options
        let correctionLevels = ["M", "L", "Q", "H"] // Medium, Low, Quartile, High
        for level in correctionLevels {
            filter.setValue(level, forKey: "inputCorrectionLevel")
            if filter.value(forKey: "inputCorrectionLevel") != nil {
                break
            }
        }
        
        return true
    }
    
    // MARK: - Image Generation and Processing
    
    /// Generates QR code image from configured filter
    /// - Parameter filter: Configured CIFilter
    /// - Returns: Generated CIImage or nil if generation fails
    private func generateQRCodeFromFilter(_ filter: CIFilter) -> CIImage? {
        guard let outputImage = filter.outputImage else {
            return nil
        }
        
        // Validate the output image has reasonable dimensions
        let extent = outputImage.extent
        guard extent.width > 0 && extent.height > 0 && 
              !extent.width.isInfinite && !extent.height.isInfinite &&
              !extent.width.isNaN && !extent.height.isNaN else {
            return nil
        }
        
        return outputImage
    }
    
    /// Safely scales QR code image with comprehensive error handling
    /// - Parameters:
    ///   - ciImage: Source CIImage from QR code generation
    ///   - size: Target size for the QR code
    /// - Returns: Scaled CIImage or nil if scaling fails
    private func scaleQRCodeImageSafely(_ ciImage: CIImage, to size: CGSize) -> CIImage? {
        // Validate input parameters
        guard size.width > 0 && size.height > 0 else {
            return nil
        }
        
        let imageSize = ciImage.extent.size
        guard imageSize.width > 0 && imageSize.height > 0 else {
            return nil
        }
        
        // Calculate scale factors with bounds checking
        let scaleX = size.width / imageSize.width
        let scaleY = size.height / imageSize.height
        let scale = min(scaleX, scaleY) // Maintain aspect ratio
        
        // Ensure scale is reasonable (not too small or too large)
        guard scale > 0.1 && scale < 100.0 else {
            return nil
        }
        
        // Apply transformation with error handling
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = ciImage.transformed(by: transform)
        
        // Validate the transformed image
        let scaledExtent = scaledImage.extent
        guard !scaledExtent.width.isInfinite && !scaledExtent.height.isInfinite &&
              !scaledExtent.width.isNaN && !scaledExtent.height.isNaN else {
            return nil
        }
        
        return scaledImage
    }
    
    /// Safely converts CIImage to SwiftUI Image with comprehensive error handling
    /// - Parameter ciImage: Source CIImage to convert
    /// - Returns: SwiftUI Image or fallback image if conversion fails
    private func convertToSwiftUIImageSafely(_ ciImage: CIImage) -> Image {
        // Validate input image
        let extent = ciImage.extent
        guard !extent.width.isInfinite && !extent.height.isInfinite &&
              !extent.width.isNaN && !extent.height.isNaN &&
              !extent.isEmpty else {
            return createFallbackImage(reason: "Invalid CIImage extent")
        }
        
        // Attempt CGImage conversion with multiple strategies
        if let cgImage = createCGImageSafely(from: ciImage) {
            // Convert CGImage to SwiftUI Image with proper labeling for accessibility
            return Image(cgImage, scale: 1.0, label: Text("QR Code"))
        }
        
        return createFallbackImage(reason: "CGImage conversion failed")
    }
    
    /// Creates CGImage from CIImage with multiple fallback strategies
    /// - Parameter ciImage: Source CIImage
    /// - Returns: CGImage or nil if all conversion attempts fail
    private func createCGImageSafely(from ciImage: CIImage) -> CGImage? {
        let extent = ciImage.extent
        
        // Primary conversion attempt with current context
        if let cgImage = context.createCGImage(ciImage, from: extent) {
            return cgImage
        }
        
        // Fallback: Try with a new context
        let fallbackContext = CIContext(options: [.useSoftwareRenderer: true])
        if let cgImage = fallbackContext.createCGImage(ciImage, from: extent) {
            return cgImage
        }
        
        // Final fallback: Try with minimal options
        let minimalContext = CIContext()
        return minimalContext.createCGImage(ciImage, from: extent)
    }
    
    // MARK: - Fallback Mechanisms
    
    /// Creates a fallback image for error states with optional reason logging
    /// - Parameter reason: Optional reason for fallback (for debugging)
    /// - Returns: SwiftUI system image indicating QR generation failure
    private func createFallbackImage(reason: String? = nil) -> Image {
        // Log the reason for debugging purposes (in debug builds only)
        #if DEBUG
        if let reason = reason {
            print("QRCodeService fallback triggered: \(reason)")
        }
        #endif
        
        // Return appropriate fallback image
        return Image(systemName: "xmark.circle")
    }
    
    /// Alternative fallback images for different error scenarios
    /// - Parameter errorType: Type of error that occurred
    /// - Returns: Contextually appropriate fallback image
    private func createContextualFallbackImage(for errorType: QRGenerationError) -> Image {
        switch errorType {
        case .invalidInput:
            return Image(systemName: "exclamationmark.triangle")
        case .filterCreationFailed:
            return Image(systemName: "gear.badge.xmark")
        case .imageProcessingFailed:
            return Image(systemName: "photo.badge.exclamationmark")
        case .conversionFailed:
            return Image(systemName: "arrow.triangle.2.circlepath")
        case .unknown:
            return Image(systemName: "xmark.circle")
        }
    }
}

// MARK: - Error Types

/// Enumeration of possible QR code generation errors for better error handling
private enum QRGenerationError {
    case invalidInput
    case filterCreationFailed
    case imageProcessingFailed
    case conversionFailed
    case unknown
}
