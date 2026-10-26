import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'models/seed_data.dart';
import 'providers/app_providers.dart';
import 'services/global_hotkey_service.dart';
import 'services/storage_service.dart';
import 'services/tray_service.dart';
import 'services/window_service.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isWindows) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('VidHub runs on Windows. Use: flutter run -d windows')),
        ),
      ),
    );
    return;
  }

  // `taskpulse.exe --tray` starts VidHub straight into the tray (handy for startup).
  final startHidden = args.contains('--tray');

  // 1. Load (or create) the data file.
  final dir = await getApplicationSupportDirectory();
  final legacyData = File('${dir.path}${Platform.pathSeparator}taskpulse.json');
  final dataFile = File('${dir.path}${Platform.pathSeparator}vidhub.json');
  // Preserve existing user data when moving from TaskPulse to VidHub.
  if (!await dataFile.exists() && await legacyData.exists()) {
    await legacyData.copy(dataFile.path);
  }
  final storage = StorageService(
    dataFile,
    onError: (e) => debugPrint('VidHub storage: $e'),
  );
  final loaded = await storage.load();
  final data = loaded.withSeed(builtInRoutines()).pruned(DateTime.now());
  await storage.save(data);

  // 2. Native window.
  final windowService = WindowService();
  await windowService.init(startHidden: startHidden);

  // 3. Wire everything together.
  final tray = TrayService();
  final hotkeys = GlobalHotkeyService();
  late final ProviderContainer container;

  Future<void> quit() async {
    container.read(schedulerRunnerProvider).stop();
    await hotkeys.dispose();
    await tray.dispose();
    await windowService.quit();
  }

  container = ProviderContainer(
    overrides: [
      initialDataProvider.overrideWithValue(data),
      storageProvider.overrideWithValue(storage),
      windowServiceProvider.overrideWithValue(windowService),
      initialWindowModeProvider.overrideWithValue(startHidden ? WindowMode.hidden : WindowMode.manager),
      quitProvider.overrideWithValue(quit),
    ],
  );

  final mode = container.read(windowModeProvider.notifier);
  windowService.onCloseRequested = mode.closeTransient;
  windowService.onBlur = mode.handleBlur;

  await tray.init(
    onOpen: mode.openManager,
    onQuickAdd: mode.openQuickAdd,
    onQuit: quit,
  );

  final hotkeyOk = await hotkeys.register(onQuickAdd: mode.openQuickAdd);
  container.read(hotkeyStatusProvider.notifier).set(hotkeyOk);

  // 4. Start the clock that fires alerts.
  container.read(schedulerRunnerProvider).start();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const VidHubApp(),
    ),
  );
}
