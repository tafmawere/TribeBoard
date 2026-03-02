import SwiftUI

struct ProgressBarView: View {
    let progress: CGFloat
    let totalWidth: CGFloat
    let height: CGFloat
    let fillColor: Color
    let trackColor: Color

    init(
        progress: CGFloat = SplashMockData.preview.progressValue,
        totalWidth: CGFloat = 320,
        height: CGFloat = 4,
        fillColor: Color = Color(red: 0.19, green: 0.43, blue: 0.95),
        trackColor: Color = Color(red: 0.86, green: 0.88, blue: 0.92)
    ) {
        self.progress = progress
        self.totalWidth = totalWidth
        self.height = height
        self.fillColor = fillColor
        self.trackColor = trackColor
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(trackColor)
                .frame(width: totalWidth, height: height)

            Capsule()
                .fill(fillColor)
                .frame(width: totalWidth * progress, height: height)
        }
        .frame(width: totalWidth, height: height)
    }
}

#Preview {
    ProgressBarView()
}
