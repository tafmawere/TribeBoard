import SwiftUI

struct LocationSearchField: View {
    let title: String
    let placeholder: String
    @ObservedObject var model: LocationSearchModel
    let onSelected: (LocationSearchResult) -> Void
    var onCleared: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField(placeholder, text: Binding(
                    get: { model.query },
                    set: { model.setQuery($0) }
                ))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()

                if model.hasVerifiedSelection {
                    Button {
                        model.clearSelection()
                        onCleared?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(uiColor: .tertiarySystemBackground))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        model.hasVerifiedSelection ? Color.green.opacity(0.55) : Color(uiColor: .separator).opacity(0.35),
                        lineWidth: model.hasVerifiedSelection ? 1.5 : 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            if model.hasVerifiedSelection {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Verified location selected")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            if !model.results.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.results) { result in
                            Button {
                                Task {
                                    let resolved = await model.selectResult(result)
                                    onSelected(resolved)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 150)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
                }
            } else if model.noMatchesFound {
                Text("No matches found")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
