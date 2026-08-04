// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AutoPMX",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AutoPMX", targets: ["AutoPMX"])
    ],
    targets: [
        .executableTarget(
            name: "AutoPMX",
            path: "Sources/AutoPMX",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
