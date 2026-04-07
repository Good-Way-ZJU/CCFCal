// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "DDLCalSwiftPrototype",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DDLCalCore", targets: ["DDLCalCore"]),
        .executable(name: "DDLCalCLI", targets: ["DDLCalCLI"])
    ],
    targets: [
        .target(
            name: "DDLCalCore",
            path: "Sources/DDLCalCore"
        ),
        .executableTarget(
            name: "DDLCalCLI",
            dependencies: ["DDLCalCore"],
            path: "Sources/DDLCalCLI"
        ),
        .testTarget(
            name: "DDLCalCoreTests",
            dependencies: ["DDLCalCore"],
            path: "Tests/DDLCalCoreTests"
        )
    ]
)
