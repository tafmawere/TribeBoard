import SwiftUI

struct LoadingStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.gray.opacity(0.16))
                    .frame(height: 20)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 180, height: 14)
            }
        }
        .padding(16)
        .background(GeneralUXTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(GeneralUXTheme.border)
        )
    }
}

#Preview {
    LoadingStateView()
        .padding()
        .background(GeneralUXTheme.background)
}
