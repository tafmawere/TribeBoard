import SwiftUI

struct HomeView: View {
    private let viewModel = HomeViewModel()
    var onOpenRuns: () -> Void = {}
    var onOpenCalendar: () -> Void = {}
    var onOpenFamily: () -> Void = {}
    var onCreateRun: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    @State private var showProfileSheet = false

    var body: some View {
        ZStack {
            HomeTheme.background
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerRow
                    dateStatusRow
                    sectionDivider
                    primaryRunSection
                    sectionDivider
                    todaysRunsSection
                    createRunButton
                    sectionDivider
                    upcomingEventsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showProfileSheet) {
            NavigationStack {
                ProfileView()
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Button {
                print("Avatar tapped")
                showProfileSheet = true
            } label: {
                Circle()
                    .fill(HomeTheme.primary.opacity(0.14))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text("TM")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(HomeTheme.primary)
                    }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .frame(width: 44, height: 44)

            Spacer()

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [HomeTheme.primary, HomeTheme.primary.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 20, height: 20)
                    .overlay {
                        Image(systemName: "house.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }

                Text("TribeBoard")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(HomeTheme.textPrimary)
            }

            Spacer()

            Button {
                print("Settings tapped")
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(HomeTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .frame(width: 44, height: 44)
        }
    }

    private var dateStatusRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MONDAY, OCTOBER 23RD")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(HomeTheme.textSecondary)
                .tracking(0.8)

            HStack(spacing: 10) {
                StatusChip(
                    title: "\(viewModel.activeRunCount) ACTIVE RUN",
                    hasDot: true
                )
                StatusChip(title: "SYNC: \(viewModel.syncStatusText)")
                Spacer(minLength: 0)
            }
        }
    }

    private var primaryRunSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Runs")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(HomeTheme.textPrimary)
                Spacer()
                Button("Open Runs") {
                    onOpenRuns()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HomeTheme.primary)
            }

            if viewModel.activeRunCount > 0 {
                HomeCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active Run")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(HomeTheme.primary)
                        Text("School Pick-up is in progress")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(HomeTheme.textPrimary)
                        Text("Live updates are available in Runs.")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(HomeTheme.textSecondary)
                    }
                }
            } else {
                HomeCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Next Scheduled Run")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(HomeTheme.primary)
                        Text(viewModel.upcomingEvent?.title ?? "No run scheduled")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(HomeTheme.textPrimary)
                        Text(viewModel.upcomingEvent?.timeRange ?? "Set up your next run")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(HomeTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var todaysRunsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Runs")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(HomeTheme.textPrimary)

            ForEach(viewModel.todaysRuns) { run in
                TodayRunCard(run: run)
            }
        }
    }

    private var createRunButton: some View {
        Button {
            onCreateRun()
        } label: {
            Text("Create Run")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(HomeTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: HomeTheme.primary.opacity(0.18), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Events")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(HomeTheme.textPrimary)
                Spacer()
                Button("See Calendar") {
                    onOpenCalendar()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HomeTheme.primary)
            }
            HomeHeroCard(event: viewModel.upcomingEvent, isSecondary: true)
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    HomeView()
}
