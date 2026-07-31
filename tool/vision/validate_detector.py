#!/usr/bin/env python3
"""Check the exported detector graph against the PyTorch model it came from.

The contract verifier answers "is this graph shaped the way the app expects".
That is a necessary check and a weak one: `DetectorForExport` reimplements
RTMDet's anchor-point and distance-to-edge decode by hand rather than calling
into mmdeploy, and a wrong stride or a flipped distance convention produces a
graph that is perfectly well shaped and puts every box in the wrong place.

So this runs both, on the same images, and compares the boxes. Agreement here
is what makes the decode trustworthy; the shapes were never in doubt.

The comparison is deliberately strict about position and lenient about
ordering. Two implementations can legitimately break a score tie differently,
so detections are matched by IoU rather than by index, and what is reported is
how far apart the matched pairs are.
"""

from __future__ import annotations

import argparse
import os
import pathlib
import sys

import numpy as np

CLASSES = ("person", "ball", "rim", "backboard")


def letterbox(image, size, pad_value=114):
    """Resize preserving aspect and pad, exactly as the contract describes."""
    height, width = image.shape[:2]
    scale = min(size / height, size / width)
    resized_w, resized_h = int(round(width * scale)), int(round(height * scale))

    import cv2

    resized = cv2.resize(image, (resized_w, resized_h))
    canvas = np.full((size, size, 3), pad_value, dtype=np.uint8)
    canvas[:resized_h, :resized_w] = resized
    return canvas, scale


def preprocess(image, spec):
    """Mirror the contract exactly, including its colour order.

    `image` arrives from cv2.imread, which is BGR. The contract says the
    detector wants BGR, so there is no swap here — and the absence of one is
    the point of this function, because the swap that used to be here cost
    twenty pixels of box centre error while still producing plausible output.
    """
    size = spec["input"]["shape"][2]
    canvas, scale = letterbox(image, size, spec["preprocess"]["padValue"])
    if spec["input"]["colour"] == "RGB":
        canvas = canvas[:, :, ::-1]
    elif spec["input"]["colour"] != "BGR":
        raise SystemExit(f"unknown colour order {spec['input']['colour']!r}")

    mean = np.array(spec["preprocess"]["mean"], dtype=np.float32)
    std = np.array(spec["preprocess"]["std"], dtype=np.float32)
    normalised = (canvas.astype(np.float32) - mean) / std
    return normalised.transpose(2, 0, 1)[None], scale


