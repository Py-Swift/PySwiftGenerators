To distribute a Swift Macro as a pre-compiled binary rather than compiling swift-syntax from source every time, you must wrap your macro executable inside an **Artifact Bundle (.artifactbundle)**. This prevents long build times for your users. \[1, 2\]

Here is the complete guide and file structure to configure MyMacro.artifactbundle for a Swift Package.

## **1\. Directory Structure**

Your .artifactbundle is a standard directory with a specific naming convention and an internal layout. It must contain your compiled macro executables alongside an info.json manifest. \[3, 4\]

`MyMacro.artifactbundle/`  
`├── info.json`  
`└── MyMacro-v1.0.0-macos/`  
    `└── bin/`  
        `└── MyMacro`

## **2\. The Manifest File (info.json) \[5\]**

Place this info.json file exactly at the root of your MyMacro.artifactbundle/ folder. It tells Swift Package Manager (SwiftPM) which executable to load based on the host user's architecture. \[1, 3\]

`{`  
  `"schemaVersion": "1.0",`  
  `"artifacts": {`  
    `"MyMacro": {`  
      `"version": "1.0.0",`  
      `"type": "executable",`  
      `"variants": [`  
        `{`  
          `"path": "MyMacro-v1.0.0-macos/bin/MyMacro",`  
          `"supportedTriples": [`  
            `"arm64-apple-macosx",`  
            `"x86_64-apple-macosx"`  
          `]`  
        `}`  
      `]`  
    `}`  
  `}`  
`}`

* **type**: Must be set to "executable" for macro plugins.  
* **supportedTriples**: Outlines the architectures your pre-compiled binary supports. The example above targets Universal macOS setups (Apple Silicon and Intel). \[2, 6, 7, 8\]

## **3\. Zip the Bundle \[1\]**

SwiftPM requires remote binary targets to be compressed into a .zip archive. Run this terminal command from the directory containing your bundle: \[1, 9\]

`zip -r MyMacro.artifactbundle.zip MyMacro.artifactbundle`

*Note: Compute the SHA256 checksum of your zip file, as you will need it for the package manifest:*

`swift package compute-checksum MyMacro.artifactbundle.zip`

## **4\. Consumer Package Configuration (Package.swift)**

In the Swift Package that exposes the macro to end-users, reference your hosted artifact bundle using .binaryTarget. Map it to your macro target using the precompiledHostCompilerPlugin dependency requirement. \[1\]

*`// swift-tools-version: 6.0`*  
`import PackageDescription`

`let package = Package(`  
    `name: "MyMacroClient",`  
    `products: [`  
        `.library(`  
            `name: "MyMacroClient",`  
            `targets: ["MyMacroClient"]`  
        `),`  
    `],`  
    `targets: [`  
        `// 1. Declare the Macro user-facing interface`  
        `.target(`  
            `name: "MyMacroClient",`  
            `dependencies: ["MyMacroBinary"]`  
        `),`  
          
        `// 2. Reference the remote pre-compiled Artifact Bundle`  
        `.binaryTarget(`  
            `name: "MyMacroBinary",`  
            `url: "https://github.com",`  
            `checksum: "PASTE_YOUR_COMPUTED_SHA256_CHECKSUM_HERE"`  
        `)`  
    `]`  
`)`

## **Important Architecture Checklist**

* **Host vs Target**: Macros execute on the developer's computer (the host) inside compiler memory, not on the user's mobile device. This means your artifact bundle binaries must strictly be compiled for **macOS** (macosx), even if your package library targets iOS, tvOS, or watchOS. \[6, 10, 11, 12\]  
* **Sandbox**: SwiftPM runs binary targets within a strict sandbox. Ensure your pre-compiled macro binary doesn't try to read or write files outside of its immediate execution scope.

Are you looking to generate this bundle **locally** for testing purposes, or are you preparing a **CI/CD automation script** to build and archive it automatically?

\[1\] [https://github.com](https://github.com/apple/swift-evolution/blob/main/proposals/0305-swiftpm-binary-target-improvements.md)  
\[2\] [https://swiftpackageindex.com](https://swiftpackageindex.com/freddi-kit/ArtifactBundleGen)  
\[3\] [https://www.reddit.com](https://www.reddit.com/r/swift/comments/1ovt9ma/what_is_the_right_way_to_setup_a_artifactbundle/)  
\[4\] [https://github.com](https://github.com/apple/swift-evolution/blob/main/proposals/0305-swiftpm-binary-target-improvements.md)  
\[5\] [https://github.com](https://github.com/apple/swift-evolution/blob/main/proposals/0305-swiftpm-binary-target-improvements.md)  
\[6\] [https://forums.swift.org](https://forums.swift.org/t/how-to-import-macros-using-methods-other-than-swiftpm/66645)  
\[7\] [https://github.com](https://github.com/apple/swift-package-manager/issues/7362)  
\[8\] [https://www.smileykeith.com](https://www.smileykeith.com/2020/12/24/swiftpm-cross-compile/)  
\[9\] [https://forums.swift.org](https://forums.swift.org/t/swift-pm-artifact-bundles-and-macos-notorization-stabling/76140)  
\[10\] [https://github.com](https://github.com/tuist/tuist/issues/6135)  
\[11\] [https://www.polpiella.dev](https://www.polpiella.dev/binary-targets-in-modern-swift-packages)  
\[12\] [https://github.com](https://github.com/pointfreeco/swift-snapshot-testing/discussions/602)