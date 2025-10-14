import SwiftUI

/// QR Code scanning section component with green accent styling
struct QRCodeScanSection: View {
    let isScanning: Bool
    let onScan: () -> Void
    
    // Error handling properties
    let errorMessage: String?
    let showError: Bool
    
    init(
        isScanning: Bool,
        onScan: @escaping () -> Void,
        errorMessage: String? = nil,
        showError: Bool = false
    ) {
        self.isScanning = isScanning
        self.onScan = onScan
        self.errorMessage = errorMessage
        self.showError = showError
    }
    
    @State private var showingScanner = false
    
    // Responsive design environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    // Computed properties for responsive design
    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }
    
    private var sectionSpacing: CGFloat {
        let baseSpacing = BrandStyle.paddingMedium
        let scaleFactor = min(dynamicTypeSize.customScaleFactor, 1.4)
        return baseSpacing * scaleFactor
    }
    
    private var buttonHeight: CGFloat {
        let baseHeight: CGFloat = 56
        let scaledHeight = baseHeight * dynamicTypeSize.customScaleFactor
        return max(scaledHeight, 44) // Ensure minimum touch target
    }
    
    var body: some View {
        VStack(spacing: sectionSpacing) {
            // QR icon and title
            HStack(spacing: BrandStyle.paddingSmall * min(dynamicTypeSize.customScaleFactor, 1.3)) {
                Image(systemName: "qrcode")
                    .font(dynamicTypeSize.isAccessibilitySize ? .title3 : .title3)
                    .foregroundColor(colorSchemeContrast == .increased ? .brandGreenAccessible : .brandGreenDynamic)
                    .accessibilityHidden(true)
                
                Text("Scan QR Code")
                    .accessibleFont(size: 17, maxSize: 24, weight: .medium)
                    .foregroundColor(.primary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("QR Code scanning section")
            .accessibilityAddTraits(.isHeader)
            
            // Scan button with green accent styling
            Button(action: {
                if !isScanning {
                    HapticManager.shared.selection()
                    EnhancedAccessibility.announce("Opening QR code scanner")
                    showingScanner = true
                } else {
                    HapticManager.shared.error()
                    EnhancedAccessibility.announce("Scanner is already active")
                }
            }) {
                HStack(spacing: sectionSpacing) {
                    if isScanning {
                        ProgressView()
                            .scaleEffect(dynamicTypeSize.isAccessibilitySize ? 1.2 : 0.9)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .accessibilityLabel("Scanning in progress")
                    } else {
                        Image(systemName: "qrcode.viewfinder")
                            .font(dynamicTypeSize.isAccessibilitySize ? .title3 : .title2)
                            .accessibilityHidden(true)
                    }
                    
                    Text(isScanning ? "Scanning..." : "Scan QR Code")
                        .accessibleFont(size: 17, maxSize: 22, weight: .semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .fill(colorSchemeContrast == .increased ? 
                              Color.brandGreenAccessible : 
                              Color.brandGreenDynamic)
                        .opacity(isScanning ? 0.7 : 1.0)
                )
            }
            .disabled(isScanning)
            .accessibleTouchTarget()
            .scaleEffect(isScanning && !reduceMotion ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isScanning)
            .accessibilityLabel(isScanning ? "QR code scanner active" : "Scan QR Code button")
            .accessibilityHint(isScanning ? 
                              "QR code scanner is currently active" : 
                              "Opens camera to scan a family invitation QR code")
            .accessibilityAddTraits(isScanning ? [AccessibilityTraits.isButton, AccessibilityTraits.updatesFrequently] : [AccessibilityTraits.isButton])
            
            // Descriptive text
            Text("From family invitation")
                .accessibleFont(size: 15, maxSize: 18, weight: .regular)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Scan QR code from family invitation")
                .accessibilityAddTraits(.isStaticText)
            
            // Error message display
            if showError, let errorMessage = errorMessage {
                QRSectionErrorView(message: errorMessage)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingScanner) {
            QRCodeScannerView(onScan: { result in
                showingScanner = false
                HapticManager.shared.success()
                EnhancedAccessibility.announce("QR code scanned successfully")
                onScan()
            })
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("QR code scanning section")
        .accessibilityHint("Use this section to scan a QR code from a family invitation")
    }
}

/// SwiftUI wrapper for QR code scanning using native capabilities
/// This is a placeholder implementation that can be extended with actual camera scanning
struct QRCodeScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    private var viewfinderSize: CGFloat {
        let baseSize: CGFloat = 250
        let scaleFactor = min(dynamicTypeSize.customScaleFactor, 1.3)
        let compactFactor = horizontalSizeClass == .compact ? 0.8 : 1.0
        return baseSize * scaleFactor * compactFactor
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: BrandStyle.paddingLarge * min(dynamicTypeSize.customScaleFactor, 1.4)) {
                Spacer()
                
                // QR viewfinder placeholder
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                    .stroke(colorSchemeContrast == .increased ? 
                            Color.brandGreenAccessible : 
                            Color.brandGreenDynamic, 
                            lineWidth: 3)
                    .frame(width: viewfinderSize, height: viewfinderSize)
                    .overlay(
                        VStack(spacing: BrandStyle.paddingMedium * min(dynamicTypeSize.customScaleFactor, 1.3)) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 50 : 60))
                                .foregroundColor(colorSchemeContrast == .increased ? 
                                               Color.brandGreenAccessible : 
                                               Color.brandGreenDynamic)
                                .accessibilityHidden(true)
                            
                            Text("Position QR code within frame")
                                .accessibleFont(size: 17, maxSize: 22, weight: .semibold)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.primary)
                        }
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("QR code viewfinder")
                    .accessibilityHint("Position the QR code from the family invitation within this frame")
                
                Text("Point your camera at the QR code from the family invitation")
                    .accessibleFont(size: 15, maxSize: 20, weight: .regular)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .accessibilityLabel("Instructions: Point your camera at the QR code from the family invitation")
                
                // Demo button for testing (will be replaced with actual scanning)
                Button("Simulate Scan (Demo)") {
                    HapticManager.shared.success()
                    EnhancedAccessibility.announce("Simulating QR code scan")
                    onScan("DEMO12")
                }
                .accessibleFont(size: 17, maxSize: 20, weight: .semibold)
                .foregroundColor(colorSchemeContrast == .increased ? 
                               Color.brandGreenAccessible : 
                               Color.brandGreenDynamic)
                .padding(BrandStyle.paddingMedium * min(dynamicTypeSize.customScaleFactor, 1.3))
                .background(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .stroke(colorSchemeContrast == .increased ? 
                               Color.brandGreenAccessible : 
                               Color.brandGreenDynamic, 
                               lineWidth: 2)
                )
                .accessibleTouchTarget()
                .accessibilityLabel("Simulate QR code scan")
                .accessibilityHint("Simulates scanning a QR code for testing purposes")
                .accessibilityAddTraits(.isButton)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.shared.lightImpact()
                        EnhancedAccessibility.announce("QR code scanning cancelled")
                        dismiss()
                    }
                    .accessibilityLabel("Cancel QR code scanning")
                    .accessibilityHint("Closes the QR code scanner and returns to the previous screen")
                }
            }
        }
        .accessibilityLabel("QR Code Scanner")
        .accessibilityAddTraits(.isModal)
        .onAppear {
            EnhancedAccessibility.announceScreenChange()
            EnhancedAccessibility.announce("QR code scanner opened. Position the QR code within the viewfinder.")
        }
    }
}

