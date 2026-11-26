#!/usr/bin/env python3
"""Time offline release builds of one or more native Drill checkouts."""
import argparse
import json
import os
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import sys
import tempfile
import time


def output(command, cwd, **kwargs):
    return subprocess.check_output(command, cwd=cwd, text=True, **kwargs).strip()


def measure(checkout, cargo, jobs):
    with tempfile.TemporaryDirectory(prefix="drill-clean-build-") as scratch:
        target = Path(scratch) / "target"
        env = dict(os.environ, CARGO_TARGET_DIR=str(target), CARGO_INCREMENTAL="0",
                   RUSTC_WRAPPER="", RUSTC_WORKSPACE_WRAPPER="")
        subprocess.run([cargo, "clean", "--target-dir", str(target)], cwd=checkout,
                       env=env, check=True)
        if target.exists() and any(target.iterdir()):
            raise RuntimeError(f"Target directory still contains artifacts: {target}")
        cmd = [cargo, "build", "--release", "--frozen", "--jobs", str(jobs),
               "-p", "drill", "--bin", "drill", "--message-format=json-render-diagnostics"]
        with tempfile.TemporaryFile(mode="w+") as messages:
            start = time.perf_counter()
            subprocess.run(cmd, cwd=checkout, env=env, stdout=messages, check=True)
            elapsed = time.perf_counter() - start
            messages.seek(0)
            artifacts = [m for m in map(json.loads, messages) if m.get("reason") == "compiler-artifact"]
        if not artifacts or any(m["fresh"] for m in artifacts):
            raise RuntimeError("Cargo did not compile every reported unit from scratch")
        binary, = {m["executable"] for m in artifacts if m["target"]["name"] == "drill" and m["executable"]}
        return {"seconds": round(elapsed, 3), "compiled_units": len(artifacts),
                "compiled_packages": len({m["package_id"] for m in artifacts}),
                "version": output([binary, "--version"], checkout, timeout=10)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checkouts", nargs="*", type=Path, default=[Path.cwd()])
    parser.add_argument("--runs", type=int, default=5, help="clean builds per checkout")
    parser.add_argument("--jobs", type=int, required=True, help="Cargo parallelism for every build")
    args = parser.parse_args()
    if min(args.runs, args.jobs) < 1:
        parser.error("runs and jobs must be positive")
    cargo = shutil.which("cargo")
    if not cargo:
        parser.error("cargo must be on PATH")
    checkouts = [p.resolve() for p in args.checkouts]
    if len(set(checkouts)) != len(checkouts):
        parser.error("specify each checkout once")
    results = {}
    versions = set()
    for path in checkouts:
        if output(["git", "status", "--porcelain"], path):
            parser.error(f"commit or stash changes before benchmarking {path}")
        compiler = output(["rustc", "-vV"], path)
        versions.add((compiler, output([cargo, "-V"], path)))
        results[path] = {"path": str(path), "commit": output(["git", "rev-parse", "HEAD"], path),
                         "samples": []}
    if len(versions) != 1:
        parser.error("use the same Rust and Cargo versions for all checkouts")
    for index in range(args.runs):
        # Alternate the order to reduce bias from system load and temperature.
        for path in (checkouts if index % 2 == 0 else reversed(checkouts)):
            sample = measure(path, cargo, args.jobs)
            results[path]["samples"].append(sample)
            print(f"{path.name} {index + 1}/{args.runs}: {sample['seconds']:.3f} s", file=sys.stderr)
    for result in results.values():
        result["median_seconds"] = statistics.median(s["seconds"] for s in result["samples"])
    rustc, cargo_version = versions.pop()
    print(json.dumps({"platform": platform.platform(), "jobs": args.jobs, "rustc": rustc,
                      "cargo": cargo_version, "checkouts": list(results.values())}, indent=2))


if __name__ == "__main__":
    main()
