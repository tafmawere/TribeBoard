import SwiftUI

struct LoadingSkeletonView: View {
    var rows: Int = 4
    @State private var animate = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0 ..< rows, id: \.self) { index in
                    skeletonCard(widthFactor: widthFactor(for: index))
                }
            }
            .padding(16)
        }
        .background(GeneralUXTheme.background.ignoresSafeArea())
        .onAppear {
            animate = true
        }
    }

    private func skeletonCard(widthFactor: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.gray.opacity(0.18))
                .frame(height: 16)
                .frame(maxWidth: .infinity, alignment: .leading)

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.gray.opacity(0.14))
                .frame(width: 220 * widthFactor, height: 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GeneralUXTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(GeneralUXTheme.border)
        )
        .modifier(ShimmerEffect(isAnimating: animate))
    }

    private func widthFactor(for index: Int) -> CGFloat {
        let factors: [CGFloat] = [1.0, 0.85, 0.92, 0.78, 0.88]
        return factors[index % factors.count]
    }
}

private struct ShimmerEffect: ViewModifier {
    let isAnimating: Bool
    @State private var phase: CGFloat = -0.8

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    let gradient = LinearGradient(
                        colors: [
                            .white.opacity(0.0),
                            .white.opacity(0.45),
                            .white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Rectangle()
                        .fill(gradient)
                        .rotationEffect(.degrees(18))
                        .offset(x: proxy.size.width * phase)
                        .frame(width: proxy.size.width * 0.7)
                        .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .onAppear {
                guard isAnimating else { return }
                withAnimation(
                    .linear(duration: 1.05).repeatForever(autoreverses: false)
                ) {
                    phase = 1.2
                }
            }
    }
}

#Preview {
    LoadingSkeletonView(rows: 6)
}
