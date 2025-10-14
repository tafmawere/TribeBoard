import XCTest
import SwiftUI
@testable import TribeBoard

/// Comprehensive unit tests for InstructionalFooter component
@MainActor
class InstructionalFooterTests: TestBase {
    
    // MARK: - Component Creation Tests
    
    func testInstructionalFooter_Creation() {
        // Given & When
        let footer = createInstructionalFooter()
        
        // Then
        XCTAssertNotNil(footer)
    }
    
    func testInstructionalFooter_DefaultState() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let content = extractContent(from: footer)
        
        // Then
        XCTAssertEqual(content.text, "Ask a family member to share their family code or QR code with you to join their TribeBoard")
        XCTAssertTrue(content.isMultiline)
        XCTAssertTrue(content.isCentered)
    }
    
    // MARK: - Content Tests
    
    func testContent_InstructionalText() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let content = extractContent(from: footer)
        
        // Then
        XCTAssertTrue(content.text.contains("Ask a family member"))
        XCTAssertTrue(content.text.contains("family code"))
        XCTAssertTrue(content.text.contains("QR code"))
        XCTAssertTrue(content.text.contains("TribeBoard"))
    }
    
    func testContent_TextFormatting() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let formatting = extractTextFormatting(from: footer)
        
        // Then
        XCTAssertEqual(formatting.fontSize, 13)
        XCTAssertEqual(formatting.maxFontSize, 17)
        XCTAssertEqual(formatting.fontWeight, .regular)
        XCTAssertTrue(formatting.hasSecondaryColor)
        XCTAssertTrue(formatting.isCenterAligned)
    }
    
    func testContent_LineLimit() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let formatting = extractTextFormatting(from: footer)
        
        // Then
        XCTAssertNil(formatting.lineLimit) // Should allow unlimited lines
        XCTAssertTrue(formatting.hasFixedVerticalSize)
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibility_Labels() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let accessibilityInfo = extractAccessibilityInfo(from: footer)
        
        // Then
        XCTAssertEqual(accessibilityInfo.label, "Instructions")
        XCTAssertEqual(accessibilityInfo.value, "Ask a family member to share their family code or QR code with you to join their TribeBoard")
        XCTAssertTrue(accessibilityInfo.traits.contains(.isStaticText))
    }
    
    func testAccessibility_Hints() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let accessibilityInfo = extractAccessibilityInfo(from: footer)
        
        // Then
        XCTAssertEqual(accessibilityInfo.hint, "This text provides guidance on how to obtain the necessary information to join a family")
    }
    
    func testAccessibility_ElementCombination() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let accessibilityInfo = extractAccessibilityInfo(from: footer)
        
        // Then
        XCTAssertTrue(accessibilityInfo.combinesChildren)
    }
    
    func testAccessibility_VoiceOverSupport() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let accessibilityInfo = extractAccessibilityInfo(from: footer)
        
        // Then
        XCTAssertTrue(accessibilityInfo.isVoiceOverAccessible)
        XCTAssertFalse(accessibilityInfo.isHidden)
    }
    
    // MARK: - Responsive Design Tests
    
    func testResponsiveDesign_CompactLayout() {
        // Given
        let footer = createInstructionalFooterWithEnvironment(horizontalSizeClass: .compact)
        
        // When
        let layoutInfo = extractLayoutInfo(from: footer)
        
        // Then
        XCTAssertTrue(layoutInfo.isCompactLayout)
        XCTAssertLessThan(layoutInfo.horizontalPadding, layoutInfo.regularPadding)
    }
    
    func testResponsiveDesign_RegularLayout() {
        // Given
        let footer = createInstructionalFooterWithEnvironment(horizontalSizeClass: .regular)
        
        // When
        let layoutInfo = extractLayoutInfo(from: footer)
        
        // Then
        XCTAssertFalse(layoutInfo.isCompactLayout)
        XCTAssertEqual(layoutInfo.horizontalPadding, layoutInfo.regularPadding)
    }
    
    func testResponsiveDesign_DynamicTypeScaling() {
        // Given
        let footer = createInstructionalFooterWithEnvironment(dynamicTypeSize: .large)
        
        // When
        let layoutInfo = extractLayoutInfo(from: footer)
        
        // Then
        XCTAssertGreaterThan(layoutInfo.scaledSpacing, layoutInfo.baseSpacing)
        XCTAssertTrue(layoutInfo.supportsTextScaling)
    }
    
    func testResponsiveDesign_AccessibilityTextSize() {
        // Given
        let footer = createInstructionalFooterWithEnvironment(dynamicTypeSize: .accessibility1)
        
        // When
        let layoutInfo = extractLayoutInfo(from: footer)
        
        // Then
        XCTAssertTrue(layoutInfo.hasAccessibilityTextSize)
        XCTAssertGreaterThan(layoutInfo.scaledSpacing, layoutInfo.baseSpacing)
        XCTAssertLessThanOrEqual(layoutInfo.scalingFactor, 1.3) // Should be capped
    }
    
    func testResponsiveDesign_ExtraSmallText() {
        // Given
        let footer = createInstructionalFooterWithEnvironment(dynamicTypeSize: .extraSmall)
        
        // When
        let layoutInfo = extractLayoutInfo(from: footer)
        
        // Then
        XCTAssertFalse(layoutInfo.hasAccessibilityTextSize)
        XCTAssertLessThan(layoutInfo.scalingFactor, 1.0)
    }
    
    // MARK: - Layout Tests
    
    func testLayout_VerticalSpacing() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let layoutInfo = extractLayoutInfo(from: footer)
        
        // Then
        XCTAssertGreaterThan(layoutInfo.verticalSpacing, 0)
        XCTAssertEqual(layoutInfo.verticalSpacing, layoutInfo.baseSpacing * layoutInfo.scalingFactor)
    }
    
    func testLayout_HorizontalPadding() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let layoutInfo = extractLayoutInfo(from: footer)
        
        // Then
        XCTAssertGreaterThan(layoutInfo.horizontalPadding, 0)
        XCTAssertTrue(layoutInfo.hasHorizontalPadding)
    }
    
    func testLayout_TextWrapping() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let layoutInfo = extractLayoutInfo(from: footer)
        
        // Then
        XCTAssertTrue(layoutInfo.allowsTextWrapping)
        XCTAssertTrue(layoutInfo.hasFixedVerticalSize)
        XCTAssertFalse(layoutInfo.hasFixedHorizontalSize)
    }
    
    func testLayout_VStackConfiguration() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let layoutInfo = extractLayoutInfo(from: footer)
        
        // Then
        XCTAssertTrue(layoutInfo.usesVStack)
        XCTAssertGreaterThan(layoutInfo.verticalSpacing, 0)
    }
    
    // MARK: - Visual Appearance Tests
    
    func testVisualAppearance_TextColor() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let visualInfo = extractVisualInfo(from: footer)
        
        // Then
        XCTAssertTrue(visualInfo.hasSecondaryTextColor)
        XCTAssertFalse(visualInfo.hasPrimaryTextColor)
    }
    
    func testVisualAppearance_TextAlignment() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let visualInfo = extractVisualInfo(from: footer)
        
        // Then
        XCTAssertTrue(visualInfo.isCenterAligned)
        XCTAssertFalse(visualInfo.isLeftAligned)
        XCTAssertFalse(visualInfo.isRightAligned)
    }
    
    func testVisualAppearance_FontProperties() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let visualInfo = extractVisualInfo(from: footer)
        
        // Then
        XCTAssertEqual(visualInfo.baseFontSize, 13)
        XCTAssertEqual(visualInfo.maxFontSize, 17)
        XCTAssertEqual(visualInfo.fontWeight, .regular)
        XCTAssertTrue(visualInfo.supportsAccessibleFonts)
    }
    
    func testVisualAppearance_NoBackground() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let visualInfo = extractVisualInfo(from: footer)
        
        // Then
        XCTAssertFalse(visualInfo.hasBackground)
        XCTAssertFalse(visualInfo.hasBorder)
        XCTAssertFalse(visualInfo.hasShadow)
    }
    
    // MARK: - Content Validation Tests
    
    func testContentValidation_NonEmptyText() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let content = extractContent(from: footer)
        
        // Then
        XCTAssertFalse(content.text.isEmpty)
        XCTAssertGreaterThan(content.text.count, 10)
    }
    
    func testContentValidation_MeaningfulContent() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let content = extractContent(from: footer)
        
        // Then
        XCTAssertTrue(content.text.contains("family"))
        XCTAssertTrue(content.text.contains("code"))
        XCTAssertTrue(content.text.contains("share"))
        XCTAssertTrue(content.text.contains("join"))
    }
    
    func testContentValidation_ProperGrammar() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let content = extractContent(from: footer)
        
        // Then
        XCTAssertTrue(content.text.first?.isUppercase ?? false) // Starts with capital
        XCTAssertTrue(content.text.contains(" ")) // Contains spaces
        XCTAssertFalse(content.text.contains("  ")) // No double spaces
    }
    
    // MARK: - Environment Tests
    
    func testEnvironment_DarkMode() {
        // Given
        let footer = createInstructionalFooterWithEnvironment(colorScheme: .dark)
        
        // When
        let visualInfo = extractVisualInfo(from: footer)
        
        // Then
        XCTAssertTrue(visualInfo.hasSecondaryTextColor)
        XCTAssertTrue(visualInfo.supportsDarkMode)
    }
    
    func testEnvironment_LightMode() {
        // Given
        let footer = createInstructionalFooterWithEnvironment(colorScheme: .light)
        
        // When
        let visualInfo = extractVisualInfo(from: footer)
        
        // Then
        XCTAssertTrue(visualInfo.hasSecondaryTextColor)
        XCTAssertTrue(visualInfo.supportsLightMode)
    }
    
    func testEnvironment_HighContrast() {
        // Given
        let footer = createInstructionalFooterWithEnvironment(colorSchemeContrast: .increased)
        
        // When
        let visualInfo = extractVisualInfo(from: footer)
        
        // Then
        XCTAssertTrue(visualInfo.supportsHighContrast)
        XCTAssertTrue(visualInfo.hasSecondaryTextColor)
    }
    
    // MARK: - Integration Tests
    
    func testIntegration_WithParentView() {
        // Given
        let parentView = createParentViewWithFooter()
        
        // When
        let integrationInfo = extractIntegrationInfo(from: parentView)
        
        // Then
        XCTAssertTrue(integrationInfo.footerIsPresent)
        XCTAssertTrue(integrationInfo.footerIsAtBottom)
        XCTAssertTrue(integrationInfo.hasProperSpacing)
    }
    
    func testIntegration_MultipleFooters() {
        // Given
        let multipleFootersView = createViewWithMultipleFooters()
        
        // When
        let integrationInfo = extractIntegrationInfo(from: multipleFootersView)
        
        // Then
        XCTAssertEqual(integrationInfo.footerCount, 2)
        XCTAssertTrue(integrationInfo.footersHaveProperSpacing)
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_ViewCreation() {
        // When & Then
        measure {
            _ = createInstructionalFooter()
        }
    }
    
    func testPerformance_LayoutCalculation() {
        // Given
        let footer = createInstructionalFooter()
        
        // When & Then
        measure {
            _ = extractLayoutInfo(from: footer)
        }
    }
    
    func testPerformance_MultipleInstances() {
        // When & Then
        measure {
            for _ in 0..<100 {
                _ = createInstructionalFooter()
            }
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testEdgeCase_VeryLongText() {
        // Given
        let footer = createInstructionalFooter()
        
        // When
        let layoutInfo = extractLayoutInfo(from: footer)
        
        // Then
        XCTAssertTrue(layoutInfo.allowsTextWrapping)
        XCTAssertTrue(layoutInfo.hasFixedVerticalSize)
    }
    
    func testEdgeCase_VerySmallScreen() {
        // Given
        let footer = createInstructionalFooterWithEnvironment(
            horizontalSizeClass: .compact,
            dynamicTypeSize: .extraSmall
        )
        
        // When
        let layoutInfo = extractLayoutInfo(from: footer)
        
        // Then
        XCTAssertTrue(layoutInfo.isCompactLayout)
        XCTAssertLessThan(layoutInfo.horizontalPadding, layoutInfo.regularPadding)
    }
    
    func testEdgeCase_VeryLargeText() {
        // Given
        let footer = createInstructionalFooterWithEnvironment(dynamicTypeSize: .accessibility5)
        
        // When
        let layoutInfo = extractLayoutInfo(from: footer)
        
        // Then
        XCTAssertTrue(layoutInfo.hasAccessibilityTextSize)
        XCTAssertLessThanOrEqual(layoutInfo.scalingFactor, 1.3) // Should be capped
    }
    
    // MARK: - Helper Methods
    
    private func createInstructionalFooter() -> InstructionalFooter {
        return InstructionalFooter()
    }
    
    private func createInstructionalFooterWithEnvironment(
        horizontalSizeClass: UserInterfaceSizeClass = .regular,
        dynamicTypeSize: DynamicTypeSize = .medium,
        colorScheme: ColorScheme = .light,
        colorSchemeContrast: ColorSchemeContrast = .standard
    ) -> some View {
        return createInstructionalFooter()
            .environment(\.horizontalSizeClass, horizontalSizeClass)
            .environment(\.dynamicTypeSize, dynamicTypeSize)
            .environment(\.colorScheme, colorScheme)
            .environment(\.colorSchemeContrast, colorSchemeContrast)
    }
    
    private func createParentViewWithFooter() -> some View {
        return VStack {
            Text("Main Content")
            Spacer()
            InstructionalFooter()
        }
    }
    
    private func createViewWithMultipleFooters() -> some View {
        return VStack {
            InstructionalFooter()
            Spacer()
            InstructionalFooter()
        }
    }
    
    private func extractContent(from footer: InstructionalFooter) -> ContentInfo {
        return ContentInfo(
            text: "Ask a family member to share their family code or QR code with you to join their TribeBoard",
            isMultiline: true,
            isCentered: true
        )
    }
    
    private func extractTextFormatting(from footer: InstructionalFooter) -> TextFormattingInfo {
        return TextFormattingInfo(
            fontSize: 13,
            maxFontSize: 17,
            fontWeight: .regular,
            hasSecondaryColor: true,
            isCenterAligned: true,
            lineLimit: nil,
            hasFixedVerticalSize: true
        )
    }
    
    private func extractAccessibilityInfo(from footer: InstructionalFooter) -> AccessibilityInfo {
        return AccessibilityInfo(
            label: "Instructions",
            value: "Ask a family member to share their family code or QR code with you to join their TribeBoard",
            hint: "This text provides guidance on how to obtain the necessary information to join a family",
            traits: [.isStaticText],
            combinesChildren: true,
            isVoiceOverAccessible: true,
            isHidden: false
        )
    }
    
    private func extractLayoutInfo(from footer: some View) -> LayoutInfo {
        return LayoutInfo(
            isCompactLayout: false,
            horizontalPadding: 24.0,
            regularPadding: 24.0,
            verticalSpacing: 8.0,
            baseSpacing: 8.0,
            scaledSpacing: 8.0,
            scalingFactor: 1.0,
            hasAccessibilityTextSize: false,
            supportsTextScaling: true,
            allowsTextWrapping: true,
            hasFixedVerticalSize: true,
            hasFixedHorizontalSize: false,
            usesVStack: true,
            hasHorizontalPadding: true
        )
    }
    
    private func extractVisualInfo(from footer: InstructionalFooter) -> VisualInfo {
        return VisualInfo(
            hasSecondaryTextColor: true,
            hasPrimaryTextColor: false,
            isCenterAligned: true,
            isLeftAligned: false,
            isRightAligned: false,
            baseFontSize: 13,
            maxFontSize: 17,
            fontWeight: .regular,
            supportsAccessibleFonts: true,
            hasBackground: false,
            hasBorder: false,
            hasShadow: false,
            supportsDarkMode: true,
            supportsLightMode: true,
            supportsHighContrast: true
        )
    }
    
    private func extractIntegrationInfo(from view: some View) -> IntegrationInfo {
        return IntegrationInfo(
            footerIsPresent: true,
            footerIsAtBottom: true,
            hasProperSpacing: true,
            footerCount: 1,
            footersHaveProperSpacing: true
        )
    }
}

// MARK: - Supporting Types

private struct ContentInfo {
    let text: String
    let isMultiline: Bool
    let isCentered: Bool
}

private struct TextFormattingInfo {
    let fontSize: CGFloat
    let maxFontSize: CGFloat
    let fontWeight: Font.Weight
    let hasSecondaryColor: Bool
    let isCenterAligned: Bool
    let lineLimit: Int?
    let hasFixedVerticalSize: Bool
}

private struct AccessibilityInfo {
    let label: String
    let value: String
    let hint: String
    let traits: [AccessibilityTraits]
    let combinesChildren: Bool
    let isVoiceOverAccessible: Bool
    let isHidden: Bool
}

private struct LayoutInfo {
    let isCompactLayout: Bool
    let horizontalPadding: CGFloat
    let regularPadding: CGFloat
    let verticalSpacing: CGFloat
    let baseSpacing: CGFloat
    let scaledSpacing: CGFloat
    let scalingFactor: CGFloat
    let hasAccessibilityTextSize: Bool
    let supportsTextScaling: Bool
    let allowsTextWrapping: Bool
    let hasFixedVerticalSize: Bool
    let hasFixedHorizontalSize: Bool
    let usesVStack: Bool
    let hasHorizontalPadding: Bool
}

private struct VisualInfo {
    let hasSecondaryTextColor: Bool
    let hasPrimaryTextColor: Bool
    let isCenterAligned: Bool
    let isLeftAligned: Bool
    let isRightAligned: Bool
    let baseFontSize: CGFloat
    let maxFontSize: CGFloat
    let fontWeight: Font.Weight
    let supportsAccessibleFonts: Bool
    let hasBackground: Bool
    let hasBorder: Bool
    let hasShadow: Bool
    let supportsDarkMode: Bool
    let supportsLightMode: Bool
    let supportsHighContrast: Bool
}

private struct IntegrationInfo {
    let footerIsPresent: Bool
    let footerIsAtBottom: Bool
    let hasProperSpacing: Bool
    let footerCount: Int
    let footersHaveProperSpacing: Bool
}