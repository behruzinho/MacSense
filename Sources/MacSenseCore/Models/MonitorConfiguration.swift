import Foundation

public enum MonitorPanel: String, CaseIterable, Identifiable, Sendable {
    case cpu, memory, gpu, storage, network, sensors, power
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .cpu: return L("Процессор")
        case .memory: return L("Память")
        case .gpu: return L("Графика")
        case .storage: return L("Накопители")
        case .network: return L("Сеть")
        case .sensors: return L("Охлаждение")
        case .power: return L("Питание")
        }
    }
}
public struct MonitorConfiguration: Equatable, Sendable {
    public var panels: [MonitorPanel]
    public static let defaultEncoded = #"["cpu","memory","gpu","storage","network","sensors","power"]"#
    public init(encoded: String) {
        guard let data = encoded.data(using: .utf8), let values = try? JSONDecoder().decode([String].self, from: data) else {
            panels = MonitorPanel.allCases; return
        }
        var seen: Set<String> = []
        panels = values.compactMap { value in guard seen.insert(value).inserted else { return nil }; return MonitorPanel(rawValue: value) }
    }
    public var encoded: String { String(decoding: (try? JSONEncoder().encode(panels.map(\.rawValue))) ?? Data(), as: UTF8.self) }
    public mutating func set(_ panel: MonitorPanel, enabled: Bool) {
        if enabled && !panels.contains(panel) { panels.append(panel) }
        if !enabled { panels.removeAll { $0 == panel } }
    }
    public mutating func move(_ panel: MonitorPanel, offset: Int) {
        guard let index = panels.firstIndex(of: panel), panels.indices.contains(index + offset) else { return }
        panels.swapAt(index, index + offset)
    }
}
