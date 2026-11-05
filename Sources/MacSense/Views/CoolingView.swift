import SwiftUI
import MacSenseCore

struct CoolingView: View {
    @EnvironmentObject private var monitor: MonitorStore
    @State private var query = ""
    private var groups: [String] { Array(Set(monitor.snapshot.temperatures.map(\.group))).sorted() }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Оборудование / Температура"), title: L("Охлаждение"), description: L("Обороты вентиляторов и доступные температурные датчики вашего Mac."))
            if !monitor.snapshot.fans.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 310))], spacing: 16) {
                    ForEach(monitor.snapshot.fans) { fan in
                        MetricCard(title: fan.name, icon: "fanblades", tint: Palette.cyan, subtitle: L("АВТО · macOS")) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(Int(fan.current))").font(.system(size: 38, weight: .semibold, design: .rounded)).monospacedDigit()
                                    Text(L("оборотов в минуту")).font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "fanblades.fill").font(.system(size: 62, weight: .ultraLight)).foregroundStyle(Palette.cyan.opacity(0.6))
                            }
                            Sparkline(points: monitor.fanHistory[fan.id] ?? [], tint: Palette.cyan, ceiling: fan.maximum, height: 66)
                            HStack {
                                Text(L("Мин. \(fan.minimum.map { String(Int($0)) } ?? "—")"))
                                Spacer()
                                Text(L("Макс. \(fan.maximum.map { String(Int($0)) } ?? "—") RPM"))
                            }.font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                InfoNote(text: L("SMC не предоставил данные вентиляторов. На Mac с пассивным охлаждением вентиляторов нет; на других моделях доступ может быть ограничен системой."), icon: "fanblades")
            }
            HStack {
                Text(L("Температурные датчики")).font(.system(size: 18, weight: .semibold))
                Text("\(monitor.snapshot.temperatures.count)").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).padding(6).background(Palette.card, in: Capsule())
                Spacer()
                TextField(L("Поиск датчика…"), text: $query).textFieldStyle(.roundedBorder).frame(width: 200)
            }.padding(.top, 8)
            if monitor.snapshot.temperatures.isEmpty {
                MetricCard(title: L("Доступ к датчикам"), icon: "thermometer.medium", tint: Palette.orange) {
                    EmptyState(icon: "thermometer.medium", title: L("Датчики SMC недоступны"), text: L("Этот Mac или текущая среда не предоставляют температурные значения через AppleSMC. Загрузка CPU, память и батарея продолжают отслеживаться."))
                    DetailRow(title: L("Тепловое состояние macOS"), value: [L("Нормальное"), L("Умеренное"), L("Высокое"), L("Критическое")][min(3, monitor.snapshot.thermalState)])
                    if let temperature = monitor.snapshot.battery.temperature { DetailRow(title: L("Температура батареи · IOKit"), value: Fmt.temperature(temperature)) }
                }
            } else {
                ForEach(groups, id: \.self) { group in
                    let sensors = monitor.snapshot.temperatures.filter { $0.group == group && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.key.localizedCaseInsensitiveContains(query)) }
                    if !sensors.isEmpty {
                        MetricCard(title: group, icon: "thermometer.medium", tint: group == "Процессор" ? Palette.green : Palette.blue) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: 22) {
                                ForEach(sensors) { sensor in
                                    VStack(alignment: .leading, spacing: 9) {
                                        HStack {
                                            Text(sensor.name).font(.system(size: 11)).foregroundStyle(.secondary)
                                            Spacer()
                                            Text(Fmt.temperature(sensor.value)).font(.system(size: 13, weight: .semibold, design: .rounded))
                                        }
                                        Sparkline(points: monitor.temperatureHistory[sensor.id] ?? [], tint: sensor.value > 85 ? Palette.orange : group == "Процессор" ? Palette.green : Palette.blue, ceiling: 110, height: 42)
                                        Text(sensor.key).font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            InfoNote(text: L("Охлаждением управляет macOS. Названия неизвестных датчиков отображаются вместе с исходным SMC-ключом; их расположение может различаться между моделями Mac."))
        }
    }
}
