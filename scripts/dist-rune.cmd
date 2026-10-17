@echo off
setlocal EnableExtensions EnableDelayedExpansion
if /I not "%~1"=="-i" goto compile
shift
set "rest="
:collect
if "%~1"=="" goto runrepl
set "rest=!rest! "%~1""
shift
goto collect
:runrepl
endlocal & "%~dp0rune-repl.cmd" %rest%
exit /b %ERRORLEVEL%
:compile
endlocal & "%~dp0runevm.exe" --heap-size 67108864 "%~dp0..\lib\rune\rune.rbc" --lib "%~dp0..\lib\rune" %*
