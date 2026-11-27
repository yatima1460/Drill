import unittest
from platforms import ALL, EGUI, LEGACY, check_outputs, scans_source, select


class PlatformRouting(unittest.TestCase):
    def test_web_and_notes(self):
        paths = ["docs/styles.css", "docs/index.html", "docs/releases.js", "docs/screenshot.png",
                 "docs/rust-migration.md", "README.md", "tools/website-ci/package.json",
                 ".github/ci/prepare-jscpd.sh", ".github/ci/windows_resource_smoke.py"]
        for event in ("push", "pull_request"):
            self.assertEqual(select(paths, event), (set(), False))

    def test_mixed_changes(self):
        paths = ["docs/styles.css"] * 3500 + ["native/macos/Permissions.swift"]
        self.assertEqual(select(paths, "pull_request"), ({"macos"}, False))
        self.assertEqual(select(paths, "push"), (ALL, True))

    def test_platform_and_test_inputs(self):
        for path, targets in [
            ("src/assets/roots_windows.txt", {"windows"}),
            ("src/linux_apps.rs", {"linux"}),
            ("src/native_menu.rs", {"windows"} | LEGACY),
            ("src/icon_sample.rs", {"windows"} | LEGACY),
            ("Cargo.lock", ALL | LEGACY),
            ("src/main.rs", ALL | LEGACY),
            ("vendor/file_icon_provider/src/implementation/macos.rs", LEGACY),
            ("tools/exe-icon-wasm/tests/fixtures/README.md", set()),
            ("src/result_emoji.rs", EGUI),
            ("tools/exe-icon-wasm/src/lib.rs", {"linux"}),
            ("tools/exe-icon-wasm/tests/fixtures/icon-pe64.exe", ALL | LEGACY),
        ]:
            with self.subTest(path=path):
                self.assertEqual(select([path], "pull_request"), (targets, False))
        self.assertEqual(select(["tests/native_ui.rs"], "push"), (EGUI, False))
        for path in [".github/workflows/rust.yml", ".github/ci/platforms.py",
                     "crates/drill-core/src/test_directory.rs"]:
            self.assertEqual(select([path], "push"), (ALL | LEGACY, False))

    def test_duplicate_scan_inputs(self):
        for path in ["docs/index.html", "docs/styles.css", "docs/releases.js", "README.md", "src/new.rs"]:
            self.assertTrue(scans_source(path), path)
        for path in ["docs/screenshot.png", "Cargo.lock", "vendor/eframe/src/lib.rs"]:
            self.assertFalse(scans_source(path), path)

    def test_native_adapter_routing(self):
        for path, targets in [
            ("crates/drill-gtk/src/linux_app_catalog.c", {"linux"}),
            ("crates/drill-windows/src/lib.rs", {"windows"}),
            ("src/platform_icon.rs", EGUI),
            ("src/platform_icon/linux.rs", {"linux"}),
            ("src/platform_icon/windows.rs", {"windows"}),
            ("src/platform_icon/windows.c", {"windows"}),
            ("src/platform_icon/shared.rs", EGUI),
            ("src/native_menu/windows.rs", {"windows"}),
        ]:
            with self.subTest(path=path):
                self.assertEqual(select([path], "pull_request"), (targets, False))
                self.assertEqual(select([path], "push"), (ALL | targets, True))
        for path, targets in [
            ("crates/drill-gtk/src/desktop_theme_test.c", {"linux"}),
            ("crates/drill-macos/build.rs", LEGACY),
            ("crates/drill-macos/src/file_icon.m", LEGACY),
            ("crates/drill-macos/tests/clipboard.m", LEGACY),
            ("vendor/eframe/src/native/glow_context/macos.rs", LEGACY),
            ("src/platform_icon/macos.rs", LEGACY),
            ("src/native_menu/macos.rs", LEGACY),
            ("src/permissions.rs", LEGACY),
            ("scripts/test-macos-clipboard.sh", LEGACY),
            ("tests/macos_clipboard.rs", LEGACY),
            ("examples/macos_opengl.rs", LEGACY),
        ]:
            with self.subTest(path=path):
                for event in ("pull_request", "push"):
                    self.assertEqual(select([path], event), (targets, False))

    def test_manual_validation(self):
        self.assertEqual(select([], "workflow_dispatch"), (ALL | LEGACY, False))

    def test_swift_product_changes_package_the_official_app(self):
        for path in ["native/macos/DrillApp.swift", "native/macos/Bridge.h", "crates/drill-swift/Cargo.toml",
                     "crates/drill-swift/include/DrillIcon.h", "crates/drill-swift/src/lib.rs",
                     "scripts/build-swift-ui.py", "src/assets/drill-macos.icns"]:
            with self.subTest(path=path):
                self.assertEqual(select([path], "pull_request"), ({"macos"}, False))
                self.assertEqual(select([path], "push"), (ALL, True))

    def test_swift_validation_only_changes(self):
        for path in ["native/macos/tests/TableChecks.swift", "crates/drill-swift/tests/search.rs",
                     "Start Drill.command", "Run UI Tests.command",
                     "scripts/launcher-env.sh"]:
            for event in ("pull_request", "push"):
                with self.subTest(path=path, event=event):
                    self.assertEqual(select([path], event), ({"macos"}, False))
        for path in ["scripts/bench-swift-ui.py", "scripts/bench_egui.py", "scripts/bench-clean-build.py"]:
            for event in ("pull_request", "push"):
                self.assertEqual(select([path], event), ({"macos"} | LEGACY, False))
        self.assertEqual(select(["Makefile"], "push"), (ALL | LEGACY, False))
        self.assertEqual(select(["native/macos/README.md", "crates/drill-swift/README.md"], "push"),
                         (set(), False))

    def test_shared_sources_and_egui_have_distinct_jobs(self):
        for path in ["crates/drill-query/src/lib.rs", "crates/drill-core/src/lib.rs",
                     "crates/drill-icons/src/lib.rs", "src/assets/exe-icon.wasm",
                     "src/assets/appimage-icon.wasm", "src/assets/wordsalpha.txt"]:
            self.assertEqual(select([path], "pull_request"), (ALL, False), path)
        for path in ["src/mod.rs", "vendor/eframe/src/lib.rs", "src/result_order.rs"]:
            self.assertEqual(select([path], "pull_request"), (EGUI, False), path)
            self.assertEqual(select([path], "push"), (ALL | LEGACY, True), path)
        outputs = check_outputs(["native/macos/SearchWindow.swift", "crates/drill-icons/src/lib.rs"], "push")
        self.assertEqual({key for key, value in outputs.items() if value}, ALL | {"release", "duplicates"})

    def test_duplicate_gate_runs_for_every_platform_build(self):
        for event in ("pull_request", "push"):
            for path in ("Cargo.lock", "vendor/eframe/src/lib.rs", "src/assets/drill.ico"):
                self.assertTrue(check_outputs([path], event)["duplicates"], path)
            self.assertFalse(check_outputs(["docs/screenshot.png"], event)["duplicates"])
        self.assertTrue(check_outputs([], "workflow_dispatch")["duplicates"])


if __name__ == "__main__":
    unittest.main()
