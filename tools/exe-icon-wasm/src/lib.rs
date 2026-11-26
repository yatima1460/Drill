use icoextract_rs::{ExtractedIcon, ExtractedImage, IconExtractor};
use std::io::Cursor;

mod resource;

#[no_mangle]
pub extern "C" fn allocate(size: u32) -> *mut u8 {
    let mut input = vec![0u8; size as usize].into_boxed_slice();
    let ptr = input.as_mut_ptr();
    std::mem::forget(input);
    ptr
}

#[no_mangle]
pub extern "C" fn decode(ptr: *const u8, len: u32) -> *mut u8 {
    // SAFETY: only the host calls this export, using the pointer returned by allocate
    // and the same bounded length. WebAssembly confines all accesses to guest memory.
    let input = unsafe { std::slice::from_raw_parts(ptr, len as usize) };
    let Some(pixels) = extract(input) else {
        return std::ptr::null_mut();
    };
    let mut result = pixels.into_boxed_slice();
    let ptr = result.as_mut_ptr();
    std::mem::forget(result);
    ptr
}

fn extract(input: &[u8]) -> Option<Vec<u8>> {
    let extractor = IconExtractor::from_bytes(input).ok()?;
    let groups = extractor.list_group_icons().ok()?;
    let group = groups.first()?;
    let image = group
        .images()
        .iter()
        .filter(|img| img.bytes_in_resource() <= 4 * 1024 * 1024)
        .min_by_key(|img| {
            (
                img.width().abs_diff(32) + img.height().abs_diff(32),
                std::cmp::Reverse(img.bit_count()),
            )
        })?;
    let range = resource::byte_range(
        image.file_offset(),
        image.bytes_in_resource(),
        u32::try_from(input.len()).ok()?,
    )?;
    let bytes = input.get(range)?.to_vec();
    let ico = ExtractedIcon::new(
        group.resource_id().clone(),
        vec![ExtractedImage::new(image.clone(), bytes)],
    )
    .to_ico_bytes()
    .ok()?;
    let mut reader = image::ImageReader::with_format(Cursor::new(ico), image::ImageFormat::Ico);
    let mut limits = image::Limits::default();
    limits.max_image_width = Some(256);
    limits.max_image_height = Some(256);
    limits.max_alloc = Some(4 * 1024 * 1024);
    reader.limits(limits);
    let rgba = reader
        .decode()
        .ok()?
        .resize_exact(32, 32, image::imageops::FilterType::Triangle)
        .to_rgba8();
    Some(rgba.into_raw())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_the_green_32_pixel_frame_from_both_pe_formats() {
        for fixture in [
            &include_bytes!("../tests/fixtures/icon-pe32.exe")[..],
            &include_bytes!("../tests/fixtures/icon-pe64.exe")[..],
        ] {
            let pixels = extract(fixture).expect("fixture has an icon");
            assert_eq!(pixels.len(), 32 * 32 * 4);
            assert_eq!(&pixels[..4], &[0, 255, 0, 255]);
            assert!(extract(&fixture[..64]).is_none());
        }
    }
}
