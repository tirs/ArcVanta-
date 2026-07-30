// Renders every launcher icon from the brand mark in lib/design/brand.
//
// Run with:  flutter test tool/generate_app_icon.dart
//
// It lives outside test/ so the normal suite does not rewrite platform assets,
// and it runs under `flutter test` because that is what gives a plain script
// access to a dart:ui rasteriser. Each size is drawn at its own resolution
// rather than downsampled from one master, which keeps the arc cap and the
// ball seam crisp at 48 px.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:arcvanta/design/brand/app_icon_art.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _androidRes = 'android/app/src/main/res';
const _iosIcons = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

/// Density buckets, as a multiple of the baseline dp size.
const _densities = <String, double>{
  'mdpi': 1,
  'hdpi': 1.5,
  'xhdpi': 2,
  'xxhdpi': 3,
  'xxxhdpi': 4,
};

/// Every iOS slot Flutter's default asset catalogue declares.
const _iosSizes = <String, int>{
  'Icon-App-20x20@1x': 20,
  'Icon-App-20x20@2x': 40,
  'Icon-App-20x20@3x': 60,
  'Icon-App-29x29@1x': 29,
  'Icon-App-29x29@2x': 58,
  'Icon-App-29x29@3x': 87,
  'Icon-App-40x40@1x': 40,
  'Icon-App-40x40@2x': 80,
  'Icon-App-40x40@3x': 120,
  'Icon-App-60x60@2x': 120,
  'Icon-App-60x60@3x': 180,
  'Icon-App-76x76@1x': 76,
  'Icon-App-76x76@2x': 152,
  'Icon-App-83.5x83.5@2x': 167,
  'Icon-App-1024x1024@1x': 1024,
};

void main() {
  test('generate launcher icons', () async {
    // iOS draws its own rounded mask and App Store Connect rejects an icon
    // that carries an alpha channel at all, so these stay square, full bleed
    // and are re-encoded without alpha.
    for (final entry in _iosSizes.entries) {
      await _write('$_iosIcons/${entry.key}.png', entry.value, (canvas, size) {
        AvIconArt.paintBackground(canvas, size);
        AvIconArt.paintMarkInset(canvas, size, 0.66);
      }, opaque: true);
    }

    for (final density in _densities.entries) {
      final dir = '$_androidRes/mipmap-${density.key}';

      // Pre-Oreo launchers show this bitmap as-is, so it carries its own
      // rounded corners.
      final legacy = (48 * density.value).round();
      await _write('$dir/ic_launcher.png', legacy, (canvas, size) {
        canvas.clipRRect(
          ui.RRect.fromRectAndRadius(
            ui.Offset.zero & size,
            ui.Radius.circular(size.width * 0.22),
          ),
        );
        AvIconArt.paintBackground(canvas, size);
        AvIconArt.paintMarkInset(canvas, size, 0.66);
      });

      // Adaptive layers are 108dp and get masked to whatever shape the
      // launcher prefers, so the mark sits inside the 66dp safe circle.
      final adaptive = (108 * density.value).round();
      await _write('$dir/ic_launcher_background.png', adaptive, (canvas, size) {
        AvIconArt.paintBackground(canvas, size);
      });
      await _write('$dir/ic_launcher_foreground.png', adaptive, (canvas, size) {
        AvIconArt.paintMarkInset(canvas, size, 0.47);
      });
      await _write('$dir/ic_launcher_monochrome.png', adaptive, (canvas, size) {
        AvIconArt.paintMarkInset(canvas, size, 0.47, monochrome: true);
      });
    }

    // A review sheet, so the icon can be checked without installing.
    await _write('docs/brand/app-icon.png', 512, (canvas, size) {
      AvIconArt.paintBackground(canvas, size);
      AvIconArt.paintMarkInset(canvas, size, 0.66);
    });
  });
}

Future<void> _write(
  String path,
  int pixels,
  void Function(ui.Canvas canvas, ui.Size size) paint, {
  bool opaque = false,
}) async {
  final recorder = ui.PictureRecorder();
  final size = ui.Size(pixels.toDouble(), pixels.toDouble());
  paint(ui.Canvas(recorder), size);

  final image = await recorder.endRecording().toImage(pixels, pixels);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (data == null) fail('Could not rasterise $path');

  final decoded = img.Image.fromBytes(
    width: pixels,
    height: pixels,
    bytes: data.buffer,
    numChannels: 4,
  );

  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(
    img.encodePng(opaque ? decoded.convert(numChannels: 3) : decoded),
  );
}
