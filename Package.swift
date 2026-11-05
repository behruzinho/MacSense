// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MacSense",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MacSense", targets: ["MacSense"])],
    targets: [
        .target(name: "TelemetryBridge", linkerSettings: [
            .linkedFramework("IOKit"), .linkedFramework("CoreFoundation")
        ]),
        .target(name: "MacSenseCore", dependencies: ["TelemetryBridge"], resources: [.process("Resources")]),
        .executableTarget(name: "MacSense", dependencies: ["MacSenseCore"]),
        .testTarget(name: "MacSenseCoreTests", dependencies: ["MacSenseCore", "TelemetryBridge"])
    ]
)
