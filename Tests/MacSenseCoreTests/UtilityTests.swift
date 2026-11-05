import XCTest
@testable import MacSenseCore

final class UtilityTests: XCTestCase {
    private let home = FileManager.default.homeDirectoryForCurrentUser
    private func file(_ path: String, _ category: String, reviewOnly: Bool = false) -> FileCandidate {
        FileCandidate(url: home.appendingPathComponent(path), title: path, category: category, bytes: 10, complete: true, reviewOnly: reviewOnly)
    }
    func testExpandedPolicyIsCategoryAndBoundaryAware() {
        XCTAssertTrue(UtilityPolicy.isAllowed(file("Library/Containers/com.example.App", "Контейнеры"), home: home))
        XCTAssertTrue(UtilityPolicy.isAllowed(file("Library/Developer/Xcode/DerivedData/Example", "DerivedData"), home: home))
        XCTAssertTrue(UtilityPolicy.isAllowed(file("Downloads/Example.dmg", "Образы дисков"), home: home))
        XCTAssertFalse(UtilityPolicy.isAllowed(file("Library/Group Containers/team.shared", "Контейнеры"), home: home))
        XCTAssertFalse(UtilityPolicy.isAllowed(file("Library/Containers", "Контейнеры"), home: home))
        XCTAssertFalse(UtilityPolicy.isAllowed(file("Downloads-other/document", "Крупные файлы"), home: home))
        XCTAssertFalse(UtilityPolicy.isAllowed(file("Library/Developer/CoreSimulator/Devices/Example", "Симуляторы", reviewOnly: true), home: home))
        XCTAssertFalse(UtilityPolicy.isAllowed(file("Library/Preferences/com.example.plist", "Кэш"), home: home))
        XCTAssertFalse(UtilityPolicy.isAllowed(file("Applications/Main.app/Contents/Helper.app", "Приложение"), home: home))
        XCTAssertTrue(UtilityPolicy.isAllowed(file("Applications/Tools/Example.app", "Приложение"), home: home))
    }
    func testRejectsSymlinkEscape() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root.appendingPathComponent("Library/Caches"), withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: root.appendingPathComponent("Library/Caches/escape"), withDestinationURL: URL(fileURLWithPath: "/etc"))
        let candidate = FileCandidate(url: root.appendingPathComponent("Library/Caches/escape"), title: "escape", category: "Кэш", bytes: 0, complete: true)
        XCTAssertFalse(UtilityPolicy.isAllowed(candidate, home: root))
    }
    func testAncestorSelectionIsCountedOnce() {
        let parent = file("Downloads/Folder", "Загрузки")
        let child = file("Downloads/Folder/large.bin", "Крупные файлы")
        let sibling = file("Downloads/Folder-two.txt", "Загрузки")
        let result = UtilityPolicy.independentFiles([child, parent, parent, sibling])
        XCTAssertEqual(Set(result.map(\.id)), Set([parent.id, sibling.id]))
    }
    func testRelatedFilesOnlyMatchExactBundleIdentifier() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        for path in ["Library/Containers/com.example.Test", "Library/Containers/com.example.Test-other", "Library/Application Scripts/com.example.Test", "Library/Group Containers/shared.com.example.Test"] {
            try fm.createDirectory(at: root.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        let app = InstalledApplication(url: root.appendingPathComponent("Applications/Test.app"), name: "Test", bundleID: "com.example.Test", version: "1", bytes: 0, complete: true)
        let files = await UtilityService(home: root).relatedFiles(for: app)
        XCTAssertEqual(files.count, 3)
        XCTAssertFalse(files.contains { $0.id.contains("Group Containers") || $0.id.hasSuffix("-other") })
    }
}
