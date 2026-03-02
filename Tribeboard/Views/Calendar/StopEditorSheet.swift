import SwiftUI
import Combine

enum StopTypeOption: String, CaseIterable, Identifiable {
    case pickup = "Pickup"
    case dropoff = "Dropoff"
    var id: String { rawValue }
}

@MainActor
final class StopEditorSheetViewModel: ObservableObject {
    @Published var stopType: StopTypeOption = .pickup
    @Published var label: String = "Home"
    @Published var address: String = "123 Maple St"
    @Published var notes: String = ""
}

struct StopEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = StopEditorSheetViewModel()

    private var canSave: Bool {
        !viewModel.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    cardContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            pickerRow
                            inputField(title: "Label", text: $viewModel.label, placeholder: "e.g., Home")
                            inputField(title: "Address", text: $viewModel.address, placeholder: "Enter address")

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes (optional)")
                                    .font(.system(size: 14, weight: .semibold))
                                TextEditor(text: $viewModel.notes)
                                    .frame(height: 120)
                                    .padding(8)
                                    .background(Color(red: 0.95, green: 0.96, blue: 0.97))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }

                    Button {
                        print("Stop saved: \(viewModel.stopType.rawValue) - \(viewModel.label)")
                        dismiss()
                    } label: {
                        Text("Save")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color(red: 0.388, green: 0.400, blue: 0.945))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.55)
                }
                .padding(16)
            }
            .background(CalendarDesign.background.ignoresSafeArea())
            .navigationTitle("Edit Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var pickerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stop Type")
                .font(.system(size: 14, weight: .semibold))
            Picker("Stop Type", selection: $viewModel.stopType) {
                ForEach(StopTypeOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func inputField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            TextField(placeholder, text: text)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(red: 0.95, green: 0.96, blue: 0.97))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct CalendarDesign {
    static let background = Color(red: 0.97, green: 0.97, blue: 0.96)
    static let cardRadius: CGFloat = 16
}

private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: CalendarDesign.cardRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
}

#Preview {
    StopEditorSheet()
}
