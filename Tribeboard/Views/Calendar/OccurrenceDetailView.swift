import SwiftUI
import Combine

@MainActor
final class OccurrenceDetailViewModel: ObservableObject {
    @Published var mockLoaded = true
    let title = "School Dropoff"
    let dateTimeText = "Tue 12 Mar • 06:45"
    let statusText = "From Schedule"
    let driverName = "Tafadzwa"
    let passengers = ["TJ", "Tawana"]
    let stops: [(type: String, label: String, color: Color)] = [
        ("Pickup", "Home", Color.blue),
        ("Dropoff", "School", Color.green)
    ]
}

struct OccurrenceDetailView: View {
    @StateObject private var viewModel = OccurrenceDetailViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    participantsCard
                    stopsCard
                    actionCard
                }
                .padding(16)
            }
            .background(CalendarDesign.background.ignoresSafeArea())
            .navigationTitle("Occurrence")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.primary)
            Text(viewModel.dateTimeText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.secondary)
            Text(viewModel.statusText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.388, green: 0.400, blue: 0.945))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(red: 0.388, green: 0.400, blue: 0.945).opacity(0.12))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .calendarCardStyle()
    }

    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Participants")
                .font(.system(size: 17, weight: .semibold))

            participantRow(name: viewModel.driverName, subtitle: "Driver", badgeText: "Driver")

            ForEach(viewModel.passengers, id: \.self) { passenger in
                participantRow(name: passenger, subtitle: "Passenger", badgeText: nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .calendarCardStyle()
    }

    private var stopsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stops")
                .font(.system(size: 17, weight: .semibold))

            ForEach(Array(viewModel.stops.enumerated()), id: \.offset) { index, stop in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(stop.color)
                            .frame(width: 10, height: 10)
                        if index < viewModel.stops.count - 1 {
                            Rectangle()
                                .fill(Color.gray.opacity(0.35))
                                .frame(width: 2, height: 24)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.type)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.secondary)
                        Text(stop.label)
                            .font(.system(size: 15, weight: .medium))
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .calendarCardStyle()
    }

    private var actionCard: some View {
        VStack(spacing: 10) {
            Button {
                print("Create Run Now tapped")
            } label: {
                Text("Create Run Now")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(red: 0.388, green: 0.400, blue: 0.945))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button {
                print("Edit Schedule tapped")
            } label: {
                Text("Edit Schedule")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.gray.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .calendarCardStyle()
    }

    private func participantRow(name: String, subtitle: String, badgeText: String?) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.blue.opacity(0.18))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String(name.prefix(1)))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.blue)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            if let badgeText {
                Text(badgeText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }
}

private struct CalendarDesign {
    static let background = Color(red: 0.97, green: 0.97, blue: 0.96)
    static let cardRadius: CGFloat = 16
}

private extension View {
    func calendarCardStyle() -> some View {
        self
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: CalendarDesign.cardRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    OccurrenceDetailView()
}
