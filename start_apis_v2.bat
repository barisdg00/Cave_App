@echo off
REM ============================================================
REM CaveApp API Sunuculari Baslatma Script (v2 - Gelistirilmis)
REM ============================================================

cd /d "%~dp0"

echo.
echo ==========================================
echo  CaveApp API Sunuculari Baslatiliyor...
echo ==========================================
echo.

REM Veritabanini kontrol et
echo [STEP 1/3] Veritabanı Bağlantısı Kontrol Ediliyor...
python -c "import pyodbc; conn = pyodbc.connect('Driver={SQL Server};Server=(local);Database=ArduinoDB;Trusted_Connection=yes;'); print('OK: Veritabanına başarıyla bağlandı'); conn.close()" 2>nul

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [HATA] Veritabanı bağlantısı başarısız!
    echo.
    echo Kontrol Edin:
    echo 1. SQL Server çalışıyor mu?
    echo 2. ArduinoDB veritabanı var mı?
    echo 3. admin kullanıcısı ve 123456 şifresi var mı?
    echo.
    pause
    exit /b 1
)

echo [OK] Veritabanı bağlantısı başarılı!
echo.

echo [STEP 2/3] Python Paketleri Kontrol Ediliyor...
python -c "import flask, flask_cors, pyodbc, waitress; print('OK: Tüm paketler yüklü')" 2>nul

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [HATA] Gerekli Python paketleri yüklü değil!
    echo.
    echo Kurmak için:
    echo   pip install flask flask-cors pyodbc waitress colorama
    echo.
    pause
    exit /b 1
)

echo [OK] Tüm paketler yüklü!
echo.

echo [STEP 3/3] API Sunucuları Başlatılıyor...
echo.

start "CaveApp - Sensor API (5000)" cmd /k "title CaveApp - Sensor API (5000) & python sensor_api.py & pause"

timeout /t 2 /nobreak > nul

start "CaveApp - Karbon API (5001)" cmd /k "title CaveApp - Karbon API (5001) & python carbon_api.py & pause"

echo.
echo ==========================================
echo  ✅ API Sunucuları Başlatıldı!
echo ==========================================
echo.
echo Endpoints:
echo   Sensor API   -> http://127.0.0.1:5000
echo   Karbon API   -> http://127.0.0.1:5001
echo.
echo Kontrol Et:
echo   python test_api.py
echo.
echo Kapatmak için her iki pencereyi de kapatin.
echo.
pause
