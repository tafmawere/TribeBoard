import SwiftUI

struct ActiveRunDriverBottomSheet: View {
    let runTitle: String
    let currentStopName: String
    let etaLabel: String
    let distanceLabel: String
    let progress: ActiveRunProgress
    let driverName: String
    let driverAvatar: TribeAvatarIdentity
    let routeStatusMessage: String?
    let isRouteLoading: Bool
    let primaryAction: ActiveRunDriverAction
    let secondaryAction: ActiveRunDriverAction
    let primaryTitle: String
    let secondaryTitle: String
    let canPerformActions: Bool
    let isPerformingAction: Bool
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    let onOpenExternalMaps: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(runTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(currentStopName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
            }

            progressSection

            HStack(spacing: 16) {
                metricBlock(title: "ETA", value: etaLabel, isLoading: isRouteLoading)
                metricBlock(title: "Distance", value: distanceLabel, isLoading: isRouteLoading)
            }

            if let routeStatusMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(routeStatusMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack(spacing: 10) {
                TribeAvatarView(identity: driverAvatar, size: .compact)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Driver")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(driverName)
                        .font(.system(size: 15, weight: .semibold))
                }
                Spacer()
                Button(action: onOpenExternalMaps) {
                    Label("Maps", systemImage: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open in Maps app")
            }

            actionButtons
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: -4)
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(progress.statusLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(progress.fraction * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.10))
                    Capsule()
                        .fill(Color.blue)
                        .frame(width: max(8, proxy.size.width * progress.fraction))
                }
            }
            .frame(height: 6)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        let showSecondary = ActiveRunActionResolver.allowsPrimaryAction(secondaryAction)
            && !secondaryTitle.isEmpty

        if showSecondary {
            HStack(spacing: 10) {
                secondaryButton
                primaryButton
            }
        } else if ActiveRunActionResolver.allowsPrimaryAction(primaryAction) {
            primaryButton
        }
    }

    private var primaryButton: some View {
        Button(action: onPrimary) {
            Group {
                if isPerformingAction {
                    ProgressView().tint(.white)
                } else {
                    Text(primaryTitle)
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(canPerformActions ? Color.blue : Color.gray.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canPerformActions || isPerformingAction || !ActiveRunActionResolver.allowsPrimaryAction(primaryAction))
    }

    private var secondaryButton: some View {
        Button(action: onSecondary) {
            Text(secondaryTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canPerformActions || isPerformingAction)
    }

    private func metricBlock(title: String, value: String, isLoading: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
            }
        }
    }
}
