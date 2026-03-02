import SwiftUI

struct AvatarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onUploadPhoto: () -> Void
    let onSelectSymbol: (AvatarSymbol) -> Void
    let onRemovePhoto: (() -> Void)?

    private let presets = AvatarSymbol.allCases
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack {
                    Text("Choose Avatar")
                        .font(.system(size: 24, weight: .bold))
                    Spacer()
                    Button("Upload Photo") {
                        onUploadPhoto()
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                }

                if let onRemovePhoto {
                    Button(role: .destructive) {
                        onRemovePhoto()
                        dismiss()
                    } label: {
                        Text("Remove Photo")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(presets, id: \.self) { preset in
                            Button {
                                onSelectSymbol(preset)
                                dismiss()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.10))
                                        .frame(width: 68, height: 68)
                                    Image(systemName: preset.rawValue)
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AvatarPickerSheet(onUploadPhoto: { }, onSelectSymbol: { _ in }, onRemovePhoto: { })
}
