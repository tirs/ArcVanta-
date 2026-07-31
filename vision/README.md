# The vision pipeline

Two models do the seeing. RTMDet finds the shooter, the ball, the ring and the
backboard; RTMPose puts seventeen landmarks on the shooter. Everything the app
reports as a number is derived from those two outputs plus the court geometry
solved from the ring.

Both are Apache 2.0, which is why they were chosen over the alternatives.

## The shape of it

```
vision/pins.lock                    commits and versions, the recipe
vision/configs/*.py                 what to train
vision/contract/model_contract.json what the app is allowed to assume
tool/vision/setup.sh                build the training environment
tool/vision/export_onnx.py          .pth -> .onnx
tool/vision/verify_contract.py      the gate
tool/vision/fetch_models.sh         put the graphs on a device
```

## Why the training tools are vendored and pinned

MMPose has had no release since January 2024, and RTMPose lives under
`projects/`, which upstream holds to a weaker API-stability bar than the main
package. `pip install mmpose` today and the same command in six months are not
guaranteed to be the same software, and the difference would not show up as a
crash. It would show up as landmarks in slightly different places, which is to
say as a different measured elbow angle for the same shot.

So `pins.lock` records commits rather than versions, `setup.sh` refuses to
advance a checkout that has drifted, and `export_onnx.py` re-checks before it
writes anything.

None of it is a runtime dependency. The app never imports mmpose, mmdet, mmcv
or torch. These tools run once on a workstation and produce two `.onnx` files;
those files are what ships. If upstream were archived tomorrow, nothing already
built would stop working. The full reasoning is in
[docs/adr/0001-vision-model-stack.md](../docs/adr/0001-vision-model-stack.md).

## The contract is the interface

`vision/contract/model_contract.json` is the source of truth for tensor names,
shapes, normalisation constants, class ids and the SimCC decode. Four things
mirror it and none of them may disagree:

| Mirror | Used by |
| --- | --- |
| `lib/data/capture/model_contract.dart` | the Dart pipeline |
| `android/.../vision/ModelContract.kt` | the Android bridge |
| `ios/Runner/Vision/ModelContract.swift` | the iOS bridge |
| `tool/vision/export_onnx.py` | the exporter |

Both native bridges check the loaded graph against their mirror before the
first frame runs, and refuse to start if it does not match. That check is worth
the startup cost because the failure it catches is silent: a pose model at the
wrong input size still returns seventeen plausible landmarks, in the wrong
places, and the first sign of the problem is a coach disputing a release angle.

## Running it

```bash
tool/vision/setup.sh                 # once, ~20 minutes, mmcv builds from source
source vision/.venv/bin/activate

# Train, then export. Either half can be done alone.
python tool/vision/export_onnx.py \
    --detector-checkpoint work/rtmdet_m_arcvanta.pth \
    --pose-checkpoint work/rtmpose_m_arcvanta.pth \
    --out build/vision

tool/vision/fetch_models.sh --from build/vision --android
```

`export_onnx.py` runs the verifier itself and refuses to record a digest for a
graph that fails it.

## The gate

```bash
python tool/vision/verify_contract.py --dir build/vision --run
```

Structural checks need only `onnx`. `--run` additionally executes both graphs
on a fixed synthetic input, which is the only way to catch an export that is
shaped correctly and computes nothing — a dead SimCC head returns a flat
distribution, every landmark argmaxes to index zero, and the result looks like
a person standing in the top-left corner of every frame.

The verifier has its own tests, which build graphs designed to pass and to
fail:

```bash
python tool/vision/test_verify_contract.py
```

The verifier reports each graph's sha256 but never asserts on it. Whether a
file matches what was published is a provenance question, and
`fetch_models.sh` is where it is asked; checking it here as well would make
every re-export fail against the digest of the export before it.

## Is it any good

Passing the contract means a graph is shaped right and computes something.
It does not mean the numbers are correct, and for a measurement product that
gap is the whole risk: a pose model that is subtly wrong still returns
seventeen plausible landmarks and still draws a convincing skeleton.

```bash
python tool/vision/validate_pose.py \
    --model build/vision/arcvanta_rtmpose_m_256x192.onnx \
    --coco vision/.vendor/mmpose/tests/data/coco
```

It scores predicted landmarks against labelled ones, over the twelve body
joints the product actually measures, and reports PCK plus the error
distribution. The face keypoints are excluded on purpose: they are the easiest
five in the set and nothing is derived from them.

The current export of stock RTMPose-m scores:

| Measure | Value |
| --- | --- |
| PCK@0.05 | 91.9% |
| Median error | 3.7 px |
| 90th percentile | 9.4 px |

That is a COCO baseline on COCO images. It is the floor, not the target: a
shooter at the top of a jump shot is the tail of that distribution, which is
what `rtmpose_m_arcvanta.py` exists to fine-tune. Re-run this after any
retrain, and against basketball footage once there is a labelled set of it.

Preprocessing and the SimCC decode are implemented in the validator from the
contract rather than borrowed from mmpose, so it doubles as the reference the
Kotlin and Swift implementations can be checked against.

## Without the models

The `.onnx` files are not in git; they are large binaries that change whenever
the models are retrained. A build without them is not broken. The native bridge
reports `modelsMissing`, `lib/state/capture_pipeline.dart` falls back to the
simulated source, and the app labels every number as simulated. That is a
working app with honest numbers rather than a crash, and it is what runs in CI
and on the golden tests.
