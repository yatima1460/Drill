set PATH=.\bin;C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\IDE;C:\Program Files (x86)\Windows Kits\10\bin;%PATH%

echo API.d >"x64\Debug GDC\Core.build.rsp"
echo Crawler.d >>"x64\Debug GDC\Core.build.rsp"
echo FileInfo.d >>"x64\Debug GDC\Core.build.rsp"
echo Utils.d >>"x64\Debug GDC\Core.build.rsp"
echo "C:/Users/feder/Documents/GitHub/Drill/Libraries/datefmt/x64/Debug GDC/datefmt.lib" >>"x64\Debug GDC\Core.build.rsp"

"C:\Program Files (x86)\VisualD\pipedmd.exe" -gdcmode -deps "x64\Debug GDC\Core.dep" gdc -mconsole -m64 -g -fno-inline-functions -fdebug -fXf="x64\Debug GDC\Core.json" -c -o "x64\Debug GDC\Core.o" @"x64\Debug GDC\Core.build.rsp"
if %errorlevel% neq 0 goto reportError


echo "x64\Debug GDC/Core.o" >"x64\Debug GDC\Core.link.rsp"
echo "C:/Users/feder/Documents/GitHub/Drill/Libraries/datefmt/x64/Debug GDC/datefmt.lib" >>"x64\Debug GDC\Core.link.rsp"

ar cru "x64\Debug GDC\Core.lib" @"x64\Debug GDC\Core.link.rsp"
if %errorlevel% neq 0 goto reportError
if not exist "x64\Debug GDC\Core.lib" (echo "x64\Debug GDC\Core.lib" not created! && goto reportError)

goto noError

:reportError
echo Building x64\Debug GDC\Core.lib failed!

:noError
