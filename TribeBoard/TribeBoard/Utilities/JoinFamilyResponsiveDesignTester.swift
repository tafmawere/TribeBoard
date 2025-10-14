import SwiftUI

/// Responsive design testing utility for Join Family components
struct JoinFamilyResponsiveDesignTester: View {
    @State private var selectedTypeSize: DynamicTypeSize = .medium
    @State private var selectedHorizontalSizeClass: UserInterfaceSizeClass = .regular
    @State private var selectedVerticalSizeClass: UserInterfaceSizeClass = .regular
    @State private var isHighContrast = false
    @State private var isReduceMotionEnabled = false
    
    private let typeSizes: [DynamicTypeSize] = [
        .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
        .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Controls
                controlsSection
                
                Divider()
                
                // Preview
                previewSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("Responsive Design Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Test Configuration")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Dynamic Type Size
            VStack(alignment: .leading, spacing: 8) {
                Text("Dynamic Type Size")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Dynamic Type Size", selection: $selectedTypeSize) {
                    ForEach(typeSizes, id: \.self) { size in
                        Text(typeSizeDisplayName(size))
                            .tag(size)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Size Classes
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Horizontal Size Class")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Horizontal", selection: $selectedHorizontalSizeClass) {
                        Text("Compact").tag(UserInterfaceSizeClass.compact)
                        Text("Regular").tag(UserInterfaceSizeClass.regular)
                    }
                    .pickerStyle(.segmented)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vertical Size Class")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Vertical", selection: $selectedVerticalSizeClass) {
                        Text("Compact").tag(UserInterfaceSizeClass.compact)
                        Text("Regular").tag(UserInterfaceSizeClass.regular)
                    }
                    .pickerStyle(.segmented)
                }
            }
            
            // Accessibility Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Accessibility Options")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Toggle("High Contrast", isOn: $isHighContrast)
                Toggle("Reduce Motion", isOn: $isReduceMotionEnabled)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var previewSection: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Family Code Card Test
                testSection("Family Code Card") {
                    FamilyCodeCardTestView()
                }
                
                // QR Code Section Test
                testSection("QR Code Section") {
                    QRCodeScanSectionTestView()
                }
                
                // Or Divider Test
                testSection("Or Divider") {
                    OrDivider()
                }
                
                // Instructional Footer Test
                testSection("Instructional Footer") {
                    InstructionalFooter()
                }
            }
        }
        .environment(\.dynamicTypeSize, selectedTypeSize)
        .environment(\.horizontalSizeClass, selectedHorizontalSizeClass)
        .environment(\.verticalSizeClass, selectedVerticalSizeClass)
        .preferredColorScheme(isHighContrast ? .dark : nil)
        .animation(isReduceMotionEnabled ? .none : .default, value: selectedTypeSize)
    }
    
    private func testSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            content()
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
        }
    }
    
    private func typeSizeDisplayName(_ size: DynamicTypeSize) -> String {
        switch size {
        case .xSmall: return "XS"
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        case .xLarge: return "XL"
        case .xxLarge: return "XXL"
        case .xxxLarge: return "XXXL"
        case .accessibility1: return "A1"
        case .accessibility2: return "A2"
        case .accessibility3: return "A3"
        case .accessibility4: return "A4"
        case .accessibility5: return "A5"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Test Components

struct FamilyCodeCardTestView: View {
    @State private var familyCode = "ABC123"
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
        FamilyCodeCard(
            familyCode: $familyCode,
            isCodeFieldFocused: $isCodeFieldFocused,
            isValidFormat: true,
            canSearch: true,
            isSearching: false,
            onSearch: {}
        )
    }
}

struct QRCodeScanSectionTestView: View {
    var body: some View {
        QRCodeScanSection(
            isScanning: false,
            onScan: {}
        )
    }
}

// MARK: - Spacing Analysis View

struct SpacingAnalysisView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spacing Analysis")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Environment Values:")
                    .font(.headline)
                
                Text("Dynamic Type: \(dynamicTypeSizeName)")
                Text("Scale Factor: \(String(format: "%.2f", dynamicTypeSize.customScaleFactor))")
                Text("Horizontal Size Class: \(horizontalSizeClass == .compact ? "Compact" : "Regular")")
                Text("Vertical Size Class: \(verticalSizeClass == .compact ? "Compact" : "Regular")")
                Text("Is Compact Layout: \(isCompactLayout ? "Yes" : "No")")
            }
            .font(.subheadline)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Computed Spacing Values:")
                    .font(.headline)
                
                Text("Card Padding: \(String(format: "%.1f", cardPadding))pt")
                Text("Header Spacing: \(String(format: "%.1f", headerSpacing))pt")
                Text("Input Spacing: \(String(format: "%.1f", inputSpacing))pt")
                Text("Button Height: \(String(format: "%.1f", buttonHeight))pt")
            }
            .font(.subheadline)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var dynamicTypeSizeName: String {
        switch dynamicTypeSize {
        case .xSmall: return "Extra Small"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .xLarge: return "Extra Large"
        case .xxLarge: return "Extra Extra Large"
        case .xxxLarge: return "Extra Extra Extra Large"
        case .accessibility1: return "Accessibility 1"
        case .accessibility2: return "Accessibility 2"
        case .accessibility3: return "Accessibility 3"
        case .accessibility4: return "Accessibility 4"
        case .accessibility5: return "Accessibility 5"
        @unknown default: return "Unknown"
        }
    }
    
    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }
    
    private var cardPadding: CGFloat {
        let basePadding = BrandStyle.paddingLarge
        let scaleFactor = min(dynamicTypeSize.customScaleFactor, 1.5)
        return isCompactLayout ? basePadding * 0.8 * scaleFactor : basePadding * scaleFactor
    }
    
    private var headerSpacing: CGFloat {
        let baseSpacing = BrandStyle.paddingLarge
        let scaleFactor = min(dynamicTypeSize.customScaleFactor, 1.3)
        return isCompactLayout ? baseSpacing * 0.7 * scaleFactor : baseSpacing * scaleFactor
    }
    
    private var inputSpacing: CGFloat {
        let baseSpacing = BrandStyle.paddingMedium
        let scaleFactor = min(dynamicTypeSize.customScaleFactor, 1.4)
        return baseSpacing * scaleFactor
    }
    
    private var buttonHeight: CGFloat {
        let baseHeight: CGFloat = 56
        let scaledHeight = baseHeight * dynamicTypeSize.customScaleFactor
        return max(scaledHeight, 44)
    }
}

// MARK: - Preview

#Preview("Responsive Design Tester") {
    JoinFamilyResponsiveDesignTester()
}

#Preview("Spacing Analysis") {
    NavigationView {
        ScrollView {
            VStack(spacing: 20) {
                SpacingAnalysisView()
                
                Divider()
                
                FamilyCodeCardTestView()
                
                OrDivider()
                
                QRCodeScanSectionTestView()
                
                InstructionalFooter()
            }
            .padding()
        }
        .navigationTitle("Spacing Test")
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .environment(\.horizontalSizeClass, .compact)
}