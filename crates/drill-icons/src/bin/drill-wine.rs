//! Unix launcher used by the Wine UI runner. The child requests bundle icons
//! on stdout and receives pixels on stdin. No socket or service is published.
#![forbid(unsafe_code)]

#[cfg(unix)]
mod host {
    use drill_icons::{EmbeddedIcon, RGBA_BYTES};
    use std::env;
    use std::fs;
    use std::io::{self, Read, Write};
    use std::os::unix::process::ExitStatusExt;
    use std::path::{Component, Path, PathBuf};
    use std::process::{Command, ExitCode, Stdio};

    pub(super) fn run() -> io::Result<ExitCode> {
        let mut args = env::args_os().skip(1);
        let wine = args.next().ok_or_else(|| {
            io::Error::new(
                io::ErrorKind::InvalidInput,
                "expected Wine executable and arguments",
            )
        })?;
        let mut child = Command::new(wine)
            .args(args)
            .env("DRILL_WINE_BUNDLE_PIPE", "1")
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .spawn()?;

        let requests = child.stdout.take().expect("piped stdout");
        let responses = child.stdin.take().expect("piped stdin");
        let prefix = env::var_os("WINEPREFIX")
            .map(PathBuf::from)
            .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".wine")));
        // The GUI's lifetime controls the launcher. Another Wine process can
        // retain a pipe handle after this child exits, so never join this worker.
        std::thread::spawn(move || {
            let _ = serve(requests, responses, prefix.as_deref());
        });
        let status = child.wait()?;
        Ok(ExitCode::from(
            status
                .code()
                .unwrap_or_else(|| 128 + status.signal().unwrap_or(1)) as u8,
        ))
    }

    pub(super) fn serve(
        mut requests: impl Read,
        mut responses: impl Write,
        prefix: Option<&Path>,
    ) -> io::Result<()> {
        loop {
            let mut header = [0; 12];
            requests.read_exact(&mut header)?;
            let units = u32::from_le_bytes(header[8..].try_into().unwrap());
            if &header[..8] != b"DRILICON" || !(1..=32_767).contains(&units) {
                return Err(io::Error::new(
                    io::ErrorKind::InvalidData,
                    "invalid Wine icon request",
                ));
            }
            let mut body = vec![0; units as usize * 2];
            requests.read_exact(&mut body)?;
            let units = body
                .as_chunks::<2>()
                .0
                .iter()
                .copied()
                .map(u16::from_le_bytes);
            let path: Result<String, _> = char::decode_utf16(units).collect();
            let pixels = path
                .ok()
                .and_then(|path| mapped_path(prefix?, &path))
                .and_then(|path| EmbeddedIcon::AppBundle.decode(&path, || true));
            match pixels {
                Some(pixels) if pixels.len() == RGBA_BYTES => {
                    responses.write_all(&[1])?;
                    responses.write_all(&pixels)?;
                }
                _ => responses.write_all(&[0])?,
            }
            responses.flush()?;
        }
    }

    pub(super) fn mapped_path(prefix: &Path, guest: &str) -> Option<PathBuf> {
        if !prefix.is_absolute() {
            return None;
        }
        let mut parts = guest.split(['\\', '/']);
        let drive = parts.next()?;
        if !matches!(drive.as_bytes(), [letter, b':'] if letter.is_ascii_alphabetic()) {
            return None;
        }
        let drive = drive.to_ascii_lowercase();
        let mut relative = PathBuf::new();
        for part in parts {
            if part.is_empty()
                || part.ends_with(['.', ' '])
                || part
                    .chars()
                    .any(|c| c.is_control() || r#"<>:"|?*"#.contains(c))
            {
                return None;
            }
            relative.push(part);
        }
        if !relative.extension()?.eq_ignore_ascii_case("app") {
            return None;
        }

        // Only resolve the drive mapping configured by the launcher user. Never
        // canonicalize a guest path: the native decoder must see and reject any
        // symlinks in it when it walks the original names from the root.
        let target = fs::read_link(prefix.join("dosdevices").join(&drive)).ok()?;
        let mut root = if target.is_absolute()
            && target
                .components()
                .all(|c| matches!(c, Component::RootDir | Component::Normal(_)))
        {
            target
        } else if drive == "c:" && target == Path::new("../drive_c") {
            prefix.canonicalize().ok()?.join("drive_c")
        } else {
            return None;
        };
        root.push(relative);
        Some(root)
    }
}

#[cfg(unix)]
fn main() -> std::io::Result<std::process::ExitCode> {
    host::run()
}

#[cfg(not(unix))]
fn main() -> std::process::ExitCode {
    eprintln!("drill-wine requires a Unix Wine host");
    std::process::ExitCode::FAILURE
}

#[cfg(all(unix, test))]
#[path = "../../../drill-core/src/test_directory.rs"]
mod test_directory;
#[cfg(all(unix, test))]
#[path = "drill-wine/tests.rs"]
mod tests;
