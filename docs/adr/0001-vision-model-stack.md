# 1. Vision model stack

Accepted, 29 July 2026.

## Decision

| Stage | Choice | Licence |
| --- | --- | --- |
| Object detection (ball, rim, players) | RTMDet, from MMDetection | Apache 2.0 |
| Pose | Basketball-trained RTMPose, from MMPose | Apache 2.0 |

Ultralytics YOLO is rejected. Monocular 3D pose is rejected for the
single-camera product.

Amended 29 July 2026: MediaPipe is no longer the first-version pose model. The
staging existed to get something shipped before a fine-tune existed, and it
bought that at the cost of two preprocessing paths, two landmark topologies and
two sets of accuracy characteristics to reason about. Since both bridges load
ONNX through the same runtime, carrying RTMPose from the start is less work
than carrying both, and it means the numbers never change underneath a user
when the second version lands.

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

## Why RTMPose

MediaPipe is also Apache 2.0, so this is about accuracy, not licensing. It is
turnkey on both platforms, and it degrades in the two conditions that define a
real gym: motion blur through the release, and other players in frame. Those
are not edge cases here; the release is the single frame every arc metric is
taken from.

RTMPose fine-tuned on basketball footage answers both. It is top-down, so it
costs one pose inference per person rather than one per frame, which is the
right trade when the product only ever measures one shooter. If several players
on court makes that cost bite, RTMO is the one-stage alternative built for
crowded scenes and it fits the same contract.

## Upstream status, checked 29 July 2026

The MMPose repository confirms the Apache 2.0 licence, and also that the
project is effectively frozen. The newest entry in its release notes is v1.3.0,
dated 4 January 2024. The main branch still advertises PyTorch 1.8 as its
floor, and there are around three hundred open issues. That is two and a half
years without a release.

RTMPose, RTMO, RTMPose3D and RTMW3D all live under `projects/` rather than in
the core tree, so they carry weaker API stability guarantees than core MMPose
even within a single version.

This does not change the decision. Apache 2.0 weights that we export once and
ship do not need an actively developed trainer. It does change how we depend on
it: MMPose and MMDetection are frozen, training-time tools, pinned and vendored,
never a runtime dependency of anything we ship.

## What this obliges us to

Every dataset used for fine-tuning is recorded in this document with its
licence before training starts.

### Amended 30 July 2026: the pretrained weights carry research-only data

This document originally said that a research-only dataset cannot produce
weights we deploy commercially. Auditing the actual checkpoints showed that
rule would disqualify the entire OpenMMLab pose model zoo, so it has been
weighed rather than applied.

What the audit found, read out of the checkpoints' own embedded configs rather
than from documentation:

| Checkpoint | Trained on | Commercial use |
| --- | --- | --- |
| `rtmdet_m_8xb32-300e_coco` | COCO | Annotations CC-BY-4.0; images are Flickr, mixed |
| `rtmpose-m_simcc-aic-coco_pt-aic-coco` | COCO + AI Challenger | AI Challenger is research-only |
| `rtmw3d-x_cocktail14` | 14 sets incl. Human3.6M, UBody, InterHand, MPII | Several explicitly non-commercial |

There is no published RTMPose-m checkpoint free of this: the `body7` variant
also includes AI Challenger, `ucoco` uses UBody, and `coco-wholebody` is
pretrained from `aic-coco`. Training our own on a licence-filtered COCO subset
was costed and is feasible — roughly 60% of COCO survives the filter — but was
not chosen.

**Decision: ship the published OpenMMLab weights, with attribution.** The
reasoning is that OpenMMLab distributes its model zoo under Apache-2.0, that
whether trained weights are a derivative work of their training data is legally
unsettled and unlitigated, and that the industry ships ImageNet-derived weights
on the same basis. That last point is not rhetorical: the CSPNeXt backbone
under both models is ImageNet-pretrained, and ImageNet's own terms are
research-only, so no realistic option cuts every strand.

This is a judgement about an unsettled question, not a finding that there is no
question. It should be reviewed by a lawyer before the app is sold, and the
route back is cheap: training on filtered COCO changes only the weights, not
the contract, the graphs or either native bridge.

RTMW3D is excluded on separate grounds — see "On 3D" — so the Human3.6M and
UBody exposure in that row is not taken on.

Pin the whole OpenMMLab chain. Exact versions come from the `requirements/`
directory of the pinned MMPose and MMDetection checkouts, not from whatever pip
resolves; mmcv in particular needs a prebuilt wheel matching the exact PyTorch
and CUDA build, which is the usual point of failure. Keep the training
environment in a Dockerfile so it survives its own dependencies ageing.

Treat ONNX as the contract. Exported artefacts are versioned and the
application is coupled to them, never to the training stack. That is what makes
a frozen upstream acceptable, and what lets the model be replaced later without
touching the app.

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

RTMW3D-X was evaluated directly on 30 July 2026 and rejected. Its own authors
put a person's nose-to-ankle span anywhere between 1.5 and 3.0 metres depending
on camera distance, which is a two-fold scale ambiguity in exactly the quantity
release height depends on. The court solve already supplies real metric scale
from the rim ellipse and the known 3.048 m ring height, so 3D lifting would
replace a measurement with a guess. It is also 92.4M parameters and 370 MB
against 13.6M and 54 MB for RTMPose-m, and spends 110 of its 133 keypoints on
faces and hands.

The supported approach is 2D pose combined with known court geometry and the
calibrated camera placement. That is already how the product reasons: metric
eligibility is a function of `CameraAngle`, so side placement measures release
angle and knee flexion, front measures alignment and elbow flare, rear measures
depth and entry angle, and diagonal reduces precision on every angle metric.
Reconsider 3D only for a two-camera or depth-sensor mode, where it is measured
rather than inferred.

## Consequences for this repository

The contract this decision anticipated is now written down and enforced.
`vision/contract/model_contract.json` fixes tensor names, shapes, normalisation
and class ids; `tool/vision/verify_contract.py` rejects any export that does not
satisfy it; and both native bridges re-check the loaded graph against their
mirror of it before the first frame runs. The pins live in `vision/pins.lock`
and `tool/vision/setup.sh` refuses to advance a vendored checkout that has
drifted off one.

The older constraints still hold. `lib/data/metrics/metric_catalog.dart`
defines what may be measured from which placements, and
`lib/data/models/confidence.dart` requires every emitted value to carry a
confidence level governing its precision and whether it may drive coaching. Any
model stack satisfying both contracts is substitutable.

What runs without the models is deliberate rather than incidental. The bridge
reports `modelsMissing`, `lib/state/capture_pipeline.dart` falls back to the
simulated source, and the interface says on screen that the session is
simulated. The geometry is solved for real either way, against a synthetic
scene, so `CalibrationSolver` and `ShotTracker` are exercised on every run and
in CI rather than only on a device.

Rim detection is per frame during calibration and locked afterwards, as this
document required. `CalibrationController` requires a run of consistent solves
before it will hand a court frame to a session, so a ring caught in a blur or
during the second a tripod is still settling cannot become the reference every
later measurement is taken against.
