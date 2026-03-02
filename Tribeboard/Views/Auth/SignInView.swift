import SwiftUI

struct SignInView: View {
    @EnvironmentObject var flow: AppFlowState
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        Form {
            Section("Sign In") {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                SecureField("Password", text: $password)
            }

            Section {
                Button("Continue") {
                    flow.signIn()
                }
                .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)
            }
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SignInView()
            .environmentObject(AppFlowState())
    }
}
