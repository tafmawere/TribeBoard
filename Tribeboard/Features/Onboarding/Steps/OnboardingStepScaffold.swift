import SwiftUI

enum OnboardingTheme {
    static let brandPurple = Color(red: 0.388, green: 0.408, blue: 0.945)
    static let cardLavender = Color(red: 0.97, green: 0.965, blue: 0.995)
    static let headlineNavy = Color(red: 0.11, green: 0.13, blue: 0.22)
}

struct OnboardingCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct OnboardingProgressHeader: View {
    let label: String
    let current: Int
    let total: Int
    var stepTitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let stepTitle, !stepTitle.isEmpty {
                    Text(stepTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.headlineNavy)
                }
            }
            GeometryReader { proxy in
                let safeTotal = max(1, total)
                let progress = CGFloat(current) / CGFloat(safeTotal)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemFill))
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(OnboardingTheme.brandPurple)
                        .frame(width: max(10, proxy.size.width * progress))
                }
            }
            .frame(height: 8)
        }
    }
}

struct OnboardingTimeWheel: View {
    @Binding var hour: Int
    @Binding var minute: Int

    var body: some View {
        HStack(spacing: 6) {
            Picker("Hour", selection: $hour) {
                ForEach(0..<24, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .pickerStyle(.menu)
            Text(":")
                .font(.headline)
            Picker("Minute", selection: $minute) {
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .pickerStyle(.menu)
        }
    }
}
