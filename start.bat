@echo off
REM AutoPMX Web — Windows Start Script
echo AutoPMX Web — DuDu PMx Workbench
echo.

cd /d "%~dp0backend"

if not exist ".venv" (
    echo Creating Python venv...
    python -m venv .venv
    .venv\Scripts\pip install -q -r requirements.txt
)

echo Starting backend...
start "AutoPMX Backend" .venv\Scripts\python main.py

cd /d "%~dp0frontend"

if not exist "node_modules" (
    echo Installing npm dependencies...
    call npm install --silent
)

echo Starting frontend...
start "AutoPMX Frontend" npm run dev

echo.
echo AutoPMX Web is starting...
echo Backend:  http://localhost:8899
echo Frontend: http://localhost:5173
echo.
pause
