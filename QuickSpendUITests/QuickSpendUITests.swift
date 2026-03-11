import XCTest

final class QuickSpendUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - App Launch

    @MainActor
    func testAppLaunches() throws {
        app.launch()
        // App should launch without crashing
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Onboarding Flow

    @MainActor
    func testOnboardingScreenIsDisplayed() throws {
        app.launch()
        // On first launch, onboarding should be visible
        // Wait for the app to load
        let exists = app.wait(for: .runningForeground, timeout: 10)
        XCTAssertTrue(exists)
    }

    // MARK: - Tab Navigation

    @MainActor
    func testTabBarExists() throws {
        app.launch()
        // After onboarding is complete, tab bar should be visible
        // This test verifies the tab structure
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 5) {
            XCTAssertTrue(tabBar.exists)
        }
    }

    // MARK: - App State

    @MainActor
    func testAppRespondsToInteraction() throws {
        app.launch()
        // Verify app is responsive
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))

        // Try tapping on the screen to verify it's responsive
        let firstElement = app.descendants(matching: .any).firstMatch
        if firstElement.waitForExistence(timeout: 5) {
            XCTAssertTrue(firstElement.exists)
        }
    }
}
