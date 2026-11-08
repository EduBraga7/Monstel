@echo off
rem Abre o Monstel no PC usando o Godot 4.7.2 (nao precisa exportar nada).
rem Para usar outro Godot, defina a variavel GODOT_EXE antes de rodar ou adicione ao PATH.
setlocal
if not defined GODOT_EXE set "GODOT_EXE=C:\Users\du-xb\Documents\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  where godot >nul 2>&1 && set "GODOT_EXE=godot"
)
if not exist "%GODOT_EXE%" if not "%GODOT_EXE%"=="godot" (
  echo Godot nao encontrado em: %GODOT_EXE%
  echo Defina a variavel GODOT_EXE, adicione ao PATH ou edite este arquivo.
  pause
  exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0"
