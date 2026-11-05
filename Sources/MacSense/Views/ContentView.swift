import SwiftUI
import MacSenseCore

enum Destination: String, CaseIterable, Identifiable {
    case overview, monitor, optimize, applications, clean, trim, cpu, memory, storage, graphics, battery, cooling, network
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: L("Обзор")
        case .monitor: L("Мониторинг")
        case .optimize: L("Автозагрузка")
        case .applications: L("Приложения")
        case .clean: L("Очистка")
        case .trim: "TRIM"
        case .cpu: L("Процессор")
        case .memory: L("Память")
        case .storage: L("Накопители")
        case .graphics: L("Графика")
        case .battery: L("Батарея")
        case .cooling: L("Охлаждение")
        case .network: L("Сеть")
        }
    }
    var icon: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .monitor: "chart.bar.xaxis"
        case .optimize: "speedometer"
        case .applications: "app.badge"
        case .clean: "sparkles"
        case .trim: "square.grid.3x3"
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .storage: "internaldrive"
        case .graphics: "display"
        case .battery: "battery.75percent"
        case .cooling: "fanblades"
        case .network: "network"
        }
    }
}
struct ContentView: View {
    @EnvironmentObject private var monitor: MonitorStore
    @Environment(\.openWindow) private var openWindow: OpenWindowAction
    @SceneStorage("selectedPage") private var selectedPage = Destination.overview.rawValue
    private var selection: Destination { Destination(rawValue: selectedPage) ?? .overview }
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                chrome
                Divider().opacity(0.5)
                ScrollView {
                    page.padding(28).frame(maxWidth: 1500).frame(maxWidth: .infinity)
                }
                .background(Palette.background)
                footer
            }
        }
        .tint(Palette.blue)
        .background(Palette.background)
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Palette.blue.gradient).frame(width: 33, height: 33)
                    Image(systemName: "waveform.path.ecg").font(.system(size: 18, weight: .medium)).foregroundStyle(.white)
                }
                Text("MacSense").font(.system(size: 18, weight: .semibold))
            }.padding(.horizontal, 21).padding(.top, 48).padding(.bottom, 24)
            ScrollView {
                VStack(spacing: 0) {
            navRow(.overview)
            navRow(.monitor)
            sectionLabel(L("УТИЛИТЫ"))
            ForEach([Destination.optimize, .applications, .clean, .trim]) { navRow($0) }
            sectionLabel(L("ОБОРУДОВАНИЕ"))
            ForEach([Destination.cpu, .memory, .storage, .graphics, .battery, .cooling, .network]) { navRow($0) }
                }
            }.scrollIndicators(.hidden)
            Spacer(minLength: 8)
            Divider().padding(.horizontal, 16)
            Link(destination: URL(string: "https://github.com/behruzinho/MacSense/issues/new")!) {
                Label(L("Обратная связь"), systemImage: "bubble.left").font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }.buttonStyle(.plain).padding(.horizontal, 8)
            SettingsLink { Label(L("Настройки"), systemImage: "gearshape").font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading).padding(12) }
                .buttonStyle(.plain).padding(.horizontal, 8).padding(.top, 5)
            Link(destination: URL(string: "https://github.com/behruzinho")!) {
                Label(L("Создано behruzinho"), systemImage: "heart").font(.system(size: 10)).foregroundStyle(.secondary)
            }.buttonStyle(.plain).padding(.horizontal, 21).padding(.bottom, 10)
            HStack(spacing: 6) {
                Image(systemName: "lock.shield").foregroundStyle(Palette.green)
                Text(L("Все данные остаются на Mac")).font(.system(size: 9))
            }.foregroundStyle(.tertiary).padding(.horizontal, 21).padding(.bottom, 16)
        }.frame(width: 205).background(.ultraThinMaterial)
    }
    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(.tertiary)
            .padding(.leading, 24).padding(.top, 22).padding(.bottom, 9)
    }
    private func navRow(_ destination: Destination) -> some View {
        Button {
            selectedPage = destination.rawValue
        } label: {
            HStack(spacing: 11) {
                Image(systemName: destination.icon).font(.system(size: 14)).frame(width: 19)
                Text(destination.title).font(.system(size: 12, weight: selection == destination ? .semibold : .regular))
                Spacer()
                if selection == destination { Circle().fill(Palette.blue).frame(width: 5, height: 5) }
            }
            .foregroundStyle(selection == destination ? .primary : .secondary)
            .padding(.horizontal, 12).frame(height: 33)
            .background(selection == destination ? Palette.blue.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }.buttonStyle(.plain).padding(.horizontal, 10)
        .accessibilityLabel(destination.title)
        .accessibilityAddTraits(selection == destination ? .isSelected : [])
    }
    private var chrome: some View {
        HStack(spacing: 9) {
            Image(systemName: selection.icon).foregroundStyle(.secondary)
            Text("MacSense").foregroundStyle(.tertiary)
            Text("/").foregroundStyle(.quaternary)
            Text(selection.title).foregroundStyle(.secondary)
            Spacer()
            Button { monitor.paused.toggle() } label: {
                HStack(spacing: 6) {
                    Circle().fill(monitor.paused ? Palette.orange : Palette.green).frame(width: 5, height: 5)
                    Text(monitor.paused ? L("Пауза") : L("В реальном времени")).font(.system(size: 10, weight: .medium))
                }.padding(.horizontal, 10).padding(.vertical, 6)
                    .background((monitor.paused ? Palette.orange : Palette.green).opacity(0.08), in: Capsule())
            }.buttonStyle(.plain).help(L("Приостановить или продолжить мониторинг"))
            Button { Task { await monitor.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.plain).padding(.leading, 8).help(L("Обновить · ⌘R")).disabled(monitor.refreshing)
            Button { monitor.exportReport() } label: { Image(systemName: "square.and.arrow.up") }
                .buttonStyle(.plain).padding(.leading, 8).help(L("Экспортировать отчёт"))
        }.font(.system(size: 11)).padding(.horizontal, 28).frame(height: 53)
    }
    private var footer: some View {
        HStack(spacing: 6) {
            Circle().fill(monitor.ready ? Palette.green : .secondary).frame(width: 4, height: 4)
            Text(monitor.ready ? L("Обновлено в \(Fmt.time(monitor.snapshot.date))") : L("Подключение к системе…"))
            Spacer()
            Text("\(monitor.hardware.architecture)  ·  MacSense \(AppInfo.version)")
        }.font(.system(size: 9)).foregroundStyle(.tertiary).padding(.horizontal, 28).frame(height: 29)
    }
    @ViewBuilder private var page: some View {
        switch selection {
        case .overview: DashboardView()
        case .monitor: MonitorView()
        case .cpu: ProcessorView()
        case .memory: MemoryView()
        case .battery: BatteryView()
        case .cooling: CoolingView()
        case .storage: StorageView()
        case .graphics: GraphicsView()
        case .network: NetworkView()
        case .trim: TrimView()
        case .optimize: StartupView()
        case .applications: ApplicationsView()
        case .clean: CleanerView()
        }
    }
}
