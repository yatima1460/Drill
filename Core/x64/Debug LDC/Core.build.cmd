set PATH=.\bin;C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\bin\HostX86\x64;C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\IDE;C:\Program Files (x86)\Windows Kits\10\bin;%PATH%
set LIB=C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\lib\x64;C:\Program Files (x86)\Windows Kits\10\Lib\10.0.17763.0\ucrt\x64;C:\Program Files (x86)\Windows Kits\10\lib\10.0.17763.0\um\x64
set VCINSTALLDIR=C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\
set VCTOOLSINSTALLDIR=C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\
set VSINSTALLDIR=C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\
set WindowsSdkDir=C:\Program Files (x86)\Windows Kits\10\
set WindowsSdkVersion=10.0.17763.0
set UniversalCRTSdkDir=C:\Program Files (x86)\Windows Kits\10\
set UCRTVersion=10.0.17763.0

echo API.d >"x64\Debug LDC\Core.build.rsp"
echo Crawler.d >>"x64\Debug LDC\Core.build.rsp"
echo FileInfo.d >>"x64\Debug LDC\Core.build.rsp"
echo Utils.d >>"x64\Debug LDC\Core.build.rsp"
echo "C:\Users\feder\Documents\GitHub\Drill\Libraries\datefmt\x64\Debug LDC\datefmt.lib" >>"x64\Debug LDC\Core.build.rsp"

"C:\Program Files (x86)\VisualD\pipedmd.exe" -deps "x64\Debug LDC\Core.dep" ldc2 -lib -oq -od="x64\Debug LDC" -m64 -g -d-debug -X -Xf="x64\Debug LDC\Core.json" -of="x64\Debug LDC\Core.lib" @"x64\Debug LDC\Core.build.rsp"
if %errorlevel% neq 0 goto reportError
if not exist "x64\Debug LDC\Core.lib" (echo "x64\Debug LDC\Core.lib" not created! && goto reportError)

goto noError

:reportError
echo Building x64\Debug LDC\Core.lib failed!

:noError
