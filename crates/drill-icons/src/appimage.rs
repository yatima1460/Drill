//! Gives the bundled AppImage reader access only to the selected open file.
//! Random reads keep icon loading independent of the size of the application.
use std::{
    fs::File,
    io::{Read, Seek, SeekFrom},
};
use wasmi::{Caller, Linker, Module, Store, StoreLimits};

struct Input {
    file: File,
    file_len: u64,
    bytes_left: usize,
    reads_left: usize,
    limits: StoreLimits,
}

fn read_at(mut caller: Caller<'_, Input>, offset: u64, dest: u32, len: u32) -> i32 {
    let Some(memory) = caller.get_export("memory").and_then(|e| e.into_memory()) else {
        return -1;
    };
    let (memory, input) = memory.data_and_store_mut(&mut caller);
    // Charge attempts (including I/O errors) before touching the filesystem.
    let len = len as usize;
    if input.reads_left == 0
        || len > input.bytes_left
        || len > 4 << 20
        || offset > input.file_len
        || len as u64 > input.file_len - offset
    {
        return -1;
    }
    let Some(buffer) = memory
        .get_mut(dest as usize..)
        .and_then(|s| s.get_mut(..len))
    else {
        return -1;
    };
    input.reads_left -= 1;
    input.bytes_left -= len;
    if input.file.seek(SeekFrom::Start(offset)).is_err() {
        return -1;
    }
    input.file.read_exact(buffer).map_or(-1, |()| len as i32)
}

pub(super) struct Decoder {
    module: Module,
}
impl Decoder {
    pub fn new() -> Option<Self> {
        let module =
            crate::compile_guest(include_bytes!("../../../src/assets/appimage-icon.wasm"))?;
        Some(Self { module })
    }

    pub fn decode(&self, file: File, file_len: u64) -> Option<Vec<u8>> {
        let input = Input {
            file,
            file_len,
            bytes_left: 8 << 20,
            reads_left: 2048,
            limits: crate::guest_limits(),
        };
        let mut store = Store::new(self.module.engine(), input);
        store.limiter(|input| &mut input.limits);
        store.set_fuel(350_000_000).ok()?;
        let mut linker = Linker::new(self.module.engine());
        linker.func_wrap("icon", "read_at", read_at).ok()?;
        let instance = linker
            .instantiate_and_start(&mut store, &self.module)
            .ok()?;
        let decode = instance.get_typed_func::<u64, u32>(&store, "decode").ok()?;
        let ptr = decode.call(&mut store, file_len).ok()?;
        if ptr == 0 {
            return None;
        }
        let mut pixels = vec![0; crate::RGBA_BYTES];
        instance
            .get_memory(&store, "memory")?
            .read(&store, ptr as usize, &mut pixels)
            .ok()?;
        Some(pixels)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn rejects_missing_archives_and_symlink_loops() {
        let decoder = Decoder::new().unwrap();
        let complete =
            include_bytes!("../../../tools/appimage-icon-wasm/tests/fixtures/linked-png.AppImage");
        for data in [
            b"plain file".as_slice(),
            &complete[..48],
            &complete[..138],
            include_bytes!("../../../tools/appimage-icon-wasm/tests/fixtures/cyclic.AppImage")
                .as_slice(),
        ] {
            let directory = crate::test_directory::private_temp_dir();
            let path = directory.path().join("invalid.AppImage");
            File::create_new(&path).unwrap().write_all(data).unwrap();
            let file = File::open(path).unwrap();
            assert!(decoder.decode(file, data.len() as u64).is_none());
        }
    }

    #[test]
    fn reads_a_large_sparse_image_without_snapshotting_it() {
        let decoder = Decoder::new().unwrap();
        let directory = crate::test_directory::private_temp_dir();
        let path = directory.path().join("sparse.AppImage");
        let mut f = File::options()
            .read(true)
            .write(true)
            .create_new(true)
            .open(path)
            .unwrap();
        let bytes =
            include_bytes!("../../../tools/appimage-icon-wasm/tests/fixtures/linked-png.AppImage");
        let offset = 160u64 << 20;
        let mut header = bytes[..128].to_vec();
        header[88..96].copy_from_slice(&offset.to_le_bytes());
        f.write_all(&header).unwrap();
        f.seek(SeekFrom::Start(offset)).unwrap();
        f.write_all(&bytes[128..]).unwrap();
        let len = f.metadata().unwrap().len();
        let pixels = decoder.decode(f, len).expect("large AppImage icon");
        assert_eq!(&pixels[..4], &[0, 255, 0, 255]);
    }
}
