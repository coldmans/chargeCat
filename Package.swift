// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ChargeCat",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "ChargeCat",
            targets: ["ChargeCat"]
        )
    ],
    targets: [
        .executableTarget(
            name: "ChargeCat",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
