import SwiftUI
import MacSenseCore

struct NetworkView: View {
    @EnvironmentObject private var monitor: MonitorStore
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Оборудование / Подключения"), title: L("Сеть"), description: L("Скорость передачи данных через активные сетевые интерфейсы."))
            HStack(alignment: .top, spacing: 16) {
                MetricCard(title: L("Загрузка"), icon: "arrow.down.circle", tint: Palette.cyan) {
                    Text(Fmt.rate(monitor.snapshot.network.download)).font(.system(size: 33, weight: .semibold, design: .rounded)).monospacedDigit()
                    Sparkline(points: monitor.downloadHistory, tint: Palette.cyan, ceiling: nil, height: 160)
                    DetailRow(title: L("Принято с запуска интерфейсов"), value: Fmt.bytes(monitor.snapshot.network.received))
                }
                MetricCard(title: L("Отправка"), icon: "arrow.up.circle", tint: Palette.purple) {
                    Text(Fmt.rate(monitor.snapshot.network.upload)).font(.system(size: 33, weight: .semibold, design: .rounded)).monospacedDigit()
                    Sparkline(points: monitor.uploadHistory, tint: Palette.purple, ceiling: nil, height: 160)
                    DetailRow(title: L("Отправлено с запуска интерфейсов"), value: Fmt.bytes(monitor.snapshot.network.sent))
                }
            }
            InfoNote(text: L("Показана сумма счётчиков активных интерфейсов Ethernet, Wi-Fi и сотовых модемов. Виртуальные VPN-интерфейсы исключены, чтобы не считать трафик дважды. Это скорость текущего трафика, а не тест скорости интернета."))
            Button(L("Настройки сети"), systemImage: "network") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") { NSWorkspace.shared.open(url) }
            }
        }
    }
}

struct GraphicsView: View {
    @EnvironmentObject private var monitor: MonitorStore
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeading(eyebrow: L("Оборудование / GPU"), title: L("Графика"), description: L("Графический процессор и доступные показатели его работы."))
            MetricCard(title: monitor.hardware.graphics, icon: "display", tint: Palette.cyan) {
                HStack(spacing: 40) {
                    MetricRing(value: monitor.snapshot.gpu, label: L("ЗАГРУЗКА GPU"), tint: Palette.cyan, size: 150)
                    VStack(spacing: 16) {
                        DetailRow(title: L("Графический процессор"), value: monitor.hardware.graphics)
                        DetailRow(title: L("Ядра GPU"), value: monitor.hardware.gpuCores ?? "—")
                        DetailRow(title: L("Максимальная температура GPU"), value: Fmt.temperature(monitor.snapshot.temperatures.filter { $0.group == "Графика" }.map(\.value).max()))
                        DetailRow(title: L("Данные загрузки"), value: monitor.snapshot.gpu != nil ? L("Доступны · IOKit") : L("Не предоставлены системой"))
                    }
                }
                Sparkline(points: monitor.gpuHistory, tint: Palette.cyan, height: 150)
            }
            MetalInformationView()
            InfoNote(text: L("Загрузка GPU читается из статистики IOAccelerator. Доступность зависит от модели Mac и версии macOS. На системах с несколькими GPU здесь показана наибольшая из доступных загрузок."))
        }
    }
}
