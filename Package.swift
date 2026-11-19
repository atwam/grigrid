// swift-tools-version:5.9
// Swift 5 language mode (tools 5.9) keeps AppKit/CGEventTap code free of strict-concurrency friction.
import PackageDescription

let package = Package(
    name: "Grigrid",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure, AppKit-free grid math so it can be unit tested.
        .target(name: "GrigridCore"),
        .executableTarget(
            name: "Grigrid",
            dependencies: ["GrigridCore"]
        ),
        .testTarget(
            name: "GrigridTests",
            dependencies: ["GrigridCore"]
        ),
    ]
)
