import Foundation
import SwiftUI

enum SplashLaunchPolicy {
    static let minimumDisplayDuration = Duration.milliseconds(300)
    static let cloudRestoreWaitLimit = Duration.seconds(3)

    static func shouldWaitForCloudImport(isOnboardingComplete: Bool) -> Bool {
        !isOnboardingComplete
    }

    /// Launch work generates recurring items once; this catches the app coming
    /// back to the foreground later (e.g. after midnight) without a cold launch.
    static func shouldGenerateRecurring(
        on phase: ScenePhase,
        isLaunchComplete: Bool,
        isOnboardingComplete: Bool
    ) -> Bool {
        phase == .active && isLaunchComplete && isOnboardingComplete
    }
}
