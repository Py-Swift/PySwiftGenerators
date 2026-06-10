You are completely right, and I messed up. I apologize for the frustration. I changed the subject instead of translating the exact points you needed.

Here is the exact translation of the two fundamental mistakes in **PySwiftGenerators**, translated directly into English:

## **1\. The Package.swift still uses a .macro target**

If you look at their Package.swift, they declared the macro target like this:

.macro(  
    name: "PySwiftGeneratorsMacros",  
    dependencies: \[  
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),  
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax")  
    \]  
)

* **Why it's wrong:** The entire purpose of an .artifactbundle is to prevent the user from downloading and building swift-syntax from source. By leaving it as a .macro target, they force SwiftPM to compile everything anyway.  
* **How to fix it:** They must completely delete the .macro target and the swift-syntax dependency, replacing it entirely with a .binaryTarget that points to their zip file.

## **2\. The Sources folder and the .artifactbundle are in the same repository**

The repository currently contains the raw source code for the macro inside the Sources directory, while simultaneously trying to distribute a precompiled version via their v0.0.1 Release.

* **Why it's wrong:** SwiftPM gets completely confused when a package contains both the raw source code for a macro and a binary target under the same names. It doesn't know whether to compile the source code or use the binary.  
* **How to fix it:** The source code of the macro should live in a separate "development" repository. The public repository that users fetch should only contain a clean Package.swift pointing to the precompiled .artifactbundle.zip.

## ---

**What their Package.swift should actually look like:**

To fix it, they need to strip out the source code and change their Package.swift to look like this:

*// swift-tools-version: 5.9*  
import PackageDescription

let package \= Package(  
    name: "PySwiftGenerators",  
    platforms: \[.macOS(.v13), .iOS(.v16)\],  
    products: \[  
        .library(  
            name: "PySwiftGenerators",  
            targets: \["PySwiftGenerators"\]  
        ),  
    \],  
    dependencies: \[\], *// NO swift-syntax dependency here\!*  
    targets: \[  
        *// 1\. The public library target that users import in their code*  
        .target(  
            name: "PySwiftGenerators",  
            dependencies: \["PySwiftGeneratorsMacros"\]  
        ),  
          
        *// 2\. The precompiled macro binary fetched from GitHub Releases*  
        .binaryTarget(  
            name: "PySwiftGeneratorsMacros",  
            url: "https://github.com",  
            checksum: "THE\_ACTUAL\_COMPUTED\_CHECKSUM\_HERER"  
        )  
    \]  
)

Are you trying to **submit a Pull Request to fix their repository**, or do you just need a **workaround to make it work in your own local project** right now?