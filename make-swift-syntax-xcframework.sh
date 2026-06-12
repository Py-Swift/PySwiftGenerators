#!/usr/bin/env bash
#
# make-swift-syntax-xcframework.sh
#
# Builds swift-syntax ONCE into a single `SwiftSyntaxWrapper.xcframework`
# (macOS arm64 + x86_64, which is all a macro plugin ever needs, since
# macros execute on the host machine — never on iOS).
#
# The trick (same as sjavora/swift-syntax-xcframeworks):
#   1. Clone swift-syntax at an exact tag.
#   2. Inject a `SwiftSyntaxWrapper` target that `@_exported import`s every
#      module a macro needs, exposed as a *dynamic* library product so that
#      Xcode wraps it in a .framework.
#   3. Archive with BUILD_LIBRARY_FOR_DISTRIBUTION=YES (emits .swiftinterface
#      so the binary survives compiler upgrades).
#   4. Copy ALL generated .swiftmodule bundles into the framework's Modules/
#      folder, so `import SwiftSyntax`, `import SwiftSyntaxMacros`, etc. keep
#      resolving in consumer code without any source changes.
#   5. xcodebuild -create-xcframework.
#
# Usage:
#   ./make-swift-syntax-xcframework.sh [swift-syntax-tag] [output-dir]
#
#   ./make-swift-syntax-xcframework.sh 601.0.1 ./Binaries
#
# Requirements: macOS, full Xcode installed (xcodebuild), git.

set -euo pipefail

# ------------------------------------------------------------------ config --
SWIFT_SYNTAX_TAG="${1:-601.0.1}"
OUTPUT_DIR="$(cd "$(dirname "${2:-./Binaries}")" 2>/dev/null && pwd)/$(basename "${2:-./Binaries}")"
WRAPPER_NAME="SwiftSyntaxWrapper"
SWIFT_SYNTAX_REPO="https://github.com/swiftlang/swift-syntax.git"

# Modules re-exported by the wrapper. These cover everything a typical macro
# package imports. (Internal helper modules like _SwiftSyntaxCShims and the
# SwiftSyntax60x version-marker modules are pulled in automatically and their
# swiftmodules are copied in step 4 regardless.)
MODULES=(
  SwiftBasicFormat
  SwiftCompilerPlugin
  SwiftCompilerPluginMessageHandling
  SwiftDiagnostics
  SwiftIfConfig
  SwiftOperators
  SwiftParser
  SwiftParserDiagnostics
  SwiftSyntax
  SwiftSyntaxBuilder
  SwiftSyntaxMacroExpansion
  SwiftSyntaxMacros
)

WORK_DIR="$(mktemp -d /tmp/swift-syntax-xcfw.XXXXXX)"
CHECKOUT_DIR="$WORK_DIR/swift-syntax"
DERIVED_DATA="$WORK_DIR/DerivedData"
NATIVE_ARCHIVE="$WORK_DIR/macos-native.xcarchive"
CROSS_FW_DIR="$WORK_DIR/cross-framework"  # manually constructed for the cross-compiled arch

HOST_ARCH="$(uname -m)"   # arm64 or x86_64
if [[ "$HOST_ARCH" == "arm64" ]]; then
  NATIVE_XCODE_ARCH="arm64"
  CROSS_ARCH="x86_64"
else
  NATIVE_XCODE_ARCH="x86_64"
  CROSS_ARCH="arm64"
fi

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

echo "==> swift-syntax tag : $SWIFT_SYNTAX_TAG"
echo "==> output directory : $OUTPUT_DIR"
echo "==> work directory   : $WORK_DIR"

# ------------------------------------------------- 1. clone swift-syntax ----
echo "==> Cloning swift-syntax @ $SWIFT_SYNTAX_TAG ..."
git clone --quiet --depth 1 --branch "$SWIFT_SYNTAX_TAG" \
  "$SWIFT_SYNTAX_REPO" "$CHECKOUT_DIR"

# ------------------------------------- 2. inject the wrapper target ---------
echo "==> Injecting $WRAPPER_NAME target ..."

WRAPPER_SRC_DIR="$CHECKOUT_DIR/Sources/$WRAPPER_NAME"
mkdir -p "$WRAPPER_SRC_DIR"

{
  echo "// Auto-generated. Re-exports every swift-syntax module a macro needs."
  for m in "${MODULES[@]}"; do
    echo "@_exported import $m"
  done
} > "$WRAPPER_SRC_DIR/Exports.swift"

