@echo off
rem Atalhos de desenvolvimento. Uso:
rem   tools\dev.bat import              importa recursos e atualiza o cache de class_name (headless)
rem   tools\dev.bat run                 abre o jogo
rem   tools\dev.bat smoke               carrega o projeto sem janela e sai (procura erros de script)
rem   tools\dev.bat script res://x.gd [args]   roda um script (extends SceneTree) sem janela
setlocal
if not defined GODOT_CONSOLE set "GODOT_CONSOLE=C:\Users\du-xb\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT_CONSOLE%" (
  where godot_console >nul 2>&1 && set "GODOT_CONSOLE=godot_console"
  if not exist "%GODOT_CONSOLE%" where godot >nul 2>&1 && set "GODOT_CONSOLE=godot"
)
set "PROJ=%~dp0.."
set "CMD=%~1"
if "%CMD%"=="" goto help
if /i "%CMD%"=="import" "%GODOT_CONSOLE%" --headless --path "%PROJ%" --import & goto :eof
if /i "%CMD%"=="run"    "%GODOT_CONSOLE%" --path "%PROJ%" & goto :eof
if /i "%CMD%"=="smoke"  "%GODOT_CONSOLE%" --headless --path "%PROJ%" --quit-after 120 & goto :eof
if /i "%CMD%"=="script" "%GODOT_CONSOLE%" --headless --path "%PROJ%" --script %2 -- %3 %4 %5 %6 %7 %8 %9 & goto :eof
:help
echo uso: dev.bat import ^| run ^| smoke ^| script ^<res://caminho.gd^> [args]
