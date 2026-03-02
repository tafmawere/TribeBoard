import SwiftUI

enum ScheduleListFilter: String, CaseIterable, Identifiable {
    case enabled = "Enabled"
    case all = "All"
    var id: String { rawValue }
}

struct ScheduleListView: View {
    @Binding var schedules: [UISchedule]
    @State private var filter: ScheduleListFilter = .enabled

    let onCreateSchedule: () -> Void
    let onEditSchedule: (UISchedule) -> Void

    private var filteredSchedules: [UISchedule] {
        switch filter {
        case .enabled:
            return schedules.filter(\.isEnabled)
        case .all:
            return schedules
        }
    }

    var body: some View {
        ZStack {
            UICalendarDesignSystem.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: UICalendarDesignSystem.Spacing.medium) {
                    Text("All Schedules")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(UICalendarDesignSystem.Colors.textPrimary)

                    Picker("Filter", selection: $filter) {
                        ForEach(ScheduleListFilter.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    VStack(spacing: 10) {
                        ForEach(filteredSchedules) { schedule in
                            UIScheduleRow(
                                schedule: schedule,
                                isEnabled: bindingForEnabled(id: schedule.id)
                            ) {
                                onEditSchedule(schedule)
                            }
                        }
                    }

                    UICalendarPrimaryButton(title: "+ New Schedule", action: onCreateSchedule)
                }
                .padding(UICalendarDesignSystem.Spacing.medium)
            }
        }
        .navigationTitle("Schedules")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bindingForEnabled(id: UUID) -> Binding<Bool> {
        Binding(
            get: { schedules.first(where: { $0.id == id })?.isEnabled ?? false },
            set: { newValue in
                guard let index = schedules.firstIndex(where: { $0.id == id }) else { return }
                schedules[index].isEnabled = newValue
            }
        )
    }
}

#Preview {
    NavigationStack {
        ScheduleListView(
            schedules: .constant(UICalendarMockData.schedules),
            onCreateSchedule: {},
            onEditSchedule: { _ in }
        )
    }
}
