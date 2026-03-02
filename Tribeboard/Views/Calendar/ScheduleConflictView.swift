import SwiftUI
import Combine

@MainActor
final class ScheduleConflictViewModel: ObservableObject {
    @Published var mockLoaded = true
    let title = "Schedule Conflict"
    let description = "This schedule overlaps with another existing school run schedule."
    let firstSchedule = "School Dropoff • 06:45 - 07:30"
    let secondSchedule = "Piano Lesson Ride • 07:00 - 07:40"
}

struct ScheduleConflictView: View {
    @StateObject private var viewModel = ScheduleConflictViewModel()

    var body: some View {
        ZStack {
            CalendarDesign.background.ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Color.orange)

                    Text(viewModel.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.primary)

                    Text(viewModel.description)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.firstSchedule)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.primary)
                        Divider()
                        Text(viewModel.secondSchedule)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.primary)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        print("Keep Both tapped")
                    } label: {
                        Text("Keep Both")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Button {
                        print("Adjust Time tapped")
                    } label: {
                        Text("Adjust Time")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }
}

private struct CalendarDesign {
    static let background = Color(red: 0.97, green: 0.97, blue: 0.96)
}

#Preview {
    ScheduleConflictView()
}
