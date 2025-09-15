# TribeBoard Logo Setup Instructions

## Overview
This document provides instructions for incorporating the TribeBoard logo into the iOS app project.

## Logo Assets Required

To complete the logo integration, you'll need to add the actual logo image files to the project. The logo should be provided in the following sizes for optimal iOS support:

### App Icon Sizes (Required)
- **1024x1024** - App Store icon (PNG, no transparency)
- **512x512** - macOS app icon @1x
- **256x256** - macOS app icon @1x  
- **128x128** - macOS app icon @1x
- **64x64** - macOS app icon @1x (optional)
- **32x32** - macOS app icon @1x (optional)
- **16x16** - macOS app icon @1x (optional)

### Additional Sizes (Recommended)
- **180x180** - iPhone app icon @3x
- **120x120** - iPhone app icon @2x
- **87x87** - iPhone Settings icon @3x
- **58x58** - iPhone Settings icon @2x
- **40x40** - iPhone Spotlight icon @2x
- **29x29** - iPhone Settings icon @1x

## How to Add Logo Files

### Method 1: Using Xcode (Recommended)
1. Open the TribeBoard project in Xcode
2. Navigate to `TribeBoard/Assets.xcassets/AppIcon.appiconset`
3. Drag and drop your logo files into the appropriate size slots
4. Xcode will automatically handle the file naming and organization

### Method 2: Manual File Addition
1. Save your logo files with the following naming convention:
   - `AppIcon-1024.png` (1024x1024)
   - `AppIcon-512.png` (512x512)
   - etc.

2. Add the files to the `TribeBoard/Assets.xcassets/AppIcon.appiconset/` directory

3. Update the `Contents.json` file to reference your image files:

```json
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    // ... other sizes
  ]
}
```

## Logo Design Guidelines

Based on your current logo design:

### Colors Used
- **Primary Brand Color**: Light purple/blue (#7AA5EA approximately)
- **Secondary Brand Color**: Darker purple/blue (#5980CC approximately)
- **Background**: Gradient from primary to secondary
- **Icon Color**: Black (#000000)

### Design Elements
- Rounded square background with gradient
- House icon with family figures inside
- Clean, modern iconography
- High contrast for visibility

### Technical Requirements
- **Format**: PNG (required for app icons)
- **Color Space**: sRGB
- **Transparency**: None for app icons (solid background required)
- **Compression**: Optimized for file size while maintaining quality

## Brand Integration Completed

The following brand elements have already been integrated into the project:

✅ **Brand Colors**: Added to Assets.xcassets with proper light/dark mode support
✅ **Color Extensions**: Swift extensions for easy access to brand colors
✅ **Logo Components**: SwiftUI components for displaying the logo in various sizes
✅ **Gradient Definitions**: Brand gradients matching your logo design
✅ **Accent Color**: Updated to match brand primary color
✅ **Brand Style Guide**: Consistent styling helpers (corner radius, shadows, etc.)

## Usage in Code

Once the image files are added, you can use the logo throughout the app:

```swift
// Simple logo
TribeBoardLogo(size: .medium)

// Logo with text
TribeBoardLogoWithText(size: .large)

// App icon representation
AppIconView(size: 60)

// Using brand colors
Rectangle()
    .fill(LinearGradient.brandGradient)
    .foregroundColor(.brandPrimary)
```

## Next Steps

1. **Add the actual logo image files** using one of the methods above
2. **Test the app icon** by building and installing on a device/simulator
3. **Verify all sizes** display correctly across different devices
4. **Update any placeholder icons** throughout the app with the new logo components

## File Locations

- **App Icon Assets**: `TribeBoard/TribeBoard/Assets.xcassets/AppIcon.appiconset/`
- **Brand Colors**: `TribeBoard/TribeBoard/Assets.xcassets/Colors/`
- **Logo Components**: `TribeBoard/TribeBoard/Views/Components/TribeBoardLogo.swift`
- **Brand Utilities**: `TribeBoard/TribeBoard/Utilities/BrandColors.swift`

---

**Note**: The logo image files themselves need to be manually added to complete the integration, as I cannot directly copy image files into the project structure. The framework and styling are now in place to support your logo design.