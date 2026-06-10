// swift-tools-version: 5.9
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "PySwiftGenerators",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [],
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
