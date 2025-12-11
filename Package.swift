// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CCBuddy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CCBuddy", targets: ["CCBuddy"])
    ],
    targets: [
        .executableTarget(
            name: "CCBuddy",
            path: "CCBuddy",
            exclude: ["Resources/Info.plist"],
            resources: [.process("Resources")]
        )
    ]
)
