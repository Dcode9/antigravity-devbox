#!/usr/bin/env bash
# Fastest reliable path: tmux + agy with remote-control enabled.
# Matches: open agy → /remote-control, without typing either.
# Safe to run on postStart and postAttach.

LOG=/tmp/agy-remote.log
SESSION=agy
NAME=codespace-cloudbox

export PATH="$HOME/.local/bin:$HOME/.antigravity/bin:$PATH"

{
  echo ""
  echo "======== $(date -u +%Y-%m-%dT%H:%M:%SZ) start-remote.sh ========"

  # Install agy if missing
  if ! command -v agy >/dev/null 2>&1; then
    echo "[!] agy not found — installing..."
    curl -fsSL https://antigravity.google/cli/install.sh | bash || echo "[!] install failed"
    # shellcheck source=/dev/null
    source "$HOME/.bashrc" 2>/dev/null || true
    export PATH="$HOME/.local/bin:$HOME/.antigravity/bin:$PATH"
  fi

  echo "[*] agy: $(command -v agy || echo missing)"
  agy --version 2>/dev/null || true

  # Need tmux so the TUI survives after this script exits
  if ! command -v tmux >/dev/null 2>&1; then
    echo "[*] installing tmux..."
    sudo apt-get update -qq && sudo apt-get install -y -qq tmux || {
      echo "[!] tmux install failed"
      exit 0
    }
  fi

  # Already have a live agy tmux session?
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "[*] tmux session '$SESSION' already exists — ensuring remote-control"
    # Re-send slash command in case session is up but RC not on
    tmux send-keys -t "$SESSION" "/remote-control" Enter 2>/dev/null || true
    # Also keep daemon path warm
    agy remote-control start --name "$NAME" >>"$LOG" 2>&1 &
    echo "[*] done (existing session)"
    exit 0
  fi

  # Prefer: start AGY already in remote-control mode (one step)
  if agy --help 2>&1 | grep -q -- '--remote-control'; then
    echo "[*] Starting: tmux → agy --remote-control"
    tmux new-session -d -s "$SESSION" "agy --remote-control 2>&1 | tee -a $LOG"
  else
    echo "[*] No --remote-control flag; starting agy then sending /remote-control"
    tmux new-session -d -s "$SESSION" "agy 2>&1 | tee -a $LOG"
    # Give TUI time to boot and reuse saved auth
    sleep 4
    tmux send-keys -t "$SESSION" "/remote-control" Enter
  fi

  # Belt-and-suspenders: official headless daemon (Hub registration)
  echo "[*] Also starting: agy remote-control start --name $NAME"
  agy remote-control start --name "$NAME" >>"$LOG" 2>&1 &

  sleep 2
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "[*] OK — tmux session '$SESSION' is running"
    echo "    Attach (debug): tmux attach -t $SESSION"
    echo "    Progress UI:   https://antigravity.google.com"
  else
    echo "[!] tmux session failed to stay up — see $LOG"
  fi
} >>"$LOG" 2>&1

exit 0
