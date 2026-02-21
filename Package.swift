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
    targets: [
        .executableTarget(
            name: "AnyFloat",
            path: "Sources/AnyFloatApp"
        )
    ]
)
