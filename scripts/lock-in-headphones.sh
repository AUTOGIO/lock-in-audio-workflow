#!/bin/zsh
set -euo pipefail

PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

HEADPHONES_NAME="beats4"
HEADPHONES_MAC="58:36:53:C3:42:E9"
MUSIC_SOURCE="${1:-Focus Noise}"
BOOM_3D_APP="/Applications/Boom 3D.app"
BOOM_3D_BUNDLE_ID="com.globaldelight.Boom3DMAS"

log() {
  printf '[lock-in] %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '[lock-in] Missing dependency: %s\n' "$1" >&2
    printf '[lock-in] Install with: brew install blueutil switchaudio-osx\n' >&2
    exit 1
  fi
}

require_cmd blueutil
require_cmd SwitchAudioSource
require_cmd osascript
require_cmd python3

bluetooth_state() {
  python3 - <<'PY'
import json
import subprocess

data = json.loads(subprocess.check_output(
    ["system_profiler", "SPBluetoothDataType", "-json"],
    text=True,
))["SPBluetoothDataType"][0]
print(data.get("controller_properties", {}).get("controller_state", "unknown"))
PY
}

headphones_connected() {
  python3 - "$HEADPHONES_NAME" <<'PY'
import json
import subprocess
import sys

name = sys.argv[1]
data = json.loads(subprocess.check_output(
    ["system_profiler", "SPBluetoothDataType", "-json"],
    text=True,
))["SPBluetoothDataType"][0]
for item in data.get("device_connected", []):
    if name in item:
        print("1")
        break
else:
    print("0")
PY
}

run_with_timeout() {
  local seconds="$1"
  shift

  "$@" &
  local pid="$!"
  local elapsed=0

  while kill -0 "$pid" 2>/dev/null; do
    if (( elapsed >= seconds )); then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  wait "$pid"
}

set_audio_source() {
  local source_name="$1"
  local source_type="$2"

  for attempt in {1..8}; do
    if SwitchAudioSource -a -t "$source_type" | grep -Fxq "$source_name"; then
      if SwitchAudioSource -s "$source_name" -t "$source_type" >/dev/null; then
        return 0
      fi
    fi
    sleep 1
  done

  return 1
}

prepare_boom_3d() {
  if [[ ! -d "$BOOM_3D_APP" ]]; then
    printf '[lock-in] Missing Boom 3D app at %s.\n' "$BOOM_3D_APP" >&2
    exit 4
  fi

  log "Opening Boom 3D"
  if ! run_with_timeout 8 open -a "$BOOM_3D_APP"; then
    printf '[lock-in] Could not open Boom 3D.\n' >&2
    exit 5
  fi

  for attempt in {1..10}; do
    if pgrep -f "$BOOM_3D_BUNDLE_ID" >/dev/null 2>&1 || pgrep -f '/Applications/Boom 3D.app/Contents/MacOS/Boom 3D' >/dev/null 2>&1; then
      log "Boom 3D ready with its saved configuration"
      return 0
    fi
    sleep 1
  done

  printf '[lock-in] Boom 3D did not finish launching.\n' >&2
  exit 6
}

case "$MUSIC_SOURCE" in
  "Focus Noise"|"Coldplay Essentials"|"Favourite Songs"|"Headphones Only"|"")
    ;;
  http://*|https://*|music://*)
    ;;
  *)
    printf '[lock-in] Unsupported music source: %s\n' "$MUSIC_SOURCE" >&2
    printf '[lock-in] Allowed: Focus Noise, Coldplay Essentials, Favourite Songs, Headphones Only, or a music URL.\n' >&2
    exit 64
    ;;
esac

prepare_boom_3d

if [[ "$(bluetooth_state)" != "attrib_on" ]]; then
  printf '[lock-in] Bluetooth is off or unavailable. Turn it on in System Settings, then run this again.\n' >&2
  exit 1
else
  log "Bluetooth already on"
fi

if [[ "$(headphones_connected)" != "1" ]]; then
  log "Connecting ${HEADPHONES_NAME}"
  run_with_timeout 15 blueutil --connect "$HEADPHONES_MAC" || true
else
  log "${HEADPHONES_NAME} already connected"
fi

for attempt in {1..10}; do
  if [[ "$(headphones_connected)" == "1" ]]; then
    break
  fi
  sleep 1
done

if [[ "$(headphones_connected)" != "1" ]]; then
  printf '[lock-in] Failed to connect %s. Make sure it is powered on and nearby.\n' "$HEADPHONES_NAME" >&2
  exit 2
fi

log "Routing audio output to ${HEADPHONES_NAME}"
if ! set_audio_source "$HEADPHONES_NAME" output; then
  printf '[lock-in] Could not route audio output to %s.\n' "$HEADPHONES_NAME" >&2
  exit 3
fi

if SwitchAudioSource -a -t input | grep -Fxq "$HEADPHONES_NAME"; then
  log "Routing audio input to ${HEADPHONES_NAME}"
  set_audio_source "$HEADPHONES_NAME" input || log "Input routing skipped"
fi

if [[ -z "$MUSIC_SOURCE" || "$MUSIC_SOURCE" == "Headphones Only" ]]; then
  log "Skipping music startup"
  log "Ready"
  exit 0
fi

if [[ "$MUSIC_SOURCE" == http://* || "$MUSIC_SOURCE" == https://* || "$MUSIC_SOURCE" == music://* ]]; then
  log "Opening music URL"
  if ! run_with_timeout 8 open "$MUSIC_SOURCE"; then
    log "Music URL did not open within 8 seconds; headphones and audio routing are ready"
  fi
  log "Ready"
  exit 0
fi

log "Starting Music playlist: ${MUSIC_SOURCE}"
if ! run_with_timeout 8 osascript \
  -e 'tell application "Music" to activate' \
  -e "tell application \"Music\" to play playlist \"${MUSIC_SOURCE}\""; then
  log "Music did not start within 8 seconds; headphones and audio routing are ready"
fi

log "Ready"

