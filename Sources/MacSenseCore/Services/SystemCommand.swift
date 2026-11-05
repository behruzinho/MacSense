import Foundation

public enum SystemCommand {
    /// Used on the telemetry/utility actor, never on the UI thread. Arguments are passed without a shell.
    public static func data(_ executable: String, _ arguments: [String], timeout: TimeInterval = 12, acceptNonzero: Bool = false) -> Data? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let timeoutItem = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        timeoutItem.cancel()
        guard process.terminationReason == .exit, acceptNonzero || process.terminationStatus == 0 else { return nil }
        return output
    }
    public static func text(_ executable: String, _ arguments: [String]) -> String? {
        data(executable, arguments).flatMap { String(data: $0, encoding: .utf8) }
    }
}
