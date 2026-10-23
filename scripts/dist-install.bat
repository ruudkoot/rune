@echo off
rem A double-clicked window closes when this file exits. Do the install in
rem a child, then wait for a key. The child sees RUNE_INSTALL_PAUSE.
if defined RUNE_INSTALL_PAUSE goto install
set RUNE_INSTALL_PAUSE=1
cmd /c "%~f0" %*
set "RC=%ERRORLEVEL%"
pause
exit /b %RC%

:install
setlocal EnableExtensions

rem Install this archive. With no arguments an elevated prompt installs for
rem everyone and any other prompt installs for the current user.
rem   install.bat [--prefix DIR] [--arch NAME] [--start-menu DIR] [--no-register]

set "PREFIX="
set "ARCH="
set "STARTMENU="
set "NOREG=0"

rem Keep the original script path in %0 for archive-relative inputs.
:parse
if "%~1"=="" goto parsed
if /I "%~1"=="--help" goto help
if /I "%~1"=="-h" goto help
if /I "%~1"=="--prefix" (
  if "%~2"=="" goto badarg
  set "PREFIX=%~2"
  shift /1
  shift /1
  goto parse
)
if /I "%~1"=="--arch" (
  if "%~2"=="" goto badarg
  set "ARCH=%~2"
  shift /1
  shift /1
  goto parse
)
if /I "%~1"=="--start-menu" (
  if "%~2"=="" goto badarg
  set "STARTMENU=%~2"
  shift /1
  shift /1
  goto parse
)
if /I "%~1"=="--no-register" (
  set "NOREG=1"
  shift /1
  goto parse
)
echo install.bat: unknown argument: %~1 1>&2
echo usage: install.bat [--prefix DIR] [--arch NAME] [--start-menu DIR] [--no-register] 1>&2
exit /b 2

:badarg
echo install.bat: missing value after %~1 1>&2
exit /b 2

:help
echo usage: install.bat [--prefix DIR] [--arch NAME] [--start-menu DIR] [--no-register]
exit /b 0

:parsed
if not defined ARCH goto detect
if /I "%ARCH%"=="x86_64" goto arch_ok
if /I "%ARCH%"=="i686" goto arch_ok
echo install.bat: %ARCH% is not a supported machine. Rune installs x86_64 and i686. 1>&2
exit /b 1

:detect
if /I "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "ARCH=x86_64" & goto arch_ok
if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" goto arch_bad
if defined PROCESSOR_ARCHITEW6432 if /I "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "ARCH=x86_64" & goto arch_ok
if /I "%PROCESSOR_ARCHITECTURE%"=="x86" set "ARCH=i686" & goto arch_ok
:arch_bad
echo install.bat: %PROCESSOR_ARCHITECTURE% is not a supported machine. Rune installs x86_64 and i686. 1>&2
exit /b 1

:arch_ok
reg query HKU\S-1-5-19 >nul 2>&1
if errorlevel 1 (set "ELEVATED=0") else (set "ELEVATED=1")

if not defined PREFIX if "%ELEVATED%"=="1" set "PREFIX=%ProgramFiles%\Rune"
if not defined PREFIX set "PREFIX=%LOCALAPPDATA%\Rune"
if "%ELEVATED%"=="1" (
  set "SCOPE=Machine"
  set "UNINSTKEY=HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Rune"
) else (
  set "SCOPE=User"
  set "UNINSTKEY=HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Rune"
)
if not defined STARTMENU if "%ELEVATED%"=="1" set "STARTMENU=%ProgramData%\Microsoft\Windows\Start Menu\Programs"
if not defined STARTMENU set "STARTMENU=%APPDATA%\Microsoft\Windows\Start Menu\Programs"
rem An absolute prefix, so the manifest does not name a path that only
rem means something from the prompt that ran the installer.
for %%P in ("%PREFIX%") do set "PREFIX=%%~fP"
rem XCOPY may silently omit long names. Reject unsupported source/target
rem lengths before creating a prefix; ordinary manifests and uninstall use
rem the same Windows path limit. Paths reach PowerShell through environment
rem values, never through executable command text.
set "RUNE_INSTALL_SOURCE=%~dp0"
powershell -NoProfile -Command "$ErrorActionPreference='Stop'; try { if ($env:PREFIX.Length -gt 248 -or $env:RUNE_INSTALL_SOURCE.TrimEnd([char]92).Length -gt 248) { throw 'archive or installation directory is too long; use shorter paths' }; foreach ($directory in [IO.Directory]::EnumerateDirectories($env:RUNE_INSTALL_SOURCE, '*', [IO.SearchOption]::AllDirectories)) { $relative=$directory.Substring($env:RUNE_INSTALL_SOURCE.Length); if ($directory.Length -gt 248 -or [IO.Path]::Combine($env:PREFIX, $relative).Length -gt 248) { throw 'archive or installation directory is too long; use shorter paths' } }; foreach ($file in [IO.Directory]::EnumerateFiles($env:RUNE_INSTALL_SOURCE, '*', [IO.SearchOption]::AllDirectories)) { $relative=$file.Substring($env:RUNE_INSTALL_SOURCE.Length); if ($file.Length -ge 260 -or [IO.Path]::Combine($env:PREFIX, $relative).Length -ge 260) { throw 'archive or installation path is too long; use shorter paths' } } } catch { [Console]::Error.WriteLine('install.bat: ' + $_.Exception.Message); exit 1 }"
if errorlevel 1 (
  echo install.bat: installation path preflight failed; PowerShell and supported paths are required 1>&2
  exit /b 1
)
if not exist "%PREFIX%" mkdir "%PREFIX%"
pushd "%PREFIX%"
if errorlevel 1 (
  echo install.bat: cannot use %PREFIX% 1>&2
  exit /b 1
)
set "PREFIX=%CD%"
popd

