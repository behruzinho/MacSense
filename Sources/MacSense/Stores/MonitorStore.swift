import SwiftUI
import MacSenseCore

struct MetricPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

@MainActor
final class MonitorStore: ObservableObject {
    @Published var snapshot = SystemSnapshot()
    @Published var hardware = HardwareInfo()
    @Published var cpuHistory: [MetricPoint] = []
    @Published var memoryHistory: [MetricPoint] = []
    @Published var gpuHistory: [MetricPoint] = []
    @Published var downloadHistory: [MetricPoint] = []
    @Published var uploadHistory: [MetricPoint] = []
    @Published var temperatureHistory: [String: [MetricPoint]] = [:]
    @Published var fanHistory: [Int: [MetricPoint]] = [:]
    @Published var batteryHistory: [MetricPoint] = []
    @Published var paused = false
    @Published var ready = false
    @Published var refreshing = false
    @Published var interval: Double = UserDefaults.standard.object(forKey: "refreshInterval") as? Double ?? 2 {
        didSet { UserDefaults.standard.set(interval, forKey: "refreshInterval") }
    }
    private let reader = TelemetryReader()
    private var monitorTask: Task<Void, Never>?

    func start() {
        guard monitorTask == nil else { return }
        monitorTask = Task {
            await refresh()
            hardware = await reader.hardware()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                if !paused { await refresh() }
            }
        }
    }
    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        let sample = await reader.sample()
        snapshot = sample
        ready = true
        if let cpu = sample.cpu.usage { append(cpu, to: &cpuHistory, date: sample.date) }
        if sample.memory.total > 0 { append(sample.memory.percentage, to: &memoryHistory, date: sample.date) }
        if let gpu = sample.gpu { append(gpu, to: &gpuHistory, date: sample.date) }
        if let download = sample.network.download { append(download, to: &downloadHistory, date: sample.date) }
        if let upload = sample.network.upload { append(upload, to: &uploadHistory, date: sample.date) }
        if sample.battery.present { append(sample.battery.percentage, to: &batteryHistory, date: sample.date) }
        for sensor in sample.temperatures {
            var history = temperatureHistory[sensor.id] ?? []
            append(sensor.value, to: &history, date: sample.date)
            temperatureHistory[sensor.id] = history
        }
        for fan in sample.fans {
            var history = fanHistory[fan.id] ?? []
            append(fan.current, to: &history, date: sample.date)
            fanHistory[fan.id] = history
        }
    }
    private func append(_ value: Double, to points: inout [MetricPoint], date: Date) {
        points.append(MetricPoint(date: date, value: value))
        if points.count > 90 { points.removeFirst(points.count - 90) }
    }
    func exportReport() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MacSense-report.txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let s = snapshot
        let lines = [L("MacSense · Отчёт о системе"), L("Дата: \(Fmt.date(s.date))"), L("Модель: \(hardware.modelName) (\(hardware.model))"), L("Система: \(hardware.os)"), L("Процессор: \(hardware.chip)"), L("Ядра: \(hardware.coreCount)"), "CPU: \(Fmt.percent(s.cpu.usage))", L("Память: \(Fmt.bytes(s.memory.used)) / \(Fmt.bytes(s.memory.total))"), L("Графика: \(hardware.graphics)"), "GPU: \(Fmt.percent(s.gpu))", L("Батарея: \(s.battery.present ? Fmt.percent(s.battery.percentage) : L("Отсутствует"))"), L("Состояние батареи: \(Fmt.percent(s.battery.health))"), L("Циклы: \(s.battery.cycles)"), "", L("Температуры:")] + s.temperatures.map { "\($0.name) [\($0.key)]: \(Fmt.temperature($0.value))" } + ["", L("Вентиляторы:")] + s.fans.map { "\($0.name): \(Int($0.current)) RPM" }
        do { try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8) }
        catch { NSAlert(error: error).runModal() }
    }
}
