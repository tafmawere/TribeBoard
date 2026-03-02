import SwiftUI

struct LoadingStatusLabel: View {
    let message: String

    init(message: String = SplashMockData.preview.loadingMessage) {
        self.message = message
    }

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(Color(red: 0.62, green: 0.64, blue: 0.67))
            .multilineTextAlignment(.center)
    }
}

#Preview {
    LoadingStatusLabel()
}
