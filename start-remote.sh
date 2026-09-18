#!/usr/bin/env bash
# Robust AGY remote-control starter for Codespaces
# Safe to run multiple times (postStart + postAttach)

LOG=/tmp/agy-remote.log
NAME="codespace-cloudbox"

export PATH="$HOME/.local/bin:$HOME/.antigravity/bin:$PATH"

exec >>"$LOG" 2>&1
echo ""
echo "======== $(date -u +%Y-%m-%dT%H:%M:%SZ) start-remote.sh ========"

# Install if missing
if ! command -v agy >/dev/null 2>&1; then
  echo "[!] agy not found — installing..."
  curl -fsSL https://antigravity.google/cli/install.sh | bash || {
    echo "[!] Installer failed"
    exit 0
  }
  # shellcheck source=/dev/null
  source "$HOME/.bashrc" 2>/dev/null || true
  export PATH="$HOME/.local/bin:$HOME/.antigravity/bin:$PATH"
fi

echo "[*] agy binary: $(command -v agy || echo 'still missing')"
agy --version 2>/dev/null || echo "[!] agy --version failed (may need auth)"

# Already running?
if pgrep -f "agy remote-control" >/dev/null 2>&1; then
  echo "[*] agy remote-control already running — skipping start"
  exit 0
fi

echo "[*] Starting: agy remote-control start --name $NAME"
# Run in background; do not let set -e kill the script
nohup agy remote-control start --name "$NAME" >>"$LOG" 2>&1 &
PID=$!
echo "[*] Launched PID $PID"

sleep 2
if pgrep -f "agy remote-control" >/dev/null 2>&1; then
  echo "[*] OK — remote-control appears to be running"
else
  echo "[!] remote-control did not stay up."
  echo "    Most common cause: AGY is not authenticated in this Codespace yet."
  echo "    Open the Codespace once, run: agy"
  echo "    Complete the Google login, then re-run this script or reopen."
  echo "    Full log: $LOG"
fi

exit 0
