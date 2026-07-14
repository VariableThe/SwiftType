// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftType",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "SwiftTypeCore",
            targets: ["SwiftTypeCore"]
        ),
        .library(
            name: "SwiftTypeSystem",
            targets: ["SwiftTypeSystem"]
        ),
        .library(
            name: "SwiftTypeUI",
            targets: ["SwiftTypeUI"]
        ),
        .executable(
            name: "SwiftType",
            targets: ["SwiftType"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwiftTypeCore",
            dependencies: [],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .target(
            name: "SwiftTypeSystem",
            dependencies: ["SwiftTypeCore"]
        ),
        .target(
            name: "SwiftTypeUI",
            dependencies: ["SwiftTypeCore", "SwiftTypeSystem"]
        ),
        .executableTarget(
            name: "SwiftType",
            dependencies: ["SwiftTypeCore", "SwiftTypeSystem", "SwiftTypeUI"]
        ),
        .testTarget(
            name: "SwiftTypeTests",
            dependencies: ["SwiftTypeCore", "SwiftTypeSystem", "SwiftTypeUI"]
        )
    ]
)
