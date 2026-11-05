import SwiftUI
import MacSenseCore

struct SettingsView: View {
    @EnvironmentObject private var monitor: MonitorStore
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("language") private var language = "ru"
    @AppStorage("showMenuBar") private var showMenuBar = true
    @AppStorage("menuMetric") private var menuMetric = "cpu"
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "waveform.path.ecg").font(.system(size: 30)).foregroundStyle(Palette.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MacSense").font(.system(size: 20, weight: .semibold))
                        Text(L("Версия \(AppInfo.version)")).font(.system(size: 11)).foregroundStyle(.secondary)
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
                Toggle(L("Показывать строку меню"), isOn: $showMenuBar)
                MenuMetricPicker(selection: $menuMetric)
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
    @AppStorage("monitorPanels") private var encoded = MonitorConfiguration.defaultEncoded
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("MacSense", systemImage: "waveform.path.ecg").font(.system(size: 14, weight: .semibold))
                Spacer()
                Button { monitor.paused.toggle() } label: { Image(systemName: monitor.paused ? "play.fill" : "pause.fill") }.buttonStyle(.plain).help(L("Приостановить или продолжить мониторинг"))
            }
            ScrollView {
                LazyVStack(spacing: 12) { ForEach(MonitorConfiguration(encoded: encoded).panels) { MonitorPanelView(panel: $0) } }
            }.frame(maxHeight: 520)
            Divider()
            HStack {
                Button(L("Открыть MacSense")) { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                Spacer()
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }.help(L("Завершить MacSense"))
            }.controlSize(.small)
        }.padding(16).frame(width: 340).task { monitor.start() }
    }
}
