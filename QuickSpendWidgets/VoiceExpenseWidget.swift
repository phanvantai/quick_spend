import SwiftUI
import WidgetKit

/// Home Screen and Lock Screen widget: one tap opens QuickSpend and starts
/// voice recording. It shows no data, so it needs no timeline updates.
struct VoiceExpenseWidget: Widget {
    static let kind = "VoiceExpenseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: Provider()) { _ in
            VoiceExpenseWidgetView()
                .containerBackground(for: .widget) { WidgetPalette.background }
                .widgetURL(QuickLaunchAction.voiceExpense.url)
        }
        .configurationDisplayName(Text("widget.voice.name"))
        .description(Text("widget.voice.description"))
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }

    struct Entry: TimelineEntry {
        let date: Date
    }

    struct Provider: TimelineProvider {
        func placeholder(in context: Context) -> Entry { Entry(date: .now) }

        func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
            completion(Entry(date: .now))
        }

        func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
            completion(Timeline(entries: [Entry(date: .now)], policy: .never))
        }
    }
}

enum WidgetPalette {
    /// QuickSpend's forest green (AppTheme.primaryGreen).
    static let background = Color(red: 0x2D / 255, green: 0x6A / 255, blue: 0x4F / 255)
}

struct VoiceExpenseWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
                    .font(.title2.weight(.semibold))
            }
            .widgetAccentable()
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "mic.circle.fill")
                    .font(.title)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 2) {
                    Text("widget.voice.title")
                        .font(.headline)
                    Text("widget.voice.subtitle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 44))
                    .symbolRenderingMode(.hierarchical)
                Spacer(minLength: 0)
                Text("widget.voice.title")
                    .font(.headline)
                Text("widget.voice.subtitle")
                    .font(.caption)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

#Preview(as: .systemSmall) {
    VoiceExpenseWidget()
} timeline: {
    VoiceExpenseWidget.Entry(date: .now)
}