# Package.swift declares `let package = Package(...)` — appending Swift code
# that mutates it afterwards is the least fragile way to patch it.
{
  echo ""
  echo "// ---- injected by make-swift-syntax-xcframework.sh ----"
  echo "package.targets.append("
  echo "    .target("
  echo "        name: \"$WRAPPER_NAME\","
  echo "        dependencies: ["
  for m in "${MODULES[@]}"; do
    echo "            \"$m\","
  done
  echo "        ],"
  echo "        path: \"Sources/$WRAPPER_NAME\""
  echo "    )"
  echo ")"
  echo "package.products.append("
  echo "    .library(name: \"$WRAPPER_NAME\", type: .dynamic, targets: [\"$WRAPPER_NAME\"])"
  echo ")"
} >> "$CHECKOUT_DIR/Package.swift"

# ----------------------------------------------- 3a. archive native arch -----
# xcodebuild only sees the native macOS arch as a valid destination.
# Use "platform=macOS" (no arch override) — picks the native arch automatically.
echo "==> Archiving (macOS, $NATIVE_XCODE_ARCH via xcodebuild) — this is the slow part ..."
(
  cd "$CHECKOUT_DIR"
  xcodebuild archive \
    -scheme "$WRAPPER_NAME" \
    -configuration Release \
    -destination "platform=macOS" \
    -archivePath "$NATIVE_ARCHIVE" \
    -derivedDataPath "$DERIVED_DATA/native" \
    ARCHS="$NATIVE_XCODE_ARCH" \
    ONLY_ACTIVE_ARCH=YES \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SWIFT_VERIFY_EMITTED_MODULE_INTERFACE=NO \
    SWIFT_VERSION=5
)

# ----------------------------------------------- 3b. cross-compile other arch -
# xcodebuild can't target the other arch (no simulator/device destination for
# it), but `swift build --arch` cross-compiles fine.  We emit module interfaces
# so the binary survives compiler upgrades, then manually wrap it as a framework.
echo "==> Cross-compiling (macOS, $CROSS_ARCH via swift build) ..."
CROSS_BUILD_DIR="$WORK_DIR/cross-build"
(
  cd "$CHECKOUT_DIR"
  swift build \
    -c release \
    --arch "$CROSS_ARCH" \
    --scratch-path "$CROSS_BUILD_DIR" \
    -Xswiftc -enable-library-evolution \
    -Xswiftc -emit-module-interface \
    -Xswiftc -swift-version -Xswiftc 5
)

# Construct a .framework directory from the swift build output so
# xcodebuild -create-xcframework can consume it alongside the xcodebuild archive.
echo "==> Wrapping cross-compiled slice into a framework ..."
CROSS_RELEASE="$CROSS_BUILD_DIR/$CROSS_ARCH-apple-macosx/release"
CROSS_FW="$CROSS_FW_DIR/$WRAPPER_NAME.framework"
mkdir -p "$CROSS_FW/Modules"

# Copy the dylib (framework binary must have the framework's name, no lib prefix)
cp "$CROSS_RELEASE/lib${WRAPPER_NAME}.dylib" "$CROSS_FW/$WRAPPER_NAME"
install_name_tool -id "@rpath/$WRAPPER_NAME.framework/$WRAPPER_NAME" \
                  "$CROSS_FW/$WRAPPER_NAME"

# Info.plist (minimal — Xcode just needs CFBundleIdentifier + version)
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.swiftlang.${WRAPPER_NAME}" \
  -c "Add :CFBundleName string ${WRAPPER_NAME}" \
  -c "Add :CFBundleVersion string 1" \
  -c "Add :CFBundleShortVersionString string 1.0" \
  -c "Add :CFBundlePackageType string FMWK" \
  -c "Add :MinimumOSVersion string 11.0" \
  "$CROSS_FW/Info.plist"

# Copy all .swiftmodule bundles produced by the cross-compile
while IFS= read -r module_dir; do
  name="$(basename "$module_dir")"
  [[ -e "$CROSS_FW/Modules/$name" ]] && continue
  cp -R "$module_dir" "$CROSS_FW/Modules/"
  echo "    [$CROSS_ARCH] + $name"
done < <(find "$CROSS_BUILD_DIR" -type d -name "*.swiftmodule" -path "*release*" | sort -u)

# ------------------------------------ 4. locate native framework + copy swiftmodules --
echo "==> Locating native framework ..."
NATIVE_FW="$(find "$NATIVE_ARCHIVE" "$DERIVED_DATA/native" \
  -type d -name "$WRAPPER_NAME.framework" -not -path "*Intermediates*" \
  2>/dev/null | head -n 1)"

[[ -n "$NATIVE_FW" ]] || { echo "ERROR: native framework not found in archive." >&2; exit 1; }
echo "    native ($NATIVE_XCODE_ARCH): $NATIVE_FW"

mkdir -p "$NATIVE_FW/Modules"
echo "==> Copying all generated .swiftmodule bundles into native framework ..."
while IFS= read -r module_dir; do
  name="$(basename "$module_dir")"
  [[ -e "$NATIVE_FW/Modules/$name" ]] && continue
  cp -R "$module_dir" "$NATIVE_FW/Modules/"
  echo "    [$NATIVE_XCODE_ARCH] + $name"
