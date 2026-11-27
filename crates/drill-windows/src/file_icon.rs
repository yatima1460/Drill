use std::os::windows::ffi::OsStrExt;
use std::path::{Path, PathBuf};
use std::sync::{mpsc, LazyLock};

/// Native Shell bitmap in packed premultiplied RGBA.
pub struct FileIcon {
    pub width: u32,
    pub height: u32,
    pub pixels: Vec<u8>,
}

unsafe extern "C" {
    fn drill_read_shell_icon(
        path: *const u16,
        size: u16,
        pixels: *mut u8,
        capacity: usize,
        width: *mut u32,
        height: *mut u32,
    ) -> i32;
}

struct Request {
    path: PathBuf,
    size: u16,
    reply: mpsc::Sender<Option<FileIcon>>,
}

static WORKER: LazyLock<Option<mpsc::Sender<Request>>> = LazyLock::new(|| {
    let (sender, receiver) = mpsc::channel::<Request>();
    std::thread::Builder::new()
        .name("drill-shell-icons".into())
        .spawn(move || {
            for request in receiver {
                let _ = request.reply.send(load(&request.path, request.size));
            }
        })
        .ok()?;
    Some(sender)
});

pub fn file_icon(path: &Path, size: u16) -> Option<FileIcon> {
    if !(1..=256).contains(&size) {
        return None;
    }
    let (reply, receiver) = mpsc::channel();
    WORKER
        .as_ref()?
        .send(Request {
            path: path.to_owned(),
            size,
            reply,
        })
        .ok()?;
    receiver.recv().ok().flatten()
}

fn load(path: &Path, size: u16) -> Option<FileIcon> {
    // The Shell can return a generic icon or resolve a namespace item even
    // when the filesystem path is missing.
    if !path.exists() {
        return None;
    }
    let mut path: Vec<_> = path.as_os_str().encode_wide().collect();
    if path.is_empty() || path.contains(&0) {
        return None;
    }
    path.push(0);
    let mut pixels = vec![0; usize::from(size).pow(2) * 4];
    let mut width = 0;
    let mut height = 0;
    // SAFETY: The path is NUL-terminated. The native adapter receives the
    // capacity of the writable pixel buffer and fills both dimensions on success.
    let ok = unsafe {
        drill_read_shell_icon(
            path.as_ptr(),
            size,
            pixels.as_mut_ptr(),
            pixels.len(),
            &mut width,
            &mut height,
        )
    };
    if ok == 0 {
        return None;
    }
    pixels.truncate((width * height * 4) as usize);
    Some(FileIcon {
        width,
        height,
        pixels,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_paths_do_not_get_shell_icons() {
        let executable = std::env::current_exe().unwrap();
        let missing = executable.join("missing-file.txt");
        assert!(!missing.exists());
        assert!(file_icon(&missing, 64).is_none());
    }
}
