// swift-tools-version: 5.9
import PackageDescription
import CompilerPluginSupport
import Foundation

// Xcode sets XCODE_PRODUCT_BUILD_VERSION; CLI builds do not.
// Under Xcode 26 beta, binaryTarget swiftCompilerPlugin support is broken,
// so we fall back to compiling swift-syntax from source when in Xcode.
let inXcode = ProcessInfo.processInfo.environment["XCODE_PRODUCT_BUILD_VERSION"] != nil

let swiftSyntaxDep: Package.Dependency = .package(
    url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"
)

let package = Package(
    name: "PySwiftGenerators",
    platforms: [.macOS(.v11), .iOS(.v13)],
    products: [
        .library(name: "PySwiftGenerators", targets: ["PySwiftGenerators"]),
    ],
    dependencies: inXcode ? [swiftSyntaxDep] : [],
    targets: inXcode ? [
        .macro(
            name: "PySwiftGenerators",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "PyWrapperInfo",
                "PyWrapperInternal",
            ]
        ),
        .target(name: "PyWrapperInfo", path: "Sources_dev/PyWrapperInfo"),
        .target(
            name: "PyWrapperInternal",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "PyWrapperInfo",
            ],
            path: "Sources_dev/PyWrapperInternal"
        ),
        .target(name: "PySwiftGenerators", path: "Sources_dev/PySwiftGenerators"),
    ] : [
        .macro(
            name: "PySwiftGenerators",
            dependencies: ["PySwiftGeneratorsBinary"]
        ),
        .binaryTarget(
            name: "PySwiftGeneratorsBinary",
            path: "PySwiftGenerators.artifactbundle"
        ),
    ]
)
