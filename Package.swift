// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "prActIce",
    dependencies: [
        .package(url: "https://github.com/guitaripod/DeepSeekKit", from: "1.0.0"), 
        .package(url: "https://github.com/TakeScoop/SwiftyRSA", from: "1.7.0")
    ], 
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "prActIce", 
            dependencies: [
                .product(name: "DeepSeekKit", package: "DeepSeekKit"), 
                .product(name: "SwiftyRSA", package: "SwiftyRSA")
            ]
        ),
        .testTarget(
            name: "prActIceTests",
            dependencies: ["prActIce"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
