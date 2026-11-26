use std::{
    env,
    ffi::OsString,
    path::{Path, PathBuf},
    process::Command,
};

fn tool(var: &str, target: &str, default: impl FnOnce() -> OsString) -> OsString {
    let names = [
        format!("{var}_{target}"),
        format!("{var}_{}", target.replace('-', "_")),
        var.into(),
    ];
    for name in &names {
        println!("cargo:rerun-if-env-changed={name}");
    }
    names.iter().find_map(env::var_os).unwrap_or_else(default)
}

fn run(command: &mut Command) {
    let status = command
        .status()
        .unwrap_or_else(|error| panic!("could not run {command:?}: {error}"));
    assert!(status.success(), "{command:?} failed: {status}");
}

fn msvc_arch(triple: &str) -> &str {
    match triple.split('-').next().unwrap() {
        "x86_64" => "amd64",
        "i686" => "x86",
        "aarch64" => "arm64",
        arch => panic!("unsupported MSVC architecture {arch}"),
    }
}

fn compile_msvc(host: &str, target: &str, source: &Path, out: &Path) {
    let object = out.join("drill_shell_icons.obj");
    let archive = out.join("drill_shell_icons.lib");
    let native = host.contains("-windows-");
    let compiler = tool("CC", target, || {
        if native { "cl.exe" } else { "clang-cl" }.into()
    });
    let librarian = tool("AR", target, || {
        if native { "lib.exe" } else { "llvm-lib" }.into()
    });
    if native {
        run(Command::new("powershell.exe")
            .args([
                "-NoProfile",
                "-NonInteractive",
                "-ExecutionPolicy",
                "Bypass",
            ])
            .args(["-File", "build-msvc.ps1", "-Compiler"])
            .arg(compiler)
            .arg("-Librarian")
            .arg(librarian)
            .arg("-Source")
            .arg(source)
            .arg("-Object")
            .arg(object)
            .arg("-Archive")
            .arg(archive)
            .args([
                "-TargetArch",
                msvc_arch(target),
                "-HostArch",
                msvc_arch(host),
            ]));
    } else {
        let mut output = OsString::from("/Fo");
        output.push(&object);
        run(Command::new(compiler)
            .arg(format!("--target={target}"))
            .args(["/nologo", "/TC", "/O2", "/c"])
            .arg(output)
            .arg(source));
        let mut output = OsString::from("/OUT:");
        output.push(archive);
        run(Command::new(librarian).arg(output).arg(object));
    }
}

fn compile_mingw(host: &str, target: &str, source: &Path, out: &Path) {
    let arch = target.split('-').next().unwrap();
    let mingw_tool = |name| {
        if host == target {
            OsString::from(name)
        } else {
            format!("{arch}-w64-mingw32-{name}").into()
        }
    };
    let compiler = tool("CC", target, || mingw_tool("gcc"));
    let archiver = tool("AR", target, || mingw_tool("ar"));
    let object = out.join("drill_shell_icons.o");
    run(Command::new(compiler)
        .args(["-std=c11", "-O2", "-c"])
        .arg(source)
        .arg("-o")
        .arg(&object));
    run(Command::new(archiver)
        .arg("crs")
        .arg(out.join("libdrill_shell_icons.a"))
        .arg(object));
}

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    if env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("windows")
        || env::var_os("CARGO_FEATURE_SHELL_ICONS").is_none()
    {
        return;
    }

    let target = env::var("TARGET").expect("Cargo target triple");
    let host = env::var("HOST").expect("Cargo host triple");
    let out = PathBuf::from(env::var_os("OUT_DIR").expect("Cargo output directory"));
    let source = Path::new("src/file_icon.c");
    println!("cargo:rerun-if-changed={}", source.display());
    if target.ends_with("-msvc") {
        println!("cargo:rerun-if-changed=build-msvc.ps1");
        compile_msvc(&host, &target, source, &out);
    } else {
        compile_mingw(&host, &target, source, &out);
    }

    println!("cargo:rustc-link-search=native={}", out.display());
    println!("cargo:rustc-link-lib=static=drill_shell_icons");
    for library in ["shell32", "ole32", "gdi32", "uuid"] {
        println!("cargo:rustc-link-lib={library}");
    }
}
