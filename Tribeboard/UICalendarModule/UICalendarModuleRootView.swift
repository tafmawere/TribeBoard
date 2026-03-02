import SwiftUI

private enum UICalendarRoute: Hashable {
    case dayList(Date)
    case runConfirmation(UIScheduleOccurrence)
}

private enum UICalendarRootTab: String, CaseIterable, Identifiable {
    case calendar = "Calendar"
    case schedules = "Schedules"
    var id: String { rawValue }
}

struct UICalendarModuleRootView: View {
    @State private var path: [UICalendarRoute] = []
    @State private var rootTab: UICalendarRootTab = .calendar

    @State private var monthDate = Date()
    @State private var selectedDate = Date()
    @State private var schedules = UICalendarMockData.schedules

    @State private var editingSchedule: UISchedule?
    @State private var showingEditor = false
    @State private var runLinkAlert = false

    private var monthOccurrences: [UIScheduleOccurrence] {
        UICalendarMockData.occurrencesForMonth(containing: monthDate, schedules: schedules)
    }

    private var selectedDayOccurrences: [UIScheduleOccurrence] {
        UICalendarMockData.occurrencesForDay(selectedDate, schedules: schedules)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                UICalendarDesignSystem.Colors.background.ignoresSafeArea()

                VStack(spacing: UICalendarDesignSystem.Spacing.medium) {
                    Picker("Module", selection: $rootTab) {
                        ForEach(UICalendarRootTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, UICalendarDesignSystem.Spacing.medium)
                    .padding(.top, UICalendarDesignSystem.Spacing.small)

                    Group {
                        switch rootTab {
                        case .calendar:
                            CalendarHomeView(
                                monthDate: $monthDate,
                                selectedDate: $selectedDate,
                                occurrencesForMonth: monthOccurrences,
                                occurrencesForSelectedDate: selectedDayOccurrences,
                                onOpenDayList: { date in
                                    path.append(.dayList(date))
                                },
                                onOpenCreateSchedule: {
                                    editingSchedule = nil
                                    showingEditor = true
                                },
                                onCreateRunNow: { occurrence in
                                    path.append(.runConfirmation(occurrence))
                                },
                                onViewSchedule: { occurrence in
                                    if let schedule = schedules.first(where: { $0.id == occurrence.scheduleId }) {
                                        editingSchedule = schedule
                                        showingEditor = true
                                    }
                                }
                            )
                        case .schedules:
                            ScheduleListView(
                                schedules: $schedules,
                                onCreateSchedule: {
                                    editingSchedule = nil
                                    showingEditor = true
                                },
                                onEditSchedule: { schedule in
                                    editingSchedule = schedule
                                    showingEditor = true
                                }
                            )
                        }
                    }
                }
            }
            .navigationDestination(for: UICalendarRoute.self) { route in
                switch route {
                case let .dayList(date):
                    UICalendarDayScheduleListView(
                        date: date,
                        occurrences: UICalendarMockData.occurrencesForDay(date, schedules: schedules),
                        onCreateRunNow: { occurrence in
                            path.append(.runConfirmation(occurrence))
                        },
                        onViewSchedule: { occurrence in
                            if let schedule = schedules.first(where: { $0.id == occurrence.scheduleId }) {
                                editingSchedule = schedule
                                showingEditor = true
                            }
                        }
                    )
                case let .runConfirmation(occurrence):
                    CreateRunConfirmationView(
                        occurrence: occurrence,
                        onGoToRun: {
                            path.removeAll()
                            rootTab = .calendar
                            runLinkAlert = true
                        }
                    )
                }
            }
            .sheet(isPresented: $showingEditor) {
                UICalendarScheduleEditorView(
                    users: UICalendarMockData.users,
                    editingSchedule: editingSchedule
                ) { saved in
                    if let index = schedules.firstIndex(where: { $0.id == saved.id }) {
                        schedules[index] = saved
                    } else {
                        schedules.append(saved)
                    }
                }
            }
            .alert("Run Module Link", isPresented: $runLinkAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Will link to RunFocus later.")
            }
        }
    }
}

#Preview {
    UICalendarModuleRootView()
}
