use std::env;
use std::path::PathBuf;
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
    let sdk = PathBuf::from(
        env::var_os("SDKROOT")
            .filter(|root| !root.is_empty())
            .unwrap_or_else(|| "macosx".into()),
    );
    let sdk = if sdk.is_dir() {
        sdk
    } else {
        let path = stdout(
            Command::new("xcrun")
                .arg("--sdk")
                .arg(sdk)
                .arg("--show-sdk-path"),
        );
        PathBuf::from(path.trim())
    };
    let output = PathBuf::from(env::var_os("OUT_DIR").unwrap());
    let optimization = env::var("OPT_LEVEL").unwrap();

    let object = output.join("drill_macos.o");
    run(Command::new("xcrun")
        .args(["--sdk", "macosx", "clang", "-arch", arch, "-isysroot"])
        .arg(&sdk)
        .arg(format!("-mmacosx-version-min={minimum}"))
        .arg(format!("-O{optimization}"))
        .args(["-fobjc-arc", "-c", "src/drill_macos.m", "-o"])
        .arg(&object));
    run(Command::new("xcrun")
        .args(["--sdk", "macosx", "libtool", "-static", "-o"])
        .arg(output.join("libdrill_macos_native.a"))
        .arg(object));

    println!("cargo:rustc-link-search=native={}", output.display());
    println!("cargo:rustc-link-lib=static=drill_macos_native");
    println!("cargo:rustc-link-lib=framework=AppKit");
    println!("cargo:rustc-link-lib=framework=Foundation");
    println!("cargo:rustc-link-lib=dylib=objc");
}
