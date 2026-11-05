import XCTest
@testable import MacSenseCore
import TelemetryBridge

final class TelemetryTests: XCTestCase {
    func testCPUUsesIntervalInsteadOfLifetimeAverage() throws {
        let first = [UInt64(100), 50, 850, 0]
        let next = [UInt64(125), 60, 915, 0]
        let result = try XCTUnwrap(MetricMath.cpuDelta(previous: first, current: next))
        XCTAssertEqual(result.usage, 35, accuracy: 0.001)
        XCTAssertEqual(result.system, 10, accuracy: 0.001)
        XCTAssertEqual(result.user, 25, accuracy: 0.001)
    }
    func testCPUCounterWrapDoesNotCreateHugeSpike() throws {
        let result = try XCTUnwrap(MetricMath.cpuDelta(previous: [UInt64(UInt32.max) - 4, 100, 100, 0], current: [5, 110, 180, 0]))
        XCTAssertEqual(result.usage, 20, accuracy: 0.001)
    }
    func testCPURequiresTwoUsableSamples() {
        XCTAssertNil(MetricMath.cpuDelta(previous: [], current: [0, 0, 0, 0]))
        XCTAssertNil(MetricMath.cpuDelta(previous: [2, 3, 4, 0], current: [2, 3, 4, 0]))
    }
    func testNetworkRateIgnoresResetAndSleep() {
        XCTAssertEqual(MetricMath.rate(previous: 1000, current: 3000, seconds: 2), 1000)
        XCTAssertNil(MetricMath.rate(previous: 3000, current: 1000, seconds: 2))
        XCTAssertNil(MetricMath.rate(previous: 1000, current: 3000, seconds: 80))
        XCTAssertNil(MetricMath.rate(previous: 1000, current: 3000, seconds: 0))
    }
    func testIntelAndAppleSiliconSensorDecoders() {
        var positive: [UInt8] = [42, 128]
        XCTAssertEqual(ms_decode_smc("sp78", &positive, 2), 42.5)
        var negative: [UInt8] = [246, 0]
        XCTAssertEqual(ms_decode_smc("sp78", &negative, 2), -10)
        var fan: [UInt8] = [0x1f, 0x40]
        XCTAssertEqual(ms_decode_smc("fpe2", &fan, 2), 2000)
        var float = Float(65.25)
        let decoded = withUnsafeBytes(of: &float) { ms_decode_smc("flt ", $0.bindMemory(to: UInt8.self).baseAddress!, 4) }
        XCTAssertEqual(decoded, 65.25)
        XCTAssertTrue(ms_decode_smc("sp78", &positive, 1).isNaN)
        XCTAssertTrue(ms_decode_smc("xxxx", &positive, 2).isNaN)
    }
    func testBundleIdentifierCannotEscapeLibrary() {
        XCTAssertTrue(UtilityPolicy.safeBundleIdentifier("com.example.App"))
        for unsafe in ["../Documents", "com.example/../../Documents", "com\\example.App", "..", ""] {
            XCTAssertFalse(UtilityPolicy.safeBundleIdentifier(unsafe))
        }
    }
    func testTrashPolicyRejectsPersonalFilesAndWholeLibrary() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        func item(_ path: String, category: String = "Кэш") -> FileCandidate {
            FileCandidate(url: home.appendingPathComponent(path), title: "Test", category: category, bytes: 0, complete: true)
        }
        XCTAssertFalse(UtilityPolicy.isAllowed(item("Documents/report.txt"), home: home))
        XCTAssertFalse(UtilityPolicy.isAllowed(item("Library"), home: home))
        XCTAssertFalse(UtilityPolicy.isAllowed(item("Library/Caches"), home: home))
        XCTAssertTrue(UtilityPolicy.isAllowed(item("Library/Caches/com.example.MacSensePolicyTest"), home: home))
        XCTAssertTrue(UtilityPolicy.isAllowed(item("Library/Preferences/com.example.MacSensePolicyTest.plist", category: "Настройки"), home: home))
    }
}
