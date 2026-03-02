import SwiftUI

struct SplashScreenView: View {
    @EnvironmentObject var flow: AppFlowState
    @State private var animatedProgress: CGFloat = 0.18
    @State private var logoScale: CGFloat = 1.0
    @State private var logoGlowOpacity: CGFloat = 0.10

    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.96, blue: 0.98)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("TribeBoardLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .scaleEffect(logoScale)
                    .shadow(color: Color(red: 0.36, green: 0.46, blue: 0.98).opacity(logoGlowOpacity), radius: 16, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 6)

                Text("TribeBoard")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.22))

                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black.opacity(0.09))
                        .frame(width: 220, height: 6)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(red: 0.36, green: 0.46, blue: 0.98))
                                .frame(width: 220 * animatedProgress, height: 6)
                        }
                    Text("Loading your family dashboard\(loadingDots)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) {
                logoScale = 1.05
                logoGlowOpacity = 0.28
            }

            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                animatedProgress = 0.88
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            flow.completeSplash()
        }
    }

    private var loadingDots: String {
        let phase = Int(Date().timeIntervalSinceReferenceDate * 2) % 4
        return String(repeating: ".", count: phase)
    }
}

#Preview {
    SplashScreenView()
        .environmentObject(AppFlowState())
}
