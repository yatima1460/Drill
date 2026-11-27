use std::io::Cursor;

mod pe;
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
    let frame = pe::icon_frame(input)?;
    let mut ico = Vec::with_capacity(22 + frame.bytes.len());
    ico.extend_from_slice(&[0, 0, 1, 0, 1, 0]); // Reserved, ICO type, one image.
    ico.extend_from_slice(frame.directory_fields);
    ico.extend_from_slice(&22u32.to_le_bytes()); // Header and entry length.
    ico.extend_from_slice(frame.bytes);
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

    #[test]
    fn extracts_from_named_groups_and_selects_the_first_language() {
        let mut fixture = include_bytes!("../tests/fixtures/icon-pe32.exe").to_vec();

        // The group name is stored after the directory, in a length-prefixed UTF-16 string.
        fixture[0x25c..0x260].copy_from_slice(&[1, 0, 0, 0]);
        write_u32(&mut fixture, 0x260, 0x8000_0130);
        fixture[0x330..0x33a].copy_from_slice(&[4, 0, b'M', 0, b'a', 0, b'i', 0, b'n', 0]);

        // Move the green frame's language table into free space. Its second locale
        // will point to a red DIB. The original green frame is a PNG.
        write_u32(&mut fixture, 0x23c, 0x8000_0140);
        fixture[0x34e..0x350].copy_from_slice(&2u16.to_le_bytes());
        write_u32(&mut fixture, 0x350, 0x0407);
        write_u32(&mut fixture, 0x354, 0x00f0);
        write_u32(&mut fixture, 0x358, 0x0409);
        write_u32(&mut fixture, 0x35c, 0x0160);

        assert_eq!(&extract(&fixture).unwrap()[..4], &[0, 255, 0, 255]);

        // A 32-bit DIB contains a 40-byte header, BGRA pixels and an AND mask.
        // The stored height includes the pixel rows and the mask rows.
        let dib = 0x50000;
        let dib_size = 40 + 32 * 32 * 4 + 32 * 4;
        write_u32(&mut fixture, dib, 40);
        write_u32(&mut fixture, dib + 4, 32);
        write_u32(&mut fixture, dib + 8, 64);
        fixture[dib + 12..dib + 16].copy_from_slice(&[1, 0, 32, 0]);
        fixture[dib + 40..dib + 40 + 32 * 32 * 4]
            .copy_from_slice(&[0, 0, 255, 255].repeat(32 * 32));
        write_u32(&mut fixture, 0x360, 0x50e00);
        write_u32(&mut fixture, 0x364, dib_size);
        write_u32(&mut fixture, 0x354, 0x0160);
        write_u32(&mut fixture, 0x35c, 0x00f0);
        write_u32(&mut fixture, 0x440a0, dib_size);

        assert_eq!(&extract(&fixture).unwrap()[..4], &[255, 0, 0, 255]);
    }

    #[test]
    fn a_preceding_overlapping_section_does_not_hide_the_resource_directory() {
        let mut fixture = include_bytes!("../tests/fixtures/icon-pe32.exe").to_vec();
        let section = 0x178;
        let section_len = 40;
        fixture[0x86..0x88].copy_from_slice(&2u16.to_le_bytes());
        fixture.copy_within(section..section + section_len, section + section_len);
        fixture[section..section + 8].copy_from_slice(b".other\0\0");
        write_u32(&mut fixture, section + 12, 0);
        write_u32(&mut fixture, section + 16, u32::MAX);
        assert_eq!(&extract(&fixture).unwrap()[..4], &[0, 255, 0, 255]);
    }

    #[test]
    fn falls_back_if_the_resource_directory_omits_the_group_payload() {
        let mut fixture = include_bytes!("../tests/fixtures/icon-pe32.exe").to_vec();
        write_u32(&mut fixture, 0x10c, 0x400);
        assert!(extract(&fixture).is_none());
    }

    fn write_u32(input: &mut [u8], offset: usize, value: u32) {
        input[offset..offset + 4].copy_from_slice(&value.to_le_bytes());
    }
}
