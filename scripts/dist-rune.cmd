@echo off
setlocal EnableExtensions EnableDelayedExpansion
if /I not "%~1"=="-i" goto compile
rem Keep %0 while forwarding -i arguments to the neighbouring launcher.
shift /1
set "rest="
:collect
if "%~1"=="" goto runrepl
set "rest=!rest! "%~1""
shift /1
goto collect
:runrepl
endlocal & "%~dp0rune-repl.cmd" %rest%
exit /b %ERRORLEVEL%
:compile
endlocal & "%~dp0runevm.exe" --heap-size 67108864 "%~dp0..\lib\rune\rune.rbc" --lib "%~dp0..\lib\rune" %*
