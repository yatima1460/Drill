use std::{env, ffi::OsString, fs, path::PathBuf, process::Command};

const PACKAGES: &[&str] = &["gtk+-3.0", "gio-unix-2.0"];
const SOURCES: &[&str] = &[
    "linux_app_catalog.c",
    "desktop_theme.c",
    "desktop_theme_test.c",
];

fn setting(name: &str, target: &str, native: bool) -> Option<OsString> {
    let kind = if native { "HOST" } else { "TARGET" };
    [
        format!("{name}_{target}"),
        format!("{name}_{}", target.replace('-', "_")),
        format!("{kind}_{name}"),
        name.to_owned(),
    ]
    .into_iter()
    .find_map(|key| {
        println!("cargo:rerun-if-env-changed={key}");
        env::var_os(key)
    })
}

// pkg-config escapes literal bytes with a backslash. Compiler overrides can
// also use shell-style quoting. Neither source is evaluated by a shell.
fn arguments(output: &str, quoted: bool) -> Option<Vec<String>> {
    let mut words = Vec::new();
    let mut word = None::<String>;
    let mut quote = None;
    let mut chars = output.chars();
    while let Some(ch) = chars.next() {
        match (quote, ch) {
            (Some(current), ch) if ch == current => quote = None,
            (None, '\'' | '"') if quoted => {
                quote = Some(ch);
                word.get_or_insert_with(String::new);
            }
            (None, ch) if ch.is_ascii_whitespace() => words.extend(word.take()),
            (current, '\\') if current != Some('\'') => {
                let next = chars.next()?;
                if quoted && next == '\n' {
                    continue;
                }
                let word = word.get_or_insert_with(String::new);
                if current == Some('"') && !matches!(next, '\\' | '"' | '$' | '`') {
                    word.push('\\');
                }
                word.push(next);
            }
            _ => word.get_or_insert_with(String::new).push(ch),
        }
    }
    if quote.is_some() {
        return None;
    }
    words.extend(word);
    Some(words)
}

fn pkg_config(option: &str, target: &str, native: bool) -> Vec<String> {
    let configured = |name| setting(name, target, native);
    let tool = configured("PKG_CONFIG");
    let sysroot = configured("PKG_CONFIG_SYSROOT_DIR");
    if !native {
        let allow = configured("PKG_CONFIG_ALLOW_CROSS");
        assert!(
            allow.as_deref().is_some_and(|value| value != "0")
                || (allow.is_none() && (tool.is_some() || sysroot.is_some())),
            "configure cross-compilation with a target pkg-config or PKG_CONFIG_SYSROOT_DIR"
        );
    }
    let mut command = Command::new(tool.unwrap_or_else(|| "pkg-config".into()));
    for name in ["PKG_CONFIG_PATH", "PKG_CONFIG_LIBDIR"] {
        if let Some(value) = configured(name) {
            command.env(name, value);
        }
    }
    if let Some(value) = sysroot {
        command.env("PKG_CONFIG_SYSROOT_DIR", value);
    }
    let output = command
        .args([option])
        .args(PACKAGES)
        .output()
        .expect("run pkg-config");
    assert!(
        output.status.success(),
        "pkg-config could not locate the GTK 3 and GIO development files: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    arguments(
        std::str::from_utf8(&output.stdout).expect("UTF-8 pkg-config flags"),
        false,
    )
    .expect("unterminated pkg-config escape")
}

fn run(command: &mut Command) {
    let status = command
        .status()
        .unwrap_or_else(|error| panic!("run {command:?}: {error}"));
    assert!(status.success(), "{command:?} failed: {status}");
}

fn main() {
    if env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("linux") {
        return;
    }
    let out = PathBuf::from(env::var_os("OUT_DIR").unwrap());
    let target = env::var("TARGET").unwrap();
    let native = env::var("HOST").as_deref() == Ok(target.as_str());
    let prefix = target.replace("-unknown-", "-");
    let compiler = setting("CC", &target, native).unwrap_or_else(|| {
        if native {
            "cc".into()
        } else {
            format!("{prefix}-gcc").into()
        }
    });
    let archiver = setting("AR", &target, native).unwrap_or_else(|| {
        if native {
            "ar".into()
        } else {
            format!("{prefix}-ar").into()
        }
    });
    let sdk_flags = pkg_config("--cflags", &target, native);
    let cflags = setting("CFLAGS", &target, native).map_or_else(Vec::new, |value| {
        arguments(value.to_str().expect("UTF-8 CFLAGS"), true)
            .expect("unterminated quote or escape in CFLAGS")
    });
    let archive = out.join("libdrill_gtk.a");
    let mut objects = Vec::new();

    let mut sources = SOURCES.to_vec();
    if env::var_os("CARGO_FEATURE_DESKTOP").is_some() {
        sources.extend([
            "window.c",
            "window_table.c",
            "window_actions.c",
            "window_panels.c",
            "window_icons.c",
        ]);
        println!("cargo:rerun-if-changed=../drill-desktop/include/DrillDesktop.h");
        for header in [
            "window_table.h",
            "window_actions.h",
            "window_panels.h",
            "window_icons.h",
        ] {
            println!("cargo:rerun-if-changed=src/{header}");
        }
    }
    for name in sources {
        let source = format!("src/{name}");
        println!("cargo:rerun-if-changed={source}");
        let object = out.join(name.replace(".c", ".o"));
        run(Command::new(&compiler)
            .args(["-fPIC", "-c", "-I../drill-desktop/include"])
            .arg(format!("-O{}", env::var("OPT_LEVEL").unwrap()))
            .args(&sdk_flags)
            .args(&cflags)
            .arg(&source)
            .arg("-o")
            .arg(&object));
        objects.push(object);
    }
    if archive.exists() {
        fs::remove_file(&archive).expect("remove previous GTK archive");
    }
    run(Command::new(archiver)
        .arg("crs")
        .arg(&archive)
        .args(objects));
    println!("cargo:rustc-link-search=native={}", out.display());
    println!("cargo:rustc-link-lib=static=drill_gtk");
    for flag in pkg_config("--libs-only-L", &target, native) {
        let path = flag.strip_prefix("-L").expect("pkg-config library path");
        println!("cargo:rustc-link-search=native={path}");
    }
    for flag in pkg_config("--libs-only-l", &target, native) {
        let lib = flag.strip_prefix("-l").expect("pkg-config library name");
        println!("cargo:rustc-link-lib={lib}");
    }
}
