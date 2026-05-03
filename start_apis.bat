@echo off
echo ==========================================
echo  CaveApp API Sunuculari Baslatiliyor...
echo ==========================================

cd /d "%~dp0"

echo [1/2] Sensor API baslatiliyor (Port 5000)...
start "CaveApp - Sensor API (5000)" cmd /k "python sensor_api.py & pause"

timeout /t 2 /nobreak > nul

echo [2/2] Karbon API baslatiliyor (Port 5001)...
start "CaveApp - Karbon API (5001)" cmd /k "python carbon_api.py & pause"

echo.
echo Her iki API de calisiyor:
echo   Sensor API   -> http://127.0.0.1:5000
echo   Karbon API   -> http://127.0.0.1:5001
echo.
echo Kapatmak icin her iki pencereyi de kapatin.
