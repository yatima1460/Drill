import unittest
from platforms import ALL, check_outputs, scans_source, select


class PlatformRouting(unittest.TestCase):
    def test_web_and_notes(self):
        paths = ["docs/styles.css", "docs/index.html", "docs/releases.js", "docs/screenshot.png",
                 "docs/rust-migration.md", "README.md", "tools/website-ci/package.json",
                 ".github/ci/prepare-jscpd.sh", ".github/ci/windows_resource_smoke.py"]
        for event in ("push", "pull_request"):
            self.assertEqual(select(paths, event), (set(), False))

    def test_mixed_changes(self):
        paths = ["docs/styles.css"] * 3500 + ["src/permissions.rs"]
        self.assertEqual(select(paths, "pull_request"), ({"macos"}, False))
        self.assertEqual(select(paths, "push"), (ALL, True))

    def test_platform_and_test_inputs(self):
        for path, targets in [
            ("src/assets/roots_windows.txt", {"windows"}),
            ("src/linux_apps.rs", {"linux"}),
            ("src/native_menu.rs", {"windows", "macos"}),
            ("src/icon_sample.rs", {"windows", "macos"}),
            ("Cargo.lock", ALL),
            ("vendor/file_icon_provider/src/implementation/macos.rs", {"macos"}),
            ("tools/exe-icon-wasm/tests/fixtures/README.md", set()),
            ("src/result_emoji.rs", ALL),
            ("tools/exe-icon-wasm/src/lib.rs", {"linux"}),
            ("tools/exe-icon-wasm/tests/fixtures/icon-pe64.exe", ALL),
        ]:
            with self.subTest(path=path):
                self.assertEqual(select([path], "pull_request"), (targets, False))
        for path in ["tests/native_ui.rs", ".github/workflows/rust.yml", ".github/ci/platforms.py",
                     "crates/drill-core/src/test_directory.rs"]:
            self.assertEqual(select([path], "push"), (ALL, False))

    def test_duplicate_scan_inputs(self):
        for path in ["docs/index.html", "docs/styles.css", "docs/releases.js", "README.md", "src/new.rs"]:
            self.assertTrue(scans_source(path), path)
        for path in ["docs/screenshot.png", "Cargo.lock", "vendor/eframe/src/lib.rs"]:
            self.assertFalse(scans_source(path), path)

    def test_native_adapter_routing(self):
        for path, targets in [
            ("crates/drill-gtk/src/linux_app_catalog.c", {"linux"}),
            ("crates/drill-macos/build.rs", {"macos"}),
            ("crates/drill-macos/src/file_icon.m", {"macos"}),
            ("crates/drill-windows/src/lib.rs", {"windows"}),
            ("src/platform_icon.rs", ALL),
            ("src/platform_icon/linux.rs", {"linux"}),
            ("src/platform_icon/macos.rs", {"macos"}),
            ("src/platform_icon/windows.rs", {"windows"}),
            ("src/platform_icon/windows.c", {"windows"}),
            ("src/platform_icon/shared.rs", ALL),
            ("src/native_menu/macos.rs", {"macos"}),
            ("src/native_menu/windows.rs", {"windows"}),
        ]:
            with self.subTest(path=path):
                self.assertEqual(select([path], "pull_request"), (targets, False))
                self.assertEqual(select([path], "push"), (ALL, True))
        for path, targets in [
            ("crates/drill-gtk/src/desktop_theme_test.c", {"linux"}),
            ("crates/drill-macos/tests/clipboard.m", {"macos"}),
            ("scripts/test-macos-clipboard.sh", {"macos"}),
            ("tests/macos_clipboard.rs", {"macos"}),
            ("examples/macos_opengl.rs", {"macos"}),
        ]:
            with self.subTest(path=path):
                for event in ("pull_request", "push"):
                    self.assertEqual(select([path], event), (targets, False))

    def test_manual_validation(self):
        self.assertEqual(select([], "workflow_dispatch"), (ALL, False))
        self.assertTrue(check_outputs([], "workflow_dispatch")["swift_ui"])

    def test_swift_prototype_does_not_trigger_desktop_packaging_or_release(self):
        for path in ["native/macos/App.swift", "native/macos/tests/WindowTests.swift",
                     "crates/drill-swift/Cargo.toml", "crates/drill-swift/src/lib.rs",
                     "scripts/build-swift-ui.py", "scripts/bench-swift-ui.py"]:
            for event in ("pull_request", "push"):
                with self.subTest(path=path, event=event):
                    outputs = check_outputs([path], event)
                    self.assertEqual({key for key, value in outputs.items() if value},
                                     {"swift_ui", "duplicates"} if event == "pull_request" else {"duplicates"})

    def test_shared_inputs_validate_swift_prototype(self):
        for path in ["Makefile", "Cargo.lock", "Cargo.toml", "rust-toolchain.toml",
                     ".github/workflows/rust.yml", ".github/ci/platforms.py",
                     "crates/drill-core/src/lib.rs", "crates/drill-query/src/lib.rs",
                     "crates/drill-icons/src/lib.rs", "src/assets/wordsalpha.txt",
                     "src/assets/roots_mac.txt", "src/assets/drill-macos.icns",
                     "src/assets/exe-icon.wasm", "src/assets/appimage-icon.wasm",
                     "tools/exe-icon-wasm/tests/fixtures/icon-pe32.exe"]:
            self.assertTrue(check_outputs([path], "pull_request")["swift_ui"], path)
        outputs = check_outputs(["native/macos/App.swift", "crates/drill-icons/src/lib.rs"], "push")
        self.assertEqual({key for key, value in outputs.items() if value}, ALL | {"release", "duplicates"})
        for path in ["crates/drill-windows/src/menu.c", "src/main.rs", "docs/index.html",
                     "crates/drill-swift/README.md", "native/macos/README.md"]:
            self.assertFalse(check_outputs([path], "pull_request")["swift_ui"], path)

    def test_duplicate_gate_runs_for_every_platform_build(self):
        for event in ("pull_request", "push"):
            for path in ("Cargo.lock", "vendor/eframe/src/lib.rs", "src/assets/drill.ico"):
                self.assertTrue(check_outputs([path], event)["duplicates"], path)
            self.assertFalse(check_outputs(["docs/screenshot.png"], event)["duplicates"])
        self.assertTrue(check_outputs([], "workflow_dispatch")["duplicates"])


if __name__ == "__main__":
    unittest.main()
