import SwiftUI

struct AppBrandingView: View {
    let title: String
    let subtitle: String

    init(
        title: String = SplashMockData.preview.appName,
        subtitle: String = SplashMockData.preview.tagline
    ) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.09, green: 0.10, blue: 0.15))

            Text(subtitle)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color(red: 0.43, green: 0.44, blue: 0.47))
        }
        .multilineTextAlignment(.center)
    }
}

#Preview {
    AppBrandingView()
}
