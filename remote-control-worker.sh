#!/usr/bin/env bash
# remote-control-worker.sh - Detached worker to send /remote-control after 10s
set -u

LOG_FILE="/tmp/agy-remote.log"
STATUS_FILE="/tmp/agy-status.txt"
NAME="codespace-cloudbox"
SESSION="agy"

sleep 10
echo "[*] Typing /remote-control and pressing enter in tmux session '$SESSION'..." >> "$LOG_FILE"
tmux send-keys -t "$SESSION" "/remote-control" Enter
sleep 3

PANE_OUT=$(tmux capture-pane -pt "$SESSION" 2>/dev/null || true)
REMOTE_URL=$(echo "$PANE_OUT" | grep -o 'https://antigravity\.google\.com/r/[^ ]*' | head -n 1)

echo "OK - running in tmux session ($NAME)" > "$STATUS_FILE"
if [ -n "$REMOTE_URL" ]; then
  echo "Remote URL: $REMOTE_URL" >> "$STATUS_FILE"
  echo "[*] Remote session established: $REMOTE_URL" >> "$LOG_FILE"
fi
