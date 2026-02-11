//
//  BottomNavigationBar.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Bottom navigation bar with 5 tabs for app-wide navigation
/// Fixed at the bottom of the screen with blur effect background
/// Validates: Requirements 6.1, 6.2, 6.3, 6.4, 6.5, 6.6
struct BottomNavigationBar: View {
    @Binding var selectedTab: MainTab
    
    /// Tab definition with icon and label
    private struct TabItem {
        let tab: MainTab
        let icon: String
        let label: String
    }
    
    private let tabs: [TabItem] = [
        TabItem(tab: .home, icon: "house.fill", label: "Today"),
        TabItem(tab: .runs, icon: "car.fill", label: "Runs"),
        TabItem(tab: .calendar, icon: "calendar", label: "Calendar"),
        TabItem(tab: .feed, icon: "list.bullet", label: "Feed"),
        TabItem(tab: .tribe, icon: "person.3.fill", label: "Tribe")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tab) { tabItem in
                TabButton(
                    icon: tabItem.icon,
                    label: tabItem.label,
                    isSelected: selectedTab == tabItem.tab
                ) {
                    selectedTab = tabItem.tab
                }
            }
        }
        .frame(height: 60)
        .background(
            .ultraThinMaterial,
            in: Rectangle()
        )
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }
}

/// Individual tab button component
private struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .frame(height: 24)
                
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .foregroundColor(isSelected ? DesignSystem.Colors.primaryBrand : Color.secondary)
            .frame(minHeight: 44) // Ensure minimum touch target height
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Navigate to \(label) tab")
    }
}

// MainTab is now defined in Models/MainTab.swift

// MARK: - Previews

#Preview("Bottom Navigation - Home Selected") {
    @Previewable @State var selectedTab: MainTab = .home
    
    VStack {
        Spacer()
        Text("Home Tab Selected")
            .font(.title)
        Spacer()
        BottomNavigationBar(selectedTab: $selectedTab)
    }
}

#Preview("Bottom Navigation - Runs Selected") {
    @Previewable @State var selectedTab: MainTab = .runs
    
    VStack {
        Spacer()
        Text("Runs Tab Selected")
            .font(.title)
        Spacer()
        BottomNavigationBar(selectedTab: $selectedTab)
    }
}

#Preview("Bottom Navigation - All Tabs") {
    @Previewable @State var selectedTab: MainTab = .home
    
    VStack {
        Spacer()
        
        VStack(spacing: 20) {
            Text("Selected: \(selectedTab.description)")
                .font(.title2)
            
            Text("Tap tabs below to switch")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        Spacer()
        
        BottomNavigationBar(selectedTab: $selectedTab)
    }
}

#Preview("Bottom Navigation - Dark Mode") {
    @Previewable @State var selectedTab: MainTab = .calendar
    
    VStack {
        Spacer()
        Text("Calendar Tab Selected")
            .font(.title)
        Spacer()
        BottomNavigationBar(selectedTab: $selectedTab)
    }
    .preferredColorScheme(.dark)
}


