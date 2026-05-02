// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "SwiftACD",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v13),
    .iOS(.v16),
    .watchOS(.v9),
    .tvOS(.v16),
    .visionOS(.v1)
  ],
  products: [
    .library(name: "SwiftACD", targets: ["SwiftACD"]),
    .executable(name: "SwiftACD_E2E", targets: ["SwiftACD_E2E"])
  ],
  dependencies: [
    .package(url: "https://github.com/CoreOffice/CoreXLSX", from: "0.14.2"),
    .package(url: "https://github.com/scinfu/SwiftSoup", from: "2.7.4"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.3")
  ],
  targets: [
    .target(
      name: "SwiftACD",
      dependencies: [
        "CoreXLSX",
        "SwiftSoup"
      ],
      resources: [
        .process("Resources/Localizable.xcstrings")
      ]
    ),
    .testTarget(
      name: "SwiftACDTests",
      dependencies: ["SwiftACD"],
      resources: [
        .copy("TestResources")
      ]
    ),
    .executableTarget(
      name: "SwiftACD_E2E",
      dependencies: [
        "SwiftACD",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
