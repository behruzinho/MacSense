import SwiftUI
import MacSenseCore

struct DashboardView: View {
    @EnvironmentObject private var monitor: MonitorStore
    private var s: SystemSnapshot { monitor.snapshot }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            PageHeading(eyebrow: L("Всё под контролем"), title: L("Обзор системы"), description: L("Ваш Mac. Все важные показатели в одном месте."))
            deviceBanner
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) {
                    batteryCard
                    diskCard
                    cpuCard
                }
                VStack(spacing: 16) {
                    memoryCard
                    networkCard
                }
                VStack(spacing: 16) {
                    graphicsCard
                    coolingCard
                }
            }
        }
    }
    private var deviceBanner: some View {
        HStack(spacing: 25) {
            LaptopIllustration().frame(width: 105, height: 82)
            VStack(alignment: .leading, spacing: 7) {
                Text(monitor.hardware.modelName).font(.system(size: 21, weight: .semibold))
                Text("\(monitor.hardware.chip)  ·  \(monitor.hardware.os)").font(.system(size: 11)).foregroundStyle(.secondary)
                HStack(spacing: 7) {
                    tag(L("\(monitor.hardware.coreCount) ядер CPU"))
                    tag(Fmt.bytes(monitor.hardware.memory) + L(" памяти"))
                    tag(monitor.hardware.model)
                }.padding(.top, 5)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 7) {
                Image(systemName: s.thermalState == 0 ? "checkmark.shield" : "thermometer.medium")
                    .font(.system(size: 25, weight: .light)).foregroundStyle(s.thermalState == 0 ? Palette.green : Palette.orange)
                Text(s.thermalState == 0 ? L("Температурный режим\nв норме") : L("Повышенная\nтепловая нагрузка"))
                    .font(.system(size: 10)).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Palette.card, Palette.blue.opacity(0.07)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border))
    }
    private func tag(_ title: String) -> some View {
        Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 8).padding(.vertical, 4).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
    }
    private var batteryCard: some View {
        MetricCard(title: L("Батарея"), icon: "battery.75percent", tint: Palette.green) {
            if s.battery.present {
                HStack(alignment: .firstTextBaseline) {
                    Text(Fmt.percent(s.battery.percentage)).font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                    Spacer()
                    Image(systemName: s.battery.charging ? "bolt.fill" : "battery.75percent").font(.system(size: 24)).foregroundStyle(Palette.green)
                }
                Meter(value: s.battery.percentage, tint: Palette.green, height: 7)
                HStack {
                    Label(Fmt.percent(s.battery.health), systemImage: "heart.fill").foregroundStyle(Palette.green)
                    Spacer()
                    Text(s.battery.status).foregroundStyle(.secondary)
                }.font(.system(size: 10))
            } else {
                Text(L("Питание от сети")).font(.system(size: 18, weight: .medium))
                Text(L("Встроенная батарея не обнаружена")).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }
    private var diskCard: some View {
        MetricCard(title: L("Накопитель"), icon: "internaldrive", tint: Palette.orange) {
            if let disk = s.disks.first {
                HStack(alignment: .firstTextBaseline) {
                    Text(Fmt.bytes(disk.used)).font(.system(size: 23, weight: .semibold, design: .rounded))
                    Text("/ \(Fmt.bytes(disk.total))").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Meter(value: disk.percentage, tint: Palette.orange)
                Text(L("\(Fmt.bytes(disk.free)) свободно")).font(.system(size: 10)).foregroundStyle(.secondary)
            } else { Text(L("Чтение накопителей…")).foregroundStyle(.secondary).font(.system(size: 12)) }
        }
    }
    private var cpuCard: some View {
        MetricCard(title: L("Процессор"), icon: "cpu", tint: Palette.blue, subtitle: "CPU") {
            HStack(spacing: 16) {
                MetricRing(value: s.cpu.usage, label: L("ЗАГРУЗКА"), size: 88)
                VStack(spacing: 10) {
                    LegendRow(title: L("Система"), value: Fmt.percent(s.cpu.system), tint: Palette.pink)
                    LegendRow(title: L("Пользователь"), value: Fmt.percent(s.cpu.user), tint: Palette.blue)
                    LegendRow(title: L("Температура"), value: Fmt.temperature(s.cpuTemperature), tint: Palette.orange)
                }
            }
            Sparkline(points: monitor.cpuHistory, height: 43)
            Divider()
            ProcessList(processes: Array(s.processes.prefix(4)), metric: .cpu, compact: true)
        }
    }
    private var memoryCard: some View {
        MetricCard(title: L("Оперативная память"), icon: "memorychip", tint: Palette.purple, subtitle: "RAM") {
            HStack(spacing: 16) {
                MetricRing(value: s.memory.total > 0 ? s.memory.percentage : nil, label: L("ЗАНЯТО"), tint: Palette.purple, size: 88)
                VStack(alignment: .leading, spacing: 6) {
                    Text(Fmt.bytes(s.memory.used)).font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text(L("из \(Fmt.bytes(s.memory.total))")).font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(L("Нагрузка: ") + s.memory.pressureLabel.lowercased()).font(.system(size: 9)).foregroundStyle(s.memory.pressureNormal ? Palette.green : .secondary)
                }
            }
            VStack(spacing: 9) {
                LegendRow(title: L("Приложения"), value: Fmt.bytes(s.memory.app), tint: Palette.purple)
                LegendRow(title: L("Зарезервировано"), value: Fmt.bytes(s.memory.wired), tint: Palette.pink)
                LegendRow(title: L("Сжато"), value: Fmt.bytes(s.memory.compressed), tint: Palette.orange)
                LegendRow(title: L("Кэш файлов"), value: Fmt.bytes(s.memory.cached), tint: Palette.cyan)
            }
            Divider()
            VStack(alignment: .leading, spacing: 7) {
                DetailRow(title: L("Файл подкачки"), value: Fmt.bytes(s.memory.swapUsed))
                Meter(value: s.memory.swapTotal > 0 ? s.memory.swapUsed / s.memory.swapTotal * 100 : 0, tint: Palette.purple)
            }
            ProcessList(processes: Array(s.processes.sorted { $0.memory > $1.memory }.prefix(5)), metric: .memory, compact: true)
        }
    }
    private var networkCard: some View {
        MetricCard(title: L("Сеть"), icon: "network", tint: Palette.cyan) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Label(L("Загрузка"), systemImage: "arrow.down").font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(Fmt.rate(s.network.download)).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(Palette.cyan)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Label(L("Отправка"), systemImage: "arrow.up").font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(Fmt.rate(s.network.upload)).font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(Palette.purple)
                }
            }
            Sparkline(points: monitor.downloadHistory, tint: Palette.cyan, ceiling: nil, height: 43)
        }
    }
    private var graphicsCard: some View {
        MetricCard(title: L("Графика"), icon: "display", tint: Palette.cyan, subtitle: "GPU") {
            Text(monitor.hardware.graphics).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            HStack(spacing: 15) {
                MetricRing(value: s.gpu, label: L("ЗАГРУЗКА"), tint: Palette.cyan, size: 88)
                VStack(alignment: .leading, spacing: 9) {
                    Text(L("Температура")).font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(Fmt.temperature(s.temperatures.filter { $0.group == "Графика" }.map(\.value).max())).font(.system(size: 19, weight: .medium, design: .rounded))
                    Text(monitor.hardware.gpuCores.map { L("\($0) ядер") } ?? L("Графический процессор")).font(.system(size: 9)).foregroundStyle(.tertiary)
                }
            }
            Sparkline(points: monitor.gpuHistory, tint: Palette.cyan, height: 49)
            if s.gpu == nil { Text(L("Система не предоставляет загрузку GPU")).font(.system(size: 9)).foregroundStyle(.tertiary) }
        }
    }
    private var coolingCard: some View {
        MetricCard(title: L("Охлаждение"), icon: "fanblades", tint: Palette.green) {
            if s.fans.isEmpty {
                HStack(spacing: 13) {
                    Image(systemName: "wind").font(.system(size: 29, weight: .light)).foregroundStyle(Palette.green)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("\(s.temperatures.count) датчиков")).font(.system(size: 18, weight: .medium, design: .rounded))
                        Text(L("Вентиляторы недоступны")).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(s.fans) { fan in
                    HStack {
                        Image(systemName: "fanblades.fill").font(.system(size: 26, weight: .light)).foregroundStyle(Palette.green)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(fan.name).font(.system(size: 10)).foregroundStyle(.secondary)
                            Text("\(Int(fan.current)) RPM").font(.system(size: 19, weight: .medium, design: .rounded)).monospacedDigit()
                        }
                        Spacer()
                    }
                }
            }
            Divider()
            DetailRow(title: "CPU", value: Fmt.temperature(s.cpuTemperature))
            DetailRow(title: L("Батарея"), value: Fmt.temperature(s.battery.temperature))
            Text(L("Управление охлаждением: macOS")).font(.system(size: 9)).foregroundStyle(.tertiary)
        }
    }
}

