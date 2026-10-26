import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../models/launch_item.dart';

class LaunchResult {
  const LaunchResult(this.item, {this.error});

  final LaunchItem item;

  /// Null when the launch worked.
  final String? error;

  bool get ok => error == null;
}

/// Opens links, programs, files and folders. Everything runs as you, with the
/// same rights you have; targets come from your own tasks and are never fetched
/// from anywhere.
class LauncherService {
  /// Launches every item, one after another, with a short pause so heavy apps
  /// get a moment to start before the next one opens.
  Future<List<LaunchResult>> launchAll(List<LaunchItem> items) async {
    final results = <LaunchResult>[];
    for (var i = 0; i < items.length; i++) {
      results.add(await launch(items[i]));
      if (i < items.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
    }
    return results;
  }

  Future<LaunchResult> launch(LaunchItem item) async {
    final target = item.target.trim();
    if (target.isEmpty) return LaunchResult(item, error: 'Nothing to open');
    try {
      switch (item.kind) {
        case LaunchKind.url:
          final uri = Uri.tryParse(target);
          if (uri == null || uri.scheme.isEmpty) {
            return LaunchResult(item, error: 'Not a valid link: $target');
          }
          final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
          return opened ? LaunchResult(item) : LaunchResult(item, error: "Couldn't open ${item.displayName}");
        case LaunchKind.app:
        case LaunchKind.file:
          await _openPath(target);
          return LaunchResult(item);
      }
    } catch (e) {
      return LaunchResult(item, error: "Couldn't open ${item.displayName}");
    }
  }

  Future<void> _openPath(String target) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Opening programs and files is only implemented for Windows');
    }
    // A real path: let Explorer open it. That handles programs, shortcuts,
    // documents (default app) and folders, without a console window.
    final exists = File(target).existsSync() || Directory(target).existsSync();
    if (exists) {
      await Process.start('explorer.exe', [target], mode: ProcessStartMode.detached);
      return;
    }
    // Otherwise treat it as a name on the PATH (code, notepad, calc ...).
    // `start` resolves it the way the Run dialog does, so refuse anything
    // that cmd.exe would read as a second command.
    if (RegExp(r'[&|<>^"]').hasMatch(target)) {
      throw ArgumentError('Target contains characters that are not allowed');
    }
    await Process.start(
      'cmd',
      ['/c', 'start', '', target],
      mode: ProcessStartMode.detached,
    );
  }
}
