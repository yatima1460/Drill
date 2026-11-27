//! Host-side bundle access for the Wine launcher on macOS. The native Mac UI
//! obtains its application icons through NSWorkspace.
#![allow(unsafe_code)]

use std::ffi::{CStr, CString, OsStr};
use std::fs::{File, OpenOptions};
use std::mem::MaybeUninit;
use std::os::fd::{AsRawFd, FromRawFd};
use std::os::macos::fs::MetadataExt;
use std::os::unix::{ffi::OsStrExt, fs::OpenOptionsExt};
use std::path::{Component, Path};

const DATALESS: u32 = 0x4000_0000; // SF_DATALESS (sys/stat.h)
const OPEN_FLAGS: i32 = libc::O_NOFOLLOW | libc::O_NONBLOCK | libc::O_CLOEXEC | libc::O_NOCTTY;

pub(super) fn contents(path: &Path, is_current: &impl Fn() -> bool) -> Option<File> {
    let path = std::path::absolute(path).ok()?;
    if !on_local_mount(&path)? {
        return None;
    }
    let mut parent = OpenOptions::new()
        .read(true)
        .custom_flags(OPEN_FLAGS | libc::O_DIRECTORY)
        .open("/")
        .ok()?;
    for part in path.components() {
        if !is_current() {
            return None;
        }
        match part {
            Component::Normal(name) => parent = open_child(&parent, name, true, false)?,
            Component::RootDir | Component::CurDir => (),
            _ => return None,
        }
    }
    child(&parent, OsStr::new("Contents"), true)
}

// Consult the cached mount table before walking. This avoids looking inside
// automount triggers and known network volumes just to classify the bundle.
fn on_local_mount(path: &Path) -> Option<bool> {
    // SAFETY: a null, zero-length output requests just the count.
    let count =
        usize::try_from(unsafe { libc::getfsstat(std::ptr::null_mut(), 0, libc::MNT_NOWAIT) })
            .ok()?;
    if count > 512 {
        return None;
    }
    let mut mounts = Vec::<MaybeUninit<libc::statfs>>::with_capacity(count + 1);
    // SAFETY: the buffer's capacity in bytes is passed to getfsstat, and only
    // the returned number of initialized records is inspected.
    let filled = usize::try_from(unsafe {
        libc::getfsstat(
            mounts.as_mut_ptr().cast(),
            (mounts.capacity() * size_of::<libc::statfs>())
                .try_into()
                .ok()?,
            libc::MNT_NOWAIT,
        )
    })
    .ok()?;
    if filled != count {
        return None;
    }
    // SAFETY: getfsstat initialized these records.
    let records =
        unsafe { std::slice::from_raw_parts(mounts.as_ptr().cast::<libc::statfs>(), filled) };
    for entry in records {
        // SAFETY: statfs mount/type fields are fixed-size, NUL-terminated names.
        let mount = unsafe { CStr::from_ptr(entry.f_mntonname.as_ptr()) };
        let mount_path = Path::new(OsStr::from_bytes(mount.to_bytes()));
        if mount_path != path && mount_path.starts_with(path) {
            return Some(false);
        }
        if path.starts_with(mount_path) && !local_disk(entry) {
            return Some(false);
        }
    }
    Some(true)
}

fn local_disk(volume: &libc::statfs) -> bool {
    // SAFETY: f_fstypename is a fixed-size, NUL-terminated filesystem name.
    let kind = unsafe { CStr::from_ptr(volume.f_fstypename.as_ptr()) }.to_bytes();
    volume.f_flags & libc::MNT_LOCAL as u32 != 0
        && matches!(kind, b"apfs" | b"hfs" | b"msdos" | b"exfat")
}

pub(super) fn child(parent: &File, name: &OsStr, directory: bool) -> Option<File> {
    open_child(parent, name, directory, true)
}

fn open_child(parent: &File, name: &OsStr, directory: bool, same_mount: bool) -> Option<File> {
    if !matches!(Path::new(name).components().next(), Some(Component::Normal(part)) if part == name)
    {
        return None;
    }
    let name = CString::new(name.as_bytes()).ok()?;
    let parent_fd = parent.as_raw_fd();
    let mut stat = MaybeUninit::uninit();
    // SAFETY: the parent and one-component C string are live. fstatat writes a
    // complete stat structure on success and inspects the link itself.
    if unsafe {
        libc::fstatat(
            parent_fd,
            name.as_ptr(),
            stat.as_mut_ptr(),
            libc::AT_SYMLINK_NOFOLLOW,
        )
    } != 0
    {
        return None;
    }
    // SAFETY: fstatat returned success and initialized every field.
    let stat = unsafe { stat.assume_init() };
    let kind = if directory {
        libc::S_IFDIR
    } else {
        libc::S_IFREG
    };
    let crosses_mount = stat.st_dev as u64 != parent.metadata().ok()?.st_dev();
    if stat.st_mode & libc::S_IFMT != kind
        || stat.st_flags & DATALESS != 0
        || (same_mount && crosses_mount)
    {
        return None;
    }
    let flags = if directory {
        OPEN_FLAGS | libc::O_DIRECTORY
    } else {
        OPEN_FLAGS
    };
    // SAFETY: openat is relative to the verified parent, with no creation.
    let fd = unsafe { libc::openat(parent_fd, name.as_ptr(), flags) };
    if fd < 0 {
        return None;
    }
    // SAFETY: openat returned a new owned descriptor.
    let file = unsafe { File::from_raw_fd(fd) };
    if crosses_mount {
        let mut volume = MaybeUninit::<libc::statfs>::uninit();
        // SAFETY: file remains open, and fstatfs initializes volume on success.
        if unsafe { libc::fstatfs(fd, volume.as_mut_ptr()) } != 0 {
            return None;
        }
        // SAFETY: the successful fstatfs call initialized this record.
        let volume = unsafe { volume.assume_init() };
        if !local_disk(&volume) {
            return None;
        }
    }
    let meta = file.metadata().ok()?;
    (meta.st_dev() == stat.st_dev as u64
        && meta.st_ino() == stat.st_ino
        && meta.st_mode() & u32::from(libc::S_IFMT) == u32::from(kind)
        && meta.st_flags() & DATALESS == 0)
        .then_some(file)
}
