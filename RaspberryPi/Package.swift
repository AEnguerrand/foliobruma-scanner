// swift-tools-version: 5.9
import PackageDescription

// Pi targets only. No dependencies are added to the Mac application.
let package = Package(
  name: "ScannerPi",
  platforms: [.macOS(.v14)],
  dependencies: [.package(name: "ScannerCore", path: "..")],
  targets: [.executableTarget(name: "DiagnosticLabel", dependencies: [
    .product(name: "ScannerCore", package: "ScannerCore")
  ]),
  .target(name: "StationCore", dependencies: [.product(name: "ScannerCore", package: "ScannerCore")]),
  .executableTarget(name: "ScannerStation", dependencies: ["StationCore"])
  ]
)