// MARK: - QR Section Error View

/// Error view specifically designed for QR code section
struct QRSectionErrorView: View {
    let message: String
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var body: some View {
        HStack(spacing: BrandStyle.paddingSmall * min(dynamicTypeSize.customScaleFactor, 1.3)) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(dynamicTypeSize.isAccessibilitySize ? .caption : .caption2)
                .foregroundColor(.red)
                .accessibilityHidden(true)
            
            Text(message)
                .accessibleFont(size: 13, maxSize: 17, weight: .medium)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(.horizontal, BrandStyle.paddingMedium * min(dynamicTypeSize.customScaleFactor, 1.2))
        .padding(.vertical, BrandStyle.paddingSmall * min(dynamicTypeSize.customScaleFactor, 1.2))
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color.red.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("QR scanning error: \(message)")
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Preview

#Preview("QR Code Scan Section") {
    VStack(spacing: BrandStyle.paddingLarge * 1.5) {
        // Normal state
        QRCodeScanSection(
            isScanning: false,
            onScan: {
                print("QR scan initiated")
            }
        )
        
        // Loading state
        QRCodeScanSection(
            isScanning: true,
            onScan: {
                print("QR scan initiated")
            }
        )
        
        // Error state
        QRCodeScanSection(
            isScanning: false,
            onScan: {
                print("QR scan initiated")
            },
            errorMessage: "QR code scanning failed. Please try again.",
            showError: true
        )
    }
    .padding(BrandStyle.paddingMedium)
    .background(Color(.systemGroupedBackground))
}

#Preview("QR Scanner View") {
    QRCodeScannerView { code in
        print("Scanned code: \(code)")
    }
}