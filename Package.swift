// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PaperAssist",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "PaperAssist",
            path: "Sources/PaperAssist"
        )
    ]
)
