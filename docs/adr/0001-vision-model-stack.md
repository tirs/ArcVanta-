# 1. Vision model stack

Accepted, 29 July 2026.

## Decision

| Stage | Choice | Licence |
| --- | --- | --- |
| Object detection (ball, rim, players) | RTMDet, from MMDetection | Apache 2.0 |
| Pose, first version | MediaPipe Pose (BlazePose) | Apache 2.0 |
| Pose, second version | Basketball-trained RTMPose, from MMPose | Apache 2.0 |

Ultralytics YOLO is rejected. Monocular 3D pose is rejected for the
single-camera product.

## Why not Ultralytics YOLO

YOLOv8 and YOLOv11 are AGPL-3.0, and both the code and the pretrained weights
carry it. Copyleft reaches the shipped application, not just the model layer, so
a closed-source store build would require Ultralytics' commercial licence.
RTMDet gives comparable custom-object detection under Apache 2.0, which imposes
no obligation on the app.

## Why RTMDet specifically

It ships a size ladder from tiny to x, so the same architecture covers an
on-device build and a heavier cloud pass. It exports through MMDeploy to ONNX
and on to NCNN, CoreML or TFLite. And it comes from the same organisation as
MMPose, so detection and pose share one training toolchain rather than two.

Acceptable substitutes under equivalent terms, if RTMDet does not fit: YOLOX,
RT-DETR, D-FINE, PP-YOLOE. Excluded on licence grounds: YOLOv6, YOLOv7 and
YOLOv9 (GPL-3.0) and YOLO-NAS (restrictive weights licence).

## Why MediaPipe first and RTMPose second

MediaPipe is already Apache 2.0, so this sequencing is about accuracy, not
licensing. MediaPipe is turnkey on both platforms and gets the first version
shipped. It degrades in the two conditions that define a real gym: motion blur
through the release, and other players in frame.

RTMPose trained on basketball footage is the answer to both, and is the reason
the second version exists. If top-down cost becomes the constraint with several
players on court, RTMO is the one-stage alternative built for crowded scenes.

## What this obliges us to

The licence of the training data propagates to the weights. A research-only
dataset cannot produce weights we deploy commercially, whatever the model
licence says. Every dataset used for fine-tuning is recorded in this document
with its licence before training starts.

The OpenMMLab dependency chain (mmengine, mmcv) is version-pinned and its
upstream pace has slowed. Pin exact versions, keep the exported artefacts in
version control, and treat ONNX as the contract so the application is never
coupled to the training stack.

Detector choice is not what decides whether shot counting works. A ball at
three-point distance is ten to twenty-five pixels wide and motion-blurred
through the arc. That needs high input resolution or tiling, temporal
association rather than independent per-frame detection, and trajectory fitting
that rejects outliers. Budget the effort there, not on architecture comparison.

The rim does not move within a session. Detect it during calibration, lock it,
and stop paying for it every frame.

## On 3D

Monocular 3D lifting, whether MotionBERT or RTMW3D, introduces depth error
larger than the effects being measured. Elbow angle, release angle and knee
flexion do not survive it.

The supported approach is 2D pose combined with known court geometry and the
calibrated camera placement. That is already how the product reasons: metric
eligibility is a function of `CameraAngle`, so side placement measures release
angle and knee flexion, front measures alignment and elbow flare, rear measures
depth and entry angle, and diagonal reduces precision on every angle metric.
Reconsider 3D only for a two-camera or depth-sensor mode, where it is measured
rather than inferred.

## Consequences for this repository

Nothing under `lib/` changes today. The capture pipeline is simulated and the
model stack sits behind a contract that is already fixed:
`lib/data/metrics/metric_catalog.dart` defines what may be measured and from
which placements, and `lib/data/models/confidence.dart` requires every emitted
value to carry a confidence level that governs its precision and whether it may
drive coaching. Any model stack that satisfies that contract is substitutable;
this decision records which one we build first and why.
