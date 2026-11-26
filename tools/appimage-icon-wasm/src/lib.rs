//! Reads the one opened AppImage through a bounded host capability.
//! All ELF, archive, compression and image parsing stays inside this guest.
use lamfold::{BlockCache, BlockSource, FileKind, FoldError, FoldFrontend, SubstrateCtx};
use lamfold_squash::SquashFs;
use std::io::Cursor;

#[link(wasm_import_module = "icon")]
extern "C" {
    fn read_at(offset: u64, dest: *mut u8, len: u32) -> i32;
}

struct Region {
    start: u64,
    len: u64,
}
impl BlockSource for Region {
    fn len(&self) -> u64 {
        self.len
    }
    fn read_at(&mut self, offset: u64, buf: &mut [u8]) -> lamfold::Result<()> {
        let len = buf.len() as u32;
        if offset > self.len || u64::from(len) > self.len - offset {
            return Err(FoldError::Io("short AppImage read"));
        }
        // SAFETY: this import writes len bytes into the live destination or returns an error.
        let count = unsafe { read_at(self.start + offset, buf.as_mut_ptr(), len) };
        if count < 0 || count as u32 != len {
            return Err(FoldError::Io("short AppImage read"));
        }
        Ok(())
    }
}

fn appimage_icon(len: u64) -> Option<Vec<u8>> {
    let mut file = Region { start: 0, len };
    let mut header = [0; 64];
    file.read_at(0, &mut header).ok()?;
    if &header[..4] != b"\x7fELF" || &header[8..10] != b"AI" {
        return None;
    }
    match header[10] {
        1 => return icon_file::<lamfold_iso::Iso9660<_>>(file),
        2 => (),
        _ => return None,
    }
    let little = match header[5] {
        1 => true,
        2 => false,
        _ => return None,
    };
    let number = |bytes: &[u8]| {
        if little {
            bytes
                .iter()
                .rev()
                .fold(0u64, |n, &b| (n << 8) | u64::from(b))
        } else {
            bytes.iter().fold(0u64, |n, &b| (n << 8) | u64::from(b))
        }
    };
    let (table, entry_size, count, off, size, width) = match header[4] {
        1 => (
            number(&header[32..36]),
            number(&header[46..48]),
            number(&header[48..50]),
            16,
            20,
            4,
        ),
        2 => (
            number(&header[40..48]),
            number(&header[58..60]),
            number(&header[60..62]),
            24,
            32,
            8,
        ),
        _ => return None,
    };
    if count == 0 || entry_size < (size + width) as u64 {
        return None;
    }
    // The reference runtime places the filesystem after both the section
    // table and the final section (the table itself can precede that section).
    let table_end = table.checked_add(count * entry_size)?;
    let mut last_section = [0; 40];
    file.read_at(table_end - entry_size, &mut last_section[..size + width])
        .ok()?;
    let section_end = number(&last_section[off..off + width])
        .checked_add(number(&last_section[size..size + width]))?;
    let start = table_end.max(section_end);
    icon_file::<SquashFs<_>>(Region {
        start,
        len: len.checked_sub(start)?,
    })
}

const MAX_ICON: u64 = 4 << 20;

fn icon_file<F: FoldFrontend<Region>>(region: Region) -> Option<Vec<u8>> {
    let mut ctx = SubstrateCtx {
        cache: &mut BlockCache::new(128 << 10),
        verifier: &lamfold::NoVerifier,
    };
    let mut fs = F::open(region, &mut ctx).ok()?;
    // All links resolve within the archive. The resolver bounds link depth.
    let node = lamfold::resolve(&mut fs, &mut ctx, "/.DirIcon").ok()?;
    let meta = fs.metadata(node, &mut ctx).ok()?;
    if meta.kind != FileKind::Regular || meta.size == 0 || meta.size > MAX_ICON {
        return None;
    }
    let mut bytes = vec![0; meta.size as usize];
    let count = fs.read_at(node, 0, &mut bytes, &mut ctx).ok()?;
    (count == bytes.len()).then_some(bytes)
}

fn pixels(input: &[u8]) -> Option<Vec<u8>> {
    if input.starts_with(b"\x89PNG\r\n\x1a\n") {
        let mut reader =
            image::ImageReader::with_format(Cursor::new(input), image::ImageFormat::Png);
        let mut limits = image::Limits::default();
        limits.max_image_width = Some(1024);
        limits.max_image_height = Some(1024);
        limits.max_alloc = Some(16 << 20);
        reader.limits(limits);
        return Some(
            reader
                .decode()
                .ok()?
                .thumbnail_exact(32, 32)
                .into_rgba8()
                .into_raw(),
        );
    }
    // Resolve no external files, fonts or embedded images. Only the vector
    // drawing itself is rendered into this fixed-size pixmap.
    let mut options = resvg::usvg::Options::default();
    options.image_href_resolver.resolve_string = Box::new(|_, _| None);
    options.image_href_resolver.resolve_data = Box::new(|_, _, _| None);
    let tree = resvg::usvg::Tree::from_data(input, &options).ok()?;
    let mut pixmap = resvg::tiny_skia::Pixmap::new(32, 32)?;
    let scale = 32.0 / tree.size().width().max(tree.size().height());
    let transform = resvg::tiny_skia::Transform::from_row(
        scale,
        0.,
        0.,
        scale,
        (32. - tree.size().width() * scale) / 2.,
        (32. - tree.size().height() * scale) / 2.,
    );
    resvg::render(&tree, transform, &mut pixmap.as_mut());
    if pixmap.pixels().iter().all(|pixel| pixel.alpha() == 0) {
        return None;
    }
    let mut rgba = Vec::with_capacity(32 * 32 * 4);
    for pixel in pixmap.pixels() {
        let color = pixel.demultiply();
        rgba.extend_from_slice(&[color.red(), color.green(), color.blue(), color.alpha()]);
    }
    Some(rgba)
}

#[no_mangle]
pub extern "C" fn decode(file_len: u64) -> *mut u8 {
    appimage_icon(file_len)
        .and_then(|data| pixels(&data))
        .map_or(std::ptr::null_mut(), |rgba| {
            Box::into_raw(rgba.into_boxed_slice()) as *mut u8
        })
}
