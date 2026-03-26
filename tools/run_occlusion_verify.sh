#!/usr/bin/env bash
set -euo pipefail
export DISPLAY="${DISPLAY:-:1}"
OUT_DIR="${1:-/tmp/occlusion_verify}"
mkdir -p "$OUT_DIR"
ERR_LOG="$OUT_DIR/godot_err.log"
rm -f "$OUT_DIR"/*.png

pkill -f "godot --path /workspace" 2>/dev/null || true
sleep 0.4

godot --path /workspace 2>"$ERR_LOG" &
G_PID=$!

W=""
for _ in $(seq 1 80); do
	W=$(xdotool search --class Godot 2>/dev/null | head -1 || true)
	[[ -n "$W" ]] && break
	sleep 0.25
done

if [[ -z "$W" ]]; then
	echo "FAIL: no Godot window"
	kill "$G_PID" 2>/dev/null || true
	exit 1
fi

xdotool windowactivate --sync "$W" 2>/dev/null || true
sleep 1.2

xdotool key --window "$W" F9
sleep 0.6
ffmpeg -y -f x11grab -video_size 1920x1200 -i "${DISPLAY}.0+0,0" -frames:v 1 "$OUT_DIR/00_teleport.png" -loglevel error

xdotool key --window "$W" Tab
sleep 0.45
# Outline only
xdotool mousemove --window "$W" 40 168 click 1
sleep 0.12
xdotool mousemove --window "$W" 40 198 click 1
sleep 0.12
xdotool mousemove --window "$W" 40 118 click 1
sleep 0.45
ffmpeg -y -f x11grab -video_size 1920x1200 -i "${DISPLAY}.0+0,0" -frames:v 1 "$OUT_DIR/10_outline.png" -loglevel error

# X-ray on
xdotool mousemove --window "$W" 40 118 click 1
sleep 0.12
xdotool mousemove --window "$W" 40 168 click 1
sleep 0.45
ffmpeg -y -f x11grab -video_size 1920x1200 -i "${DISPLAY}.0+0,0" -frames:v 1 "$OUT_DIR/20_xray.png" -loglevel error

# Punch on, x-ray off
xdotool mousemove --window "$W" 40 168 click 1
sleep 0.12
xdotool mousemove --window "$W" 40 198 click 1
sleep 0.45
ffmpeg -y -f x11grab -video_size 1920x1200 -i "${DISPLAY}.0+0,0" -frames:v 1 "$OUT_DIR/30_punch.png" -loglevel error

kill "$G_PID" 2>/dev/null || true
	sleep 0.5
kill -9 "$G_PID" 2>/dev/null || true

if grep -qi "shader error" "$ERR_LOG"; then
	echo "FAIL: shader errors in log"
	grep -i shader "$ERR_LOG" | head -20
	exit 1
fi

echo "OK: screenshots in $OUT_DIR"
ls -la "$OUT_DIR"
