//! Open one component at a time relative to verified directory handles.
#![allow(unsafe_code)]

use std::ffi::{c_void, OsStr};
use std::fs::File;
use std::os::windows::ffi::OsStrExt;
use std::os::windows::fs::MetadataExt;
use std::os::windows::io::{AsRawHandle, FromRawHandle};
use std::path::{Component, Path, Prefix};
use std::ptr;
use windows_sys::Win32::Foundation::{
    HANDLE, INVALID_HANDLE_VALUE, OBJ_CASE_INSENSITIVE, STATUS_SUCCESS, UNICODE_STRING,
};
use windows_sys::Win32::Storage::FileSystem::{
    GetFileType, QueryDosDeviceW, ReOpenFile, FILE_ATTRIBUTE_OFFLINE,
    FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS, FILE_ATTRIBUTE_RECALL_ON_OPEN,
    FILE_ATTRIBUTE_REPARSE_POINT, FILE_FLAG_OPEN_NO_RECALL, FILE_FLAG_OPEN_REPARSE_POINT,
    FILE_READ_ATTRIBUTES, FILE_READ_DATA, FILE_SHARE_DELETE, FILE_SHARE_READ, FILE_SHARE_WRITE,
    FILE_TRAVERSE, FILE_TYPE_DISK, SYNCHRONIZE,
};

// winternl.h. NtOpenFile accepts a directory handle and a counted component name.
#[repr(C)]
struct ObjectAttributes {
    length: u32,
    root: HANDLE,
    name: *const UNICODE_STRING,
    attributes: u32,
    security: *const c_void,
    quality_of_service: *const c_void,
}

#[repr(C)]
struct IoStatusBlock {
    status_or_pointer: usize,
    information: usize,
}

#[link(name = "ntdll")]
unsafe extern "system" {
    fn NtOpenFile(
        file: *mut HANDLE,
        access: u32,
        attributes: *const ObjectAttributes,
        status: *mut IoStatusBlock,
        share: u32,
        options: u32,
    ) -> i32;
}

const FILE_DIRECTORY_FILE: u32 = 1;
const FILE_SYNCHRONOUS_IO_NONALERT: u32 = 0x20;
const FILE_NON_DIRECTORY_FILE: u32 = 0x40;
const FILE_OPEN_REPARSE_POINT: u32 = 0x0020_0000;
const FILE_OPEN_NO_RECALL: u32 = 0x0040_0000;

pub(super) fn contents(bundle: &Path, is_current: &impl Fn() -> bool) -> Option<File> {
    let mut parts = bundle.components();
    let Component::Prefix(prefix) = parts.next()? else {
        return None;
    };
    let (Prefix::Disk(letter) | Prefix::VerbatimDisk(letter)) = prefix.kind() else {
        return None;
    };
    if !letter.is_ascii_alphabetic() || parts.next()? != Component::RootDir {
        return None;
    }
    let mut parent = local_root(letter)?;
    for part in parts {
        if !is_current() {
            return None;
        }
        let Component::Normal(name) = part else {
            return None;
        };
        parent = child(&parent, name, true)?;
    }
    if !is_current() {
        return None;
    }
    child(&parent, OsStr::new("Contents"), true)
}

fn local_root(letter: u8) -> Option<File> {
    let drive = [u16::from(letter), u16::from(b':'), 0];
    let mut target = [0_u16; 512];
    // SAFETY: drive is terminated and the output is sized in UTF-16 units.
    let used = unsafe { QueryDosDeviceW(drive.as_ptr(), target.as_mut_ptr(), target.len() as u32) };
    let current = target
        .get(..used as usize)?
        .split(|&unit| unit == 0)
        .next()?;
    let mut root = disk_volume_root(current)?;
    open(ptr::null_mut(), &mut root, true)
}

fn disk_volume_root(current: &[u16]) -> Option<Vec<u16>> {
    let device = String::from_utf16(current).ok()?;
    // Only accept a direct disk-volume device. Use its captured kernel name through
    // the root open, so changing a drive mapping cannot redirect us to a server.
    let number = device.strip_prefix(r"\Device\HarddiskVolume")?;
    if number.is_empty() || !number.bytes().all(|byte| byte.is_ascii_digit()) {
        return None;
    }
    let mut root = current.to_vec();
    root.push(u16::from(b'\\'));
    Some(root)
}

pub(super) fn child(parent: &File, name: &OsStr, directory: bool) -> Option<File> {
    let mut wide = component_name(name)?;
    open(parent.as_raw_handle(), &mut wide, directory)
}

fn component_name(name: &OsStr) -> Option<Vec<u16>> {
    let wide: Vec<_> = name.encode_wide().take(256).collect();
    // NT counts UTF-16 units and preserves unpaired surrogates. The lossy view
    // only identifies forbidden characters and DOS aliases; open the original units.
    (wide.len() <= 255 && super::safe_component_text(&name.to_string_lossy())).then_some(wide)
}

