import SwiftUI
import UIKit

// MARK: - Lightweight markers (icons + circular avatars only)

private enum AuthHeroMarkers {
    static let carIcon = asset("icon_car")
    static let schoolIcon = asset("icon_school")
    static let tennisIcon = asset("icon_tennis", fallbacks: ["activity_tennis"])

    static let avatarRue = asset("avatar_mother", fallbacks: ["avatar_mother_driving", "avatar_father"])
    static let avatarTJ = asset("avatar_boy_school", fallbacks: ["avatar_boy"])
    static let avatarTC = asset("avatar_girl", fallbacks: ["avatar_girl_otw"])

    private static func asset(_ name: String, fallbacks: [String] = []) -> String? {
        if UIImage(named: name) != nil { return name }
        for candidate in fallbacks where UIImage(named: candidate) != nil {
            return candidate
        }
        return nil
    }
}

/// Live family-coordination hero — one connected trip, not separate illustration cards.
struct AuthHeroIllustrationView: View {
    var height: CGFloat = 168

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var routePulse = false
    @State private var floatPhase = false
    @State private var schoolGlow = false

    var body: some View {
        AuthHeroCoordinationScene(
            height: height,
            routePulse: routePulse,
            floatPhase: floatPhase,
            schoolGlow: schoolGlow,
            reduceMotion: reduceMotion
        )
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Family journey from driving to school to tennis practice")
        .onAppear(perform: startMotionIfAllowed)
    }

    private func startMotionIfAllowed() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            routePulse = true
        }
        withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
            floatPhase = true
        }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            schoolGlow = true
        }
    }
}

// MARK: - Cohesive coordination scene

private struct AuthHeroCoordinationScene: View {
    let height: CGFloat
    let routePulse: Bool
    let floatPhase: Bool
    let schoolGlow: Bool
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let car = HeroWaypoint.car.point(in: size)
            let school = HeroWaypoint.school.point(in: size)
            let tennis = HeroWaypoint.tennis.point(in: size)

            ZStack {
                HeroLiveTripRoute(
                    car: car,
                    school: school,
                    tennis: tennis
                )
                .stroke(
                    AuthTheme.primary.opacity(routePulse ? 0.7 : 0.36),
                    style: StrokeStyle(
                        lineWidth: 3.5,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [9, 10],
                        dashPhase: routePulse ? 8 : 0
                    )
                )
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.8), value: routePulse)

                routeDots(car: car, school: school, tennis: tennis)

                schoolHub(at: school, in: size)
                drivingStop(at: car, in: size)
                tennisStop(at: tennis, in: size)

                statusPills(size: size, car: car, school: school, tennis: tennis)
            }
        }
    }

    // MARK: Stops

    @ViewBuilder
    private func schoolHub(at point: CGPoint, in size: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AuthTheme.primary.opacity(schoolGlow ? 0.28 : 0.14),
                            AuthTheme.primary.opacity(0.02)
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 44
                    )
                )
                .frame(width: 88, height: 88)
                .blur(radius: 2)
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.5), value: schoolGlow)

            HeroMapIcon(
                assetName: AuthHeroMarkers.schoolIcon,
                systemFallback: "building.columns.fill",
                tint: AuthTheme.teal,
                width: 46,
                height: 46
            )
            .offset(y: floatY(1))

            if let tj = AuthHeroMarkers.avatarTJ {
                HeroAvatarMarker(name: tj, size: 28)
                    .offset(y: 36 + floatY(1.2))
            }
        }
        .position(point)
    }

    @ViewBuilder
    private func drivingStop(at point: CGPoint, in size: CGSize) -> some View {
        ZStack {
            HeroMapIcon(
                assetName: AuthHeroMarkers.carIcon,
                systemFallback: "car.fill",
                tint: AuthTheme.headlineNavy.opacity(0.75),
                width: 34,
                height: 22
            )
            .offset(y: -18 + floatY(1))

            if let rue = AuthHeroMarkers.avatarRue {
                HeroAvatarMarker(name: rue, size: 26)
                    .offset(y: 10 + floatY(1.4))
            }
        }
        .position(point)
    }

    @ViewBuilder
    private func tennisStop(at point: CGPoint, in size: CGSize) -> some View {
        ZStack {
            HeroMapIcon(
                assetName: AuthHeroMarkers.tennisIcon,
                systemFallback: "tennisball.fill",
                tint: AuthTheme.primary,
                width: 28,
                height: 28
            )
            .offset(y: -16 + floatY(1))

            if let tc = AuthHeroMarkers.avatarTC {
                HeroAvatarMarker(name: tc, size: 26)
                    .offset(y: 10 + floatY(1.2))
            }
        }
        .position(point)
    }

    // MARK: Pills

    private func statusPills(size: CGSize, car: CGPoint, school: CGPoint, tennis: CGPoint) -> some View {
        ZStack {
            AuthLiveStatusPill(
                name: "Rue",
                status: "Driving",
                dotColor: AuthTheme.orange,
                breathe: floatPhase,
                reduceMotion: reduceMotion
            )
            .position(x: car.x - 4, y: car.y - size.height * 0.22)

            AuthLiveStatusPill(
                name: "TJ",
                status: "At School",
                dotColor: AuthTheme.liveGreen,
                breathe: floatPhase,
                reduceMotion: reduceMotion
            )
            .position(x: school.x, y: school.y - size.height * 0.2)

            AuthLiveStatusPill(
                name: "TC",
                status: "Tennis",
                dotColor: AuthTheme.primary,
                breathe: floatPhase,
                reduceMotion: reduceMotion
            )
            .position(x: tennis.x + 2, y: tennis.y - size.height * 0.22)
        }
        .allowsHitTesting(false)
    }

    private func routeDots(car: CGPoint, school: CGPoint, tennis: CGPoint) -> some View {
        ZStack {
            HeroRouteDot(color: AuthTheme.orange, pulse: routePulse, reduceMotion: reduceMotion)
                .position(car)
            HeroRouteDot(color: AuthTheme.liveGreen, pulse: routePulse, reduceMotion: reduceMotion)
                .position(school)
            HeroRouteDot(color: AuthTheme.primary, pulse: routePulse, reduceMotion: reduceMotion)
                .position(tennis)
        }
    }

    private func floatY(_ amount: CGFloat) -> CGFloat {
        guard !reduceMotion else { return 0 }
        return floatPhase ? amount : -amount
    }
}

