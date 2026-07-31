import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/platform/device_identity.dart';
import 'data/store/repository.dart';
import 'features/legal/model_notices.dart';
import 'state/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  registerModelNotices();

  // The database opens before the first frame so no screen has to render a
  // loading state over the user's own history. A season of sessions is a
  // handful of milliseconds to read; the splash covers it either way.
  await DeviceIdentity.resolve();

  final repository = await ArcVantaRepository.open();
  final snapshot = await AppSnapshot.load(repository);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: SystemUiOverlay.values,
  );

  runApp(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        appSnapshotProvider.overrideWithValue(snapshot),
      ],
      child: const ArcVantaApp(),
    ),
  );
}
