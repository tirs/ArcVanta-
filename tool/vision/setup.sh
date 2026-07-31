#!/usr/bin/env bash
#
# Builds the training-time environment at the commits in vision/pins.lock.
#
# This is not part of the app build. It runs on a workstation, produces two
# .onnx files, and is then not needed again until the models change. Nothing it
# installs is a runtime dependency: see the note at the top of pins.lock.
#
#   tool/vision/setup.sh [--dir vision/.venv]
#
# Idempotent. Re-running with the same pins is a no-op apart from the checks.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PINS="$ROOT/vision/pins.lock"
VENDOR="$ROOT/vision/.vendor"
VENV="$ROOT/vision/.venv"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) VENV="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

pin() {
  # Reads one `key value` line out of the lock file.
  local key="$1"
  local value
  value="$(grep -E "^${key}[[:space:]]" "$PINS" | head -n1 | awk '{print $2}')"
  if [[ -z "$value" ]]; then
    echo "pins.lock has no entry for '$key'" >&2
    exit 1
  fi
  printf '%s' "$value"
}

vendor() {
  # Clones at a commit, or checks that an existing clone is at that commit.
  # Refusing to move an existing checkout is deliberate: a silent fast-forward
  # is how a pinned pipeline stops being pinned.
  local name="$1" url="$2" commit="$3"
  local path="$VENDOR/$name"

  if [[ -d "$path/.git" ]]; then
    local head
    head="$(git -C "$path" rev-parse HEAD)"
    if [[ "$head" != "$commit" ]]; then
      echo "vision/.vendor/$name is at $head, pins.lock says $commit." >&2
      echo "Delete it and re-run if the pin was changed on purpose." >&2
      exit 1
    fi
    echo "  $name at $commit (already vendored)"
    return
  fi

  echo "  $name -> $commit"
  mkdir -p "$path"
  git -C "$path" init --quiet
  git -C "$path" remote add origin "$url"
  git -C "$path" fetch --quiet --depth 1 origin "$commit"
  git -C "$path" checkout --quiet FETCH_HEAD
}

echo "Reading pins from vision/pins.lock"
TORCH="$(pin torch)"
TORCHVISION="$(pin torchvision)"
ONNX="$(pin onnx)"
ONNXRUNTIME="$(pin onnxruntime)"
ONNXSIM="$(pin onnxsim)"
NUMPY="$(pin numpy)"
SETUPTOOLS="$(pin setuptools)"
OPENCV="$(pin opencv)"

if [[ ! -d "$VENV" ]]; then
  echo "Creating $VENV"
  python3 -m venv "$VENV"
fi
# shellcheck disable=SC1091
source "$VENV/bin/activate"

python -m pip install --quiet --upgrade pip wheel
python -m pip install --quiet "setuptools==$SETUPTOOLS"

echo "Installing the export toolchain"
python -m pip install --quiet \
  "numpy==$NUMPY" \
  "torch==$TORCH" \
  "torchvision==$TORCHVISION" \
  "onnx==$ONNX" \
  "onnxruntime==$ONNXRUNTIME" \
  "onnxsim==$ONNXSIM" \
  "opencv-python==$OPENCV"

echo "Vendoring the OpenMMLab tree"
mkdir -p "$VENDOR"
vendor mmengine "$(pin mmengine)" "$(pin mmengine.commit)"
vendor mmcv     "$(pin mmcv)"     "$(pin mmcv.commit)"
vendor mmdet    "$(pin mmdet)"    "$(pin mmdet.commit)"
vendor mmpose   "$(pin mmpose)"   "$(pin mmpose.commit)"

echo "Installing the vendored tree in editable mode"
python -m pip install --quiet --no-build-isolation -e "$VENDOR/mmengine"
# mmcv builds its extensions from source, which is slow the first time and
# cached afterwards. MMCV_WITH_OPS is what makes the CUDA-free build usable.
MMCV_WITH_OPS=1 python -m pip install --quiet --no-build-isolation -e "$VENDOR/mmcv"
python -m pip install --quiet --no-build-isolation -e "$VENDOR/mmdet"
python -m pip install --quiet --no-build-isolation -e "$VENDOR/mmpose"

# The OpenMMLab installs pull their own requirements and can drag numpy
# forward again, so the pinned pair is reasserted after them rather than
# before.
python -m pip install --quiet "numpy==$NUMPY" "opencv-python==$OPENCV"

echo
echo "Ready. The environment is at $VENV"
echo "Next:  source ${VENV#"$ROOT"/}/bin/activate && python tool/vision/export_onnx.py --help"
