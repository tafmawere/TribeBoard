# Requirements Document

## Introduction

The QRCodeService utility currently has UIKit dependencies that cause compilation errors when building for iOS Simulator or non-UIKit platforms. This creates build failures with "No such module 'UIKit'" errors. The service needs to be refactored to use only SwiftUI and CoreImage frameworks to ensure cross-platform compatibility and eliminate build issues.

## Requirements

### Requirement 1

**User Story:** As a developer, I want the QRCodeService to compile successfully on all iOS targets, so that the app builds without UIKit-related errors.

#### Acceptance Criteria

1. WHEN the app is built for iOS Simulator THEN the QRCodeService SHALL compile without "No such module 'UIKit'" errors
2. WHEN the QRCodeService is imported THEN it SHALL NOT include any UIKit dependencies
3. WHEN building for any iOS target THEN the QRCodeService SHALL use only SwiftUI and CoreImage frameworks

### Requirement 2

**User Story:** As a developer, I want a pure SwiftUI QR code generation function, so that I can easily integrate QR codes into any SwiftUI view without platform-specific code.

#### Acceptance Criteria

1. WHEN calling generateQRCode(from: String) THEN the service SHALL return a SwiftUI Image
2. WHEN the QR code generation succeeds THEN the service SHALL return a valid QR code image
3. WHEN QR code generation fails THEN the service SHALL return a system fallback image ("xmark.circle")
4. WHEN using the service in SwiftUI views THEN it SHALL work without any additional platform-specific imports

### Requirement 3

**User Story:** As a developer, I want the QRCodeService to use CoreImage for QR generation, so that it leverages Apple's built-in QR code generation capabilities efficiently.

#### Acceptance Criteria

1. WHEN generating QR codes THEN the service SHALL use CoreImage.CIFilterBuiltins
2. WHEN creating QR codes THEN the service SHALL use CIFilter for image generation
3. WHEN converting to SwiftUI Image THEN the service SHALL properly handle CoreImage to SwiftUI conversion

### Requirement 4

**User Story:** As a developer, I want the QRCodeService to be reusable across the app, so that any SwiftUI view can generate QR codes consistently.

#### Acceptance Criteria

1. WHEN implementing the service THEN it SHALL be placed in Utilities/QRCodeService.swift
2. WHEN using the service THEN it SHALL provide a clean, simple API for QR code generation
3. WHEN integrating with existing code THEN the service SHALL maintain backward compatibility with current usage patterns
4. WHEN the service is used THEN it SHALL handle edge cases gracefully without crashing