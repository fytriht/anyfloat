// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TextF",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TextFApp", targets: ["TextFApp"]) 
    ],
    targets: [
        .executableTarget(
            name: "TextFApp",
            path: "Sources/TextFApp"
        )
    ]
)
