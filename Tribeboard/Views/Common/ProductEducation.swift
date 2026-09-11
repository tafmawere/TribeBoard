import SwiftUI

enum ProductEducationTopic: String, Equatable {
    case scheduleVsRun
    case childFirstSetup
    case schoolAndActivities
    case calendarMeaning
}

struct ProductEducationItem: Identifiable, Equatable {
    let id: UUID
    let topic: ProductEducationTopic
    let title: String
    let message: String
}

enum ProductEducationProvider {
    static func item(for topic: ProductEducationTopic) -> ProductEducationItem {
        switch topic {
        case .scheduleVsRun:
            return ProductEducationItem(
                id: UUID(),
                topic: .scheduleVsRun,
                title: "Schedules and Runs",
                message: "A schedule is a repeating plan. A run is the actual trip for a specific day."
            )
        case .childFirstSetup:
            return ProductEducationItem(
                id: UUID(),
                topic: .childFirstSetup,
                title: "Start with your children",
                message: "Add your children first, then schools and activities. Tribeboard builds logistics around their routine."
            )
        case .schoolAndActivities:
            return ProductEducationItem(
                id: UUID(),
                topic: .schoolAndActivities,
                title: "Why school and activities matter",
                message: "School and activity details help Tribeboard understand where your child needs to be."
            )
        case .calendarMeaning:
            return ProductEducationItem(
                id: UUID(),
                topic: .calendarMeaning,
                title: "How Calendar works",
                message: "Calendar brings together school, activities, schedules, and runs for each day."
            )
        }
    }
}

struct ProductEducationCard: View {
    let item: ProductEducationItem
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.yellow)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(item.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.25), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
