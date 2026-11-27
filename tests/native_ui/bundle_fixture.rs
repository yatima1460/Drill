//! Stage the checked-in bundles on the test filesystem selected by TMPDIR.
//! A container's source checkout may reside on an overlay with remote backing.
use std::fs;
use std::path::{Path, PathBuf};

pub(super) fn stage(root: &Path) -> PathBuf {
    let source =
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../../tests/native_ui/fixtures/mac-bundles");
    let staged = root.canonicalize().unwrap().join("mac-bundles");
    for name in ["Jade.app", "Carmine.app", "Missing.app"] {
        let contents = source.join(name).join("Contents");
        let destination = staged.join(name).join("Contents");
        fs::create_dir_all(&destination).unwrap();
        fs::copy(contents.join("Info.plist"), destination.join("Info.plist")).unwrap();
        if name != "Missing.app" {
            let icon = Path::new("Resources/TestIcon.icns");
            fs::create_dir(destination.join("Resources")).unwrap();
            fs::copy(contents.join(icon), destination.join(icon)).unwrap();
        }
    }
    staged
}
