use std::{
    cell::RefCell,
    collections::BTreeMap,
    ffi::{OsStr, c_void},
    path::Path,
    sync::{
        LazyLock,
        mpsc::{Sender, channel},
    },
};

use scopeguard::defer;
use windows::{
    Win32::{
        Foundation::SIZE,
        Graphics::Gdi::{
            BI_RGB, BITMAP, BITMAPINFO, BITMAPINFOHEADER, CreateCompatibleDC, DIB_RGB_COLORS, DeleteDC, DeleteObject, GetDIBits, GetObjectW, HBITMAP, HDC
        },
        System::Com::{CoInitialize, CoUninitialize},
        UI::Shell::{
            IShellItemImageFactory, SHCreateItemFromParsingName, SIIGBF_ICONONLY, SIIGBF_SCALEUP,
        },
    },
    core::HSTRING,
};

use crate::Icon;

use log::{debug, error};

enum ImageFactoryRequest {
    RequestImage {
        path: HSTRING,
        size: u16,
        reply: Sender<ImageFactoryReply>,
    },
}

enum ImageFactoryReply {
    Success(Icon),
    Failure,
}

static IMAGE_FACTORY_REQUEST_SENDER: LazyLock<Sender<ImageFactoryRequest>> =
    LazyLock::new(start_image_factory_thread);

fn start_image_factory_thread() -> Sender<ImageFactoryRequest> {
    let (sender, receiver) = channel();

    std::thread::spawn(move || {
        debug!("Start Image Factory thread");
        for request in receiver.iter() {
            match request {
                ImageFactoryRequest::RequestImage { path, size, reply } => {
                    if let Err(error) = unsafe { CoInitialize(None).ok() } {
                        error!("Failed to initialize COM: {error}");
                        let _ = reply.send(ImageFactoryReply::Failure);
                        continue;
                    }

                    defer!(unsafe { CoUninitialize() });

                    let factory: Result<IShellItemImageFactory, _> =
                        unsafe { SHCreateItemFromParsingName(&path, None) };
                    match factory {
                        Ok(factory) => {
                            let hbitmap = unsafe {
                                let image_size = i32::from(size);
                                factory.GetImage(
                                    SIZE {
                                        cx: image_size,
                                        cy: image_size,
                                    },
                                    SIIGBF_ICONONLY | SIIGBF_SCALEUP,
                                )
                            };

                            match hbitmap {
                                Ok(hbitmap) => {
                                    match get_hbitmap_pixels(hbitmap) {
                                        Some(pixels) => {
                                            let size = u32::from(size);
                                            let _ = reply.send(ImageFactoryReply::Success(Icon {
                                                width: size,
                                                height: size,
                                                pixels,
                                            }));
                                        }
                                        None => {
                                            let _ = reply.send(ImageFactoryReply::Failure);
                                        }
                                    }
                                }
                                Err(error) => {
                                    error!("Failed to get image from factory: {error}");
                                    let _ = reply.send(ImageFactoryReply::Failure);
                                }
                            }
                        }
                        Err(error) => {
                            error!("Failed to create IShellItemImageFactory: {error}");
                            let _ = reply.send(ImageFactoryReply::Failure);
                        }
                    }
                }
            }
        }
        debug!("Image Factory thread stopped");
    });

    sender
}

/// Just `std::mem::size_of::<T>()` casted to `i32`
/// I made that to appease clippy
fn size_of_i32<T>() -> i32 {
    i32::try_from(std::mem::size_of::<T>()).unwrap()
}

/// Just `std::mem::size_of::<T>()` casted to `u32`
/// I made that to appease clippy
fn size_of_u32<T>() -> u32 {
    u32::try_from(std::mem::size_of::<T>()).unwrap()
}

