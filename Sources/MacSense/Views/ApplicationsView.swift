import SwiftUI
import MacSenseCore

struct ApplicationsView: View {
    @State private var apps: [InstalledApplication] = []
    @State private var selectedApp: String?
    @State private var selectedFiles: Set<String> = []
    @State private var query = ""
    @State private var issues: [String] = []
    @State private var scanning = false
    @State private var progress = ScanProgress(completed: 0, total: 0, current: "")
    @State private var scanTask: Task<Void, Never>?
    @State private var deleting = false
    @State private var confirmTrash = false
    @State private var message: String?
    private let service = UtilityService()
    private var current: InstalledApplication? { apps.first { $0.id == selectedApp } }
    private var allFiles: [FileCandidate] { UtilityPolicy.independentFiles(apps.flatMap(\.files).filter { selectedFiles.contains($0.id) }) }
    private var runningSelection: Bool {
        apps.contains { app in app.files.contains { selectedFiles.contains($0.id) } && app.bundleID.map { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty } == true }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Утилиты / Приложения"), title: L("Удаление приложений"), description: L("Установленные приложения и связанные файлы в вашей библиотеке."))
            HStack {
                TextField(L("Найти приложение…"), text: $query).textFieldStyle(.roundedBorder).frame(width: 280)
                Text(L("\(apps.count) приложений")).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button(L("Сканировать"), systemImage: "arrow.clockwise", action: startScan).disabled(scanning || deleting)
            }
            if !allFiles.isEmpty && !scanning {
                SelectionBar(files: allFiles, blocked: deleting || runningSelection, cancel: { selectedFiles = [] }, confirm: { confirmTrash = true })
                if runningSelection { Text(L("Сначала завершите приложение, чтобы переместить его файлы в Корзину.")).font(.system(size: 10)).foregroundStyle(Palette.orange) }
            }
            if scanning {
                ScanProgressCard(progress: progress) { scanTask?.cancel() }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 3) {
                        ForEach(apps.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.bundleID?.localizedCaseInsensitiveContains(query) == true }) { app in
                            HStack(spacing: 9) {
                                GroupSelectionToggle(files: app.files, selection: $selectedFiles, title: app.name)
                                Button { selectedApp = app.id } label: {
                                    HStack(spacing: 10) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path)).resizable().frame(width: 30, height: 30)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(app.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                            Text(L("\(app.files.count) объектов")).font(.system(size: 9)).foregroundStyle(.secondary)
                                        }
                                        Spacer(minLength: 4)
                                        Text((app.totalComplete ? "" : "≥ ") + Fmt.bytes(app.totalBytes)).font(.system(size: 10)).foregroundStyle(.secondary)
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }.padding(10).background(selectedApp == app.id ? Palette.blue.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        }
                        if apps.isEmpty { EmptyState(icon: "app", title: L("Приложения не найдены"), text: L("Нажмите «Сканировать», чтобы обновить список.")) }
                    }.padding(8).frame(width: 320).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 16) {
                        if let app = current {
                            MetricCard(title: app.name, icon: "app.badge", subtitle: L("Версия \(app.version)")) {
                                Text(app.bundleID ?? app.url.lastPathComponent).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                                GroupedFileSelectionList(files: app.files, selection: $selectedFiles)
                            }
                        } else { EmptyState(icon: "app.badge", title: L("Выберите приложение"), text: L("Справа появятся его файлы и настройки.")) }
                    }.frame(maxWidth: .infinity)
                }
            }
            ScanIssuesView(paths: issues)
            InfoNote(text: L("Связанные файлы определяются по точному идентификатору приложения. Общие папки разработчика и неизвестные остатки не включаются. Размер с символом ≥ подсчитан частично. Удаление выполняется только после выбора и подтверждения."))
        }
        .onAppear { if apps.isEmpty { startScan() } }
        .onDisappear { scanTask?.cancel() }
        .confirmationDialog(L("Переместить выбранные файлы в Корзину?"), isPresented: $confirmTrash, titleVisibility: .visible) {
            Button(L("Переместить \(allFiles.count) объектов в Корзину"), role: .destructive) { Task { await trash() } }
        } message: { Text(L("Общий размер: \(Fmt.bytes(allFiles.reduce(0) { $0 + $1.bytes })). Выбранные данные и настройки также будут перемещены в Корзину.")) }
        .alert(L("Результат операции"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }
    private func startScan() {
        guard !scanning else { return }; scanning = true
        scanTask = Task {
            let result = await service.applications { value in await MainActor.run { progress = value } }
            issues = await service.scanIssues()
            if !Task.isCancelled { apps = result; selectedFiles = []; selectedApp = result.first?.id }
            scanning = false
        }
    }
    private func trash() async {
        guard !runningSelection, !deleting else { return }; deleting = true
        let result = await service.trash(allFiles)
        apps.removeAll { result.removed.contains($0.id) }
        for i in apps.indices { apps[i].files.removeAll { result.removed.contains($0.id) } }
        selectedFiles.subtract(result.removed); deleting = false
        message = L("Перемещено в Корзину: \(result.removed.count).") + (result.failures.isEmpty ? "" : "\n\n" + result.failures.joined(separator: "\n"))
    }
}

