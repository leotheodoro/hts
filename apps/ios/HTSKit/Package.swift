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
        .library(name: "HTSPersistence", targets: ["HTSPersistence"]),
        .library(name: "HTSAPI", targets: ["HTSAPI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession.git", from: "1.0.0"),
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
        .target(
            name: "HTSPersistence",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        .testTarget(name: "HTSPersistenceTests", dependencies: ["HTSPersistence"]),
        .target(
            name: "HTSAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]
        ),
        .testTarget(name: "HTSAPITests", dependencies: ["HTSAPI"]),
    ]
)