def iou(a, b):
    x1 = max(a[0], b[0])
    y1 = max(a[1], b[1])
    x2 = min(a[2], b[2])
    y2 = min(a[3], b[3])
    overlap = max(0.0, x2 - x1) * max(0.0, y2 - y1)
    area_a = max(0.0, a[2] - a[0]) * max(0.0, a[3] - a[1])
    area_b = max(0.0, b[2] - b[0]) * max(0.0, b[3] - b[1])
    union = area_a + area_b - overlap
    return overlap / union if union > 0 else 0.0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--onnx", required=True, type=pathlib.Path)
    parser.add_argument("--config", required=True)
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--images", required=True, type=pathlib.Path)
    parser.add_argument("--contract", type=pathlib.Path, default=None)
    parser.add_argument("--threshold", type=float, default=0.3)
    parser.add_argument("--limit", type=int, default=12)
    args = parser.parse_args()

    os.environ.setdefault("TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD", "1")

    import json

    import cv2
    import onnxruntime
    import torch
    from mmdet.apis import inference_detector, init_detector

    root = pathlib.Path(__file__).resolve().parents[2]
    contract_path = args.contract or root / "vision/contract/model_contract.json"
    spec = json.loads(contract_path.read_text())["detector"]

    session = onnxruntime.InferenceSession(
        str(args.onnx), providers=["CPUExecutionProvider"]
    )
    model = init_detector(args.config, args.checkpoint, device="cpu")

    # The contract's NMS is not mmdet's: it suppresses at 0.6 rather than 0.65
    # and returns a hundred boxes rather than three hundred, both because the
    # graph has to hand a fixed-size buffer to a phone. Those are product
    # choices, so they are pushed onto the reference here. Comparing against
    # mmdet's defaults would report them as decode errors and bury whatever
    # real disagreement is left.
    nms = spec["nms"]
    model.bbox_head.test_cfg["nms"]["iou_threshold"] = nms["iouThreshold"]
    model.bbox_head.test_cfg["score_thr"] = nms["scoreThreshold"]
    model.bbox_head.test_cfg["max_per_img"] = nms["maxDetections"]

    paths = sorted(args.images.glob("*.jpg"))[: args.limit]
    if not paths:
        raise SystemExit(f"no images in {args.images}")

    ious: list[float] = []
    centre_errors: list[float] = []
    score_errors: list[float] = []
    matched = 0
    claimed = 0
    torch_total = 0
    onnx_only = 0

    for path in paths:
        image = cv2.imread(str(path))
        tensor, scale = preprocess(image, spec)

        dets, labels = session.run(None, {spec["input"]["name"]: tensor})
        dets, labels = dets[0], labels[0]
        # Boxes come back in letterboxed input pixels; undo the scale so both
        # sides are talking about the original image.
        onnx_boxes = [
            (int(label), float(row[4]), (row[:4] / scale).tolist())
            for row, label in zip(dets, labels)
            if row[4] >= args.threshold
        ]

        result = inference_detector(model, image).pred_instances
        torch_boxes = [
            (int(label), float(score), bbox.tolist())
            for bbox, score, label in zip(
                result.bboxes.numpy(), result.scores.numpy(), result.labels.numpy()
            )
            if score >= args.threshold
        ]
        torch_total += len(torch_boxes)

        remaining = list(onnx_boxes)
        for cls, score, box in torch_boxes:
            best, best_iou = None, 0.0
            for candidate in remaining:
                if candidate[0] != cls:
                    continue
                overlap = iou(box, candidate[2])
                if overlap > best_iou:
                    best, best_iou = candidate, overlap
            if best is None or best_iou < 0.5:
                # mmdet emits a detection per class per anchor, so one anchor
                # can appear as both a ball and a faint person. The graph emits
                # one row per anchor carrying its best class, because the app
                # wants one object per box and a rim that is also labelled
                # backboard is noise the calibration then has to unpick. When a
                # reference detection is absent, check whether its anchor was
                # simply claimed by a stronger class before calling it lost.
                # Against every graph detection, not just the unmatched ones:
                # the row that claimed this anchor was paired off with its own
                # reference detection long before we got here.
                if any(
                    other[0] != cls and iou(box, other[2]) >= 0.5
                    for other in onnx_boxes
                ):
                    claimed += 1
                continue
            remaining.remove(best)
            matched += 1
            ious.append(best_iou)
            score_errors.append(abs(score - best[1]))
            centre_errors.append(
                float(
                    np.hypot(
                        (box[0] + box[2]) / 2 - (best[2][0] + best[2][2]) / 2,
                        (box[1] + box[3]) / 2 - (best[2][1] + best[2][3]) / 2,
                    )
                )
            )
        onnx_only += len(remaining)

    print(f"{len(paths)} images, score threshold {args.threshold}\n")
    print(f"  PyTorch detections      {torch_total}")
    print(f"  matched in ONNX         {matched}")
    print(f"  same box, better class  {claimed}")
    print(f"  missing from ONNX       {torch_total - matched - claimed}")
    print(f"  extra in ONNX           {onnx_only}")

    if not ious:
        print("\n  Nothing matched. The decode is wrong, not merely imprecise.")
        return 1

    print(f"\n  box IoU        median {np.median(ious):.4f}  min {min(ious):.4f}")
    print(
        f"  centre error   median {np.median(centre_errors):.2f} px  "
        f"max {max(centre_errors):.2f} px"
    )
    print(
        f"  score error    median {np.median(score_errors):.4f}  "
        f"max {max(score_errors):.4f}"
    )

    # A hand-written decode that agrees to within a pixel is reproducing the
    # reference, not approximating it. Anything looser means a convention is
    # subtly off and the boxes will drift with object size or position.
    healthy = (
        matched + claimed == torch_total
        and onnx_only == 0
        and float(np.median(ious)) > 0.99
        and max(centre_errors) < 2.0
    )
    print("\n  " + ("Graph agrees with the model." if healthy else "MISMATCH."))
    return 0 if healthy else 1


if __name__ == "__main__":
    sys.exit(main())
