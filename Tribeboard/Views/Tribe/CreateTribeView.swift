import SwiftUI
import UIKit

struct CreateTribeView: View {
    @ObservedObject var store: TribeStore
    let onCreate: () -> Void

    @State private var tribeName = ""
    @State private var tribeCode = TribeStore.generateTribeCode()
    @State private var didCopyTribeCode = false

    var body: some View {
        ZStack {
            TribeTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Spacer().frame(height: 20)

                Text("Create your Family")
                    .font(.title.weight(.bold))
                    .foregroundStyle(TribeTheme.textPrimary)

                Text("Set up your family workspace and start coordinating together.")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.secondary)

                TribeCard {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Family Name")
                                .font(.system(size: 14, weight: .semibold))
                            TextField("e.g. Mawere Family", text: $tribeName)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Family Code")
                                .font(.system(size: 14, weight: .semibold))

                            HStack(spacing: 10) {
                                Text(tribeCode)
                                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                                    .foregroundStyle(TribeTheme.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer(minLength: 8)

                                Button {
                                    copyTribeCode()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("Copy")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(TribeTheme.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(TribeTheme.primary.opacity(0.10))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                ShareLink(item: tribeCode) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text("Share")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(TribeTheme.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(TribeTheme.primary.opacity(0.10))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            if didCopyTribeCode {
                                Text("Copied")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(TribeTheme.primary)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 6)

                Button {
                    store.createTribe(name: tribeName, tribeCode: tribeCode)
                    onCreate()
                } label: {
                    Text("Create Family")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(TribeTheme.primary)
                        .clipShape(Capsule())
                        .shadow(color: TribeTheme.primary.opacity(0.20), radius: 12, x: 0, y: 8)
                        .scaleEffect(isCreateEnabled ? 1.0 : 0.985)
                }
                .disabled(!isCreateEnabled)
                .opacity(isCreateEnabled ? 1.0 : 0.65)
                .animation(.easeInOut(duration: 0.18), value: isCreateEnabled)

                Text("You can edit your tribe later in Settings.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .navigationTitle("New Family")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isCreateEnabled: Bool {
        !tribeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func copyTribeCode() {
        UIPasteboard.general.string = tribeCode
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.easeInOut(duration: 0.18)) {
            didCopyTribeCode = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation(.easeInOut(duration: 0.18)) {
                didCopyTribeCode = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        CreateTribeView(store: TribeStore()) { }
    }
}
