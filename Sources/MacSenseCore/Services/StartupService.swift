import Foundation
import Darwin

public enum StartupParser {
    public static func validLabel(_ label: String) -> Bool {
        label.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]{0,254}$"#, options: .regularExpression) != nil
    }
    public static func disabledOverrides(_ text: String) -> [String: Bool] {
        let pattern = #""([^"\n]+)"\s*=>\s*(true|false|disabled|enabled)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }
        let ns = text as NSString
        return Dictionary(regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (ns.substring(with: match.range(at: 1)), ["true", "disabled"].contains(ns.substring(with: match.range(at: 2))))
        }, uniquingKeysWith: { _, latest in latest })
    }
    public static func loadedLabels(_ text: String) -> Set<String> {
        Set(text.split(separator: "\n").compactMap { line in
            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.count == 3, parts[0] == "-" || Int(parts[0]) != nil, validLabel(String(parts[2])) else { return nil }
            return String(parts[2])
        })
    }
    public static func canManage(_ entry: StartupEntry, home: URL) -> Bool {
        validLabel(entry.label) && !entry.label.hasPrefix("com.apple.") && entry.url.pathExtension == "plist" &&
        entry.url.standardizedFileURL == entry.url.resolvingSymlinksInPath() &&
        entry.url.deletingLastPathComponent() == home.appendingPathComponent("Library/LaunchAgents")
    }
}
public enum StartupService {
    public static func entries(home: URL) -> [StartupEntry] {
        let fm = FileManager.default
        let userDomain = "gui/\(getuid())"
        let userText = SystemCommand.text("/bin/launchctl", ["print-disabled", userDomain])
        let systemText = SystemCommand.text("/bin/launchctl", ["print-disabled", "system"])
        let listText = SystemCommand.text("/bin/launchctl", ["list"])
        let loaded = listText.map(StartupParser.loadedLabels)
        let roots: [(String, String)] = [(home.appendingPathComponent("Library/LaunchAgents").path, "Пользовательские агенты"), ("/Library/LaunchAgents", "Агенты системы"), ("/Library/LaunchDaemons", "Фоновые службы")]
        return roots.flatMap { path, group -> [StartupEntry] in
            let text = group == "Фоновые службы" ? systemText : userText
            let overrides = text.map(StartupParser.disabledOverrides)
            let urls = (try? fm.contentsOfDirectory(at: URL(fileURLWithPath: path), includingPropertiesForKeys: nil)) ?? []
            return urls.filter { $0.pathExtension == "plist" }.compactMap { url in
                guard let data = try? Data(contentsOf: url), let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else { return nil }
                let args = plist["ProgramArguments"] as? [String]
                let label = plist["Label"] as? String ?? url.deletingPathExtension().lastPathComponent
                return StartupEntry(url: url, label: label, program: plist["Program"] as? String ?? args?.first ?? "—", group: group,
                    runAtLoad: plist["RunAtLoad"] as? Bool ?? false,
                    enabled: overrides.map { !($0[label] ?? (plist["Disabled"] as? Bool ?? false)) },
                    loaded: group == "Фоновые службы" ? nil : loaded.map { $0.contains(label) })
            }.sorted { $0.label < $1.label }
        }
    }
    public static func setEnabled(_ enabled: Bool, entry: StartupEntry, home: URL) -> Bool {
        guard StartupParser.canManage(entry, home: home),
              let data = try? Data(contentsOf: entry.url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              plist["Label"] as? String == entry.label else { return false }
        return SystemCommand.data("/bin/launchctl", [enabled ? "enable" : "disable", "gui/\(getuid())/\(entry.label)"], timeout: 5) != nil
    }
}
