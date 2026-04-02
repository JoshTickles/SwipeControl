// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "SwipeControl",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "SwipeControl",
            path: "Sources/SwipeControl",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("Vision"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
            ]
        )
    ]
)
