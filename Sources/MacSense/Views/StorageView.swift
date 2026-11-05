import SwiftUI
import MacSenseCore

struct StorageView: View {
    @EnvironmentObject private var monitor: MonitorStore
    @State private var devices: [StorageDevice] = []
    @State private var selected: String?
    @State private var section = "info"
    @State private var scanning = false
    @State private var health: NVMeHealth?
    @State private var readingHealth = false
    private let service = StorageService()
    private var current: StorageDevice? { devices.first { $0.id == selected } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Оборудование / Диски"), title: L("Накопители"), description: L("Физические диски, APFS, состояние и производительность."))
            HStack {
                Picker(L("Накопитель"), selection: $selected) {
                    ForEach(devices) { Text("\($0.name) · \($0.id)").tag(Optional($0.id)) }
                }.frame(maxWidth: 480)
                Spacer()
                Button(L("Обновить список"), systemImage: "arrow.clockwise") { Task { await scan() } }.disabled(scanning)
            }
            if scanning { ProgressView(L("Чтение накопителей…")) }
            if let disk = current {
                MetricCard(title: disk.name, icon: "internaldrive", tint: Palette.orange, subtitle: disk.id) {
                    HStack {
                        Text(Fmt.bytes(disk.bytes)).font(.system(size: 30, weight: .semibold, design: .rounded))
                        Spacer()
                        Text(disk.bus ?? "—").foregroundStyle(.secondary)
                    }
                }
                Picker(L("Раздел"), selection: $section) {
                    Text(L("Информация")).tag("info")
                    Text(L("Состояние")).tag("health")
                    Text(L("Статистика")).tag("stats")
                    Text(L("Тест скорости")).tag("benchmark")
                }.pickerStyle(.segmented)
                switch section {
                case "health": healthPanel(disk)
                case "stats": statistics(disk)
                case "benchmark": BenchmarkView()
                default: information(disk)
                }
            }
            DisclosureGroup(L("Подключённые тома")) {
                ForEach(monitor.snapshot.disks) { disk in
                    MetricCard(title: disk.name, icon: "externaldrive", tint: Palette.orange, subtitle: disk.filesystem) {
                        DetailRow(title: L("Объём тома"), value: Fmt.bytes(disk.total))
                        Meter(value: disk.percentage, tint: Palette.orange)
                        DetailRow(title: L("Свободно"), value: Fmt.bytes(disk.free), tint: Palette.green)
                        Button(L("Открыть в Finder")) { NSWorkspace.shared.open(URL(fileURLWithPath: disk.id)) }.controlSize(.small)
                    }
                }
            }
            InfoNote(text: L("Тома APFS могут совместно использовать один контейнер. Свободное место показано без учёта пространства, которое macOS может дополнительно освободить из кэша и снимков."))
            Button(L("Открыть Дисковую утилиту"), systemImage: "externaldrive") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Disk Utility.app")) }
        }.task { await scan() }
        .task(id: selected) {
            health = nil
            guard let id = selected else { return }; readingHealth = true
            let value = await service.health(disk: id)
            if selected == id { health = value; readingHealth = false }
        }
    }
    private func scan() async {
        guard !scanning else { return }; scanning = true
        devices = await service.inventory(); scanning = false
        if !devices.contains(where: { $0.id == selected }) { selected = devices.first?.id }
    }
    private func information(_ disk: StorageDevice) -> some View {
        VStack(spacing: 16) {
            MetricCard(title: L("Информация"), icon: "info.circle", tint: Palette.orange) {
                DetailRow(title: L("Интерфейс"), value: disk.bus ?? "—")
                DetailRow(title: L("Расположение"), value: disk.internalDevice.map { $0 ? L("Встроенный") : L("Внешний") } ?? "—")
                DetailRow(title: L("Тип"), value: disk.solidState.map { $0 ? "SSD" : "HDD" } ?? "—")
                DetailRow(title: L("Размер блока"), value: disk.blockSize.map { "\($0) B" } ?? "—")
                DetailRow(title: L("Съёмный"), value: yesNo(disk.removable))
                DetailRow(title: L("Запись разрешена"), value: yesNo(disk.writable))
                DetailRow(title: "S.M.A.R.T.", value: disk.smart ?? "—")
            }
            MetricCard(title: L("Разделы и контейнеры APFS"), icon: "square.stack.3d.up", tint: Palette.purple) {
                OutlineGroup(disk.contents, children: \.outlineChildren) { node in
                    HStack {
                        Image(systemName: node.children.isEmpty ? "internaldrive" : "folder").foregroundStyle(Palette.purple)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(node.name).font(.system(size: 12, weight: .medium))
                            Text("\(L10n.translate(node.kind)) · \(node.id)").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(Fmt.bytes(node.bytes)).font(.system(size: 11))
                            if let free = node.free { Text(L("\(Fmt.bytes(free)) свободно")).font(.system(size: 9)).foregroundStyle(.secondary) }
                        }
                    }.padding(.vertical, 7)
                }
                Text(L("Размер тома APFS — занятые данные; размер контейнера — общая ёмкость. Эти значения не складываются.")).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }
    private func healthPanel(_ disk: StorageDevice) -> some View {
        VStack(spacing: 16) {
            MetricCard(title: L("Состояние накопителя"), icon: "heart", tint: Palette.pink) {
                DetailRow(title: "S.M.A.R.T. · macOS", value: disk.smart ?? L("Недоступен"))
                if readingHealth { ProgressView() }
                else if let health {
                    DetailRow(title: L("Оценка оставшегося ресурса"), value: Fmt.percent(health.estimatedRemaining))
                    DetailRow(title: L("Температура"), value: Fmt.temperature(health.temperature))
                    DetailRow(title: L("Проверка SMART"), value: health.passed.map { $0 ? L("Пройдена") : L("Есть предупреждения") } ?? "—")
                    Divider()
                    ForEach(health.attributes) { attribute in
                        DetailRow(title: L10n.translate(attribute.title), value: attribute.unit == "bytes" ? Fmt.bytes(attribute.value) : attribute.unit == "°C" ? Fmt.temperature(attribute.value) : "\(attribute.value.formatted(.number.locale(L10n.locale))) \(attribute.unit)")
                    }
                    Text(L("Источник: установленный smartctl. Ресурс рассчитан как 100 − Percentage Used и не является гарантией срока службы.")).font(.system(size: 10)).foregroundStyle(.secondary)
                } else {
                    InfoNote(text: L("Подробные NVMe SMART доступны через установленный smartctl при разрешённом чтении устройства. Встроенный источник macOS сообщает только общий статус. Отсутствующие значения не заменяются нулями."))
                }
            }
        }
    }
    private func statistics(_ disk: StorageDevice) -> some View {
        let io = monitor.snapshot.diskIO.first { $0.id == disk.id }
        return MetricCard(title: L("Ввод-вывод"), icon: "chart.xyaxis.line", tint: Palette.blue) {
            DetailRow(title: L("Чтение"), value: Fmt.rate(io?.readRate))
            Sparkline(points: monitor.diskReadHistory[disk.id] ?? [], tint: Palette.blue, ceiling: nil, height: 100)
            DetailRow(title: L("Запись"), value: Fmt.rate(io?.writeRate))
            Sparkline(points: monitor.diskWriteHistory[disk.id] ?? [], tint: Palette.purple, ceiling: nil, height: 100)
            DetailRow(title: L("Прочитано с подключения"), value: io.map { Fmt.bytes($0.read) } ?? "—")
            DetailRow(title: L("Записано с подключения"), value: io.map { Fmt.bytes($0.written) } ?? "—")
            Text(L("Счётчики IOBlockStorageDriver относятся к текущему подключению устройства, а не ко всему сроку службы SSD.")).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
    private func yesNo(_ value: Bool?) -> String { value.map { $0 ? L("Да") : L("Нет") } ?? "—" }
}

struct BenchmarkView: View {
    @State private var folder = FileManager.default.temporaryDirectory
    @State private var size = 256
    @State private var running = false
    @State private var task: Task<Void, Never>?
    @State private var progress = 0.0
    @State private var stage = ""
    @State private var result: BenchmarkResult?
    @State private var message: String?
    private let service = DiskBenchmark()
    var body: some View {
        MetricCard(title: L("Тест скорости"), icon: "speedometer", tint: Palette.orange) {
            Text(L("Тестируется диск выбранной папки. Записывается и читается один временный файл; кэш файлов отключён. Файл удаляется после завершения или отмены.")).font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Text(folder.path).font(.system(size: 10, design: .monospaced)).lineLimit(2).textSelection(.enabled)
                Spacer()
                Button(L("Выбрать папку…"), action: chooseFolder).disabled(running)
            }
            Picker(L("Размер теста"), selection: $size) { ForEach([64, 256, 1024], id: \.self) { Text("\($0) MB").tag($0) } }.disabled(running)
            if running {
                ProgressView(L10n.translate(stage), value: progress)
                Button(L("Отмена")) { task?.cancel() }
            } else { Button(L("Начать тест"), systemImage: "play.fill", action: start).buttonStyle(.borderedProminent) }
            if let result {
                DetailRow(title: L("Чтение"), value: Fmt.rate(result.readBytesPerSecond), tint: Palette.blue)
                DetailRow(title: L("Запись"), value: Fmt.rate(result.writeBytesPerSecond), tint: Palette.purple)
            }
            if let message { Text(message).font(.system(size: 11)).foregroundStyle(.secondary) }
        }.onDisappear { task?.cancel() }
    }
    private func chooseFolder() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { folder = url; result = nil }
    }
    private func start() {
        guard !running else { return }; running = true; progress = 0; result = nil; message = nil
        let target = folder, megabytes = size
        task = Task {
            do {
                result = try await service.run(at: target, megabytes: megabytes) { value in
                    await MainActor.run { progress = value.fraction; stage = value.stage }
                }
            } catch is CancellationError { message = L("Тест отменён. Временный файл удалён.") }
            catch { message = error.localizedDescription }
            running = false
        }
    }
}

struct TrimView: View {
    @EnvironmentObject private var monitor: MonitorStore
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Утилиты / SSD"), title: L("Поддержка TRIM"), description: L("Информация о команде освобождения блоков твердотельного накопителя."))
            MetricCard(title: L("Встроенный SSD"), icon: "square.grid.3x3", tint: Palette.green) {
                HStack(spacing: 24) {
                    Image(systemName: "internaldrive").font(.system(size: 58, weight: .ultraLight)).foregroundStyle(Palette.green)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(monitor.hardware.diskModel ?? L("Накопитель Mac")).font(.system(size: 21, weight: .semibold))
                        Text(monitor.hardware.trim.map { $0 ? L("TRIM поддерживается") : L("Поддержка TRIM не обнаружена") } ?? L("Система не предоставила статус TRIM"))
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 15)
            }
            InfoNote(text: L("TRIM сообщает SSD, какие блоки больше не используются. Статус читается из системного отчёта NVMe. В этой версии приложение показывает доступную информацию и не изменяет конфигурацию драйверов."))
        }
    }
}
