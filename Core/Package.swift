// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "PrivateActionCore", platforms: [.iOS(.v17), .macOS(.v14)], products: [.library(name: "PrivateActionCore", targets: ["PrivateActionCore"])], targets: [.target(name: "PrivateActionCore"), .executableTarget(name: "SecurityChecks", dependencies: ["PrivateActionCore"]), .testTarget(name: "PrivateActionCoreTests", dependencies: ["PrivateActionCore"])])
