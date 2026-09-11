import SwiftUI

/// White house + family mark from the splash spec (matches `TribeBoardLogo` iconography without app-icon chrome).
struct SplashMarkView: View {
    var color: Color = .white

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 200
            context.scaleBy(x: scale, y: scale)

            var house = Path()
            house.move(to: CGPoint(x: 38, y: 108))
            house.addLine(to: CGPoint(x: 100, y: 48))
            house.addLine(to: CGPoint(x: 162, y: 108))
            house.addLine(to: CGPoint(x: 162, y: 164))
            house.addQuadCurve(to: CGPoint(x: 158, y: 168), control: CGPoint(x: 162, y: 168))
            house.addLine(to: CGPoint(x: 42, y: 168))
            house.addQuadCurve(to: CGPoint(x: 38, y: 164), control: CGPoint(x: 38, y: 168))
            house.closeSubpath()
            context.stroke(
                house,
                with: .color(color),
                style: StrokeStyle(lineWidth: 10.5, lineCap: .round, lineJoin: .round)
            )

            func fillCircle(cx: CGFloat, cy: CGFloat, r: CGFloat) {
                context.fill(
                    Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                    with: .color(color)
                )
            }

            fillCircle(cx: 100, cy: 98, r: 13.5)

            var centerBody = Path()
            centerBody.move(to: CGPoint(x: 83, y: 168))
            centerBody.addLine(to: CGPoint(x: 83, y: 141))
            centerBody.addQuadCurve(to: CGPoint(x: 100, y: 124), control: CGPoint(x: 83, y: 124))
            centerBody.addQuadCurve(to: CGPoint(x: 117, y: 141), control: CGPoint(x: 117, y: 124))
            centerBody.addLine(to: CGPoint(x: 117, y: 168))
            centerBody.closeSubpath()
            context.fill(centerBody, with: .color(color))

            fillCircle(cx: 67, cy: 114, r: 9.5)
            var leftBody = Path()
            leftBody.move(to: CGPoint(x: 52, y: 168))
            leftBody.addLine(to: CGPoint(x: 52, y: 150))
            leftBody.addQuadCurve(to: CGPoint(x: 67, y: 139), control: CGPoint(x: 52, y: 139))
            leftBody.addQuadCurve(to: CGPoint(x: 82, y: 150), control: CGPoint(x: 82, y: 139))
            leftBody.addLine(to: CGPoint(x: 82, y: 168))
            leftBody.closeSubpath()
            context.fill(leftBody, with: .color(color))

            fillCircle(cx: 133, cy: 114, r: 9.5)
            var rightBody = Path()
            rightBody.move(to: CGPoint(x: 118, y: 168))
            rightBody.addLine(to: CGPoint(x: 118, y: 150))
            rightBody.addQuadCurve(to: CGPoint(x: 133, y: 139), control: CGPoint(x: 118, y: 139))
            rightBody.addQuadCurve(to: CGPoint(x: 148, y: 150), control: CGPoint(x: 148, y: 139))
            rightBody.addLine(to: CGPoint(x: 148, y: 168))
            rightBody.closeSubpath()
            context.fill(rightBody, with: .color(color))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.48, green: 0.51, blue: 0.94),
                Color(red: 0.36, green: 0.42, blue: 0.90),
                Color(red: 0.29, green: 0.33, blue: 0.80),
            ],
            startPoint: UnitPoint(x: 0.18, y: 0),
            endPoint: UnitPoint(x: 0.82, y: 1)
        )
        SplashMarkView()
            .frame(width: 100, height: 100)
    }
}
