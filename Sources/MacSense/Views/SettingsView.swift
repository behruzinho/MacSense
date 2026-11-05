import SwiftUI
import MacSenseCore

struct SettingsView: View {
    @EnvironmentObject private var monitor: MonitorStore
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("language") private var language = "ru"
    @AppStorage("showMenuBar") private var showMenuBar = true
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "waveform.path.ecg").font(.system(size: 30)).foregroundStyle(Palette.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MacSense").font(.system(size: 20, weight: .semibold))
                        Text(L("Монитор вашего Mac · версия 0.1.0")).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 8)
            }
            Section(L("Мониторинг")) {
                Picker(L("Обновление показателей"), selection: $monitor.interval) {
                    Text(L("Каждую секунду")).tag(1.0)
                    Text(L("Каждые 2 секунды")).tag(2.0)
                    Text(L("Каждые 5 секунд")).tag(5.0)
                    Text(L("Каждые 10 секунд")).tag(10.0)
                }
                Toggle(L("Показывать CPU в строке меню"), isOn: $showMenuBar)
                Toggle(L("Приостановить мониторинг"), isOn: $monitor.paused)
            }
            Section(L("Язык и оформление")) {
                Picker(L("Язык приложения"), selection: $language) {
                    ForEach(AppLanguage.allCases) { item in Text(item.nativeName).tag(item.rawValue) }
                }
                Picker(L("Тема"), selection: $appearance) {
                    Text(L("Тёмная")).tag("dark")
                    Text(L("Светлая")).tag("light")
                    Text(L("Системная")).tag("system")
                }
            }
            Section(L("Поддержать разработку")) {
                SupportView()
            }
            Section {
                Label(L("Все показатели обрабатываются локально. Приложение не отправляет данные в интернет."), systemImage: "lock.shield").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).frame(width: 540, height: 670)
    }
}

struct MenuMonitorView: View {
    @EnvironmentObject private var monitor: MonitorStore
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Label("MacSense", systemImage: "waveform.path.ecg").font(.system(size: 14, weight: .semibold))
                Spacer()
                Circle().fill(monitor.paused ? Palette.orange : Palette.green).frame(width: 6, height: 6)
            }
            DetailRow(title: L("Процессор"), value: Fmt.percent(monitor.snapshot.cpu.usage))
            Meter(value: monitor.snapshot.cpu.usage ?? 0)
            DetailRow(title: L("Память"), value: "\(Fmt.bytes(monitor.snapshot.memory.used)) / \(Fmt.bytes(monitor.snapshot.memory.total))")
            Meter(value: monitor.snapshot.memory.percentage, tint: Palette.purple)
            if monitor.snapshot.battery.present {
                DetailRow(title: L("Батарея"), value: Fmt.percent(monitor.snapshot.battery.percentage))
            }
            if let temperature = monitor.snapshot.cpuTemperature { DetailRow(title: L("Температура CPU"), value: Fmt.temperature(temperature)) }
            Divider()
            HStack {
                Button(L("Открыть MacSense")) { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                Spacer()
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }.help(L("Завершить MacSense"))
            }.controlSize(.small)
        }.padding(20).frame(width: 310).task { monitor.start() }
    }
}
