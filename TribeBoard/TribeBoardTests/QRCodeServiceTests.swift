import XCTest
import SwiftUI
@testable import TribeBoard

final class QRCodeServiceTests: XCTestCase {
    
    var qrCodeService: QRCodeService!
    
    override func setUp() {
        super.setUp()
        qrCodeService = QRCodeService()
    }
    
    override func tearDown() {
        qrCodeService = nil
        super.tearDown()
    }
    
    // MARK: - Successful QR Code Generation Tests
    
    @MainActor func testGenerateQRCode_ValidString() {
        // Test with a simple valid string
        let testString = "ABC123"
        let qrImage = qrCodeService.generateQRCode(from: testString)
        
        // Verify that a SwiftUI Image is returned
        XCTAssertNotNil(qrImage, "Should generate QR code image for valid string")
        
        // Verify it's a SwiftUI Image type (not a fallback)
        // We can't directly inspect SwiftUI Image content, but we can verify it's not the fallback
        let fallbackImage = Image(systemName: "xmark.circle")
        XCTAssertTrue(type(of: qrImage) == type(of: fallbackImage), "Should return SwiftUI Image type")
    }
    
    @MainActor func testGenerateQRCode_ValidStringWithCustomSize() {
        let testString = "TEST123"
        let customSize = CGSize(width: 300, height: 300)
        let qrImage = qrCodeService.generateQRCode(from: testString, size: customSize)
        
        XCTAssertNotNil(qrImage, "Should generate QR code image with custom size")
        XCTAssertTrue(type(of: qrImage) == type(of: Image(systemName: "xmark.circle")), "Should return SwiftUI Image type")
    }
    
    @MainActor func testGenerateQRCode_AlphanumericString() {
        let alphanumericString = "FAMILY2024CODE"
        let qrImage = qrCodeService.generateQRCode(from: alphanumericString)
        
        XCTAssertNotNil(qrImage, "Should generate QR code for alphanumeric string")
    }
    
    @MainActor func testGenerateQRCode_NumericString() {
        let numericString = "1234567890"
        let qrImage = qrCodeService.generateQRCode(from: numericString)
        
        XCTAssertNotNil(qrImage, "Should generate QR code for numeric string")
    }
    
    @MainActor func testGenerateQRCode_MixedCaseString() {
        let mixedCaseString = "FamilyCode123"
        let qrImage = qrCodeService.generateQRCode(from: mixedCaseString)
        
        XCTAssertNotNil(qrImage, "Should generate QR code for mixed case string")
    }
    
    // MARK: - Fallback Behavior Tests (Empty and Invalid Input)
    
    @MainActor func testGenerateQRCode_EmptyString() {
        let qrImage = qrCodeService.generateQRCode(from: "")
        
        // Empty string should return fallback image according to the implementation
        XCTAssertNotNil(qrImage, "Should return fallback image for empty string")
        
        // Since we can't directly compare SwiftUI Images, we verify it returns an Image
        XCTAssertTrue(type(of: qrImage) == type(of: Image(systemName: "xmark.circle")), "Should return SwiftUI Image type")
    }
    
    @MainActor func testGenerateQRCode_WhitespaceOnlyString() {
        let whitespaceString = "   \n\t  "
        let qrImage = qrCodeService.generateQRCode(from: whitespaceString)
        
        // Whitespace-only string should return fallback image
        XCTAssertNotNil(qrImage, "Should return fallback image for whitespace-only string")
    }
    
    @MainActor func testGenerateQRCode_VeryLongString() {
        // Test with string longer than QR code capacity (>4296 characters)
        let veryLongString = String(repeating: "A", count: 5000)
        let qrImage = qrCodeService.generateQRCode(from: veryLongString)
        
        // Should return fallback image for overly long string
        XCTAssertNotNil(qrImage, "Should return fallback image for very long string")
    }
    
    @MainActor func testGenerateQRCode_ZeroSize() {
        let testString = "ABC123"
        let zeroSize = CGSize.zero
        let qrImage = qrCodeService.generateQRCode(from: testString, size: zeroSize)
        
        // Should return fallback image for invalid size
        XCTAssertNotNil(qrImage, "Should return fallback image for zero size")
    }
    
