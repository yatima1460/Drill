use objc2::{AnyThread, rc::Retained};
use objc2_app_kit::{
    NSBitmapImageRep, NSCompositingOperation, NSGraphicsContext, NSImage, NSWorkspace,
};
use objc2_foundation::{NSPoint, NSRect, NSSize, NSString};
use objc2_uniform_type_identifiers::UTType;

use crate::Icon;
use std::{
    cell::RefCell,
    collections::{BTreeMap, btree_map},
    path::Path,
};

use log::error;

pub(crate) fn get_file_icon(path: impl AsRef<Path>, size: u16) -> Option<Icon> {
    let file_path = path_to_nsstring(path)?;
    let shared_workspace = NSWorkspace::sharedWorkspace();
    let image = shared_workspace.iconForFile(&file_path);
    let bitmap_representation = create_bitmap_representation(size)?;
    let context = create_context(&bitmap_representation)?;
    let size = u32::from(size);

    Some(Icon {
        width: size,
        height: size,
        pixels: get_pixels(&image, &context, &bitmap_representation, size)?,
    })
}

pub struct Provider<T: Clone> {
    shared_workspace: Retained<NSWorkspace>,
    bitmap_representation: Retained<NSBitmapImageRep>,
    context: Option<Retained<NSGraphicsContext>>,
    icon_size: u32,
    cache: RefCell<BTreeMap<String, T>>,
    converter: fn(Icon) -> T,
}

impl<T> Provider<T>
where
    T: Clone,
{
    pub fn new(icon_size: u16, converter: fn(Icon) -> T) -> Option<Self> {
        let mut provider = Self {
            shared_workspace: NSWorkspace::sharedWorkspace(),
            bitmap_representation: create_bitmap_representation(icon_size)?,
            context: None,
            icon_size: u32::from(icon_size),
            cache: RefCell::new(BTreeMap::new()),
            converter,
        };

        provider.context = create_context(&provider.bitmap_representation);

        Some(provider)
    }

    pub fn get_file_icon(&self, path: impl AsRef<Path>) -> Option<T> {
        match Self::get_uttype_identifier(&path) {
            Some(identifier) => match self.cache.borrow_mut().entry(identifier) {
                btree_map::Entry::Vacant(vacant_entry) => {
                    let icon = self.get_icon(path)?;

                    Some(vacant_entry.insert(icon).clone())
                }
                btree_map::Entry::Occupied(occupied_entry) => Some(occupied_entry.get().clone()),
            },
            None => self.get_icon(path),
        }
    }

    fn get_uttype_identifier(path: impl AsRef<Path>) -> Option<String> {
        if path.as_ref().is_dir() {
            return None;
        }

        let extension = NSString::from_str(path.as_ref().extension()?.to_str()?);
        let ut_type = UTType::typeWithFilenameExtension(&extension)?;

        Some(ut_type.identifier().to_string())
    }

    pub fn get_icon(&self, path: impl AsRef<Path>) -> Option<T> {
        let path = path.as_ref();
        let context = self.context.as_ref().unwrap();
        let file_path = path_to_nsstring(path)?;
        let image = self.shared_workspace.iconForFile(&file_path);

        Some((self.converter)(Icon {
            width: self.icon_size,
            height: self.icon_size,
            pixels: get_pixels(&image, context, &self.bitmap_representation, self.icon_size)?,
        }))
    }
}

fn create_bitmap_representation(icon_size: u16) -> Option<Retained<NSBitmapImageRep>> {
    let color_space_name = NSString::from_str("NSDeviceRGBColorSpace");
    let icon_size = isize::try_from(icon_size).ok()?;
    let bitmap_representation = unsafe { NSBitmapImageRep::initWithBitmapDataPlanes_pixelsWide_pixelsHigh_bitsPerSample_samplesPerPixel_hasAlpha_isPlanar_colorSpaceName_bytesPerRow_bitsPerPixel(
        NSBitmapImageRep::alloc(),
        std::ptr::null_mut(),
        icon_size,
        icon_size,
        8,
        4,
        true,
        false,
        &color_space_name,
        icon_size * 4,
        32,
    ) };

    if bitmap_representation.is_none() {
        error!("Failed to create NSBitmapImageRep");
    }

    bitmap_representation
}

fn create_context(
    bitmap_representation: &Retained<NSBitmapImageRep>,
) -> Option<Retained<NSGraphicsContext>> {
    if let Some(context) = NSGraphicsContext::graphicsContextWithBitmapImageRep(bitmap_representation) {
        Some(context)
    } else {
        error!("Failed to create graphics context");
        None
    }
}

fn get_pixels(
    image: &NSImage,
    context: &NSGraphicsContext,
    bitmap_representation: &NSBitmapImageRep,
    icon_size: u32,
) -> Option<Vec<u8>> {
    let image_size = image.size();

    if image_size.width < 1.0 || image_size.height < 1.0 {
        error!("Invalid image size");
        return None;
    }
    let icon_size = f64::from(icon_size);
    let desired_size = NSSize {
        width: icon_size,
        height: icon_size,
    };

    Some(unsafe {
        context.saveGraphicsState();
        NSGraphicsContext::setCurrentContext(Some(context));
        image.setSize(desired_size);
        image.drawAtPoint_fromRect_operation_fraction(
            NSPoint::ZERO,
            NSRect::new(NSPoint::ZERO, desired_size),
            NSCompositingOperation::Copy,
            1.0,
        );
        context.flushGraphics();
        context.restoreGraphicsState();

        let bytes_per_plane = usize::try_from(bitmap_representation.bytesPerPlane()).ok()?;

        std::slice::from_raw_parts(
            bitmap_representation.bitmapData(),
            bytes_per_plane,
        )
        .to_vec()
    })
}

fn path_to_nsstring(path: impl AsRef<Path>) -> Option<Retained<NSString>> {
    let path = match path.as_ref().canonicalize() {
        Ok(path) => path,
        Err(error) => {
            error!(
                "Failed to canonicalize path '{}': {}",
                path.as_ref().display(),
                error
            );
            return None;
        }
    };

    if let Some(path) = path.to_str() {
        Some(NSString::from_str(path))
    } else {
        error!("Path '{}' is not valid unicode", path.display());
        None
    }
}
