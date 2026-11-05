import Foundation
import IOKit
import Metal

public struct BatteryDetails: Sendable {
    public var manufacturer: String?
    public var serial: String?
    public var model: String?
    public var manufactureDate: Date?
    public var designCycles: Int?
    public var cellCount: Int?
    public init() {}
    public static func decodeDate(_ raw: Int) -> Date? {
        let day = raw & 31, month = (raw >> 5) & 15, year = 1980 + (raw >> 9)
        guard (1...31).contains(day), (1...12).contains(month), (1980...2100).contains(year) else { return nil }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components), calendar.dateComponents([.year, .month, .day], from: date) == components else { return nil }
        return date
    }
}
public struct GPUDeviceInfo: Identifiable, Sendable {
    public let id: UInt64
    public let name: String
    public let unified: Bool
    public let removable: Bool
    public let lowPower: Bool
    public let workingSetBudget: Double
    public let families: [String]
}
public enum HardwareDetails {
    public static func battery() -> BatteryDetails {
        var result = BatteryDetails()
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return result }; defer { IOObjectRelease(service) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dictionary = properties?.takeRetainedValue() as? [String: Any] else { return result }
        result.manufacturer = dictionary["Manufacturer"] as? String
        result.serial = dictionary["Serial"] as? String ?? dictionary["BatterySerialNumber"] as? String
        result.model = dictionary["DeviceName"] as? String
        result.designCycles = (dictionary["DesignCycleCount9C"] as? NSNumber)?.intValue
        result.cellCount = (dictionary["CellCount"] as? NSNumber)?.intValue
        if let raw = (dictionary["ManufactureDate"] as? NSNumber)?.intValue { result.manufactureDate = BatteryDetails.decodeDate(raw) }
        return result
    }
    public static func graphics() -> [GPUDeviceInfo] {
        MTLCopyAllDevices().map { device in
            let candidates: [(MTLGPUFamily, String)] = [(.apple1, "Apple 1"), (.apple2, "Apple 2"), (.apple3, "Apple 3"), (.apple4, "Apple 4"), (.apple5, "Apple 5"), (.apple6, "Apple 6"), (.apple7, "Apple 7"), (.apple8, "Apple 8"), (.apple9, "Apple 9"), (.mac2, "Mac 2"), (.common3, "Common 3")]
            return GPUDeviceInfo(id: device.registryID, name: device.name, unified: device.hasUnifiedMemory, removable: device.isRemovable, lowPower: device.isLowPower, workingSetBudget: Double(device.recommendedMaxWorkingSetSize), families: candidates.filter { device.supportsFamily($0.0) }.map(\.1))
        }
    }
}
