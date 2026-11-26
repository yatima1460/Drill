fn main() {
    println!("cargo:rerun-if-changed=src/assets/drill.rc");
    println!("cargo:rerun-if-changed=src/assets/drill.ico");
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        embed_resource::compile_for("src/assets/drill.rc", ["drill"], embed_resource::NONE)
            .manifest_required()
            .expect("could not embed the Drill executable icon");
    }
}
