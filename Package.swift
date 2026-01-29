// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentariumClient",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "AgentariumClient",
            path: "Sources"
        ),
        // Note: Tests require full Xcode installation (XCTest not available with CLT only)
        // .testTarget(
        //     name: "AgentariumClientTests",
        //     dependencies: [],
        //     path: "Tests"
        // ),
    ]
)
