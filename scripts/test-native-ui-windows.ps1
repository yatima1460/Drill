# Run on a controlled Windows desktop. The driver moves the mouse and uses the clipboard.
param([string]$App, [string]$Driver)
$ErrorActionPreference = 'Stop'
$temp = Join-Path ([IO.Path]::GetTempPath()) ("drill-window-test-" + [Guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $temp
try {
    if (!$App) {
        $cargo = if ($env:CARGO) { $env:CARGO } else { 'cargo' }
        $events = & $cargo build --release --locked -p drill --bin drill --message-format=json-render-diagnostics
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        $App = $events | ForEach-Object { $_ | ConvertFrom-Json } |
            Where-Object { $_.target.name -eq 'drill' -and $_.executable } |
            Select-Object -Last 1 -ExpandProperty executable
    }
    if (!$Driver) {
        $Driver = Join-Path $temp 'drill-native-window.exe'
        $source = Join-Path $PSScriptRoot '..\crates\drill-windows\tests\native_window.c'
        $hostTriple = ((& rustc -vV) -match '^host: ') -replace '^host: ', ''
        if ($hostTriple -like '*-windows-gnu*') {
            & gcc -std=c11 -municode -Wall -Wextra -Werror $source -o $Driver -lgdi32 -ladvapi32 -loleacc -loleaut32 -lole32 -luuid
        } else {
            if (!$env:INCLUDE -or !(Get-Command cl.exe -ErrorAction SilentlyContinue)) {
                $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
                $vs = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
                if (!$vs) { throw 'The native UI test needs Visual Studio C++ Build Tools and the Windows SDK.' }
                $arch = if ($hostTriple -like 'aarch64-*') { 'arm64' } elseif ($hostTriple -like 'i686-*') { 'x86' } else { 'amd64' }
                & (Join-Path $vs 'Common7\Tools\Launch-VsDevShell.ps1') -Arch $arch -HostArch $arch -SkipAutomaticLocation | Out-Null
            }
            $obj = Join-Path $temp 'driver.obj'
            & cl.exe /nologo /W4 /WX /std:c11 /MT $source "/Fo$obj" "/Fe$Driver" user32.lib gdi32.lib advapi32.lib oleacc.lib oleaut32.lib ole32.lib uuid.lib
        }
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    & (Resolve-Path -LiteralPath $Driver).Path (Resolve-Path -LiteralPath $App).Path
    exit $LASTEXITCODE
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force
}
