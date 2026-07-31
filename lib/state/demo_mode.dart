import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo/demo_data.dart';
import '../data/store/repository.dart';
import 'app_settings.dart';
import 'bootstrap.dart';
import 'stores.dart';

/// Loads and unloads the sample history.
///
/// Writing the demo into the same tables as real sessions, rather than keeping
/// it in a parallel in-memory list, is what makes the feature safe: the
/// `is_demo` column travels with every row, so turning it off is a delete that
/// provably cannot touch anything the user shot.
class DemoModeController {
  const DemoModeController(this._ref);

  final Ref _ref;

  ArcVantaRepository get _repository => _ref.read(repositoryProvider);

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _repository.saveSessions(DemoData.sessions);
    } else {
      await _repository.deleteDemoSessions();
    }

    _ref.read(appSettingsProvider.notifier).update(
          (current) => current.copyWith(demoDataEnabled: enabled),
        );

    // The session store is seeded from the launch snapshot, so it has to be
    // told what changed underneath it rather than left to re-read on restart.
    await _ref.read(sessionStoreProvider.notifier).reload(
          includeDemo: enabled,
        );
  }
}

final demoModeProvider = Provider<DemoModeController>(
  DemoModeController.new,
);