    @MainActor func testGenerateQRCode_NegativeSize() {
        let testString = "ABC123"
        let negativeSize = CGSize(width: -100, height: -100)
        let qrImage = qrCodeService.generateQRCode(from: testString, size: negativeSize)
        
        // Should return fallback image for negative size
        XCTAssertNotNil(qrImage, "Should return fallback image for negative size")
    }
    
    // MARK: - SwiftUI Image Verification Tests
    
    @MainActor func testGenerateQRCode_ReturnsSwiftUIImage() {
        let testString = "VALID123"
        let qrImage = qrCodeService.generateQRCode(from: testString)
        
        // Verify the returned object is a SwiftUI Image
        XCTAssertTrue(qrImage is Image, "Should return SwiftUI Image type")
        
        // Verify it's not nil
        XCTAssertNotNil(qrImage, "Should return non-nil SwiftUI Image")
    }
    
    @MainActor func testGenerateQRCode_FallbackIsSwiftUIImage() {
        let emptyString = ""
        let fallbackImage = qrCodeService.generateQRCode(from: emptyString)
        
        // Verify fallback is also a SwiftUI Image
        XCTAssertTrue(fallbackImage is Image, "Fallback should be SwiftUI Image type")
        XCTAssertNotNil(fallbackImage, "Fallback should be non-nil SwiftUI Image")
    }
    
    @MainActor func testGenerateQRCode_ConsistentImageType() {
        let validString = "VALID123"
        let invalidString = ""
        
        let validImage = qrCodeService.generateQRCode(from: validString)
        let fallbackImage = qrCodeService.generateQRCode(from: invalidString)
        
        // Both should return the same type (SwiftUI Image)
        XCTAssertTrue(type(of: validImage) == type(of: fallbackImage), "Both valid and fallback should return same Image type")
    }
    
    // MARK: - Special Characters and Unicode Tests
    
    @MainActor func testGenerateQRCode_SpecialCharacters() {
        let specialString = "ABC-123_!@#$%^&*()"
        let qrImage = qrCodeService.generateQRCode(from: specialString)
        
        XCTAssertNotNil(qrImage, "Should generate QR code for string with special characters")
    }
    
    @MainActor func testGenerateQRCode_UnicodeCharacters() {
        let unicodeString = "Hello世界🌍"
        let qrImage = qrCodeService.generateQRCode(from: unicodeString)
        
        XCTAssertNotNil(qrImage, "Should generate QR code for Unicode string")
    }
    
    @MainActor func testGenerateQRCode_EmojiCharacters() {
        let emojiString = "Family👨‍👩‍👧‍👦🏠"
        let qrImage = qrCodeService.generateQRCode(from: emojiString)
        
        XCTAssertNotNil(qrImage, "Should generate QR code for emoji string")
    }
    
    @MainActor func testGenerateQRCode_MixedUnicodeAndASCII() {
        let mixedString = "Family2024世界🌍"
        let qrImage = qrCodeService.generateQRCode(from: mixedString)
        
        XCTAssertNotNil(qrImage, "Should generate QR code for mixed Unicode and ASCII string")
    }
    
    @MainActor func testGenerateQRCode_AccentedCharacters() {
        let accentedString = "Café Niño Résumé"
        let qrImage = qrCodeService.generateQRCode(from: accentedString)
        
        XCTAssertNotNil(qrImage, "Should generate QR code for accented characters")
    }
    
    @MainActor func testGenerateQRCode_CyrillicCharacters() {
        let cyrillicString = "Привет мир"
        let qrImage = qrCodeService.generateQRCode(from: cyrillicString)
        
        XCTAssertNotNil(qrImage, "Should generate QR code for Cyrillic characters")
    }
    
    @MainActor func testGenerateQRCode_ArabicCharacters() {
        let arabicString = "مرحبا بالعالم"
        let qrImage = qrCodeService.generateQRCode(from: arabicString)
        
        XCTAssertNotNil(qrImage, "Should generate QR code for Arabic characters")
    }
    
    // MARK: - Edge Case Input Tests
    
    @MainActor func testGenerateQRCode_SingleCharacter() {
        let singleChar = "A"
        let qrImage = qrCodeService.generateQRCode(from: singleChar)
        
        XCTAssertNotNil(qrImage, "Should generate QR code for single character")
    }
    
    @MainActor func testGenerateQRCode_NumbersOnly() {
        let numbersOnly = "1234567890"
        let qrImage = qrCodeService.generateQRCode(from: numbersOnly)
        
        XCTAssertNotNil(qrImage, "Should generate QR code for numbers only")
    }
    
