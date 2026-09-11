import SwiftUI

/// Lightweight skeleton placeholders that mirror Home card layout without heavy shimmer.
struct HomeLoadingPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            heroSkeleton
            horizontalCardsSkeleton(titleWidth: 120)
            timelineSkeleton
            horizontalCardsSkeleton(titleWidth: 160)
        }
    }

    private var heroSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            skeletonBar(width: 88, height: 11)
            skeletonBar(width: nil, height: 132, cornerRadius: 18)
            skeletonBar(width: 200, height: 16)
            skeletonBar(width: 140, height: 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TribePalette.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func horizontalCardsSkeleton(titleWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            skeletonBar(width: titleWidth, height: 12)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(0 ..< 3, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 6) {
                            skeletonBar(width: 40, height: 40, cornerRadius: 20)
                            skeletonBar(width: 64, height: 10)
                        }
                        .padding(10)
                        .frame(width: 100, alignment: .leading)
                        .background(TribePalette.surface.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    private var timelineSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            skeletonBar(width: 100, height: 12)
            VStack(spacing: 8) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    HStack(spacing: 10) {
                        skeletonBar(width: 48, height: 10)
                        skeletonBar(width: nil, height: 36, cornerRadius: 10)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TribePalette.surface.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func skeletonBar(width: CGFloat?, height: CGFloat, cornerRadius: CGFloat = 6) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.primary.opacity(0.06))
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

/// Subtle in-tab placeholders for Runs, Calendar, Family, and More during bootstrap.
struct HouseholdTabSkeletonView: View {
    var showsSyncingStatus: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsSyncingStatus {
                HStack {
                    Spacer()
                    SyncingMicroStatus(isActive: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            VStack(spacing: 10) {
                ForEach(0 ..< 4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                        .frame(height: 68)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(TribePalette.canvas.ignoresSafeArea())
    }
}
