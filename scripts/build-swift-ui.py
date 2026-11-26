#!/usr/bin/env python3
"""Build the experimental macOS search window with the Rust core and Apple SDK."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time


ROOT = Path(__file__).resolve().parent.parent
MIN_MACOS = "13.0"


def build_rust(cargo, cargo_target, jobs, timings, env):
    command = [cargo, "build", "--release", "--locked", "-p", "drill-swift", "--lib",
               "--jobs", str(jobs), "--message-format=json-render-diagnostics"]
    if cargo_target:
        command.extend(["--target", cargo_target])
    if timings:
        command.append("--timings")
    start = time.perf_counter()
    output = subprocess.check_output(command, cwd=ROOT, env=env, text=True)
    elapsed = time.perf_counter() - start
    artifacts = [row for row in map(json.loads, output.splitlines())
                 if row["reason"] == "compiler-artifact"]
    archive, = (Path(filename) for row in artifacts if row["target"]["name"] == "drill_swift"
                for filename in row["filenames"] if filename.endswith(".a"))
    packages = {row["package_id"] for row in artifacts}
    # Cargo uses the final path component when a package ID fragment has only a version.
    names = []
    for package in packages:
        source, _, fragment = package.rpartition("#")
        names.append(fragment.split("@")[0] if "@" in fragment else source.rsplit("/", 1)[-1])
    return archive, {"rust_seconds": elapsed, "cargo_packages": len(packages),
                     "package_names": sorted(names), "cargo_units": len(artifacts),
                     "fresh_units": sum(row["fresh"] for row in artifacts)}


def stage_bundle(app, executable, version):
    contents = app / "Contents"
    binaries, resources = contents / "MacOS", contents / "Resources"
    binaries.mkdir(parents=True, exist_ok=True)
    resources.mkdir(exist_ok=True)
    shutil.copy2(executable, binaries / "drill-swift")
    shutil.copy2(ROOT / "src/assets/drill-macos.icns", resources / "Drill.icns")
    info = {
        "CFBundleExecutable": "drill-swift", "CFBundleIdentifier": "software.drill.swift-preview",
        "CFBundlePackageType": "APPL", "CFBundleName": "Drill Swift",
        "CFBundleIconFile": "Drill", "CFBundleShortVersionString": version,
        "CFBundleVersion": "1", "LSMinimumSystemVersion": MIN_MACOS,
        "NSHighResolutionCapable": True,
    }
    for key, location in [("DesktopFolder", "Desktop"), ("DocumentsFolder", "Documents"),
                          ("DownloadsFolder", "Downloads"), ("NetworkVolumes", "network volumes"),
                          ("RemovableVolumes", "removable volumes"), ("FileProviderDomain", "cloud folders")]:
        info[f"NS{key}UsageDescription"] = f"Drill searches your {location} for matching filenames."
    with (contents / "Info.plist").open("wb") as file:
        plistlib.dump(info, file)
    subprocess.run(["codesign", "--force", "--sign", "-", "--timestamp=none", app], check=True)


def bundle(out, executable, version):
    # Build and sign new files before publishing so a running app keeps its mapped executable.
    installed = out / "Drill Swift.app"
    with tempfile.TemporaryDirectory(dir=out, prefix="swift-bundle-") as temporary:
        stage = Path(temporary) / installed.name
        previous = Path(temporary) / "previous.app"
        stage_bundle(stage, executable, version)
        if installed.exists():
            installed.rename(previous)
        try:
            stage.rename(installed)
        except OSError:
            if previous.exists():
                previous.rename(installed)
            raise
    return installed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "target/swift-ui")
    parser.add_argument("--module-cache", type=Path, help="Swift and Clang SDK module cache directory")
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 1)
    parser.add_argument("--arch", choices=["arm64", "x86_64"], default=platform.machine())
    parser.add_argument("--timings", action="store_true", help="save Cargo's build timing report")
    parser.add_argument("--test", action="store_true", help="build and run the native interaction suite")
    args = parser.parse_args()
    if sys.platform != "darwin" or args.jobs < 1:
        parser.error("choose a positive job count and run on macOS with the Apple SDK installed")
    cargo = os.environ.get("CARGO") or shutil.which("cargo")
    if not cargo:
        parser.error("the workspace's pinned Cargo is required")
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    # Two Make invocations may target the same Swift object and app bundle.
    import fcntl
    with (out / ".build.lock").open("a+b") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        build(args, cargo, out)


def build(args, cargo, out):
    cache = (args.module_cache or out / "sdk-modules").resolve()
    cache.mkdir(parents=True, exist_ok=True)
    sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip()
    swift_target = f"{args.arch}-apple-macosx{MIN_MACOS}"
    rust_target = {"arm64": "aarch64-apple-darwin", "x86_64": "x86_64-apple-darwin"}[args.arch]
    explicit_target = rust_target if args.arch != platform.machine() else None
    cargo_dir = str(out / "cargo")
    env = dict(os.environ, MACOSX_DEPLOYMENT_TARGET=MIN_MACOS, SDKROOT=sdk,
               CARGO_TARGET_DIR=cargo_dir, CARGO_BUILD_BUILD_DIR=cargo_dir, CARGO_INCREMENTAL="0",
               RUSTC_WRAPPER="", RUSTC_WORKSPACE_WRAPPER="")
    swiftc = ["xcrun", "--sdk", "macosx", "swiftc", "-O", "-target", swift_target, "-sdk", sdk,
              "-module-cache-path", str(cache)]
    sources = ROOT / "native/macos"
    files = sorted(sources.glob("*.swift"))
    name = "drill-swift-tests" if args.test else "drill-swift"
    object_file, executable = out / f"{name}.o", out / name
    command = [*swiftc, "-parse-as-library", "-whole-module-optimization", "-emit-object",
               "-import-objc-header", str(sources / "Bridge.h")]
    if args.test:
        command += ["-D", "DRILL_UI_TEST"]
        files.extend(sorted((sources / "tests").glob("*.swift")))
    command.extend([*files, "-o", object_file])
    # Swift can compile against the C declarations while Cargo builds their implementation.
    with ThreadPoolExecutor(max_workers=1) as pool:
        rust = pool.submit(build_rust, cargo, explicit_target, max(args.jobs - 1, 1),
                           args.timings, env)
        if args.jobs == 1:
            rust.result()
        start = time.perf_counter()
        subprocess.run(command, cwd=ROOT, env=env, check=True)
        swift_seconds = time.perf_counter() - start
        archive, stats = rust.result()
    start = time.perf_counter()
    subprocess.run([*swiftc, object_file, archive, "-Xlinker", "-dead_strip",
                    "-o", executable], cwd=ROOT, env=env, check=True)
    stats.update(swift_seconds=swift_seconds, link_seconds=time.perf_counter() - start,
                 swift_target=swift_target)
    if args.test:
        subprocess.run([executable], cwd=ROOT, check=True)
    else:
        start = time.perf_counter()
        metadata = subprocess.check_output([cargo, "metadata", "--locked", "--no-deps",
                                            "--format-version", "1"], cwd=ROOT, env=env, text=True)
        version, = (p["version"] for p in json.loads(metadata)["packages"] if p["name"] == "drill")
        app = bundle(out, executable, version)
        stats["assemble_seconds"] = time.perf_counter() - start
        (out / "build-stats.json").write_text(json.dumps(stats, indent=2) + "\n")
        print(app)


if __name__ == "__main__":
    main()
