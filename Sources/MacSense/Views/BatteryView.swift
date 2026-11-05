import SwiftUI
import MacSenseCore

struct BatteryView: View {
    @EnvironmentObject private var monitor: MonitorStore
    var body: some View {
        let battery = monitor.snapshot.battery
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Оборудование / Питание"), title: L("Батарея"), description: L("Уровень заряда, состояние аккумулятора и параметры питания."))
            if battery.present {
                HStack(alignment: .top, spacing: 16) {
                    MetricCard(title: L("Текущий заряд"), icon: "battery.75percent", tint: Palette.green) {
                        HStack(spacing: 35) {
                            MetricRing(value: battery.percentage, label: L("ЗАРЯД"), tint: Palette.green, size: 150)
                            VStack(alignment: .leading, spacing: 15) {
                                Label(battery.status, systemImage: battery.charging ? "bolt.fill" : "battery.75percent").font(.system(size: 15, weight: .medium))
                                if let minutes = battery.minutes {
                                    Text(L("\(minutes / 60) ч \(minutes % 60) мин \(battery.charging ? L("до полного заряда") : L("до разряда"))")).font(.system(size: 12)).foregroundStyle(.secondary)
                                } else { Text(L("Оценка оставшегося времени недоступна")).font(.system(size: 11)).foregroundStyle(.secondary) }
                                Text(L("Источник питания: \(battery.external ? L("адаптер") : L("аккумулятор"))")).font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                        }
                        Sparkline(points: monitor.batteryHistory, tint: Palette.green, height: 75)
                    }
                    MetricCard(title: L("Состояние аккумулятора"), icon: "heart", tint: Palette.pink) {
                        Text(Fmt.percent(battery.health)).font(.system(size: 42, weight: .semibold, design: .rounded)).foregroundStyle(Palette.green)
                        Text(L("от проектной ёмкости")).font(.system(size: 12)).foregroundStyle(.secondary)
                        Divider()
                        DetailRow(title: L("Циклы зарядки"), value: "\(battery.cycles)")
                        DetailRow(title: L("Температура"), value: Fmt.temperature(battery.temperature))
                    }.frame(width: 290)
                }
                MetricCard(title: L("Электрические параметры"), icon: "bolt.circle", tint: Palette.orange) {
                    DetailRow(title: L("Текущая ёмкость"), value: battery.currentCapacity > 100 ? L("\(battery.currentCapacity) мА·ч") : "—")
                    DetailRow(title: L("Полная ёмкость"), value: battery.maxCapacity > 100 ? L("\(battery.maxCapacity) мА·ч") : "—")
                    DetailRow(title: L("Проектная ёмкость"), value: battery.designCapacity > 100 ? L("\(battery.designCapacity) мА·ч") : "—")
                    DetailRow(title: L("Напряжение"), value: battery.voltage.map { String(format: L("%.2f В"), locale: L10n.locale, $0) } ?? "—")
                    DetailRow(title: L("Сила тока"), value: battery.amperage.map { String(format: L("%.0f мА"), locale: L10n.locale, $0) } ?? "—")
                    DetailRow(title: L("Мощность батареи"), value: powerText)
                }
                InfoNote(text: L("Здоровье аккумулятора рассчитано по полной и проектной ёмкости из IOKit. Оно может немного отличаться от оценки macOS. Положительный ток означает заряд, отрицательный — разряд."))
            } else {
                MetricCard(title: L("Питание"), icon: "powerplug", tint: Palette.green) {
                    EmptyState(icon: "powerplug", title: L("Mac работает от сети"), text: L("Встроенный аккумулятор не обнаружен. На настольных Mac этот раздел не содержит показателей батареи."))
                }
            }
        }
    }
    private var powerText: String {
        let b = monitor.snapshot.battery
        guard let v = b.voltage, let a = b.amperage else { return "—" }
        return String(format: L("%.1f Вт"), locale: L10n.locale, abs(v * a / 1000))
    }
}
