// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HTSKit",
    defaultLocalization: "pt-BR",
    // macOS is only here so `swift test` runs on the host; the app is iPhone-only.
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "HTSDesign", targets: ["HTSDesign"]),
    ],
    targets: [
        .target(
            name: "HTSDesign",
            resources: [.process("Resources")]
        ),
    ]
)
