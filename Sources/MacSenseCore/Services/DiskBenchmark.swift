import Foundation
import Darwin

public struct BenchmarkProgress: Sendable {
    public let stage: String
    public let fraction: Double
}
public struct BenchmarkResult: Sendable {
    public let readBytesPerSecond: Double
    public let writeBytesPerSecond: Double
    public let bytes: Int
}
public enum BenchmarkError: LocalizedError {
    case busy, size, folder, space, io(Int32)
    public var errorDescription: String? {
        switch self {
        case .busy: return L("Тест уже выполняется")
        case .size: return L("Размер теста должен быть от 4 до 1024 МБ")
        case .folder: return L("Выберите доступную папку на нужном диске")
        case .space: return L("Недостаточно свободного места для временного файла")
        case .io(let code): return String(cString: strerror(code))
        }
    }
}
/// Creates only a unique, exclusive scratch file. No raw device writes or existing files.
public actor DiskBenchmark {
    private var running = false
    public init() {}
    public func run(at folder: URL, megabytes: Int = 256, progress: (@Sendable (BenchmarkProgress) async -> Void)? = nil) async throws -> BenchmarkResult {
        guard !running else { throw BenchmarkError.busy }
        guard (4...1024).contains(megabytes) else { throw BenchmarkError.size }
        try Task.checkCancellation()
        let fm = FileManager.default, folder = folder.standardizedFileURL.resolvingSymlinksInPath()
        guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { throw BenchmarkError.folder }
        let bytes = megabytes * 1024 * 1024
        let available = (try? fm.attributesOfFileSystem(forPath: folder.path)[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        guard available > Int64(bytes + 256 * 1024 * 1024) else { throw BenchmarkError.space }
        running = true; defer { running = false }
        let file = folder.appendingPathComponent(".MacSense-benchmark-\(UUID().uuidString).tmp")
        let descriptor = open(file.path, O_CREAT | O_EXCL | O_RDWR | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw BenchmarkError.io(errno) }
        defer { close(descriptor); try? fm.removeItem(at: file) }
        guard fcntl(descriptor, F_NOCACHE, 1) == 0 else { throw BenchmarkError.io(errno) }
        var buffer = [UInt8](repeating: 0, count: 4 * 1024 * 1024)
        buffer.withUnsafeMutableBytes { arc4random_buf($0.baseAddress!, $0.count) }
        let writeStart = ProcessInfo.processInfo.systemUptime
        var done = 0
        while done < bytes {
            try Task.checkCancellation()
            let count = min(buffer.count, bytes - done)
            let n = buffer.withUnsafeBytes { Darwin.write(descriptor, $0.baseAddress!, count) }
            if n < 0 && errno == EINTR { continue }
            guard n > 0 else { throw BenchmarkError.io(errno) }; done += n
            await progress?(BenchmarkProgress(stage: "Запись", fraction: Double(done) / Double(bytes) / 2))
            await Task.yield()
        }
        guard fsync(descriptor) == 0 else { throw BenchmarkError.io(errno) }
        let writeSeconds = ProcessInfo.processInfo.systemUptime - writeStart
        guard lseek(descriptor, 0, SEEK_SET) == 0 else { throw BenchmarkError.io(errno) }
        let readStart = ProcessInfo.processInfo.systemUptime
        done = 0
        while done < bytes {
            try Task.checkCancellation()
            let count = min(buffer.count, bytes - done)
            let n = buffer.withUnsafeMutableBytes { Darwin.read(descriptor, $0.baseAddress!, count) }
            if n < 0 && errno == EINTR { continue }
            guard n > 0 else { throw BenchmarkError.io(errno) }; done += n
            await progress?(BenchmarkProgress(stage: "Чтение", fraction: 0.5 + Double(done) / Double(bytes) / 2))
            await Task.yield()
        }
        return BenchmarkResult(readBytesPerSecond: Double(bytes) / max(0.000001, ProcessInfo.processInfo.systemUptime - readStart), writeBytesPerSecond: Double(bytes) / max(0.000001, writeSeconds), bytes: bytes)
    }
}
