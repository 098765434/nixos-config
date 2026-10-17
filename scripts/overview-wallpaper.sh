#!/usr/bin/env bash
# Swap the wallpaper layer depending on whether niri's overview is open.
# - Overview closed: solid black (so empty workspaces/gaps stay black).
# - Overview open:  the configured image (visible through transparent
#   workspace background + transparent overview backdrop).
#
# Requires: niri, swaybg, jq.

set -euo pipefail

IMAGE="${OVERVIEW_WALLPAPER:-$HOME/Pictures/overview.jpg}"
BLACK_COLOR="#000000"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/overview-wallpaper.pid"

kill_swaybg() {
    if [[ -f "$STATE_FILE" ]]; then
        local pid
        pid=$(cat "$STATE_FILE" 2>/dev/null || true)
        [[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null || true
        rm -f "$STATE_FILE"
    fi
    # Belt-and-suspenders: kill any stray swaybg we spawned.
    pkill -x swaybg 2>/dev/null || true
}

start_black() {
    kill_swaybg
    swaybg -c "$BLACK_COLOR" &
    echo $! > "$STATE_FILE"
}

start_image() {
    kill_swaybg
    if [[ -f "$IMAGE" ]]; then
        swaybg -i "$IMAGE" -m fill &
    else
        # Fall back to a non-black color so the overview backdrop is at least
        # visibly different if the image is missing.
        swaybg -c "#202030" &
    fi
    echo $! > "$STATE_FILE"
}

# Start in the "closed" state.
start_black

# Stream events; react to overview open/close.
niri msg --json event-stream | while IFS= read -r line; do
    is_open=$(printf '%s\n' "$line" \
        | jq -r 'if .OverviewOpenedOrClosed then .OverviewOpenedOrClosed.is_open else empty end' \
        2>/dev/null || true)
    case "$is_open" in
        true)  start_image ;;
        false) start_black ;;
    esac
done
