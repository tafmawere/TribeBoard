import SwiftUI

struct ChildAvatarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedKey: String
    var onSelectionChanged: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Pick how this child appears in your tribe.")
                        .font(.system(size: 15))
                        .foregroundStyle(TribeTheme.textSecondary)

                    ForEach(AvatarPresetCatalog.childAvatarSections(), id: \.title) { section in
                        sectionCard(section)
                    }
                }
                .padding(20)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("Choose child avatar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
    }

    private func sectionCard(_ section: (title: String, options: [ChildAvatarOption])) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(TribeTheme.textSecondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 76), spacing: 12)],
                spacing: 12
            ) {
                ForEach(section.options) { option in
                    avatarTile(option)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    private func avatarTile(_ option: ChildAvatarOption) -> some View {
        let isSelected = selectedKey == option.key
        return Button {
            selectedKey = option.key
            onSelectionChanged?()
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(option.assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(
                                    isSelected ? TribeAvatarStyle.accent : Color.gray.opacity(0.18),
                                    lineWidth: isSelected ? 3 : 1
                                )
                        }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, TribeAvatarStyle.accent)
                            .offset(x: 4, y: -4)
                    }
                }

                Text(option.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TribeTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
