@echo off
REM Construye PanelArduino.exe portable (sin admin) a partir de panel_arduino.py
REM Este .bat vive en arduino\apps\windows\ y el .py en arduino\apps\ (un
REM nivel arriba): el script se coloca alli solo, da igual desde donde lo
REM lances (doble clic incluido).
REM Requisitos: Python en Windows (Store o instalado solo para tu usuario).
REM El resultado queda en arduino\apps\dist\PanelArduino.exe

setlocal

REM %~dp0 = carpeta de este .bat (arduino\apps\windows\); subimos a apps\
cd /d "%~dp0.."

if not exist "panel_arduino.py" (
    echo ERROR: no encuentro panel_arduino.py en "%CD%".
    echo Este .bat debe estar en arduino\apps\windows\ dentro del repo.
    pause
    exit /b 1
)

REM Detecta el lanzador de Python disponible (python o py)
set "PY=python"
%PY% --version >nul 2>&1
if errorlevel 1 (
    set "PY=py"
    %PY% --version >nul 2>&1
    if errorlevel 1 (
        echo ERROR: no encuentro Python. Instalalo desde la Microsoft Store
        echo o python.org - ninguno pide administrador.
        pause
        exit /b 1
    )
)

echo Usando %PY% para construir. Instalando dependencias (sin admin)...
%PY% -m pip install --user --quiet pyserial pyinstaller
if errorlevel 1 goto :error

echo Construyendo PanelArduino.exe (tarda 1-2 minutos)...
%PY% -m PyInstaller --onefile --windowed --name PanelArduino --clean --noconfirm "%CD%\panel_arduino.py"
if errorlevel 1 goto :error

echo.
echo ============================================
echo   Listo: %CD%\dist\PanelArduino.exe
echo   Copialo donde quieras: es portable, no
echo   necesita Python ni instalacion.
echo ============================================
pause
exit /b 0

:error
echo.
echo Fallo la construccion. Revisa los mensajes de arriba.
pause
exit /b 1