struct GroupSelectionToggle: View {
    let files: [FileCandidate]
    @Binding var selection: Set<String>
    let title: String
    private var ids: Set<String> { Set(files.filter { !$0.reviewOnly }.map(\.id)) }
    private var checked: Bool { !ids.isEmpty && ids.isSubset(of: selection) }
    private var partial: Bool { !checked && !ids.isDisjoint(with: selection) }
    var body: some View {
        Button {
            if checked { selection.subtract(ids) } else { selection.formUnion(ids) }
        } label: {
            Image(systemName: checked ? "checkmark.square.fill" : partial ? "minus.square.fill" : "square")
                .foregroundStyle(checked || partial ? Palette.blue : .secondary).font(.system(size: 15))
        }.buttonStyle(.plain).disabled(ids.isEmpty)
            .accessibilityLabel(L("Выбрать \(title)"))
            .accessibilityValue(checked ? L("Выбрано") : partial ? L("Частично") : L("Не выбрано"))
    }
}
struct GroupedFileSelectionList: View {
    let files: [FileCandidate]
    @Binding var selection: Set<String>
    var body: some View {
        ForEach(Array(Set(files.map(\.category))).sorted(), id: \.self) { category in
            let items = files.filter { $0.category == category }
            DisclosureGroup {
                FileSelectionList(files: items, selection: $selection).padding(.top, 10)
            } label: {
                HStack {
                    GroupSelectionToggle(files: items, selection: $selection, title: L10n.translate(category))
                    Text(L10n.translate(category)).font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text((items.allSatisfy(\.complete) ? "" : "≥ ") + Fmt.bytes(items.reduce(0) { $0 + $1.bytes })).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }.padding(.vertical, 4)
        }
    }
}
struct FileSelectionList: View {
    let files: [FileCandidate]
    @Binding var selection: Set<String>
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(files) { file in
                HStack(alignment: .top, spacing: 9) {
                    Toggle(L("Выбрать \(file.title)"), isOn: Binding(get: { selection.contains(file.id) }, set: { if $0 { selection.insert(file.id) } else { selection.remove(file.id) } }))
                        .labelsHidden().toggleStyle(.checkbox).disabled(file.reviewOnly)
                    Image(nsImage: NSWorkspace.shared.icon(forFile: file.url.path)).resizable().frame(width: 20, height: 20)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(file.title).font(.system(size: 11, weight: .medium)).lineLimit(1).truncationMode(.middle)
                        Text(file.reviewOnly ? L("Только просмотр") : L10n.translate(file.category)).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 5)
                    Text((file.complete ? "" : "≥ ") + Fmt.bytes(file.bytes)).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize()
                    Button { NSWorkspace.shared.activateFileViewerSelecting([file.url]) } label: { Image(systemName: "magnifyingglass") }
                        .buttonStyle(.borderless).font(.system(size: 10)).help(L("Показать в Finder"))
                }.help(file.url.path)
            }
        }
    }
}
struct ScanProgressCard: View {
    let progress: ScanProgress
    let cancel: () -> Void
    var body: some View {
        MetricCard(title: L("Сканирование…"), icon: "magnifyingglass") {
            ProgressView(value: progress.fraction)
            HStack {
                Text(L10n.translate(progress.current)).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text("\(progress.completed) / \(progress.total)").font(.system(size: 10)).monospacedDigit()
                Button(L("Отмена"), action: cancel)
            }
        }
    }
}
struct SelectionBar: View {
    let files: [FileCandidate]
    let blocked: Bool
    let cancel: () -> Void
    let confirm: () -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(L("Выбрано: \(Fmt.bytes(files.reduce(0) { $0 + $1.bytes }))")).font(.system(size: 13, weight: .semibold))
                Text(L("\(files.count) объектов")).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(L("Отмена"), action: cancel)
            Button(L("В Корзину…"), systemImage: "trash", role: .destructive, action: confirm).disabled(blocked)
        }.padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 12).padding(.bottom, 10)
    }
}

struct ScanIssuesView: View {
    let paths: [String]
    var body: some View {
        if !paths.isEmpty {
            DisclosureGroup(L("Недоступные папки: \(paths.count)")) {
                ForEach(paths, id: \.self) { path in Text(path).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled) }
            }
        }
    }
}
