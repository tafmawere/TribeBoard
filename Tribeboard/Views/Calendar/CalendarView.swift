//
//  CalendarView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import SwiftUI
import Combine

// MARK: - CalendarViewModel

/// View model for the calendar view that manages schedule occurrences
@MainActor
class CalendarViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var occurrences: [Date: [ScheduledRunPreview]] = [:]
    @Published var isLoading = false
    
    // MARK: - Dependencies
    
    private let generator: ScheduleRunGenerator
    private let calendar: Calendar
    
    // MARK: - Initialization
    
    init(generator: ScheduleRunGenerator, calendar: Calendar = .current) {
        self.generator = generator
        self.calendar = calendar
    }
    
    // MARK: - Public Methods
    
    /// Load occurrences for a specific month
    func loadOccurrences(for month: Date) async {
        isLoading = true
        defer { isLoading = false }
        
        // Get the first and last day of the month
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else {
            return
        }
        
        let startDate = monthInterval.start
        let endDate = monthInterval.end
        
        // Generate previews for the month
        let previews = generator.occurrences(in: startDate...endDate)
        
        // Group previews by date
        var grouped: [Date: [ScheduledRunPreview]] = [:]
        for preview in previews {
            let dayStart = calendar.startOfDay(for: preview.occurrenceDateTime)
            grouped[dayStart, default: []].append(preview)
        }
        
        // Sort each day's previews by time
        for (date, previews) in grouped {
            grouped[date] = previews.sorted { $0.occurrenceDateTime < $1.occurrenceDateTime }
        }
        
        occurrences = grouped
    }
    
    /// Get occurrences for a specific date
    func occurrences(for date: Date) -> [ScheduledRunPreview] {
        let dayStart = calendar.startOfDay(for: date)
        return occurrences[dayStart] ?? []
    }
    
    /// Check if a date has any occurrences
    func hasOccurrences(on date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        return occurrences[dayStart]?.isEmpty == false
    }
}

// MARK: - CalendarView

/// Calendar view displaying a month grid with schedule occurrences
struct CalendarView: View {
    
    // MARK: - State Properties
    
    @StateObject private var viewModel: CalendarViewModel
    @State private var selectedDate: Date = Date()
    @State private var displayedMonth: Date = Date()
    
    // MARK: - Environment
    
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Private Properties
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    
    // MARK: - Initialization
    
