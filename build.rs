use std::{env, ffi::OsString, path::PathBuf, process::Command};

// Cargo can find the MSVC linker in an ordinary shell where the Windows SDK's
// rc.exe is not on PATH. Locate the newest installed SDK with a host compiler.
fn windows_sdk_rc() -> OsString {
    let discover = r#"
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$cmd = Get-Command rc.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($cmd) { $cmd.Source; exit 0 }
$kit = $env:WindowsSdkDir
if (!$kit) {
    $kit = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots' KitsRoot10
}
$versions = Get-ChildItem (Join-Path $kit bin) -Directory |
    Where-Object { $_.Name -as [version] } | Sort-Object { [version]$_.Name } -Descending
foreach ($version in $versions) {
    foreach ($arch in @($env:PROCESSOR_ARCHITECTURE.Replace('AMD64', 'x64'), 'x86')) {
        $rc = Join-Path $version.FullName "$arch\rc.exe"
        if (Test-Path -LiteralPath $rc -PathType Leaf) { $rc; exit 0 }
    }
}
throw 'rc.exe not found; install the Windows SDK or set RC'
"#;
    let found = Command::new("powershell.exe")
        .args(["-NoProfile", "-NonInteractive", "-Command", discover])
        .output()
        .expect("locate the Windows SDK resource compiler with PowerShell");
    assert!(
        found.status.success(),
        "could not locate rc.exe: {}",
        String::from_utf8_lossy(&found.stderr)
    );
    String::from_utf8(found.stdout)
        .expect("SDK path must be UTF-8")
        .trim_end()
        .into()
}

fn main() {
    println!("cargo:rerun-if-changed=src/assets/drill.rc");
    println!("cargo:rerun-if-changed=src/assets/drill.ico");
    if env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("windows") {
        return;
    }

    let target = env::var("TARGET").unwrap();
    let msvc = target.ends_with("-msvc");
    let overrides = [
        format!("RC_{target}"),
        format!("RC_{}", target.replace('-', "_")),
        "RC".to_owned(),
    ];
    for key in &overrides {
        println!("cargo:rerun-if-env-changed={key}");
    }
    let compiler = overrides.iter().find_map(env::var_os).unwrap_or_else(|| {
        if msvc {
            if cfg!(windows) {
                windows_sdk_rc()
            } else {
                "llvm-rc".into()
            }
        } else if cfg!(windows) && env::var("HOST").as_deref() == Ok(&target) {
            "windres".into()
        } else {
            let arch = target.split('-').next().unwrap();
            format!("{arch}-w64-mingw32-windres").into()
        }
    });
    let out = PathBuf::from(env::var_os("OUT_DIR").unwrap());
    let mut command = Command::new(&compiler);
    let resource = if msvc {
        let resource = out.join("drill.res");
        command
            .args(["/i", "src/assets", "/fo"])
            .arg(&resource)
            .arg("src/assets/drill.rc");
        resource
    } else {
        let resource = out.join("drill-icon.o");
        command
            .args([
                "-I",
                "src/assets",
                "-O",
                "coff",
                "-i",
                "src/assets/drill.rc",
                "-o",
            ])
            .arg(&resource);
        resource
    };
    let status = command
        .status()
        .unwrap_or_else(|error| panic!("could not run {compiler:?} for {target}: {error}"));
    assert!(
        status.success(),
        "{compiler:?} failed for {target}: {status}"
    );
    println!("cargo:rustc-link-arg-bin=drill={}", resource.display());
}
