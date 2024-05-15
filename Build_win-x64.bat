@echo off

dotnet restore WinForms\WinForms.csproj --locked-mode
if %ERRORLEVEL% neq 0 (
    echo Restore failed with error code %ERRORLEVEL%.
    exit /b %ERRORLEVEL%
)

dotnet clean -maxCpuCount WinForms\WinForms.csproj
if %ERRORLEVEL% neq 0 (
    echo Cleaning failed with error code %ERRORLEVEL%.
    exit /b %ERRORLEVEL%
)

dotnet publish -maxCpuCount WinForms\WinForms.csproj /p:DebugType=None /p:DebugSymbols=False /p:Configuration=Release /p:Platform=x64 /p:EnableCompressionInSingleFile=true /p:CopyOutputSymbolsToPublishDirectory=false /p:IncludeNativeLibrariesForSelfExtract=true /p:PublishTrimmed=false /p:SelfContained=true /p:PublishSingleFile=true /p:PublishReadyToRun=true /p:TargetFramework=net8.0-windows /p:RuntimeIdentifier=win-x64 /p:PublishDir=%CD%\bin
if %ERRORLEVEL% neq 0 (
    echo Publishing failed with error code %ERRORLEVEL%.
    exit /b %ERRORLEVEL%
)

move bin\Drill.exe bin\Drill_win-x64.exe
if %ERRORLEVEL% neq 0 (
    echo Moving file failed with error code %ERRORLEVEL%.
    exit /b %ERRORLEVEL%
)

dir bin\Drill_win-x64.exe
if %ERRORLEVEL% neq 0 (
    echo Directory listing failed with error code %ERRORLEVEL%.
    exit /b %ERRORLEVEL%
)

echo Script completed successfully.
exit /b 0