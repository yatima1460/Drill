//! The PE and ICNS guest receives only a bounded snapshot and has no host imports.
use crate::RGBA_BYTES;
use wasmi::{Linker, Module, Store, StoreLimits};

const FUEL: u64 = 80_000_000;

pub(super) struct Decoder {
    module: Module,
}
impl Decoder {
    pub(super) fn new() -> Option<Self> {
        let module = crate::compile_guest(include_bytes!("../../../src/assets/exe-icon.wasm"))?;
        // The fixed decoder must not receive filesystem, process, network, or any other host imports.
        if module.imports().next().is_some() {
            return None;
        }
        Some(Self { module })
    }
    pub(super) fn decode(&self, bytes: &[u8], export: &'static str) -> Option<Vec<u8>> {
        let limits = crate::guest_limits();
        let mut store = Store::new(self.module.engine(), limits);
        store.limiter(|limits: &mut StoreLimits| limits);
        store.set_fuel(FUEL).ok()?;
        let linker = Linker::new(self.module.engine());
        let instance = linker
            .instantiate_and_start(&mut store, &self.module)
            .ok()?;
        let memory = instance.get_memory(&store, "memory")?;
        let allocate = instance
            .get_typed_func::<u32, u32>(&store, "allocate")
            .ok()?;
        let decode = instance
            .get_typed_func::<(u32, u32), u32>(&store, export)
            .ok()?;
        let len = u32::try_from(bytes.len()).ok()?;
        let input = allocate.call(&mut store, len).ok()?;
        memory.write(&mut store, input as usize, bytes).ok()?;
        let output = decode.call(&mut store, (input, len)).ok()?;
        if output == 0 {
            return None;
        }
        let mut pixels = vec![0; RGBA_BYTES];
        memory.read(&store, output as usize, &mut pixels).ok()?;
        Some(pixels)
    }
}
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn malformed_input_is_rejected_and_decoder_has_no_imports() {
        let decoder = Decoder::new().expect("decoder must instantiate");
        assert!(decoder.decode(b"MZ not an executable", "decode").is_none());
    }
    #[test]
    fn extracts_pe32_and_pe64_icons_inside_the_guest() {
        let decoder = Decoder::new().expect("decoder must instantiate");
        for fixture in [
            &include_bytes!("../../../tools/exe-icon-wasm/tests/fixtures/icon-pe32.exe")[..],
            &include_bytes!("../../../tools/exe-icon-wasm/tests/fixtures/icon-pe64.exe")[..],
        ] {
            let pixels = decoder
                .decode(fixture, "decode")
                .expect("valid embedded icon");
            assert_eq!(pixels.len(), RGBA_BYTES);
            assert_eq!(&pixels[..4], &[0, 255, 0, 255]);
        }
    }

    #[test]
    fn malformed_resource_headers_do_not_escape_or_crash_decoder() {
        let decoder = Decoder::new().expect("decoder must instantiate");
        let fixture = include_bytes!("../../../tools/exe-icon-wasm/tests/fixtures/icon-pe32.exe");
        for offset in [0x3c, 0x80, 0x100, 0x200, 0x400, 0x800] {
            let mut input = fixture.to_vec();
            for byte in &mut input[offset..offset + 4] {
                *byte = 0xff;
            }
            if let Some(pixels) = decoder.decode(&input, "decode") {
                assert_eq!(pixels.len(), RGBA_BYTES);
            }
        }
    }
}