struct LaptopIllustration: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: 0x596270)).frame(width: 94, height: 63)
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x10141B)).frame(width: 90, height: 59)
                ZStack {
                    LinearGradient(colors: [Color(hex: 0x142740), Color(hex: 0x385E94), Color(hex: 0x72AEAA)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "waveform.path.ecg").font(.system(size: 30, weight: .ultraLight)).foregroundStyle(.white.opacity(0.65))
                }.frame(width: 84, height: 52).clipShape(RoundedRectangle(cornerRadius: 2))
            }
            RoundedRectangle(cornerRadius: 2).fill(LinearGradient(colors: [Color(hex: 0x8D97A3), Color(hex: 0x4B5562)], startPoint: .top, endPoint: .bottom)).frame(width: 109, height: 5)
            Ellipse().fill(.black.opacity(0.18)).frame(width: 100, height: 5).blur(radius: 3).padding(.top, 3)
        }.accessibilityHidden(true)
    }
}

struct ProcessList: View {
    enum Metric { case cpu, memory }
    let processes: [ProcessReading]
    var metric: Metric = .cpu
    var compact = false
    var body: some View {
        VStack(spacing: compact ? 8 : 14) {
            if processes.isEmpty { Text(L("Получение списка процессов…")).font(.system(size: 11)).foregroundStyle(.tertiary) }
            ForEach(processes) { process in
                HStack(spacing: 8) {
                    Image(systemName: "app.fill").font(.system(size: compact ? 11 : 15)).foregroundStyle(Palette.blue.opacity(0.65))
                    Text(process.name).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(metric == .cpu ? String(format: "%.1f%%", locale: L10n.locale, process.cpu) : Fmt.bytes(process.memory)).monospacedDigit()
                }.font(.system(size: compact ? 10 : 12))
            }
        }
    }
}
