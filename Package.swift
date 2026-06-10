// swift-tools-version: 5.9
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "PySwiftGenerators",
    platforms: [.macOS(.v11), .iOS(.v13)],
    products: [
        .library(name: "PySwiftGenerators", targets: ["PySwiftGenerators"]),
        .library(name: "PyWrapperInfo", targets: ["PyWrapperInfo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        .macro(
            name: "PySwiftGenerators",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "PyWrapperInfo",
                "PyWrapperInternal",
            ],
            path: "Sources_dev/PySwiftGenerators"
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
    ]
)
