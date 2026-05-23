import Testing
import Foundation
@testable import QuickSpend

/// Covers persistence of the Home FocalChartCard's currently selected chart.
/// The toggle state survives app relaunch via AppConfig.focalChartPreference,
/// so a fresh AppConfigViewModel built from the same UserDefaults must see the
/// last picked value. Unknown / missing values fall back to `.donut` so a
/// future build can rename the enum case without breaking older clients.
@Suite("Focal Chart State Tests")
struct FocalChartStateTests {

    /// Create an isolated ViewModel + the underlying defaults so a follow-up
    /// ViewModel can be built on the same suite to verify persistence.
    private func makeIsolatedPair() -> (UserDefaults, AppConfigViewModel) {
        let suiteName = "test.focalchart.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let preferences = PreferencesService(defaults: defaults)
        return (defaults, AppConfigViewModel(preferences: preferences))
    }

    @Test("Default preference is donut")
    func testDefaultIsDonut() {
        let (_, vm) = makeIsolatedPair()
        #expect(vm.focalChartPreference == .donut)
    }

    @Test("setFocalChartPreference flips the in-memory accessor")
    func testSetFlipsAccessor() {
        let (_, vm) = makeIsolatedPair()
        vm.setFocalChartPreference(.bar)
        #expect(vm.focalChartPreference == .bar)
    }

    @Test("setFocalChartPreference persists across ViewModel reinit on the same defaults")
    func testPersistsAcrossReinit() {
        let (defaults, vm) = makeIsolatedPair()
        vm.setFocalChartPreference(.bar)

        // Build a fresh ViewModel from the same UserDefaults — simulates app relaunch.
        let preferences = PreferencesService(defaults: defaults)
        let reloaded = AppConfigViewModel(preferences: preferences)

        #expect(reloaded.focalChartPreference == .bar)
    }

    @Test("Unknown stored raw value decodes to donut")
    func testUnknownStoredValueFallsBackToDonut() {
        // Simulate a future build writing an enum case this build doesn't know.
        let (defaults, vm) = makeIsolatedPair()
        var config = vm.config
        config.focalChartPreference = "line"
        // Bypass setFocalChartPreference (which is type-safe) by encoding raw config.
        let data = try! JSONEncoder().encode(config)
        defaults.set(data, forKey: "app_config")

        let preferences = PreferencesService(defaults: defaults)
        let reloaded = AppConfigViewModel(preferences: preferences)

        #expect(reloaded.focalChartPreference == .donut)
    }
}
