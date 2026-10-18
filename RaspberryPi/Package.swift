// swift-tools-version: 5.9
import PackageDescription

// Diagnostic tools only. No dependencies are added to the Mac application.
let package = Package(
  name: "ScannerPiDiagnostics",
  platforms: [.macOS(.v14)],
  dependencies: [.package(name: "ScannerCore", path: "..")],
  targets: [.executableTarget(name: "DiagnosticLabel", dependencies: [
    .product(name: "ScannerCore", package: "ScannerCore")
  ])]
)
