#!/usr/bin/env bash
# Fails if the tunnel URL can't be pulled out of a log full of
# ANSI escapes, CR bytes and NULs (the exact shape of cloudflared output).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/sc.sh"
FIX="$(mktemp)"
EXPECT="https://fake-test-1234.trycloudflare.com"

[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

printf 'INF starting\0\0\r\n\x1b[32mINF\x1b[0m |  %s  |\r\n\0\0tail noise\n' "$EXPECT" > "$FIX"

GOT="$("$SCRIPT" --extract "$FIX" 2>/dev/null)"
rm -f "$FIX"

if [ "$GOT" != "$EXPECT" ]; then
  echo "FAIL: extraction broke"
  echo "  expected: $EXPECT"
  echo "  got:      ${GOT:-<empty>}"
  echo "  hint: grep needs -a, and the log needs its ANSI stripped first"
  exit 1
fi

echo "PASS: URL extracted from binary-contaminated log"
