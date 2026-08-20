// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ZIKORAP00Spikes",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "P00Spikes", targets: ["P00Spikes"]),
    ],
    targets: [
        .executableTarget(name: "P00Spikes"),
    ],
    swiftLanguageModes: [.v5]
)

