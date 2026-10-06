#!/usr/bin/env bash
# Start AGY Remote Control daemon on Codespace boot.
# Auth is one-time; this command must run on every Start (VM was off).
# Always exits 0 so Codespace lifecycle is never blocked.

set +e

LOG="/tmp/agy-remote.log"
STATUS="/tmp/agy-status.txt"
NAME="codespace-cloudbox"

export PATH="$HOME/.gemini/antigravity-cli/bin:$HOME/.local/bin:$HOME/.antigravity/bin:$PATH"

log() {
  echo "$*" | tee -a "$LOG"
}

{
  echo ""
  echo "======== $(date -u +%Y-%m-%dT%H:%M:%SZ) start-remote.sh ========"
} >>"$LOG"

log "[*] user=$(whoami) home=$HOME"

# Install agy if missing
if ! command -v agy >/dev/null 2>&1; then
  log "[!] agy missing — installing"
  curl -fsSL https://antigravity.google/cli/install.sh | bash >>"$LOG" 2>&1
  # shellcheck source=/dev/null
  source "$HOME/.bashrc" 2>/dev/null || true
  export PATH="$HOME/.gemini/antigravity-cli/bin:$HOME/.local/bin:$HOME/.antigravity/bin:$PATH"
fi

if ! command -v agy >/dev/null 2>&1; then
  log "[!] agy still not found"
  echo "agy_missing" >"$STATUS"
  exit 0
fi

log "[*] $(command -v agy)"
agy --version >>"$LOG" 2>&1 || true

# Official headless path (works without interactive TUI)
log "[*] agy remote-control stop (cleanup)"
agy remote-control stop >>"$LOG" 2>&1 || true

log "[*] agy remote-control start --name $NAME"
agy remote-control start --name "$NAME" >>"$LOG" 2>&1
RC=$?
log "[*] start exit code=$RC"

sleep 2

STATUS_OUT=$(agy remote-control status 2>&1)
echo "$STATUS_OUT" >>"$LOG"
log "[*] status:"
log "$STATUS_OUT"

if echo "$STATUS_OUT" | grep -qiE 'running|active|started|online|enabled|pid'; then
  echo "daemon_ok" >"$STATUS"
  log "[+] remote-control daemon looks up — Hub: https://antigravity.google.com ($NAME)"
else
  echo "daemon_uncertain" >"$STATUS"
  log "[!] status unclear. If Hub is empty: open Codespace once, run 'agy' to login, then re-run this script."
fi

# Optional live preview server (if present)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/preview-server.py" ] && ! pgrep -f "preview-server.py" >/dev/null 2>&1; then
  log "[*] starting preview-server.py"
  nohup python3 "$SCRIPT_DIR/preview-server.py" </dev/null >>"$LOG" 2>&1 &
fi

log "[*] done status=$(cat "$STATUS" 2>/dev/null)"
exit 0
