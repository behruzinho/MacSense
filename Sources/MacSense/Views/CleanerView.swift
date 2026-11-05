import SwiftUI
import MacSenseCore

struct CleanerView: View {
    @State private var files: [FileCandidate] = []
    @State private var selected: Set<String> = []
    @State private var scanning = false
    @State private var scanned = false
    @State private var deleting = false
    @State private var confirmTrash = false
    @State private var message: String?
    private let service = UtilityService()
    private var chosen: [FileCandidate] { files.filter { selected.contains($0.id) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Утилиты / Пространство"), title: L("Очистка"), description: L("Найдите пользовательский кэш и журналы, которые занимают место."))
            MetricCard(title: L("Анализ файлов"), icon: "sparkles", tint: Palette.orange) {
                HStack(spacing: 25) {
                    Image(systemName: "externaldrive.badge.magnifyingglass").font(.system(size: 52, weight: .ultraLight)).foregroundStyle(Palette.orange)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(scanning ? L("Сканирование…") : scanned ? Fmt.bytes(files.map(\.bytes).reduce(0, +)) : L("Освободите место на Mac"))
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                        Text(scanned ? L("найдено в доступных папках кэша и журналов") : L("Просмотрите файлы и выберите, что переместить в Корзину."))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if scanning { ProgressView().controlSize(.small) }
                    else { Button(scanned ? L("Сканировать снова") : L("Сканировать")) { Task { await scan() } }.buttonStyle(.borderedProminent).disabled(deleting) }
                }.padding(.vertical, 14)
            }
            if scanned && !scanning {
                if files.isEmpty { EmptyState(icon: "checkmark.circle", title: L("Доступных файлов не найдено"), text: L("Папки могут быть пустыми или закрытыми для чтения. macOS ограничивает доступ к некоторым данным.")) }
                else {
                    HStack {
                        Text(L("\(files.count) объектов")).font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text(L("Выбрано: \(Fmt.bytes(chosen.map(\.bytes).reduce(0, +)))")).font(.system(size: 12)).foregroundStyle(.secondary)
                        Button(L("В Корзину…"), systemImage: "trash", role: .destructive) { confirmTrash = true }.disabled(chosen.isEmpty || deleting)
                    }
                    ForEach(["Кэш", "Журналы"], id: \.self) { category in
                        let items = files.filter { $0.category == category }
                        if !items.isEmpty {
                            MetricCard(title: category, icon: category == "Кэш" ? "archivebox" : "doc.text", tint: Palette.orange, subtitle: L("\(items.count) объектов")) {
                                FileSelectionList(files: items, selection: $selected)
                            }
                        }
                    }
                }
            }
            InfoNote(text: L("Проверяются только ~/Library/Caches и ~/Library/Logs. Закройте соответствующие приложения перед очисткой. Доступные размеры могут быть неполными и отмечаются символом ≥. Файлы останутся в Корзине до её очистки."))
        }
        .confirmationDialog(L("Переместить выбранные файлы в Корзину?"), isPresented: $confirmTrash, titleVisibility: .visible) {
            Button(L("Переместить \(chosen.count) объектов"), role: .destructive) { Task { await trash() } }
        } message: { Text(L("Общий размер: \(Fmt.bytes(chosen.map(\.bytes).reduce(0, +))). Кэш некоторых приложений будет создан заново при следующем запуске.")) }
        .alert(L("Результат очистки"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }
    private func scan() async {
        guard !scanning else { return }; scanning = true; selected = []
        files = await service.cleanerFiles(); scanning = false; scanned = true
    }
    private func trash() async {
        guard !deleting else { return }; deleting = true
        let result = await service.trash(chosen)
        files.removeAll { result.removed.contains($0.id) }; selected.subtract(result.removed); deleting = false
        message = L("Перемещено в Корзину: \(result.removed.count). Место освободится после очистки Корзины.") + (result.failures.isEmpty ? "" : "\n\n" + result.failures.joined(separator: "\n"))
    }
}