    init(viewModel: CalendarViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Month navigation header
                monthNavigationHeader
                    .padding(.horizontal, DesignSystem.Spacing.spacing16)
                    .padding(.vertical, DesignSystem.Spacing.spacing12)
                
                Divider()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.spacing20) {
                        // Calendar grid
                        monthGridView
                            .padding(.horizontal, DesignSystem.Spacing.spacing16)
                            .padding(.top, DesignSystem.Spacing.spacing16)
                        
                        // Selected day occurrences
                        if !viewModel.occurrences(for: selectedDate).isEmpty {
                            selectedDayOccurrencesView
                                .padding(.horizontal, DesignSystem.Spacing.spacing16)
                        }
                    }
                    .padding(.bottom, DesignSystem.Spacing.spacing20)
                }
                .background(DesignSystem.Colors.screenBackground)
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.loadOccurrences(for: displayedMonth)
        }
    }
    
    // MARK: - Month Navigation Header
    
    private var monthNavigationHeader: some View {
        HStack {
            // Previous month button
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(DesignSystem.Colors.primaryBlue)
            }
            
            Spacer()
            
            // Month and year display
            Text(monthYearString)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
            
            // Next month button
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(DesignSystem.Colors.primaryBlue)
            }
        }
    }
    
    // MARK: - Month Grid View
    
    private var monthGridView: some View {
        VStack(spacing: DesignSystem.Spacing.spacing12) {
            // Weekday headers
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar days
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        dayCell(for: date)
                    } else {
                        // Empty cell for padding
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.spacing16)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.radiusLarge)
        .shadow(
            color: DesignSystem.Shadow.card.color,
            radius: DesignSystem.Shadow.card.radius,
            x: DesignSystem.Shadow.card.x,
            y: DesignSystem.Shadow.card.y
        )
    }
    
    // MARK: - Day Cell
    
    private func dayCell(for date: Date) -> some View {
        Button(action: {
            selectedDate = date
        }) {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.body)
                    .fontWeight(isToday(date) ? .bold : .regular)
                    .foregroundColor(cellTextColor(for: date))
                
                // Indicator dot for days with occurrences
                if viewModel.hasOccurrences(on: date) {
                    Circle()
                        .fill(DesignSystem.Colors.primaryBlue)
                        .frame(width: 6, height: 6)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(cellBackgroundColor(for: date))
            .cornerRadius(DesignSystem.CornerRadius.radiusSmall)
        }
    }
    
    // MARK: - Selected Day Occurrences View
    
    private var selectedDayOccurrencesView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.spacing12) {
            // Section header
            Text(selectedDateString)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.spacing16)
                .padding(.top, DesignSystem.Spacing.spacing16)
            
            // Occurrences list
            VStack(spacing: DesignSystem.Spacing.spacing12) {
                ForEach(viewModel.occurrences(for: selectedDate)) { preview in
                    SchedulePreviewCard(preview: preview)
                        .onTapGesture {
                            // Navigate to day schedule list view
                            appCoordinator.presentSheet(.dayScheduleList(date: selectedDate))
                        }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.spacing16)
            .padding(.bottom, DesignSystem.Spacing.spacing16)
        }
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.radiusLarge)
        .shadow(
            color: DesignSystem.Shadow.card.color,
            radius: DesignSystem.Shadow.card.radius,
            x: DesignSystem.Shadow.card.x,
            y: DesignSystem.Shadow.card.y
        )
    }
    
    // MARK: - Helper Methods
    
    private func previousMonth() {
        guard let newMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else {
            return
        }
        displayedMonth = newMonth
        Task {
            await viewModel.loadOccurrences(for: displayedMonth)
        }
    }
    
    private func nextMonth() {
        guard let newMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else {
            return
        }
        displayedMonth = newMonth
        Task {
            await viewModel.loadOccurrences(for: displayedMonth)
        }
    }
    
    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }
    
    private func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    private func cellTextColor(for date: Date) -> Color {
        if isSelected(date) {
            return .white
        } else if isToday(date) {
            return DesignSystem.Colors.primaryBlue
        } else {
            return DesignSystem.Colors.textPrimary
        }
    }
    
    private func cellBackgroundColor(for date: Date) -> Color {
        if isSelected(date) {
            return DesignSystem.Colors.primaryBlue
        } else if isToday(date) {
            return DesignSystem.Colors.primaryBlueLight
        } else {
            return Color.clear
        }
    }
    
    // MARK: - Computed Properties
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }
    
    private var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: selectedDate)
    }
    
    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        // Reorder to start with Monday if needed (depends on calendar locale)
        return symbols
    }
    
    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        
        var days: [Date?] = []
        var currentDate = monthFirstWeek.start
        
        // Generate dates for the calendar grid (including padding days)
        while days.count < 42 { // 6 weeks * 7 days
            if calendar.isDate(currentDate, equalTo: displayedMonth, toGranularity: .month) {
                days.append(currentDate)
            } else if currentDate < monthInterval.start {
                // Padding before month starts
                days.append(nil)
            } else {
                // Stop after month ends
                break
            }
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        
        return days
    }
}

// MARK: - Schedule Preview Card

/// Card component for displaying a schedule preview
struct SchedulePreviewCard: View {
    let preview: ScheduledRunPreview
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.spacing12) {
            // Time indicator
            VStack(alignment: .leading, spacing: 4) {
                Text(timeString)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .frame(width: 60, alignment: .leading)
            
            // Divider
            Rectangle()
                .fill(DesignSystem.Colors.textTertiary.opacity(0.3))
                .frame(width: 1)
            
            // Schedule details
            VStack(alignment: .leading, spacing: 4) {
                Text(preview.title)
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text("\(preview.passengerUserIds.count) passenger\(preview.passengerUserIds.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
        .padding(DesignSystem.Spacing.spacing12)
        .background(DesignSystem.Colors.screenBackground)
        .cornerRadius(DesignSystem.CornerRadius.radiusMedium)
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: preview.occurrenceDateTime)
    }
}

// MARK: - Preview

#if DEBUG
struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        let container = DependencyContainer()
        let viewModel = container.createCalendarViewModel()
        
        return CalendarView(viewModel: viewModel)
            .environmentObject(AppCoordinator(dependencyContainer: container))
    }
}
#endif
