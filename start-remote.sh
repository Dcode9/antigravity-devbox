#!/usr/bin/env bash
set -e

export PATH="$HOME/.local/bin:$HOME/.antigravity/bin:$PATH"

if ! command -v agy &> /dev/null; then
  echo "[!] Antigravity CLI not found. Running installer..."
  curl -fsSL https://antigravity.google/cli/install.sh | bash
  source "$HOME/.bashrc" || true
fi

echo "[*] Checking Antigravity version..."
agy --version || true

echo "[*] Starting Antigravity Remote Control daemon in background..."
nohup agy remote-control start --name "codespace-cloudbox" > /tmp/agy-remote.log 2>&1 &
echo "[*] Daemon started (PID $!). Log: /tmp/agy-remote.log"
