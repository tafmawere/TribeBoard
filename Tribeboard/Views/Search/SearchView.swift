import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var isLoading = false
    @State private var selectedError: ErrorStateKind? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                searchBar
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(GeneralUXTheme.background.ignoresSafeArea())
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("State") {
                        Button("Loading") {
                            selectedError = nil
                            isLoading = true
                        }
                        Button("Empty") {
                            selectedError = nil
                            isLoading = false
                        }

                        Divider()

                        ForEach(ErrorStateKind.allCases) { error in
                            Button(error.title) {
                                selectedError = error
                                isLoading = false
                            }
                        }
                    }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(GeneralUXTheme.textSecondary)

            TextField("Search runs, family, or schedules", text: $query)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(GeneralUXTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(GeneralUXTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(GeneralUXTheme.border)
        )
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            LoadingSkeletonView(rows: 5)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else if let selectedError {
            ErrorStateView(kind: selectedError, retryAction: {
                self.selectedError = nil
            })
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "Start typing to search",
                message: "Search is UI-only in this build, so results are not connected yet.",
                primaryButtonTitle: "Show Loading Demo"
            ) {
                self.isLoading = true
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

#Preview {
    SearchView()
}