set /p VERSION=<"%~dp0VERSION"
if not defined VERSION (
  echo install.bat: VERSION is missing 1>&2
  exit /b 1
)
set "SRC=%~dp0runtime\%ARCH%\runevm.exe"
if not exist "%SRC%" (
  echo install.bat: no runtime for %ARCH% 1>&2
  exit /b 1
)
if not exist "%~dp0lib\rune\" (
  echo install.bat: the archive has no lib\rune 1>&2
  exit /b 1
)

mkdir "%PREFIX%\bin" 2>nul
mkdir "%PREFIX%\lib\rune" 2>nul
copy /Y "%SRC%" "%PREFIX%\bin\runevm.exe" >nul
if errorlevel 1 (
  echo install.bat: could not copy the runtime 1>&2
  exit /b 1
)
xcopy /E /I /Y /Q "%~dp0lib\rune" "%PREFIX%\lib\rune" >nul
if errorlevel 1 (
  echo install.bat: could not copy the libraries 1>&2
  exit /b 1
)
copy /Y "%~dp0wrappers\rune.cmd" "%PREFIX%\bin\rune.cmd" >nul
copy /Y "%~dp0wrappers\rune-repl.cmd" "%PREFIX%\bin\rune-repl.cmd" >nul
if exist "%~dp0wrappers\runeffi.cmd" copy /Y "%~dp0wrappers\runeffi.cmd" "%PREFIX%\bin\runeffi.cmd" >nul
copy /Y "%~dp0uninstall.bat" "%PREFIX%\uninstall.bat" >nul
copy /Y "%~dp0register.ps1" "%PREFIX%\register.ps1" >nul
copy /Y "%~dp0LICENSE" "%PREFIX%\LICENSE" >nul
copy /Y "%~dp0VERSION" "%PREFIX%\VERSION" >nul
mkdir "%PREFIX%\share" 2>nul
copy /Y "%~dp0share\rune.ico" "%PREFIX%\share\rune.ico" >nul
if errorlevel 1 (
  echo install.bat: could not copy the installer 1>&2
  exit /b 1
)

set "REGVAL=1"
if "%NOREG%"=="1" set "REGVAL=0"
> "%PREFIX%\install-info.txt" echo elevated=%ELEVATED%
>> "%PREFIX%\install-info.txt" echo registered=%REGVAL%
>> "%PREFIX%\install-info.txt" echo startmenu=%STARTMENU%
>> "%PREFIX%\install-info.txt" echo pathscope=%SCOPE%
>> "%PREFIX%\install-info.txt" echo uninstkey=%UNINSTKEY%
>> "%PREFIX%\install-info.txt" echo version=%VERSION%

dir /s /b /a-d "%PREFIX%" > "%TEMP%\rune-dist-files.txt"
copy /Y "%TEMP%\rune-dist-files.txt" "%PREFIX%\DISTMANIFEST" >nul
>> "%PREFIX%\DISTMANIFEST" echo %PREFIX%\DISTMANIFEST
del /F /Q "%TEMP%\rune-dist-files.txt" >nul 2>&1

if "%NOREG%"=="0" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0register.ps1" -Prefix "%PREFIX%" -StartMenu "%STARTMENU%" -Scope %SCOPE% -UninstKey "%UNINSTKEY%" -Version "%VERSION%"
  if errorlevel 1 (
    echo install.bat: could not register the install 1>&2
    exit /b 1
  )
)

echo installed rune in %PREFIX%
exit /b 0
