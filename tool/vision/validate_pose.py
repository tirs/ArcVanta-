#!/usr/bin/env python3
"""Measures the exported pose graph against ground-truth landmarks.

verify_contract.py proves a graph is shaped right and computes something
finite. That is not the same as proving it is correct, and the difference
matters here more than in most products: a pose model that is subtly wrong
still returns seventeen plausible landmarks, the app still draws a convincing
skeleton, and the first sign of trouble is a coach disputing a release angle.

So this runs the graph over annotated images and reports how far the predicted
landmarks actually land from the labelled ones.

    python tool/vision/validate_pose.py \\
        --model build/vision/arcvanta_rtmpose_m_256x192.onnx \\
        --coco vision/.vendor/mmpose/tests/data/coco

Preprocessing and decode are implemented here from
vision/contract/model_contract.json rather than from mmpose, deliberately. The
native bridges implement the same two steps from the same file, and this is the
only place the three implementations can be checked against a known answer.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np
import onnxruntime as ort

import pins

# Landmarks the product actually measures. Faces are dropped at the bridge, so
# scoring them here would flatter the result with the easiest five points in
# the set.
BODY_KEYPOINTS = tuple(range(5, 17))


def contract() -> dict:
    return json.loads(
        "\n".join(
            line
            for line in pins.CONTRACT.read_text().splitlines()
            if not line.lstrip().startswith("//")
        )
    )


def box_to_centre_scale(
    bbox: tuple[float, float, float, float],
    aspect: float,
    padding: float,
) -> tuple[np.ndarray, np.ndarray]:
    """COCO xywh to the centre and source size the affine crop reads.

    The box is padded, then widened or heightened to the model's aspect ratio,
    so the athlete is never squashed to fit 192x256.
    """
    x, y, w, h = bbox
    centre = np.array([x + w * 0.5, y + h * 0.5], dtype=np.float32)
    scale = np.array([w, h], dtype=np.float32) * padding

    if scale[0] > scale[1] * aspect:
        scale[1] = scale[0] / aspect
    else:
        scale[0] = scale[1] * aspect

    return centre, scale


def preprocess(
    image: np.ndarray,
    centre: np.ndarray,
    scale: np.ndarray,
    size: tuple[int, int],
    mean: np.ndarray,
    std: np.ndarray,
) -> np.ndarray:
    """Warp the person box to the model input and normalise it."""
    width, height = size
    source = np.array(
        [
            [centre[0] - scale[0] * 0.5, centre[1] - scale[1] * 0.5],
            [centre[0] + scale[0] * 0.5, centre[1] - scale[1] * 0.5],
            [centre[0] - scale[0] * 0.5, centre[1] + scale[1] * 0.5],
        ],
        dtype=np.float32,
    )
    target = np.array([[0, 0], [width, 0], [0, height]], dtype=np.float32)

    warp = cv2.getAffineTransform(source, target)
    crop = cv2.warpAffine(image, warp, (width, height), flags=cv2.INTER_LINEAR)

    rgb = cv2.cvtColor(crop, cv2.COLOR_BGR2RGB).astype(np.float32)
    rgb = (rgb - mean) / std
    return rgb.transpose(2, 0, 1)[None]


def decode(
    simcc_x: np.ndarray,
    simcc_y: np.ndarray,
    split: float,
    centre: np.ndarray,
    scale: np.ndarray,
    size: tuple[int, int],
) -> tuple[np.ndarray, np.ndarray]:
    """SimCC argmax on each axis, mapped back to image pixels."""
    width, height = size

    x_index = simcc_x.argmax(axis=-1).astype(np.float32)
    y_index = simcc_y.argmax(axis=-1).astype(np.float32)
    scores = simcc_x.max(axis=-1) * simcc_y.max(axis=-1)

    # Input-space coordinates, then back through the crop that produced them.
    x = x_index / split
    y = y_index / split
    image_x = centre[0] - scale[0] * 0.5 + x * scale[0] / width
    image_y = centre[1] - scale[1] * 0.5 + y * scale[1] / height

    return np.stack([image_x, image_y], axis=-1)[0], scores[0]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--coco", type=Path, required=True)
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.05,
        help="PCK radius as a fraction of the person box's longer side.",
    )
    args = parser.parse_args()

    spec = contract()["pose"]
    _, _, height, width = spec["input"]["shape"]
    size = (width, height)
    mean = np.array(spec["preprocess"]["mean"], dtype=np.float32)
    std = np.array(spec["preprocess"]["std"], dtype=np.float32)
    padding = spec["preprocess"]["paddingFactor"]
    split = spec["decode"]["splitRatio"]

    annotations = json.loads((args.coco / "test_coco.json").read_text())
    images = {image["id"]: image for image in annotations["images"]}

    session = ort.InferenceSession(
        str(args.model), providers=["CPUExecutionProvider"]
    )
    input_name = session.get_inputs()[0].name

    errors: list[float] = []
    hits = 0
    counted = 0
    people = 0

    for annotation in annotations["annotations"]:
        if annotation.get("iscrowd") or annotation["num_keypoints"] == 0:
            continue

        meta = images[annotation["image_id"]]
        path = args.coco / Path(meta["file_name"]).name
        image = cv2.imread(str(path))
        if image is None:
            print(f"  missing image: {path}")
            continue

        centre, scale = box_to_centre_scale(
            annotation["bbox"], width / height, padding
        )
        batch = preprocess(image, centre, scale, size, mean, std)
        simcc_x, simcc_y = session.run(None, {input_name: batch})
        predicted, _ = decode(simcc_x, simcc_y, split, centre, scale, size)

        truth = np.array(annotation["keypoints"], dtype=np.float32).reshape(-1, 3)
        radius = max(annotation["bbox"][2], annotation["bbox"][3]) * args.threshold
        people += 1

        for joint in BODY_KEYPOINTS:
            if truth[joint, 2] <= 0:
                continue
            distance = float(
                np.linalg.norm(predicted[joint] - truth[joint, :2])
            )
            errors.append(distance)
            counted += 1
            if distance <= radius:
                hits += 1

    if not counted:
        print("No labelled body landmarks to score against.")
        return 1

    errors_array = np.array(errors)
    print(f"People scored:      {people}")
    print(f"Landmarks scored:   {counted}")
    print(f"PCK@{args.threshold:.2f}:          {hits / counted * 100:.1f}%")
    print(f"Median error:       {np.median(errors_array):.1f} px")
    print(f"Mean error:         {errors_array.mean():.1f} px")
    print(f"90th percentile:    {np.percentile(errors_array, 90):.1f} px")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
