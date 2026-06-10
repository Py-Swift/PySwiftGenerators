// swift-tools-version: 5.9
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "PySwiftGenerators",
    platforms: [.macOS(.v11), .iOS(.v13)],
    products: [
        .library(name: "PySwiftGenerators", targets: ["PySwiftGenerators"]),
    ],
    dependencies: [],
    targets: [
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
