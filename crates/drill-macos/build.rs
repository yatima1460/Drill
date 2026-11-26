use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;

fn run(command: &mut Command) {
    let status = command
        .status()
        .unwrap_or_else(|err| panic!("could not run {command:?}: {err}"));
    assert!(status.success(), "{command:?} failed with {status}");
}

fn stdout(command: &mut Command) -> String {
    let output = command
        .output()
        .unwrap_or_else(|err| panic!("could not run {command:?}: {err}"));
    assert!(
        output.status.success(),
        "{command:?} failed with {}: {}",
        output.status,
        String::from_utf8_lossy(&output.stderr)
    );
    String::from_utf8(output.stdout).expect("UTF-8 tool output")
}

fn main() {
    if env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("macos") {
        return;
    }

    for variable in ["DEVELOPER_DIR", "SDKROOT", "MACOSX_DEPLOYMENT_TARGET"] {
        println!("cargo:rerun-if-env-changed={variable}");
    }
    // Includes the native sources and all of their local headers.
    println!("cargo:rerun-if-changed=src");

    let target = env::var("TARGET").unwrap();
    let arch = match env::var("CARGO_CFG_TARGET_ARCH").as_deref() {
        Ok("aarch64") => "arm64",
        Ok("x86_64") => "x86_64",
        arch => panic!("unsupported macOS architecture {arch:?}"),
    };
    let rustc = env::var_os("RUSTC").unwrap();
    let deployment = stdout(
        Command::new(rustc)
            .args(["--print", "deployment-target", "--target"])
            .arg(target),
    );
    let minimum = deployment
        .trim()
        .strip_prefix("MACOSX_DEPLOYMENT_TARGET=")
        .filter(|value| !value.is_empty())
        .expect("rustc must report a macOS deployment target");
    let sdk = env::var_os("SDKROOT")
        .filter(|root| !root.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| {
            PathBuf::from(
                stdout(Command::new("xcrun").args(["--sdk", "macosx", "--show-sdk-path"])).trim(),
            )
        });
    let output = PathBuf::from(env::var_os("OUT_DIR").unwrap());
    let source = Path::new("src");
    let optimization = env::var("OPT_LEVEL").unwrap();

    let mut objects = Vec::new();
    for module in ["clipboard", "file_icon", "menu", "permissions", "png"] {
        let object = output.join(format!("{module}.o"));
        run(Command::new("xcrun")
            .args(["--sdk", "macosx", "clang", "-arch", arch, "-isysroot"])
            .arg(&sdk)
            .arg(format!("-mmacosx-version-min={minimum}"))
            .arg(format!("-O{optimization}"))
            .args(["-fobjc-arc", "-c"])
            .arg(source.join(format!("{module}.m")))
            .arg("-o")
            .arg(&object));
        objects.push(object);
    }
    run(Command::new("xcrun")
        .args(["--sdk", "macosx", "libtool", "-static", "-o"])
        .arg(output.join("libdrill_macos_native.a"))
        .args(objects));

    println!("cargo:rustc-link-search=native={}", output.display());
    println!("cargo:rustc-link-lib=static=drill_macos_native");
    println!("cargo:rustc-link-lib=framework=AppKit");
    println!("cargo:rustc-link-lib=framework=Foundation");
    println!("cargo:rustc-link-lib=dylib=objc");
}
