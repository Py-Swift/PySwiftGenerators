// swift-tools-version: 5.9
import PackageDescription
import CompilerPluginSupport
import Foundation

// Standalone package for the PySwiftKit macro plugin.
//
// Usage modes:
//
//  1. Local path dep from PySwiftKit during development:
//       .package(path: "../PySwiftGenerators")
//
//  2. Remote source dep (compiles swift-syntax — slow first build):
//       .package(url: "https://github.com/py-swift/PySwiftGenerators", from: "1.0.0")
//
//  3. Pre-built binary dep (zero swift-syntax compile, recommended for CI):
//       .binaryTarget(
//           name: "PySwiftGenerators",
//           url: "https://github.com/py-swift/PySwiftGenerators/releases/download/v1.0.0/PySwiftGenerators.artifactbundle.zip",
//           checksum: "<checksum printed by the release workflow>"
//       )
//
// GitHub Actions releases a universal (arm64 + x86_64) .artifactbundle.zip on
// every version tag push. See .github/workflows/release.yml.

let syntaxDeps: [Target.Dependency] = [
    .product(name: "SwiftSyntaxMacros",   package: "swift-syntax"),
    .product(name: "SwiftSyntaxBuilder",  package: "swift-syntax"),
    .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
]

let package = Package(
    name: "PySwiftGenerators",
    platforms: [.macOS(.v11)],
    products: [
        // Product.macro does not exist in the PackageDescription API;
        // .library wrapping a .macro target works identically for consumers.
        .library(name: "PySwiftGenerators",  targets: ["PySwiftGenerators"]),
        .library(name: "PyWrapperInternal",  targets: ["PyWrapperInternal"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "601.0.0"),
    ],
    targets: [
        .macro(
            name: "PySwiftGenerators",
            dependencies: syntaxDeps + ["PyWrapperInternal", "PyWrapperInfo"]
        ),
        .target(
            name: "PyWrapperInternal",
            dependencies: syntaxDeps + ["PyWrapperInfo"]
        ),
        .target(name: "PyWrapperInfo"),
    ]
)