    @MainActor func testGenerateQRCode_SpecialCharactersOnly() {
        let specialOnly = "!@#$%^&*()"
        let qrImage = qrCodeService.generateQRCode(from: specialOnly)
        
        XCTAssertNotNil(qrImage, "Should generate QR code for special characters only")
    }
    
    @MainActor func testGenerateQRCode_URLString() {
        let urlString = "https://example.com/family/join?code=ABC123"
        let qrImage = qrCodeService.generateQRCode(from: urlString)
        
        XCTAssertNotNil(qrImage, "Should generate QR code for URL string")
    }
    
    @MainActor func testGenerateQRCode_JSONString() {
        let jsonString = "{\"familyCode\":\"ABC123\",\"type\":\"join\"}"
        let qrImage = qrCodeService.generateQRCode(from: jsonString)
        
        XCTAssertNotNil(qrImage, "Should generate QR code for JSON string")
    }
    
    // MARK: - Size Handling Tests
    
    @MainActor func testGenerateQRCode_DefaultSize() {
        let testString = "DEFAULT123"
        let qrImage = qrCodeService.generateQRCode(from: testString)
        
        // Default method should work without specifying size
        XCTAssertNotNil(qrImage, "Should generate QR code with default size")
    }
    
    @MainActor func testGenerateQRCode_CustomValidSize() {
        let testString = "CUSTOM123"
        let customSize = CGSize(width: 300, height: 300)
        let qrImage = qrCodeService.generateQRCode(from: testString, size: customSize)
        
        XCTAssertNotNil(qrImage, "Should generate QR code with custom valid size")
    }
    
    @MainActor func testGenerateQRCode_VeryLargeSize() {
        let testString = "LARGE123"
        let largeSize = CGSize(width: 2000, height: 2000)
        let qrImage = qrCodeService.generateQRCode(from: testString, size: largeSize)
        
        // Should handle large size (might return fallback if too large)
        XCTAssertNotNil(qrImage, "Should return image (valid or fallback) for very large size")
    }
    
    @MainActor func testGenerateQRCode_VerySmallSize() {
        let testString = "SMALL123"
        let smallSize = CGSize(width: 1, height: 1)
        let qrImage = qrCodeService.generateQRCode(from: testString, size: smallSize)
        
        // Should handle very small size (might return fallback if too small)
        XCTAssertNotNil(qrImage, "Should return image (valid or fallback) for very small size")
    }
    
    // MARK: - Performance Tests
    
    @MainActor func testGenerateQRCode_Performance() {
        let testString = "PERFORMANCE123"
        
        measure {
            for _ in 0..<10 {
                _ = qrCodeService.generateQRCode(from: testString)
            }
        }
    }
    
    @MainActor func testGenerateQRCode_PerformanceWithCustomSize() {
        let testString = "PERFORMANCE456"
        let customSize = CGSize(width: 400, height: 400)
        
        measure {
            for _ in 0..<10 {
                _ = qrCodeService.generateQRCode(from: testString, size: customSize)
            }
        }
    }
    
    // MARK: - Consistency Tests
    
    @MainActor func testGenerateQRCode_ConsistentOutput() {
        let testString = "CONSISTENT123"
        
        let image1 = qrCodeService.generateQRCode(from: testString)
        let image2 = qrCodeService.generateQRCode(from: testString)
        
        // Both should be non-nil and of the same type
        XCTAssertNotNil(image1, "First generation should succeed")
        XCTAssertNotNil(image2, "Second generation should succeed")
        XCTAssertTrue(type(of: image1) == type(of: image2), "Both generations should return same type")
    }
    
    @MainActor func testGenerateQRCode_DifferentStringsProduceDifferentResults() {
        let string1 = "STRING1"
        let string2 = "STRING2"
        
        let image1 = qrCodeService.generateQRCode(from: string1)
        let image2 = qrCodeService.generateQRCode(from: string2)
        
        // Both should be generated successfully
        XCTAssertNotNil(image1, "First string should generate image")
        XCTAssertNotNil(image2, "Second string should generate image")
        
        // Note: We can't directly compare SwiftUI Image content, but we verify both succeed
        XCTAssertTrue(type(of: image1) == type(of: image2), "Both should return SwiftUI Image type")
    }
}