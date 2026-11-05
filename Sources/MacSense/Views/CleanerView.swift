import SwiftUI
import MacSenseCore

struct CleanerView: View {
    @State private var files: [FileCandidate] = []
    @State private var selected: Set<String> = []
    @State private var category: String?
    @State private var scanning = false
    @State private var scanned = false
    @State private var progress = ScanProgress(completed: 0, total: 0, current: "")
    @State private var scanTask: Task<Void, Never>?
    @State private var deleting = false
    @State private var confirmTrash = false
    @State private var message: String?
    private let service = UtilityService()
    private var chosen: [FileCandidate] { UtilityPolicy.independentFiles(files.filter { selected.contains($0.id) }) }
    private var categories: [String] { Array(Set(files.map(\.category))).sorted { total($0) > total($1) } }
    private func total(_ key: String) -> Double { files.filter { $0.category == key }.reduce(0) { $0 + $1.bytes } }
    private func categorySize(_ key: String) -> String {
        let prefix = files.filter { $0.category == key }.allSatisfy { $0.complete } ? "" : "≥ "
        return prefix + Fmt.bytes(total(key))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Утилиты / Пространство"), title: L("Очистка"), description: L("Кэш, данные разработчика, загрузки и другие категории для просмотра."))
            MetricCard(title: L("Анализ файлов"), icon: "sparkles", tint: Palette.orange) {
                HStack(spacing: 25) {
                    Image(systemName: "externaldrive.badge.magnifyingglass").font(.system(size: 45, weight: .ultraLight)).foregroundStyle(Palette.orange)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(scanned ? Fmt.bytes(files.reduce(0) { $0 + $1.bytes }) : L("Освободите место на Mac")).font(.system(size: 28, weight: .semibold, design: .rounded))
                        Text(L("Просмотрите файлы и выберите, что переместить в Корзину.")).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(scanned ? L("Сканировать снова") : L("Сканировать"), action: startScan).buttonStyle(.borderedProminent).disabled(scanning || deleting)
                }.padding(.vertical, 14)
            }
            if scanning { ScanProgressCard(progress: progress) { scanTask?.cancel() } }
            else if scanned {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 4) {
                        ForEach(categories, id: \.self) { key in
                            let items = files.filter { $0.category == key }
                            HStack(spacing: 9) {
                                GroupSelectionToggle(files: items, selection: $selected, title: L10n.translate(key))
                                Button { category = key } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(L10n.translate(key)).font(.system(size: 12, weight: .medium))
                                        HStack {
                                            Text(L("\(items.count) объектов"))
                                            Spacer()
                                            Text(categorySize(key))
                                        }.font(.system(size: 9)).foregroundStyle(.secondary)
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }.padding(12).background(category == key ? Palette.orange.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }.padding(6).frame(width: 260).background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
                    MetricCard(title: category.map { L10n.translate($0) } ?? L("Выберите категорию"), icon: "folder", tint: Palette.orange) {
                        if let category {
                            if ["Загрузки", "Крупные файлы", "Архивы Xcode", "Вложения почты"].contains(category) {
                                InfoNote(text: L("Здесь могут быть личные файлы и архивы сборок. Они не являются мусором: выбирайте только ненужные объекты."))
                            }
                            FileSelectionList(files: files.filter { $0.category == category }, selection: $selected)
                        } else { Text(L("Доступных файлов не найдено")).foregroundStyle(.secondary) }
                    }
                }
            }
            InfoNote(text: L("Размеры с ≥ неполные, в том числе при ограничениях доступа macOS. Крупные файлы от 500 МБ ищутся в Загрузках. Симуляторы и системные журналы доступны только для просмотра. Закройте Xcode и соответствующие приложения перед очисткой."))
        }
        .safeAreaInset(edge: .bottom) { if !chosen.isEmpty && !scanning { SelectionBar(files: chosen, blocked: deleting, cancel: { selected = [] }, confirm: { confirmTrash = true }) } }
        .onDisappear { scanTask?.cancel() }
        .confirmationDialog(L("Переместить выбранные файлы в Корзину?"), isPresented: $confirmTrash, titleVisibility: .visible) {
            Button(L("Переместить \(chosen.count) объектов"), role: .destructive) { Task { await trash() } }
        } message: { Text(L("Общий размер: \(Fmt.bytes(chosen.reduce(0) { $0 + $1.bytes })). Выбранные данные и настройки также будут перемещены в Корзину.")) }
        .alert(L("Результат очистки"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }
    private func startScan() {
        guard !scanning else { return }; scanning = true
        scanTask = Task {
            let result = await service.cleanerFiles { value in await MainActor.run { progress = value } }
            if !Task.isCancelled { files = result; selected = []; scanned = true; category = categories.first }
            scanning = false
        }
    }
    private func trash() async {
        guard !deleting else { return }; deleting = true
        let result = await service.trash(chosen)
        files.removeAll { result.removed.contains($0.id) }; selected.subtract(result.removed); deleting = false
        message = L("Перемещено в Корзину: \(result.removed.count). Место освободится после очистки Корзины.") + (result.failures.isEmpty ? "" : "\n\n" + result.failures.joined(separator: "\n"))
    }
}
