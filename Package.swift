// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ForgeCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ForgeCore", targets: ["ForgeCore"])],
    targets: [
        .target(name: "ForgeCore", path: "Forge/Core"),
        .testTarget(name: "ForgeCoreTests", dependencies: ["ForgeCore"], path: "Tests/ForgeCoreTests", resources: [.copy("Fixtures")])
    ]
)
