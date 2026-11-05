import SwiftUI
import MacSenseCore

struct SensitiveValue: View {
    let title: String
    let value: String?
    @State private var revealed = false
    var body: some View {
        HStack {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Text(value.map { revealed ? $0 : "••••••••" } ?? "—").font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
            if value != nil {
                Button { revealed.toggle() } label: { Image(systemName: revealed ? "eye.slash" : "eye") }.buttonStyle(.borderless)
                    .help(revealed ? L("Скрыть номер") : L("Показать номер"))
            }
        }
    }
}
struct HardwareInformationView: View {
    @EnvironmentObject private var monitor: MonitorStore
    var body: some View {
        MetricCard(title: L("Об этом Mac"), icon: "laptopcomputer") {
            DetailRow(title: L("Имя компьютера"), value: monitor.hardware.computerName ?? "—")
            DetailRow(title: L("Модель"), value: monitor.hardware.modelName)
            DetailRow(title: L("Идентификатор модели"), value: monitor.hardware.model)
            DetailRow(title: L("Система"), value: monitor.hardware.os)
            SensitiveValue(title: L("Серийный номер"), value: monitor.hardware.serial)
            Text(L("Серийные номера скрыты и не включаются в экспорт отчёта.")).font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(.top, 12)
    }
}
struct BatteryInformationView: View {
    @EnvironmentObject private var monitor: MonitorStore
    var body: some View {
        let details = monitor.hardware.batteryDetails
        MetricCard(title: L("Информация о батарее"), icon: "battery.100percent", tint: Palette.green) {
            DetailRow(title: L("Производитель"), value: details.manufacturer ?? "—")
            DetailRow(title: L("Модель"), value: details.model ?? "—")
            SensitiveValue(title: L("Серийный номер"), value: details.serial)
            DetailRow(title: L("Дата производства"), value: details.manufactureDate.map(Fmt.date) ?? "—")
            DetailRow(title: L("Проектное число циклов"), value: details.designCycles.map(String.init) ?? "—")
            DetailRow(title: L("Число ячеек"), value: details.cellCount.map(String.init) ?? "—")
        }
    }
}
struct MetalInformationView: View {
    @EnvironmentObject private var monitor: MonitorStore
    var body: some View {
        ForEach(monitor.hardware.gpuDevices) { gpu in
            MetricCard(title: gpu.name, icon: "cpu", tint: Palette.cyan, subtitle: "Metal") {
                DetailRow(title: L("Архитектура памяти"), value: gpu.unified ? L("Единая память") : L("Выделенная память"))
                if gpu.unified { DetailRow(title: L("Общая память Mac"), value: Fmt.bytes(monitor.hardware.memory)) }
                DetailRow(title: L("Рекомендуемый бюджет Metal"), value: Fmt.bytes(gpu.workingSetBudget))
                DetailRow(title: L("Семейства Metal"), value: gpu.families.joined(separator: ", "))
                DetailRow(title: L("Съёмный"), value: gpu.removable ? L("Да") : L("Нет"))
                Text(L("На Apple Silicon CPU и GPU используют общую память. Бюджет Metal — рекомендация для приложения, а не объём выделенной VRAM или её текущая загрузка.")).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
    }
}
