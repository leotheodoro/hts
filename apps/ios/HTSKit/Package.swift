// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HTSKit",
    defaultLocalization: "pt-BR",
    // macOS is only here so `swift test` runs on the host; the app is iPhone-only.
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "HTSDesign", targets: ["HTSDesign"]),
        .library(name: "HTSDomain", targets: ["HTSDomain"]),
    ],
    targets: [
        .target(
            name: "HTSDesign",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "HTSDesignTests", dependencies: ["HTSDesign"]),
        .target(
            name: "HTSDomain",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "HTSDomainTests",
            dependencies: ["HTSDomain"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
