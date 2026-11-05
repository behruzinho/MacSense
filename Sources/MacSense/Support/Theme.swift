import SwiftUI
import MacSenseCore

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let darkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let h = darkMode ? dark : light
            return NSColor(srgbRed: Double((h >> 16) & 255) / 255, green: Double((h >> 8) & 255) / 255, blue: Double(h & 255) / 255, alpha: 1)
        })
    }
}
enum Palette {
    static let background = Color.adaptive(light: 0xF3F5F8, dark: 0x17191D)
    static let card = Color.adaptive(light: 0xFFFFFF, dark: 0x22252B)
    static let inset = Color.adaptive(light: 0xEAEFF5, dark: 0x1A1D22)
    static let border = Color.primary.opacity(0.065)
    static let blue = Color(hex: 0x568DFF)
    static let green = Color(hex: 0x5CD6A0)
    static let purple = Color(hex: 0xB494F8)
    static let orange = Color(hex: 0xF4B86A)
    static let pink = Color(hex: 0xF17A9D)
    static let cyan = Color(hex: 0x5CC8D9)
}
enum Fmt {
    static func bytes(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "—" }
        let units = ["Б", "КБ", "МБ", "ГБ", "ТБ"]
        var amount = value
        var index = 0
        while amount >= 1024 && index < units.count - 1 { amount /= 1024; index += 1 }
        let number = amount.formatted(.number.precision(.fractionLength(0...(index >= 3 ? 2 : 1))).locale(L10n.locale))
        return number + " " + L10n.translate(units[index])
    }
    static func time(_ date: Date) -> String { date.formatted(.dateTime.hour().minute().second().locale(L10n.locale)) }
    static func date(_ date: Date) -> String { date.formatted(.dateTime.year().month().day().hour().minute().locale(L10n.locale)) }
    static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return "\(Int(value.rounded()))%"
    }
    static func temperature(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return String(format: "%.0f °C", value)
    }
    static func rate(_ value: Double?) -> String { value.map { bytes($0) + L("/с") } ?? "—" }
    static func duration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        return hours >= 24 ? L("\(hours / 24) д \(hours % 24) ч") : L("\(hours) ч \(Int(seconds) % 3600 / 60) мин")
    }
}
