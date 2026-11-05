import SwiftUI
import MacSenseCore

struct StorageView: View {
    @EnvironmentObject private var monitor: MonitorStore
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Оборудование / Диски"), title: L("Накопители"), description: L("Занятое пространство и информация о подключённых томах."))
            ForEach(monitor.snapshot.disks) { disk in
                MetricCard(title: disk.name, icon: "internaldrive", tint: Palette.orange, subtitle: disk.filesystem) {
                    HStack(spacing: 35) {
                        MetricRing(value: disk.percentage, label: L("ЗАНЯТО"), tint: Palette.orange, size: 135)
                        VStack(spacing: 14) {
                            DetailRow(title: L("Объём тома"), value: Fmt.bytes(disk.total))
                            DetailRow(title: L("Используется"), value: Fmt.bytes(disk.used))
                            DetailRow(title: L("Свободно"), value: Fmt.bytes(disk.free), tint: Palette.green)
                            Meter(value: disk.percentage, tint: Palette.orange, height: 9)
                        }
                    }
                    HStack {
                        Text(disk.id).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                        Spacer()
                        Button(L("Открыть в Finder")) { NSWorkspace.shared.open(URL(fileURLWithPath: disk.id)) }.controlSize(.small)
                    }
                }
            }
            MetricCard(title: L("Встроенный накопитель"), icon: "externaldrive.badge.checkmark", tint: Palette.green) {
                DetailRow(title: L("Модель"), value: monitor.hardware.diskModel ?? L("Не предоставлена системой"))
                DetailRow(title: "S.M.A.R.T.", value: smartText, tint: monitor.hardware.smart?.lowercased().contains("verified") == true ? Palette.green : nil)
                DetailRow(title: "TRIM", value: monitor.hardware.trim.map { $0 ? L("Поддерживается") : L("Не поддерживается") } ?? L("Не предоставлен системой"))
            }
            InfoNote(text: L("Тома APFS могут совместно использовать один контейнер. Свободное место показано без учёта пространства, которое macOS может дополнительно освободить из кэша и снимков."))
            Button(L("Открыть Дисковую утилиту"), systemImage: "externaldrive") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Disk Utility.app")) }
        }
    }
    private var smartText: String {
        guard let smart = monitor.hardware.smart else { return L("Недоступен") }
        return smart.lowercased().contains("verified") ? L("Проверен") : smart
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
