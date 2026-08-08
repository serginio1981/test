@echo off
REM Construye PanelArduino.exe portable (sin admin) a partir de panel_arduino.py
REM Requisitos: Python en Windows (Store o instalado solo para tu usuario).
REM Uso: doble clic, o desde PowerShell:  .\construir_exe.bat
REM El resultado queda en dist\PanelArduino.exe — un unico archivo portable.

cd /d "%~dp0"

echo Instalando dependencias (solo para tu usuario, sin admin)...
python -m pip install --user --quiet pyserial pyinstaller
if errorlevel 1 goto :error

echo Construyendo PanelArduino.exe (tarda 1-2 minutos)...
python -m PyInstaller --onefile --windowed --name PanelArduino --clean --noconfirm panel_arduino.py
if errorlevel 1 goto :error

echo.
echo ============================================
echo   Listo: dist\PanelArduino.exe
echo   Copialo donde quieras: es portable, no
echo   necesita Python ni instalacion.
echo ============================================
pause
exit /b 0

:error
echo.
echo Fallo la construccion. Comprueba que "python" funciona en esta terminal.
pause
exit /b 1