fn open(parent: HANDLE, name: &mut [u16], directory: bool) -> Option<File> {
    let length = u16::try_from(size_of_val(name)).ok()?;
    let name = UNICODE_STRING {
        Length: length,
        MaximumLength: length,
        Buffer: name.as_mut_ptr(),
    };
    let attrs = ObjectAttributes {
        length: size_of::<ObjectAttributes>() as u32,
        root: parent,
        name: &name,
        attributes: OBJ_CASE_INSENSITIVE,
        security: ptr::null(),
        quality_of_service: ptr::null(),
    };
    let mut status = IoStatusBlock {
        status_or_pointer: 0,
        information: 0,
    };
    let mut handle = ptr::null_mut();
    let (access, kind) = if directory {
        (FILE_TRAVERSE, FILE_DIRECTORY_FILE)
    } else {
        (0, FILE_NON_DIRECTORY_FILE)
    };
    // SAFETY: all referenced storage and the optional parent handle outlive this
    // synchronous call. The OS writes an owned handle only on success.
    let result = unsafe {
        NtOpenFile(
            &mut handle,
            access | FILE_READ_ATTRIBUTES | SYNCHRONIZE,
            &attrs,
            &mut status,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            kind | FILE_SYNCHRONOUS_IO_NONALERT | FILE_OPEN_REPARSE_POINT | FILE_OPEN_NO_RECALL,
        )
    };
    if result != STATUS_SUCCESS {
        return None;
    }
    // SAFETY: the successful open transferred this handle to us.
    let file = unsafe { File::from_raw_handle(handle) };
    // SAFETY: file owns this live handle.
    if unsafe { GetFileType(handle) } != FILE_TYPE_DISK {
        return None;
    }
    let meta = file.metadata().ok()?;
    let excluded = FILE_ATTRIBUTE_OFFLINE
        | FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS
        | FILE_ATTRIBUTE_RECALL_ON_OPEN
        | FILE_ATTRIBUTE_REPARSE_POINT;
    if meta.file_attributes() & excluded != 0 || meta.is_dir() != directory {
        return None;
    }
    if directory {
        return Some(file);
    }
    // SAFETY: upgrade only this verified, live disk file for reading. Keeping the
    // metadata handle alive prevents a name replacement from redirecting the read.
    let reader = unsafe {
        ReOpenFile(
            file.as_raw_handle(),
            FILE_READ_DATA | FILE_READ_ATTRIBUTES,
            FILE_SHARE_READ,
            FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_OPEN_NO_RECALL,
        )
    };
    if reader == INVALID_HANDLE_VALUE {
        return None;
    }
    // SAFETY: ReOpenFile returned a second, owned handle.
    Some(unsafe { File::from_raw_handle(reader) })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::OsString;
    use std::os::windows::ffi::OsStringExt;

    #[test]
    fn counts_native_units_and_preserves_unpaired_surrogates() {
        let mut units = vec![0x754c; 254];
        units.push(0xd800);
        assert_eq!(
            component_name(&OsString::from_wide(&units)),
            Some(units.clone())
        );
        units.push(0x754c);
        assert!(component_name(&OsString::from_wide(&units)).is_none());
        assert!(component_name(OsStr::new(&"🌳".repeat(128))).is_none());
        for name in ["CON .txt", "lpt²", "PRN", "a:b", r"a\b", "..", "name."] {
            assert!(component_name(OsStr::new(name)).is_none(), "{name}");
        }
    }

    #[test]
    fn opens_contents_below_a_long_unicode_directory() {
        let temp = crate::test_directory::private_temp_dir();
        let ancestor = "界".repeat(128);
        let app = temp
            .path()
            .canonicalize()
            .unwrap()
            .join(ancestor)
            .join("Example.app");
        std::fs::create_dir_all(app.join("Contents")).unwrap();
        assert!(contents(&app, &|| true).is_some());
    }

    #[test]
    fn accepts_only_direct_nt_disk_volume_targets() {
        fn root(target: &str) -> Option<String> {
            let wide: Vec<_> = target.encode_utf16().collect();
            String::from_utf16(&disk_volume_root(&wide)?).ok()
        }
        assert_eq!(
            root(r"\Device\HarddiskVolume12").as_deref(),
            Some(r"\Device\HarddiskVolume12\")
        );
        for target in [
            r"\Device\Mup\host\share",
            r"\Device\NamedPipe",
            r"\??\C:\alias",
            r"\Device\HarddiskVolume1\directory",
            r"\Device\HarddiskVolume",
        ] {
            assert!(root(target).is_none(), "{target}");
        }
    }

    #[test]
    fn rejects_unc_device_and_drive_relative_paths() {
        for path in [
            r"\\server\share\Example.app",
            r"\\?\UNC\server\share\Example.app",
            r"\\.\pipe\Example.app",
            r"C:Example.app",
        ] {
            assert!(contents(Path::new(path), &|| true).is_none(), "{path}");
        }
    }
}
