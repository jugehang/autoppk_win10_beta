#!/bin/bash
# AutoPMX Web — Start Script
# Launches both backend (FastAPI) and frontend (Vite dev server)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "╔══════════════════════════════════════╗"
echo "║   AutoPMX Web — DuDu PMx Workbench  ║"
echo "╚══════════════════════════════════════╝"

# Backend
echo ""
echo "📦 Starting backend..."
cd "$SCRIPT_DIR/backend"

if [ ! -d ".venv" ]; then
    echo "   Creating Python venv..."
    python3 -m venv .venv
    .venv/bin/pip install -q -r requirements.txt
fi

.venv/bin/python main.py &
BACKEND_PID=$!
echo "   Backend PID: $BACKEND_PID (port 8899)"

# Wait for backend
sleep 1

# Frontend
echo ""
echo "🎨 Starting frontend..."
cd "$SCRIPT_DIR/frontend"

if [ ! -d "node_modules" ]; then
    echo "   Installing npm dependencies..."
    npm install --silent
fi

npm run dev &
FRONTEND_PID=$!
echo "   Frontend PID: $FRONTEND_PID (port 5173)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  AutoPMX Web is running!"
echo "  Open: http://localhost:5173"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Press Ctrl+C to stop all services."

# Trap cleanup
cleanup() {
    echo ""
    echo "🛑 Stopping services..."
    kill $BACKEND_PID 2>/dev/null || true
    kill $FRONTEND_PID 2>/dev/null || true
    echo "   Done."
}
trap cleanup EXIT INT TERM

# Wait
wait
