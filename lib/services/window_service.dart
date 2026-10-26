import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// The single native window plays four roles. Only one is active at a time.
enum WindowMode {
  /// Nothing visible; the app lives in the tray.
  hidden,

  /// The full app: today, tasks, routines.
  manager,

  /// Small always-on-top alert card in the bottom-right corner.
  overlay,

  /// Tiny centred input opened by Ctrl+Shift+T.
  quickAdd,
}

/// Thin wrapper over `window_manager`. It only does native window work; the
/// decisions about which mode to be in live in `WindowModeController`.
class WindowService with WindowListener {
  static const Size managerSize = Size(1040, 700);
  static const Size managerMin = Size(880, 580);
  static const Size overlaySize = Size(392, 292);
  static const Size quickAddSize = Size(560, 132);
  static const Size _tiny = Size(100, 100);

  /// The user pressed the window's close button (or Alt+F4). We never really
  /// close; the controller decides what to show instead.
  void Function()? onCloseRequested;

  /// The window lost keyboard focus.
  void Function()? onBlur;

  Future<void> init({required bool startHidden}) async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    const options = WindowOptions(
      size: managerSize,
      minimumSize: managerMin,
      center: true,
      backgroundColor: Color(0xFF0E1014),
      skipTaskbar: false,
      title: 'VidHub',
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      if (startHidden) {
        await windowManager.hide();
      } else {
        await windowManager.show();
        await windowManager.focus();
      }
    });
  }

  /// Sets size, position and flags for [mode] while the window is still
  /// hidden or about to change, so nothing flashes at the wrong size.
  Future<void> prepare(WindowMode mode) async {
    switch (mode) {
      case WindowMode.hidden:
        return;
      case WindowMode.manager:
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setSkipTaskbar(false);
        await windowManager.setResizable(true);
        await windowManager.setMinimumSize(managerMin);
        await windowManager.setSize(managerSize);
        await windowManager.setAlignment(Alignment.center);
      case WindowMode.overlay:
        await _shrink(overlaySize);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setSkipTaskbar(true);
        // Bottom-right of the screen the mouse is on, clear of the taskbar.
        await windowManager.setAlignment(Alignment.bottomRight);
        final p = await windowManager.getPosition();
        await windowManager.setPosition(Offset(p.dx - 20, p.dy - 20));
      case WindowMode.quickAdd:
        await _shrink(quickAddSize);
        await windowManager.setAlwaysOnTop(true);
        await windowManager.setSkipTaskbar(true);
        await windowManager.setAlignment(const Alignment(0, -0.35));
    }
  }

  Future<void> _shrink(Size size) async {
    if (await windowManager.isMaximized()) await windowManager.unmaximize();
    await windowManager.setMinimumSize(_tiny);
    await windowManager.setResizable(true);
    await windowManager.setSize(size);
    await windowManager.setResizable(false);
  }

  /// Makes the window visible. The alert overlay appears without taking
  /// keyboard focus, so it never swallows what you are typing.
  Future<void> reveal(WindowMode mode) async {
    switch (mode) {
      case WindowMode.hidden:
        return;
      case WindowMode.overlay:
        await windowManager.show(inactive: true);
      case WindowMode.manager:
      case WindowMode.quickAdd:
        await windowManager.show();
        await windowManager.focus();
    }
  }

  Future<void> hide() => windowManager.hide();
  Future<bool> isFocused() => windowManager.isFocused();
  Future<void> minimize() => windowManager.minimize();

  Future<void> quit() async {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() => onCloseRequested?.call();

  @override
  void onWindowBlur() => onBlur?.call();
}
