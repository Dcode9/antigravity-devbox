#!/usr/bin/env bash
set -e

# Ensure agy binary is in PATH if not already loaded
export PATH="$HOME/.local/bin:$HOME/.antigravity/bin:$PATH"

if ! command -v agy &> /dev/null; then
  echo "[!] Antigravity CLI not found. Running installer..."
  curl -fsSL https://antigravity.google/cli/install.sh | bash
  source "$HOME/.bashrc" || true
fi

echo "[*] Checking Antigravity version..."
agy --version

echo "[*] Starting Antigravity Remote Control daemon..."
agy remote-control start --name "codespace-cloudbox"
