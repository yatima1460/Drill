use super::host::{mapped_path, serve};
use crate::test_directory::private_temp_dir;
use std::fs;
use std::io::ErrorKind;
use std::os::unix::fs::symlink;
use std::path::Path;

fn frame(path: &[u16]) -> Vec<u8> {
    let mut bytes = b"DRILICON".to_vec();
    bytes.extend((path.len() as u32).to_le_bytes());
    bytes.extend(path.iter().flat_map(|unit| unit.to_le_bytes()));
    bytes
}

#[test]
fn honors_configured_drives_and_rejects_device_and_parent_paths() {
    let temp = private_temp_dir();
    let prefix = temp.path().canonicalize().unwrap();
    let drives = prefix.join("dosdevices");
    fs::create_dir(&drives).unwrap();
    symlink("/", drives.join("z:")).unwrap();
    symlink("../drive_c", drives.join("c:")).unwrap();
    assert_eq!(
        mapped_path(&prefix, r"Z:\Applications\🎨.app"),
        Some("/Applications/🎨.app".into())
    );
    assert_eq!(
        mapped_path(&prefix, "c:/apps/X.ApP"),
        Some(prefix.join("drive_c/apps/X.ApP"))
    );
    for name in [
        r"\\server\s\x.app",
        r"\\?\C:\x.app",
        r"C:foo.app",
        r"C:\..\x.app",
        "Z://x.app",
        r"X:\a.app",
        r"C:\a:x.app",
        r"Z:\x.app\",
        r"Z:\x.exe",
    ] {
        assert_eq!(mapped_path(&prefix, name), None, "{name:?}");
    }
    symlink("../drive_c", drives.join("e:")).unwrap();
    assert!(mapped_path(&prefix, r"E:\X.app").is_none());
    for alias in ["dd:", "1:", "é:", "d::"] {
        symlink("/", drives.join(alias)).unwrap();
        assert!(mapped_path(&prefix, &format!(r"{alias}\X.app")).is_none());
    }
    fs::remove_file(drives.join("z:")).unwrap();
    assert!(mapped_path(&prefix, r"Z:\X.app").is_none());
    symlink("../../arbitrary", drives.join("z:")).unwrap();
    assert!(mapped_path(&prefix, r"Z:\X.app").is_none());
}

#[test]
fn framed_pipe_serves_repeated_requests_and_skips_symlinks() {
    let temp = private_temp_dir();
    let prefix = temp.path().canonicalize().unwrap();
    let drives = prefix.join("dosdevices");
    fs::create_dir(&drives).unwrap();
    let fixtures = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../tests/native_ui/fixtures/mac-bundles")
        .canonicalize()
        .unwrap();
    symlink(&fixtures, drives.join("z:")).unwrap();
    symlink(&fixtures, drives.join("d:")).unwrap();
    symlink("../drive_c", drives.join("c:")).unwrap();
    symlink(&fixtures, prefix.join("drive_c")).unwrap();

    let mut input = frame(&[0xD800]);
    for name in [
        r"Z:\Missing.app",
        r"D:\Carmine.app",
        r"d:\Jade.app",
        r"C:\Carmine.app",
    ] {
        input.extend(frame(&name.encode_utf16().collect::<Vec<_>>()));
    }
    let mut output = Vec::new();
    assert_eq!(
        serve(&input[..], &mut output, Some(&prefix))
            .unwrap_err()
            .kind(),
        ErrorKind::UnexpectedEof
    );
    let mut expected = vec![0, 0, 1];
    expected.extend([255, 0, 0, 255].repeat(1024));
    expected.push(1);
    expected.extend([0, 255, 0, 255].repeat(1024));
    expected.push(0);
    assert_eq!(output, expected);
}

#[test]
fn invalid_or_truncated_frame_closes_without_a_response() {
    for (magic, len, error) in [
        (b"NOISICON", 2_u32, ErrorKind::InvalidData),
        (b"DRILICON", 0, ErrorKind::InvalidData),
        (b"DRILICON", 32_768, ErrorKind::InvalidData),
        (b"DRILICON", 32_767, ErrorKind::UnexpectedEof),
    ] {
        let mut input = magic.to_vec();
        input.extend(len.to_le_bytes());
        let mut output = Vec::new();
        assert_eq!(
            serve(&input[..], &mut output, None).unwrap_err().kind(),
            error
        );
        assert!(output.is_empty());
    }
}
