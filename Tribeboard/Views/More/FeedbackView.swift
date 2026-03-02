import SwiftUI
import UIKit

struct FeedbackView: View {
    private enum FeedbackCategory: String, CaseIterable, Identifiable {
        case bug = "Bug"
        case feature = "Feature"
        case ui = "UI"
        case performance = "Performance"
        case other = "Other"

        var id: String { rawValue }
    }

    @Environment(\.openURL) private var openURL

    @State private var rating: Int = 0
    @State private var selectedCategory: FeedbackCategory?
    @State private var feedbackText: String = ""
    @State private var includeDiagnostics = true
    @State private var didAttemptSubmit = false
    @State private var submissionError: String?

    private let supportEmail = "support@tribeboard.app"
    private let minimumFeedbackLength = 20

    private var trimmedFeedback: String {
        feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFeedbackLengthValid: Bool {
        trimmedFeedback.count >= minimumFeedbackLength
    }

    private var isFormValid: Bool {
        rating > 0 && selectedCategory != nil && isFeedbackLengthValid
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Send Feedback")
                    .font(.system(size: 30, weight: .bold))

                Text("Tell us what is working and what we can improve.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                ratingSection
                categorySection
                messageSection
                diagnosticsSection
                submitSection
            }
            .padding(20)
        }
        .background(Color(red: 0.976, green: 0.980, blue: 0.984).ignoresSafeArea())
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rating")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        rating = value
                    } label: {
                        Image(systemName: value <= rating ? "star.fill" : "star")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(value <= rating ? Color.yellow.opacity(0.9) : Color.secondary.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                }
            }

            if didAttemptSubmit && rating == 0 {
                validationText("Please select a rating.")
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(FeedbackCategory.allCases) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : Color(red: 0.388, green: 0.400, blue: 0.945))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color(red: 0.388, green: 0.400, blue: 0.945) : Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.10))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if didAttemptSubmit && selectedCategory == nil {
                validationText("Please choose a category.")
            }
        }
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Feedback")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            TextEditor(text: $feedbackText)
                .frame(minHeight: 150)
                .padding(10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isFeedbackLengthValid || trimmedFeedback.isEmpty ? Color.black.opacity(0.08) : Color.red.opacity(0.45), lineWidth: 1)
                }

            Text("\(trimmedFeedback.count)/\(minimumFeedbackLength) minimum characters")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isFeedbackLengthValid ? .secondary : Color.red.opacity(0.9))

            if didAttemptSubmit && !isFeedbackLengthValid {
                validationText("Please enter at least \(minimumFeedbackLength) characters.")
            }
        }
    }

    private var diagnosticsSection: some View {
        Toggle("Include diagnostics", isOn: $includeDiagnostics)
            .font(.system(size: 14, weight: .semibold))
            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.388, green: 0.400, blue: 0.945)))
    }

    private var submitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                didAttemptSubmit = true
                guard isFormValid else { return }
                submitViaMailto()
            } label: {
                Text("Submit")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color(red: 0.388, green: 0.400, blue: 0.945))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!isFormValid)
            .opacity(isFormValid ? 1 : 0.55)

            if let submissionError {
                validationText(submissionError)
            }
        }
    }

    private func validationText(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.red.opacity(0.9))
    }

    private func submitViaMailto() {
        submissionError = nil
        guard let category = selectedCategory else {
            submissionError = "Please choose a category."
            return
        }

        let body = makeMailBody(category: category)
        let subject = "TribeBoard Feedback - \(category.rawValue)"

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        guard let url = components.url else {
            submissionError = "Unable to prepare email draft."
            return
        }

        openURL(url) { accepted in
            if !accepted {
                submissionError = "No mail app available to submit feedback."
            }
        }
    }

    private func makeMailBody(category: FeedbackCategory) -> String {
        var lines: [String] = [
            "Feedback Submission",
            "-------------------",
            "Rating: \(rating)/5",
            "Category: \(category.rawValue)",
            "Timestamp: \(ISO8601DateFormatter().string(from: Date()))",
            "",
            "Message:",
            trimmedFeedback
        ]

        if includeDiagnostics {
            lines.append(contentsOf: [
                "",
                "Diagnostics:",
                "App Version: \(appVersionString)",
                "iOS Version: \(UIDevice.current.systemVersion)",
                "Device Model: \(deviceModelIdentifier)"
            ])
        }

        return lines.joined(separator: "\n")
    }

    private var appVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    private var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(String(UnicodeScalar(UInt8(value))))
        }
    }
}

#Preview {
    NavigationStack {
        FeedbackView()
    }
}
