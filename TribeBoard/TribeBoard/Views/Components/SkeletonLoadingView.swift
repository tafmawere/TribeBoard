import SwiftUI

/// A skeleton loading view that shows placeholder content
struct SkeletonLoadingView: View {
    let rows: Int
    let showAvatar: Bool
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: 12) {
                    if showAvatar {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 44, height: 44)
                            .shimmer(isAnimating: isAnimating)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 16)
                            .frame(maxWidth: .infinity)
                            .shimmer(isAnimating: isAnimating)
                        
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(width: .random(in: 100...200))
                            .shimmer(isAnimating: isAnimating)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

/// Shimmer effect modifier
struct ShimmerModifier: ViewModifier {
    let isAnimating: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)
                .animation(
                    isAnimating ? 
                    Animation.linear(duration: 1.5).repeatForever(autoreverses: false) : 
                    .default,
                    value: phase
                )
            )
            .onAppear {
                if isAnimating {
                    phase = 300
                }
            }
            .clipped()
    }
}

extension View {
    func shimmer(isAnimating: Bool) -> some View {
        modifier(ShimmerModifier(isAnimating: isAnimating))
    }
}

#Preview {
    SkeletonLoadingView(rows: 3, showAvatar: true)
        .padding()
}