#!/usr/bin/env bash
# Start AGY Remote Control on Codespace boot (postStart / postAttach).
# Primary path: official headless daemon (agy remote-control start).
# Fallback: tmux + agy --remote-control with a real TTY (no pipe).
# Always exits 0 so Codespace startup is never blocked.

set +e

LOG="/tmp/agy-remote.log"
STATUS="/tmp/agy-status.txt"
NAME="codespace-cloudbox"
SESSION="agy"

export PATH="$HOME/.local/bin:$HOME/.antigravity/bin:$PATH"

log() { echo "$*" | tee -a "$LOG"; }

{
  echo ""
  echo "======== $(date -u +%Y-%m-%dT%H:%M:%SZ) ========"
} >>"$LOG"

log "[*] PATH=$PATH"
log "[*] user=$(whoami) home=$HOME pwd=$(pwd)"

# --- ensure agy ---
if ! command -v agy >/dev/null 2>&1; then
  log "[!] agy missing — installing"
  curl -fsSL https://antigravity.google/cli/install.sh | bash >>"$LOG" 2>&1
  # shellcheck source=/dev/null
  source "$HOME/.bashrc" 2>/dev/null || true
  export PATH="$HOME/.local/bin:$HOME/.antigravity/bin:$PATH"
fi

if ! command -v agy >/dev/null 2>&1; then
  log "[!] agy still not on PATH after install"
  echo "agy_missing" >"$STATUS"
  exit 0
fi

log "[*] $(command -v agy)"
agy --version >>"$LOG" 2>&1 || true

# --- PRIMARY: headless daemon (official always-on path) ---
log "[*] agy remote-control stop (cleanup)"
agy remote-control stop >>"$LOG" 2>&1 || true

log "[*] agy remote-control start --name $NAME"
agy remote-control start --name "$NAME" >>"$LOG" 2>&1
RC_START=$?
log "[*] remote-control start exit=$RC_START"

sleep 2
log "[*] agy remote-control status:"
agy remote-control status >>"$LOG" 2>&1
STATUS_OUT=$(agy remote-control status 2>&1)
echo "$STATUS_OUT" >>"$LOG"

if echo "$STATUS_OUT" | grep -qiE 'running|active|started|online|enabled'; then
  log "[+] daemon looks up"
  echo "daemon_ok" >"$STATUS"
else
  log "[!] daemon status unclear — starting interactive fallback in tmux"
  echo "daemon_uncertain" >"$STATUS"

  # --- FALLBACK: interactive session with real TTY (no pipe/tee) ---
  if ! command -v tmux >/dev/null 2>&1; then
    log "[*] installing tmux"
    sudo apt-get update -qq >>"$LOG" 2>&1
    sudo apt-get install -y -qq tmux >>"$LOG" 2>&1
  fi

  if command -v tmux >/dev/null 2>&1; then
    tmux kill-session -t "$SESSION" 2>/dev/null || true
    # Real PTY inside tmux — required for AGY TUI
    tmux new-session -d -s "$SESSION" -c "${CODESPACE_VSCODE_FOLDER:-$HOME}" -- \
      env PATH="$PATH" agy --remote-control
    sleep 3
    if tmux has-session -t "$SESSION" 2>/dev/null; then
      log "[+] tmux session '$SESSION' running (agy --remote-control)"
      echo "tmux_ok" >"$STATUS"
    else
      log "[!] tmux session died"
      echo "failed" >"$STATUS"
    fi
  else
    log "[!] no tmux — cannot start interactive fallback"
    echo "failed" >"$STATUS"
  fi
fi

log "[*] status file: $(cat "$STATUS" 2>/dev/null)"
log "[*] Hub: https://antigravity.google.com"
log "[*] Debug: cat $LOG | tmux attach -t $SESSION | agy remote-control status"

exit 0
