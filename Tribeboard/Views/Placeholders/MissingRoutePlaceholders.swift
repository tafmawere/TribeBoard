import SwiftUI

struct RunEditView: View {
    let runId: String

    var body: some View {
        VStack(spacing: 12) {
            Text("Run Edit")
                .font(.title2.weight(.semibold))
            Text("runId: \(runId)")
                .foregroundStyle(.secondary)
            Text("TODO: implement")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle("Edit Run")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CancelRunView: View {
    let runId: String

    var body: some View {
        VStack(spacing: 12) {
            Text("Cancel Run")
                .font(.title2.weight(.semibold))
            Text("runId: \(runId)")
                .foregroundStyle(.secondary)
            Text("TODO: implement")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle("Cancel Run")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ErrorScreenView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Text("Error")
                .font(.title2.weight(.semibold))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("TODO: implement")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle("Error")
        .navigationBarTitleDisplayMode(.inline)
    }
}
