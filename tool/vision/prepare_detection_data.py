#!/usr/bin/env python3
"""Rewrite a source basketball dataset into the four classes the app expects.

The contract in vision/contract/model_contract.json fixes the detector's class
ids: 0 person, 1 ball, 2 rim, 3 backboard. Source datasets do not use those
ids, do not use those names, and generally do not have all four. This script is
the one place that mapping lives, so the training config, the exporter and the
app can all assume the contract order without any of them knowing where the
data came from.

Two decisions worth stating, because both are easy to get silently wrong:

Referees are people. Mapping them to `person` alongside players is not a
compromise; the app has no notion of who is playing, it needs to find human
bodies to run pose on. Dropping referees would leave annotated humans in the
frame marked as background, which actively teaches the detector to miss people
standing at the edge of a court.

A class with no annotations is kept, not dropped. Backboard has no labels in
any source we have. Training a three-class head and renumbering would make the
graph disagree with the contract, and every consumer would need to know which
vintage of model it was holding. A four-class head with an untrained class
produces near-zero scores for it, which is the truthful output — the model has
never seen one — and the court solve already treats the backboard as optional.
"""

from __future__ import annotations

import argparse
import collections
import json
import pathlib
import sys

# Fixed by the contract. Order is the class id.
CONTRACT_CLASSES = ("person", "ball", "rim", "backboard")

# Source category name (lowercased) -> contract class name.
SOURCE_ALIASES = {
    "player": "person",
    "referee": "person",
    "person": "person",
    "people": "person",
    "basketball": "ball",
    "ball": "ball",
    "sports ball": "ball",
    "hoop": "rim",
    "rim": "rim",
    "basket": "rim",
    "net": "rim",
    "backboard": "backboard",
    "board": "backboard",
}


def convert(source: pathlib.Path, destination: pathlib.Path) -> dict[str, int]:
    payload = json.loads(source.read_text())

    by_id = {c["id"]: c["name"].strip().lower() for c in payload["categories"]}

    unmapped = sorted({n for n in by_id.values() if n not in SOURCE_ALIASES})
    if unmapped:
        raise SystemExit(
            f"{source.name}: no contract class for {unmapped}. Add it to "
            f"SOURCE_ALIASES, or decide deliberately to drop it."
        )

    remap = {
        cid: CONTRACT_CLASSES.index(SOURCE_ALIASES[name])
        for cid, name in by_id.items()
    }

    counts: collections.Counter[str] = collections.Counter()
    annotations = []
    for annotation in payload["annotations"]:
        x, y, w, h = annotation["bbox"]
        # Degenerate boxes make the loss non-finite rather than merely wrong,
        # so they are dropped here instead of at epoch 30.
        if w <= 1 or h <= 1:
            counts["dropped: degenerate box"] += 1
            continue

        target = remap[annotation["category_id"]]
        annotations.append(
            {
                **annotation,
                "category_id": target,
                "iscrowd": annotation.get("iscrowd", 0),
                "area": annotation.get("area", w * h),
            }
        )
        counts[CONTRACT_CLASSES[target]] += 1

    payload["categories"] = [
        {"id": i, "name": name, "supercategory": "arcvanta"}
        for i, name in enumerate(CONTRACT_CLASSES)
    ]
    payload["annotations"] = annotations

    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(payload))

    counts["images"] = len(payload["images"])
    return dict(counts)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=pathlib.Path)
    parser.add_argument("--destination", required=True, type=pathlib.Path)
    args = parser.parse_args()

    counts = convert(args.source, args.destination)

    print(f"{args.source.name} -> {args.destination}")
    for key in ("images", *CONTRACT_CLASSES):
        marker = "  (none in this source)" if counts.get(key, 0) == 0 else ""
        print(f"  {key:<10} {counts.get(key, 0):>7}{marker}")
    for key, value in sorted(counts.items()):
        if key.startswith("dropped"):
            print(f"  {key}: {value}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
