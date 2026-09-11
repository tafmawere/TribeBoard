import SwiftUI

enum ErrorStateKind: CaseIterable, Identifiable {
    case noInternet
    case runNotFound
    case permissionDenied
    case loadFailed

    var id: String { title }

    var icon: String {
        switch self {
        case .noInternet: return "wifi.slash"
        case .runNotFound: return "map.fill"
        case .permissionDenied: return "lock.shield"
        case .loadFailed: return "exclamationmark.triangle"
        }
    }

    var title: String {
        switch self {
        case .noInternet: return "No internet connection"
        case .runNotFound: return "Run not found"
        case .permissionDenied: return "Permission denied"
        case .loadFailed: return "Couldn't load"
        }
    }

    var message: String {
        switch self {
        case .noInternet:
            return "Reconnect and try again to load the latest run updates."
        case .runNotFound:
            return "This run might have been removed or moved to a different day."
        case .permissionDenied:
            return "Your account cannot access this area. Contact your family admin."
        case .loadFailed:
            return BackendUserFacingErrorMapper.genericLoadFailure
        }
    }
}

struct ErrorStateView: View {
    let kind: ErrorStateKind
    var retryButtonTitle: String = "Retry"
    var retryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(Color.red.opacity(0.12))
                .frame(width: 76, height: 76)
                .overlay {
                    Image(systemName: kind.icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.9))
                }

            VStack(spacing: 8) {
                Text(kind.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(GeneralUXTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(kind.message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(GeneralUXTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 320)

            Button(retryButtonTitle) {
                retryAction?()
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(GeneralUXTheme.primary)
            .clipShape(Capsule())
            .shadow(color: GeneralUXTheme.primary.opacity(0.20), radius: 8, x: 0, y: 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GeneralUXTheme.background)
    }
}

#Preview("Error Variants") {
    NavigationStack {
        List {
            ForEach(ErrorStateKind.allCases) { kind in
                NavigationLink(kind.title) {
                    ErrorStateView(kind: kind) {
                        // UI-only action
                    }
                }
            }
        }
        .navigationTitle("Error States")
    }
}
