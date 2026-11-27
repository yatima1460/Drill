"""Choose platform builds from all paths in a PR or main push."""
import os
import subprocess
from pathlib import Path


ALL = {"linux", "windows", "macos"}
LEGACY = {"macos_legacy"}
EGUI = {"linux", "windows"} | LEGACY


def route(path):
    """Return affected build jobs and whether the installed product can change."""
    if path.endswith(".md"):
        return set(), False
    if path.startswith(("native/macos/", "crates/drill-swift/")):
        return {"macos"}, "/tests/" not in path
    if path in {"scripts/build-swift-ui.py", "src/assets/drill-macos.icns", "src/assets/roots_mac.txt"}:
        return {"macos"}, True
    if path.startswith(("scripts/package-macos", "scripts/sign-macos", "scripts/macos-dmg/")):
        return {"macos"}, True
    if path in {"scripts/bench-swift-ui.py", "scripts/bench_egui.py", "scripts/bench-clean-build.py"}:
        return {"macos"} | LEGACY, False
    if path.endswith(".command") or path == "scripts/launcher-env.sh":
        return {"macos"}, False
    if path in {"Makefile", ".github/workflows/rust.yml", ".github/ci/platforms.py",
                ".github/ci/test_platforms.py", "crates/drill-core/src/test_directory.rs"}:
        return ALL | LEGACY, False
    if path in {"Cargo.toml", "Cargo.lock", "rust-toolchain.toml"} or path.startswith(".cargo/"):
        return ALL | LEGACY, True
    if path == "src/main.rs":
        return ALL | LEGACY, True
    if path.startswith(("crates/drill-macos/", "src/assets/drill-macos", "src/permissions.rs")) or path in {
        "scripts/test-macos-clipboard.sh", "tests/macos_clipboard.rs", "examples/macos_opengl.rs",
    }:
        return LEGACY, False
    if path.startswith("tests/"):
        return EGUI, False
    if path.startswith(("scripts/test-native-ui-linux", "scripts/test-appimage-open")):
        return {"linux"}, False
    if path == "scripts/test-wine-linux.sh":
        return {"windows"}, False
    if path == ".github/ci/ubuntu-apt-get.sh":
        return {"linux", "windows"}, False
    if path in {"scripts/package-linux.sh", "src/linux_apps.rs", "src/appearance/linux.rs", "src/assets/roots_linux.txt"}:
        return {"linux"}, True
    if path in {"build.rs", "src/assets/drill.ico", "src/assets/drill.rc", "src/assets/roots_windows.txt"}:
        return {"windows"}, True
    if path in {"src/native_menu.rs", "src/icon_sample.rs"}:
        return {"windows"} | LEGACY, True
    if path.startswith("crates/drill-gtk/"):
        return {"linux"}, "/tests/" not in path and path != "crates/drill-gtk/src/desktop_theme_test.c"
    if path.startswith("crates/drill-windows/"):
        return {"windows"}, "/tests/" not in path
    if path.startswith(("tools/exe-icon-wasm/", "tools/appimage-icon-wasm/")):
        # Desktop builds embed the checked-in Wasm files. Fixtures exercise both UIs.
        return (ALL | LEGACY if "/tests/fixtures/" in path else {"linux"}), False
    if path.startswith(("src/platform_icon/", "src/native_menu/", "vendor/file_icon_provider/src/implementation/",
                        "vendor/eframe/src/native/clipboard/", "vendor/eframe/src/native/glow_context/")):
        platform = Path(path).stem
        if platform == "macos":
            return LEGACY, False
        if platform in {"linux", "windows"}:
            return {platform}, True
        return EGUI, True
    if path in {"src/assets/exe-icon.wasm", "src/assets/appimage-icon.wasm", "src/assets/wordsalpha.txt",
                "LICENSE", "scripts/wait-release-artifacts.sh"}:
        return ALL, True
    if path.startswith(("src/", "vendor/eframe/")):
        return EGUI, True
    if path.startswith(("crates/", "vendor/")):
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
    if event == "workflow_dispatch":
        platforms.update(LEGACY)
    return platforms, release


def scans_source(path):
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
    values = {platform: platform in platforms for platform in sorted(ALL | LEGACY)}
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
