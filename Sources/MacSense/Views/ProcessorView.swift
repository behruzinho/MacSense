import SwiftUI
import MacSenseCore

struct ProcessorView: View {
    @EnvironmentObject private var monitor: MonitorStore
    @State private var processSort = "cpu"
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Оборудование / CPU"), title: L("Процессор"), description: L("Загрузка каждого ядра и приложения, использующие процессор."))
            HStack(alignment: .top, spacing: 16) {
                MetricCard(title: monitor.hardware.chip, icon: "cpu") {
                    HStack(spacing: 35) {
                        MetricRing(value: monitor.snapshot.cpu.usage, label: L("ЗАГРУЗКА"), size: 145)
                        VStack(spacing: 15) {
                            DetailRow(title: L("Пользователь"), value: Fmt.percent(monitor.snapshot.cpu.user))
                            DetailRow(title: L("Система"), value: Fmt.percent(monitor.snapshot.cpu.system))
                            DetailRow(title: L("Логических ядер"), value: "\(monitor.hardware.coreCount)")
                            DetailRow(title: L("Температура датчиков CPU"), value: Fmt.temperature(monitor.snapshot.cpuTemperature))
                        }
                    }
                    Sparkline(points: monitor.cpuHistory, height: 100)
                    Text(L("История последних \(monitor.cpuHistory.count) измерений")).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                MetricCard(title: L("Характеристики"), icon: "info.circle", tint: Palette.cyan) {
                    DetailRow(title: L("Архитектура"), value: monitor.hardware.architecture)
                    DetailRow(title: L("Производительные ядра"), value: monitor.hardware.performanceCores > 0 ? "\(monitor.hardware.performanceCores)" : "—")
                    DetailRow(title: L("Энергоэффективные ядра"), value: monitor.hardware.efficiencyCores > 0 ? "\(monitor.hardware.efficiencyCores)" : "—")
                    DetailRow(title: L("Время работы"), value: Fmt.duration(monitor.snapshot.uptime))
                    DetailRow(title: L("Тепловое состояние"), value: [L("Нормальное"), L("Умеренное"), L("Высокое"), L("Критическое")][min(3, monitor.snapshot.thermalState)], tint: monitor.snapshot.thermalState == 0 ? Palette.green : Palette.orange)
                }.frame(width: 290)
            }
            MetricCard(title: L("Загрузка по ядрам"), icon: "square.grid.3x3", subtitle: L("0–100% на ядро")) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 20) {
                    ForEach(Array(monitor.snapshot.cpu.cores.enumerated()), id: \.offset) { index, value in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text(L("Ядро \(index + 1)")).foregroundStyle(.secondary); Spacer(); Text(Fmt.percent(value)) }
                                .font(.system(size: 10)).monospacedDigit()
                            Meter(value: value, tint: value > 80 ? Palette.orange : Palette.blue, height: 5)
                        }
                    }
                }
            }
            MetricCard(title: L("Активные процессы"), icon: "list.bullet.rectangle") {
                Picker(L("Сортировка"), selection: $processSort) { Text(L("По CPU")).tag("cpu"); Text(L("По памяти")).tag("memory") }.pickerStyle(.segmented).frame(width: 230)
                ProcessList(processes: Array(monitor.snapshot.processes.sorted { processSort == "cpu" ? $0.cpu > $1.cpu : $0.memory > $1.memory }.prefix(15)), metric: processSort == "cpu" ? .cpu : .memory)
                Text(L("Процесс может использовать более 100% CPU, если работает на нескольких ядрах. Список обновляется каждые четыре измерения."))
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
    }
}

struct MemoryView: View {
    @EnvironmentObject private var monitor: MonitorStore
    var body: some View {
        let memory = monitor.snapshot.memory
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Оборудование / RAM"), title: L("Оперативная память"), description: L("Использование физической памяти, сжатие и файл подкачки."))
            HStack(alignment: .top, spacing: 16) {
                MetricCard(title: L("Использование памяти"), icon: "memorychip", tint: Palette.purple) {
                    HStack(spacing: 35) {
                        MetricRing(value: memory.total > 0 ? memory.percentage : nil, label: L("ЗАНЯТО"), tint: Palette.purple, size: 145)
                        VStack(spacing: 14) {
                            DetailRow(title: L("Физическая память"), value: Fmt.bytes(memory.total))
                            DetailRow(title: L("Используется"), value: Fmt.bytes(memory.used))
                            DetailRow(title: L("Доступно"), value: Fmt.bytes(max(0, memory.total - memory.used)))
                            DetailRow(title: L("Нагрузка"), value: memory.pressureLabel, tint: memory.pressureNormal ? Palette.green : nil)
                        }
                    }
                    Sparkline(points: monitor.memoryHistory, tint: Palette.purple, height: 120)
                }
                MetricCard(title: L("Распределение"), icon: "chart.pie", tint: Palette.purple) {
                    LegendRow(title: L("Приложения"), value: Fmt.bytes(memory.app), tint: Palette.purple)
                    LegendRow(title: L("Зарезервировано"), value: Fmt.bytes(memory.wired), tint: Palette.pink)
                    LegendRow(title: L("Сжатая память"), value: Fmt.bytes(memory.compressed), tint: Palette.orange)
                    LegendRow(title: L("Кэш файлов"), value: Fmt.bytes(memory.cached), tint: Palette.cyan)
                    Divider()
                    DetailRow(title: L("Подкачка занята"), value: Fmt.bytes(memory.swapUsed))
                    DetailRow(title: L("Подкачка выделена"), value: Fmt.bytes(memory.swapTotal))
                }.frame(width: 290)
            }
            InfoNote(text: L("macOS использует свободную память для кэширования файлов и освобождает её при необходимости. Нагрузка на память информативнее самого процента занятости."))
            MetricCard(title: L("Процессы по использованию памяти"), icon: "list.bullet.rectangle", tint: Palette.purple) {
                ProcessList(processes: Array(monitor.snapshot.processes.sorted { $0.memory > $1.memory }.prefix(20)), metric: .memory)
            }
        }
    }
}
