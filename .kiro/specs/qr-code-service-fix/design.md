# Design Document

## Overview

The current QRCodeService has extensive UIKit dependencies that cause compilation errors on iOS Simulator and non-UIKit platforms. This design focuses on creating a pure SwiftUI + CoreImage implementation that eliminates UIKit dependencies while maintaining essential QR code generation functionality. The scanning functionality will be separated into a different service to maintain clean separation of concerns.

## Architecture

### Current Issues
- UIKit imports causing "No such module 'UIKit'" errors
- UIImage return types incompatible with SwiftUI
- UIGraphicsImageRenderer dependencies
- Mixed responsibilities (generation + scanning in one service)

### New Architecture
- **QRCodeService**: Pure SwiftUI + CoreImage QR generation service
- **QRScannerService**: Separate service for camera-based scanning (future implementation)
- Clean separation between generation and scanning concerns
- SwiftUI-native Image return types

## Components and Interfaces

### QRCodeService (Refactored)

```swift
import SwiftUI
import CoreImage

class QRCodeService {
    private let context = CIContext()
    
    // Primary interface - returns SwiftUI Image
    func generateQRCode(from string: String) -> Image
    
    // Optional: Advanced generation with size control
    func generateQRCode(from string: String, size: CGSize) -> Image
}
```

### Key Design Decisions

1. **SwiftUI Image Return Type**: Returns `SwiftUI.Image` instead of `UIImage` for direct SwiftUI integration
2. **CoreImage Only**: Uses `CoreImage.CIFilterBuiltins` and `CIContext` for QR generation
3. **Fallback Strategy**: Returns system image "xmark.circle" on generation failure
4. **Simplified API**: Single primary method `generateQRCode(from:) -> Image`
5. **No Scanning**: Camera scanning moved to separate future service

## Data Models

### Input/Output Types
- **Input**: `String` - text to encode in QR code
- **Output**: `SwiftUI.Image` - ready-to-use SwiftUI image
- **Fallback**: System image for error states

### Error Handling Strategy
- No throwing methods - graceful degradation with fallback images
- Silent failure handling with system fallback image
- Logging for debugging purposes (optional)

## Error Handling

### Generation Failures
1. **Invalid Input Data**: Return fallback image
2. **CIFilter Creation Failure**: Return fallback image  
3. **CoreImage Processing Failure**: Return fallback image
4. **CGImage Conversion Failure**: Return fallback image

### Fallback Image
- Use `Image(systemName: "xmark.circle")` as universal fallback
- Ensures UI never breaks due to QR generation failure
- Provides visual indication that QR generation failed

## Testing Strategy

### Unit Tests
1. **Successful Generation**: Test with valid string input
2. **Empty String Handling**: Verify fallback behavior
3. **Special Characters**: Test Unicode and special character handling
4. **Large Strings**: Test with long input strings
5. **Fallback Verification**: Ensure fallback image is returned on failure

### Integration Tests
1. **SwiftUI Integration**: Test in actual SwiftUI views
2. **Performance**: Verify generation speed for typical use cases
3. **Memory Usage**: Ensure no memory leaks in generation process

## Implementation Details

### CoreImage Pipeline
1. Convert string to UTF-8 data
2. Create CIFilter with "CIQRCodeGenerator"
3. Set input message and error correction level
4. Scale output image to desired size
5. Convert CIImage to CGImage to SwiftUI Image

### SwiftUI Integration
```swift
// Usage in SwiftUI views
struct QRCodeView: View {
    let familyCode: String
    private let qrService = QRCodeService()
    
    var body: some View {
        qrService.generateQRCode(from: familyCode)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}
```

### Removed Functionality
- Camera scanning (moved to future QRScannerService)
- Styled QR codes with UIGraphicsImageRenderer
- UIView-based preview functionality
- AVFoundation camera integration

### Migration Strategy
- Existing code using `generateQRCode()` will need minor updates
- Change from `UIImage?` to `SwiftUI.Image` return type
- Remove size parameter from basic usage (use default sizing)
- Update import statements to remove UIKit dependencies