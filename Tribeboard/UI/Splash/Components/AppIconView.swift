import SwiftUI

struct AppIconView: View {
    let size: CGFloat

    init(size: CGFloat = 84) {
        self.size = size
    }

    var body: some View {
        Image("TribeBoardLogo")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 6)
    }
}

#Preview {
    AppIconView()
}
