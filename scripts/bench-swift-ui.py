#!/usr/bin/env python3
"""Compare a clean egui baseline against the native macOS SwiftUI app."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import time




# Rotate build positions, then reverse the order for the next three rounds.
ORDERS = [
    ("egui", "swift-cold", "swift-warm"), ("swift-cold", "swift-warm", "egui"),
    ("swift-warm", "egui", "swift-cold"), ("egui", "swift-warm", "swift-cold"),
    ("swift-warm", "swift-cold", "egui"), ("swift-cold", "egui", "swift-warm"),
]
GUESTS = ("exe-icon.wasm", "appimage-icon.wasm")


def output(command, checkout, **kwargs):
    return subprocess.check_output(command, cwd=checkout, text=True, **kwargs).strip()


def revision(checkout):
    if output(["git", "status", "--porcelain"], checkout):
        raise ValueError(f"benchmark requires a clean checkout: {checkout}")
    return output(["git", "rev-parse", "HEAD"], checkout)


def rust_tools(checkout, env):
    return (output(["rustc", "-vV"], checkout, env=env),
            output([env["CARGO"], "-V"], checkout, env=env))


def sdk_module_count(cache):
    return sum(path.suffix in {".pcm", ".swiftmodule"} for path in cache.rglob("*"))


def validate_executable(binary, cwd, arch, guests):
    version = output([binary, "--version"], cwd, timeout=10)
    if not re.search(r"\bDrill\b.*\d+\.\d+\.\d+", version, re.IGNORECASE):
        raise ValueError(f"unexpected version from {binary}: {version}")
    if output(["xcrun", "lipo", "-archs", binary], cwd) != arch:
        raise ValueError(f"{binary} does not match native host architecture {arch}")
    build = output(["xcrun", "vtool", "-show-build", binary], cwd)
    if not re.search(r"^\s*platform MACOS$", build, re.M) or not re.search(
            r"^\s*minos 13\.0(?:\.0)?$", build, re.M):
        raise ValueError(f"expected a macOS 13.0 executable, got {build}")
    data = binary.read_bytes()
    if any(guest not in data for guest in guests.values()):
        raise ValueError(f"missing embedded Wasm decoder in {binary}")
    return {"executable_bytes": len(data), "version": version}


def baseline_features(cargo, checkout, env):
    metadata = json.loads(output([cargo, "metadata", "--frozen", "--no-deps", "--format-version", "1"], checkout, env=env))
    package, = (p for p in metadata["packages"] if p["name"] == "drill")
    if not any(dep["name"] == "eframe" for dep in package["dependencies"]):
        raise ValueError("choose a historical egui checkout for the baseline")
    return ["--features", "macos-egui"] if "macos-egui" in package["features"] else []


def egui_build(checkout, dest, jobs, env):
    target = dest / "cargo"
    env = dict(env, CARGO_TARGET_DIR=str(target), CARGO_BUILD_BUILD_DIR=str(target))
    command = [env["CARGO"], "build", "--release", "--frozen", "-p", "drill", "--bin", "drill",
               "--jobs", str(jobs), "--timings", "--message-format=json-render-diagnostics"]
    command.extend(baseline_features(env["CARGO"], checkout, env))
    start = time.perf_counter()
    messages = output(command, checkout, env=env)
    elapsed = time.perf_counter() - start
    artifacts = [m for m in map(json.loads, messages.splitlines()) if m["reason"] == "compiler-artifact"]
    binary, = (Path(m["executable"]) for m in artifacts if m["target"]["name"] == "drill" and m["executable"])
    targets = {m["target"]["name"] for m in artifacts}
    if not {"wasmi", "eframe", "egui", "drill_core", "drill_query"} <= targets:
        raise ValueError("egui build did not compile the expected renderer, search and Wasm crates")
    return elapsed, binary, {"cargo_units": len(artifacts), "fresh_units": sum(m["fresh"] for m in artifacts),
                             "cargo_packages": len({m["package_id"] for m in artifacts})}


def swift_build(checkout, dest, cache, jobs, env, arch):
    command = [sys.executable, "scripts/build-swift-ui.py", "--output-dir", str(dest),
               "--module-cache", str(cache), "--jobs", str(jobs), "--timings"]
    start = time.perf_counter()
    subprocess.run(command, cwd=checkout, env=env, stdout=subprocess.DEVNULL, check=True)
    elapsed = time.perf_counter() - start
    stats = json.loads((dest / "build-stats.json").read_text())
    names = set(stats["package_names"])
    if not {"wasmi", "drill-core", "drill-query"} <= names or {"egui", "eframe"} & names:
        raise ValueError("SwiftUI build must include the search and Wasm crates and exclude egui/eframe")
    if stats["swift_target"] != f"{arch}-apple-macosx13.0":
        raise ValueError(f"unexpected Swift target: {stats['swift_target']}")
    # The checkout under test owns the bundle and executable names.
    app, = dest.glob("*.app")
    with (app / "Contents/Info.plist").open("rb") as info:
        binary = app / "Contents/MacOS" / plistlib.load(info)["CFBundleExecutable"]
    return elapsed, binary, stats


def measure(arm, args, env, arch, guests, warm_cache, timing_file=None):
    with tempfile.TemporaryDirectory(prefix="drill-swift-build-") as scratch:
        dest = Path(scratch)
        if arm == "egui":
            checkout = args.egui_checkout
            elapsed, binary, stats = egui_build(checkout, dest, args.jobs, env)
        else:
            checkout = args.swift_checkout
            cache = warm_cache if arm == "swift-warm" else dest / "sdk-modules"
            before = sdk_module_count(cache)
            if timing_file and arm == "swift-warm" and before == 0:
                raise ValueError("warm SDK module cache is empty")
            elapsed, binary, stats = swift_build(checkout, dest, cache, args.jobs, env, arch)
            after = sdk_module_count(cache)
            if after == 0:
                raise ValueError(f"Swift did not use the specified module cache: {cache}")
            stats.update(sdk_modules_before=before, sdk_modules_after=after)
        if not stats["cargo_units"] or stats["fresh_units"]:
            raise ValueError(f"{arm} reused a Cargo build artifact")
        stats.update(validate_executable(binary, checkout, arch, guests), seconds=elapsed)
        if timing_file:
            shutil.copyfile(dest / "cargo/cargo-timings/cargo-timing.html", timing_file)
            stats["cargo_timing"] = timing_file.name
        return stats


def write_report(report, results):
    # An interruption leaves the last completed sample readable.
    with tempfile.NamedTemporaryFile(mode="w", dir=report.parent, delete=False) as pending:
        json.dump(results, pending, indent=2)
        pending.write("\n")
    os.replace(pending.name, report)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("egui_checkout", type=Path)
    parser.add_argument("swift_checkout", type=Path, help="may be the same checkout as egui")
    parser.add_argument("--runs", type=int, default=4, help="samples per arm (default: 4)")
    parser.add_argument("--jobs", type=int, default=12)
    parser.add_argument("--output", required=True, type=Path, help="new JSON file, outside the checkouts or ignored")
    args = parser.parse_args()
    if sys.platform != "darwin" or min(args.jobs, args.runs) < 1:
        parser.error("use macOS and positive job/run counts")
    args.egui_checkout, args.swift_checkout = args.egui_checkout.resolve(), args.swift_checkout.resolve()
    checkouts = {"egui": args.egui_checkout, "swift": args.swift_checkout}
    commits = {name: revision(path) for name, path in checkouts.items()}
    env = dict(os.environ, CARGO_NET_OFFLINE="true", CARGO_INCREMENTAL="0", RUSTC_WRAPPER="",
               RUSTC_WORKSPACE_WRAPPER="", CCACHE_DISABLE="1", SCCACHE_DISABLE="1",
               CARGO_ENCODED_RUSTFLAGS="", CARGO_PROFILE_RELEASE_OPT_LEVEL="3",
               CARGO_PROFILE_RELEASE_LTO="off", MACOSX_DEPLOYMENT_TARGET="13.0")
    env["PATH"] += os.pathsep + str(Path.home() / ".cargo/bin")
    env["CARGO"] = shutil.which("cargo", path=env["PATH"]) or ""
    if not env["CARGO"]:
        parser.error("install the workspace's pinned Rust toolchain")
    tools = {rust_tools(path, env) for path in checkouts.values()}
    if len(tools) != 1:
        parser.error("both checkouts must use identical rustc and Cargo versions")
    rustc, cargo = tools.pop()
    arch = platform.machine()
    if arch not in {"arm64", "x86_64"}:
        parser.error(f"unsupported macOS architecture: {arch}")
    rust_arch = "aarch64" if arch == "arm64" else arch
    if f"host: {rust_arch}-apple-darwin" not in rustc.splitlines():
        parser.error("rustc and the macOS process must have matching native architectures")
    if env.get("CARGO_BUILD_TARGET"):
        parser.error("unset CARGO_BUILD_TARGET to compare native builds")
    cwd = args.swift_checkout
    env["SDKROOT"] = output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], cwd)
    guests = {name: (cwd / "src/assets" / name).read_bytes() for name in GUESTS}
    if any((args.egui_checkout / "src/assets" / name).read_bytes() != value for name, value in guests.items()):
        parser.error("the two checkouts must use identical Wasm guests")

    report = args.output.resolve()
    timings = report.with_name(report.stem + "-timings")
    if report.exists() or timings.exists():
        parser.error("use a fresh output path and timings directory")
    timings.mkdir(parents=True)
    results = {
        "platform": platform.platform(), "architecture": arch, "logical_cpus": os.cpu_count(),
        "rustc": rustc, "cargo": cargo, "xcode": output(["xcodebuild", "-version"], cwd),
        "swift": output(["xcrun", "swiftc", "-version"], cwd), "macos_sdk": env["SDKROOT"],
        "release": {"rust_opt_level": 3, "rust_lto": "off", "swift_optimization": "-O",
                    "deployment_target": "13.0", "build_jobs": args.jobs},
        "checkouts": {name: {"path": str(path), "commit": commits[name]} for name, path in checkouts.items()},
        "wasm_sha256": {k: hashlib.sha256(v).hexdigest() for k, v in guests.items()},
        "timing_boundary": "Build command through linked egui executable or assembled and ad-hoc signed Swift app. "
                           "Post-build verification is excluded. Rust and Swift compilation may overlap.",
        "caches": "Every build starts with empty project outputs, offline sources, no incremental compilation "
                  "or compiler wrappers. swift-cold uses a new writable SDK module cache per build; "
                  "swift-warm reuses a dedicated primed module cache. Filesystem pages and installed SDK are shared.",
        "timings_directory": timings.name, "runs_per_arm": args.runs, "completed": False, "samples": [],
    }
    with tempfile.TemporaryDirectory(prefix="drill-warm-sdk-") as name:
        warm = Path(name)
        for arm in ("egui", "swift-warm"):
            print(f"Priming {arm} (untimed)", file=sys.stderr, flush=True)
            measure(arm, args, env, arch, guests, warm)
        for index in range(args.runs):
            for arm in ORDERS[index % len(ORDERS)]:
                filename = timings / f"round-{index + 1}-{arm}.html"
                stats = measure(arm, args, env, arch, guests, warm, filename)
                results["samples"].append(dict(stats, arm=arm, round=index + 1))
                write_report(report, results)
                print(f"Round {index + 1} {arm}: {stats['seconds']:.3f} s", file=sys.stderr, flush=True)
    if any(revision(path) != commits[name] for name, path in checkouts.items()):
        raise ValueError("a checkout changed during benchmarking")
    results["median_seconds"] = {arm: statistics.median(s["seconds"] for s in results["samples"] if s["arm"] == arm)
                                 for arm in ORDERS[0]}
    results["completed"] = True
    write_report(report, results)


if __name__ == "__main__":
    main()
