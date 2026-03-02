import SwiftUI
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var fullName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var agreedToTerms = false

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var didSendReset = false

    func validateLogin() -> Bool {
        errorMessage = nil

        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Please enter your email."
            return false
        }

        if !isValidEmail(email) {
            errorMessage = "Please enter a valid email address."
            return false
        }

        if password.isEmpty {
            errorMessage = "Please enter your password."
            return false
        }

        return true
    }

    func validateSignup() -> Bool {
        errorMessage = nil

        if fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Please enter your full name."
            return false
        }

        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Please enter your email."
            return false
        }

        if !isValidEmail(email) {
            errorMessage = "Please enter a valid email address."
            return false
        }

        if password.count < 8 {
            errorMessage = "Password must be at least 8 characters."
            return false
        }

        if confirmPassword != password {
            errorMessage = "Passwords do not match."
            return false
        }

        if !agreedToTerms {
            errorMessage = "Please agree to Terms & Privacy."
            return false
        }

        return true
    }

    func validateReset() -> Bool {
        errorMessage = nil

        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Please enter your email."
            return false
        }

        if !isValidEmail(email) {
            errorMessage = "Please enter a valid email address."
            return false
        }

        return true
    }

    func loginTapped() async {
        guard validateLogin() else { return }

        isLoading = true
        defer { isLoading = false }
        try? await Task.sleep(nanoseconds: 900_000_000)
    }

    func signupTapped() async {
        guard validateSignup() else { return }

        isLoading = true
        defer { isLoading = false }
        try? await Task.sleep(nanoseconds: 900_000_000)
    }

    func resetTapped() async {
        guard validateReset() else { return }

        isLoading = true
        didSendReset = false
        defer { isLoading = false }
        try? await Task.sleep(nanoseconds: 900_000_000)
        didSendReset = true
    }

    private func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
    }
}
