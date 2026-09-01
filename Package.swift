// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "LidAwake",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "LidAwakeShared", targets: ["LidAwakeShared"]),
    .executable(name: "LidAwakeApp", targets: ["LidAwakeApp"]),
    .executable(name: "LidAwakeHelper", targets: ["LidAwakeHelper"]),
  ],
  targets: [
    .target(name: "LidAwakeShared"),
    .executableTarget(
      name: "LidAwakeApp",
      dependencies: ["LidAwakeShared"],
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("IOKit"),
      ]
    ),
    .executableTarget(
      name: "LidAwakeHelper",
      dependencies: ["LidAwakeShared"],
      linkerSettings: [.linkedFramework("IOKit")]
    ),
    .testTarget(name: "LidAwakeSharedTests", dependencies: ["LidAwakeShared"]),
  ]
)
