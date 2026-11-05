import Foundation

public struct CPUReading: Sendable {
    public var usage: Double?
    public var system: Double = 0
    public var user: Double = 0
    public var cores: [Double] = []
    public init() {}
}
public struct MemoryReading: Sendable {
    public var total: Double = 0
    public var used: Double = 0
    public var app: Double = 0
    public var wired: Double = 0
    public var compressed: Double = 0
    public var cached: Double = 0
    public var swapUsed: Double = 0
    public var swapTotal: Double = 0
    public var pressure: Int = -1
    public var percentage: Double { total > 0 ? used / total * 100 : 0 }
    public var pressureLabel: String { pressure < 0 ? L("Недоступна") : pressure <= 1 ? L("Нормальная") : pressure == 2 ? L("Повышенная") : L("Высокая") }
    public var pressureNormal: Bool { pressure >= 0 && pressure <= 1 }
    public init() {}
}
public struct BatteryReading: Sendable {
    public var present = false
    public var charging = false
    public var external = false
    public var percentage: Double = 0
    public var health: Double?
    public var temperature: Double?
    public var voltage: Double?
    public var amperage: Double?
    public var cycles = 0
    public var currentCapacity = 0
    public var maxCapacity = 0
    public var designCapacity = 0
    public var minutes: Int?
    public var status: String { charging ? L("Заряжается") : external ? L("Питание от сети") : L("Работа от батареи") }
    public init() {}
}
public struct TemperatureReading: Identifiable, Sendable {
    public let key: String
    public let value: Double
    public var id: String { key }
    public var group: String {
        if key.hasPrefix("TC") || key.hasPrefix("Tp") || key.hasPrefix("Te") { return "Процессор" }
        if key.hasPrefix("TG") || key.hasPrefix("Tg") { return "Графика" }
        if key.hasPrefix("TB") || key.hasPrefix("Tb") { return "Батарея" }
        if key.hasPrefix("TM") || key.hasPrefix("Tm") { return "Память" }
        if key.hasPrefix("TH") || key.hasPrefix("TN") { return "Накопитель" }
        if key.hasPrefix("TW") { return "Wi-Fi" }
        if key.hasPrefix("TL") { return "Плата" }
        if key.hasPrefix("TP") { return "Питание" }
        if key.hasPrefix("Ts") { return "Корпус" }
        return "Система"
    }
    public var name: String {
        let names = ["TC0P": "CPU · рядом с чипом", "TC0D": "CPU · кристалл", "TC0E": "CPU · PECI", "TC0F": "CPU · PECI", "TC0H": "CPU · теплоотвод", "TG0P": "GPU · рядом с чипом", "TG0D": "GPU · кристалл", "TB0T": "Батарея", "TB1T": "Батарея · ячейка 1", "TB2T": "Батарея · ячейка 2", "TM0P": "Оперативная память", "TH0P": "Накопитель", "Ts0P": "Область ладоней", "TA0P": "Окружающий воздух"]
        return names[key].map { L10n.translate($0) } ?? L("Датчик \(key)")
    }
    public init(key: String, value: Double) { self.key = key; self.value = value }
}
public struct FanReading: Identifiable, Sendable {
    public let id: Int
    public let current: Double
    public let minimum: Double?
    public let maximum: Double?
    public var name: String { L("Вентилятор \(id + 1)") }
    public init(id: Int, current: Double, minimum: Double?, maximum: Double?) {
        self.id = id; self.current = current; self.minimum = minimum; self.maximum = maximum
    }
}
public struct NetworkReading: Sendable {
    public var received: Double = 0
    public var sent: Double = 0
    public var download: Double?
    public var upload: Double?
    public init() {}
}
public struct ProcessReading: Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let cpu: Double
    public let memory: Double
}
public struct DiskReading: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let total: Double
    public let free: Double
    public let filesystem: String
    public var used: Double { max(0, total - free) }
    public var percentage: Double { total > 0 ? used / total * 100 : 0 }
}
public struct HardwareInfo: Sendable {
    public var computerName: String?
    public var serial: String?
    public var batteryDetails = BatteryDetails()
    public var gpuDevices: [GPUDeviceInfo] = []
    public var model = "Mac"
    public var modelName = "Ваш Mac"
    public var chip = "Процессор Mac"
    public var coreCount = ProcessInfo.processInfo.processorCount
    public var performanceCores: Int = 0
    public var efficiencyCores: Int = 0
    public var memory: Double = Double(ProcessInfo.processInfo.physicalMemory)
    public var graphics = "Графический процессор"
    public var gpuCores: String?
    public var os = ProcessInfo.processInfo.operatingSystemVersionString
    public var architecture = ""
    public var diskModel: String?
    public var smart: String?
    public var trim: Bool?
    public init() {}
}
public struct SystemSnapshot: Sendable {
    public var date = Date()
    public var cpu = CPUReading()
    public var memory = MemoryReading()
    public var battery = BatteryReading()
    public var network = NetworkReading()
    public var gpu: Double?
    public var temperatures: [TemperatureReading] = []
    public var fans: [FanReading] = []
    public var processes: [ProcessReading] = []
    public var disks: [DiskReading] = []
    public var diskIO: [DiskIOReading] = []
    public var thermalState = 0
    public var uptime: TimeInterval = 0
    public var cpuTemperature: Double? {
        let items = temperatures.filter { $0.group == "Процессор" }
        return items.isEmpty ? nil : items.map(\.value).reduce(0, +) / Double(items.count)
    }
    public init() {}
}
public enum MetricMath {
    public static func rate(previous: Double, current: Double, seconds: Double) -> Double? {
        guard seconds > 0, seconds < 30, current >= previous else { return nil }
        return (current - previous) / seconds
    }
    public static func cpuDelta(previous: [UInt64], current: [UInt64]) -> (usage: Double, system: Double, user: Double)? {
        guard previous.count == 4, current.count == 4 else { return nil }
        // host_processor_info exposes wrapping 32-bit counters.
        let delta = zip(current, previous).map { Double(UInt32(truncatingIfNeeded: $0) &- UInt32(truncatingIfNeeded: $1)) }
        let total = delta.reduce(0, +)
        guard total > 0 else { return nil }
        return ((total - delta[2]) / total * 100, delta[1] / total * 100, (delta[0] + delta[3]) / total * 100)
    }
}
