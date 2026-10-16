import SwiftUI
import WidgetKit

@main
struct QuickSpendWidgetsBundle: WidgetBundle {
    var body: some Widget {
        VoiceExpenseWidget()
        VoiceExpenseControl()
    }
}
