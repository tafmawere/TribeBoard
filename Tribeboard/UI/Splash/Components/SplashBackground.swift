import SwiftUI

struct SplashBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.95, green: 0.96, blue: 0.98)
                .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.85, green: 0.89, blue: 1.0).opacity(0.65),
                            Color(red: 0.95, green: 0.96, blue: 0.98).opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 220
                    )
                )
                .frame(width: 320, height: 320)
                .offset(y: -140)
        }
    }
}

#Preview {
    SplashBackground()
}
