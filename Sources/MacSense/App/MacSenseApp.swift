import SwiftUI
import MacSenseCore

@main
struct MacSenseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var monitor = MonitorStore()
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("language") private var language = "ru"
    @AppStorage("showMenuBar") private var showMenuBar = true

    init() {
        if CommandLine.arguments.contains("--diagnostics") {
            Diagnostics.run()
            exit(0)
        }
    }
    var body: some Scene {
        WindowGroup("MacSense", id: "main") {
            ContentView()
                .environmentObject(monitor)
                .environment(\.locale, L10n.locale)
                .id(language)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
                .frame(minWidth: 1060, minHeight: 740)
                .task { monitor.start() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1260, height: 850)
        .commands {
            AboutCommands()
            CommandGroup(replacing: .newItem) {}
            CommandMenu(L("Мониторинг")) {
                Button(monitor.paused ? L("Продолжить мониторинг") : L("Приостановить мониторинг")) { monitor.paused.toggle() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                Button(L("Обновить показатели")) { Task { await monitor.refresh() } }
                    .keyboardShortcut("r")
                Divider()
                Button(L("Экспортировать отчёт…")) { monitor.exportReport() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }
        Settings {
            SettingsView().environmentObject(monitor).environment(\.locale, L10n.locale)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        }
        Window(L("О MacSense"), id: "about") {
            AboutView().environment(\.locale, L10n.locale).id(language)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        MenuBarExtra(isInserted: $showMenuBar) {
            MenuMonitorView().environmentObject(monitor).environment(\.locale, L10n.locale).id(language)
        } label: {
            Label(monitor.snapshot.cpu.usage.map { "\(Int($0))%" } ?? "MacSense", systemImage: "waveform.path.ecg")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

enum Diagnostics {
    static func run() {
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            let reader = TelemetryReader()
            let hardware = await reader.hardware()
            _ = await reader.sample()
            try? await Task.sleep(for: .seconds(1))
            let sample = await reader.sample()
            let inventory = await StorageService().inventory()
            let result: [String: Any] = [
                "model": hardware.model, "chip": hardware.chip, "cpuCores": hardware.coreCount,
                "cpuPercent": sample.cpu.usage as Any? ?? NSNull(), "memoryTotal": sample.memory.total,
                "memoryUsed": sample.memory.used, "batteryPresent": sample.battery.present,
                "batteryPercent": sample.battery.percentage, "batteryCycles": sample.battery.cycles,
                "batteryHealth": sample.battery.health as Any? ?? NSNull(), "batteryMaxCapacity": sample.battery.maxCapacity,
                "batteryTemperature": sample.battery.temperature as Any? ?? NSNull(), "temperatureSensors": sample.temperatures.count,
                "fans": sample.fans.count, "gpuPercent": sample.gpu as Any? ?? NSNull(),
                "physicalDisks": inventory.count, "diskIODevices": sample.diskIO.map(\.id),
                "metalDevices": hardware.gpuDevices.count, "modelSerialAvailable": hardware.serial != nil,
                "volumes": sample.disks.count, "processes": sample.processes.count,
                "downloadBytesPerSecond": sample.network.download as Any? ?? NSNull()
            ]
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
                print(String(decoding: data, as: UTF8.self))
            }
            semaphore.signal()
        }
        semaphore.wait()
    }
}
