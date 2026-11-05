import Foundation

public struct FileCandidate: Identifiable, Sendable {
    public let url: URL
    public let title: String
    public let category: String
    public let bytes: Double
    public let complete: Bool
    public var id: String { url.path }
    public init(url: URL, title: String, category: String, bytes: Double, complete: Bool) {
        self.url = url; self.title = title; self.category = category; self.bytes = bytes; self.complete = complete
    }
}
public struct InstalledApplication: Identifiable, Sendable {
    public let url: URL
    public let name: String
    public let bundleID: String?
    public let version: String
    public let bytes: Double
    public let complete: Bool
    public var id: String { url.path }
}
public struct StartupEntry: Identifiable, Sendable {
    public let url: URL
    public let label: String
    public let program: String
    public let group: String
    public let runAtLoad: Bool
    public var id: String { url.path }
}
public struct TrashResult: Sendable {
    public let removed: [String]
    public let failures: [String]
}
public enum UtilityPolicy {
    public static func safeBundleIdentifier(_ identifier: String) -> Bool {
        identifier.contains(".") && !identifier.contains("/") && !identifier.contains("\\") && identifier != "." && identifier != ".." && !identifier.contains("..")
    }
    public static func isAllowed(_ candidate: FileCandidate, home: URL) -> Bool {
        let url = candidate.url.standardizedFileURL
        guard url == url.resolvingSymlinksInPath() else { return false }
        let library = home.appendingPathComponent("Library")
        let parents = ["Caches", "Logs", "Preferences", "Application Support", "Saved Application State"].map { library.appendingPathComponent($0).path }
        if candidate.category == "Приложение" {
            return url.pathExtension == "app" && ["/Applications", home.appendingPathComponent("Applications").path].contains(url.deletingLastPathComponent().path)
        }
        return parents.contains(url.deletingLastPathComponent().path) && url.path != library.path
    }
}
