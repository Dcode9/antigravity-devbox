#!/usr/bin/env bash
# start-remote.sh - Starts Antigravity Remote Control reliably in Codespaces
# Primary path: official headless daemon (agy remote-control start --name codespace-cloudbox)
# Fallback: tmux with a real TTY running agy --remote-control
# Always exits 0 so Codespace startup is never blocked.
# Idempotent, safe for postStart and postAttach hooks.
set -u

LOG_FILE="/tmp/agy-remote.log"
STATUS_FILE="/tmp/agy-status.txt"
NAME="codespace-cloudbox"
SESSION="agy"

# Redirect stdout and stderr to LOG_FILE while preserving exit status
exec >> "$LOG_FILE" 2>&1

echo ""
echo "=== [$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Starting Antigravity Remote Control setup ==="

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

# 3. Ensure tmux is installed (fallback dependency)
if ! command -v tmux &>/dev/null; then
  echo "[*] Installing tmux..."
  if command -v sudo &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq tmux || true
  else
    apt-get update -qq && apt-get install -y -qq tmux || true
  fi
fi

# 4. PRIMARY: Attempt official headless remote-control start
echo "[*] Stopping any existing daemon (cleanup)..."
agy remote-control stop || true

echo "[*] Starting official headless remote-control with instance name: $NAME..."
DAEMON_OUTPUT=$(agy remote-control start --name "$NAME" 2>&1) || true
echo "$DAEMON_OUTPUT"

# Verify daemon status
DAEMON_STATUS=$(agy remote-control status 2>&1) || true
echo "[*] Daemon status output:"
echo "$DAEMON_STATUS"

# Check if official daemon succeeded or failed due to container systemd limitations
if echo "$DAEMON_STATUS" | grep -qiE 'systemd.*not running|timed out waiting for the daemon'; then
  echo "[!] Systemd daemon cannot run in this container environment. Using tmux fallback with pseudo-TTY..."

  if command -v tmux &>/dev/null; then
    if tmux has-session -t "$SESSION" 2>/dev/null; then
      echo "[*] tmux session '$SESSION' already active."
    else
      echo "[*] Launching agy --remote-control inside tmux session '$SESSION'..."
      tmux new-session -d -s "$SESSION" -c "${CODESPACE_VSCODE_FOLDER:-$HOME}" -- \
        env PATH="$PATH" agy --remote-control
      sleep 3
    fi

    # Check session health and capture remote link
    if tmux has-session -t "$SESSION" 2>/dev/null; then
      PANE_OUT=$(tmux capture-pane -pt "$SESSION" 2>/dev/null || true)
      REMOTE_URL=$(echo "$PANE_OUT" | grep -o 'https://antigravity\.google\.com/r/[^ ]*' | head -n 1)

      echo "OK - running in tmux session ($NAME)" > "$STATUS_FILE"
      if [ -n "$REMOTE_URL" ]; then
        echo "Remote URL: $REMOTE_URL" >> "$STATUS_FILE"
        echo "[*] Remote session established: $REMOTE_URL"
      fi
    else
      echo "[!] tmux session failed to start"
      echo "FAILED - tmux session died" > "$STATUS_FILE"
    fi
  else
    echo "[ERROR] tmux not found and systemd unavailable."
    echo "FAILED - no tmux available" > "$STATUS_FILE"
  fi
elif echo "$DAEMON_STATUS" | grep -qiE 'running|active|started|online|enabled'; then
  echo "OK - running via headless daemon ($NAME)" > "$STATUS_FILE"
  echo "$DAEMON_STATUS" >> "$STATUS_FILE"
else
  echo "daemon_uncertain" > "$STATUS_FILE"
fi

echo "[*] Status file contents:"
cat "$STATUS_FILE" 2>/dev/null || true
echo "=== [$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Finished setup ==="
exit 0
