//! Pin each name with O_PATH before opening any bundle data. A search may cross
//! local mount points to reach the bundle, but resources must stay on its mount.
use std::ffi::{CStr, CString, OsStr};
use std::fs::File;
use std::io::Read;
use std::os::fd::{AsRawFd, FromRawFd, RawFd};
use std::os::unix::ffi::OsStrExt;
use std::path::{Component, Path};

pub(super) fn contents(path: &Path, is_current: &impl Fn() -> bool) -> Option<File> {
    let start = if path.is_absolute() { c"/" } else { c"." };
    let mut parent = open_path(libc::AT_FDCWD, start)?;
    let mut mount = mount_id(&parent)?;
    if !local_mount(mount)? {
        return None;
    }
    for component in path.components() {
        if !is_current() {
            return None;
        }
        let name = match component {
            Component::RootDir | Component::CurDir => continue,
            Component::Normal(name) => name,
            _ => return None,
        };
        let next = lookup(&parent, name)?;
        let next_mount = mount_id(&next)?;
        if next_mount != mount && !local_mount(next_mount)? {
            return None;
        }
        if !next.metadata().ok()?.is_dir() {
            return None;
        }
        parent = next;
        mount = next_mount;
    }
    child(&parent, OsStr::new("Contents"), true)
}

pub(super) fn child(parent: &File, name: &OsStr, directory: bool) -> Option<File> {
    let entry = lookup(parent, name)?;
    if mount_id(&entry)? != mount_id(parent)? {
        return None;
    }
    let metadata = entry.metadata().ok()?;
    if directory {
        return metadata.is_dir().then_some(entry);
    }
    if !metadata.is_file() {
        return None;
    }
    // The procfs magic link addresses the pinned inode, even across renames.
    File::open(format!("/proc/self/fd/{}", entry.as_raw_fd())).ok()
}

fn lookup(parent: &File, name: &OsStr) -> Option<File> {
    if !matches!(Path::new(name).components().next(), Some(Component::Normal(part)) if part == name)
    {
        return None;
    }
    open_path(parent.as_raw_fd(), &CString::new(name.as_bytes()).ok()?)
}

#[allow(unsafe_code)]
fn open_path(parent: RawFd, name: &CStr) -> Option<File> {
    // O_PATH has no read/device-open side effects and does not trigger a final
    // automount. O_NOFOLLOW pins the symlink itself, which the type check rejects.
    // SAFETY: name is NUL terminated, parent is live (or AT_FDCWD), no O_CREAT.
    let fd = unsafe {
        libc::openat(
            parent,
            name.as_ptr(),
            libc::O_PATH | libc::O_NOFOLLOW | libc::O_CLOEXEC,
        )
    };
    // SAFETY: on success openat transfers sole ownership of this descriptor.
    (fd >= 0).then(|| unsafe { File::from_raw_fd(fd) })
}

// Inspect kernel-owned proc records before asking the filesystem about the
// entry. fstatfs on an NFS mount can itself send an RPC. Holding the descriptor
// pins the mount ID throughout this check.
fn mount_id(file: &File) -> Option<u64> {
    let data = proc_record(format!("/proc/self/fdinfo/{}", file.as_raw_fd()), 4096)?;
    let line = data
        .split(|&b| b == b'\n')
        .find_map(|line| line.strip_prefix(b"mnt_id:"))?;
    std::str::from_utf8(line).ok()?.trim().parse().ok()
}

fn local_mount(id: u64) -> Option<bool> {
    let mounts = proc_record("/proc/self/mountinfo", 1024 * 1024)?;
    let id = id.to_string();
    let line = mounts
        .split(|&b| b == b'\n')
        .find(|line| line.split(|&b| b == b' ').next() == Some(id.as_bytes()))?;
    let kind = line
        .split(|&b| b == b' ')
        .skip_while(|field| *field != b"-")
        .nth(1)?;
    Some(matches!(
        kind,
        b"ext2"
            | b"ext3"
            | b"ext4"
            | b"xfs"
            | b"btrfs"
            | b"f2fs"
            | b"zfs"
            | b"bcachefs"
            | b"vfat"
            | b"exfat"
            | b"ntfs3"
            | b"hfsplus"
            | b"tmpfs"
            | b"ramfs"
            | b"squashfs"
            | b"erofs"
            | b"iso9660"
            | b"udf"
    ))
}

fn proc_record(path: impl AsRef<Path>, limit: u64) -> Option<Vec<u8>> {
    let mut bytes = Vec::new();
    File::open(path)
        .ok()?
        .take(limit + 1)
        .read_to_end(&mut bytes)
        .ok()?;
    (bytes.len() as u64 <= limit).then_some(bytes)
}
