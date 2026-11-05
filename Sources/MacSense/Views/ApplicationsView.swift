import SwiftUI
import MacSenseCore

struct ApplicationsView: View {
    @State private var apps: [InstalledApplication] = []
    @State private var selectedApp: String?
    @State private var files: [FileCandidate] = []
    @State private var selectedFiles: Set<String> = []
    @State private var query = ""
    @State private var scanning = false
    @State private var loadingFiles = false
    @State private var deleting = false
    @State private var confirmTrash = false
    @State private var message: String?
    private let service = UtilityService()
    private var current: InstalledApplication? { apps.first { $0.id == selectedApp } }
    private var chosen: [FileCandidate] { files.filter { selectedFiles.contains($0.id) } }
    private var running: Bool { current?.bundleID.map { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty } ?? false }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Утилиты / Приложения"), title: L("Удаление приложений"), description: L("Установленные приложения и связанные файлы в вашей библиотеке."))
            HStack {
                TextField(L("Найти приложение…"), text: $query).textFieldStyle(.roundedBorder).frame(width: 280)
                Text(L("\(apps.count) приложений")).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button(L("Сканировать"), systemImage: "arrow.clockwise") { Task { await scan() } }.disabled(scanning || deleting)
            }
            if scanning {
                MetricCard(title: L("Анализ приложений"), icon: "app.badge") {
                    ProgressView(L("Считаем размеры приложений…")).frame(maxWidth: .infinity).padding(45)
                    Text(L("Большие приложения могут потребовать больше времени. Сканируются /Applications и ~/Applications.")).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 3) {
                        ForEach(apps.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { app in
                            Button { selectedApp = app.id } label: {
                                HStack(spacing: 11) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path)).resizable().frame(width: 31, height: 31)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(app.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                        Text(L("Версия \(app.version)")).font(.system(size: 9)).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 4)
                                    Text((app.complete ? "" : "≥ ") + Fmt.bytes(app.bytes)).font(.system(size: 10)).foregroundStyle(.secondary)
                                }.padding(10).contentShape(Rectangle()).background(selectedApp == app.id ? Palette.blue.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain)
                        }
                        if apps.isEmpty { EmptyState(icon: "app", title: L("Приложения не найдены"), text: L("Нажмите «Сканировать», чтобы обновить список.")) }
                    }.padding(8).frame(width: 305).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 16) {
                        if let app = current {
                            MetricCard(title: app.name, icon: "app.badge", subtitle: L("Связанные файлы")) {
                                Text(app.bundleID ?? app.url.lastPathComponent).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                                if loadingFiles { ProgressView().frame(maxWidth: .infinity).padding(20) }
                                else { FileSelectionList(files: files, selection: $selectedFiles) }
                                Divider()
                                DetailRow(title: L("Выбрано"), value: Fmt.bytes(chosen.map(\.bytes).reduce(0, +)))
                                Button(L("Переместить в Корзину…"), systemImage: "trash", role: .destructive) { confirmTrash = true }
                                    .disabled(chosen.isEmpty || loadingFiles || deleting || running)
                                if running { Text(L("Сначала завершите приложение, чтобы переместить его файлы в Корзину.")).font(.system(size: 10)).foregroundStyle(Palette.orange) }
                            }
                        } else { EmptyState(icon: "app.badge", title: L("Выберите приложение"), text: L("Справа появятся его файлы и настройки.")) }
                    }.frame(maxWidth: .infinity)
                }
            }
            InfoNote(text: L("Связанные файлы определяются по точному идентификатору приложения. Общие папки разработчика и неизвестные остатки не включаются. Размер с символом ≥ подсчитан частично. Удаление выполняется только после выбора и подтверждения."))
        }
        .task { if apps.isEmpty { await scan() } }
        .task(id: selectedApp) { await loadFiles() }
        .confirmationDialog(L("Переместить выбранные файлы в Корзину?"), isPresented: $confirmTrash, titleVisibility: .visible) {
            Button(L("Переместить \(chosen.count) объектов в Корзину"), role: .destructive) { Task { await trash() } }
        } message: { Text(L("\(current?.name ?? L("Приложение")) · \(Fmt.bytes(chosen.map(\.bytes).reduce(0, +))). Выбранные настройки и данные приложения также будут перемещены в Корзину.")) }
        .alert(L("Результат операции"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }
    private func scan() async {
        guard !scanning else { return }; scanning = true
        apps = await service.applications(); scanning = false
        if !apps.contains(where: { $0.id == selectedApp }) { selectedApp = apps.first?.id }
    }
    private func loadFiles() async {
        files = []; selectedFiles = []
        guard let app = current else { return }
        loadingFiles = true
        let result = await service.relatedFiles(for: app)
        guard selectedApp == app.id else { return }
        files = result; selectedFiles = [app.id]; loadingFiles = false
    }
    private func trash() async {
        guard !running, !deleting else { return }; deleting = true
        let result = await service.trash(chosen)
        files.removeAll { result.removed.contains($0.id) }
        apps.removeAll { result.removed.contains($0.id) }
        selectedFiles.subtract(result.removed)
        deleting = false
        message = L("Перемещено в Корзину: \(result.removed.count).") + (result.failures.isEmpty ? "" : "\n\n" + result.failures.joined(separator: "\n"))
    }
}

struct FileSelectionList: View {
    let files: [FileCandidate]
    @Binding var selection: Set<String>
    var body: some View {
        VStack(spacing: 16) {
            ForEach(files) { file in
                HStack(alignment: .top, spacing: 9) {
                    Toggle(L("Выбрать \(file.title)"), isOn: Binding(get: { selection.contains(file.id) }, set: { if $0 { selection.insert(file.id) } else { selection.remove(file.id) } }))
                        .labelsHidden().toggleStyle(.checkbox)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(file.title).font(.system(size: 11, weight: .medium)).lineLimit(1).truncationMode(.middle)
                        Text(L10n.translate(file.category)).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 5)
                    Text((file.complete ? "" : "≥ ") + Fmt.bytes(file.bytes)).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize()
                    Button { NSWorkspace.shared.activateFileViewerSelecting([file.url]) } label: { Image(systemName: "magnifyingglass") }
                        .buttonStyle(.borderless).font(.system(size: 10)).help(L("Показать в Finder"))
                }
            }
        }
    }
}
