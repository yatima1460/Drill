//! Pin each name with O_PATH before opening any bundle data. A search may cross
//! local mount points to reach the bundle, but resources must stay on its mount.
use std::ffi::{CStr, CString, OsStr};
use std::fs::File;
use std::io::Read;
use std::os::fd::{AsRawFd, FromRawFd, RawFd};
use std::os::unix::ffi::OsStrExt;
use std::path::{Component, Path};

#[derive(Clone, Copy, PartialEq, Eq)]
enum MountAccess {
    Local,
    CachedTraversal,
}

pub(super) fn contents(path: &Path, is_current: &impl Fn() -> bool) -> Option<File> {
    let start = if path.is_absolute() { c"/" } else { c"." };
    let parent = open_path(libc::AT_FDCWD, start, MountAccess::Local)?;
    let mount = mount_id(&parent)?;
    walk(parent, path, mount, mount_access(mount)?, is_current)
}

fn walk(
    mut parent: File,
    path: &Path,
    mut mount: u64,
    mut access: MountAccess,
    is_current: &impl Fn() -> bool,
) -> Option<File> {
    for component in path.components() {
        if !is_current() {
            return None;
        }
        let name = match component {
            Component::RootDir | Component::CurDir => continue,
            Component::Normal(name) => name,
            _ => return None,
        };
        let next = lookup(&parent, name, access)?;
        let next_mount = mount_id(&next)?;
        if next_mount != mount {
            access = mount_access(next_mount)?;
        }
        if access == MountAccess::Local && !next.metadata().ok()?.is_dir() {
            return None;
        }
        parent = next;
        mount = next_mount;
    }
    if access != MountAccess::Local {
        return None;
    }
    child(&parent, OsStr::new("Contents"), true)
}

pub(super) fn child(parent: &File, name: &OsStr, directory: bool) -> Option<File> {
    let entry = lookup(parent, name, MountAccess::Local)?;
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

fn lookup(parent: &File, name: &OsStr, access: MountAccess) -> Option<File> {
    if !matches!(Path::new(name).components().next(), Some(Component::Normal(part)) if part == name)
    {
        return None;
    }
    open_path(
        parent.as_raw_fd(),
        &CString::new(name.as_bytes()).ok()?,
        access,
    )
}

#[allow(unsafe_code)]
fn open_path(parent: RawFd, name: &CStr, access: MountAccess) -> Option<File> {
    // O_PATH has no read/device-open side effects and does not trigger a final
    // automount. O_NOFOLLOW pins the symlink itself, which the type check rejects.
    let flags = libc::O_PATH | libc::O_NOFOLLOW | libc::O_CLOEXEC;
    let fd = match access {
        // SAFETY: name is NUL terminated, parent is live (or AT_FDCWD), no O_CREAT.
        MountAccess::Local => unsafe { libc::openat(parent, name.as_ptr(), flags) },
        MountAccess::CachedTraversal => {
            // Overlay lower layers can be remote. Reach mounted local storage
            // using cached dentries only. EAGAIN or an unsupported syscall
            // leaves the fallback icon in place.
            // SAFETY: zero is valid for all open_how fields and future padding.
            let mut how: libc::open_how = unsafe { std::mem::zeroed() };
            how.flags = flags as u64;
            how.resolve = libc::RESOLVE_CACHED | libc::RESOLVE_NO_SYMLINKS;
            // SAFETY: the same path/descriptor contract applies, and how is
            // initialized and remains valid for its supplied size.
            unsafe {
                libc::syscall(
                    libc::SYS_openat2,
                    parent,
                    name.as_ptr(),
                    &how,
                    size_of_val(&how),
                ) as i32
            }
        }
    };
    // SAFETY: a successful open transfers sole ownership of this descriptor.
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

fn mount_access(id: u64) -> Option<MountAccess> {
    let mounts = proc_record("/proc/self/mountinfo", 1024 * 1024)?;
    let id = id.to_string();
    let line = mounts
        .split(|&b| b == b'\n')
        .find(|line| line.split(|&b| b == b' ').next() == Some(id.as_bytes()))?;
    let kind = line
        .split(|&b| b == b' ')
        .skip_while(|field| *field != b"-")
        .nth(1)?;
    match kind {
        b"overlay" | b"devtmpfs" => Some(MountAccess::CachedTraversal),
        b"ext2" | b"ext3" | b"ext4" | b"xfs" | b"btrfs" | b"f2fs" | b"zfs" | b"bcachefs"
        | b"vfat" | b"exfat" | b"ntfs3" | b"hfsplus" | b"tmpfs" | b"ramfs" | b"squashfs"
        | b"erofs" | b"iso9660" | b"udf" => Some(MountAccess::Local),
        _ => None,
    }
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reaches_tmpfs_through_a_cached_ancestor() {
        // /dev/shm is a separate writable tmpfs in the standard Linux desktop
        // and container layouts. Chroots can legitimately omit that mount.
        let (Ok(dev), Ok(shm)) = (File::open("/dev"), File::open("/dev/shm")) else {
            return;
        };
        let dev_mount = mount_id(&dev).unwrap();
        let shm_mount = mount_id(&shm).unwrap();
        if dev_mount == shm_mount || mount_access(shm_mount) != Some(MountAccess::Local) {
            return;
        }
        let fixture = crate::test_directory::private_temp_dir_in(Path::new("/dev/shm"));
        let relative = Path::new("shm")
            .join(fixture.path().file_name().unwrap())
            .join("Example.app");
        std::fs::create_dir_all(Path::new("/dev").join(&relative).join("Contents")).unwrap();

        // Pin /dev/shm above so the lookup is cached. Unsupported kernels or
        // seccomp profiles cannot offer this optional transition.
        if open_path(dev.as_raw_fd(), c"shm", MountAccess::CachedTraversal).is_none() {
            let error = std::io::Error::last_os_error();
            if matches!(
                error.raw_os_error(),
                Some(libc::ENOSYS | libc::EINVAL | libc::EPERM)
            ) {
                return;
            }
            panic!("cached tmpfs lookup failed: {error}");
        }
        assert!(walk(
            dev,
            &relative,
            dev_mount,
            MountAccess::CachedTraversal,
            &|| true
        )
        .is_some());
    }

    #[test]
    fn overlay_cannot_supply_bundle_contents() {
        let fixture = crate::test_directory::private_temp_dir();
        std::fs::create_dir(fixture.path().join("Contents")).unwrap();
        let bundle = File::open(fixture.path()).unwrap();
        let mount = mount_id(&bundle).unwrap();
        for (access, readable) in [
            (MountAccess::Local, true),
            (MountAccess::CachedTraversal, false),
        ] {
            let contents = walk(
                bundle.try_clone().unwrap(),
                Path::new(""),
                mount,
                access,
                &|| true,
            );
            assert_eq!(contents.is_some(), readable);
        }
    }
}
