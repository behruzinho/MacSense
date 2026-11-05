import SwiftUI
import MacSenseCore

/// Keeps the existing banner styling while making About This Mac facts immediately visible.
struct DeviceSummaryCard: View {
    @EnvironmentObject private var monitor: MonitorStore
    @State private var revealedSerial = false
    private var h: HardwareInfo { monitor.hardware }
    private var normal: Bool { monitor.snapshot.thermalState == 0 }
    var body: some View {
        HStack(spacing: 24) {
            LaptopIllustration().frame(width: 105, height: 82)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(h.modelName).font(.system(size: 21, weight: .semibold))
                    if let size = h.displayDiagonal {
                        Text(String(format: "≈ %.1f″", locale: L10n.locale, size) + " · " + h.chip)
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }.padding(.bottom, 16)
                ViewThatFits(in: .horizontal) { facts(wide: true); facts(wide: false) }
                    .padding(.bottom, 16)
                HStack(spacing: 8) {
                    tag(L("\(h.coreCount) ядер CPU"))
                    tag(h.model)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 8) {
                Image(systemName: normal ? "checkmark.shield" : "thermometer.medium")
                    .font(.system(size: 25, weight: .light)).foregroundStyle(normal ? Palette.green : Palette.orange)
                Text(normal ? L("Температурный режим\nв норме") : L("Повышенная\nтепловая нагрузка"))
                    .font(.system(size: 10)).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }.frame(width: 140, alignment: .trailing)
        }.padding(.horizontal, 24).padding(.vertical, 22).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Palette.card, Palette.blue.opacity(0.07)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.border))
    }
    @ViewBuilder private func facts(wide: Bool) -> some View {
        if wide {
            HStack(alignment: .top, spacing: 32) {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 9) {
                    GridRow { caption(L("Чип")); value(h.chip) }
                    GridRow { caption(L("Загрузочный диск")); value(h.startupDisk ?? "—") }
                    GridRow { caption("macOS"); value(h.os) }
                }
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 9) {
                    GridRow { caption(L("Память")); value(Fmt.bytes(h.memory)) }
                    GridRow { caption(L("Серийный номер")); serial }
                }
            }
        } else {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 9) {
                GridRow { caption(L("Чип")); value(h.chip) }
                GridRow { caption(L("Память")); value(Fmt.bytes(h.memory)) }
                GridRow { caption(L("Загрузочный диск")); value(h.startupDisk ?? "—") }
                GridRow { caption(L("Серийный номер")); serial }
                GridRow { caption("macOS"); value(h.os) }
            }
        }
    }
    private var serial: some View {
        HStack(spacing: 7) {
            value(h.serial.map { revealedSerial ? $0 : "••••••••" } ?? "—")
            if h.serial != nil {
                Button { revealedSerial.toggle() } label: { Image(systemName: revealedSerial ? "eye.slash" : "eye") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).font(.system(size: 11))
                    .help(revealedSerial ? L("Скрыть номер") : L("Показать номер"))
            }
        }
    }
    private func caption(_ title: String) -> some View { Text(title).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize() }
    private func value(_ title: String) -> some View { Text(title).font(.system(size: 11, weight: .medium)).textSelection(.enabled).fixedSize(horizontal: true, vertical: false) }
    private func tag(_ title: String) -> some View {
        Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 11).padding(.vertical, 6).background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }
}
