#!/usr/bin/env bash

# Remotey macOS Server Launcher
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=========================================================="
echo "  Remotey macOS Server Launcher"
echo "=========================================================="
echo ""

# Verify Python 3
if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERROR] python3 is required to run Remotey on macOS."
    exit 1
fi

echo "Starting Remotey macOS Server on Port ${REMOTEY_PORT:-7777}..."
exec python3 "$DIR/remotey_server_mac.py"
