# What is verified, and what is not

Last checked 30 July 2026, on Linux with an Android emulator (Pixel 9a, API 36),
an RTX 5080 for training, and no macOS machine available.

This file exists because the capture pipeline spans four languages and two
platforms, and "it builds" is a much weaker claim than it sounds. Anything
below the line has been written but not executed, and should be treated as a
first draft until someone runs it.

## Verified by running it

| What | How |
| --- | --- |
| Dart analyzer | `flutter analyze`, no issues |
| Dart test suite | `flutter test`, 754 passing |
| Calibration geometry | Unit tests over synthetic scenes with known answers: eigensolve, conic fit, rim pose, court frame, solver scoring |
| Shot segmentation | `ShotTracker` tests drive made, missed, short, left and right shots plus dribbling, from generated detection frames |
| Calibration controller | 16 tests covering settling, blocked scenes, camera movement mid-run, and refusing to commit a partial solve |
| Wire protocol decode | `NativeCaptureSource` tests feed payloads through the platform channel codec |
| Contract verifier | `tool/vision/test_verify_contract.py`, 10 cases, building ONNX graphs designed to pass and to fail |
| Android build | `flutter build apk --debug` and `flutter build apk --release` |
| Android Kotlin compiles | `VisionEngine`, `CaptureBridge`, `RimEllipse`, `ModelContract` all present in `build/app/tmp/kotlin-classes` |
| 16 KB page alignment | Every bundled `.so` reports `0x4000` or wider under `readelf -lW`. This is a Play Store requirement, and ONNX Runtime 1.20 failed it; 1.22 is the reason for the version floor |
| Fallback to simulation | On device, with camera permission never granted, the calibration screen reports "Simulated capture" and still solves the geometry |
| Calibration end to end | On device: press calibrate, watch it settle frame by frame, read a real quality report (court plane 100, rim reference 59, lighting 84, stability 94, framing 83) and start a session from it |
| Layout under stress | Every screen mounted at seven viewports from 320x568 to 852x393, at text scales 1.0, 1.3 and 1.6, with overflow treated as a test failure |
| Detector training | RTMDet-m fine-tuned to the four contract classes, 60 epochs on an RTX 5080 |
| Detector export | `tool/vision/export_onnx.py` produces a graph the contract verifier accepts: static `[1,100,5]` and `[1,100]`, float32, one `NonMaxSuppression` node |
| Export matches the model | `tool/vision/validate_detector.py`: over 160 detections, median *and* minimum box IoU 1.0000, zero centre error, zero score error (fp32 graph) |
| Quantised models | Both graphs quantised to uint8 dynamic: detector 105 MB to 28 MB, pose 52 MB to 14 MB. Quantised detector validates at median IoU 0.88, median 2.8 px centre error |
| Models bundled | Both `.onnx` graphs are in `android/app/src/main/assets/` and `ios/Runner/Models/`. APK verified with `unzip -l` |
| Model loading | Android `VisionEngine.create` extracts from APK assets on first run. iOS `VisionEngine.create` resolves from Bundle.main, falling back to Application Support for OTA |
| Release signing | `flutter build apk --release` refuses to run without a keystore, and the signed APK verifies (136.7 MB with all ABIs) |
| Attribution | `registerModelNotices()` places OpenMMLab, ONNX Runtime, and dataset attributions into Flutter's licence page. `test/model_notices_test.dart` verifies they appear |

## What the detector actually scores

Trained on E-BARD, the only basketball detection set with a usable licence.
Held-out test split, 180 images:

| Class | mAP | mAP@50 | mAP@75 |
| --- | --- | --- | --- |
| person | 0.782 | 0.976 | 0.889 |
| ball | 0.348 | 0.698 | 0.300 |
| rim | 0.580 | 0.936 | 0.701 |
| backboard | — | — | — |

Those numbers describe broadcast footage, which is what the data is, and not
what the app points a camera at. On eighteen held-out close-range photographs
at roughly the app's framing, the rim is found in ten with a median confidence
of 0.81, and the ball in three.

The model ships as-is because it is the best available from open data, and
the pipeline works end to end when it fires. Better training data will
improve these numbers without changing a line of the app or the contract.

## Written but needs on-device verification

**The iOS bridge.** `ios/Runner/Vision/*.swift` has never been compiled on
macOS. The Xcode project has all five Swift sources in the Sources build
phase, both ONNX models in the Resources build phase under a Models group,
and the Podfile pins `onnxruntime-objc` 1.22.0. The user will do the first
Xcode build.

**CameraX on real hardware.** The Android bridge builds and its channels
answer, but no frame has been through it on a real camera. Untested: the RGBA
row-stride conversion against a device whose stride is not the width, the
intrinsics read from `LENS_INFO_AVAILABLE_FOCAL_LENGTHS`, and whether frames
keep up at all once two models are running per frame.

