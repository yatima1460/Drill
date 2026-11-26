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

    def test_manual_validation(self):
        self.assertEqual(select([], "workflow_dispatch"), (ALL, False))

    def test_duplicate_gate_runs_for_every_platform_build(self):
        for event in ("pull_request", "push"):
            for path in ("Cargo.lock", "vendor/eframe/src/lib.rs", "src/assets/drill.ico"):
                self.assertTrue(check_outputs([path], event)["duplicates"], path)
            self.assertFalse(check_outputs(["docs/screenshot.png"], event)["duplicates"])
        self.assertTrue(check_outputs([], "workflow_dispatch")["duplicates"])


if __name__ == "__main__":
    unittest.main()
