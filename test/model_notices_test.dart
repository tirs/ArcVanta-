import 'package:arcvanta/features/legal/model_notices.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// The attribution is the whole basis on which the bundled weights are shipped,
/// and it lives in a file nothing else imports. Without a test, deleting it
/// breaks no build and fails no screen — it just quietly stops crediting
/// anyone.
void main() {
  test('the model and dataset notices reach the licence page', () async {
    registerModelNotices();

    final entries = await LicenseRegistry.licenses.toList();
    final packages = [for (final entry in entries) ...entry.packages];

    expect(packages, contains('RTMDet and RTMPose (OpenMMLab)'));
    expect(packages, contains('ONNX Runtime'));
    expect(packages, contains('Model training data'));
  });

  test('each notice names its licence and its authors', () async {
    registerModelNotices();

    final text = {
      for (final entry in await LicenseRegistry.licenses.toList())
        for (final package in entry.packages)
          package: entry.paragraphs.map((p) => p.text).join(' '),
    };

    expect(text['RTMDet and RTMPose (OpenMMLab)'], contains('OpenMMLab'));
    expect(text['RTMDet and RTMPose (OpenMMLab)'], contains('Apache License'));
    expect(text['ONNX Runtime'], contains('MIT License'));

    // CC BY 4.0 obliges us to name the source; the others are cited because a
    // model cannot be understood apart from what it was trained on.
    expect(text['Model training data'], contains('COCO Consortium'));
    expect(text['Model training data'], contains('CC BY 4.0'));
    expect(text['Model training data'], contains('AI Challenger'));
    expect(text['Model training data'], contains('ImageNet'));
  });
}
