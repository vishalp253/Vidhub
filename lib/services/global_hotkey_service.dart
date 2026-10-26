import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

/// Registers the system-wide Ctrl+Shift+T shortcut that opens quick-add.
class GlobalHotkeyService {
  /// Returns false when another app already owns the shortcut (or the
  /// registration fails), so the UI can say so instead of failing silently.
  Future<bool> register({required VoidCallback onQuickAdd}) async {
    try {
      await hotKeyManager.unregisterAll();
      final quickAdd = HotKey(
        key: PhysicalKeyboardKey.keyT,
        modifiers: [HotKeyModifier.control, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      );
      await hotKeyManager.register(
        quickAdd,
        keyDownHandler: (_) => onQuickAdd(),
      );
      return true;
    } catch (e) {
      debugPrint('VidHub: could not register Ctrl+Shift+T: $e');
      return false;
    }
  }

  Future<void> dispose() async {
    try {
      await hotKeyManager.unregisterAll();
    } catch (_) {
      // Shutting down anyway.
    }
  }
}
