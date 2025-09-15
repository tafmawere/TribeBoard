import SwiftUI

/// Loading overlay for global loading states
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                
                Text("Loading...")
                    .font(.headline)
                    .foregroundColor(.brandPrimary)
            }
            .padding(30)
            .background(Color(.systemBackground))
            .cornerRadius(BrandStyle.cornerRadius)
            .shadow(radius: 10)
        }
    }
}

#Preview {
    LoadingOverlay()
}