// swift-tools-version: 5.9
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "PySwiftGenerators",
    platforms: [.macOS(.v11), .iOS(.v13)],
    products: [
        .library(name: "PySwiftGenerators", targets: ["PySwiftGenerators"]),
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
                "PSG_WrapperInfo",
                "PSG_WrapperInternal",
            ],
            path: "Sources_dev/PySwiftGenerators"
        ),
        .target(name: "PSG_WrapperInfo", path: "Sources_dev/PyWrapperInfo"),
        .target(
            name: "PSG_WrapperInternal",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "PSG_WrapperInfo",
            ],
            path: "Sources_dev/PyWrapperInternal"
        ),
    ]
)
