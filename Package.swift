// swift-tools-version: 5.9
import PackageDescription

// The desktop app is built by build.sh. This package has no Apple framework dependency.
let package = Package(
  name: "ScannerCore",
  platforms: [.macOS(.v14)],
  products: [.library(name: "ScannerCore", targets: ["ScannerCore"])],
  targets: [
    .target(name: "ScannerCore", path: "Sources/ScannerCore"),
    .executableTarget(name: "ScannerCoreChecks", dependencies: ["ScannerCore"], path: "Tests/ScannerCore"),
  ]
)
