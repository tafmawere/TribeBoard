//
//  ContentView.swift
//  TribeBoard
//
//  Created by Tafadzwa Mawere on 2025/09/15.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 30) {
            // TribeBoard Logo
            TribeBoardLogoWithText(size: .large)
            
            // Welcome message with brand styling
            VStack(spacing: 16) {
                Text("Welcome to TribeBoard")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.brandPrimary)
                
                Text("Bringing families together")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Sample brand-styled button
            Button(action: {
                // Action placeholder
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient.brandGradient)
                    .cornerRadius(BrandStyle.cornerRadius)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(LinearGradient.brandGradientSubtle)
    }
}

#Preview {
    ContentView()
}
