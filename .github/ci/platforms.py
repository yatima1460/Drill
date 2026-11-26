"""Choose platform builds from all paths in a PR or main push."""
import os
import subprocess
from pathlib import Path


ALL = {"linux", "windows", "macos"}


def select(paths, event):
    platforms = set()
    product = False
    for path in paths:
        if path.endswith(".md") or path.startswith("vendor/jscpd/"):
            continue
        targets = ALL
        shipped = True
        if path.startswith("tests/") or path in {
            ".github/workflows/rust.yml", ".github/ci/platforms.py",
            ".github/ci/test_platforms.py", "crates/drill-core/src/test_directory.rs",
        }:
            shipped = False
        elif path.startswith(("scripts/test-native-ui-linux", "scripts/test-appimage-open", "scripts/test-wine-linux")):
            targets = {"windows"} if path == "scripts/test-wine-linux.sh" else {"linux"}
            shipped = False
        elif path.startswith(("scripts/package-macos", "scripts/sign-macos", "scripts/macos-dmg/", "src/assets/drill-macos", "src/permissions.rs", "src/assets/roots_mac.txt")):
            targets = {"macos"}
        elif path in {"scripts/package-linux.sh", "src/linux_apps.rs", "src/appearance/linux.rs", "src/assets/roots_linux.txt"}:
            targets = {"linux"}
        elif path in {"src/assets/drill.ico", "src/assets/drill.rc", "src/assets/roots_windows.txt"}:
            targets = {"windows"}
        elif path in {"src/native_menu.rs", "src/icon_sample.rs"}:
            targets = {"macos", "windows"}
        elif path.startswith(("tools/exe-icon-wasm/", "tools/appimage-icon-wasm/")):
            targets = ALL if "/tests/fixtures/" in path else {"linux"}
            shipped = False  # Desktop builds embed the checked-in Wasm files.
        elif path.startswith("vendor/file_icon_provider/src/implementation/"):
            platform = Path(path).stem
            targets = {platform} if platform in ALL else ALL
        elif not (path.startswith(("src/", "crates/", "vendor/", ".cargo/")) or path in {
            "build.rs", "Cargo.lock", "Cargo.toml", "rust-toolchain.toml", "LICENSE",
            "scripts/wait-release-artifacts.sh",
        }):
            continue
        platforms.update(targets)
        product |= shipped
    release = event == "push" and product
    # Each release takes all platform downloads from the same tested commit.
    return (ALL if release or event == "workflow_dispatch" else platforms), release


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
