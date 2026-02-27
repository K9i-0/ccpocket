// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "screencapturekit-daemon",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "screencapturekit-daemon",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("ImageIO"),
                .linkedFramework("CoreImage"),
            ]
        )
    ]
)
