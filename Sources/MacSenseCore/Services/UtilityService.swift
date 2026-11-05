import Foundation

public actor UtilityService {
    private let fm = FileManager.default
    public init() {}
    public func applications() -> [InstalledApplication] {
        let roots = [URL(fileURLWithPath: "/Applications"), fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        var apps: [InstalledApplication] = []
        for root in roots {
            let urls = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            for url in urls where url.pathExtension == "app" {
                guard url == url.resolvingSymlinksInPath(), let bundle = Bundle(url: url) else { continue }
                let info = bundle.infoDictionary ?? [:]
                let size = directorySize(url, seconds: 1)
                apps.append(InstalledApplication(url: url, name: info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? url.deletingPathExtension().lastPathComponent, bundleID: bundle.bundleIdentifier, version: info["CFBundleShortVersionString"] as? String ?? "—", bytes: size.bytes, complete: size.complete))
            }
        }
        return apps.sorted { $0.bytes > $1.bytes }
    }
    public func relatedFiles(for app: InstalledApplication) -> [FileCandidate] {
        var items = [FileCandidate(url: app.url, title: app.url.lastPathComponent, category: "Приложение", bytes: app.bytes, complete: app.complete)]
        guard let id = app.bundleID, UtilityPolicy.safeBundleIdentifier(id) else { return items }
        let library = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        let paths: [(String, String)] = [("Caches/\(id)", "Кэш"), ("Preferences/\(id).plist", "Настройки"), ("Application Support/\(id)", "Данные приложения"), ("Saved Application State/\(id).savedState", "Состояние")]
        for (path, category) in paths {
            let url = library.appendingPathComponent(path)
            guard fm.fileExists(atPath: url.path), url == url.resolvingSymlinksInPath() else { continue }
            let size = directorySize(url, seconds: 2)
            items.append(FileCandidate(url: url, title: url.lastPathComponent, category: category, bytes: size.bytes, complete: size.complete))
        }
        return items
    }
    public func cleanerFiles() -> [FileCandidate] {
        var items: [FileCandidate] = []
        let library = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        for (folder, category) in [("Caches", "Кэш"), ("Logs", "Журналы")] {
            let parent = library.appendingPathComponent(folder)
            let children = (try? fm.contentsOfDirectory(at: parent, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles])) ?? []
            for url in children {
                guard url == url.resolvingSymlinksInPath() else { continue }
                let size = directorySize(url, seconds: 0.6)
                if size.bytes > 0 { items.append(FileCandidate(url: url, title: url.lastPathComponent, category: category, bytes: size.bytes, complete: size.complete)) }
            }
        }
        return items.sorted { $0.bytes > $1.bytes }
    }
    public func startupEntries() -> [StartupEntry] {
        let roots: [(String, String)] = [(fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents").path, "Пользовательские агенты"), ("/Library/LaunchAgents", "Агенты системы"), ("/Library/LaunchDaemons", "Фоновые службы")]
        return roots.flatMap { path, group -> [StartupEntry] in
            let urls = (try? fm.contentsOfDirectory(at: URL(fileURLWithPath: path), includingPropertiesForKeys: nil)) ?? []
            return urls.filter { $0.pathExtension == "plist" }.compactMap { url in
                guard let data = try? Data(contentsOf: url), let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] else { return nil }
                let arguments = plist["ProgramArguments"] as? [String]
                return StartupEntry(url: url, label: plist["Label"] as? String ?? url.deletingPathExtension().lastPathComponent, program: plist["Program"] as? String ?? arguments?.first ?? "—", group: group, runAtLoad: plist["RunAtLoad"] as? Bool ?? false)
            }.sorted { $0.label < $1.label }
        }
    }
    public func trash(_ files: [FileCandidate]) -> TrashResult {
        var removed: [String] = [], failures: [String] = []
        for item in files {
            guard UtilityPolicy.isAllowed(item, home: fm.homeDirectoryForCurrentUser) else {
                failures.append(L("\(item.title): путь не входит в разрешённые папки"))
                continue
            }
            do { try fm.trashItem(at: item.url, resultingItemURL: nil); removed.append(item.id) }
            catch { failures.append("\(item.title): \(error.localizedDescription)") }
        }
        return TrashResult(removed: removed, failures: failures)
    }
    private func directorySize(_ url: URL, seconds: TimeInterval) -> (bytes: Double, complete: Bool) {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey, .fileSizeKey]
        guard let value = try? url.resourceValues(forKeys: keys) else { return (0, false) }
        if value.isSymbolicLink == true { return (0, false) }
        if value.isRegularFile == true { return (Double(value.totalFileAllocatedSize ?? value.fileAllocatedSize ?? value.fileSize ?? 0), true) }
        var complete = true
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in complete = false; return true }) else { return (0, false) }
        let deadline = ProcessInfo.processInfo.systemUptime + seconds
        var bytes = 0.0
        for case let child as URL in enumerator {
            if ProcessInfo.processInfo.systemUptime > deadline { return (bytes, false) }
            guard let values = try? child.resourceValues(forKeys: keys) else { complete = false; continue }
            if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            if values.isRegularFile == true { bytes += Double(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0) }
        }
        return (bytes, complete)
    }
}
