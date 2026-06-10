#!/usr/bin/env python3
"""
release.py — ship a new PySwiftGenerators release.

Usage:
    python3 release.py 0.0.2

What it does:
  1. Copies arm64 + x86_64 binaries from PySwiftKit/bin/PySwiftGenerators.artifactbundle
     into this repo's PySwiftGenerators.artifactbundle.
  2. Updates info.json version.
  3. git commit + tag + push.

No GitHub Release asset. No checksum. No manual Package.swift editing.
SwiftPM fetches the binary straight from the git tag checkout via path:.
"""

import subprocess
import sys
import shutil
import json
from pathlib import Path

HERE = Path(__file__).parent.resolve()
REPO_BUNDLE = HERE / "PySwiftGenerators.artifactbundle"
SRC_BUNDLE = HERE.parent / "PySwiftKit" / "bin" / "PySwiftGenerators.artifactbundle"
ARCHS = ["arm64-apple-macosx", "x86_64-apple-macosx"]


def run(*cmd):
    print("+", " ".join(str(c) for c in cmd))
    subprocess.run([str(c) for c in cmd], check=True, cwd=HERE)


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 release.py <version>   e.g. 0.0.2")
        sys.exit(1)
    version = sys.argv[1].lstrip("v")

    # 1. Copy fresh binaries from PySwiftKit/bin bundle
    for arch in ARCHS:
        src = SRC_BUNDLE / arch / "bin" / "PySwiftGenerators-tool"
        dst = REPO_BUNDLE / arch / "bin" / "PySwiftGenerators-tool"
        if not src.exists():
            sys.exit(f"ERROR: {src} not found — build it first with build-macro-binary.sh")
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        dst.chmod(0o755)
        print(f"Copied {arch}")

    # 2. Update info.json version
    info_path = REPO_BUNDLE / "info.json"
    info = json.loads(info_path.read_text())
    for artifact in info["artifacts"].values():
        artifact["version"] = version
    info_path.write_text(json.dumps(info, indent=2) + "\n")
    print(f"Updated info.json -> version {version}")

    # 3. Commit, tag, push
    run("git", "add", "PySwiftGenerators.artifactbundle", "Package.swift")
    run("git", "commit", "-m", f"Release {version}")
    run("git", "tag", version)
    run("git", "push", "origin", "main", "--tags")
    run("gh", "release", "create", version,
        "--repo", "Py-Swift/PySwiftGenerators",
        "--title", version,
        "--notes", f"Prebuilt macro plugin binary for macOS (arm64 + x86_64).\n\n```swift\n.package(url: \"https://github.com/Py-Swift/PySwiftGenerators\", from: \"{version}\")\n```")
    print(f"\nDone. Release {version} published.")


main()
