use std::{
    env,
    ffi::{OsStr, OsString},
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

fn compile_msvc(host: &str, target: &str, source: &Path, out: &Path, defines: &[&str]) {
    let object = out.join("drill_windows_native.obj");
    let archive = out.join("drill_windows_native.lib");
    let native = host.contains("-windows-");
    let crt = if env::var("CARGO_CFG_TARGET_FEATURE")
        .is_ok_and(|features| features.split(',').any(|feature| feature == "crt-static"))
    {
        "/MT"
    } else {
        "/MD"
    };
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
            .arg("-Defines")
            .arg(defines.join(","))
            .args(["-Crt", crt])
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
            .args(["/nologo", "/TC", "/O2", crt, "/c"])
            .args(defines.iter().map(|define| format!("/D{define}")))
            .arg(output)
            .arg(source));
        let mut output = OsString::from("/OUT:");
        output.push(archive);
        run(Command::new(librarian).arg(output).arg(object));
    }
}

fn mingw_archiver(compiler: &OsStr, fallback: OsString) -> OsString {
    let reported = Command::new(compiler)
        .arg("-print-prog-name=ar")
        .output()
        .ok()
        .filter(|output| output.status.success())
        .and_then(|output| String::from_utf8(output.stdout).ok());
    let reported = reported.as_deref().map(str::trim).filter(|s| !s.is_empty());
    if let Some(directory) = Path::new(compiler)
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
    {
        for name in reported
            .into_iter()
            .map(OsStr::new)
            .chain([fallback.as_os_str()])
        {
            let sibling = directory.join(name);
            if sibling.is_file() {
                return sibling.into();
            }
            if cfg!(windows) && sibling.with_extension("exe").is_file() {
                return sibling.with_extension("exe").into();
            }
        }
    }
    // A bare "ar" means GCC did not locate its archiver. Avoid picking up
    // the host archiver in a cross build.
    reported
        .filter(|&name| name != "ar")
        .map_or(fallback, Into::into)
}

fn compile_mingw(host: &str, target: &str, source: &Path, out: &Path, defines: &[&str]) {
    let arch = target.split('-').next().unwrap();
    let mingw_tool = |name| {
        if host == target {
            OsString::from(name)
        } else {
            format!("{arch}-w64-mingw32-{name}").into()
        }
    };
    // Cargo exposes the compiler driver chosen by make start_wine or target
    // configuration. Explicit C compiler/archiver overrides still take priority.
    println!("cargo:rerun-if-env-changed=RUSTC_LINKER");
    let linker_env = target.replace('-', "_").to_ascii_uppercase();
    println!("cargo:rerun-if-env-changed=CARGO_TARGET_{linker_env}_LINKER");
    let compiler = tool("CC", target, || {
        env::var_os("RUSTC_LINKER").unwrap_or_else(|| mingw_tool("gcc"))
    });
    let archiver = tool("AR", target, || mingw_archiver(&compiler, mingw_tool("ar")));
    let object = out.join("drill_windows_native.o");
    run(Command::new(compiler)
        .args(["-std=c11", "-O2", "-c"])
        .args(defines.iter().map(|define| format!("-D{define}")))
        .arg(source)
        .arg("-o")
        .arg(&object));
    run(Command::new(archiver)
        .arg("crs")
        .arg(out.join("libdrill_windows_native.a"))
        .arg(object));
}

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    if env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("windows") {
        return;
    }
    let desktop = env::var_os("CARGO_FEATURE_DESKTOP").is_some();
    let clipboard = env::var_os("CARGO_FEATURE_CLIPBOARD").is_some();
    let menu = env::var_os("CARGO_FEATURE_MENU").is_some();
    let shell_icons = env::var_os("CARGO_FEATURE_SHELL_ICONS").is_some();
    let mut defines = Vec::new();
    for (enabled, define, file) in [
        (desktop, "DRILL_DESKTOP", "src/window.c"),
        (clipboard, "DRILL_CLIPBOARD", "src/clipboard.c"),
        (menu, "DRILL_MENU", "src/menu.c"),
        (shell_icons, "DRILL_SHELL_ICONS", "src/file_icon.c"),
    ] {
        if enabled {
            println!("cargo:rerun-if-changed={file}");
            defines.push(define);
        }
    }
    if defines.is_empty() {
        return;
    }

    let target = env::var("TARGET").expect("Cargo target triple");
    let host = env::var("HOST").expect("Cargo host triple");
    let out = PathBuf::from(env::var_os("OUT_DIR").expect("Cargo output directory"));
    let source = Path::new("src/native.c");
    println!("cargo:rerun-if-changed={}", source.display());
    if target.ends_with("-msvc") {
        println!("cargo:rerun-if-changed=build-msvc.ps1");
        compile_msvc(&host, &target, source, &out, &defines);
    } else {
        compile_mingw(&host, &target, source, &out, &defines);
    }

    println!("cargo:rustc-link-search=native={}", out.display());
    println!("cargo:rustc-link-lib=static=drill_windows_native");
    if desktop {
        for file in [
            "../drill-desktop/include/DrillDesktop.h",
            "src/window_actions.h",
            "src/window_actions.c",
            "src/window_shell.c",
            "src/window_preferences.c",
            "src/window_icons.c",
            "src/window_panels.c",
            "src/window_table.c",
            "src/window_accessibility.c",
        ] {
            println!("cargo:rerun-if-changed={file}");
        }
        for library in [
            "shell32", "ole32", "oleaut32", "uuid", "advapi32", "dwmapi", "uxtheme",
        ] {
            println!("cargo:rustc-link-lib={library}");
        }
    }
    if menu {
        println!("cargo:rerun-if-changed=src/menu_appearance.c");
        println!("cargo:rustc-link-lib=comctl32");
        println!("cargo:rustc-link-lib=gdi32");
    }
    if clipboard || menu {
        println!("cargo:rustc-link-lib=user32");
    }
    if shell_icons {
        for library in ["shell32", "ole32", "gdi32", "uuid"] {
            println!("cargo:rustc-link-lib={library}");
        }
    }
}
