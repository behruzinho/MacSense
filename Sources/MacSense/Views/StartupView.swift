import SwiftUI
import MacSenseCore

struct StartupView: View {
    @State private var entries: [StartupEntry] = []
    @State private var scanning = false
    private let service = UtilityService()
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Утилиты / Оптимизация"), title: L("Автозагрузка"), description: L("Агенты запуска и фоновые службы, установленные на вашем Mac."))
            HStack {
                Button(L("Обновить список"), systemImage: "arrow.clockwise") { Task { await scan() } }.disabled(scanning)
                Spacer()
                Button(L("Объекты входа macOS"), systemImage: "gearshape") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") { NSWorkspace.shared.open(url) }
                }
            }
            if scanning { ProgressView(L("Читаем конфигурации запуска…")).frame(maxWidth: .infinity).padding(30) }
            ForEach(["Пользовательские агенты", "Агенты системы", "Фоновые службы"], id: \.self) { group in
                let items = entries.filter { $0.group == group }
                if !items.isEmpty {
                    MetricCard(title: group, icon: "speedometer", subtitle: "\(items.count)") {
                        ForEach(items) { item in
                            HStack(spacing: 13) {
                                Image(systemName: "terminal").font(.system(size: 21)).foregroundStyle(Palette.blue)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.label).font(.system(size: 12, weight: .medium)).textSelection(.enabled)
                                    Text(item.program).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                }
                                Spacer()
                                Text(item.runAtLoad ? L("При загрузке") : L("По конфигурации")).font(.system(size: 9)).foregroundStyle(.secondary)
                                Button { NSWorkspace.shared.activateFileViewerSelecting([item.url]) } label: { Image(systemName: "folder") }.buttonStyle(.borderless).help(L("Показать конфигурацию в Finder"))
                            }
                            if item.id != items.last?.id { Divider() }
                        }
                    }
                }
            }
            if !scanning && entries.isEmpty { EmptyState(icon: "speedometer", title: L("Агенты не найдены"), text: L("В доступных папках LaunchAgents и LaunchDaemons нет конфигураций.")) }
            InfoNote(text: L("Список показывает найденные plist-конфигурации, а не фактическое состояние запущенных служб. Управлять разрешёнными объектами входа можно в настройках macOS."))
        }.task { await scan() }
    }
    private func scan() async { guard !scanning else { return }; scanning = true; entries = await service.startupEntries(); scanning = false }
}
