import Foundation

public actor UtilityService {
    private let fm = FileManager.default
    private var issues: [String] = []
    public func scanIssues() -> [String] { issues }
    private let home: URL
    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) { self.home = home }

    public func applications(progress: (@Sendable (ScanProgress) async -> Void)? = nil) async -> [InstalledApplication] {
        issues = []
        let urls = applicationURLs()
        var apps: [InstalledApplication] = []
        for (index, url) in urls.enumerated() {
            if Task.isCancelled { break }
            guard let bundle = Bundle(url: url) else { continue }
            let info = bundle.infoDictionary ?? [:]
            let name = info["CFBundleDisplayName"] as? String ?? info["CFBundleName"] as? String ?? url.deletingPathExtension().lastPathComponent
            await progress?(ScanProgress(completed: index, total: urls.count, current: name))
            let size = directorySize(url, seconds: 0.6)
            var app = InstalledApplication(url: url, name: name, bundleID: bundle.bundleIdentifier, version: info["CFBundleShortVersionString"] as? String ?? "—", bytes: size.bytes, complete: size.complete)
            app.files = relatedFiles(for: app)
            apps.append(app)
            await Task.yield()
        }
        await progress?(ScanProgress(completed: urls.count, total: urls.count, current: ""))
        return apps.sorted { $0.totalBytes > $1.totalBytes }
    }
    private func applicationURLs() -> [URL] {
        let roots = [URL(fileURLWithPath: "/Applications"), home.appendingPathComponent("Applications")]
        var urls: [URL] = []
        for root in roots {
            guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in enumerator {
                if Task.isCancelled { return [] }
                guard url == url.resolvingSymlinksInPath() else { enumerator.skipDescendants(); continue }
                if url.pathExtension == "app" { urls.append(url); enumerator.skipDescendants() }
                else if enumerator.level >= 3 { enumerator.skipDescendants() }
            }
        }
        return urls
    }
    public func relatedFiles(for app: InstalledApplication) -> [FileCandidate] {
        var items = [FileCandidate(url: app.url, title: app.url.lastPathComponent, category: "Приложение", bytes: app.bytes, complete: app.complete)]
        guard let id = app.bundleID, UtilityPolicy.safeBundleIdentifier(id) else { return items }
        let library = home.appendingPathComponent("Library")
        let paths: [(String, String)] = [
            ("Caches/\(id)", "Кэш"), ("Logs/\(id)", "Журналы"), ("Preferences/\(id).plist", "Настройки"),
            ("Application Support/\(id)", "Данные приложения"), ("Saved Application State/\(id).savedState", "Состояние"),
            ("Containers/\(id)", "Контейнеры"), ("Application Scripts/\(id)", "Скрипты приложений")
        ]
        for (path, category) in paths {
            if Task.isCancelled { break }
            let url = library.appendingPathComponent(path)
            guard fm.fileExists(atPath: url.path), url == url.resolvingSymlinksInPath() else { continue }
            let size = directorySize(url, seconds: 0.5)
            items.append(FileCandidate(url: url, title: url.lastPathComponent, category: category, bytes: size.bytes, complete: size.complete))
        }
        // Shared Group Containers are deliberately excluded: more than one app may own them.
        return items
    }
    public func cleanerFiles(progress: (@Sendable (ScanProgress) async -> Void)? = nil) async -> [FileCandidate] {
        issues = []
        let library = home.appendingPathComponent("Library")
        let roots: [(URL, String, Bool)] = [
            (library.appendingPathComponent("Caches"), "Кэш", false), (library.appendingPathComponent("Logs"), "Журналы", false),
            (library.appendingPathComponent("Developer/Xcode/DerivedData"), "DerivedData", false),
            (library.appendingPathComponent("Developer/Xcode/Archives"), "Архивы Xcode", false),
            (library.appendingPathComponent("Developer/Xcode/iOS DeviceSupport"), "Поддержка устройств", false),
            (library.appendingPathComponent("Developer/Xcode/watchOS DeviceSupport"), "Поддержка устройств", false),
            (library.appendingPathComponent("Developer/Xcode/tvOS DeviceSupport"), "Поддержка устройств", false),
            (library.appendingPathComponent("Developer/CoreSimulator/Devices"), "Симуляторы", true),
            (home.appendingPathComponent("Downloads"), "Загрузки", false),
            (library.appendingPathComponent("Containers/com.apple.mail/Data/Library/Mail Downloads"), "Вложения почты", false),
            (URL(fileURLWithPath: "/Library/Logs"), "Системные журналы", true)
        ]
        var items: [FileCandidate] = []
        for (index, entry) in roots.enumerated() {
            if Task.isCancelled { break }
            let (parent, category, readOnly) = entry
            await progress?(ScanProgress(completed: index, total: roots.count, current: category))
            let children: [URL]
            do { children = try fm.contentsOfDirectory(at: parent, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles]) }
            catch {
                let error = error as NSError
                if error.domain != NSCocoaErrorDomain || ![NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code) { issues.append(parent.path) }
                continue
            }
            for url in children {
                if Task.isCancelled { break }
                guard url == url.resolvingSymlinksInPath() else { continue }
                let size = directorySize(url, seconds: 0.35)
                var kind = category
                if category == "Загрузки" {
                    if ["dmg", "iso", "sparseimage"].contains(url.pathExtension.lowercased()) { kind = "Образы дисков" }
                    else if ["pkg", "mpkg"].contains(url.pathExtension.lowercased()) { kind = "Установщики" }
                    else if size.bytes >= 500_000_000 { kind = "Крупные файлы" }
                }
                if size.bytes > 0 || !size.complete {
                    items.append(FileCandidate(url: url, title: url.lastPathComponent, category: kind, bytes: size.bytes, complete: size.complete, reviewOnly: readOnly))
                }
                await Task.yield()
            }
        }
        await progress?(ScanProgress(completed: roots.count, total: roots.count, current: ""))
        return items.sorted { $0.bytes > $1.bytes }
    }
    public func startupEntries() -> [StartupEntry] { StartupService.entries(home: home) }
    public func setStartupEnabled(_ enabled: Bool, entry: StartupEntry) -> Bool { StartupService.setEnabled(enabled, entry: entry, home: home) }
    public func trash(_ files: [FileCandidate]) -> TrashResult {
        var removed: [String] = [], failures: [String] = []
        for item in UtilityPolicy.independentFiles(files) {
            guard UtilityPolicy.isAllowed(item, home: home) else {
                failures.append(L("\(item.title): путь не входит в разрешённые папки")); continue
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
            if Task.isCancelled || ProcessInfo.processInfo.systemUptime > deadline { return (bytes, false) }
            guard let values = try? child.resourceValues(forKeys: keys) else { complete = false; continue }
            if values.isSymbolicLink == true { enumerator.skipDescendants(); continue }
            if values.isRegularFile == true { bytes += Double(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? values.fileSize ?? 0) }
        }
        return (bytes, complete)
    }
}
