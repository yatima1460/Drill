"""Select the optional macOS egui frontend when timing a Rust desktop checkout."""
import json
import platform
import subprocess


def egui_features(cargo, checkout, env):
    if platform.system() != "Darwin":
        return []
    metadata = subprocess.check_output(
        [cargo, "metadata", "--frozen", "--no-deps", "--format-version", "1"],
        cwd=checkout, env=env, text=True,
    )
    package, = (p for p in json.loads(metadata)["packages"] if p["name"] == "drill")
    return ["--features", "macos-egui"] if "macos-egui" in package["features"] else []
