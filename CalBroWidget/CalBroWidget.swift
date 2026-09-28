import WidgetKit
import SwiftUI

// MARK: - Timeline

struct NutritionEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetNutritionSnapshot
}

struct NutritionProvider: TimelineProvider {
    func placeholder(in context: Context) -> NutritionEntry {
        NutritionEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (NutritionEntry) -> Void) {
        let snap = context.isPreview ? .placeholder : SharedNutritionStore.load()
        completion(NutritionEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NutritionEntry>) -> Void) {
        let now = Date()
        let today = SharedNutritionStore.load(for: now)
        var entries = [NutritionEntry(date: now, snapshot: today)]
        // Roll over to an empty day at midnight even if the app isn't opened.
        if let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0),
                                                    matchingPolicy: .nextTime) {
            entries.append(NutritionEntry(date: midnight, snapshot: today.startingDay(midnight)))
        }
        // The app reloads timelines on every meal change; this is only a fallback.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(next)))
    }
}

// MARK: - Views

struct CalBroWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NutritionEntry

    var body: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular:
            NutritionWidgetFace(family: family, snapshot: entry.snapshot)
                .containerBackground(.clear, for: .widget)
        default:
            NutritionWidgetFace(family: family, snapshot: entry.snapshot)
                .containerBackground(WidgetPalette.card, for: .widget)
        }
    }
}

// MARK: - Widget declaration

struct CalBroWidget: Widget {
    let kind = "CalBroWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutritionProvider()) { entry in
            CalBroWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("CalBro")
        .description("Today's calories and macros at a glance.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular
        ])
    }
}

@main
struct CalBroWidgetBundle: WidgetBundle {
    var body: some Widget {
        CalBroWidget()
    }
}
