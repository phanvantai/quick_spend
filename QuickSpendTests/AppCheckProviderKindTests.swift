import Testing
@testable import QuickSpend

@Suite("AppCheckProviderKind Tests")
struct AppCheckProviderKindTests {

    @Test("Debug builds use the debug provider even on App Attest devices")
    func testDebugBuildUsesDebugProvider() {
        let kind = AppCheckProviderKind.resolve(isDebugBuild: true, isSimulator: false, isAppAttestSupported: true)
        #expect(kind == .debug)
    }

    @Test("Simulator uses the debug provider in release builds")
    func testSimulatorUsesDebugProvider() {
        let kind = AppCheckProviderKind.resolve(isDebugBuild: false, isSimulator: true, isAppAttestSupported: false)
        #expect(kind == .debug)
    }

    @Test("Release build on a supported device uses App Attest")
    func testReleaseDeviceUsesAppAttest() {
        let kind = AppCheckProviderKind.resolve(isDebugBuild: false, isSimulator: false, isAppAttestSupported: true)
        #expect(kind == .appAttest)
    }

    @Test("Release build without App Attest support falls back to DeviceCheck")
    func testReleaseDeviceFallsBackToDeviceCheck() {
        let kind = AppCheckProviderKind.resolve(isDebugBuild: false, isSimulator: false, isAppAttestSupported: false)
        #expect(kind == .deviceCheck)
    }
}
