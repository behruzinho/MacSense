import Foundation

public struct FileCandidate: Identifiable, Sendable {
    public let url: URL
    public let title: String
    /// Stable IDs are independent of the display language.
    public let category: String
    public let bytes: Double
    public let complete: Bool
    public let reviewOnly: Bool
    public var id: String { url.path }
    public var containsPersonalData: Bool { ["Загрузки", "Крупные файлы", "Вложения почты", "Архивы Xcode", "Контейнеры", "Данные приложения"].contains(category) }
    public init(url: URL, title: String, category: String, bytes: Double, complete: Bool, reviewOnly: Bool = false) {
        self.url = url; self.title = title; self.category = category; self.bytes = bytes; self.complete = complete; self.reviewOnly = reviewOnly
    }
}
public struct InstalledApplication: Identifiable, Sendable {
    public let url: URL
    public let name: String
    public let bundleID: String?
    public let version: String
    public let bytes: Double
    public let complete: Bool
    public var files: [FileCandidate] = []
    public var totalBytes: Double { files.isEmpty ? bytes : files.reduce(0) { $0 + $1.bytes } }
    public var totalComplete: Bool { complete && files.allSatisfy(\.complete) }
    public var id: String { url.path }
}
public struct ScanProgress: Sendable {
    public let completed: Int
    public let total: Int
    public let current: String
    public var fraction: Double { total > 0 ? min(1, Double(completed) / Double(total)) : 0 }
    public init(completed: Int, total: Int, current: String) { self.completed = completed; self.total = total; self.current = current }
}
public struct StartupEntry: Identifiable, Sendable {
    public let url: URL
    public let label: String
    public let program: String
    public let group: String
    public let runAtLoad: Bool
    public var enabled: Bool? = nil
    public var loaded: Bool? = nil
    public var id: String { url.path }
}
public struct TrashResult: Sendable {
    public let removed: [String]
    public let failures: [String]
}
public enum UtilityPolicy {
    public static func safeBundleIdentifier(_ identifier: String) -> Bool {
        identifier.contains(".") && !identifier.contains("/") && !identifier.contains("\\") && !identifier.contains("..") && !identifier.contains("\0")
    }
    public static func isDescendant(_ url: URL, of parent: URL) -> Bool {
        let p = parent.standardizedFileURL.path
        return url.standardizedFileURL.path.hasPrefix(p + "/")
    }
    public static func isAllowed(_ candidate: FileCandidate, home: URL) -> Bool {
        let url = candidate.url.standardizedFileURL
        guard !candidate.reviewOnly, url == url.resolvingSymlinksInPath() else { return false }
        let library = home.appendingPathComponent("Library")
        if candidate.category == "Приложение" {
            let roots = [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")]
            return url.pathExtension == "app" && roots.contains { root in
                guard isDescendant(url, of: root) else { return false }
                // Never treat helpers nested inside an app bundle as installed applications.
                let parents = url.deletingLastPathComponent().pathComponents.dropFirst(root.pathComponents.count)
                return !parents.contains { $0.hasSuffix(".app") }
            }
        }
        let immediate: [String: [String]] = [
            "Кэш": ["Caches"], "Журналы": ["Logs"], "Настройки": ["Preferences"],
            "Данные приложения": ["Application Support"], "Состояние": ["Saved Application State"],
            "Контейнеры": ["Containers"], "Скрипты приложений": ["Application Scripts"],
            "DerivedData": ["Developer/Xcode/DerivedData"], "Архивы Xcode": ["Developer/Xcode/Archives"],
            "Поддержка устройств": ["Developer/Xcode/iOS DeviceSupport", "Developer/Xcode/watchOS DeviceSupport", "Developer/Xcode/tvOS DeviceSupport"],
            "Вложения почты": ["Containers/com.apple.mail/Data/Library/Mail Downloads"]
        ]
        if let paths = immediate[candidate.category], paths.contains(where: { url.deletingLastPathComponent() == library.appendingPathComponent($0) }) { return true }
        if ["Загрузки", "Образы дисков", "Установщики"].contains(candidate.category) {
            return url.deletingLastPathComponent() == home.appendingPathComponent("Downloads")
        }
        if candidate.category == "Крупные файлы" {
            // Personal files are discovered under Downloads only; no arbitrary home-directory deletion.
            return isDescendant(url, of: home.appendingPathComponent("Downloads")) && url.pathExtension != "app"
        }
        return false
    }
    /// Avoid double counting or attempting to trash both an ancestor and its child.
    public static func independentFiles(_ files: [FileCandidate]) -> [FileCandidate] {
        var output: [FileCandidate] = []
        for file in files.sorted(by: { $0.url.pathComponents.count < $1.url.pathComponents.count }) {
            if !output.contains(where: { $0.id == file.id || isDescendant(file.url, of: $0.url) }) { output.append(file) }
        }
        return output
    }
}
