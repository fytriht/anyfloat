// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnyFloat",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AnyFloat", targets: ["AnyFloat"])
    ],
    dependencies: [
        .package(url: "https://github.com/mixpanel/mixpanel-swift.git", from: "4.3.1")
    ],
    targets: [
        .executableTarget(
            name: "AnyFloat",
            dependencies: [
                .product(name: "Mixpanel", package: "mixpanel-swift")
            ],
            path: "Sources/AnyFloatApp"
        )
    ]
)
