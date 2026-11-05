import XCTest
@testable import MacSenseCore

final class StorageTests: XCTestCase {
    func testAPFSHierarchyLinksVolumesToPhysicalStoreWithoutSummingSharedCapacity() throws {
        let list: [String: Any] = ["AllDisksAndPartitions": [["DeviceIdentifier": "disk2", "Size": 1000, "Partitions": [["DeviceIdentifier": "disk2s2", "Content": "Apple_APFS", "Size": 900]]]]]
        let apfs: [String: Any] = ["Containers": [["ContainerReference": "disk3", "CapacityCeiling": 900, "CapacityFree": 300, "PhysicalStores": [["DeviceIdentifier": "disk2s2"]], "Volumes": [["DeviceIdentifier": "disk3s1", "Name": "Test volume", "CapacityInUse": 200]]]]]
        let disks = StorageParser.devices(list: list, apfs: apfs, information: ["disk2": ["MediaName": "Test SSD", "Internal": true]])
        let disk = try XCTUnwrap(disks.first)
        XCTAssertEqual(disk.bytes, 1000)
        XCTAssertEqual(disk.contents.first?.children.first?.free, 300)
        XCTAssertEqual(disk.contents.first?.children.first?.children.first?.bytes, 200)
        XCTAssertEqual(disk.contents.first?.children.first?.children.first?.id, "disk3s1")
    }
    func testNVMeUnitsAndUnknownHealth() throws {
        let health = try XCTUnwrap(StorageParser.health(json: ["nvme_smart_health_information_log": ["percentage_used": 7, "data_units_written": 2, "critical_warning": 0]]))
        XCTAssertEqual(health.estimatedRemaining, 93)
        XCTAssertEqual(health.attributes.first { $0.id == "data_units_written" }?.value, 1_024_000)
        XCTAssertNil(health.temperature)
        XCTAssertNil(health.passed)
        XCTAssertNil(StorageParser.health(json: ["error": "permission denied"]))
        XCTAssertNil(StorageParser.health(json: ["nvme_smart_health_information_log": [:]]))
    }
    func testDeviceIdentifierAndDateValidation() {
        XCTAssertTrue(StorageParser.validDiskID("disk12s2s1"))
        for invalid in ["../disk0", "disk0;echo", "-disk0", "disk", "/dev/disk0"] { XCTAssertFalse(StorageParser.validDiskID(invalid)) }
        XCTAssertNil(BatteryDetails.decodeDate(0))
        XCTAssertNil(BatteryDetails.decodeDate(((2024 - 1980) << 9) | (2 << 5) | 31))
        XCTAssertNotNil(BatteryDetails.decodeDate(((2024 - 1980) << 9) | (2 << 5) | 29))
    }
    func testBenchmarkOnlyCreatesAndRemovesItsScratchFile() async throws {
        let fm = FileManager.default, root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let original = root.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: original)
        let result = try await DiskBenchmark().run(at: root, megabytes: 4)
        XCTAssertEqual(result.bytes, 4 * 1024 * 1024)
        XCTAssertGreaterThan(result.readBytesPerSecond, 0)
        XCTAssertGreaterThan(result.writeBytesPerSecond, 0)
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: root.path), ["keep.txt"])
        XCTAssertEqual(try String(contentsOf: original), "keep")
    }
    func testCancellationCleansScratchFile() async throws {
        let fm = FileManager.default, root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let task = Task {
            try await DiskBenchmark().run(at: root, megabytes: 64) { _ in
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch is CancellationError {} catch { throw error }
        XCTAssertTrue(try fm.contentsOfDirectory(atPath: root.path).isEmpty)
    }
}
