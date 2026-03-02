import SwiftUI

struct TermsGateView<Content: View>: View {
    @ObservedObject var termsStore: TermsAcceptanceStore

    let onDecline: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if termsStore.hasAcceptedTerms {
                content()
            } else {
                TermsAndConditionsView(
                    onAccept: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            termsStore.acceptTerms()
                        }
                    },
                    onDecline: onDecline
                )
            }
        }
    }
}

#Preview {
    TermsGateView(
        termsStore: TermsAcceptanceStore(),
        onDecline: {}
    ) {
        Text("Main app content")
    }
}
