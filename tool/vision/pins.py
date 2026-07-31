"""Reads vision/pins.lock.

Shared by the export script and the verifier so there is one parser and one
place that knows where the lock file lives.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / "vision" / "pins.lock"
CONTRACT = ROOT / "vision" / "contract" / "model_contract.json"
VENDOR = ROOT / "vision" / ".vendor"


class PinError(RuntimeError):
    pass


def load() -> dict[str, str]:
    if not LOCK.exists():
        raise PinError(f"{LOCK} is missing")

    pins: dict[str, str] = {}
    for number, raw in enumerate(LOCK.read_text().splitlines(), start=1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split(None, 1)
        if len(parts) != 2:
            raise PinError(f"{LOCK}:{number}: expected 'key value', got {raw!r}")
        pins[parts[0]] = parts[1].strip()
    return pins


def require(pins: dict[str, str], key: str) -> str:
    if key not in pins:
        raise PinError(f"pins.lock has no entry for '{key}'")
    return pins[key]


def check_vendor(pins: dict[str, str]) -> None:
    """Fails if a vendored checkout has drifted off its pin.

    Worth doing before every export rather than once at setup: a checkout that
    moved produces a graph that no longer matches the recipe recorded beside
    it, and the resulting model is indistinguishable from a correct one until
    someone compares measured angles.
    """
    for name in ("mmengine", "mmcv", "mmdet", "mmpose"):
        path = VENDOR / name
        expected = require(pins, f"{name}.commit")

        if not (path / ".git").exists():
            raise PinError(f"{path} is not vendored. Run tool/vision/setup.sh first.")

        head = subprocess.run(
            ["git", "-C", str(path), "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()

        if head != expected:
            raise PinError(
                f"{name} is at {head}, pins.lock says {expected}. "
                "The export would not match the recipe."
            )
