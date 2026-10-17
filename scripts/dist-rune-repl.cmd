@echo off
"%~dp0runevm.exe" --heap-size 67108864 --restore "%~dp0..\lib\rune\rune-repl.img" -- %*
