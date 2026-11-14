#!/usr/bin/env bash
# sc_cf.sh - capture loop + fresh tunnel + menu (patched)

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAPDIR="$DIR/captures"
LOG="$DIR/sc_cf.log"
PORT="${PORT:-8080}"
INTERVAL="${INTERVAL:-10}"
CAM="${CAM:-/dev/video0}"

mkdir -p "$CAPDIR"
: > "$LOG"

TUN_PID=""
CAP_PID=""
URL=""

say()  { printf '%s\n' "$*"; }
die()  { say "error: $*"; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
strip() { sed -e 's/\x1b\[[0-9;]*[mGKHF]//g' -e 's/\r/\n/g'; }

cleanup() {
  [ -n "${TUN_PID:-}" ] && kill "$TUN_PID" 2>/dev/null
  [ -n "${CAP_PID:-}" ] && kill "$CAP_PID" 2>/dev/null
  pkill -f "http.server $PORT" 2>/dev/null
}
trap cleanup EXIT INT TERM

pick_backend() {
  if [ -n "$CAM" ] && have ffmpeg && [ -e "$CAM" ]; then echo cam; return; fi
  for t in grim scrot import gnome-screenshot spectacle; do
    have "$t" && { echo "$t"; return; }
  done
  echo none
}
BACKEND="$(pick_backend)"

capture_one() {
  local f
  f="$CAPDIR/$(date +%Y%m%d-%H%M%S).jpg"
  case "$BACKEND" in
    cam)              ffmpeg -loglevel error -f v4l2 -i "$CAM" -frames:v 1 -q:v 3 -y "$f" ;;
    grim)             grim "$f" ;;
    scrot)            scrot -q 85 "$f" ;;
    import)           import -window root "$f" ;;
    gnome-screenshot) gnome-screenshot -f "$f" ;;
    spectacle)        spectacle -b -n -o "$f" ;;
    *)                return 1 ;;
  esac
}

start_capture_loop() {
  if [ "$BACKEND" = none ]; then
    say "no capture tool found - serving $CAPDIR as-is"
    return
  fi
  ( while :; do capture_one || true; sleep "$INTERVAL"; done ) &
  CAP_PID=$!
}

extract_url() {
  [ -s "$LOG" ] || return 0
  strip < "$LOG" | grep -aoE 'https://[a-z0-9-]+\.trycloudflare\.com' | tail -1
}

start_tunnel() {
  if [ -n "$TUN_PID" ]; then
    kill "$TUN_PID" 2>/dev/null
    wait "$TUN_PID" 2>/dev/null
    TUN_PID=""
  fi
  URL=""
  : > "$LOG"

  have cloudflared || die "cloudflared not installed"
  pkill -f "http.server $PORT" 2>/dev/null
  ( cd "$CAPDIR" && exec python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1 ) &
  sleep 1

  NO_COLOR=1 TERM=dumb cloudflared tunnel --no-autoupdate \
      --url "http://127.0.0.1:$PORT" >"$LOG" 2>&1 &
  TUN_PID=$!

  local i
  for i in $(seq 1 40); do
    URL="$(extract_url)"
    [ -n "$URL" ] && break
    kill -0 "$TUN_PID" 2>/dev/null || break
    sleep 0.5
  done

  if [ -z "$URL" ]; then
    say "tunnel failed - last log lines:"
    strip < "$LOG" | tail -20
    return 1
  fi

  say ""
  say "LINK: $URL"
  if have wl-copy; then printf '%s' "$URL" | wl-copy
  elif have xclip; then printf '%s' "$URL" | xclip -sel clip
  fi
}

list_caps() { ls -1t "$CAPDIR" 2>/dev/null; }

menu() {
  say ""
  say "Created by Arx Elliot (patched)"
  say "  [1] New link (fresh tunnel)"
  say "  [2] Show captures"
  say "  [3] Show last capture"
  say "  [4] Quit"
  printf 'Choose: '
}

if [ "${1:-}" = "--extract" ]; then LOG="${2:-$LOG}"; extract_url; exit 0; fi

start_capture_loop

while :; do
  menu
  read -r raw || break
  choice="$(printf '%s' "$raw" | tr -cd '0-9' | cut -c1)"
  case "$choice" in
    1) start_tunnel ;;
    2) say "captures in $CAPDIR:"
       list_caps | head -40
       have xdg-open && xdg-open "$CAPDIR" >/dev/null 2>&1 ;;
    3) last="$(list_caps | head -1)"
       if [ -z "$last" ]; then say "no captures yet"
       elif have xdg-open; then xdg-open "$CAPDIR/$last" >/dev/null 2>&1 || say "$CAPDIR/$last"
       else say "$CAPDIR/$last"; fi ;;
    4) break ;;
    *) say "pick 1-4" ;;
  esac
done
