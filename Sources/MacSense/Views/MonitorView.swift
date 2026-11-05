import SwiftUI
import MacSenseCore

struct MonitorView: View {
    @EnvironmentObject private var monitor: MonitorStore
    @AppStorage("monitorPanels") private var encoded = MonitorConfiguration.defaultEncoded
    @AppStorage("monitorCombined") private var combined = false
    @AppStorage("menuMetric") private var menuMetric = "cpu"
    @AppStorage("showMenuBar") private var showMenuBar = true
    private var configuration: MonitorConfiguration { MonitorConfiguration(encoded: encoded) }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Всё под контролем"), title: L("Мониторинг"), description: L("Настройте живые панели и показатель в строке меню."))
            HStack {
                Toggle(L("Единая колонка"), isOn: $combined).toggleStyle(.switch)
                Spacer()
                Button(monitor.paused ? L("Продолжить мониторинг") : L("Приостановить мониторинг"), systemImage: monitor.paused ? "play.fill" : "pause.fill") { monitor.paused.toggle() }
            }
            DisclosureGroup(L("Настроить панели")) {
                MetricCard(title: L("Настроить панели"), icon: "slider.horizontal.3") {
                    Toggle(L("Показывать строку меню"), isOn: $showMenuBar)
                    MenuMetricPicker(selection: $menuMetric)
                    Divider()
                    ForEach(configuration.panels + MonitorPanel.allCases.filter { !configuration.panels.contains($0) }) { panel in
                        HStack {
                            Toggle(panel.title, isOn: Binding(get: { configuration.panels.contains(panel) }, set: { enabled in
                                var updated = configuration; updated.set(panel, enabled: enabled); encoded = updated.encoded
                            }))
                            Spacer()
                            Button { move(panel, -1) } label: { Image(systemName: "arrow.up") }.disabled(configuration.panels.first == panel || !configuration.panels.contains(panel)).help(L("Переместить выше"))
                            Button { move(panel, 1) } label: { Image(systemName: "arrow.down") }.disabled(configuration.panels.last == panel || !configuration.panels.contains(panel)).help(L("Переместить ниже"))
                        }.controlSize(.small)
                    }
                    Button(L("Восстановить панели")) { encoded = MonitorConfiguration.defaultEncoded }
                }.padding(.top, 12)
            }
            LazyVGrid(columns: combined ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 320))], alignment: .leading, spacing: 16) {
                ForEach(configuration.panels) { panel in MonitorPanelView(panel: panel) }
            }
            if configuration.panels.isEmpty { InfoNote(text: L("Выберите панели в настройках выше.")) }
        }
    }
    private func move(_ panel: MonitorPanel, _ offset: Int) { var updated = configuration; updated.move(panel, offset: offset); encoded = updated.encoded }
}
struct MenuMetricPicker: View {
    @Binding var selection: String
    var body: some View {
        Picker(L("Показатель в меню"), selection: $selection) {
            Text("CPU").tag("cpu")
            Text("RAM").tag("memory")
            Text("GPU").tag("gpu")
            Text(L("Батарея")).tag("battery")
            Text(L("Температура CPU")).tag("temperature")
            Text(L("Загрузка сети")).tag("network")
        }
    }
}
struct MetricMenuLabel: View {
    @EnvironmentObject private var monitor: MonitorStore
    @AppStorage("menuMetric") private var metric = "cpu"
    private var title: String {
        let s = monitor.snapshot
        switch metric {
        case "memory": return "RAM " + Fmt.percent(s.memory.total > 0 ? s.memory.percentage : nil)
        case "gpu": return "GPU " + Fmt.percent(s.gpu)
        case "battery": return Fmt.percent(s.battery.present ? s.battery.percentage : nil)
        case "temperature": return Fmt.temperature(s.cpuTemperature)
        case "network": return "↓ " + Fmt.rate(s.network.download)
        default: return "CPU " + Fmt.percent(s.cpu.usage)
        }
    }
    var body: some View { Label(title, systemImage: monitor.paused ? "pause.circle" : "waveform.path.ecg") }
}
struct MonitorPanelView: View {
    @EnvironmentObject private var monitor: MonitorStore
    let panel: MonitorPanel
    private var s: SystemSnapshot { monitor.snapshot }
    var body: some View {
        MetricCard(title: panel.title, icon: icon, tint: tint) {
            switch panel {
            case .cpu:
                DetailRow(title: "CPU", value: Fmt.percent(s.cpu.usage))
                Sparkline(points: monitor.cpuHistory, height: 65)
                DetailRow(title: L("Пользователь"), value: Fmt.percent(s.cpu.user))
                DetailRow(title: L("Система"), value: Fmt.percent(s.cpu.system))
            case .memory:
                DetailRow(title: "RAM", value: "\(Fmt.bytes(s.memory.used)) / \(Fmt.bytes(s.memory.total))")
                Meter(value: s.memory.percentage, tint: Palette.purple)
                DetailRow(title: L("Давление памяти"), value: s.memory.pressureLabel)
                DetailRow(title: "Swap", value: Fmt.bytes(s.memory.swapUsed))
            case .gpu:
                DetailRow(title: "GPU", value: Fmt.percent(s.gpu))
                Sparkline(points: monitor.gpuHistory, tint: Palette.cyan, height: 65)
                Text(monitor.hardware.graphics).font(.system(size: 11)).foregroundStyle(.secondary)
            case .storage:
                if let disk = s.disks.first {
                    DetailRow(title: disk.name, value: Fmt.percent(disk.percentage))
                    Meter(value: disk.percentage, tint: Palette.orange)
                    Text(L("\(Fmt.bytes(disk.free)) свободно")).font(.system(size: 11)).foregroundStyle(.secondary)
                } else { Text(L("Чтение накопителей…")).foregroundStyle(.secondary) }
            case .network:
                DetailRow(title: L("Загрузка"), value: Fmt.rate(s.network.download))
                Sparkline(points: monitor.downloadHistory, tint: Palette.cyan, ceiling: nil, height: 55)
                DetailRow(title: L("Отправка"), value: Fmt.rate(s.network.upload))
            case .sensors:
                DetailRow(title: L("Температура CPU"), value: Fmt.temperature(s.cpuTemperature))
                DetailRow(title: L("Максимальная температура GPU"), value: Fmt.temperature(s.temperatures.filter { $0.group == "Графика" }.map(\.value).max()))
                ForEach(s.fans) { fan in DetailRow(title: fan.name, value: "\(Int(fan.current)) RPM") }
            case .power:
                if s.battery.present {
                    DetailRow(title: L("Батарея"), value: Fmt.percent(s.battery.percentage))
                    Meter(value: s.battery.percentage, tint: Palette.green)
                    DetailRow(title: L("Состояние аккумулятора"), value: Fmt.percent(s.battery.health))
                    DetailRow(title: L("Циклы зарядки"), value: "\(s.battery.cycles)")
                    Text(s.battery.status).font(.system(size: 11)).foregroundStyle(.secondary)
                } else { Text(L("Питание от сети")).foregroundStyle(.secondary) }
            }
        }
    }
    private var tint: Color { panel == .memory ? Palette.purple : panel == .power ? Palette.green : panel == .storage ? Palette.orange : Palette.blue }
    private var icon: String {
        switch panel {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .gpu: "display"
        case .storage: "internaldrive"
        case .network: "network"
        case .sensors: "thermometer.medium"
        case .power: "bolt"
        }
    }
}
