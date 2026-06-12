// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "PySwiftGenerators",
    platforms: [.macOS(.v11), .iOS(.v13)],
    products: [
        .library(name: "PySwiftGenerators", targets: ["PySwiftGeneratorsPlugin"]),
        //.library(name: "SwiftSyntaxWrapper", targets: ["SwiftSyntaxWrapper"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "601.0.1"),
    ],
    targets: [
        //.binaryTarget(
         //   name: "SwiftSyntaxWrapper",
         //   path: "Binaries/SwiftSyntaxWrapper.xcframework"
        //),
        .macro(
            name: "PySwiftGenerators",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                //"SwiftSyntaxWrapper",
                "PSGWrapperInfo",
                "PyWrapperInternal",
            ],
            path: "Sources_dev/PySwiftGenerators"
        ),
        .target(
            name: "PySwiftGeneratorsPlugin",
            dependencies: ["PySwiftGenerators"],
            path: "Sources_dev/PySwiftGeneratorsPlugin"
        ),
        .target(name: "PSGWrapperInfo", path: "Sources_dev/PyWrapperInfo"),
        .target(
            name: "PyWrapperInternal",
            dependencies: [
                //"SwiftSyntaxWrapper",
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                "PSGWrapperInfo",
            ],
            path: "Sources_dev/PyWrapperInternal"
        ),
    ]
)
