@echo off
rem Gera builds\Monstel-debug.apk (APK de debug, assinado com a chave de debug local).
rem Pre-requisitos: templates do Godot 4.7.2, JDK 17 e Android SDK.
rem Os caminhos do JDK/SDK e da chave ficam nas Configuracoes do Editor do Godot (veja o README).
setlocal
if not defined GODOT_CONSOLE set "GODOT_CONSOLE=C:\Users\du-xb\Documents\Godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT_CONSOLE%" (
  where godot_console >nul 2>&1 && set "GODOT_CONSOLE=godot_console"
  if not exist "%GODOT_CONSOLE%" where godot >nul 2>&1 && set "GODOT_CONSOLE=godot"
)
set "PROJ=%~dp0.."
if not exist "%PROJ%\builds" mkdir "%PROJ%\builds"
"%GODOT_CONSOLE%" --headless --path "%PROJ%" --import
"%GODOT_CONSOLE%" --headless --path "%PROJ%" --export-debug "Android" "builds/Monstel-debug.apk"
if errorlevel 1 (
  echo.
  echo A exportacao falhou. Veja as mensagens acima e a secao "Gerar o APK" do README.
  exit /b 1
)
echo.
echo Pronto: %PROJ%\builds\Monstel-debug.apk
