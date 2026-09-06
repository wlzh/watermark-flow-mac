// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "WatermarkFlow",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "WatermarkCore", targets: ["WatermarkCore"]),
        .executable(name: "WatermarkFlow", targets: ["WatermarkFlowApp"]),
        .executable(name: "WatermarkFlowTests", targets: ["WatermarkFlowTests"])
    ],
    targets: [
        .target(name: "WatermarkCore"),
        .executableTarget(
            name: "WatermarkFlowApp",
            dependencies: ["WatermarkCore"]
        ),
        .executableTarget(
            name: "WatermarkFlowTests",
            dependencies: ["WatermarkCore"],
            path: "Tests/WatermarkCoreTests"
        )
    ]
)