fn get_hbitmap_pixels(hbitmap: HBITMAP) -> Option<Vec<u8>> {
    let pixels = unsafe {
        defer!({
            let _ = DeleteObject(hbitmap.into());
        });

        let mut bmp: BITMAP = std::mem::zeroed();

        if GetObjectW(
            hbitmap.into(),
            size_of_i32::<BITMAP>(),
            Some((&raw mut bmp).cast::<c_void>()),
        ) == 0
        {
            error!("Failed to get HBITMAP data");
            return None
        }

        let mut bi: BITMAPINFO = std::mem::zeroed();
        bi.bmiHeader.biSize = size_of_u32::<BITMAPINFOHEADER>();
        bi.bmiHeader.biWidth = bmp.bmWidth;
        bi.bmiHeader.biHeight = -bmp.bmHeight;
        bi.bmiHeader.biPlanes = 1;
        bi.bmiHeader.biBitCount = 32;
        bi.bmiHeader.biCompression = BI_RGB.0;

        let Ok(bmp_width) = usize::try_from(bmp.bmWidth) else {
            error!("Negative bitmap width: {}", bmp.bmWidth);
            return None
        };
        let Ok(bmp_height) = usize::try_from(bmp.bmHeight) else {
            error!("Negative bitmap height: {}", bmp.bmHeight);
            return None
        };
        let Ok(clines) = u32::try_from(bmp_height) else {
            error!("Out of bound bitmap height: {bmp_height}");
            return None
        };
        let mut pixels = vec![0u8; bmp_width * bmp_height * 4];
        let hdc: HDC = CreateCompatibleDC(None);
        if hdc.is_invalid() {
            error!("Unable to create Device Context");
            return None
        }
        let res = GetDIBits(
            hdc,
            hbitmap,
            0,
            clines,
            Some(pixels.as_mut_ptr().cast()),
            &raw mut bi,
            DIB_RGB_COLORS,
        );
        let _ = DeleteDC(hdc);

        if res == 0 {
            error!("Failed to get HBITMAP bits");
            return None
        }

        // GetDIBits() returns BGRA pixels, converting to RGBA
        for chunk in pixels.chunks_exact_mut(4) {
            chunk.swap(0, 2);
        }

        pixels
    };

    Some(pixels)
}

pub(crate) fn get_file_icon(path: impl AsRef<Path>, size: u16) -> Option<Icon> {
    let path = HSTRING::from(path.as_ref());
    let (reply_tx, reply_rx) = channel();

    match IMAGE_FACTORY_REQUEST_SENDER.send(ImageFactoryRequest::RequestImage {
        path,
        size,
        reply: reply_tx,
    }) {
        Ok(()) => {
            let Ok(ImageFactoryReply::Success(icon)) = reply_rx.recv() else {
                return None
            };

            Some(icon)
        }
        Err(error) => {
            error!("Failed to send request: {error}");
            None
        }
    }
}

pub(crate) struct Provider<T: Clone> {
    icon_size: u16,
    converter: fn(Icon) -> T,
    icons_cache: RefCell<BTreeMap<String, T>>,
}

impl<T: Clone> Provider<T> {
    #[allow(clippy::unnecessary_wraps)]
    pub fn new(icon_size: u16, converter: fn(Icon) -> T) -> Option<Self> {
        Some(Self {
            icon_size,
            converter,
            icons_cache: RefCell::new(BTreeMap::new()),
        })
    }

    pub fn get_file_icon(&self, path: impl AsRef<Path>) -> Option<T> {
        let path = path.as_ref();

        match path.extension().and_then(OsStr::to_str) {
            // On Windows .exe and .lnk can have any icon so they are never cached.
            Some(extension) if extension.eq_ignore_ascii_case("exe") || extension.eq_ignore_ascii_case("lnk") => {
                get_file_icon(path, self.icon_size).map(self.converter)
            }
            None => get_file_icon(path, self.icon_size).map(self.converter),
            Some(extension) => match self.icons_cache.borrow_mut().entry(extension.to_owned()) {
                std::collections::btree_map::Entry::Vacant(vacant_entry) => Some(
                    vacant_entry
                        .insert(get_file_icon(path, self.icon_size).map(self.converter)?)
                        .clone(),
                ),
                std::collections::btree_map::Entry::Occupied(occupied_entry) => {
                    Some(occupied_entry.get().clone())
                }
            },
        }
    }
}
