import SwiftUI
import MacSenseCore
import ServiceManagement

struct StartupView: View {
    @State private var entries: [StartupEntry] = []
    @State private var scanning = false
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var needsApproval = SMAppService.mainApp.status == .requiresApproval
    @State private var pending: StartupEntry?
    @State private var pendingEnabled = false
    @State private var confirm = false
    @State private var message: String?
    private let service = UtilityService()
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Утилиты / Оптимизация"), title: L("Автозагрузка"), description: L("Агенты запуска и фоновые службы, установленные на вашем Mac."))
            MetricCard(title: L("Объекты входа"), icon: "power", tint: Palette.green) {
                Toggle(L("Запускать MacSense при входе"), isOn: Binding(get: { loginEnabled }, set: { value in Task { await setLogin(value) } })).toggleStyle(.switch)
                if needsApproval { Text(L("Разрешите автозапуск MacSense в настройках macOS.")).font(.system(size: 11)).foregroundStyle(Palette.orange) }
                Button(L("Объекты входа macOS"), systemImage: "gearshape") { SMAppService.openSystemSettingsLoginItems() }
                Text(L("Сторонние объекты входа управляются в настройках macOS.")).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            HStack {
                Text(L("Состояние launchd")).font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(L("Обновить список"), systemImage: "arrow.clockwise") { Task { await scan() } }.disabled(scanning)
            }
            if scanning { ProgressView(L("Читаем конфигурации запуска…")).frame(maxWidth: .infinity).padding(30) }
            ForEach(["Пользовательские агенты", "Агенты системы", "Фоновые службы"], id: \.self) { group in
                let items = entries.filter { $0.group == group }
                if !items.isEmpty {
                    MetricCard(title: group, icon: "speedometer", subtitle: "\(items.count)") {
                        ForEach(items) { item in
                            HStack(spacing: 13) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: item.program)).resizable().frame(width: 27, height: 27)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.label).font(.system(size: 12, weight: .medium)).textSelection(.enabled)
                                    Text(item.program).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(item.enabled.map { $0 ? L("Разрешён запуск") : L("Запуск отключён") } ?? "—")
                                    Text(item.loaded.map { $0 ? L("Загружен") : L("Не загружен") } ?? L("Состояние процесса недоступно"))
                                }.font(.system(size: 9)).foregroundStyle(.secondary)
                                if StartupParser.canManage(item, home: FileManager.default.homeDirectoryForCurrentUser), let enabled = item.enabled {
                                    Toggle(L("Разрешён запуск"), isOn: Binding(get: { enabled }, set: { value in pending = item; pendingEnabled = value; confirm = true })).labelsHidden().toggleStyle(.switch).controlSize(.small).disabled(scanning)
                                }
                                Button { NSWorkspace.shared.activateFileViewerSelecting([item.url]) } label: { Image(systemName: "folder") }.buttonStyle(.borderless).help(L("Показать конфигурацию в Finder"))
                            }
                            if item.id != items.last?.id { Divider() }
                        }
                    }
                }
            }
            if !scanning && entries.isEmpty { EmptyState(icon: "speedometer", title: L("Агенты не найдены"), text: L("В доступных папках LaunchAgents и LaunchDaemons нет конфигураций.")) }
            InfoNote(text: L("Переключатели пользовательских агентов изменяют разрешение launchd для будущих запусков. Уже загруженный процесс не останавливается. Системные агенты и службы доступны только для просмотра."))
        }.task { await scan() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refreshLogin() }
        .confirmationDialog(pendingEnabled ? L("Разрешить запуск агента?") : L("Отключить запуск агента?"), isPresented: $confirm, titleVisibility: .visible) {
            Button(pendingEnabled ? L("Разрешить запуск") : L("Отключить запуск")) { Task { await changeAgent() } }
        } message: { Text(pending?.label ?? "") }
        .alert(L("Результат операции"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }
    private func scan() async { guard !scanning else { return }; scanning = true; entries = await service.startupEntries(); refreshLogin(); scanning = false }
    private func refreshLogin() {
        loginEnabled = SMAppService.mainApp.status == .enabled
        needsApproval = SMAppService.mainApp.status == .requiresApproval
    }
    private func setLogin(_ enabled: Bool) async {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try await SMAppService.mainApp.unregister() }
        } catch { message = error.localizedDescription }
        refreshLogin()
    }
    private func changeAgent() async {
        guard let entry = pending else { return }
        let success = await service.setStartupEnabled(pendingEnabled, entry: entry)
        if !success { message = L("macOS не разрешила изменить состояние агента.") }
        pending = nil; await scan()
    }
}
