import Foundation

public struct DiskIOReading: Identifiable, Sendable {
    public let id: String
    public let read: Double
    public let written: Double
    public let readRate: Double?
    public let writeRate: Double?
}
public struct StorageNode: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let kind: String
    public let bytes: Double
    public let free: Double?
    public let children: [StorageNode]
    public var outlineChildren: [StorageNode]? { children.isEmpty ? nil : children }
}
public struct StorageDevice: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let bytes: Double
    public let bus: String?
    public let internalDevice: Bool?
    public let solidState: Bool?
    public let removable: Bool?
    public let writable: Bool?
    public let blockSize: Int?
    public let smart: String?
    public let contents: [StorageNode]
}
public struct SMARTAttribute: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let value: Double
    public let unit: String
}
public struct NVMeHealth: Sendable {
    public let percentageUsed: Double?
    public let temperature: Double?
    public let passed: Bool?
    public let attributes: [SMARTAttribute]
    public var estimatedRemaining: Double? { percentageUsed.map { max(0, 100 - $0) } }
}
public enum StorageParser {
    public static func validDiskID(_ value: String) -> Bool {
        value.range(of: #"^disk[0-9]+(s[0-9]+)*$"#, options: .regularExpression) != nil
    }
    public static func devices(list: [String: Any], apfs: [String: Any], information: [String: [String: Any]]) -> [StorageDevice] {
        let containers = apfs["Containers"] as? [[String: Any]] ?? []
        return (list["AllDisksAndPartitions"] as? [[String: Any]] ?? []).compactMap { disk in
            guard let id = disk["DeviceIdentifier"] as? String, validDiskID(id) else { return nil }
            let info = information[id] ?? [:]
            let partitions = (disk["Partitions"] as? [[String: Any]] ?? []).compactMap { part -> StorageNode? in
                guard let pid = part["DeviceIdentifier"] as? String else { return nil }
                let related = containers.filter { container in
                    (container["PhysicalStores"] as? [[String: Any]] ?? []).contains { $0["DeviceIdentifier"] as? String == pid }
                }
                let nodes = related.compactMap { container -> StorageNode? in
                    guard let cid = container["ContainerReference"] as? String else { return nil }
                    let volumes = (container["Volumes"] as? [[String: Any]] ?? []).compactMap { volume -> StorageNode? in
                        guard let vid = volume["DeviceIdentifier"] as? String else { return nil }
                        return StorageNode(id: vid, name: volume["Name"] as? String ?? vid, kind: "Том APFS", bytes: number(volume["CapacityInUse"]) ?? 0, free: nil, children: [])
                    }
                    return StorageNode(id: cid, name: cid, kind: "Контейнер APFS", bytes: number(container["CapacityCeiling"]) ?? 0, free: number(container["CapacityFree"]), children: volumes)
                }
                return StorageNode(id: pid, name: part["VolumeName"] as? String ?? pid, kind: part["Content"] as? String ?? "Partition", bytes: number(part["Size"]) ?? 0, free: nil, children: nodes)
            }
            return StorageDevice(id: id, name: info["MediaName"] as? String ?? id, bytes: number(info["TotalSize"]) ?? number(disk["Size"]) ?? 0,
                bus: info["BusProtocol"] as? String, internalDevice: info["Internal"] as? Bool, solidState: info["SolidState"] as? Bool,
                removable: info["Removable"] as? Bool, writable: info["Writable"] as? Bool, blockSize: (info["DeviceBlockSize"] as? NSNumber)?.intValue,
                smart: info["SMARTStatus"] as? String, contents: partitions)
        }
    }
    public static func health(json: [String: Any]) -> NVMeHealth? {
        guard let log = json["nvme_smart_health_information_log"] as? [String: Any], !log.isEmpty else { return nil }
        let descriptions: [(String, String, String, Double)] = [
            ("critical_warning", "Критическое предупреждение", "", 1), ("temperature", "Температура", "°C", 1),
            ("available_spare", "Доступный резерв", "%", 1), ("percentage_used", "Израсходованный ресурс", "%", 1),
            ("data_units_read", "Прочитано за срок службы", "bytes", 512_000), ("data_units_written", "Записано за срок службы", "bytes", 512_000),
            ("host_reads", "Команды чтения", "", 1), ("host_writes", "Команды записи", "", 1),
            ("controller_busy_time", "Время занятости контроллера", "min", 1), ("power_cycles", "Включения", "", 1),
            ("power_on_hours", "Часы работы", "h", 1), ("unsafe_shutdowns", "Небезопасные отключения", "", 1),
            ("media_errors", "Ошибки целостности данных", "", 1), ("num_err_log_entries", "Записи журнала ошибок", "", 1)
        ]
        let attributes = descriptions.compactMap { key, title, unit, multiplier -> SMARTAttribute? in
            guard let value = number(log[key]), value >= 0 else { return nil }
            return SMARTAttribute(id: key, title: title, value: value * multiplier, unit: unit)
        }
        return NVMeHealth(percentageUsed: number(log["percentage_used"]), temperature: number(log["temperature"]), passed: (json["smart_status"] as? [String: Any])?["passed"] as? Bool, attributes: attributes)
    }
    private static func number(_ value: Any?) -> Double? {
        let result = (value as? NSNumber)?.doubleValue ?? (value as? String).flatMap(Double.init)
        return result.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
    }
}
