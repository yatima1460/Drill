//! Helpers for loading [`egui::IconData`].

use egui::IconData;

/// Helpers for working with [`IconData`].
pub trait IconDataExt {
    /// Convert into [`image::RgbaImage`]
    ///
    /// # Errors
    /// If `width*height != 4 * rgba.len()`, or if the image is too big.
    #[cfg(not(target_os = "macos"))]
    fn to_image(&self) -> Result<image::RgbaImage, String>;

    /// Encode as PNG.
    ///
    /// # Errors
    /// The image is invalid, or the PNG encoder failed.
    fn to_png_bytes(&self) -> Result<Vec<u8>, String>;
}

/// Load the contents of .png file.
///
/// # Errors
/// If this is not a valid png.
#[cfg(not(target_os = "macos"))]
pub fn from_png_bytes(png_bytes: &[u8]) -> Result<IconData, image::ImageError> {
    profiling::function_scope!();
    let image = image::load_from_memory(png_bytes)?;
    Ok(from_image(image))
}

#[cfg(not(target_os = "macos"))]
fn from_image(image: image::DynamicImage) -> IconData {
    let image = image.into_rgba8();
    IconData {
        width: image.width(),
        height: image.height(),
        rgba: image.into_raw(),
    }
}

/// Decode a bundled PNG through AppKit on macOS.
///
/// # Errors
/// Returns an error if the PNG has an unsupported layout or cannot be read.
#[cfg(target_os = "macos")]
pub fn from_png_bytes(png_bytes: &[u8]) -> Result<IconData, &'static str> {
    profiling::function_scope!();
    let (width, height, rgba) =
        drill_macos::png::decode_png(png_bytes).ok_or("Invalid bundled PNG")?;
    Ok(IconData {
        width,
        height,
        rgba,
    })
}

impl IconDataExt for IconData {
    #[cfg(not(target_os = "macos"))]
    fn to_image(&self) -> Result<image::RgbaImage, String> {
        profiling::function_scope!();
        let Self {
            rgba,
            width,
            height,
        } = self.clone();
        image::RgbaImage::from_raw(width, height, rgba).ok_or_else(|| "Invalid IconData".to_owned())
    }

    #[cfg(not(target_os = "macos"))]
    fn to_png_bytes(&self) -> Result<Vec<u8>, String> {
        profiling::function_scope!();
        let image = self.to_image()?;
        let mut png_bytes: Vec<u8> = Vec::new();
        image
            .write_to(
                &mut std::io::Cursor::new(&mut png_bytes),
                image::ImageFormat::Png,
            )
            .map_err(|err| err.to_string())?;
        Ok(png_bytes)
    }

    #[cfg(target_os = "macos")]
    fn to_png_bytes(&self) -> Result<Vec<u8>, String> {
        profiling::function_scope!();
        drill_macos::png::encode_png(self.width, self.height, &self.rgba)
            .ok_or_else(|| "Could not encode AppKit icon PNG".to_owned())
    }
}
