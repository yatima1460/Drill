#[cfg(test)]
mod tests {
    #[test]
    #[ignore = "requires a packaged AppImage and --features verify-packaged-appimage"]
    fn packaged_appimage_contains_drill_icon() {
        #[cfg(not(feature = "verify-packaged-appimage"))]
        panic!("Rerun the packaged icon check with --features verify-packaged-appimage");
        #[cfg(feature = "verify-packaged-appimage")]
        check_packaged_icon();
    }

    #[cfg(feature = "verify-packaged-appimage")]
    fn check_packaged_icon() {
        let path = std::env::var_os("DRILL_PACKAGED_APPIMAGE")
            .unwrap_or_else(|| "dist/Drill-linux-x86_64.AppImage".into());
        let actual =
            drill_icons::decode(std::path::Path::new(&path), || true).expect("read packaged icon");
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