// MARK: - Waypoints (car → school → activity)

private enum HeroWaypoint {
    case car
    case school
    case tennis

    func point(in size: CGSize) -> CGPoint {
        switch self {
        case .car:
            return CGPoint(x: size.width * 0.15, y: size.height * 0.78)
        case .school:
            return CGPoint(x: size.width * 0.5, y: size.height * 0.36)
        case .tennis:
            return CGPoint(x: size.width * 0.85, y: size.height * 0.76)
        }
    }
}

// MARK: - Route shape

private struct HeroLiveTripRoute: Shape {
    let car: CGPoint
    let school: CGPoint
    let tennis: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: car)

        path.addCurve(
            to: school,
            control1: CGPoint(x: car.x + rect.width * 0.12, y: car.y - rect.height * 0.22),
            control2: CGPoint(x: school.x - rect.width * 0.14, y: school.y + rect.height * 0.18)
        )

        path.addCurve(
            to: tennis,
            control1: CGPoint(x: school.x + rect.width * 0.14, y: school.y + rect.height * 0.16),
            control2: CGPoint(x: tennis.x - rect.width * 0.12, y: tennis.y - rect.height * 0.2)
        )

        return path
    }
}

// MARK: - Components

private struct HeroMapIcon: View {
    let assetName: String?
    let systemFallback: String
    let tint: Color
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: height)
            } else {
                Image(systemName: systemFallback)
                    .font(.system(size: min(width, height) * 0.72, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: width, height: height)
            }
        }
        .shadow(color: tint.opacity(0.15), radius: 6, y: 2)
    }
}

/// Small circular profile marker — no rectangular image containers.
private struct HeroAvatarMarker: View {
    let name: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.08), radius: 5, y: 2)

            Circle()
                .fill(Color.white)
                .frame(width: size - 4, height: size - 4)
                .overlay {
                    Image(name)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size - 4, height: size - 4)
                        .clipShape(Circle())
                }
        }
        .frame(width: size, height: size)
        .overlay {
            Circle()
                .strokeBorder(Color.white, lineWidth: 2)
        }
    }
}

private struct HeroRouteDot: View {
    let color: Color
    let pulse: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(pulse ? 0.22 : 0.1))
                .frame(width: 18, height: 18)
                .scaleEffect(reduceMotion ? 1 : (pulse ? 1.15 : 0.9))
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 2.8), value: pulse)
    }
}
