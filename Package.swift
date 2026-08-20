// swift-tools-version: 6.3
import PackageDescription

let approachableConcurrency: [SwiftSetting] = [
  .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  .enableUpcomingFeature("InferIsolatedConformances")
]

let package = Package(
  name: "SwiftACD",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v15),
    .iOS(.v18),
    .watchOS(.v11),
    .tvOS(.v18),
    .visionOS(.v2)
  ],
  products: [
    .library(name: "SwiftACD", targets: ["SwiftACD"]),
    .executable(name: "SwiftACD_E2E", targets: ["SwiftACD_E2E"])
  ],
  dependencies: [
    .package(url: "https://github.com/CoreOffice/CoreXLSX", from: "0.14.2"),
    .package(url: "https://github.com/scinfu/SwiftSoup", from: "2.13.7"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.8.2"),
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.5.0")
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
      ],
      swiftSettings: approachableConcurrency
    ),
    .testTarget(
      name: "SwiftACDTests",
      dependencies: ["SwiftACD"],
      resources: [
        .copy("TestResources")
      ],
      swiftSettings: approachableConcurrency
    ),
    .executableTarget(
      name: "SwiftACD_E2E",
      dependencies: [
        "SwiftACD",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ],
      swiftSettings: approachableConcurrency
    )
  ],
  swiftLanguageModes: [.v6]
)
