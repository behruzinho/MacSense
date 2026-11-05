import Foundation

public actor StorageService {
    public init() {}
    public func inventory() -> [StorageDevice] {
        guard let list = plist(["list", "-plist", "physical"]) else { return [] }
        let apfs = plist(["apfs", "list", "-plist"]) ?? [:]
        var info: [String: [String: Any]] = [:]
        for disk in list["AllDisksAndPartitions"] as? [[String: Any]] ?? [] {
            guard let id = disk["DeviceIdentifier"] as? String, StorageParser.validDiskID(id) else { continue }
            info[id] = plist(["info", "-plist", id])
        }
        return StorageParser.devices(list: list, apfs: apfs, information: info)
    }
    public func health(disk: String) -> NVMeHealth? {
        guard StorageParser.validDiskID(disk), let executable = Self.smartctlPath,
              let data = SystemCommand.data(executable, ["-j", "-a", "/dev/" + disk], timeout: 15, acceptNonzero: true),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return StorageParser.health(json: json)
    }
    public nonisolated static var smartctlPath: String? {
        ["/opt/homebrew/bin/smartctl", "/usr/local/bin/smartctl"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    private func plist(_ arguments: [String]) -> [String: Any]? {
        guard let data = SystemCommand.data("/usr/sbin/diskutil", arguments, timeout: 15) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }
}