done < <(find "$DERIVED_DATA/native" -type d -name "*.swiftmodule" -path "*Release*" | sort -u)

# ----------------------------------------------- 5. create the xcframework --
# Use a *library-type* xcframework (dylib + headers dir) rather than a framework
# bundle.  This is the only structure where both SPM CLI and Xcode add
# -I <slice_dir>/Headers to the compiler, making ALL bundled .swiftmodule bundles
# findable (SPM CLI and Xcode both add -I <HeadersPath> for library xcframeworks,
# but only SPM CLI adds -I <slice_dir> for framework xcframeworks).

echo "==> Lipo-ing slices into universal dylib ..."
UNIVERSAL_DYLIB="$WORK_DIR/$WRAPPER_NAME.dylib"
lipo -create \
  "$NATIVE_FW/$WRAPPER_NAME" \
  "$CROSS_FW/$WRAPPER_NAME" \
  -output "$UNIVERSAL_DYLIB"
install_name_tool -id "@rpath/$WRAPPER_NAME.dylib" "$UNIVERSAL_DYLIB"

# Assemble the Headers/ dir: merge swiftmodule bundles from both builds + C headers.
echo "==> Assembling Headers/ directory ..."
HEADERS_DIR="$WORK_DIR/Headers"
mkdir -p "$HEADERS_DIR"

for fw in "$NATIVE_FW" "$CROSS_FW"; do
  while IFS= read -r module_dir; do
    name="$(basename "$module_dir")"
    if [[ -e "$HEADERS_DIR/$name" ]]; then
      cp -n "$module_dir"/* "$HEADERS_DIR/$name/" 2>/dev/null || true
    else
      cp -R "$module_dir" "$HEADERS_DIR/"
      echo "    + $name"
    fi
  done < <(find "$fw/Modules" -type d -name "*.swiftmodule" 2>/dev/null)
done

# _SwiftSyntaxCShims C headers + module.modulemap alongside the swiftmodule bundles.
cp "$CHECKOUT_DIR/Sources/_SwiftSyntaxCShims/include/_includes.h"         "$HEADERS_DIR/"
cp "$CHECKOUT_DIR/Sources/_SwiftSyntaxCShims/include/AtomicBool.h"        "$HEADERS_DIR/"
cp "$CHECKOUT_DIR/Sources/_SwiftSyntaxCShims/include/swiftsyntax_errno.h" "$HEADERS_DIR/"
cp "$CHECKOUT_DIR/Sources/_SwiftSyntaxCShims/include/swiftsyntax_stdio.h" "$HEADERS_DIR/"
cat > "$HEADERS_DIR/module.modulemap" <<'MODULEMAP'
module _SwiftSyntaxCShims {
  header "_includes.h"
  header "AtomicBool.h"
  header "swiftsyntax_errno.h"
  header "swiftsyntax_stdio.h"
  export *
}
MODULEMAP

echo "==> Creating XCFramework (library type) ..."
mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_DIR/$WRAPPER_NAME.xcframework"

xcodebuild -create-xcframework \
  -library "$UNIVERSAL_DYLIB" \
  -headers "$HEADERS_DIR" \
  -output "$OUTPUT_DIR/$WRAPPER_NAME.xcframework"

# Optional: zip + checksum, in case you'd rather host it on a GitHub release
# than commit the binary into the repo (recommended — it's large).
(
  cd "$OUTPUT_DIR"
  rm -f "$WRAPPER_NAME.xcframework.zip"
  ditto -c -k --keepParent \
    "$WRAPPER_NAME.xcframework" "$WRAPPER_NAME.xcframework.zip"
  echo ""
  echo "==> Done."
  echo "    XCFramework : $OUTPUT_DIR/$WRAPPER_NAME.xcframework"
  echo "    Zip         : $OUTPUT_DIR/$WRAPPER_NAME.xcframework.zip"
  echo -n "    Checksum    : "
  swift package compute-checksum "$WRAPPER_NAME.xcframework.zip"
)

cat <<'EOF'

Next steps in your macro package (e.g. PySwiftGenerators):

  1. Drop the swift-syntax package dependency.
  2. Add:   .binaryTarget(name: "SwiftSyntaxWrapper",
                          path: "Binaries/SwiftSyntaxWrapper.xcframework")
  3. In every target that used swift-syntax products, replace
     .product(name: "Swift...", package: "swift-syntax")
     with the single dependency "SwiftSyntaxWrapper".
  4. Source files keep their existing `import SwiftSyntaxMacros` etc. — the
     module interfaces ship inside the framework. No code changes needed.
EOF
