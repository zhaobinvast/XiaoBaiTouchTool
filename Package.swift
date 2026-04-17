// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "XiaoBaiTouchTool",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "XiaoBaiTouchTool",
            path: "Sources/XiaoBaiTouchTool",
            linkerSettings: [
                .unsafeFlags(["-framework", "AppKit", "-framework", "ApplicationServices"])
            ]
        )
    ]
)
