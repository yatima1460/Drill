use std::collections::hash_map::RandomState;
use std::fs::{self, DirBuilder};
use std::hash::BuildHasher;
use std::io::ErrorKind;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

pub(super) struct TestDirectory(PathBuf);

impl TestDirectory {
    pub(super) fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for TestDirectory {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

pub(super) fn private_temp_dir() -> TestDirectory {
    private_temp_dir_in(&std::env::temp_dir())
}

pub(super) fn private_temp_dir_in(root: &Path) -> TestDirectory {
    static NEXT_ID: AtomicU64 = AtomicU64::new(0);

    let random = RandomState::new();
    let builder = DirBuilder::new();
    #[cfg(unix)]
    let builder = {
        let mut builder = builder;
        std::os::unix::fs::DirBuilderExt::mode(&mut builder, 0o700);
        builder
    };

    for _ in 0..128 {
        let id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
        let suffix = random.hash_one((std::process::id(), id));
        let path = root.join(format!("drill-test-{suffix:016x}"));
        match builder.create(&path) {
            Ok(()) => return TestDirectory(path),
            Err(error) if error.kind() == ErrorKind::AlreadyExists => continue,
            Err(error) => panic!(
                "could not create test directory {}: {error}",
                path.display()
            ),
        }
    }
    panic!("could not reserve a test directory in {}", root.display());
}
