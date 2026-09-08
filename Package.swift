// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RamBar",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "RamBar", targets: ["RamBar"])],
    targets: [
        .executableTarget(name: "RamBar"),
        .testTarget(name: "RamBarTests", dependencies: ["RamBar"])
    ]
)
