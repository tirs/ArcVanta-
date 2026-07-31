#!/usr/bin/env python3
"""Exports RTMDet and RTMPose to the graphs the app builds against.

Run inside the environment tool/vision/setup.sh creates. Everything that
defines the interface — tensor names, shapes, normalisation, decode — comes
from vision/contract/model_contract.json, so this script cannot quietly
disagree with the app: if it writes something else, verify_contract.py fails
and the file is not published.

    python tool/vision/export_onnx.py \
        --detector-checkpoint work/rtmdet_m_arcvanta.pth \
        --pose-checkpoint work/rtmpose_m_arcvanta.pth \
        --out build/vision

The graphs carry non-maximum suppression for the detector, because the
alternative is two more decode implementations — one Kotlin, one Swift — that
have to agree with each other and with this one about anchor strides.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

import pins

# Vendored, not installed: the pinned tree is on the path explicitly so an
# unrelated mmdet in site-packages cannot be picked up instead.
for _package in ("mmengine", "mmcv", "mmdet", "mmpose"):
    sys.path.insert(0, str(pins.VENDOR / _package))

import torch  # noqa: E402
import torch.nn as nn  # noqa: E402
import torchvision  # noqa: E402
from mmengine.config import Config  # noqa: E402
from mmengine.runner import load_checkpoint  # noqa: E402

ROOT = pins.ROOT
CONFIGS = ROOT / "vision" / "configs"


def contract() -> dict:
    return json.loads(
        "\n".join(
            line
            for line in pins.CONTRACT.read_text().splitlines()
            if not line.lstrip().startswith("//")
        )
    )


class DetectorForExport(nn.Module):
    """RTMDet with decode and NMS folded into the graph.

    The head predicts, per feature level, a class score map and a distance map:
    for each anchor point, how far the box edge is in each of the four
    directions. Turning that into boxes needs the stride of each level and the
    grid of anchor points, and both are properties of the config rather than of
    the weights. Doing it here means the two native bridges do not each need a
    copy of that knowledge, and cannot drift from it.
    """

    def __init__(self, model, spec: dict):
        super().__init__()
        self.model = model
        self.nms = spec["nms"]
        self.size = spec["input"]["shape"][2]
        # How many candidates reach NMS. RTMDet-m at 640 produces 8,400 anchor
        # points; a thousand is far more than the hundred that can survive and
        # keeps the sort cheap on a phone.
        self.pre_nms_topk = 1000
        # RTMDet-m runs three levels at these strides. Read off the config
        # rather than hardcoded so a variant change cannot silently shift every
        # decoded box by a factor of two.
        self.strides = [
            level["strides"][0] if isinstance(level, dict) else level
            for level in model.bbox_head.prior_generator.strides
        ]
        # Where in its cell an anchor point sits, as a fraction of the stride.
        # RTMDet uses 0, putting the point on the cell's top-left corner; the
        # more common 0.5 puts it at the centre. Read rather than assumed,
        # because guessing 0.5 here moves every box from the coarsest level by
        # sixteen pixels diagonally and leaves the scores untouched, so it
        # looks like a working detector that cannot quite find the rim.
        self.offset = float(model.bbox_head.prior_generator.offset)

    def forward(self, images: torch.Tensor):
        features = self.model.extract_feat(images)
        cls_scores, bbox_preds = self.model.bbox_head(features)

        boxes = []
        scores = []

        for level, (cls_score, bbox_pred) in enumerate(zip(cls_scores, bbox_preds)):
            stride = self.strides[level]
            stride = stride[0] if isinstance(stride, (tuple, list)) else stride
            batch, classes, rows, columns = cls_score.shape

            # Anchor points in input pixels.
            shift_x = (
                torch.arange(columns, device=cls_score.device) + self.offset
            ) * stride
            shift_y = (
                torch.arange(rows, device=cls_score.device) + self.offset
            ) * stride
            grid_y, grid_x = torch.meshgrid(shift_y, shift_x, indexing="ij")
            centres = torch.stack(
                [grid_x.reshape(-1), grid_y.reshape(-1)], dim=-1
            )  # [rows*columns, 2]

            # RTMDet's head is distance-to-edge, already in input pixels.
            distances = bbox_pred.permute(0, 2, 3, 1).reshape(batch, -1, 4)
            level_boxes = torch.stack(
                [
                    centres[:, 0] - distances[..., 0],
                    centres[:, 1] - distances[..., 1],
                    centres[:, 0] + distances[..., 2],
                    centres[:, 1] + distances[..., 3],
                ],
                dim=-1,
            )

            boxes.append(level_boxes)
            scores.append(
                cls_score.permute(0, 2, 3, 1).reshape(batch, -1, classes).sigmoid()
            )

        boxes = torch.cat(boxes, dim=1)[0]
        scores = torch.cat(scores, dim=1)[0]

        best_score, best_class = scores.max(dim=1)

        # Everything below is written to keep every tensor's shape a constant,
        # because NNAPI and Core ML reject a graph whose buffers cannot be
        # sized ahead of time. The obvious formulations all fail that:
        #
        #   boxes[best_score > threshold]  -> NonZero, output length unknown
        #   nms(...)[:limit]               -> Slice of an unknown length
        #   if pad > 0: cat(...)           -> a Python branch on a traced shape,
        #                                     baked to whatever the dummy input
        #                                     happened to produce
        #
        # So the score threshold becomes a fixed-size top-k, and NMS is applied
        # by *masking* rather than by gathering: the suppressed candidates keep
        # their slot and lose their score. A second top-k then picks the output
        # rows. Both top-k calls have constant k, so the whole tail is static.
        candidates = min(self.pre_nms_topk, best_score.shape[0])
        best_score, shortlist = best_score.topk(candidates)
        boxes = boxes.index_select(0, shortlist)
        best_class = best_class.index_select(0, shortlist)

        boxes = boxes.clamp(min=0.0, max=float(self.size))

        # Class-aware, so a ball in front of the backboard cannot suppress the
        # backboard and leave the calibration without it. Offsetting each
        # class into its own coordinate band is how one NMS call is made to
        # behave like one call per class, and unlike torchvision's batched_nms
        # it survives the trace as a single NonMaxSuppression node.
        offsets = best_class.to(boxes.dtype) * (float(self.size) + 1.0)
        shifted = boxes + offsets.unsqueeze(-1)

        kept = torchvision.ops.nms(shifted, best_score, self.nms["iouThreshold"])
        # scatter rather than index_fill: the latter's ONNX symbolic in the
        # pinned torch reaches into an empty axes list and raises during
        # export. Both mean "put a one at each of these positions".
        survives = torch.zeros_like(best_score).scatter(0, kept, 1.0) * (
            best_score > self.nms["scoreThreshold"]
        ).to(best_score.dtype)

        limit = self.nms["maxDetections"]
        # Padding rows come out of this with a zero score, which is what the
        # bridge reads to know where the real detections stop.
        final_score, order = (best_score * survives).topk(limit)
        final_boxes = boxes.index_select(0, order)
        final_class = best_class.index_select(0, order)

        dets = torch.cat(
            [final_boxes, final_score.unsqueeze(-1)], dim=-1
        ).unsqueeze(0)
        labels = final_class.to(torch.int64).unsqueeze(0)
        return dets.to(torch.float32), labels


class PoseForExport(nn.Module):
    """RTMPose stopping at the two SimCC distributions.

    The head already emits them; what this drops is the decode, which belongs
    on the device where the crop transform that maps the result back to image
    pixels is known.
    """

    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, image: torch.Tensor):
        features = self.model.extract_feat(image)
        simcc_x, simcc_y = self.model.head(features)
        return simcc_x, simcc_y


def export_detector(args, spec: dict, out: Path) -> Path:
    from mmdet.apis import init_detector

    config = Config.fromfile(str(CONFIGS / "rtmdet_m_arcvanta.py"))
    model = init_detector(config, str(args.detector_checkpoint), device="cpu")
    model.eval()

    wrapper = DetectorForExport(model, spec).eval()
    size = spec["input"]["shape"][2]
    dummy = torch.zeros(1, 3, size, size)

    path = out / spec["file"]
    torch.onnx.export(
        wrapper,
        dummy,
        str(path),
        opset_version=spec["opset"],
        input_names=[spec["input"]["name"]],
        output_names=[output["name"] for output in spec["outputs"]],
        do_constant_folding=True,
        dynamic_axes=None,
    )
    return path


def export_pose(args, spec: dict, out: Path) -> Path:
    from mmpose.apis import init_model

    config = Config.fromfile(str(CONFIGS / "rtmpose_m_arcvanta.py"))
    model = init_model(config, str(args.pose_checkpoint), device="cpu")
    model.eval()

    wrapper = PoseForExport(model).eval()
    height, width = spec["input"]["shape"][2], spec["input"]["shape"][3]
    dummy = torch.zeros(1, 3, height, width)

    path = out / spec["file"]
    torch.onnx.export(
        wrapper,
        dummy,
        str(path),
        opset_version=spec["opset"],
        input_names=[spec["input"]["name"]],
        output_names=[output["name"] for output in spec["outputs"]],
        do_constant_folding=True,
        dynamic_axes=None,
    )
    return path


def simplify(path: Path) -> None:
    """Folds the shape arithmetic the tracer leaves behind.

    Not cosmetic. NNAPI and Core ML partition the graph, and a Reshape whose
    shape is computed at runtime is a node they will not take, which pushes
    everything downstream of it back onto the CPU.
    """
    try:
        import onnx
        from onnxsim import simplify as run

        model, ok = run(onnx.load(str(path)))
        if not ok:
            print(f"  {path.name}: simplifier could not verify, keeping the original")
            return
        onnx.save(model, str(path))
        print(f"  {path.name}: simplified")
    except ImportError:
        print(f"  {path.name}: onnxsim not installed, skipping")


def write_sidecars(path: Path, pins_data: dict[str, str], role: str) -> None:
    """Records what produced this file, next to the file.

    Read back at load time and reported with the session, so a measurement can
    always be traced to the graph that made it.
    """
    digest = hashlib.sha256(path.read_bytes()).hexdigest()

    framework = "mmdet" if role == "detector" else "mmpose"
    commit = pins_data[f"{framework}.commit"][:12]
    path.with_suffix(".version").write_text(
        f"{framework}@{commit}+{digest[:12]}\n"
    )
    path.with_suffix(".sha256").write_text(f"{digest}  {path.name}\n")
    print(f"  {path.name}: sha256 {digest[:16]}...")
    return digest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--detector-checkpoint", type=Path)
    parser.add_argument("--pose-checkpoint", type=Path)
    parser.add_argument("--out", type=Path, default=ROOT / "build" / "vision")
    parser.add_argument(
        "--skip-pin-check",
        action="store_true",
        help="Export from a moved checkout. For bisecting a bad graph only.",
    )
    args = parser.parse_args()

    pins_data = pins.load()
    if not args.skip_pin_check:
        pins.check_vendor(pins_data)
    else:
        print("WARNING: exporting without the pin check. Do not publish this.")

    spec = contract()
    args.out.mkdir(parents=True, exist_ok=True)
    digests = {}

    if args.detector_checkpoint:
        print("Exporting the detector")
        path = export_detector(args, spec["detector"], args.out)
        simplify(path)
        digests["detector"] = write_sidecars(path, pins_data, "detector")

    if args.pose_checkpoint:
        print("Exporting the pose model")
        path = export_pose(args, spec["pose"], args.out)
        simplify(path)
        digests["pose"] = write_sidecars(path, pins_data, "pose")

    if not digests:
        parser.error("nothing to do: pass --detector-checkpoint or --pose-checkpoint")

    print("\nVerifying against the contract")
    result = subprocess.run(
        [sys.executable, str(Path(__file__).parent / "verify_contract.py"),
         "--dir", str(args.out)],
    )
    if result.returncode != 0:
        print("\nThe export does not satisfy the contract. Nothing was published.")
        return result.returncode

    print("\nRecording the digests in the contract")
    text = pins.CONTRACT.read_text()
    for role, digest in digests.items():
        marker = f'"file": "{spec[role]["file"]}",'
        start = text.index(marker)
        head = text.index('"sha256":', start)
        tail = text.index("\n", head)
        text = text[:head] + f'"sha256": "{digest}",' + text[tail:]
    pins.CONTRACT.write_text(text)

    print(f"\nDone. Graphs are in {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
