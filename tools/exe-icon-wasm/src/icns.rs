const MAX_CHUNKS: usize = 128;
const MAX_DIMENSION: u32 = 1024;
const MAX_FRAME_BYTES: usize = 8 << 20;

pub(super) fn extract(input: &[u8]) -> Option<Vec<u8>> {
    if input.get(..4)? != b"icns" || word(input, 4)? as usize != input.len() {
        return None;
    }
    let mut chunks = &input[8..];
    let mut candidates = Vec::new();
    for _ in 0..MAX_CHUNKS {
        if chunks.is_empty() {
            break;
        }
        // Both container and chunk lengths include their eight-byte headers.
        let kind = chunks.get(..4)?;
        let length = word(chunks, 4)? as usize;
        let frame = chunks.get(8..length)?;
        chunks = &chunks[length..];
        if let Some(width) = png_width(kind, frame) {
            candidates.push((width, frame));
        }
    }
    if !chunks.is_empty() {
        return None;
    }

    // Use actual PNG dimensions. Prefer downsampling over enlarging a smaller
    // icon, and preserve file order among equally suitable representations.
    candidates.sort_by_key(|&(width, _)| (width < 32, width.abs_diff(32)));
    candidates.into_iter().find_map(|(_, frame)| {
        super::decode_image(frame, image::ImageFormat::Png, MAX_DIMENSION, 16 << 20)
            // Some bundles ship fully transparent placeholder representations.
            .filter(|rgba| rgba.as_chunks::<4>().0.iter().any(|pixel| pixel[3] != 0))
    })
}

fn png_width(kind: &[u8], frame: &[u8]) -> Option<u32> {
    // Other chunks can be masks, tables of contents or alternate icon families.
    if !matches!(
        kind,
        b"icp4"
            | b"icp5"
            | b"icp6"
            | b"ic04"
            | b"ic05"
            | b"ic06"
            | b"ic07"
            | b"ic08"
            | b"ic09"
            | b"ic10"
            | b"ic11"
            | b"ic12"
            | b"ic13"
            | b"ic14"
    ) || frame.len() > MAX_FRAME_BYTES
        || !frame.starts_with(b"\x89PNG\r\n\x1a\n\0\0\0\rIHDR")
    {
        return None;
    }
    let width = word(frame, 16)?;
    let height = word(frame, 20)?;
    (width == height && (1..=MAX_DIMENSION).contains(&width)).then_some(width)
}

fn word(bytes: &[u8], offset: usize) -> Option<u32> {
    Some(u32::from_be_bytes(
        bytes.get(offset..offset + 4)?.try_into().ok()?,
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use image::ImageEncoder;

    fn png(width: u32, color: [u8; 4]) -> Vec<u8> {
        let mut bytes = Vec::new();
        image::codecs::png::PngEncoder::new(&mut bytes)
            .write_image(
                &color.repeat((width * width) as usize),
                width,
                width,
                image::ExtendedColorType::Rgba8,
            )
            .unwrap();
        bytes
    }

    fn family(chunks: &[(&[u8; 4], &[u8])]) -> Vec<u8> {
        let mut bytes = b"icns\0\0\0\0".to_vec();
        for &(kind, data) in chunks {
            bytes.extend_from_slice(kind);
            bytes.extend_from_slice(&(8 + data.len() as u32).to_be_bytes());
            bytes.extend_from_slice(data);
        }
        let length = bytes.len() as u32;
        bytes[4..8].copy_from_slice(&length.to_be_bytes());
        bytes
    }

    #[test]
    fn selects_the_exact_png_by_its_pixels_and_preserves_alpha() {
        let color = [40, 80, 120, 190];
        let exact = png(32, color);
        let larger = png(64, [255; 4]);
        let other = png(32, [0; 4]);
        let input = family(&[
            (b"TOC ", &other),
            (b"ic11", &larger),
            (b"ic12", &exact),
            (b"ic11", &other),
        ]);
        assert_eq!(extract(&input).unwrap(), color.repeat(32 * 32));
        assert!(super::super::extract(&input).is_none());
    }

    #[test]
    fn skips_damaged_and_unsupported_frames_and_prefers_downsampling() {
        let color = [15, 175, 216, 255];
        let larger = png(64, color);
        let exact = png(32, [0; 4]);
        let smaller = png(16, [255; 4]);
        let mut oversized = exact.clone();
        oversized[16..24].copy_from_slice(&[0xff; 8]);
        let input = family(&[
            (b"ic09", &oversized),
            (b"ic04", b"ARGB"),
            (b"icp5", &exact[..24]),
            (b"icp4", &smaller),
            (b"icp6", &larger),
        ]);
        assert_eq!(extract(&input).unwrap(), color.repeat(32 * 32));
    }

    #[test]
    fn skips_invisible_frames_and_preserves_the_generic_fallback() {
        let invisible = png(32, [100, 110, 120, 0]);
        assert!(extract(&family(&[(b"ic11", &invisible)])).is_none());
        let color = [80, 90, 100, 255];
        let visible = png(64, color);
        assert_eq!(
            extract(&family(&[(b"ic11", &invisible), (b"ic12", &visible)])).unwrap(),
            color.repeat(32 * 32)
        );
    }

    #[test]
    fn rejects_invalid_containers_and_chunk_lengths() {
        let valid = family(&[(b"ic11", &png(32, [255; 4]))]);
        assert!(extract(&valid[..valid.len() - 1]).is_none());
        let mut damaged = valid.clone();
        damaged[..4].copy_from_slice(b"xxxx");
        assert!(extract(&damaged).is_none());
        for length in [0u32, 7, u32::MAX] {
            let mut damaged = valid.clone();
            damaged[12..16].copy_from_slice(&length.to_be_bytes());
            assert!(extract(&damaged).is_none());
        }
        assert!(extract(include_bytes!("../tests/fixtures/icon-pe32.exe")).is_none());
    }

    #[test]
    fn bounds_the_number_of_chunks_even_after_finding_a_valid_frame() {
        let frame = png(32, [255; 4]);
        let mut chunks: Vec<(&[u8; 4], &[u8])> = vec![(b"TOC ", &[]); MAX_CHUNKS];
        chunks[0] = (b"ic11", &frame);
        assert!(extract(&family(&chunks)).is_some());
        chunks.push((b"TOC ", &[]));
        assert!(extract(&family(&chunks)).is_none());
    }
}
