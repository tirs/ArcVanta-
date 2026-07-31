import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The name of the phone that measured a session.
///
/// Stamped onto every stored session so a number can be traced to the hardware
/// that produced it: a solve from a three-year-old mid-range phone at 30 fps is
/// not the same evidence as one from a current flagship at 120, and the record
/// should not pretend otherwise.
///
/// Resolved once at startup and cached, because it cannot change while the app
/// is running and the session writer must not have to await it.
abstract final class DeviceIdentity {
  static String _name = 'This device';
  static String _appVersion = '';

  static String get name => _name;

  /// Version and build as the store published them, so a support report says
  /// what the user is actually running rather than what the source said when
  /// the string was last edited by hand.
  static String get appVersion => _appVersion;

  static Future<void> resolve() async {
    _name = await _read();
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version} (${info.buildNumber})';
    } catch (error) {
      debugPrint('Package info unavailable: $error');
    }
  }

  static Future<String> _read() async {
    final plugin = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final model = info.model.trim();
        final brand = info.manufacturer.trim();
        if (model.isEmpty) return 'Android device';
        // Some vendors already prefix the model with the brand, and "Google
        // Google Pixel 9" reads like a bug in the app rather than in the
        // device tables.
        return model.toLowerCase().startsWith(brand.toLowerCase())
            ? model
            : '${_capitalise(brand)} $model'.trim();
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        final model = info.utsname.machine.trim();
        return model.isEmpty ? info.model : model;
      }
    } catch (error) {
      debugPrint('Device identity unavailable: $error');
    }
    return 'This device';
  }

  static String _capitalise(String value) => value.isEmpty
      ? value
      : value[0].toUpperCase() + value.substring(1);
}
