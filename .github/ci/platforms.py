"""Choose platform builds from all paths in a PR or main push."""
import os
import subprocess
from pathlib import Path


ALL = {"linux", "windows", "macos"}
DESKTOP = {"linux", "windows"}


def route(path):
    """Return affected build jobs and whether the installed product can change."""
    if path.endswith(".md") or path.startswith("vendor/jscpd/"):
        return set(), False
    if path.startswith(("native/macos/", "crates/drill-swift/")):
        return {"macos"}, "/tests/" not in path
    if path in {"scripts/build-swift-ui.py", "src/assets/drill-macos.icns", "src/assets/roots_mac.txt"}:
        return {"macos"}, True
    if path.startswith(("scripts/package-macos", "scripts/sign-macos", "scripts/macos-dmg/")):
        return {"macos"}, True
    if path.endswith(".command") or path in {"scripts/launcher-env.sh", "scripts/bench-swift-ui.py"}:
        return {"macos"}, False
    if path in {"Makefile", ".github/workflows/rust.yml", ".github/ci/platforms.py",
                ".github/ci/test_platforms.py", "crates/drill-core/src/test_directory.rs",
                "scripts/bench-clean-build.py", "scripts/bench-linker.py"}:
        return ALL, False
    if path in {"Cargo.toml", "Cargo.lock", "rust-toolchain.toml", "src/main.rs"} or path.startswith(".cargo/"):
        return ALL, True
    if path == "tests/packaged_appimage.rs" or path.startswith((
        "tests/native_ui/linux", "scripts/test-native-ui-linux", "scripts/test-appimage-open",
    )):
        return {"linux"}, False
    if path in {"scripts/test-wine-linux.sh", "scripts/wine-runner.sh", "scripts/test-native-ui-windows.ps1"}:
        return {"windows"}, False
    if path == ".github/ci/ubuntu-apt-get.sh" or path.startswith("tests/"):
        return DESKTOP, False
    if path in {"scripts/package-linux.sh", "src/assets/roots_linux.txt"}:
        return {"linux"}, True
    if path in {"build.rs", "src/assets/drill.ico", "src/assets/drill.rc", "src/assets/drill.manifest",
                "src/assets/roots_windows.txt"}:
        return {"windows"}, True
    if path.startswith("crates/drill-gtk/"):
        return {"linux"}, "/tests/" not in path and not path.endswith("_test.c")
    if path.startswith("crates/drill-windows/"):
        return {"windows"}, "/tests/" not in path
    if path.startswith("crates/drill-desktop/"):
        return DESKTOP, "/tests/" not in path
    if path.startswith(("tools/exe-icon-wasm/", "tools/appimage-icon-wasm/")):
        # Linux rebuilds the guests. Every desktop embeds the Wasm and exercises its fixtures.
        return (ALL if "/tests/fixtures/" in path else {"linux"}), False
    if path in {"LICENSE", "scripts/wait-release-artifacts.sh"} or path.startswith(("src/", "crates/")):
        return ALL, "/tests/" not in path
    return set(), False


def select(paths, event):
    platforms = set()
    product = False
    for path in paths:
        jobs, shipped = route(path)
        platforms.update(jobs)
        product |= shipped
    release = event == "push" and product
    # Every release takes all three downloads from the same tested commit.
    if release or event == "workflow_dispatch":
        platforms.update(ALL)
    return platforms, release


def scans_source(path):
    if path.startswith("vendor/jscpd/"):
        return True
    if path.startswith("vendor/") or path.rsplit("/", 1)[-1] == "Cargo.lock":
        return False
    if path in {"src/assets/wordsalpha.txt", "tools/website-ci/package-lock.json",
                "src/assets/drill.svg", "src/assets/drill-macos.svg", "docs/drill.svg"}:
        return False
    return not path.lower().endswith((".png", ".ico", ".icns", ".ttf", ".woff", ".woff2",
                                      ".wasm", ".exe", ".appimage", ".bin", ".jpg", ".webp"))


def changed_paths(event):
    if event == "workflow_dispatch":
        return []
    before, after = os.environ["BEFORE"], os.environ["AFTER"]
    if event == "pull_request":
        before = subprocess.check_output(["git", "merge-base", before, after], text=True).strip()
    if set(before) == {"0"}:  # A newly created branch has no previous tree.
        before = subprocess.check_output(["git", "hash-object", "-t", "tree", "--stdin"], input=b"").decode().strip()
    raw = subprocess.check_output(["git", "diff", "--no-renames", "--name-only", "-z", before, after, "--"])
    return [os.fsdecode(path) for path in raw.split(b"\0") if path]


def check_outputs(paths, event):
    platforms, release = select(paths, event)
    values = {platform: platform in platforms for platform in sorted(ALL)}
    values["release"] = release
    values["duplicates"] = bool(platforms) or any(map(scans_source, paths))
    return values


if __name__ == "__main__":
    event = os.environ["GITHUB_EVENT_NAME"]
    values = check_outputs(changed_paths(event), event)
    outputs = "".join(f"{key}={str(value).lower()}\n" for key, value in values.items())
    print(outputs, end="")
    with Path(os.environ["GITHUB_OUTPUT"]).open("a") as output:
        output.write(outputs)
