#!/usr/bin/env bash
#
# Puts the exported graphs where the app looks for them.
#
# The .onnx files are not in git: they are large binaries produced by the
# pinned recipe in vision/pins.lock, and a repository is the wrong place for
# sixty megabytes that change whenever the models are retrained. This script
# takes them from a local export or a release URL, checks them against the
# digests in the contract, and pushes them onto a connected device.
#
#   tool/vision/fetch_models.sh --from build/vision --android
#   tool/vision/fetch_models.sh --url https://models.example/v1 --android
#
# Without a target it only verifies. The app reports 'models missing' and falls
# back to the simulated pipeline when this has not been run, which is a working
# app with clearly-labelled numbers rather than a crash.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACT="$ROOT/vision/contract/model_contract.json"
SOURCE="$ROOT/build/vision"
URL=""
ANDROID=0
IOS=0

usage() {
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) SOURCE="$2"; shift 2 ;;
    --url) URL="$2"; shift 2 ;;
    --android) ANDROID=1; shift ;;
    --ios) IOS=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown argument: $1" >&2; usage 2 ;;
  esac
done

field() {
  # Pulls one string out of the contract without needing a JSON parser on the
  # path. Good enough for two known keys in a file this repository owns.
  python3 -c "
import json, sys
contract = json.load(open('$CONTRACT'))
value = contract['$1'].get('$2')
print(value if value is not None else '')
"
}

DETECTOR="$(field detector file)"
POSE="$(field pose file)"
DETECTOR_SHA="$(field detector sha256)"
POSE_SHA="$(field pose sha256)"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

for name in "$DETECTOR" "$POSE"; do
  if [[ -n "$URL" ]]; then
    echo "Downloading $name"
    curl --fail --location --progress-bar "$URL/$name" --output "$STAGE/$name"
    curl --fail --location --silent "$URL/$name.version" \
      --output "$STAGE/${name%.onnx}.version" || true
  else
    if [[ ! -f "$SOURCE/$name" ]]; then
      echo "$SOURCE/$name is missing. Run tool/vision/export_onnx.py first." >&2
      exit 1
    fi
    cp "$SOURCE/$name" "$STAGE/$name"
    [[ -f "$SOURCE/${name%.onnx}.version" ]] &&
      cp "$SOURCE/${name%.onnx}.version" "$STAGE/"
  fi
done

check() {
  local file="$1" expected="$2"
  local actual
  actual="$(sha256sum "$STAGE/$file" | awk '{print $1}')"

  if [[ -z "$expected" || "$expected" == "null" ]]; then
    echo "  $file: $actual (the contract records no digest yet)"
    return
  fi
  if [[ "$actual" != "$expected" ]]; then
    echo "  $file: digest mismatch" >&2
    echo "    expected $expected" >&2
    echo "    actual   $actual" >&2
    exit 1
  fi
  echo "  $file: digest matches"
}

echo "Checking against the contract"
check "$DETECTOR" "$DETECTOR_SHA"
check "$POSE" "$POSE_SHA"

if [[ $ANDROID -eq 1 ]]; then
  # Matches VisionEngine.modelDirectory: filesDir/vision.
  PACKAGE="ai.arcvanta.arcvanta"
  TARGET="/data/data/$PACKAGE/files/vision"
  echo "Pushing to Android at $TARGET"

  adb shell "run-as $PACKAGE mkdir -p files/vision" 2>/dev/null || {
    echo "run-as failed. The app must be installed and debuggable." >&2
    exit 1
  }
  for file in "$STAGE"/*; do
    name="$(basename "$file")"
    adb push "$file" "/data/local/tmp/$name" >/dev/null
    adb shell "run-as $PACKAGE cp /data/local/tmp/$name files/vision/$name"
    adb shell "rm /data/local/tmp/$name"
    echo "  $name"
  done
fi

if [[ $IOS -eq 1 ]]; then
  # Matches VisionEngine.modelDirectory: Application Support/vision.
  echo "Pushing to iOS"
  if ! command -v xcrun >/dev/null; then
    echo "xcrun is not on the path; this half needs macOS." >&2
    exit 1
  fi
  BUNDLE="ai.arcvanta.arcvanta"
  CONTAINER="$(xcrun simctl get_app_container booted "$BUNDLE" data)"
  mkdir -p "$CONTAINER/Library/Application Support/vision"
  cp "$STAGE"/* "$CONTAINER/Library/Application Support/vision/"
  echo "  copied into $CONTAINER"
fi

if [[ $ANDROID -eq 0 && $IOS -eq 0 ]]; then
  echo
  echo "Verified only. Pass --android or --ios to install."
fi
