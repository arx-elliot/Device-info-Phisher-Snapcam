#!/usr/bin/env bash
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.local/share/snapcam"
BIN="$HOME/.local/bin"

echo "[*] snapcam installer"

for c in python3 curl; do
  command -v "$c" >/dev/null || {
    echo "[*] installing $c"
    sudo apt-get update -qq && sudo apt-get install -y "$c"
  }
done

mkdir -p "$DEST" "$BIN"
install -m 755 "$SRC/snapcam.sh" "$DEST/snapcam.sh"
install -m 644 "$SRC/server.py"   "$DEST/server.py"
install -m 644 "$SRC/index.html"  "$DEST/index.html"
ln -sf "$DEST/snapcam.sh" "$BIN/snapcam"

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "[*] installing cloudflared"
  case "$(uname -m)" in
    x86_64|amd64) A=amd64 ;; aarch64|arm64) A=arm64 ;;
    armv7l|armv8l|arm) A=arm ;; *) A=amd64 ;;
  esac
  curl -fsSL --max-time 90 \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$A" \
    -o "$BIN/cloudflared"
  chmod +x "$BIN/cloudflared"
fi

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc" ;;
esac

echo "[+] installed. run: snapcam"
