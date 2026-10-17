@echo off
setlocal EnableExtensions

rem Remove the tree install.bat wrote, and the Start menu entry, PATH edit
rem and uninstall key when that install registered them. The work runs from
rem a copy in TEMP so the tree can be deleted out from under this file.

if /I "%~1"=="--finish" goto finish
set "HERE=%~dp0"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"
if not exist "%HERE%\install-info.txt" (
  echo uninstall.bat: %HERE% is not an installed Rune 1>&2
  exit /b 1
)
set "ME=%TEMP%\rune-uninstall-%RANDOM%.bat"
copy /Y "%~f0" "%ME%" >nul
if errorlevel 1 (
  echo uninstall.bat: could not copy itself to TEMP 1>&2
  exit /b 1
)
"%ME%" --finish "%HERE%"
set "RC=%ERRORLEVEL%"
del /F /Q "%ME%" >nul 2>&1
exit /b %RC%

:finish
set "PREFIX=%~2"
if "%PREFIX:~-1%"=="\" set "PREFIX=%PREFIX:~0,-1%"
rem The prompt that launched this file may still be inside the tree, and
rem Windows will not remove a process's current directory.
cd /d "%TEMP%"
if not exist "%PREFIX%\install-info.txt" (
  echo uninstall.bat: %PREFIX% is not an installed Rune 1>&2
  exit /b 1
)

set "REGVAL=0"
set "STARTMENU="
set "SCOPE=User"
set "UNINSTKEY="
set "VERSION="
for /f "usebackq tokens=1,* delims==" %%A in ("%PREFIX%\install-info.txt") do (
  if /I "%%A"=="registered" set "REGVAL=%%B"
  if /I "%%A"=="startmenu" set "STARTMENU=%%B"
  if /I "%%A"=="pathscope" set "SCOPE=%%B"
  if /I "%%A"=="uninstkey" set "UNINSTKEY=%%B"
  if /I "%%A"=="version" set "VERSION=%%B"
)
if "%REGVAL%"=="1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%PREFIX%\register.ps1" -Undo -Prefix "%PREFIX%" -StartMenu "%STARTMENU%" -Scope %SCOPE% -UninstKey "%UNINSTKEY%" -Version "%VERSION%"
  if errorlevel 1 (
    echo uninstall.bat: could not remove the registration 1>&2
    exit /b 1
  )
)

if not exist "%PREFIX%\DISTMANIFEST" (
  echo uninstall.bat: %PREFIX%\DISTMANIFEST is missing 1>&2
  exit /b 1
)
copy /Y "%PREFIX%\DISTMANIFEST" "%TEMP%\rune-dist-manifest.txt" >nul
for /f "usebackq delims=" %%F in ("%TEMP%\rune-dist-manifest.txt") do (
  del /F /Q "%%F" >nul 2>&1
  call :cleandir "%%~dpF"
)
del /F /Q "%TEMP%\rune-dist-manifest.txt" >nul 2>&1
rmdir "%PREFIX%" >nul 2>&1
echo uninstalled rune from %PREFIX%
exit /b 0

:cleandir
set "D=%~1"
if "%D:~-1%"=="\" set "D=%D:~0,-1%"
:cleanloop
if /I "%D%"=="%PREFIX%" exit /b 0
rmdir "%D%" >nul 2>&1
if errorlevel 1 exit /b 0
for %%P in ("%D%") do set "PARENT=%%~dpP"
if "%PARENT:~-1%"=="\" set "PARENT=%PARENT:~0,-1%"
if /I "%PARENT%"=="%D%" exit /b 0
set "D=%PARENT%"
goto cleanloop
