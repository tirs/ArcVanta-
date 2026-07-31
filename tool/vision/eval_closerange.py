#!/usr/bin/env python3
"""Run the detector over close-range hoop photographs and report what it sees.

The COCO metrics computed during training answer "how well does this model do
on data like its training data". That is not the question the app asks. The app
points a phone at one hoop from four to six metres, where the ring fills a
large part of the frame; the only public basketball detection data is broadcast
footage where the ring is sixty pixels wide in a wide elevated shot. A model can
score well on the first and be useless for the second, and no number computed
on the validation split will reveal that.

So this evaluates on held-out photographs at roughly the app's framing, taken
from Wikimedia Commons under open licences (see the manifest beside them). They
carry no ground-truth boxes, which limits what can be claimed: this reports
detection rate and confidence and writes an annotated contact sheet, and the
judgement about whether the boxes are good enough is made by looking at it.

That is a weaker instrument than mAP, and deliberately so. A precise-looking
number derived from boxes this script drew itself would be worse than an honest
picture.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys

import cv2
import numpy as np

CLASSES = ("person", "ball", "rim", "backboard")
COLOURS = {
    "person": (62, 138, 232),
    "ball": (51, 92, 214),
    "rim": (123, 122, 44),
    "backboard": (74, 63, 58),
}


def annotate(image, detections, threshold):
    canvas = image.copy()
    for name, score, (x1, y1, x2, y2) in detections:
        if score < threshold:
            continue
        colour = COLOURS[name]
        cv2.rectangle(canvas, (int(x1), int(y1)), (int(x2), int(y2)), colour, 3)
        label = f"{name} {score:.2f}"
        (tw, th), _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
        cv2.rectangle(
            canvas,
            (int(x1), int(y1) - th - 8),
            (int(x1) + tw + 6, int(y1)),
            colour,
            -1,
        )
        cv2.putText(
            canvas,
            label,
            (int(x1) + 3, int(y1) - 5),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            (255, 255, 255),
            2,
        )
    return canvas


def contact_sheet(tiles, columns=3, cell=(640, 400)):
    rows = (len(tiles) + columns - 1) // columns
    sheet = np.full((rows * cell[1], columns * cell[0], 3), 24, dtype=np.uint8)
    for i, tile in enumerate(tiles):
        h, w = tile.shape[:2]
        scale = min(cell[0] / w, cell[1] / h)
        resized = cv2.resize(tile, (int(w * scale), int(h * scale)))
        r, c = divmod(i, columns)
        y = r * cell[1] + (cell[1] - resized.shape[0]) // 2
        x = c * cell[0] + (cell[0] - resized.shape[1]) // 2
        sheet[y : y + resized.shape[0], x : x + resized.shape[1]] = resized
    return sheet


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True)
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--images", required=True, type=pathlib.Path)
    parser.add_argument("--out", required=True, type=pathlib.Path)
    parser.add_argument("--threshold", type=float, default=0.3)
    parser.add_argument("--device", default="cuda:0")
    args = parser.parse_args()

    # torch 2.6 flipped torch.load's default to weights_only=True and mmengine
    # 0.10.5 predates it, so its checkpoints will not load unmodified. The
    # allowlist route was tried first and abandoned: the metric buffers pull in
    # enough of the pickle machinery that satisfying it ends at allowlisting
    # `getattr`, which is not a smaller hole than the one it was closing.
    #
    # These are checkpoints written by tools/train.py on this machine, so
    # provenance is not in question. mmdet's own tools/train.py and tools/
    # test.py need the same variable set in the environment; this sets it here
    # so the one script anybody runs by hand does not need a wrapper.
    os.environ.setdefault("TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD", "1")

    from mmdet.apis import inference_detector, init_detector

    model = init_detector(args.config, args.checkpoint, device=args.device)
    args.out.mkdir(parents=True, exist_ok=True)

    paths = sorted(args.images.glob("*.jpg"))
    if not paths:
        raise SystemExit(f"no images in {args.images}")

    tiles = []
    report = {}
    found = {name: 0 for name in CLASSES}

    for path in paths:
        image = cv2.imread(str(path))
        result = inference_detector(model, image)
        instances = result.pred_instances

        detections = [
            (CLASSES[int(label)], float(score), bbox.tolist())
            for bbox, score, label in zip(
                instances.bboxes.cpu().numpy(),
                instances.scores.cpu().numpy(),
                instances.labels.cpu().numpy(),
            )
        ]

        best: dict[str, float] = {}
        for name, score, _ in detections:
            best[name] = max(best.get(name, 0.0), score)
        for name, score in best.items():
            if score >= args.threshold:
                found[name] += 1

        report[path.name] = {
            "size": [image.shape[1], image.shape[0]],
            "best_score": {k: round(v, 3) for k, v in sorted(best.items())},
        }
        tiles.append(annotate(image, detections, args.threshold))

    sheet_path = args.out / "closerange_detections.jpg"
    cv2.imwrite(str(sheet_path), contact_sheet(tiles))
    (args.out / "closerange_report.json").write_text(json.dumps(report, indent=1))

    total = len(paths)
    print(f"{total} close-range images at threshold {args.threshold}\n")
    for name in CLASSES:
        rate = found[name] / total
        print(f"  {name:<10} detected in {found[name]:>2}/{total}  ({rate:.0%})")

    rims = [
        r["best_score"].get("rim", 0.0)
        for r in report.values()
        if r["best_score"].get("rim", 0.0) >= args.threshold
    ]
    if rims:
        print(
            f"\n  rim confidence when found: "
            f"min {min(rims):.2f}  median {sorted(rims)[len(rims) // 2]:.2f}  "
            f"max {max(rims):.2f}"
        )
    print(f"\nContact sheet: {sheet_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
