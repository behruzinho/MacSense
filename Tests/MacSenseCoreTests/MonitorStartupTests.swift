import XCTest
@testable import MacSenseCore

final class MonitorStartupTests: XCTestCase {
    func testPanelOrderVisibilityAndForwardCompatibility() {
        var config = MonitorConfiguration(encoded: #"["gpu","unknown-future-panel","cpu","gpu"]"#)
        XCTAssertEqual(config.panels, [.gpu, .cpu])
        config.move(.cpu, offset: -1)
        XCTAssertEqual(config.panels, [.cpu, .gpu])
        config.move(.cpu, offset: -1)
        XCTAssertEqual(config.panels, [.cpu, .gpu])
        config.set(.gpu, enabled: false)
        config.set(.network, enabled: true)
        XCTAssertEqual(MonitorConfiguration(encoded: config.encoded), config)
        XCTAssertEqual(MonitorConfiguration(encoded: "[]").panels, [])
        XCTAssertEqual(MonitorConfiguration(encoded: "invalid").panels, MonitorPanel.allCases)
    }
    func testLaunchctlModernAndLegacyOutput() {
        let output = #"""
        disabled services = {
            "com.example.off" => disabled
            "com.example.on" => enabled
            "com.example.legacyOff" => true
            "com.example.legacyOn" => false
        }
        """#
        let values = StartupParser.disabledOverrides(output)
        XCTAssertEqual(values["com.example.off"], true)
        XCTAssertEqual(values["com.example.on"], false)
        XCTAssertEqual(values["com.example.legacyOff"], true)
        XCTAssertEqual(values["com.example.legacyOn"], false)
        XCTAssertNil(values["missing"])
        XCTAssertEqual(StartupParser.loadedLabels("PID\tStatus\tLabel\n123\t0\tcom.example.running\n-\t0\tcom.example.idle\n"), ["com.example.running", "com.example.idle"])
    }
    func testOnlyExactUserLaunchAgentCanBeManaged() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        func entry(_ path: String, label: String = "com.example.agent") -> StartupEntry {
            StartupEntry(url: URL(fileURLWithPath: path), label: label, program: "/bin/true", group: "", runAtLoad: false)
        }
        XCTAssertTrue(StartupParser.canManage(entry(home.appendingPathComponent("Library/LaunchAgents/com.example.agent.plist").path), home: home))
        XCTAssertFalse(StartupParser.canManage(entry("/Library/LaunchDaemons/com.example.agent.plist"), home: home))
        XCTAssertFalse(StartupParser.canManage(entry(home.appendingPathComponent("Library/LaunchAgents/com.apple.service.plist").path, label: "com.apple.service"), home: home))
        for label in ["../test", "com.example/agent", "--help", "com.example;echo"] { XCTAssertFalse(StartupParser.validLabel(label)) }
    }
}