**Sensor conventions.** `RimEllipse.rollFromGravity` and the iOS gravity
scaling assume image `y` runs down and that the two platforms can be made to
agree on sign. That is written to be true and has not been observed to be true.
A sign error here rotates the solved rim ellipse and quietly tilts the court
plane.

## Decoder history

**The decode was wrong twice, and both would have shipped quietly.** This is
recorded because the failure mode is the point, not the fix.

`DetectorForExport` reimplements RTMDet's anchor decode rather than calling
into mmdeploy, and it placed anchor points at the centre of each cell. RTMDet
puts them at the corner — `MlvlPointGenerator(offset=0)`. Every box from the
coarsest level moved sixteen pixels diagonally, scores were untouched, and the
result looked like a working detector that could not quite find the rim. The
offset is now read off the model.

Separately, the contract said the detector wanted RGB. It wants BGR: mmdet's
RTMDet config sets `bgr_to_rgb=False`, and the mean and std are listed in that
order. The pose model is the opposite, so the two graphs genuinely disagree and
both bridges had been feeding the detector a swap it was never trained for.
Alongside it, both bridges centred the letterbox padding where mmdet leaves the
image in the top-left corner.

None of the three was caught by the contract verifier, because all three
produce a perfectly well-shaped graph. What caught them was comparing the
graph's output against the model's, which is now
`tool/vision/validate_detector.py` and should be run after any export.

## Known limits, by design

These are not gaps to close; they are decisions to know about.

**Rim height is assumed, never measured.** Every height comes from the
regulation 3.048 m. On an adjustable hoop set lower, release and apex heights
read high by the difference. The calibration screen says so on screen rather
than hiding it, and `CalibrationSolution.rimHeightAssumed` carries the flag.

**The rim ellipse comes from a detection box.** A box bounds the ring but
cannot express its rotation, so the roll measured from gravity is used as the
ellipse orientation. That holds for a phone on a tripod. A segmentation mask
would remove the assumption, and the contract has room for one.

This also assumes the box bounds the *ring*. The model trained above bounds the
ring and the net together, which is the single largest reason to collect better
data; whoever labels the next dataset should treat "rim means the ring
only" as a requirement rather than a preference.

**Thermal headroom is inferred from frame rate**, not read from a thermal API,
because what a measurement cares about is whether frames arrive fast enough to
catch a release.

## Reproducing the device check

```bash
flutter emulators --launch Pixel_9a
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell pm clear ai.arcvanta.arcvanta
adb shell am start -n ai.arcvanta.arcvanta/.MainActivity
```

Skip onboarding, continue as guest, pick an adult age band, start a session,
continue to calibration, press "Calibrate court". It should settle within about
a second and report a quality score in the low eighties against the simulated
scene.

## Reproducing the detector work

Training needs a second environment: mmcv has to be built against a torch new
enough for the GPU, and the export environment is pinned to an older one so the
graph stays reproducible. They share the vendored config tree, which is why
`vision/configs/rtmdet_m_arcvanta.py` reads its base config by path rather than
through mmdet's `mmdet::` scheme.

```bash
# Dataset into the four contract classes.
python tool/vision/prepare_detection_data.py \
    --source  work/datasets/ebard/coco/annotations/instances_train.json \
    --destination work/datasets/arcvanta-det/annotations/train.json

# Fine-tune. TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD is needed because mmengine
# 0.10.5 predates torch 2.6 flipping torch.load's default.
TORCH_FORCE_NO_WEIGHTS_ONLY_LOAD=1 python tools/train.py \
    vision/configs/rtmdet_m_arcvanta.py --work-dir work/train/rtmdet_m_arcvanta

# Export through the pinned toolchain, then check the graph against the model.
vision/.venv/bin/python tool/vision/export_onnx.py \
    --detector-checkpoint work/train/rtmdet_m_arcvanta/best_coco_bbox_mAP_epoch_58.pth
vision/.venv/bin/python tool/vision/validate_detector.py \
    --onnx build/vision/arcvanta_rtmdet_m_640.onnx \
    --config vision/configs/rtmdet_m_arcvanta.py \
    --checkpoint work/train/rtmdet_m_arcvanta/best_coco_bbox_mAP_epoch_58.pth \
    --images work/datasets/arcvanta-det/images_test

# Quantise for shipping.
python -c "
from onnxruntime.quantization import quantize_dynamic, QuantType
quantize_dynamic('build/vision/arcvanta_rtmdet_m_640.onnx', 'build/vision/quantised/arcvanta_rtmdet_m_640.onnx', weight_type=QuantType.QUInt8)
quantize_dynamic('build/vision/arcvanta_rtmpose_m_256x192.onnx', 'build/vision/quantised/arcvanta_rtmpose_m_256x192.onnx', weight_type=QuantType.QUInt8)
"

# And how it behaves at the distance the app actually shoots from.
vision/.venv/bin/python tool/vision/eval_closerange.py ... --images work/datasets/closerange
```
