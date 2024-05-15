
@echo off

dotnet clean
if %errorlevel% neq 0 exit /b %errorlevel%
echo Clean done

dotnet restore
if %errorlevel% neq 0 exit /b %errorlevel%
echo Restore done

dotnet build -t:Build -p:Configuration=Release -f net8.0-windows10.0.19041.0 UI\UI.csproj /p:WindowsAppSDKSelfContained=true /p:Platform=x64 /p:WindowsPackageType=None 
if %errorlevel% neq 0 exit /b %errorlevel%
echo Release done

dir UI\bin\Release\net8.0-windows10.0.19041.0\win10-x64
if %errorlevel% neq 0 exit /b %errorlevel%
dir UI\bin\Release\net8.0-windows10.0.19041.0\win10-x64\Drill.exe
if %errorlevel% neq 0 exit /b %errorlevel%

echo All done