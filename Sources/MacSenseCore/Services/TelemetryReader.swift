import Foundation
import TelemetryBridge

public actor TelemetryReader {
    private var previousTicks: [[UInt64]] = []
    private var previousNetwork: (received: Double, sent: Double, time: Double)?
    private var processes: [ProcessReading] = []
    private var disks: [DiskReading] = []
    private var tick = 0
    public init() {}

    public func hardware() -> HardwareInfo {
        var h = HardwareInfo()
        h.model = sysString("hw.model") ?? "Mac"
        h.chip = sysString("machdep.cpu.brand_string") ?? "Apple Silicon"
        h.coreCount = max(1, Int(ms_sysctl_uint("hw.logicalcpu")))
        h.performanceCores = Int(ms_sysctl_uint("hw.perflevel0.physicalcpu"))
        h.efficiencyCores = Int(ms_sysctl_uint("hw.perflevel1.physicalcpu"))
        #if arch(arm64)
        h.architecture = "Apple Silicon · arm64"
        #else
        h.architecture = "Intel · x86_64"
        #endif
        if let data = SystemCommand.data("/usr/sbin/system_profiler", ["SPHardwareDataType", "SPDisplaysDataType", "SPNVMeDataType", "-json"], timeout: 20),
           let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            if let item = (root["SPHardwareDataType"] as? [[String: Any]])?.first {
                h.modelName = item["machine_name"] as? String ?? h.model
                h.chip = item["chip_type"] as? String ?? h.chip
            }
            if let gpu = (root["SPDisplaysDataType"] as? [[String: Any]])?.first {
                h.graphics = gpu["sppci_model"] as? String ?? h.chip
                h.gpuCores = gpu["sppci_cores"] as? String
            }
            if let controllers = root["SPNVMeDataType"] as? [[String: Any]],
               let drive = controllers.compactMap({ $0["_items"] as? [[String: Any]] }).flatMap({ $0 }).first {
                h.diskModel = drive["device_model"] as? String ?? drive["_name"] as? String
                h.smart = drive["smart_status"] as? String
                if let value = drive["spnvme_trim_support"] as? String { h.trim = value.lowercased().contains("yes") }
            }
        }
        if h.modelName == "Ваш Mac" { h.modelName = h.model }
        if h.graphics == "Графический процессор" { h.graphics = h.chip }
        let version = ProcessInfo.processInfo.operatingSystemVersion
        h.os = "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        return h
    }

    public func sample() -> SystemSnapshot {
        var snapshot = SystemSnapshot()
        snapshot.uptime = ProcessInfo.processInfo.systemUptime
        snapshot.thermalState = ProcessInfo.processInfo.thermalState.rawValue
        var raw = [MSCPUTicks](repeating: MSCPUTicks(), count: 256)
        let coreCount = Int(ms_cpu_ticks(&raw, Int32(raw.count)))
        let current = raw.prefix(coreCount).map { [$0.user, $0.system, $0.idle, $0.nice] }
        if current.count == previousTicks.count, !current.isEmpty {
            let readings = zip(previousTicks, current).compactMap { MetricMath.cpuDelta(previous: $0, current: $1) }
            if !readings.isEmpty {
                snapshot.cpu.usage = readings.map(\.usage).reduce(0, +) / Double(readings.count)
                snapshot.cpu.system = readings.map(\.system).reduce(0, +) / Double(readings.count)
                snapshot.cpu.user = readings.map(\.user).reduce(0, +) / Double(readings.count)
                snapshot.cpu.cores = readings.map(\.usage)
            }
        }
        previousTicks = current
        let memory = ms_memory()
        if memory.valid {
            snapshot.memory.total = Double(memory.total)
            // Activity Monitor-style physical usage: active + inactive + wired + compressor,
            // excluding reclaimable file-backed and purgeable pages.
            let occupied = Double(memory.active) + Double(memory.inactive) + Double(memory.wired) + Double(memory.compressed)
            let reclaimable = Double(memory.purgeable) + Double(memory.external)
            snapshot.memory.used = min(Double(memory.total), max(0, occupied - reclaimable))
            snapshot.memory.wired = Double(memory.wired)
            snapshot.memory.compressed = Double(memory.compressed)
            snapshot.memory.app = max(0, snapshot.memory.used - snapshot.memory.wired - snapshot.memory.compressed)
            snapshot.memory.cached = Double(memory.external) + Double(memory.purgeable)
            snapshot.memory.swapUsed = Double(memory.swapUsed)
            snapshot.memory.swapTotal = Double(memory.swapTotal)
            snapshot.memory.pressure = Int(memory.pressure)
        }
        let battery = ms_battery()
        snapshot.battery.present = battery.present
        snapshot.battery.charging = battery.charging
        snapshot.battery.external = battery.external
        snapshot.battery.percentage = max(0, min(100, battery.percentage))
        snapshot.battery.health = battery.health >= 0 ? battery.health : nil
        snapshot.battery.temperature = battery.temperature > 0 && battery.temperature < 100 ? battery.temperature : nil
        snapshot.battery.voltage = battery.voltage > 0 ? battery.voltage : nil
        snapshot.battery.amperage = battery.amperage == -1 ? nil : battery.amperage
        snapshot.battery.cycles = Int(battery.cycles)
        snapshot.battery.currentCapacity = Int(battery.currentCapacity)
        snapshot.battery.maxCapacity = Int(battery.maxCapacity)
        snapshot.battery.designCapacity = Int(battery.designCapacity)
        snapshot.battery.minutes = battery.minutes > 0 && battery.minutes < 6000 ? Int(battery.minutes) : nil
        let gpu = ms_gpu_usage()
        snapshot.gpu = gpu >= 0 ? gpu : nil
        let network = ms_network()
        let now = ProcessInfo.processInfo.systemUptime
        if network.valid {
            let received = Double(network.received), sent = Double(network.sent)
            snapshot.network.received = received; snapshot.network.sent = sent
            if let previous = previousNetwork {
                snapshot.network.download = MetricMath.rate(previous: previous.received, current: received, seconds: now - previous.time)
                snapshot.network.upload = MetricMath.rate(previous: previous.sent, current: sent, seconds: now - previous.time)
            }
            previousNetwork = (received, sent, now)
        }
        var temperatures = [MSTemperature](repeating: MSTemperature(), count: 512)
        let count = Int(ms_temperatures(&temperatures, Int32(temperatures.count)))
        snapshot.temperatures = temperatures.prefix(count).map { item in
            var key = item.key
            let name = withUnsafePointer(to: &key) { $0.withMemoryRebound(to: CChar.self, capacity: 5) { String(cString: $0) } }
            return TemperatureReading(key: name, value: item.value)
        }.sorted { $0.key < $1.key }
        if snapshot.battery.present && snapshot.battery.temperature == nil {
            let batterySensors = snapshot.temperatures.filter { ["TB0T", "TB1T", "TB2T", "TB3T"].contains($0.key) }
            if !batterySensors.isEmpty { snapshot.battery.temperature = batterySensors.map(\.value).reduce(0, +) / Double(batterySensors.count) }
        }
        var fans = [MSFan](repeating: MSFan(), count: 16)
        let fanCount = Int(ms_fans(&fans, Int32(fans.count)))
        snapshot.fans = fans.prefix(fanCount).map { FanReading(id: Int($0.index), current: $0.current, minimum: $0.minimum.isFinite ? $0.minimum : nil, maximum: $0.maximum.isFinite ? $0.maximum : nil) }
        if tick % 4 == 0 { processes = readProcesses() }
        if tick % 10 == 0 { disks = readDisks() }
        snapshot.processes = processes
        snapshot.disks = disks
        tick += 1
        return snapshot
    }
    private func readProcesses() -> [ProcessReading] {
        guard let text = SystemCommand.text("/bin/ps", ["-axo", "pid=,pcpu=,rss=,comm="]) else { return [] }
        return text.split(separator: "\n").compactMap { line -> ProcessReading? in
            let parts = line.split(maxSplits: 3, omittingEmptySubsequences: true, whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.count == 4, let pid = Int(parts[0]), let cpu = Double(parts[1]), let rss = Double(parts[2]) else { return nil }
            let name = URL(fileURLWithPath: String(parts[3])).lastPathComponent
            return ProcessReading(id: pid, name: name, cpu: cpu, memory: rss * 1024)
        }.sorted { $0.cpu > $1.cpu }.prefix(80).map { $0 }
    }
    private func readDisks() -> [DiskReading] {
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey, .volumeLocalizedFormatDescriptionKey, .volumeIsInternalKey]
        let fm = FileManager.default
        var urls = [URL(fileURLWithPath: NSHomeDirectory())]
        urls += (fm.mountedVolumeURLs(includingResourceValuesForKeys: Array(keys), options: [.skipHiddenVolumes]) ?? []).filter { $0.path.hasPrefix("/Volumes/") }
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys), let total = values.volumeTotalCapacity, let free = values.volumeAvailableCapacity, total > 0 else { return nil }
            return DiskReading(id: url.path, name: values.volumeName ?? "Macintosh HD", total: Double(total), free: Double(free), filesystem: values.volumeLocalizedFormatDescription ?? "APFS")
        }
    }
    private func sysString(_ key: String) -> String? {
        var buffer = [CChar](repeating: 0, count: 512)
        return ms_sysctl_string(key, &buffer, 512) > 0 ? String(cString: buffer) : nil
    }
}
