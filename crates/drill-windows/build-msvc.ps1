param(
    [string]$Compiler,
    [string]$Librarian,
    [string]$Source,
    [string]$Object,
    [string]$Archive,
    [string]$Defines,
    [ValidateSet('/MD', '/MT')][string]$Crt,
    [string]$TargetArch,
    [string]$HostArch
)

$ErrorActionPreference = 'Stop'
$activeArch = $env:VSCMD_ARG_TGT_ARCH -replace '^x64$', 'amd64'
if ($activeArch -ne $TargetArch -or !$env:INCLUDE -or !$env:LIB) {
    $programFiles = ${env:ProgramFiles(x86)}
    if (!$programFiles) { $programFiles = $env:ProgramFiles }
    $vswhere = Join-Path $programFiles 'Microsoft Visual Studio\Installer\vswhere.exe'
    $components = @('Microsoft.VisualStudio.Component.VC.Tools.x86.x64')
    if ($TargetArch -eq 'arm64' -or $HostArch -eq 'arm64') {
        $components += 'Microsoft.VisualStudio.Component.VC.Tools.ARM64'
    }
    $install = & $vswhere -latest -products '*' -requires @components -property installationPath |
        Select-Object -First 1
    if (!$install) { throw 'Visual Studio C++ Build Tools and the Windows SDK are required.' }
    $devShell = Join-Path $install 'Common7\Tools\Launch-VsDevShell.ps1'
    & $devShell -Arch $TargetArch -HostArch $HostArch -SkipAutomaticLocation | Out-Null
}

$defineArguments = @($Defines -split ',' | ForEach-Object { "/D$_" })
& $Compiler '/nologo' '/TC' '/O2' $Crt '/c' @defineArguments "/Fo$Object" $Source
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $Librarian '/nologo' "/OUT:$Archive" $Object
exit $LASTEXITCODE
