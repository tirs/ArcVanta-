/// Attribution for things Flutter's licence page cannot discover by itself.
///
/// `showLicensePage` lists every Dart package, because pub packages declare
/// their licences and the framework collects them. It knows nothing about the
/// two ONNX graphs bundled as assets, the native runtime that executes them,
/// or the datasets those graphs were trained on — none of which are pub
/// packages, and all of which carry attribution obligations.
///
/// Registering them here puts them in the same list the user already has a
/// link to, rather than inventing a second screen that says licence on it.
library;

import 'package:flutter/foundation.dart';

const _apacheSummary = '''
Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.
''';

const _openMMLab = '''
Copyright (c) OpenMMLab. All rights reserved.

ArcVanta AI bundles two neural networks exported from the OpenMMLab toolchain:

  RTMDet-m, for detecting people, the ball and the rim.
  RTMPose-m, for locating seventeen body landmarks.

Both were produced with MMDetection, MMPose, MMEngine and MMCV.

  Lyu et al., "RTMDet: An Empirical Study of Designing Real-Time Object
  Detectors", arXiv:2212.07784, 2022.

  Jiang et al., "RTMPose: Real-Time Multi-Person Pose Estimation based on
  MMPose", arXiv:2303.07399, 2023.

$_apacheSummary''';

const _onnxRuntime = '''
Copyright (c) Microsoft Corporation. All rights reserved.

ONNX Runtime executes the bundled graphs on the device. Distributed under the
MIT License.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

/// Datasets get their own entry because a model's behaviour is inherited from
/// what it was shown, and because several of these licences ask to be named.
const _trainingData = '''
The bundled networks learned from the following datasets. Their authors are
credited here as their licences require, and because the limits of a model are
the limits of the data behind it.

COCO — Common Objects in Context
  Lin et al., "Microsoft COCO: Common Objects in Context", ECCV 2014.
  Annotations (c) the COCO Consortium, licensed CC BY 4.0.
  https://creativecommons.org/licenses/by/4.0/
  Images are from Flickr and remain under their photographers' own terms.

AI Challenger — Human Keypoint Detection
  Wu et al., "Large-scale Datasets for Going Deeper in Image Understanding",
  ICME 2019. (c) Sinovation Ventures.

ImageNet
  Deng et al., "ImageNet: A Large-Scale Hierarchical Image Database", CVPR
  2009. Used for the backbone both networks start from.
''';

/// Call once during startup, before the first frame.
void registerModelNotices() {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['RTMDet and RTMPose (OpenMMLab)'],
      _openMMLab,
    );
    yield const LicenseEntryWithLineBreaks(['ONNX Runtime'], _onnxRuntime);
    yield const LicenseEntryWithLineBreaks(
      ['Model training data'],
      _trainingData,
    );
  });
}
