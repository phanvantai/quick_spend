import Foundation

enum SplashLaunchPolicy {
    static let minimumDisplayDuration = Duration.milliseconds(300)
    static let cloudRestoreWaitLimit = Duration.seconds(3)

    static func shouldWaitForCloudImport(isOnboardingComplete: Bool) -> Bool {
        !isOnboardingComplete
    }
}
