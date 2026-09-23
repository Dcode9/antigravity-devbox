#!/usr/bin/env bash
# start-remote.sh - Starts Antigravity and executes /remote-control with Live Preview
# Always exits 0 so Codespace startup is never blocked.
# Idempotent, safe for postStart and postAttach hooks.
set -u

LOG_FILE="/tmp/agy-remote.log"
STATUS_FILE="/tmp/agy-status.txt"
NAME="codespace-cloudbox"
SESSION="agy"
PREVIEW_PORT=7681

# Redirect stdout and stderr to LOG_FILE
exec >> "$LOG_FILE" 2>&1

echo ""
echo "=== [$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Starting Antigravity setup ==="

# 1. Environment & PATH setup
export PATH="$HOME/.gemini/antigravity-cli/bin:$HOME/.local/bin:$HOME/.antigravity/bin:$PATH"

# 2. Check if agy is installed; install if missing
if ! command -v agy &>/dev/null; then
  echo "[!] agy binary not found in PATH. Attempting installation..."
  curl -fsSL https://antigravity.google/cli/install.sh | bash || true
  # shellcheck source=/dev/null
  source "$HOME/.bashrc" 2>/dev/null || true
  export PATH="$HOME/.gemini/antigravity-cli/bin:$HOME/.local/bin:$HOME/.antigravity/bin:$PATH"
fi

if ! command -v agy &>/dev/null; then
  echo "[ERROR] agy CLI could not be found or installed."
  echo "FAILED - agy binary missing" > "$STATUS_FILE"
  exit 0
fi

echo "[*] agy binary found: $(command -v agy) ($(agy --version 2>/dev/null || echo 'unknown'))"

# 3. Ensure tmux is installed
if ! command -v tmux &>/dev/null; then
  echo "[*] Installing tmux..."
  if command -v sudo &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq tmux || true
  else
    apt-get update -qq && apt-get install -y -qq tmux || true
  fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 4. Launch agy inside tmux and trigger /remote-control after 10 seconds
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "[*] tmux session '$SESSION' already active."
else
  echo "[*] Launching agy in tmux session '$SESSION'..."
  agy remote-control stop 2>/dev/null || true
  
  tmux new-session -d -s "$SESSION" -c "${CODESPACE_VSCODE_FOLDER:-/workspaces/antigravity-devbox}" -- \
    env PATH="$PATH" agy

  echo "Starting agy (waiting 10s before /remote-control)..." > "$STATUS_FILE"

  # Background detached worker to send /remote-control after exactly 10 seconds
  if [ -f "$SCRIPT_DIR/remote-control-worker.sh" ]; then
    nohup "$SCRIPT_DIR/remote-control-worker.sh" </dev/null >/dev/null 2>&1 &
  fi
fi

# 5. Start Live Preview HTTP Server on port 7681 (if not already running)
if ! pgrep -f "preview-server.py" >/dev/null 2>&1; then
  echo "[*] Starting live preview server on port $PREVIEW_PORT..."
  if [ -f "$SCRIPT_DIR/preview-server.py" ]; then
    nohup python3 "$SCRIPT_DIR/preview-server.py" </dev/null >/dev/null 2>&1 &
  fi
fi

echo "[*] Current Status file contents:"
cat "$STATUS_FILE" 2>/dev/null || true
echo "=== [$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Setup triggered successfully ==="
exit 0
