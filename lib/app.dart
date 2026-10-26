import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/app_providers.dart';
import 'services/window_service.dart';
import 'ui/manager_view.dart';
import 'ui/quick_add_view.dart';
import 'ui/sticky_overlay_widget.dart';
import 'ui/theme.dart';

/// One MaterialApp, four faces. Which one shows depends on the window mode.
class VidHubApp extends ConsumerWidget {
  const VidHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(windowModeProvider);

    return MaterialApp(
      title: 'VidHub',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        backgroundColor: TP.bg,
        body: switch (mode) {
          WindowMode.hidden => const SizedBox.shrink(),
          WindowMode.manager => const ManagerView(),
          WindowMode.overlay => const StickyOverlayView(),
          WindowMode.quickAdd => const QuickAddView(),
        },
      ),
    );
  }
}
