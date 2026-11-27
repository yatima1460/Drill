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

fn compile_msvc(host: &str, target: &str, units: &[&str], out: &Path, archive: &Path) {
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
            .arg("-Units")
            .arg(units.join(","))
            .arg("-OutDir")
            .arg(out)
            .arg("-Archive")
            .arg(archive)
            .args(["-Crt", crt])
            .args([
                "-TargetArch",
                msvc_arch(target),
                "-HostArch",
                msvc_arch(host),
            ]));
    } else {
        let mut lib = Command::new(librarian);
        let mut output = OsString::from("/OUT:");
        output.push(archive);
        lib.arg(output);
        for unit in units {
            let object = out.join(format!("{unit}.obj"));
            let mut output = OsString::from("/Fo");
            output.push(&object);
            run(Command::new(&compiler)
                .arg(format!("--target={target}"))
                .args(["/nologo", "/TC", "/O2", crt, "/c"])
                .arg(output)
                .arg(format!("src/{unit}.c")));
            lib.arg(object);
        }
        run(&mut lib);
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

fn compile_mingw(host: &str, target: &str, units: &[&str], out: &Path, archive: &Path) {
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
    let mut ar = Command::new(archiver);
    ar.arg("crs").arg(archive);
    for unit in units {
        let object = out.join(format!("{unit}.o"));
        run(Command::new(&compiler)
            .args(["-std=c11", "-O2", "-c"])
            .arg(format!("src/{unit}.c"))
            .arg("-o")
            .arg(&object));
        ar.arg(object);
    }
    run(&mut ar);
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
    // Keep the window (which calls into the Rust model) in its own archive
    // member. Consumers of an adapter can link it independently.
    let mut units = Vec::new();
    for (enabled, unit) in [
        (desktop, "native"),
        (desktop, "accessibility_guids"),
        (clipboard, "clipboard"),
        (menu, "menu"),
        (shell_icons, "file_icon"),
    ] {
        if enabled {
            println!("cargo:rerun-if-changed=src/{unit}.c");
            units.push(unit);
        }
    }
    if units.is_empty() {
        return;
    }

    let target = env::var("TARGET").expect("Cargo target triple");
    let host = env::var("HOST").expect("Cargo host triple");
    let out = PathBuf::from(env::var_os("OUT_DIR").expect("Cargo output directory"));
    let msvc = target.ends_with("-msvc");
    let archive = out.join(if msvc {
        "drill_windows_native.lib"
    } else {
        "libdrill_windows_native.a"
    });
    // ar updates an existing library in place and retains removed or renamed members.
    if archive
        .try_exists()
        .expect("inspect previous native archive")
    {
        std::fs::remove_file(&archive).expect("replace previous native archive");
    }
    if clipboard || menu {
        println!("cargo:rerun-if-changed=src/adapters.h");
    }
    if msvc {
        println!("cargo:rerun-if-changed=build-msvc.ps1");
        compile_msvc(&host, &target, &units, &out, &archive);
    } else {
        compile_mingw(&host, &target, &units, &out, &archive);
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
            "src/window_icon_path.h",
            "src/window_panels.c",
            "src/window.c",
            "src/window_table.c",
            "src/window_placement.c",
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
