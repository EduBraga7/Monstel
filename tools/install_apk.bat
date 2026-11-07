@echo off
rem Instala o APK no celular conectado por USB (com "Depuracao USB" ativada) e abre o jogo.
setlocal
if not defined ADB set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" (
  where adb >nul 2>&1 && set "ADB=adb"
)
set "PROJ=%~dp0.."
if not exist "%ADB%" if not "%ADB%"=="adb" (
  echo adb nao encontrado em %ADB% nem no PATH.
  exit /b 1
)
if not exist "%PROJ%\builds\Monstel-debug.apk" (
  echo Gere o APK antes: tools\build_apk.bat
  exit /b 1
)
"%ADB%" devices
"%ADB%" install -r "%PROJ%\builds\Monstel-debug.apk"
if errorlevel 1 (
  echo.
  echo Falhou. Confira o cabo, a "Depuracao USB" e se o celular autorizou este computador.
  echo Se ja existir o Monstel com outra assinatura no aparelho, desinstale-o antes.
  exit /b 1
)
"%ADB%" shell monkey -p com.monstel.game -c android.intent.category.LAUNCHER 1
"%ADB%" kill-server
