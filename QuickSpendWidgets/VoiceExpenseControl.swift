import AppIntents
import SwiftUI
import WidgetKit

/// Control Center / Lock Screen / Action button control that opens QuickSpend
/// and starts voice recording.
struct VoiceExpenseControl: ControlWidget {
    static let kind = "com.randomtech.quickSpend.VoiceExpenseControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartVoiceExpenseIntent()) {
                Label("widget.voice.title", systemImage: "mic.fill")
            }
        }
        .displayName("widget.voice.name")
        .description("widget.voice.description")
    }
}
