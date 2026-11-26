//! Gives the bundled AppImage reader access only to the selected open file.
//! Random reads keep icon loading independent of the size of the application.
use std::{
    fs::File,
    io::{Read, Seek, SeekFrom},
};
use wasmi::{Caller, Config, Engine, Linker, Module, Store, StoreLimits, StoreLimitsBuilder};

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
    engine: Engine,
    module: Module,
}
impl Decoder {
    pub fn new() -> Option<Self> {
        let mut config = Config::default();
        config.consume_fuel(true);
        let engine = Engine::new(&config);
        let module = Module::new(&engine, &include_bytes!("assets/appimage-icon.wasm")[..]).ok()?;
        Some(Self { engine, module })
    }

    pub fn decode(&self, file: File, file_len: u64) -> Option<Vec<u8>> {
        let input = Input {
            file,
            file_len,
            bytes_left: 8 << 20,
            reads_left: 2048,
            limits: StoreLimitsBuilder::new()
                .memory_size(64 << 20)
                .instances(1)
                .memories(1)
                .tables(1)
                .build(),
        };
        let mut store = Store::new(&self.engine, input);
        store.limiter(|input| &mut input.limits);
        store.set_fuel(350_000_000).ok()?;
        let mut linker = Linker::new(&self.engine);
        linker.func_wrap("icon", "read_at", read_at).ok()?;
        let instance = linker
            .instantiate_and_start(&mut store, &self.module)
            .ok()?;
        let decode = instance.get_typed_func::<u64, u32>(&store, "decode").ok()?;
        let ptr = decode.call(&mut store, file_len).ok()?;
        if ptr == 0 {
            return None;
        }
        let mut pixels = vec![0; 32 * 32 * 4];
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
            include_bytes!("../tools/appimage-icon-wasm/tests/fixtures/linked-png.AppImage");
        for data in [
            b"plain file".as_slice(),
            &complete[..48],
            &complete[..138],
            include_bytes!("../tools/appimage-icon-wasm/tests/fixtures/cyclic.AppImage").as_slice(),
        ] {
            let mut f = tempfile::tempfile().unwrap();
            f.write_all(data).unwrap();
            assert!(decoder.decode(f, data.len() as u64).is_none());
        }
    }

    #[test]
    fn reads_a_large_sparse_image_without_snapshotting_it() {
        let decoder = Decoder::new().unwrap();
        let mut f = tempfile::tempfile().unwrap();
        let bytes =
            include_bytes!("../tools/appimage-icon-wasm/tests/fixtures/linked-png.AppImage");
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

    #[test]
    #[ignore = "requires the packaged Linux AppImage"]
    fn packaged_appimage_contains_drill_icon() {
        let path = std::env::var_os("DRILL_PACKAGED_APPIMAGE")
            .unwrap_or_else(|| "dist/Drill-linux-x86_64.AppImage".into());
        let file = File::open(path).unwrap();
        let len = file.metadata().unwrap().len();
        let actual = Decoder::new()
            .unwrap()
            .decode(file, len)
            .expect("read packaged icon");
        let expected = image::load_from_memory(include_bytes!("assets/drill.png"))
            .unwrap()
            .thumbnail_exact(32, 32)
            .to_rgba8();
        assert!(
            actual == expected.as_raw().as_slice(),
            "packaged icon differs from the application icon"
        );
    }
}
