import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';

/// Notification-area icon with a small menu. Left click opens the app.
class TrayService {
  final SystemTray _tray = SystemTray();

  Future<void> init({
    required VoidCallback onOpen,
    required VoidCallback onQuickAdd,
    required Future<void> Function() onQuit,
  }) async {
    try {
      await _tray.initSystemTray(
        iconPath: 'assets/icons/tray.ico',
        toolTip: 'VidHub',
      );

      final menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(label: 'Open VidHub', onClicked: (_) => onOpen()),
        MenuItemLabel(label: 'Quick add   Ctrl+Shift+T', onClicked: (_) => onQuickAdd()),
        MenuSeparator(),
        MenuItemLabel(label: 'Quit', onClicked: (_) => onQuit()),
      ]);
      await _tray.setContextMenu(menu);

      _tray.registerSystemTrayEventHandler((event) {
        if (event == kSystemTrayEventClick || event == kSystemTrayEventDoubleClick) {
          onOpen();
        } else if (event == kSystemTrayEventRightClick) {
          _tray.popUpContextMenu();
        }
      });
    } catch (e) {
      // The app still works without a tray icon; the hotkey and alerts do not need it.
      debugPrint('VidHub: tray icon failed: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _tray.destroy();
    } catch (_) {
      // Shutting down anyway.
    }
  }
}
